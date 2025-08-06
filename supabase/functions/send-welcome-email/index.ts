import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    // Verify the request is from Supabase webhook
    const authHeader = req.headers.get('Authorization')
    if (authHeader !== `Bearer ${SERVICE_ROLE_KEY}`) {
      return new Response('Unauthorized', { status: 401 })
    }

    // Parse the webhook payload
    const { type, table, record, old_record } = await req.json()

    // Only process INSERT events on parent_profiles table
    if (type !== 'INSERT' || table !== 'parent_profiles') {
      return new Response('Event not applicable', { status: 200 })
    }

    // Extract user information
    const { email, full_name } = record

    if (!email) {
      console.error('No email found for new parent profile')
      return new Response('No email found', { status: 400 })
    }

    // Send welcome email using Resend
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Bemo Team <welcome@playbemo.com>',
        to: email,
        subject: 'Welcome to Bemo - Educational Games for Kids! 🎮',
        html: `
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="utf-8">
              <title>Welcome to Bemo</title>
              <style>
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                  line-height: 1.6;
                  color: #333;
                  max-width: 600px;
                  margin: 0 auto;
                  padding: 20px;
                }
                .header {
                  background-color: #4F46E5;
                  color: white;
                  padding: 30px;
                  text-align: center;
                  border-radius: 10px 10px 0 0;
                }
                .content {
                  background-color: #f9fafb;
                  padding: 30px;
                  border-radius: 0 0 10px 10px;
                }
                .button {
                  display: inline-block;
                  background-color: #4F46E5;
                  color: white;
                  padding: 12px 30px;
                  text-decoration: none;
                  border-radius: 5px;
                  margin-top: 20px;
                }
                .footer {
                  margin-top: 30px;
                  font-size: 14px;
                  color: #666;
                  text-align: center;
                }
                .feature-list {
                  background-color: white;
                  padding: 20px;
                  border-radius: 8px;
                  margin: 20px 0;
                }
                .feature-list li {
                  margin: 10px 0;
                }
              </style>
            </head>
            <body>
              <div class="header">
                <h1>Welcome to Bemo! 🎉</h1>
              </div>
              <div class="content">
                <p>Hi${full_name ? ` ${full_name}` : ''},</p>
                
                <p><strong>Congrats on signing up for Bemo!</strong> You've just taken the first step in providing your children with fun, educational games that help them learn while they play.</p>
                
                <div class="feature-list">
                  <h2>What's Next?</h2>
                  <ul>
                    <li>📱 <strong>Create profiles</strong> for your children in the app</li>
                    <li>🎮 <strong>Explore</strong> our collection of educational games</li>
                    <li>📊 <strong>Track</strong> your children's learning progress</li>
                    <li>🏆 <strong>Watch</strong> them earn XP and unlock achievements</li>
                  </ul>
                </div>
                
                <p>Our games are designed to adapt to your child's learning pace, making education fun and engaging!</p>
                
                <p>Check out <a href="https://playbemo.com">playbemo.com</a> for more details about our games, educational approach, and tips for maximizing your children's learning experience.</p>
                
                <center>
                  <a href="https://playbemo.com" class="button">Visit PlayBemo.com</a>
                </center>
                
                <h3>Need Help?</h3>
                <p>If you have any questions or need assistance, our support team is here to help. Simply reply to this email or visit our support page.</p>
              </div>
              <div class="footer">
                <p>© 2024 Bemo. All rights reserved.</p>
                <p>Making learning fun, one game at a time! 🎮</p>
              </div>
            </body>
          </html>
        `,
        text: `Hi${full_name ? ` ${full_name}` : ''},

Congrats on signing up for Bemo! You've just taken the first step in providing your children with fun, educational games that help them learn while they play.

What's Next?
- Create profiles for your children in the app
- Explore our collection of educational games  
- Track your children's learning progress
- Watch them earn XP and unlock achievements

Our games are designed to adapt to your child's learning pace, making education fun and engaging!

Check out playbemo.com for more details about our games, educational approach, and tips for maximizing your children's learning experience.

Need Help?
If you have any questions or need assistance, our support team is here to help.

© 2024 Bemo. All rights reserved.
Making learning fun, one game at a time!`
      }),
    })

    if (!emailResponse.ok) {
      const error = await emailResponse.text()
      console.error('Failed to send email:', error)
      return new Response(`Failed to send email: ${error}`, { status: 500 })
    }

    const emailData = await emailResponse.json()
    console.log('Welcome email sent successfully:', emailData)

    return new Response(JSON.stringify({ success: true, emailId: emailData.id }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Error in send-welcome-email function:', error)
    return new Response(`Internal server error: ${error.message}`, { status: 500 })
  }
})