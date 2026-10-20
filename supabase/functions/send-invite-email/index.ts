/**
 * Valgfri edge-funksjon for invitasjonsmail.
 * Appen bruker i praksis Supabase Auth signInWithOtp (standardmal) direkte.
 * Denne funksjonen gjør det samme via service role hvis den kalles.
 */
import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const publicSiteUrl =
  (Deno.env.get("PUBLIC_SITE_URL") ?? "https://www.lavdi.no").replace(/\/$/, "");

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }
  if (!supabaseUrl || !serviceRoleKey) {
    return json(503, { error: "Supabase mangler" });
  }

  const body = await req.json().catch(() => ({}));
  const token = typeof body?.token === "string" ? body.token.trim() : "";
  if (!token) return json(400, { error: "Token mangler" });

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data: invite, error } = await supabase
    .from("band_invites")
    .select("email, accepted_at")
    .eq("token", token)
    .maybeSingle();

  if (error) return json(500, { error: error.message });
  if (!invite) return json(404, { error: "Invitasjonen finnes ikke" });
  if (invite.accepted_at != null) {
    return json(400, { error: "Allerede brukt" });
  }

  const email = (invite.email ?? "").trim().toLowerCase();
  if (!email.includes("@")) {
    return json(400, { error: "Mangler e-post" });
  }

  const redirectTo = `${publicSiteUrl}/min-side/invitasjon/${token}`;
  const { error: otpError } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: redirectTo,
      shouldCreateUser: true,
    },
  });
  if (otpError) return json(500, { error: otpError.message });

  return json(200, { ok: true, email, via: "supabase_auth" });
});
