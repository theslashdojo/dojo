---
name: auth
description: Implement user authentication with Firebase — email/password, Google OAuth, phone SMS, anonymous sign-in, Admin SDK token verification, and custom claims. Use when adding login/signup flows, verifying tokens server-side, or managing user roles.
---

# Firebase Auth

## When to Use
- Adding user authentication (sign-up, sign-in, sign-out) to a web or mobile app
- Implementing Google, Facebook, Apple, or GitHub OAuth sign-in
- Adding phone number SMS verification
- Providing anonymous guest access that upgrades to a permanent account
- Verifying ID tokens on a backend server or in Cloud Functions
- Setting custom claims for role-based access control (admin, editor, viewer)
- Writing Firestore or Storage security rules that depend on auth state

## Prerequisites
- Firebase project created at console.firebase.google.com
- Firebase SDK installed: `npm install firebase`
- Firebase app initialized with apiKey, authDomain, and projectId (see firebase/config)
- For Admin SDK: `npm install firebase-admin` and a service account key or Google Cloud environment
- Desired sign-in providers enabled in Firebase Console > Authentication > Sign-in method

## Workflow

### Initialize Firebase Auth

```typescript
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const app = initializeApp({
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN,
  projectId: process.env.FIREBASE_PROJECT_ID,
});

const auth = getAuth(app);
```

### Email/Password Authentication

```typescript
import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  sendEmailVerification,
  sendPasswordResetEmail,
} from 'firebase/auth';

// Sign up
const { user } = await createUserWithEmailAndPassword(auth, email, password);
await sendEmailVerification(user);

// Sign in
const { user: signedIn } = await signInWithEmailAndPassword(auth, email, password);

// Password reset
await sendPasswordResetEmail(auth, email);
```

### Google OAuth

```typescript
import { signInWithPopup, GoogleAuthProvider } from 'firebase/auth';

const provider = new GoogleAuthProvider();
provider.addScope('email');
provider.addScope('profile');

try {
  const result = await signInWithPopup(auth, provider);
  const credential = GoogleAuthProvider.credentialFromResult(result);
  console.log('User:', result.user.displayName);
  console.log('Google access token:', credential?.accessToken);
} catch (error: any) {
  if (error.code === 'auth/popup-blocked') {
    // Fall back to redirect flow
    await signInWithRedirect(auth, provider);
  } else if (error.code === 'auth/popup-closed-by-user') {
    console.log('User closed the popup');
  }
}
```

### Phone Number Auth

```typescript
import { signInWithPhoneNumber, RecaptchaVerifier } from 'firebase/auth';

// Set up invisible reCAPTCHA
const recaptcha = new RecaptchaVerifier(auth, 'sign-in-button', {
  size: 'invisible',
});

// Send SMS
const confirmation = await signInWithPhoneNumber(auth, '+15551234567', recaptcha);

// After user enters the code
const { user } = await confirmation.confirm(userEnteredCode);
```

### Anonymous Auth

```typescript
import { signInAnonymously, linkWithCredential, EmailAuthProvider } from 'firebase/auth';

// Sign in anonymously
const { user } = await signInAnonymously(auth);
// user.isAnonymous === true

// Later, upgrade to permanent account
const credential = EmailAuthProvider.credential(email, password);
const { user: upgraded } = await linkWithCredential(user, credential);
// upgraded.isAnonymous === false
```

### Listen to Auth State

```typescript
import { onAuthStateChanged } from 'firebase/auth';

const unsubscribe = onAuthStateChanged(auth, (user) => {
  if (user) {
    console.log('Signed in:', user.uid, user.email);
  } else {
    console.log('Signed out');
  }
});
```

### Get ID Token

```typescript
const user = auth.currentUser;
if (user) {
  const idToken = await user.getIdToken();
  // Send idToken to your backend in Authorization header
  fetch('/api/data', {
    headers: { Authorization: `Bearer ${idToken}` },
  });
}
```

### Admin SDK: Verify Tokens

```typescript
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

initializeApp({ credential: cert('./service-account.json') });

// Verify ID token from client
const decoded = await getAuth().verifyIdToken(idToken);
console.log('UID:', decoded.uid);
```

### Admin SDK: Custom Claims

```typescript
// Set claims (server-side)
await getAuth().setCustomUserClaims(uid, { admin: true, role: 'editor' });

// Claims appear in security rules as request.auth.token.admin
// Client reads claims after token refresh:
const { claims } = await user.getIdTokenResult(true);
if (claims.admin) { /* show admin UI */ }
```

### Security Rules with request.auth

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.data.authorId;
    }
    match /admin/{doc=**} {
      allow read, write: if request.auth.token.admin == true;
    }
  }
}
```

## Critical Rules

1. **Always use onAuthStateChanged** to track auth state instead of checking auth.currentUser directly, which may be null during SDK initialization
2. **Verify ID tokens server-side** with Admin SDK verifyIdToken() before trusting client-supplied tokens; never trust client-side auth state alone for sensitive operations
3. **Handle all auth errors** with specific error codes (auth/email-already-in-use, auth/wrong-password, auth/user-not-found, auth/too-many-requests) and surface clear messages to users
4. **Enable only needed providers** in the Firebase console; each enabled provider is an attack surface
5. **Force-refresh tokens after setting custom claims** by calling getIdToken(true) on the client, since claims only update on token refresh (up to 1 hour otherwise)
6. **Use security rules** that check request.auth; never rely solely on client-side route guards for access control

## Edge Cases

### Popup blocked by browser
signInWithPopup may fail with `auth/popup-blocked`. Catch this error and fall back to signInWithRedirect(auth, provider), then handle the result with getRedirectResult(auth) on page load.

### Email not verified
After createUserWithEmailAndPassword, the user can sign in even without verifying their email. Check user.emailVerified before granting access to protected features. Send verification with sendEmailVerification(user).

### Token expiry
ID tokens expire after 1 hour. The SDK auto-refreshes them, but if you cache tokens externally (e.g., in a cookie), implement refresh logic. Server-side verifyIdToken() rejects expired tokens by default; pass checkRevoked: true to also catch revoked tokens.

### Anonymous account data loss
If an anonymous user clears browser data or signs out without linking to a permanent credential, their account is effectively lost. Prompt anonymous users to link accounts early.

### Custom claims size limit
Custom claims are capped at 1000 bytes total (serialized JSON). Store large user data in Firestore, not in claims.

### Rate limiting
Firebase Auth enforces rate limits on sign-in attempts. Handle `auth/too-many-requests` by showing a cooldown message. For email/password, enable email enumeration protection to prevent account existence probing.
