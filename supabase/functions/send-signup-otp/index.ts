// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/// <reference lib="deno.window" />
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { sendEmail } from "../utils/email.ts";

declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const GMAIL_USER = Deno.env.get("GMAIL_USER") || "";
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD") || "";

interface RequestBody {
  email: string;
  name: string;
  role: "student" | "mentor";
}

function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function sendOtp(email: string, otp: string, name: string): Promise<void> {
  const subject = "Verify Your Email - Elm Orbit";
  const htmlContent = `
    <div style="font-family: Arial, sans-serif; color: #333;">
      <h2>Welcome to Elm Orbit, ${name}!</h2>
      <p>Use this code to verify your email:</p>
      <div style="background: #f0f0f0; padding: 20px; border-radius: 8px; text-align: center;">
        <h1 style="letter-spacing: 4px; color: #003566;">${otp}</h1>
      </div>
      <p>This code expires in <strong>10 minutes</strong>.</p>
      <p>If you didn't sign up, ignore this email.</p>
    </div>
  `;

  await sendEmail(email, subject, htmlContent, {
    name: "Elm Orbit",
    email: "onboarding@resend.dev",
  });
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
    const { email, name, role } = body;

    if (!email || !name || !role) {
      return new Response(
        JSON.stringify({ error: "Missing email, name, or role" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Generate OTP
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Store OTP in database
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const {
      data: { users },
      error: listError,
    } = await supabase.auth.admin.listUsers({
      email,
    });

    if (listError) {
      return new Response(JSON.stringify({ error: listError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    if (users && users.length > 0) {
      return new Response(JSON.stringify({ error: "Email already registered" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Store OTP token
    const { error: insertError } = await supabase.from("otp_tokens").insert({
      email,
      otp_code: otp,
      type: "signup",
      user_data: { name, role },
      expires_at: expiresAt.toISOString(),
    });

    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Send OTP
    await sendOtp(email, otp, name);

    return new Response(
      JSON.stringify({
        success: true,
        message: "OTP sent to your email",
        email,
      }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
