// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/// <reference lib="deno.window" />
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface RequestBody {
  email: string;
  otp: string;
  newPassword?: string;
  password?: string;
  type?: "signup" | "password_reset";
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const body: RequestBody = await req.json();
    const { email, otp, newPassword, password, type } = body;

    if (!email || !otp) {
      return new Response(JSON.stringify({ error: "Email and OTP are required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Determine if this is signup or password reset
    const isSignup = type === "signup" || (password && !type);
    const isPasswordReset = type === "password_reset" || (!password && newPassword && !type);

    if (isPasswordReset && !newPassword) {
      return new Response(JSON.stringify({ error: "New password required for password reset" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    if (isSignup && !password) {
      return new Response(JSON.stringify({ error: "Password required for signup" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Find OTP token
    const { data: otpData, error: otpError } = await supabase
      .from("otp_tokens")
      .select("*")
      .eq("email", email)
      .eq("otp_code", otp)
      .order("created_at", { ascending: false })
      .maybeSingle();

    if (otpError || !otpData) {
      return new Response(JSON.stringify({ error: "Invalid or expired OTP" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Check expiration
    const now = new Date();
    const expiresAt = new Date(otpData.expires_at);
    if (now > expiresAt) {
      return new Response(JSON.stringify({ error: "OTP has expired" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Verify correct type
    if (isSignup && otpData.type !== "signup") {
      return new Response(JSON.stringify({ error: "Invalid OTP type for signup" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    if (isPasswordReset && otpData.type !== "password_reset") {
      return new Response(JSON.stringify({ error: "Invalid OTP type for password reset" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Delete used OTP
    await supabase.from("otp_tokens").delete().eq("id", otpData.id);

    // Handle signup flow
    if (isSignup) {
      const { name, role } = otpData.user_data || {};
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { name, role },
      });

      if (authError) {
        return new Response(JSON.stringify({ error: authError.message }), {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      const userId = authData.user?.id;
      if (userId) {
        // Seed profiles row so role is persisted in the database
        await supabase.from("profiles").upsert(
          { id: userId, name: name ?? "", role: role ?? "student", bio: "" },
          { onConflict: "id" }
        );
        // Seed users row (used by session history, earnings, world chat, etc.)
        await supabase.from("users").upsert(
          {
            id: userId,
            email,
            name: name ?? "",
            role: role ?? "student",
            is_active: true,
            last_login_at: new Date().toISOString(),
          },
          { onConflict: "id" }
        );
      }

      return new Response(JSON.stringify({ success: true, user: authData.user }), {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Handle password reset flow
    if (isPasswordReset) {
      // Get user ID
      const { data: users, error: userError } = await supabase.auth.admin.listUsers();

      if (userError) {
        return new Response(JSON.stringify({ error: "Failed to find user" }), {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      const user = users?.users?.find((u: any) => u.email === email);
      if (!user) {
        return new Response(JSON.stringify({ error: "User not found" }), {
          status: 404,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      // Update password
      const { error: updateError } = await supabase.auth.admin.updateUserById(user.id, {
        password: newPassword,
      });

      if (updateError) {
        return new Response(JSON.stringify({ error: updateError.message }), {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      return new Response(
        JSON.stringify({ success: true, message: "Password reset successfully" }),
        {
          status: 200,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    return new Response(JSON.stringify({ error: "Invalid request" }), {
      status: 400,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (e) {
    console.error("Error:", e);
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
