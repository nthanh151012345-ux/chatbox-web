# Supabase setup

The Flutter SDK is installed and will initialize when both connection values are supplied.

The `chatbox` Project URL and publishable key are configured in
`lib/supabase_config.dart`. Run the app with:

```powershell
flutter run
```

You can override either value at build time with `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` if the project changes.

The app uses Supabase Email/Password authentication and one protected Edge
Function: `gemini-career-chat`. The Function calls Gemini on behalf of the app;
the Gemini API key is stored in the Supabase secret `GEMINI_API_KEY` and is not
included in Flutter or the web build. No database, storage, or realtime feature
has been added.

## Deploying the AI function

After installing and signing in to the Supabase CLI, set the Gemini key as a
secret and deploy the function:

```powershell
supabase secrets set GEMINI_API_KEY=your_key --project-ref htbvqsakurkqyimjwruo
supabase functions deploy gemini-career-chat --project-ref htbvqsakurkqyimjwruo --use-api
```

Do not put `GEMINI_API_KEY` in a Flutter file or GitHub Actions variable. The
Flutter app invokes the authenticated Edge Function instead.

## Demo accounts without a real email

The sign-in screen keeps the normal Email field. Students can register with
any syntactically valid address, such as `minh123@demo.edu`; the mailbox does
not need to exist. They must use the same address and password to sign in.

To let a newly registered demo account enter the app immediately, open
**Authentication → Providers → Email** in the Supabase Dashboard and turn off
**Confirm email**. This is appropriate for a classroom demo; enable email
confirmation again for a production app.
