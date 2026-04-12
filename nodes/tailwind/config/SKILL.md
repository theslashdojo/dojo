---
name: config
description: Install and configure Tailwind CSS in any project. Use when setting up Tailwind, customizing theme tokens, debugging missing classes, or migrating between build tools.
---

# Tailwind CSS Configuration

Set up Tailwind CSS and customize the design system for your project.

## When to Use

- Adding Tailwind to a new or existing project
- Customizing colors, fonts, spacing, or breakpoints
- Debugging classes that aren't generating CSS
- Switching between Vite and PostCSS build tools
- Adding or configuring Tailwind plugins
- Migrating from v3 to v4

## Workflow

1. Detect project type (Vite, Next.js, PostCSS, static HTML)
2. Install appropriate packages
3. Configure build tool (Vite plugin or PostCSS plugin)
4. Create CSS entry point with `@import "tailwindcss"`
5. Add theme customizations if needed
6. Verify classes generate by adding a test class and checking output

## v4 Setup (Recommended)

### Vite Projects
```bash
npm install tailwindcss @tailwindcss/vite
```

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [tailwindcss()],
});
```

```css
/* src/app.css */
@import "tailwindcss";
```

### PostCSS Projects (Next.js, etc.)
```bash
npm install tailwindcss @tailwindcss/postcss
```

```javascript
// postcss.config.mjs
export default {
  plugins: ["@tailwindcss/postcss"],
};
```

```css
/* src/app.css */
@import "tailwindcss";
```

### Theme Customization
```css
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.6 0.2 260);
  --color-brand-light: oklch(0.8 0.15 260);
  --font-display: "Cal Sans", sans-serif;
  --breakpoint-3xl: 120rem;
}
```

## v3 Setup (Legacy)

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

```javascript
// tailwind.config.js
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx,html}"],
  theme: {
    extend: {
      colors: { brand: "#4f46e5" },
    },
  },
  plugins: [],
};
```

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

## Debugging Checklist

If Tailwind classes aren't generating CSS:

1. Is the CSS file imported in your app entry point?
2. Is the build tool configured? (Vite plugin or PostCSS plugin)
3. v3: Do content paths match your source files?
4. v4: Is the file in a gitignored directory? Use `@source` to include it
5. Are you constructing class names dynamically? Use complete strings only
6. Is the dev server running?

## Edge Cases

- **Monorepos**: Use `@source "../packages/ui/src"` to scan sibling packages
- **CMS content**: Classes in database content can't be scanned — use safelisting or a safelist comment
- **CSS modules**: Use `@reference "tailwindcss"` in scoped `<style>` blocks instead of `@import`
- **Multiple CSS entries**: Each `@import "tailwindcss"` generates a full copy — use one entry point
