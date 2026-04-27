# Deploying the `narratives` Edge Function

This is a one-time setup. After this, the ✨ Rewrite with Claude button in the Quarterly Report Builder will work.

## What this does

The Edge Function sits between your browser and Anthropic's API. Your `ANTHROPIC_API_KEY` lives in Supabase's secret store on the server, so it's never visible to anyone opening the HTML file or browser devtools. When you click "Rewrite with Claude", your browser sends the report metrics to this function, it calls Claude Sonnet 4.6, and returns the four narrative paragraphs.

## Prerequisites

- An **Anthropic API key** (starts with `sk-ant-...`). Get one at https://console.anthropic.com/settings/keys if you don't have one already.
- Your Supabase project (the one already wired into `index.html` — `beoquaazkkxjisxnmrmg`).

## Easiest path — Supabase web console (no CLI required)

1. **Go to the Edge Functions page.** Open your Supabase project: https://supabase.com/dashboard/project/beoquaazkkxjisxnmrmg/functions
2. **Add the secret.** In the same sidebar, click **Project Settings → Edge Functions → Secrets**, then **Add new secret**:
   - Name: `ANTHROPIC_API_KEY`
   - Value: *(paste your `sk-ant-...` key)*
   - Save.
3. **Create the function.** Back on the Edge Functions page, click **Deploy a new function**:
   - Name: `narratives` (exactly this — the HTML calls this name).
   - Paste the entire contents of `narratives/index.ts` (in this same folder) into the editor.
   - Click **Deploy function**.
4. **Verify.** Open the Quarterly Report Builder, process a report, go to the narratives step, and click **✨ Rewrite with Claude**. Within a few seconds the four paragraphs should be replaced with fresh prose. If it fails, the red error banner at the top of the app will tell you why.

## Alternate path — Supabase CLI

If you prefer the terminal:

```bash
# Install the CLI (one time)
brew install supabase/tap/supabase       # macOS
# or: npm install -g supabase

# Sign in and link
supabase login
cd "Quarterly Report Builder/supabase-edge-function"
supabase link --project-ref beoquaazkkxjisxnmrmg

# Set the secret
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

# Deploy
supabase functions deploy narratives
```

## Updating later

To tweak the prompt (tone, length, what to mention), edit `narratives/index.ts` in this folder and redeploy — either by pasting the updated file into the console editor or re-running `supabase functions deploy narratives`. No browser/HTML change is needed.

## Cost

Each rewrite call is roughly 1–2k input tokens and ~600 output tokens through Claude Sonnet 4.6 — single-digit cents per report. Watch your Anthropic dashboard if you're curious.

## Troubleshooting

- **"forbidden — email domain not allowed"** → you signed in with a non-`@leavenwealth.com` address. The function mirrors the same domain rule the rest of the app enforces.
- **"missing auth" or "not authenticated"** → you're not signed in to the builder. Sign in and try again.
- **"server misconfigured: ANTHROPIC_API_KEY not set"** → step 2 didn't save. Re-add the secret in Supabase and redeploy.
- **"anthropic api error … status 401"** → the Anthropic key is invalid or revoked. Generate a new one and update the secret.
- **"anthropic api error … status 429"** → rate-limited by Anthropic. Wait a minute and retry.
- **Any other error** → the red banner in the app will include the message; the existing narratives (template or user-edited) are left untouched as a safety fallback.
