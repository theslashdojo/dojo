---
name: server-actions
description: Mutate data in Next.js with Server Actions — 'use server' functions for forms, revalidation, redirects, and optimistic updates. Use when handling form submissions, creating/updating/deleting data, or building mutation workflows in App Router.
---

# Server Actions

Handle data mutations in Next.js with server-side functions called directly from components.

## When to Use

- Handling form submissions (create, update, delete)
- Mutating database records from the UI
- Processing file uploads
- Running server-side validation
- Triggering cache revalidation after data changes
- Building optimistic UI updates

## Workflow

1. Create an actions file with `'use server'` at the top
2. Define async functions that accept `FormData` or typed arguments
3. Validate inputs (use Zod or manual checks)
4. Perform the mutation (database, API, etc.)
5. Call `revalidatePath()` or `revalidateTag()` to refresh cached data
6. Optionally `redirect()` to a new page
7. Wire up to `<form action={...}>` or call from event handlers

## Basic Pattern

```tsx
// app/actions.ts
'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'

export async function createItem(formData: FormData) {
  const name = formData.get('name') as string

  if (!name || name.length < 2) {
    return { error: 'Name must be at least 2 characters' }
  }

  await db.item.create({ data: { name } })
  revalidatePath('/items')
  redirect('/items')
}
```

```tsx
// app/items/new/page.tsx
import { createItem } from '@/app/actions'

export default function NewItemPage() {
  return (
    <form action={createItem}>
      <input name="name" required />
      <button type="submit">Create</button>
    </form>
  )
}
```

## With Validation (useActionState)

```tsx
// app/actions.ts
'use server'

import { z } from 'zod'

const schema = z.object({
  email: z.string().email(),
  name: z.string().min(2),
})

export async function createUser(
  prevState: { errors?: Record<string, string[]> },
  formData: FormData
) {
  const result = schema.safeParse(Object.fromEntries(formData))

  if (!result.success) {
    return { errors: result.error.flatten().fieldErrors }
  }

  await db.user.create({ data: result.data })
  revalidatePath('/users')
  redirect('/users')
}
```

```tsx
// app/users/new/form.tsx
'use client'

import { useActionState } from 'react'
import { createUser } from '@/app/actions'

export function CreateUserForm() {
  const [state, action, pending] = useActionState(createUser, { errors: {} })

  return (
    <form action={action}>
      <input name="name" />
      {state.errors?.name && <p>{state.errors.name[0]}</p>}
      <input name="email" type="email" />
      {state.errors?.email && <p>{state.errors.email[0]}</p>}
      <button disabled={pending}>
        {pending ? 'Creating...' : 'Create User'}
      </button>
    </form>
  )
}
```

## Non-Form Usage (Event Handlers)

```tsx
'use client'

import { deleteItem } from '@/app/actions'
import { useTransition } from 'react'

export function DeleteButton({ id }: { id: string }) {
  const [isPending, startTransition] = useTransition()

  return (
    <button
      onClick={() => startTransition(() => deleteItem(id))}
      disabled={isPending}
    >
      {isPending ? 'Deleting...' : 'Delete'}
    </button>
  )
}
```

## Edge Cases

- Server Actions always use POST — they cannot be called via GET
- `redirect()` throws internally — don't catch it in try/catch (call it outside the try block)
- `revalidatePath('/')` revalidates only the home page; use `revalidatePath('/', 'layout')` for the entire app
- Server Actions in a `'use server'` file create public HTTP endpoints — always validate auth
- `useActionState` replaces the older `useFormState` (renamed in React 19)
- `useFormStatus` must be used in a child component of the form, not in the same component
- Progressive enhancement: forms work without JS, but `useActionState` requires JS for error display
- TypeScript: the first argument to a `useActionState` action is the previous state, not FormData
