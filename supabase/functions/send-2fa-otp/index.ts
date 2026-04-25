// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/// <reference lib="deno.window" />
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { sendEmail } from "../utils/email.ts";

declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface RequestBody {
  email: string;
  userId: string;
  otp: string;
  expirationMinutes: number;
}

async function sendOtp(email: string, otp: string): Promise<void> {
  const subject = "Your Two-Factor Authentication Code";
  const htmlContent = `
    <div style="font-family: Arial, sans-serif; color: #333;">
      <h2>Elm Origin Two-Factor Authentication</h2>
      <p>Use this code to complete your login:</p>
      <div style="background: #f0f0f0; padding: 20px; border-radius: 8px; text-align: center;">
        <h1 style="letter-spacing: 4px; color: #003566;">${otp}</h1>
      </div>
      <p>This code expires in <strong>10 minutes</strong>.</p>
      <p>If you didn't request this, please secure your account.</p>
    </div>
  `;

  await sendEmail(email, subject, htmlContent, {
    name: "Elm Origin 2FA",
    email: "onboarding@resend.dev",
  });
}

serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

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

    const { email, userId, otp, expirationMinutes } = await req.json();

    if (!email || !userId || !otp || !expirationMinutes) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const expiresAt = new Date(Date.now() + expirationMinutes * 60 * 1000);

    const { error: insertError } = await supabase.from("user_2fa_otps").insert({
      user_id: userId,
      otp_code: otp,
      expires_at: expiresAt.toISOString(),
    });

    if (insertError) {
      throw new Error(insertError.message);
    }

    await sendOtp(email, otp);

    return new Response(
      JSON.stringify({
        success: true,
        message: "2FA OTP sent successfully.",
        expiresInSeconds: expirationMinutes * 60,
      }),
      { status: 200, headers: { "Content-Iype": "application/json", ...corsHeaders } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "An unknown error occurred" }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
