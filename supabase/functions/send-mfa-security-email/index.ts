import { clarityBrandedEmailHtml } from "../_shared/clarity-email.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type MfaSecurityEvent = "mfa_enabled" | "mfa_disabled";

function jsonResponse(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function eventCopy(event: MfaSecurityEvent) {
  if (event === "mfa_enabled") {
    return {
      subject: "MFA was turned on for your Clarity account",
      preview:
        "Multi-factor authentication is now protecting your Clarity account.",
      body:
        "Multi-factor authentication was turned on for your Clarity account. Future sign-ins will ask for your authenticator app code after your password.",
    };
  }

  return {
    subject: "MFA was turned off for your Clarity account",
    preview:
      "Multi-factor authentication is no longer required for your Clarity account.",
    body:
      "Multi-factor authentication was turned off for your Clarity account. Future sign-ins will only require your password unless you turn MFA back on.",
  };
}

async function currentUserEmail(authHeader: string): Promise<string | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) return null;

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: authHeader,
      apikey: supabaseAnonKey,
    },
  });
  if (!response.ok) return null;

  const data = await response.json();
  return typeof data.email === "string" && data.email.trim().length > 0
    ? data.email.trim()
    : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonResponse({ error: "Missing Supabase auth token" }, 401);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const event = payload.event;
  if (event !== "mfa_enabled" && event !== "mfa_disabled") {
    return jsonResponse({ error: "Unsupported MFA security event" }, 400);
  }

  const email = await currentUserEmail(authHeader);
  if (!email) {
    return jsonResponse({ error: "Could not resolve authenticated user" }, 401);
  }

  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("SECURITY_EMAIL_FROM") ??
    "Clarity Security <security@goclarity.app>";
  if (!resendApiKey) {
    return jsonResponse({ error: "Missing RESEND_API_KEY secret" }, 503);
  }

  const copy = eventCopy(event);
  const sentAt = new Date().toUTCString();
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: email,
      subject: copy.subject,
      text:
        `${copy.body}\n\nIf this was you, no action is needed.\n\nIf this was not you, change your password and contact support immediately.\n\nTime: ${sentAt}`,
      html: clarityBrandedEmailHtml({
        eyebrow: "Account security",
        title: event === "mfa_enabled" ? "MFA is on" : "MFA is off",
        preview: copy.preview,
        bodyHtml: `
          <p style="margin:0 0 16px;color:#667085;font-size:16px;line-height:1.65;">${copy.body}</p>
          <p style="margin:0 0 12px;color:#667085;font-size:16px;line-height:1.65;">If this was you, no action is needed.</p>
          <p style="margin:0;color:#344054;font-size:16px;line-height:1.65;"><strong>If this was not you, change your password and contact support immediately.</strong></p>
          <p style="margin:16px 0 0;color:#667085;font-size:13px;line-height:1.55;">Time: ${sentAt}</p>
        `,
        ctaLabel: "",
        footerNote:
          "This notice was sent because multi-factor authentication changed on your Clarity account.",
      }),
    }),
  });

  if (!response.ok) {
    let details: unknown = null;
    try {
      details = await response.json();
    } catch {
      details = await response.text();
    }
    return jsonResponse(
      { error: "Email provider rejected request", details },
      502,
    );
  }

  return jsonResponse({ ok: true }, 200);
});
