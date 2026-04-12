---
name: classes
description: Apply Tailwind CSS utility classes to build UI components. Use when adding styles to HTML/JSX, fixing layouts, centering elements, or translating designs into Tailwind markup.
---

# Tailwind Utility Classes

Build any UI by composing single-purpose utility classes directly in markup.

## When to Use

- Styling HTML or JSX elements with Tailwind
- Building a new component (card, navbar, form, hero, modal)
- Fixing layout issues (centering, spacing, overflow)
- Adding hover/focus/active states to interactive elements
- Making a design responsive across screen sizes
- Adding dark mode support to components

## Workflow

1. Identify the visual requirement (layout, spacing, typography, color, effect)
2. Apply the appropriate utility class(es) to the element
3. Add state variants as needed: `hover:`, `focus:`, `active:`, `disabled:`
4. Add responsive variants: `md:`, `lg:` for different screen sizes
5. Add `dark:` variants for dark mode support
6. Test in browser — classes generate CSS on build

## Quick Reference

### Layout
```
flex items-center justify-between gap-4     → horizontal row, centered, spaced
flex flex-col gap-2                          → vertical stack
grid grid-cols-3 gap-6                       → 3-column grid
hidden md:block                              → hide on mobile, show on md+
relative / absolute top-0 right-0            → positioned elements
```

### Spacing
```
p-4      → 1rem padding all sides
px-6     → 1.5rem horizontal padding
py-2     → 0.5rem vertical padding
m-4      → 1rem margin all sides
mx-auto  → center horizontally
mt-8     → 2rem top margin
gap-4    → 1rem gap in flex/grid
space-y-2 → 0.5rem between children
```

### Sizing
```
w-full max-w-md    → full width, max 28rem
h-screen           → 100vh
size-12            → 3rem width and height
min-h-0            → allow shrinking
```

### Typography
```
text-sm / text-base / text-lg / text-xl    → font size
font-medium / font-semibold / font-bold    → font weight
text-gray-900 dark:text-white              → text color
tracking-tight / leading-relaxed           → letter/line spacing
truncate / line-clamp-3                    → text overflow
```

### Colors
```
bg-white dark:bg-gray-900                  → background
text-gray-600 dark:text-gray-400           → text
border-gray-200 dark:border-gray-700       → border
bg-indigo-600 hover:bg-indigo-700          → interactive
bg-black/50                                → 50% opacity
```

### Effects
```
rounded-lg / rounded-full                  → border radius
shadow-sm / shadow-md / shadow-lg          → box shadow
ring-2 ring-blue-500                       → outline ring
opacity-50                                 → transparency
blur-sm / backdrop-blur-md                 → blur effects
transition-colors duration-200             → smooth transitions
```

### Interactive States
```
hover:bg-blue-700              → mouse hover
focus:ring-2 focus:ring-blue-500 → keyboard focus
active:bg-blue-800             → mouse down
disabled:opacity-50            → disabled state
group-hover:underline          → child reacts to parent hover
peer-invalid:text-red-500      → sibling reacts to input state
```

## Common Patterns

### Centered Container
```html
<div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
  Content
</div>
```

### Card
```html
<div class="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
  <h3 class="text-lg font-semibold text-gray-900">Title</h3>
  <p class="mt-2 text-sm text-gray-600">Description</p>
</div>
```

### Button
```html
<button class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
  Click me
</button>
```

### Responsive Grid
```html
<div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
  <!-- Cards -->
</div>
```

## Edge Cases

- **Dynamic classes don't work**: `bg-${color}-500` fails — Tailwind scans statically. Use complete strings: `bg-red-500`
- **Class conflicts**: Later classes in the stylesheet win. Only include the one you want. Use `!` suffix to force: `bg-red-500!`
- **Custom values**: Use brackets for one-off values: `w-[calc(100%-2rem)]`, `bg-[#1a1a2e]`
- **Important override**: Append `!` to force priority: `bg-red-500!`
- **Prefix collisions**: Use `@import "tailwindcss" prefix(tw)` to namespace all classes as `tw:text-red-500`
