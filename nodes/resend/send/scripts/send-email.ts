/**
 * Send a transactional email via the Resend API.
 *
 * Usage:
 *   RESEND_API_KEY=re_xxx npx tsx send-email.ts
 *
 * Environment:
 *   RESEND_API_KEY  — required, your Resend API key
 *
 * Stdin (JSON):
 *   { "from": "Acme <hello@yourdomain.com>", "to": ["user@example.com"], "subject": "Hello", "html": "<p>Hi</p>" }
 *
 * Or pass individual env vars:
 *   EMAIL_FROM, EMAIL_TO (comma-separated), EMAIL_SUBJECT, EMAIL_HTML
 */

import { Resend } from "resend";

interface SendInput {
  from: string;
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  cc?: string | string[];
  bcc?: string | string[];
  replyTo?: string | string[];
  tags?: { name: string; value: string }[];
  scheduledAt?: string;
  idempotencyKey?: string;
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

async function main() {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.error("Error: RESEND_API_KEY environment variable is required");
    process.exit(1);
  }

  const resend = new Resend(apiKey);

  let input: SendInput;

  // Try reading from stdin first, fall back to env vars
  if (!process.stdin.isTTY) {
    const raw = await readStdin();
    if (raw.trim()) {
      input = JSON.parse(raw);
    } else {
      input = buildFromEnv();
    }
  } else {
    input = buildFromEnv();
  }

  // Validate required fields
  if (!input.from || !input.to || !input.subject) {
    console.error("Error: 'from', 'to', and 'subject' are required");
    process.exit(1);
  }

  if (!input.html && !input.text) {
    console.error("Error: at least one of 'html' or 'text' is required");
    process.exit(1);
  }

  const { data, error } = await resend.emails.send({
    from: input.from,
    to: Array.isArray(input.to) ? input.to : [input.to],
    subject: input.subject,
    html: input.html,
    text: input.text,
    cc: input.cc,
    bcc: input.bcc,
    replyTo: input.replyTo,
    tags: input.tags,
    scheduledAt: input.scheduledAt,
  });

  if (error) {
    console.error("Send failed:", JSON.stringify(error, null, 2));
    process.exit(1);
  }

  console.log(JSON.stringify(data, null, 2));
}

function buildFromEnv(): SendInput {
  const from = process.env.EMAIL_FROM || "";
  const toRaw = process.env.EMAIL_TO || "";
  const to = toRaw.includes(",") ? toRaw.split(",").map((s) => s.trim()) : toRaw;
  const subject = process.env.EMAIL_SUBJECT || "";
  const html = process.env.EMAIL_HTML;
  const text = process.env.EMAIL_TEXT;

  return { from, to, subject, html, text };
}

main().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
