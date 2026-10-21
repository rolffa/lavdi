/**
 * Sender køede rader i public.mail_outbox via Resend.
 * Secrets: RESEND_API_KEY, MAIL_FROM (valgfri), MAIL_DISPATCH_SECRET
 */
import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";
const mailFrom =
  Deno.env.get("MAIL_FROM") ??
  Deno.env.get("INVITE_FROM_EMAIL") ??
  "Lávdi Booking <noreply@lavdi.no>";
const dispatchSecret = Deno.env.get("MAIL_DISPATCH_SECRET") ?? "";

type OutboxRow = {
  id: string;
  to_email: string;
  subject: string;
  body: string;
  url: string;
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }
  if (dispatchSecret && req.headers.get("x-mail-secret") !== dispatchSecret) {
    return json(401, { error: "Unauthorized" });
  }
  if (!supabaseUrl || !serviceRoleKey) {
    return json(503, { error: "Supabase mangler" });
  }
  if (!resendApiKey) {
    return json(503, { error: "RESEND_API_KEY mangler" });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data, error } = await supabase
    .from("mail_outbox")
    .select("id, to_email, subject, body, url")
    .is("sent_at", null)
    .order("created_at", { ascending: true })
    .limit(50);

  if (error) return json(500, { error: error.message });

  let sent = 0;
  const failures: string[] = [];

  for (const row of (data ?? []) as OutboxRow[]) {
    const text = row.url.trim()
      ? `${row.body}\n\n${row.url}`
      : row.body;
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: mailFrom,
        to: [row.to_email],
        subject: row.subject,
        text,
      }),
    });
    if (!resendResponse.ok) {
      const detail = await resendResponse.text().catch(() => "");
      failures.push(`${row.id}:${resendResponse.status}:${detail}`);
      continue;
    }
    const { error: updateError } = await supabase
      .from("mail_outbox")
      .update({ sent_at: new Date().toISOString() })
      .eq("id", row.id);
    if (updateError) {
      failures.push(`${row.id}:update:${updateError.message}`);
      continue;
    }
    sent += 1;
  }

  return json(200, { ok: true, sent, failures });
});
