import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * Refreshes the Supabase auth session on every request and gates `/admin`.
 * The admin role lives in `public.users.role` (see
 * 0005_roles_and_email_auth.sql), not JWT user_metadata — a DB lookup, not
 * just a token claim — so a demoted admin loses access on their very next
 * request rather than whenever their JWT happens to refresh.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // getUser()/the role lookup talk to Supabase over the network — if the
  // project is unreachable (misconfigured .env.local, an outage), fail
  // closed (treat as "not admin") rather than letting the error escape
  // middleware. Errors thrown here happen outside React's render tree, so
  // app/error.tsx can't catch them; a page-level Supabase failure below is
  // a normal render error and is caught there instead.
  let isAdmin = false;
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: profile } = await supabase.from("users").select("role").eq("id", user.id).single();
      isAdmin = profile?.role === "admin";
    }
  } catch {
    isAdmin = false;
  }

  if (request.nextUrl.pathname.startsWith("/admin") && request.nextUrl.pathname !== "/admin/login") {
    if (!isAdmin) {
      const redirectUrl = request.nextUrl.clone();
      redirectUrl.pathname = "/admin/login";
      return NextResponse.redirect(redirectUrl);
    }
  }

  return response;
}
