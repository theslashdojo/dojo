---
name: hosting
description: >
  Deploy static sites and single-page applications to Firebase Hosting. Use when serving
  static assets via global CDN with automatic SSL, when setting up preview channels for
  staging, when configuring rewrites to Cloud Functions or Cloud Run for dynamic content,
  or when managing custom domains and multi-site hosting.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: firebase-hosting
---

# Firebase Hosting

Deploy static sites and SPAs to a global CDN with automatic SSL, preview channels, and rewrites to Cloud Functions or Cloud Run.

## When to Use

- Deploying a static site or SPA (React, Vue, Angular, Svelte, etc.)
- Need global CDN distribution with automatic SSL
- Want preview channels for staging/testing before production
- Need rewrites to Cloud Functions or Cloud Run for dynamic API routes
- Hosting multiple sites in one Firebase project (deploy targets)
- Want GitHub Actions CI/CD for automatic deploys on push/PR

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Authenticated: `firebase login` (interactive) or `GOOGLE_APPLICATION_CREDENTIALS` / `FIREBASE_TOKEN` for CI
- Firebase project created: `firebase projects:create PROJECT_ID`
- Build output directory ready (e.g., `dist`, `build`, `public`)

## Workflow

### 1. Initialize Hosting

```bash
firebase init hosting
```

Select or create a project, set the public directory (e.g., `dist`), and choose whether to configure as a single-page app (adds the catch-all rewrite to `index.html`).

### 2. Configure firebase.json

```json
{
  "hosting": {
    "public": "dist",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "cleanUrls": true,
    "trailingSlash": false,
    "rewrites": [
      { "source": "/api/**", "function": "api" },
      { "source": "**", "destination": "/index.html" }
    ],
    "redirects": [
      { "source": "/old-page", "destination": "/new-page", "type": 301 }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
        ]
      }
    ]
  }
}
```

### 3. Deploy to Production

```bash
# Build your app first
npm run build

# Deploy hosting only
firebase deploy --only hosting
```

## Preview Channels Workflow

Preview channels let you test changes at a temporary URL before going live:

```bash
# Deploy to a preview channel
firebase hosting:channel:deploy staging

# Deploy with custom expiration (default 7 days)
firebase hosting:channel:deploy pr-42 --expires 3d

# List active channels
firebase hosting:channel:list

# Delete a channel when done
firebase hosting:channel:delete staging
```

Preview URL format: `https://PROJECT_ID--CHANNEL_ID-RANDOM.web.app`

For GitHub Actions, the official Firebase action auto-creates preview channels on PRs and comments the URL:

```yaml
- uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    repoToken: ${{ secrets.GITHUB_TOKEN }}
    firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
    projectId: my-project-id
    # Omit channelId for PR previews; set channelId: live for production
```

## Rewrites to Cloud Functions

Route API requests to Cloud Functions while serving static content from the CDN:

```json
{
  "rewrites": [
    { "source": "/api/**", "function": "api" },
    { "source": "/users/**", "function": "userService" }
  ]
}
```

The function name must match an exported HTTP function in your Cloud Functions code.

## Rewrites to Cloud Run

Route requests to a Cloud Run service:

```json
{
  "rewrites": [
    {
      "source": "/app/**",
      "run": {
        "serviceId": "my-service",
        "region": "us-central1"
      }
    }
  ]
}
```

## Custom Domains

1. Go to Firebase Console > Hosting > Add custom domain
2. Verify domain ownership with a DNS TXT record
3. Add A records pointing to Firebase IPs or a CNAME for subdomains
4. SSL certificate is auto-provisioned (typically under 24 hours)

Multiple custom domains can point to the same hosting site.

## Multi-Site Hosting (Deploy Targets)

Host multiple sites in one Firebase project:

```bash
# Register deploy targets
firebase target:apply hosting app my-app-site
firebase target:apply hosting blog my-blog-site

# Deploy a specific target
firebase deploy --only hosting:app
```

```json
{
  "hosting": [
    {
      "target": "app",
      "public": "app/dist",
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    },
    {
      "target": "blog",
      "public": "blog/dist"
    }
  ]
}
```

## Rollback

```bash
# Roll back to the previous release
firebase hosting:rollback

# Roll back a specific site
firebase hosting:rollback --site my-site
```

## Critical Rules

- **Set the correct `public` directory** — must match your build output (`dist`, `build`, `out`, etc.). Deploying the wrong directory is the most common mistake.
- **Use `cleanUrls: true`** — drops `.html` extensions from URLs for cleaner paths (`/about` instead of `/about.html`).
- **Cache static assets aggressively** — use `max-age=31536000, immutable` for hashed JS/CSS bundles. Firebase CDN serves cached content from edge locations worldwide.
- **Keep the SPA catch-all rewrite last** — rewrites are evaluated in order, first match wins. Put specific rewrites (`/api/**`) before the catch-all (`**`).
- **Build before deploying** — `firebase deploy` uploads files from the public directory as-is; it does not run your build step.

## Edge Cases

- **SPA client-side routing**: Add `{ "source": "**", "destination": "/index.html" }` as the last rewrite rule so all unmatched routes serve the app shell for client-side routing.
- **Maximum file size**: Individual files cannot exceed 2GB.
- **Release retention**: Firebase retains up to 10 previous releases per hosting site. Older releases are automatically deleted and cannot be rolled back to.
- **Static files take precedence**: If a file exists in the public directory matching a URL, it is served directly — rewrites only apply when no static file matches.
- **Preview channel limits**: Channels expire after 7 days by default (configurable up to 30 days). Expired channels are automatically cleaned up.
- **Deploy target persistence**: Deploy targets are stored in `.firebaserc`, not `firebase.json`. Ensure `.firebaserc` is committed to version control for multi-site projects.
