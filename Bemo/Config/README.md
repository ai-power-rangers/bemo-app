# Configuration Setup

This directory contains environment-specific configuration files for the Bemo app.

## Setup Instructions

1. Copy the example files to create your actual configuration files:
   ```bash
   cp Debug.xcconfig.example Debug.xcconfig
   cp Release.xcconfig.example Release.xcconfig
   ```

2. Edit the configuration files with your actual API keys and endpoints:

### Debug.xcconfig
- Used for development builds
- Set `SENTRY_ENVIRONMENT` to `debug`
- Can use development/staging endpoints

### Release.xcconfig
- Used for production builds
- Set `SENTRY_ENVIRONMENT` to `production`
- Must use production endpoints

## Required Configuration Values

### PostHog Analytics
- `POSTHOG_API_KEY`: Your PostHog project API key
- `POSTHOG_HOST`: PostHog instance URL (usually https://us.i.posthog.com or https://eu.i.posthog.com)

### Supabase Backend
- `SUPABASE_URL`: Your Supabase project URL (e.g., https://your-project.supabase.co)
- `SUPABASE_ANON_KEY`: Your Supabase anonymous/public key

### Sentry Error Tracking
- `SENTRY_DSN`: Your Sentry Data Source Name (DSN)
- `SENTRY_ENVIRONMENT`: Environment name (debug/production)

## Security Notes

- **NEVER** commit the actual `.xcconfig` files with real API keys
- The `.xcconfig` files are already in `.gitignore`
- Only commit the `.example` files
- Store production keys securely (e.g., in a password manager)

## Troubleshooting

If the app crashes on startup with configuration errors:
1. Ensure the `.xcconfig` files exist (not just the examples)
2. Check that all required keys are present
3. Verify the values don't contain placeholder text like "YOUR_API_KEY"
4. Make sure the Xcode project is properly referencing the config files in Build Settings