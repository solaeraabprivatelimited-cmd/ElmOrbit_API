// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/// <reference lib="deno.window" />
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

declare const Deno: any;

// For Brevo/SendGrid integration (replace with your email service)
const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") || "";

interface BookingConfirmationRequest {
  studentId: string;
  studentName: string;
  studentEmail: string;
  mentorName: string;
  dateTime: string;
  duration: string;
}

async function sendEmail(email: string, subject: string, htmlContent: string) {
  if (!BREVO_API_KEY) {
    console.log("[send-booking-confirmation] No email service configured, logging instead");
    return {
      success: true,
      message: "Email service not configured (would send to " + email + ")"
    };
  }

  // Using Brevo API (formerly Sendinblue)
  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "accept": "application/json",
      "content-type": "application/json",
      "api-key": BREVO_API_KEY,
    },
    body: JSON.stringify({
      sender: { name: "Elm Orbit", email: "solaeraab@gmail.com" },
      to: [{ email, name: email.split("@")[0] }],
      subject,
      htmlContent,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Email service error: ${error}`);
  }

  return await response.json();
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload: BookingConfirmationRequest = await req.json();

    const {
      studentId,
      studentName,
      studentEmail,
      mentorName,
      dateTime,
      duration,
    } = payload;

    console.log("[send-booking-confirmation] Processing booking confirmation:", {
      studentName,
      studentEmail,
      mentorName,
    });

    // Create HTML email template
    const htmlContent = `
      <html>
        <head>
          <style>
            body { font-family: 'Plus Jakarta Sans', sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #003566, #0967bd); color: white; padding: 30px; border-radius: 12px 12px 0 0; text-align: center; }
            .content { background: #f9fafb; padding: 30px; border-radius: 0 0 12px 12px; }
            .success-badge { display: inline-block; background: #10b981; color: white; padding: 8px 16px; border-radius: 20px; font-weight: bold; margin: 10px 0; }
            .booking-details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #003566; }
            .booking-detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e5e7eb; }
            .booking-detail-row:last-child { border-bottom: none; }
            .label { color: #6b7280; font-size: 14px; }
            .value { font-weight: bold; color: #003566; }
            .cta-button { display: inline-block; background: linear-gradient(135deg, #003566, #0967bd); color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; margin: 20px 0; font-weight: bold; }
            .footer { text-align: center; color: #9ca3af; font-size: 12px; margin-top: 20px; padding-top: 20px; border-top: 1px solid #e5e7eb; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 style="margin: 0; font-size: 28px;">Booking Confirmed! ✓</h1>
              <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.95;">Your mentor session has been successfully booked</p>
            </div>

            <div class="content">
              <p>Hi <strong>${studentName}</strong>,</p>

              <p>Great news! Your 1:1 session with <strong>${mentorName}</strong> is confirmed. We're excited to have you learn directly from an experienced mentor.</p>

              <div class="booking-details">
                <h3 style="margin-top: 0; color: #003566;">Session Details</h3>
                
                <div class="booking-detail-row">
                  <span class="label">Mentor</span>
                  <span class="value">${mentorName}</span>
                </div>

                <div class="booking-detail-row">
                  <span class="label">Date & Time</span>
                  <span class="value">${dateTime}</span>
                </div>

                <div class="booking-detail-row">
                  <span class="label">Duration</span>
                  <span class="value">${duration}</span>
                </div>

                <div class="booking-detail-row">
                  <span class="label">Amount</span>
                  <span class="value">₹500.00</span>
                </div>
              </div>

              <p><strong>What happens next?</strong></p>
              <ul>
                <li>We'll send you a reminder 10 minutes before your session starts</li>
                <li>The mentor will join the session via video call</li>
                <li>You'll be able to ask questions and get personalized guidance</li>
              </ul>

              <center>
                <a href="https://elmorbit.co.in/dashboard" class="cta-button">Go to Dashboard</a>
              </center>

              <p>If you have any questions or need to reschedule, please contact our support team.</p>

              <p>Happy Learning! 🎓<br>The Elm Orbit Team</p>

              <div class="footer">
                <p>© 2026 Elm Orbit. All rights reserved.<br>
                This is an automated email, please don't reply directly.</p>
              </div>
            </div>
          </div>
        </body>
      </html>
    `;

    // Send email
    const emailResult = await sendEmail(
      studentEmail,
      `✓ Booking Confirmed with ${mentorName} - Elm Orbit`,
      htmlContent
    );

    console.log("[send-booking-confirmation] Email sent successfully:", emailResult);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Booking confirmation email sent",
        email: studentEmail,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("[send-booking-confirmation] Error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
