import { initializeApp } from 'firebase/app';
import {
  getFirestore,
  collection,
  doc,
  addDoc,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  onSnapshot,
  serverTimestamp,
  WhereFilterOp,
  Firestore,
} from 'firebase/firestore';

// ---------------------------------------------------------------------------
// Initialize Firebase + Firestore from environment variables
// ---------------------------------------------------------------------------

const app = initializeApp({
  apiKey: process.env.FIREBASE_API_KEY,
  projectId: process.env.FIREBASE_PROJECT_ID,
});

const db: Firestore = getFirestore(app);

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

interface Args {
  operation: string;
  collection: string;
  id?: string;
  data?: Record<string, unknown>;
  where?: { field: string; op: WhereFilterOp; value: string };
  orderBy?: string;
  limit?: number;
}

function parseArgs(argv: string[]): Args {
  const args: Partial<Args> = {};
  let i = 2; // skip node and script path
  while (i < argv.length) {
    switch (argv[i]) {
      case '--op':
      case '--operation':
        args.operation = argv[++i];
        break;
      case '--collection':
        args.collection = argv[++i];
        break;
      case '--id':
        args.id = argv[++i];
        break;
      case '--data':
        args.data = JSON.parse(argv[++i]);
        break;
      case '--where': {
        // format: field,op,value  e.g. "age,>,18"
        const parts = argv[++i].split(',');
        if (parts.length < 3) {
          throw new Error('--where format: field,op,value (e.g. "age,>,18")');
        }
        args.where = {
          field: parts[0],
          op: parts[1] as WhereFilterOp,
          value: parts.slice(2).join(','), // rejoin in case value contains commas
        };
        break;
      }
      case '--orderBy':
        args.orderBy = argv[++i];
        break;
      case '--limit':
        args.limit = parseInt(argv[++i], 10);
        break;
      default:
        // First positional arg is the operation if not already set
        if (!args.operation) {
          args.operation = argv[i];
        }
        break;
    }
    i++;
  }

  if (!args.operation) {
    printUsage();
    process.exit(1);
  }
  if (!args.collection) {
    console.error('Error: --collection is required');
    process.exit(1);
  }
  return args as Args;
}

function printUsage(): void {
  console.log(`Usage: npx ts-node firestore-ops.ts <operation> --collection <name> [options]

Operations:
  add       Add a document with auto-generated ID
  set       Set a document with explicit --id
  get       Get a single document by --id
  list      List all documents in a collection
  query     Query documents with --where, --orderBy, --limit
  update    Update a document by --id with --data
  delete    Delete a document by --id
  listen    Listen to real-time changes (Ctrl+C to stop)

Options:
  --collection <name>    Firestore collection path (required)
  --id <documentId>      Document ID (required for get, set, update, delete)
  --data <json>          JSON data for add, set, update
  --where <f,op,v>       Where clause: field,operator,value (e.g. "age,>,18")
  --orderBy <field>      Field to order results by
  --limit <n>            Maximum number of documents to return

Examples:
  npx ts-node firestore-ops.ts add --collection users --data '{"name":"Alice","age":30}'
  npx ts-node firestore-ops.ts get --collection users --id abc123
  npx ts-node firestore-ops.ts query --collection users --where "age,>,18" --orderBy name --limit 10
  npx ts-node firestore-ops.ts listen --collection messages --where "room,==,general"
`);
}

// ---------------------------------------------------------------------------
// Coerce string values to appropriate types for query filters
// ---------------------------------------------------------------------------

function coerceValue(value: string): unknown {
  if (value === 'true') return true;
  if (value === 'false') return false;
  if (value === 'null') return null;
  const num = Number(value);
  if (!isNaN(num) && value.trim() !== '') return num;
  return value;
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

async function opAdd(args: Args): Promise<void> {
  if (!args.data) {
    console.error('Error: --data is required for add');
    process.exit(1);
  }
  const colRef = collection(db, args.collection);
  const docRef = await addDoc(colRef, {
    ...args.data,
    createdAt: serverTimestamp(),
  });
  console.log(JSON.stringify({ success: true, id: docRef.id }, null, 2));
}

async function opSet(args: Args): Promise<void> {
  if (!args.id) {
    console.error('Error: --id is required for set');
    process.exit(1);
  }
  if (!args.data) {
    console.error('Error: --data is required for set');
    process.exit(1);
  }
  const docRef = doc(db, args.collection, args.id);
  await setDoc(docRef, args.data);
  console.log(JSON.stringify({ success: true, id: args.id }, null, 2));
}

async function opGet(args: Args): Promise<void> {
  if (!args.id) {
    console.error('Error: --id is required for get');
    process.exit(1);
  }
  const docRef = doc(db, args.collection, args.id);
  const snap = await getDoc(docRef);
  if (snap.exists()) {
    console.log(JSON.stringify({ success: true, id: snap.id, documents: [{ id: snap.id, ...snap.data() }] }, null, 2));
  } else {
    console.log(JSON.stringify({ success: false, id: args.id, documents: [], error: 'Document not found' }, null, 2));
  }
}

async function opList(args: Args): Promise<void> {
  const colRef = collection(db, args.collection);
  const snapshot = await getDocs(colRef);
  const documents = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
  console.log(JSON.stringify({ success: true, documents, count: documents.length }, null, 2));
}

async function opQuery(args: Args): Promise<void> {
  const colRef = collection(db, args.collection);
  const constraints: Parameters<typeof query>[1][] = [];

  if (args.where) {
    constraints.push(where(args.where.field, args.where.op, coerceValue(args.where.value)));
  }
  if (args.orderBy) {
    constraints.push(orderBy(args.orderBy));
  }
  if (args.limit) {
    constraints.push(limit(args.limit));
  }

  const q = constraints.length > 0
    ? query(colRef, ...constraints)
    : query(colRef);

  const snapshot = await getDocs(q);
  const documents = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
  console.log(JSON.stringify({ success: true, documents, count: documents.length }, null, 2));
}

async function opUpdate(args: Args): Promise<void> {
  if (!args.id) {
    console.error('Error: --id is required for update');
    process.exit(1);
  }
  if (!args.data) {
    console.error('Error: --data is required for update');
    process.exit(1);
  }
  const docRef = doc(db, args.collection, args.id);
  await updateDoc(docRef, args.data);
  console.log(JSON.stringify({ success: true, id: args.id }, null, 2));
}

async function opDelete(args: Args): Promise<void> {
  if (!args.id) {
    console.error('Error: --id is required for delete');
    process.exit(1);
  }
  const docRef = doc(db, args.collection, args.id);
  await deleteDoc(docRef);
  console.log(JSON.stringify({ success: true, id: args.id }, null, 2));
}

async function opListen(args: Args): Promise<void> {
  const colRef = collection(db, args.collection);
  const constraints: Parameters<typeof query>[1][] = [];

  if (args.where) {
    constraints.push(where(args.where.field, args.where.op, coerceValue(args.where.value)));
  }
  if (args.orderBy) {
    constraints.push(orderBy(args.orderBy));
  }
  if (args.limit) {
    constraints.push(limit(args.limit));
  }

  const q = constraints.length > 0
    ? query(colRef, ...constraints)
    : query(colRef);

  console.error('Listening for changes... (Ctrl+C to stop)');

  onSnapshot(q, (snapshot) => {
    snapshot.docChanges().forEach((change) => {
      const event = {
        type: change.type,
        id: change.doc.id,
        data: change.doc.data(),
      };
      console.log(JSON.stringify(event));
    });
  }, (error) => {
    console.error(JSON.stringify({ success: false, error: error.message }));
    process.exit(1);
  });

  // Keep the process alive until interrupted
  await new Promise<void>((resolve) => {
    process.on('SIGINT', () => {
      console.error('\nStopped listening.');
      resolve();
    });
    process.on('SIGTERM', () => {
      resolve();
    });
  });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const args = parseArgs(process.argv);

  switch (args.operation) {
    case 'add':
      await opAdd(args);
      break;
    case 'set':
      await opSet(args);
      break;
    case 'get':
      await opGet(args);
      break;
    case 'list':
      await opList(args);
      break;
    case 'query':
      await opQuery(args);
      break;
    case 'update':
      await opUpdate(args);
      break;
    case 'delete':
      await opDelete(args);
      break;
    case 'listen':
      await opListen(args);
      break;
    default:
      console.error(`Unknown operation: ${args.operation}`);
      printUsage();
      process.exit(1);
  }
}

main().catch((err) => {
  console.error(JSON.stringify({ success: false, error: err.message }));
  process.exit(1);
});
