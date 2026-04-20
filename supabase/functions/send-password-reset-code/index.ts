// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/// <reference lib="deno.window" />
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const GMAIL_USER = Deno.env.get("GMAIL_USER") || "";
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD") || "";

interface RequestBody {
  email: string;
  name?: string;
  role?: "student" | "mentor";
}

function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function sendOtpViaEmail(recipientEmail: string, otp: string, name: string): Promise<void> {
  if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
    throw new Error("Gmail credentials not set. Configure GMAIL_USER and GMAIL_APP_PASSWORD.");
  }

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

  // Connect to Gmail via TLS
  const conn = await Deno.connectTls({
    hostname: "smtp.gmail.com",
    port: 465,
  });

  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  async function sendCommand(cmd: string): Promise<string> {
    await conn.write(encoder.encode(cmd + "\r\n"));
    const buffer = new Uint8Array(4096);
    const n = await conn.read(buffer);
    return decoder.decode(buffer.subarray(0, n));
  }

  try {
    // Read initial response
    const buffer = new Uint8Array(4096);
    let n = await conn.read(buffer);
    let response = decoder.decode(buffer.subarray(0, n));
    console.log("SMTP Response:", response);

    // Send EHLO
    response = await sendCommand(`EHLO localhost`);
    console.log("EHLO Response:", response);

    // AUTH LOGIN
    response = await sendCommand(`AUTH LOGIN`);
    console.log("AUTH LOGIN Response:", response);

    // Send base64 encoded email
    const userB64 = btoa(GMAIL_USER);
    response = await sendCommand(userB64);
    console.log("User B64 Response:", response);

    // Send base64 encoded password
    const passB64 = btoa(GMAIL_APP_PASSWORD);
    response = await sendCommand(passB64);
    console.log("Password B64 Response:", response);

    // MAIL FROM
    response = await sendCommand(`MAIL FROM:<${GMAIL_USER}>`);
    console.log("MAIL FROM Response:", response);

    // RCPT TO
    response = await sendCommand(`RCPT TO:<${recipientEmail}>`);
    console.log("RCPT TO Response:", response);

    // DATA
    response = await sendCommand(`DATA`);
    console.log("DATA Response:", response);

    // Send email content
    const emailMessage = `From: ${GMAIL_USER}\r\nTo: ${recipientEmail}\r\nSubject: Verify Your Email - Elm Orbit\r\nContent-Type: text/html; charset="UTF-8"\r\n\r\n${htmlContent}\r\n.`;
    response = await sendCommand(emailMessage);
    console.log("Message Response:", response);

    // QUIT
    response = await sendCommand(`QUIT`);
    console.log("QUIT Response:", response);

    conn.close();
  } catch (error) {
    conn.close();
    throw error;
  }
}

serve(async (req: Request) => {
  // CORS headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
    "Content-Type": "application/json",
  };

  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: corsHeaders,
      });
    }

    const body: RequestBody = await req.json();
    const { email, name, role } = body;

    // Determine if this is signup or password reset
    if (!email) {
      return new Response(
        JSON.stringify({ error: "Missing email" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const isSignup = name && role;
    const isPasswordReset = !name && !role;

    if (!isSignup && !isPasswordReset) {
      return new Response(
        JSON.stringify({ error: "Invalid request. Either provide (name, role) for signup or just email for password reset" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Generate OTP
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Store OTP in database
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // For signup: Check if email already exists
    if (isSignup) {
      const { data: existing } = await supabase
        .from("users")
        .select("id")
        .eq("email", email)
        .maybeSingle();

      if (existing) {
        return new Response(JSON.stringify({ error: "Email already registered" }), {
          status: 400,
          headers: corsHeaders,
        });
      }
    }

    // For password reset: Verify email exists
    if (isPasswordReset) {
      const { data: existing } = await supabase
        .from("users")
        .select("id")
        .eq("email", email)
        .maybeSingle();

      if (!existing) {
        return new Response(JSON.stringify({ error: "Email not found" }), {
          status: 404,
          headers: corsHeaders,
        });
      }
    }

    // Store OTP token
    const { error: insertError } = await supabase.from("otp_tokens").insert([
      {
        email,
        otp_code: otp,
        type: isSignup ? "signup" : "password_reset",
        user_data: isSignup ? { name, role } : {},
        expires_at: expiresAt.toISOString(),
      },
    ]);

    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 500,
        headers: corsHeaders,
      });
    }

    // Send OTP via Resend
    const displayName = name || email.split("@")[0];
    await sendOtpViaEmail(email, otp, displayName);

    return new Response(
      JSON.stringify({
        success: true,
        message: "OTP sent to your email",
        email,
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: corsHeaders }
    );
  }
});
