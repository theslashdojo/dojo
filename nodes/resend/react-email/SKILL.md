---
name: react-email
description: Build email templates with React components using @react-email/components — use when creating transactional or marketing email templates for Resend delivery
---

# React Email Templates

Build email templates using React components. React Email provides typed, email-client-compatible components that render to cross-client HTML.

## Prerequisites

- Node.js >= 18
- `npm install @react-email/components react react-dom`
- For dev preview: `npm install -D react-email`

## Workflow

1. **Install packages**: `npm install @react-email/components react react-dom`
2. **Create template**: Write a TSX component using React Email components
3. **Preview locally**: Run `npx react-email dev --dir ./emails`
4. **Integrate with Resend**: Pass component to `resend.emails.send({ react: ... })`

## Creating a Template

```tsx
// emails/welcome.tsx
import {
  Html, Head, Body, Container, Text,
  Button, Preview, Heading, Hr, Section,
} from '@react-email/components';

interface WelcomeEmailProps {
  firstName: string;
  loginUrl: string;
}

export function WelcomeEmail({ firstName, loginUrl }: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Welcome to Acme, {firstName}!</Preview>
      <Body style={{ backgroundColor: '#f6f9fc', fontFamily: 'sans-serif' }}>
        <Container style={{ maxWidth: '600px', margin: '0 auto', padding: '20px' }}>
          <Heading as="h1">Welcome, {firstName}!</Heading>
          <Text>Thanks for signing up. Get started below.</Text>
          <Hr />
          <Section style={{ textAlign: 'center', marginTop: '20px' }}>
            <Button
              href={loginUrl}
              style={{
                backgroundColor: '#000',
                color: '#fff',
                padding: '12px 24px',
                borderRadius: '6px',
              }}
            >
              Get Started
            </Button>
          </Section>
        </Container>
      </Body>
    </Html>
  );
}
```

## Available Components

| Component | Purpose |
|-----------|---------|
| `Html` | Root `<html>` wrapper |
| `Head` | `<head>` with meta tags |
| `Body` | `<body>` wrapper |
| `Container` | Centered max-width wrapper |
| `Section` | Grouping element |
| `Row` / `Column` | Table-based layout |
| `Text` | Paragraph text |
| `Heading` | h1-h6 headings |
| `Button` | CTA link styled as button |
| `Link` | Anchor link |
| `Img` | Image |
| `Hr` | Horizontal rule |
| `Preview` | Inbox preheader text |
| `Tailwind` | Tailwind CSS utility support |
| `CodeBlock` / `CodeInline` | Code formatting |
| `Markdown` | Render markdown content |
| `Font` | Custom web fonts |

## Using Tailwind CSS

Wrap your template in `<Tailwind>` to use utility classes:

```tsx
import { Tailwind, Html, Body, Container, Text, Button } from '@react-email/components';

export function StyledEmail({ name }: { name: string }) {
  return (
    <Tailwind>
      <Html>
        <Body className="bg-gray-100 font-sans">
          <Container className="max-w-xl mx-auto p-6 bg-white rounded-lg">
            <Text className="text-2xl font-bold text-gray-900">Hello, {name}!</Text>
            <Button
              href="https://example.com"
              className="bg-blue-600 text-white px-6 py-3 rounded-md mt-4 inline-block"
            >
              Get Started
            </Button>
          </Container>
        </Body>
      </Html>
    </Tailwind>
  );
}
```

## Sending with Resend

```typescript
import { Resend } from 'resend';
import { WelcomeEmail } from './emails/welcome';

const resend = new Resend(process.env.RESEND_API_KEY);

const { data, error } = await resend.emails.send({
  from: 'Acme <hello@yourdomain.com>',
  to: ['user@example.com'],
  subject: 'Welcome to Acme',
  react: WelcomeEmail({ firstName: 'John', loginUrl: 'https://app.acme.com' }),
});
```

**Critical**: Call components as functions (`WelcomeEmail({ ... })`), NOT as JSX (`<WelcomeEmail />`).

## Rendering to HTML String

For use with non-Node SDKs or caching:

```typescript
import { render } from '@react-email/render';

const html = await render(WelcomeEmail({ firstName: 'John', loginUrl: '...' }));
const text = await render(WelcomeEmail({ firstName: 'John', loginUrl: '...' }), { plainText: true });
```

## Local Dev Server

```json
{
  "scripts": {
    "email:dev": "email dev --dir ./emails --port 3030"
  }
}
```

Run `npm run email:dev` to preview templates with hot reload at `http://localhost:3030`.

## Template Patterns

### Invoice Email

```tsx
export function InvoiceEmail({ amount, items, dueDate }: InvoiceProps) {
  return (
    <Html>
      <Head />
      <Preview>Invoice for ${amount}</Preview>
      <Body style={styles.body}>
        <Container style={styles.container}>
          <Heading>Invoice</Heading>
          <Text>Amount due: ${amount}</Text>
          <Text>Due date: {dueDate}</Text>
          <Hr />
          {items.map((item, i) => (
            <Row key={i}>
              <Column>{item.name}</Column>
              <Column style={{ textAlign: 'right' }}>${item.price}</Column>
            </Row>
          ))}
        </Container>
      </Body>
    </Html>
  );
}
```

### Password Reset

```tsx
export function PasswordResetEmail({ resetUrl, expiresIn }: ResetProps) {
  return (
    <Html>
      <Head />
      <Preview>Reset your password</Preview>
      <Body style={styles.body}>
        <Container style={styles.container}>
          <Heading>Password Reset</Heading>
          <Text>Click below to reset your password. This link expires in {expiresIn}.</Text>
          <Button href={resetUrl} style={styles.button}>Reset Password</Button>
          <Text style={styles.footer}>If you didn't request this, ignore this email.</Text>
        </Container>
      </Body>
    </Html>
  );
}
```

## Edge Cases

- **Inline styles required**: Most email clients strip `<style>` tags; use inline styles or Tailwind component
- **No external CSS**: Don't use CSS imports or stylesheets
- **Image hosting**: Images must be hosted on a public URL (no local paths)
- **Limited CSS**: Flexbox and Grid are poorly supported; use Row/Column for layout
- **Test thoroughly**: Preview in multiple clients (Gmail, Outlook, Apple Mail)
- **Component functions**: Always call as `Template({ props })`, never `<Template />`
- **Default exports**: Export both named and default for compatibility with the dev server
