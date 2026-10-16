import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const publicKey = Deno.env.get("VAPID_PUBLIC_KEY") ?? "";
const privateKey = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
const subject = Deno.env.get("VAPID_SUBJECT") ?? "mailto:booking@amundsen.studio";
const dispatchSecret = Deno.env.get("PUSH_DISPATCH_SECRET") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

type OutboxRow = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  url: string;
};

type SubscriptionRow = {
  id: string;
  endpoint: string;
  p256dh: string;
  auth: string;
};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!dispatchSecret || request.headers.get("x-push-secret") !== dispatchSecret) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (!publicKey || !privateKey || !supabaseUrl || !serviceRoleKey) {
    return new Response("Push er ikke satt opp.", { status: 503 });
  }

  webpush.setVapidDetails(subject, publicKey, privateKey);
  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data, error } = await supabase
    .from("push_outbox")
    .select("id, user_id, title, body, url")
    .is("sent_at", null)
    .order("created_at", { ascending: true })
    .limit(50);

  if (error) {
    return new Response(error.message, { status: 500 });
  }

  let sent = 0;
  for (const row of (data ?? []) as OutboxRow[]) {
    const { data: subscriptions, error: subscriptionError } = await supabase
      .from("user_push_subscriptions")
      .select("id, endpoint, p256dh, auth")
      .eq("user_id", row.user_id);

    if (subscriptionError) continue;

    const devices = (subscriptions ?? []) as SubscriptionRow[];
    let delivered = devices.length === 0;
    for (const device of devices) {
      try {
        await webpush.sendNotification(
          {
            endpoint: device.endpoint,
            keys: { p256dh: device.p256dh, auth: device.auth },
          },
          JSON.stringify({ title: row.title, body: row.body, url: row.url }),
        );
        delivered = true;
      } catch (pushError) {
        const status = (pushError as { statusCode?: number }).statusCode;
        if (status === 404 || status === 410) {
          await supabase.from("user_push_subscriptions").delete().eq("id", device.id);
        }
      }
    }

    if (delivered) {
      const { error: updateError } = await supabase
        .from("push_outbox")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", row.id);
      if (!updateError) sent += 1;
    }
  }

  return Response.json({ sent });
});
