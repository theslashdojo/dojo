/**
 * Manage Resend sending domains: add, verify, list, get status, delete.
 *
 * Usage:
 *   RESEND_API_KEY=re_xxx npx tsx manage-domains.ts <action> [args]
 *
 * Actions:
 *   create <domain-name>     Add a new sending domain
 *   verify <domain-id>       Trigger DNS verification
 *   get    <domain-id>       Check domain status and records
 *   list                     List all domains
 *   delete <domain-id>       Remove a domain
 *
 * Environment:
 *   RESEND_API_KEY — required, Resend API key with full_access permission
 *
 * Examples:
 *   npx tsx manage-domains.ts create send.myapp.com
 *   npx tsx manage-domains.ts verify d91cd9bd-1176-453e-8fc1-35364d380206
 *   npx tsx manage-domains.ts list
 */

import { Resend } from "resend";

async function main() {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.error("Error: RESEND_API_KEY environment variable is required");
    process.exit(1);
  }

  const resend = new Resend(apiKey);
  const [action, arg] = process.argv.slice(2);

  if (!action) {
    console.error("Usage: manage-domains.ts <create|verify|get|list|delete> [args]");
    process.exit(1);
  }

  switch (action) {
    case "create": {
      if (!arg) {
        console.error("Usage: manage-domains.ts create <domain-name>");
        process.exit(1);
      }
      const { data, error } = await resend.domains.create({ name: arg });
      if (error) {
        console.error("Failed to create domain:", JSON.stringify(error, null, 2));
        process.exit(1);
      }
      console.log("Domain created successfully:");
      console.log(JSON.stringify(data, null, 2));
      console.log("\nAdd these DNS records to your DNS provider:");
      if (data && "records" in data) {
        for (const record of (data as any).records) {
          console.log(`  ${record.type}\t${record.name}\t${record.value}`);
        }
      }
      break;
    }

    case "verify": {
      if (!arg) {
        console.error("Usage: manage-domains.ts verify <domain-id>");
        process.exit(1);
      }
      const { data, error } = await resend.domains.verify(arg);
      if (error) {
        console.error("Failed to verify domain:", JSON.stringify(error, null, 2));
        process.exit(1);
      }
      console.log("Verification triggered:", JSON.stringify(data, null, 2));
      break;
    }

    case "get": {
      if (!arg) {
        console.error("Usage: manage-domains.ts get <domain-id>");
        process.exit(1);
      }
      const { data, error } = await resend.domains.get(arg);
      if (error) {
        console.error("Failed to get domain:", JSON.stringify(error, null, 2));
        process.exit(1);
      }
      console.log(JSON.stringify(data, null, 2));
      break;
    }

    case "list": {
      const { data, error } = await resend.domains.list();
      if (error) {
        console.error("Failed to list domains:", JSON.stringify(error, null, 2));
        process.exit(1);
      }
      console.log(JSON.stringify(data, null, 2));
      break;
    }

    case "delete": {
      if (!arg) {
        console.error("Usage: manage-domains.ts delete <domain-id>");
        process.exit(1);
      }
      const { data, error } = await resend.domains.remove(arg);
      if (error) {
        console.error("Failed to delete domain:", JSON.stringify(error, null, 2));
        process.exit(1);
      }
      console.log("Domain deleted:", JSON.stringify(data, null, 2));
      break;
    }

    default:
      console.error(`Unknown action: ${action}. Use create, verify, get, list, or delete.`);
      process.exit(1);
  }
}

main().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
