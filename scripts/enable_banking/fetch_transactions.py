import os
import json
import sys
import base64
import io
import uuid
import logging
import boto3
import requests
import jwt as pyjwt
import pandas as pd
import re
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse, parse_qs
from botocore.exceptions import ClientError


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


API_ORIGIN = "https://api.enablebanking.com"
ASPSP_LIST = json.loads(os.environ.get("ENABLE_BANKING_ASPSP", "[]"))
R2_BUCKET_NAME = "actual-budget"
R2_SESSION_KEY = "enable-banking/{aspsp}/session_store.json"
R2_CHECKPOINT_KEY = "enable-banking/checkpoint.txt"

def mask_iban(iban):
    if not iban or len(iban) < 4:
        return iban
    return f"IBAN ending in {iban[-4:]}"

def get_r2_client():
    """Initialize and return a boto3 client for R2."""
    
    account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID")
    access_key = os.environ.get("CLOUDFLARE_R2_KEY_ID")
    secret_key = os.environ.get("CLOUDFLARE_R2_SECRET_KEY")
    
    if not all([account_id, access_key, secret_key]):
        logger.error("Missing Cloudflare R2 credentials in environment variables.")
        sys.exit(1)
        
    endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"
    
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key
    )

def read_from_r2(client, key):
    """Read a file from R2."""
    try:
        logger.info(f"Reading {key} from R2...")
        response = client.get_object(Bucket=R2_BUCKET_NAME, Key=key)
        return response['Body'].read().decode('utf-8')
    except ClientError as e:
        if e.response['Error']['Code'] == "NoSuchKey":
            logger.warning(f"File {key} not found in R2.")
            return None
        else:
            logger.error(f"Error reading from R2: {e}")
            raise

def write_to_r2(client, key, content):
    """Write content to R2."""
    try:
        logger.info(f"Writing {key} to R2...")
        client.put_object(Bucket=R2_BUCKET_NAME, Key=key, Body=content)
        logger.info(f"Successfully saved {key} to R2.")
    except Exception as e:
        logger.error(f"Error writing to R2: {e}")
        raise

def get_jwt():
    """Generate JWT for Enable Banking API."""
    iat = int(datetime.now().timestamp())
    jwt_body = {
        "iss": "enablebanking.com",
        "aud": "api.enablebanking.com",
        "iat": iat,
        "exp": iat + 3600,
    }
    
    private_key_b64 = os.environ.get("ENABLE_BANKING_PRIVATE_KEY_BASE64")
    if private_key_b64:
        try:
            private_key = base64.b64decode(private_key_b64)
        except Exception as e:
            logger.error(f"Failed to decode ENABLE_BANKING_PRIVATE_KEY_BASE64: {e}")
            sys.exit(1)
    else:
        logger.error(f"Private key not found in env var ENABLE_BANKING_PRIVATE_KEY_BASE64")
        sys.exit(1)
        
    return pyjwt.encode(
        jwt_body,
        private_key,
        algorithm="RS256",
        headers={"kid": os.environ.get("ENABLE_BANKING_APPLICATION_ID")},
    )

def authenticate(headers, r2_client, aspsp, current_session=None):
    """Authenticate with Enable Banking API, reusing session or creating new one."""
    
    # Check if current session is valid
    if current_session:
        session_id = current_session.get("session_id")
        if session_id:
            logger.info(f"Checking validity of stored session: {session_id}")
            try:
                r = requests.get(f"{API_ORIGIN}/sessions/{session_id}", headers=headers)
                if r.status_code == 200:
                    logger.info("Session is valid.")
                    return current_session
                else:
                    logger.warning(f"Session invalid (Status: {r.status_code}).")
            except Exception as e:
                logger.warning(f"Error checking session: {e}")
    elif os.environ.get("IS_LOCAL"):
        
        r = requests.get(f"{API_ORIGIN}/application", headers=headers)
        r.raise_for_status()
        app_details = r.json()
        
        # Start Auth
        logger.info(f"Starting new authentication flow valid for {aspsp['name']}...")
        valid_until = (datetime.now(timezone.utc) + timedelta(seconds=aspsp["consent_validity_seconds"])).isoformat()
        body = {
            "access": {"valid_until": valid_until},
            "aspsp": {"name": aspsp["name"], "country": aspsp["country"]},
            "state": str(uuid.uuid4()),
            "redirect_url": app_details["redirect_urls"][0],
            "psu_type": "personal",
        }
        
        r = requests.post(f"{API_ORIGIN}/auth", json=body, headers=headers)
        r.raise_for_status()
        auth_url = r.json()["url"]
        
        logger.info(f"\n\n\n========ACTION REQUIRED: Please open the following URL to authenticate:========\n\n{auth_url}\n")
        redirected_url = input("Paste the redirected URL (or the 'code' parameter) here: ").strip()
        
        # Extract code
        if "code=" in redirected_url:
            parsed = urlparse(redirected_url)
            qs = parse_qs(parsed.query)
            auth_code = qs.get("code", [None])[0]
        else:
            auth_code = redirected_url # Assume user pasted just the code
            
        if not auth_code:
            logger.error("Could not extract auth code from input.")
            sys.exit(1)
            
        # Create Session
        r = requests.post(f"{API_ORIGIN}/sessions", json={"code": auth_code}, headers=headers)
        r.raise_for_status()
        session = r.json()
        logger.info("New session created.")
        
        # Save to R2
        write_to_r2(r2_client, R2_SESSION_KEY.format(aspsp=aspsp['name'].lower().replace(" ", "_")), json.dumps(session, indent=2))
    else:
        logger.error("No valid session found and IS_LOCAL is not set. Cannot authenticate.")
        sys.exit(1)
    return session

def clean_remittance_info(remittance_information):
    if not remittance_information:
        return "Unknown"
        
    cleaned = remittance_information[0].upper()

    patterns_to_remove = [
        r'^COMPRA\s\d{4}\s',
        r'CONTACTLESS',
        r'\sEE$',
        r'\sLI$',
        r'\sE LI$',
        r'\sES$',
        r'\sNL$',
    ]
    
    for pattern in patterns_to_remove:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)
    
    cleaned = ' '.join(word.capitalize() for word in cleaned.split())
    return cleaned if cleaned else "Unknown"

def fetch_transactions(headers, account_uid, date_from, date_to):
    """Fetch transactions with pagination."""
    logger.info(f"Fetching transactions from {date_from} to {date_to}...")
    
    params = {
        "date_from": date_from,
        "date_to": date_to,
        "strategy": "default",
    }
    
    all_transactions = []
    continuation_key = None
    
    while True:
        if continuation_key:
            params["continuation_key"] = continuation_key
            
        r = requests.get(f"{API_ORIGIN}/accounts/{account_uid}/transactions", headers=headers, params=params)
        r.raise_for_status()
        data = r.json()
        
        batch = data.get("transactions", [])
        all_transactions.extend(batch)
        logger.info(f"Fetched {len(batch)} transactions (Total: {len(all_transactions)})")
        
        continuation_key = data.get("continuation_key")
        if not continuation_key:
            break
            
    return all_transactions

def process_transactions(transactions):
    if transactions:
        processed_txs = []
        for tx in transactions:
            amount = tx["transaction_amount"]["amount"]
            if tx["credit_debit_indicator"] == "DBIT":
                amount = "-" + amount

            processed_txs.append({
                "booking_date": tx["booking_date"],
                "total_amount": amount,
                "remittance_information": clean_remittance_info(tx.get("remittance_information", []))
            })
        return pd.DataFrame(processed_txs)
    else:
        return None

def main():
    r2 = get_r2_client()
        
    # Load Checkpoint
    checkpoint_date = read_from_r2(r2, R2_CHECKPOINT_KEY)
    checkpoint_date = checkpoint_date.strip()
    logger.info(f"Checkpoint found: {checkpoint_date}")

    # Determine Date Range
    date_from = checkpoint_date
    date_to = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")

    if date_from >= date_to:
        logger.info(f"Checkpoint is up to date ({date_from}). No transactions to fetch.")
        return

    for aspsp in ASPSP_LIST:
        logger.info(f"Processing ASPSP: {aspsp['name']}")
    
        # Load Session
        session_data = None
        session_json = read_from_r2(r2, R2_SESSION_KEY.format(aspsp=aspsp['name'].lower().replace(" ", "_")))
        if session_json:
            session_data = json.loads(session_json)

        # Auth
        token = get_jwt()
        headers = {"Authorization": f"Bearer {token}"}
        session = authenticate(headers, r2, aspsp, session_data)

        # Fetch Transactions per Account
        for acc in session.get("accounts", []):
            # Check IBAN
            target_iban = acc.get("account_id", {}).get("iban")
            account_uid = acc.get("uid")
            if not account_uid:
                logger.error(f"Account UID not found in session.")
                sys.exit(1)

            transactions = fetch_transactions(headers, account_uid, date_from, date_to)
            processed_transactions = process_transactions(transactions)
            if processed_transactions is not None and not processed_transactions.empty:
                for date, group in processed_transactions.groupby('booking_date'):
                    csv_buffer = io.StringIO()
                    group.to_csv(csv_buffer, index=False)

                    filename = f"transactions_{target_iban}_{date}.csv"
                    r2_key = f"enable-banking/transactions/{target_iban}/{filename}"

                    write_to_r2(r2, r2_key, csv_buffer.getvalue())

                    masked_iban = mask_iban(target_iban)
                    masked_key = r2_key.replace(target_iban, masked_iban)
                    logger.info(f"Saved {len(group)} transactions for {date} to R2: {masked_key}")
            else:
                logger.info("No transactions found.")

    # Update Checkpoint
    write_to_r2(r2, R2_CHECKPOINT_KEY, date_to)
    logger.info(f"Checkpoint updated to {date_to}")

if __name__ == "__main__":
    main()
