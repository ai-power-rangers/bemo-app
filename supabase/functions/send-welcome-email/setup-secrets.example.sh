#!/bin/bash

# Example script for setting up secrets for the send-welcome-email function
# Copy this file to setup-secrets.sh and replace with your actual values

# DO NOT COMMIT setup-secrets.sh to version control!

echo "Setting up secrets for send-welcome-email function..."

# Set your Resend API key
supabase secrets set RESEND_API_KEY="re_YOUR_ACTUAL_RESEND_API_KEY"

# The SERVICE_ROLE_KEY should already be available in your Supabase project
# If you need to set it manually (rare), you can find it in your project settings
# supabase secrets set SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"

echo "Secrets setup completed!"
echo ""
echo "To verify secrets are set, run:"
echo "supabase secrets list"