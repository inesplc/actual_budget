const actual = require('@actual-app/api');
const { S3Client, ListObjectsV2Command, GetObjectCommand, PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { parse } = require('csv-parse/sync');
const path = require('path');
const fs = require('fs');

// Configuration
const SERVER_URL = process.env.ACTUAL_BUDGET_SERVER;
const PASSWORD = process.env.ACTUAL_BUDGET_PASSWORD;
const IMPORT_CONFIG = process.env.ACTUAL_IMPORT_CONFIG ? JSON.parse(process.env.ACTUAL_IMPORT_CONFIG.replace(/^'|'$/g, '')) : [];

// R2 Configuration
const R2_ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.CLOUDFLARE_R2_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.CLOUDFLARE_R2_SECRET_KEY;
const R2_BUCKET = 'actual-budget';

if (!PASSWORD || !R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
  console.error('Missing required environment variables.');
  process.exit(1);
}

if (IMPORT_CONFIG.length === 0) {
    console.error('No import configuration found in ACTUAL_IMPORT_CONFIG.');
    process.exit(1);
}

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  },
});

function maskIBAN(iban) {
  if (!iban || iban.length < 4) return iban;
  return `IBAN ending in ${iban.slice(-4)}`;
}

async function main() {
  console.log('Initializing Actual Budget API...');
  const cacheDir = path.join(process.cwd(), 'cache');
  if (!fs.existsSync(cacheDir)){
      fs.mkdirSync(cacheDir);
  }
  await actual.init({
    serverURL: SERVER_URL,
    password: PASSWORD,
    dataDir: cacheDir,
  });

  for (const config of IMPORT_CONFIG) {
      const { iban, syncId, accountName } = config;
      const maskedIban = maskIBAN(iban);
      console.log(`\n--- Processing ${maskedIban} ---`);
      
      try {
        console.log(`Downloading budget ${syncId}...`);
        await actual.downloadBudget(syncId);

        const accounts = await actual.getAccounts();
        const account = accounts.find(a => a.name === accountName);

        if (!account) {
            console.error(`Account "${accountName}" not found for ${maskedIban}. Skipping.`);
            continue;
        }
        console.log(`Found account "${accountName}" with ID: ${account.id}`);

        // List files in R2
        const prefix = `enable-banking/transactions/${iban}/`;
        console.log(`Checking for files in R2 with prefix: enable-banking/transactions/${maskedIban}/`);
        
        const listCmd = new ListObjectsV2Command({
            Bucket: R2_BUCKET,
            Prefix: prefix,
        });

        const listedObjects = await s3.send(listCmd);

        if (!listedObjects.Contents || listedObjects.Contents.length === 0) {
            console.log('No transaction files found.');
            continue;
        }

        for (const file of listedObjects.Contents) {
            const key = file.Key;
            if (!key.endsWith('.csv')) continue;

            const maskedKey = key.replaceAll(iban, maskedIban);
            console.log(`Processing ${maskedKey}...`);

            // Get file content
            const getCmd = new GetObjectCommand({ Bucket: R2_BUCKET, Key: key });
            const response = await s3.send(getCmd);
            const str = await response.Body.transformToString();

            // Parse CSV
            const records = parse(str, {
            columns: true,
            skip_empty_lines: true
            });

            if (records.length === 0) {
                console.log('No records in CSV.');
            } else {
                // Transform to Actual format
                const transactions = records.map(record => ({
                date: record.booking_date,
                amount: Math.round(parseFloat(record.total_amount) * 100), // Convert to cents
                payee_name: record.remittance_information,
                imported_id: `${record.booking_date}-${record.total_amount}-${record.remittance_information}`
                }));

                // Import
                console.log(`Importing ${transactions.length} transactions...`);
                await actual.importTransactions(account.id, transactions);
                console.log('Import successful.');
            }

            // Move file
            const filename = key.split('/').pop();
            const newKey = `enable-banking/transactions_imported/${iban}/${filename}`;

            const maskedNewKey = newKey.replaceAll(iban, maskedIban);
            console.log(`Moving file to ${maskedNewKey}...`);
            await s3.send(new PutObjectCommand({
            Bucket: R2_BUCKET,
            Key: newKey,
            Body: str
            }));

            await s3.send(new DeleteObjectCommand({
            Bucket: R2_BUCKET,
            Key: key
            }));
        }
      } catch (error) {
          console.error(`Error processing ${maskedIban}:`, error);
      }
  }

  console.log('\nAll done.');
  await actual.shutdown();
}

main();