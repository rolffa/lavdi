import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";
const inviteFrom =
  Deno.env.get("INVITE_FROM_EMAIL") ?? "Lávdi <noreply@lavdi.no>";
const publicSiteUrl =
  (Deno.env.get("PUBLIC_SITE_URL") ?? "https://www.lavdi.no").replace(/\/$/, "");

type InviteRow = {
  email: string;
  rolle: string;
  accepted_at: string | null;
  bands: { navn: string } | { navn: string }[] | null;
};

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

function bandNameFrom(row: InviteRow): string {
  const bands = row.bands;
  if (Array.isArray(bands)) return bands[0]?.navn?.trim() || "bandet";
  return bands?.navn?.trim() || "bandet";
}

function inviteBody(bandName: string, link: string): { text: string; html: string } {
  const text =
    `Hei!\n` +
    `Du er invitert til å være med i ${bandName} på lavdi.no. ` +
    `Trykk på linken under for å lage deg en bruker.\n\n` +
    `${link}\n\n` +
    `Med vennlig hilsen\n` +
    `Admin, Lávdi`;

  const html =
    `<p>Hei!</p>` +
    `<p>Du er invitert til å være med i <strong>${escapeHtml(bandName)}</strong> på lavdi.no. ` +
    `Trykk på linken under for å lage deg en bruker.</p>` +
    `<p><a href="${escapeHtml(link)}">${escapeHtml(link)}</a></p>` +
    `<p>Med vennlig hilsen<br>Admin, Lávdi</p>`;

  return { text, html };
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  if (request.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }
  if (!supabaseUrl || !serviceRoleKey) {
    return json(503, { error: "Supabase er ikke satt opp." });
  }
  if (!resendApiKey) {
    return json(503, {
      error:
        "RESEND_API_KEY mangler. Sett secret på Edge Function send-invite-email.",
    });
  }

  let token = "";
  try {
    const body = await request.json();
    token = typeof body?.token === "string" ? body.token.trim() : "";
  } catch {
    return json(400, { error: "Ugyldig forespørsel." });
  }
  if (!token) {
    return json(400, { error: "Invitasjonstoken mangler." });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data: invite, error: inviteError } = await supabase
    .from("band_invites")
    .select("email, rolle, accepted_at, bands(navn)")
    .eq("token", token)
    .maybeSingle();

  if (inviteError) {
    return json(500, { error: inviteError.message });
  }
  if (!invite) {
    return json(404, { error: "Invitasjonen finnes ikke." });
  }

  const row = invite as InviteRow;
  if (row.accepted_at != null) {
    return json(400, { error: "Invitasjonen er allerede brukt." });
  }

  const email = (row.email ?? "").trim().toLowerCase();
  if (!email.includes("@")) {
    return json(400, { error: "Invitasjonen mangler e-post." });
  }

  const bandName = bandNameFrom(row);
  const redirectTo = `${publicSiteUrl}/min-side/invitasjon/${token}`;

  const { data: linkData, error: linkError } = await supabase.auth.admin
    .generateLink({
      type: "magiclink",
      email,
      options: { redirectTo },
    });

  if (linkError || !linkData?.properties?.action_link) {
    return json(500, {
      error: linkError?.message ?? "Kunne ikke lage innloggingslenke.",
    });
  }

  const actionLink = linkData.properties.action_link as string;
  const { text, html } = inviteBody(bandName, actionLink);

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: inviteFrom,
      to: [email],
      subject: `Invitasjon til ${bandName} på Lávdi`,
      text,
      html,
    }),
  });

  const resendJson = await resendResponse.json().catch(() => ({}));
  if (!resendResponse.ok) {
    const message =
      (resendJson as { message?: string }).message ??
      `Resend feilet (${resendResponse.status})`;
    return json(502, { error: message });
  }

  try {
    await supabase.from("mail_outbox").insert({
      to_email: email,
      subject: `Invitasjon til ${bandName} på Lávdi`,
      body: text,
      url: redirectTo,
      dedupe_key: `invite:${token}:${Date.now()}`,
    });
  } catch {
    // ignore
  }

  return json(200, { ok: true, email, band: bandName });
});
