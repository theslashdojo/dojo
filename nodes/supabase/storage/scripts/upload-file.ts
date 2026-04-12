import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { basename, extname } from 'path';

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

async function uploadFile(
  bucketName: string,
  localPath: string,
  storagePath?: string
) {
  const fileName = basename(localPath);
  const targetPath = storagePath || fileName;
  const ext = extname(fileName).toLowerCase();

  const mimeTypes: Record<string, string> = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.pdf': 'application/pdf',
    '.json': 'application/json',
    '.txt': 'text/plain',
    '.csv': 'text/csv',
  };

  const buffer = readFileSync(localPath);
  const contentType = mimeTypes[ext] || 'application/octet-stream';

  console.log(`Uploading ${localPath} to ${bucketName}/${targetPath}...`);

  const { data, error } = await supabase.storage
    .from(bucketName)
    .upload(targetPath, buffer, {
      contentType,
      upsert: true,
    });

  if (error) {
    console.error('Upload error:', error.message);
    return;
  }

  console.log('Uploaded:', data.path);

  // Generate URL
  const { data: urlData } = await supabase.storage
    .from(bucketName)
    .createSignedUrl(targetPath, 3600);

  if (urlData) {
    console.log('Signed URL (1hr):', urlData.signedUrl);
  }
}

const bucket = process.argv[2] || 'uploads';
const file = process.argv[3];
const path = process.argv[4];

if (!file) {
  console.error('Usage: npx tsx upload-file.ts <bucket> <local-file> [storage-path]');
  process.exit(1);
}

uploadFile(bucket, file, path).catch(console.error);
