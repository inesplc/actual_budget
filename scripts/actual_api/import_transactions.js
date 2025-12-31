const actual = require('@actual-app/api');
const { S3Client, ListObjectsV2Command, GetObjectCommand, PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { parse } = require('csv-parse/sync');

// Configuration
const SERVER_URL = 'https://actual-budget-ines-478d02935e03.herokuapp.com';
const PASSWORD = process.env.ACTUAL_BUDGET_PASSWORD;
const SYNC_ID = process.env.ACTUAL_SYNC_ID ? process.env.ACTUAL_SYNC_ID.trim() : null;
const IBAN = process.env.ENABLE_BANKING_DUO_IBAN;

// R2 Configuration
const R2_ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.CLOUDFLARE_R2_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.CLOUDFLARE_R2_SECRET_KEY;
const R2_BUCKET = 'actual-budget';

if (!PASSWORD || !SYNC_ID || !IBAN || !R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
  console.error('Missing required environment variables.');
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

async function main() {
  console.log('Initializing Actual Budget API...');
  await actual.init({
    serverURL: SERVER_URL,
    password: PASSWORD,
  });

  console.log(`Downloading budget ${SYNC_ID}...`);
  await actual.downloadBudget(SYNC_ID);

  const accounts = await actual.getAccounts();
  const duoAccount = accounts.find(a => a.name === 'DUO');

  if (!duoAccount) {
    console.error('Account "DUO" not found');
    await actual.shutdown();
    process.exit(1);
  }
  console.log(`Found account "DUO" with ID: ${duoAccount.id}`);

  // List files in R2
  const prefix = `enable-banking/transactions/${IBAN}/`;
  console.log(`Checking for files in R2 with prefix: ${prefix}`);
  
  const listCmd = new ListObjectsV2Command({
    Bucket: R2_BUCKET,
    Prefix: prefix,
  });

  const listedObjects = await s3.send(listCmd);

  if (!listedObjects.Contents || listedObjects.Contents.length === 0) {
    console.log('No transaction files found.');
    await actual.shutdown();
    return;
  }

  for (const file of listedObjects.Contents) {
    const key = file.Key;
    if (!key.endsWith('.csv')) continue;

    console.log(`Processing ${key}...`);

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
        await actual.importTransactions(duoAccount.id, transactions);
        console.log('Import successful.');
    }

    // Move file
    const filename = key.split('/').pop();
    const newKey = `enable-banking/transactions_imported/${IBAN}/${filename}`;

    console.log(`Moving file to ${newKey}...`);
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

  console.log('All done.');
  await actual.shutdown();
}