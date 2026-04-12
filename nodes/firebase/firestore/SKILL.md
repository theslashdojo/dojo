---
name: firestore
description: Cloud Firestore — NoSQL document database with real-time sync, offline persistence, and security rules. Use when storing, querying, or syncing structured data in Firebase apps.
---

# Cloud Firestore

## When to Use
- Storing and retrieving structured data as JSON-like documents
- Building apps that need real-time data sync across clients
- Querying data with filters, ordering, and pagination
- Enforcing access control with declarative security rules
- Working offline with automatic sync on reconnect
- Performing atomic multi-document writes via transactions or batches

## Prerequisites
- Firebase project initialized (see firebase/config)
- `firebase` npm package installed
- Firebase Authentication configured if using security rules with `request.auth`
- Firestore enabled in the Firebase Console (Database section)

## Data Model

Firestore organizes data into **collections** and **documents**:

```
users (collection)
  |-- userId1 (document)
  |     |-- name: "Alice"
  |     |-- email: "alice@example.com"
  |     |-- createdAt: Timestamp
  |     |-- posts (subcollection)
  |           |-- postId1 (document)
  |           |-- postId2 (document)
  |-- userId2 (document)
```

- **Collections** contain documents. They are created implicitly when you add a document.
- **Documents** contain fields and can hold subcollections. Max size is 1 MB.
- **Fields** support types: string, number, boolean, timestamp, array, map, reference, geopoint, null.
- **Subcollections** allow hierarchical nesting without loading parent document data.

## Workflow

### 1. Initialize Firestore

```typescript
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';

const app = initializeApp({
  apiKey: process.env.FIREBASE_API_KEY,
  projectId: process.env.FIREBASE_PROJECT_ID,
});
const db = getFirestore(app);
```

### 2. CRUD Operations

#### Add a Document (auto-generated ID)

```typescript
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';

const docRef = await addDoc(collection(db, 'users'), {
  name: 'Alice',
  email: 'alice@example.com',
  createdAt: serverTimestamp(),
});
console.log('Created with ID:', docRef.id);
```

#### Set a Document (explicit ID)

```typescript
import { doc, setDoc } from 'firebase/firestore';

await setDoc(doc(db, 'users', 'alice-uid'), {
  name: 'Alice',
  email: 'alice@example.com',
});

// Merge with existing data instead of overwriting
await setDoc(doc(db, 'users', 'alice-uid'), { age: 31 }, { merge: true });
```

#### Get a Document

```typescript
import { doc, getDoc } from 'firebase/firestore';

const snap = await getDoc(doc(db, 'users', 'alice-uid'));
if (snap.exists()) {
  console.log(snap.id, snap.data());
} else {
  console.log('Not found');
}
```

#### Update a Document

```typescript
import { doc, updateDoc, arrayUnion, increment, serverTimestamp } from 'firebase/firestore';

await updateDoc(doc(db, 'users', 'alice-uid'), {
  age: 31,
  'address.city': 'San Francisco',  // nested field via dot notation
  tags: arrayUnion('premium'),       // append to array
  loginCount: increment(1),          // atomic increment
  updatedAt: serverTimestamp(),
});
```

#### Delete a Document

```typescript
import { doc, deleteDoc } from 'firebase/firestore';

await deleteDoc(doc(db, 'users', 'alice-uid'));
```

### 3. Querying

```typescript
import { collection, query, where, orderBy, limit, startAfter, getDocs } from 'firebase/firestore';

// Simple query
const q = query(
  collection(db, 'users'),
  where('age', '>', 18),
  orderBy('name'),
  limit(10)
);
const snapshot = await getDocs(q);
snapshot.forEach(doc => console.log(doc.id, doc.data()));

// Pagination with cursors
const lastVisible = snapshot.docs[snapshot.docs.length - 1];
const nextPage = query(
  collection(db, 'users'),
  orderBy('name'),
  startAfter(lastVisible),
  limit(10)
);
```

### 4. Real-time Listeners

```typescript
import { doc, collection, query, where, onSnapshot } from 'firebase/firestore';

// Listen to a single document
const unsub = onSnapshot(doc(db, 'users', 'alice-uid'), (snap) => {
  console.log('Current data:', snap.data());
});

// Listen to a query
const unsubQuery = onSnapshot(
  query(collection(db, 'messages'), where('room', '==', 'general')),
  (snapshot) => {
    snapshot.docChanges().forEach((change) => {
      console.log(change.type, change.doc.id, change.doc.data());
    });
  }
);

// Stop listening when done
unsub();
unsubQuery();
```

### 5. Security Rules

Define in `firestore.rules` and deploy with `firebase deploy --only firestore:rules`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    match /posts/{postId} {
      allow read: if resource.data.status == 'published'
                  || request.auth.uid == resource.data.authorId;
      allow create: if request.auth != null
                    && request.resource.data.keys().hasAll(['title', 'authorId'])
                    && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if request.auth.uid == resource.data.authorId;
    }
  }
}
```

## Critical Rules

1. **Always define security rules** -- default deny-all rules block all reads and writes; never use allow-all in production.
2. **Handle offline state** -- Firestore queues writes offline and syncs when connectivity resumes; design your UI to reflect pending writes.
3. **Create composite indexes for multi-field queries** -- queries combining equality on one field with range/orderBy on another require a composite index. Firestore error messages include a direct link to create the missing index.
4. **Use transactions for read-then-write consistency** -- without a transaction, another client can modify data between your read and write.
5. **Prefer batched writes for bulk operations** -- batched writes are atomic and more efficient than individual writes.
6. **Structure data for your queries** -- Firestore does not support arbitrary joins; denormalize or use subcollections to match your access patterns.

## Edge Cases

- **Document size limit: 1 MB** -- documents exceeding this size cannot be written. Store large blobs in Cloud Storage instead.
- **Max 500 writes per batch** -- writeBatch and transactions are limited to 500 operations. Split larger batches into multiple commits.
- **1 write per second per document** -- sustained writes faster than 1/s to a single document cause contention. Use distributed counters or sharded writes for high-throughput counters.
- **Composite index limits** -- a project can have at most 200 composite indexes and 500 single-field index exemptions.
- **In/array-contains-any limit** -- the `in`, `not-in`, and `array-contains-any` operators accept a maximum of 30 comparison values.
- **Offline cache size** -- default cache size is 40 MB on web (configurable). Exceeding this evicts least-recently-used data.
- **Deleting collections** -- there is no single operation to delete a collection. You must delete each document individually or use a batched delete.
