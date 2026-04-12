import { initializeApp, FirebaseApp } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signInWithPopup,
  signInAnonymously,
  signOut,
  onAuthStateChanged,
  GoogleAuthProvider,
  Auth,
  UserCredential,
} from 'firebase/auth';

// ---------------------------------------------------------------------------
// Firebase Auth Setup Script
//
// Usage:
//   npx tsx auth-setup.ts <action> [options]
//
// Actions:
//   signup   --email <email> --password <password>
//   signin   --email <email> --password <password>
//   google   (opens popup — browser environment only)
//   anonymous
//   signout
//   status
//
// Environment variables (required):
//   FIREBASE_API_KEY       — Web API key from Firebase console
//   FIREBASE_AUTH_DOMAIN   — e.g. my-project.firebaseapp.com
//   FIREBASE_PROJECT_ID    — Firebase project ID
// ---------------------------------------------------------------------------

interface ActionResult {
  action: string;
  success: boolean;
  uid?: string;
  email?: string | null;
  displayName?: string | null;
  idToken?: string;
  isAnonymous?: boolean;
  error?: string;
}

function getFirebaseConfig(): { apiKey: string; authDomain: string; projectId: string } {
  const apiKey = process.env.FIREBASE_API_KEY;
  const authDomain = process.env.FIREBASE_AUTH_DOMAIN;
  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (!apiKey || !authDomain || !projectId) {
    console.error(
      JSON.stringify({
        action: 'init',
        success: false,
        error:
          'Missing required environment variables. Set FIREBASE_API_KEY, FIREBASE_AUTH_DOMAIN, and FIREBASE_PROJECT_ID.',
      })
    );
    process.exit(1);
  }

  return { apiKey, authDomain, projectId };
}

function parseArgs(): { action: string; email?: string; password?: string } {
  const args = process.argv.slice(2);
  const action = args[0] || 'status';
  let email: string | undefined;
  let password: string | undefined;

  for (let i = 1; i < args.length; i++) {
    if (args[i] === '--email' && args[i + 1]) {
      email = args[++i];
    } else if (args[i] === '--password' && args[i + 1]) {
      password = args[++i];
    }
  }

  return { action, email, password };
}

function printResult(result: ActionResult): void {
  console.log(JSON.stringify(result, null, 2));
}

async function credentialToResult(
  action: string,
  credential: UserCredential
): Promise<ActionResult> {
  const { user } = credential;
  const idToken = await user.getIdToken();
  return {
    action,
    success: true,
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    idToken,
    isAnonymous: user.isAnonymous,
  };
}

async function handleSignup(auth: Auth, email: string, password: string): Promise<ActionResult> {
  try {
    const credential = await createUserWithEmailAndPassword(auth, email, password);
    return credentialToResult('signup', credential);
  } catch (err: any) {
    return { action: 'signup', success: false, error: `${err.code}: ${err.message}` };
  }
}

async function handleSignin(auth: Auth, email: string, password: string): Promise<ActionResult> {
  try {
    const credential = await signInWithEmailAndPassword(auth, email, password);
    return credentialToResult('signin', credential);
  } catch (err: any) {
    return { action: 'signin', success: false, error: `${err.code}: ${err.message}` };
  }
}

async function handleGoogleSignin(auth: Auth): Promise<ActionResult> {
  try {
    const provider = new GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    const credential = await signInWithPopup(auth, provider);
    return credentialToResult('google', credential);
  } catch (err: any) {
    return { action: 'google', success: false, error: `${err.code}: ${err.message}` };
  }
}

async function handleAnonymous(auth: Auth): Promise<ActionResult> {
  try {
    const credential = await signInAnonymously(auth);
    return credentialToResult('anonymous', credential);
  } catch (err: any) {
    return { action: 'anonymous', success: false, error: `${err.code}: ${err.message}` };
  }
}

async function handleSignout(auth: Auth): Promise<ActionResult> {
  try {
    await signOut(auth);
    return { action: 'signout', success: true };
  } catch (err: any) {
    return { action: 'signout', success: false, error: `${err.code}: ${err.message}` };
  }
}

function handleStatus(auth: Auth): Promise<ActionResult> {
  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      resolve({ action: 'status', success: true, uid: undefined, email: null });
    }, 3000);

    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      clearTimeout(timeout);
      unsubscribe();

      if (user) {
        const idToken = await user.getIdToken();
        resolve({
          action: 'status',
          success: true,
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          idToken,
          isAnonymous: user.isAnonymous,
        });
      } else {
        resolve({
          action: 'status',
          success: true,
          error: 'No user is currently signed in.',
        });
      }
    });
  });
}

async function main(): Promise<void> {
  const config = getFirebaseConfig();
  const app: FirebaseApp = initializeApp(config);
  const auth: Auth = getAuth(app);

  const { action, email, password } = parseArgs();

  let result: ActionResult;

  switch (action) {
    case 'signup':
      if (!email || !password) {
        result = {
          action: 'signup',
          success: false,
          error: 'Usage: auth-setup.ts signup --email <email> --password <password>',
        };
        break;
      }
      result = await handleSignup(auth, email, password);
      break;

    case 'signin':
      if (!email || !password) {
        result = {
          action: 'signin',
          success: false,
          error: 'Usage: auth-setup.ts signin --email <email> --password <password>',
        };
        break;
      }
      result = await handleSignin(auth, email, password);
      break;

    case 'google':
      result = await handleGoogleSignin(auth);
      break;

    case 'anonymous':
      result = await handleAnonymous(auth);
      break;

    case 'signout':
      result = await handleSignout(auth);
      break;

    case 'status':
      result = await handleStatus(auth);
      break;

    default:
      result = {
        action,
        success: false,
        error: `Unknown action: ${action}. Valid actions: signup, signin, google, anonymous, signout, status`,
      };
  }

  printResult(result);
  process.exit(result.success ? 0 : 1);
}

main().catch((err) => {
  printResult({ action: 'unknown', success: false, error: err.message });
  process.exit(1);
});
