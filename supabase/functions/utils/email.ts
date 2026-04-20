import nodemailer from "npm:nodemailer";

declare const Deno: any;

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "";
const NODE_ENV = Deno.env.get("NODE_ENV") || "production";
const GMAIL_USER = Deno.env.get("GMAIL_USER") || "";
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD") || "";

export async function sendEmail(
  to: string,
  subject: string,
  html: string,
  from: { name: string; email: string }
) {
  if (NODE_ENV === "development") {
    if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
      throw new Error("Gmail credentials are not set for development environment.");
    }
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: GMAIL_USER,
        pass: GMAIL_APP_PASSWORD,
      },
    });

    await transporter.sendMail({
      from: `"${from.name}" <${GMAIL_USER}>`,
      to: to,
      subject: subject,
      html: html,
    });
    return;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: `${from.name} <${from.email}>`,
      to: [to],
      subject: subject,
      html: html,
    }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(`Resend API error: ${error.message}`);
  }
}
