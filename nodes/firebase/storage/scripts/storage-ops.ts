import { initializeApp, FirebaseApp } from 'firebase/app';
import {
  getStorage,
  ref,
  uploadBytes,
  getDownloadURL,
  getMetadata,
  updateMetadata,
  deleteObject,
  listAll,
  FirebaseStorage,
  FullMetadata,
} from 'firebase/storage';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { basename, extname } from 'path';

// --- Firebase initialization ---

function initFirebase(): FirebaseApp {
  const apiKey = process.env.FIREBASE_API_KEY;
  const authDomain = process.env.FIREBASE_AUTH_DOMAIN;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const storageBucket = process.env.FIREBASE_STORAGE_BUCKET;

  if (!apiKey || !projectId || !storageBucket) {
    console.error(JSON.stringify({
      error: 'Missing required environment variables',
      required: ['FIREBASE_API_KEY', 'FIREBASE_PROJECT_ID', 'FIREBASE_STORAGE_BUCKET'],
      optional: ['FIREBASE_AUTH_DOMAIN'],
    }, null, 2));
    process.exit(1);
  }

  return initializeApp({
    apiKey,
    authDomain: authDomain || `${projectId}.firebaseapp.com`,
    projectId,
    storageBucket,
  });
}

// --- MIME type detection ---

const MIME_TYPES: Record<string, string> = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.bmp': 'image/bmp',
  '.ico': 'image/x-icon',
  '.pdf': 'application/pdf',
  '.json': 'application/json',
  '.xml': 'application/xml',
  '.zip': 'application/zip',
  '.gz': 'application/gzip',
  '.tar': 'application/x-tar',
  '.txt': 'text/plain',
  '.csv': 'text/csv',
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.ts': 'application/typescript',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
};

function detectMimeType(filePath: string): string {
  const ext = extname(filePath).toLowerCase();
  return MIME_TYPES[ext] || 'application/octet-stream';
}

// --- Operations ---

async function uploadFile(
  storage: FirebaseStorage,
  storagePath: string,
  localFile: string,
): Promise<void> {
  if (!existsSync(localFile)) {
    console.error(JSON.stringify({ error: `Local file not found: ${localFile}` }));
    process.exit(1);
  }

  const data = new Uint8Array(readFileSync(localFile));
  const contentType = detectMimeType(localFile);
  const storageRef = ref(storage, storagePath);

  const snapshot = await uploadBytes(storageRef, data, {
    contentType,
    customMetadata: {
      originalName: basename(localFile),
      uploadedAt: new Date().toISOString(),
    },
  });

  const downloadUrl = await getDownloadURL(snapshot.ref);

  console.log(JSON.stringify({
    operation: 'upload',
    path: storagePath,
    size: snapshot.metadata.size,
    contentType: snapshot.metadata.contentType,
    downloadUrl,
    timeCreated: snapshot.metadata.timeCreated,
  }, null, 2));
}

async function downloadFile(
  storage: FirebaseStorage,
  storagePath: string,
  localFile?: string,
): Promise<void> {
  const storageRef = ref(storage, storagePath);
  const downloadUrl = await getDownloadURL(storageRef);

  if (localFile) {
    const response = await fetch(downloadUrl);
    if (!response.ok) {
      console.error(JSON.stringify({ error: `Download failed: ${response.status} ${response.statusText}` }));
      process.exit(1);
    }
    const buffer = Buffer.from(await response.arrayBuffer());
    writeFileSync(localFile, buffer);

    console.log(JSON.stringify({
      operation: 'download',
      path: storagePath,
      savedTo: localFile,
      size: buffer.length,
      downloadUrl,
    }, null, 2));
  } else {
    console.log(JSON.stringify({
      operation: 'download',
      path: storagePath,
      downloadUrl,
    }, null, 2));
  }
}

async function listFiles(
  storage: FirebaseStorage,
  storagePath: string,
): Promise<void> {
  const storageRef = ref(storage, storagePath);
  const result = await listAll(storageRef);

  const files = result.items.map((item) => ({
    name: item.name,
    fullPath: item.fullPath,
  }));

  const prefixes = result.prefixes.map((prefix) => ({
    name: prefix.name,
    fullPath: prefix.fullPath,
  }));

  console.log(JSON.stringify({
    operation: 'list',
    path: storagePath,
    fileCount: files.length,
    prefixCount: prefixes.length,
    files,
    prefixes,
  }, null, 2));
}

async function deleteFile(
  storage: FirebaseStorage,
  storagePath: string,
): Promise<void> {
  const storageRef = ref(storage, storagePath);
  await deleteObject(storageRef);

  console.log(JSON.stringify({
    operation: 'delete',
    path: storagePath,
    deleted: true,
  }, null, 2));
}

function formatMetadata(metadata: FullMetadata): Record<string, unknown> {
  return {
    name: metadata.name,
    fullPath: metadata.fullPath,
    bucket: metadata.bucket,
    size: metadata.size,
    contentType: metadata.contentType,
    contentEncoding: metadata.contentEncoding,
    cacheControl: metadata.cacheControl,
    contentDisposition: metadata.contentDisposition,
    contentLanguage: metadata.contentLanguage,
    customMetadata: metadata.customMetadata || {},
    timeCreated: metadata.timeCreated,
    updated: metadata.updated,
    md5Hash: metadata.md5Hash,
    generation: metadata.generation,
    metageneration: metadata.metageneration,
  };
}

async function manageMetadata(
  storage: FirebaseStorage,
  storagePath: string,
  newMetadata?: Record<string, string>,
): Promise<void> {
  const storageRef = ref(storage, storagePath);

  if (newMetadata) {
    // Separate known metadata fields from custom metadata
    const { contentType, cacheControl, contentDisposition, contentLanguage, ...customFields } = newMetadata;
    const updatePayload: Record<string, unknown> = {};

    if (contentType) updatePayload.contentType = contentType;
    if (cacheControl) updatePayload.cacheControl = cacheControl;
    if (contentDisposition) updatePayload.contentDisposition = contentDisposition;
    if (contentLanguage) updatePayload.contentLanguage = contentLanguage;

    if (Object.keys(customFields).length > 0) {
      updatePayload.customMetadata = customFields;
    }

    const updated = await updateMetadata(storageRef, updatePayload);

    console.log(JSON.stringify({
      operation: 'metadata',
      action: 'update',
      path: storagePath,
      metadata: formatMetadata(updated),
    }, null, 2));
  } else {
    const metadata = await getMetadata(storageRef);

    console.log(JSON.stringify({
      operation: 'metadata',
      action: 'get',
      path: storagePath,
      metadata: formatMetadata(metadata),
    }, null, 2));
  }
}

// --- CLI argument parsing ---

interface CliArgs {
  operation: string;
  path: string;
  file?: string;
  bucket?: string;
  metadata?: Record<string, string>;
}

function parseArgs(): CliArgs {
  const args = process.argv.slice(2);
  const result: CliArgs = { operation: '', path: '' };
  const metadataEntries: Record<string, string> = {};

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--op':
      case '--operation':
        result.operation = args[++i];
        break;
      case '--path':
        result.path = args[++i];
        break;
      case '--file':
        result.file = args[++i];
        break;
      case '--bucket':
        result.bucket = args[++i];
        break;
      case '--meta':
      case '--metadata': {
        // Accept key=value pairs: --meta contentType=image/png --meta author=user1
        const pair = args[++i];
        const eqIndex = pair.indexOf('=');
        if (eqIndex > 0) {
          metadataEntries[pair.substring(0, eqIndex)] = pair.substring(eqIndex + 1);
        }
        break;
      }
      default:
        // First positional arg is operation, second is path
        if (!result.operation) {
          result.operation = args[i];
        } else if (!result.path) {
          result.path = args[i];
        }
    }
  }

  if (Object.keys(metadataEntries).length > 0) {
    result.metadata = metadataEntries;
  }

  return result;
}

function printUsage(): void {
  console.error(`Firebase Cloud Storage Operations

Usage: npx tsx storage-ops.ts <operation> --path <storage-path> [options]

Operations:
  upload     Upload a local file to Cloud Storage
  download   Get download URL or save file locally
  list       List files and prefixes at a path
  delete     Delete a file from Cloud Storage
  metadata   Get or update file metadata

Options:
  --path <path>         Storage path (e.g. 'images/photo.jpg')
  --file <local-path>   Local file path (for upload source or download destination)
  --bucket <bucket>     Custom storage bucket (gs:// URL)
  --meta <key=value>    Metadata key-value pair (repeatable)

Examples:
  npx tsx storage-ops.ts upload --path images/photo.jpg --file ./photo.jpg
  npx tsx storage-ops.ts download --path images/photo.jpg
  npx tsx storage-ops.ts download --path images/photo.jpg --file ./downloaded.jpg
  npx tsx storage-ops.ts list --path images/
  npx tsx storage-ops.ts delete --path images/photo.jpg
  npx tsx storage-ops.ts metadata --path images/photo.jpg
  npx tsx storage-ops.ts metadata --path images/photo.jpg --meta contentType=image/jpeg --meta author=user1

Environment Variables:
  FIREBASE_API_KEY           Firebase API key (required)
  FIREBASE_AUTH_DOMAIN       Firebase auth domain (optional)
  FIREBASE_PROJECT_ID        Firebase project ID (required)
  FIREBASE_STORAGE_BUCKET    Storage bucket name (required)`);
}

// --- Main ---

async function main(): Promise<void> {
  const cli = parseArgs();

  if (!cli.operation || !cli.path) {
    printUsage();
    process.exit(1);
  }

  const app = initFirebase();
  const storage = cli.bucket
    ? getStorage(app, cli.bucket)
    : getStorage(app);

  try {
    switch (cli.operation) {
      case 'upload':
        if (!cli.file) {
          console.error(JSON.stringify({ error: '--file is required for upload' }));
          process.exit(1);
        }
        await uploadFile(storage, cli.path, cli.file);
        break;

      case 'download':
        await downloadFile(storage, cli.path, cli.file);
        break;

      case 'list':
        await listFiles(storage, cli.path);
        break;

      case 'delete':
        await deleteFile(storage, cli.path);
        break;

      case 'metadata':
        await manageMetadata(storage, cli.path, cli.metadata);
        break;

      default:
        console.error(JSON.stringify({ error: `Unknown operation: ${cli.operation}`, valid: ['upload', 'download', 'list', 'delete', 'metadata'] }));
        process.exit(1);
    }
  } catch (error: unknown) {
    const err = error as { code?: string; message?: string };
    console.error(JSON.stringify({
      error: err.message || 'Unknown error',
      code: err.code || 'unknown',
      operation: cli.operation,
      path: cli.path,
    }, null, 2));
    process.exit(1);
  }
}

main();
