/**
 * Linear webhook handler with signature verification.
 *
 * Environment variables:
 *   LINEAR_WEBHOOK_SECRET - Required. Webhook signing secret from Linear.
 *   PORT                  - Optional. Server port (default: 3000).
 *
 * Usage:
 *   npm install express @types/express
 *   npx tsx webhook-handler.ts
 *
 * The server listens for POST requests at /webhooks/linear.
 * Verifies HMAC-SHA256 signatures, checks timestamp freshness,
 * and logs events to stdout.
 */

import express, { Request, Response } from "express";
import { createHmac, timingSafeEqual } from "crypto";

const WEBHOOK_SECRET = process.env.LINEAR_WEBHOOK_SECRET;
if (!WEBHOOK_SECRET) {
  console.error("Error: LINEAR_WEBHOOK_SECRET environment variable is required.");
  console.error("Get it from Linear → Settings → API → Webhooks → your webhook's signing secret.");
  process.exit(1);
}

const PORT = parseInt(process.env.PORT || "3000", 10);
const MAX_AGE_MS = 60_000; // Reject payloads older than 60 seconds

const app = express();

// Use raw body for HMAC verification
app.post(
  "/webhooks/linear",
  express.raw({ type: "application/json" }),
  (req: Request, res: Response) => {
    const signature = req.headers["linear-signature"] as string | undefined;
    const deliveryId = req.headers["linear-delivery"] as string | undefined;
    const eventType = req.headers["linear-event"] as string | undefined;

    if (!signature) {
      console.warn("Rejected: missing Linear-Signature header");
      res.status(401).send("Missing signature");
      return;
    }

    const body = req.body.toString();

    // Step 1: Verify HMAC-SHA256 signature
    const hmac = createHmac("sha256", WEBHOOK_SECRET);
    hmac.update(body);
    const expectedDigest = hmac.digest("hex");

    const sigBuffer = Buffer.from(signature, "utf8");
    const digestBuffer = Buffer.from(expectedDigest, "utf8");

    if (sigBuffer.length !== digestBuffer.length || !timingSafeEqual(sigBuffer, digestBuffer)) {
      console.warn(`Rejected: invalid signature (delivery: ${deliveryId})`);
      res.status(401).send("Invalid signature");
      return;
    }

    // Step 2: Parse payload and verify timestamp
    let payload: {
      action: string;
      type: string;
      data: Record<string, unknown>;
      actor?: { id: string; name: string; type: string };
      webhookTimestamp: number;
      updatedFrom?: Record<string, unknown> | null;
      createdAt: string;
    };

    try {
      payload = JSON.parse(body);
    } catch {
      console.warn(`Rejected: invalid JSON (delivery: ${deliveryId})`);
      res.status(400).send("Invalid JSON");
      return;
    }

    const age = Date.now() - payload.webhookTimestamp;
    if (age > MAX_AGE_MS) {
      console.warn(`Rejected: stale payload (${age}ms old, delivery: ${deliveryId})`);
      res.status(401).send("Stale webhook");
      return;
    }

    // Step 3: Process the event
    const { action, type, data, actor, updatedFrom } = payload;
    const entityId = (data.identifier as string) || (data.id as string) || "unknown";
    const actorName = actor?.name || "system";

    console.log(`[${new Date().toISOString()}] ${type} ${action} — ${entityId} (by ${actorName})`);

    switch (type) {
      case "Issue": {
        if (action === "create") {
          console.log(`  New issue: ${data.title}`);
          console.log(`  Priority: ${data.priority}, Team: ${(data.team as Record<string, string>)?.key}`);
        } else if (action === "update") {
          if (updatedFrom) {
            const changedFields = Object.keys(updatedFrom);
            console.log(`  Updated fields: ${changedFields.join(", ")}`);
            if (updatedFrom.stateId) {
              console.log(`  State changed to: ${(data.state as Record<string, string>)?.name}`);
            }
          }
        } else if (action === "remove") {
          console.log(`  Issue removed: ${data.title}`);
        }
        break;
      }

      case "Comment": {
        if (action === "create") {
          const issueRef = (data.issue as Record<string, string>)?.identifier || "unknown";
          console.log(`  New comment on ${issueRef}`);
        }
        break;
      }

      case "Project": {
        console.log(`  Project: ${data.name} — state: ${data.state}`);
        break;
      }

      case "ProjectUpdate": {
        console.log(`  Project update — health: ${data.health}`);
        break;
      }

      default:
        console.log(`  ${type} event (no specific handler)`);
    }

    // Always respond 200 quickly
    res.status(200).send("OK");
  }
);

// Health check
app.get("/health", (_req: Request, res: Response) => {
  res.json({ status: "ok", service: "linear-webhook-handler" });
});

app.listen(PORT, () => {
  console.log(`Linear webhook handler listening on port ${PORT}`);
  console.log(`Endpoint: POST http://localhost:${PORT}/webhooks/linear`);
  console.log(`Health:   GET  http://localhost:${PORT}/health`);
});
