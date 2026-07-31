const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function resolveAuthenticatedUser(authHeader: string): Promise<{
  id: string;
  email: string | null;
} | null> {
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
  const id = typeof data.id === "string" ? data.id.trim() : "";
  if (!id) return null;
  const email =
    typeof data.email === "string" && data.email.trim().length > 0
      ? data.email.trim()
      : null;
  return { id, email };
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

  const user = await resolveAuthenticatedUser(authHeader);
  if (!user) {
    return jsonResponse({ error: "Could not resolve authenticated user" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Account deletion is not configured" }, 503);
  }

  const deleteResponse = await fetch(
    `${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(user.id)}`,
    {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
        apikey: serviceRoleKey,
      },
    },
  );

  if (!deleteResponse.ok) {
    let details: unknown = null;
    try {
      details = await deleteResponse.json();
    } catch {
      details = await deleteResponse.text();
    }
    return jsonResponse(
      { error: "Could not delete account", details },
      deleteResponse.status >= 400 && deleteResponse.status < 600
        ? deleteResponse.status
        : 502,
    );
  }

  return jsonResponse({ ok: true, deleted_user_id: user.id }, 200);
});
