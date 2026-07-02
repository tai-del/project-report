# Setup — one-time steps

These steps use your own accounts, so I can't do them for you. Do them in order; send me what's asked for at the end of each step and I'll continue.

## 1. Create a Supabase project
1. Go to https://supabase.com → sign in / sign up → **New project**.
2. Pick any name (e.g. `pikuach-tama38`), a database password (save it somewhere, you likely won't need it again), and the region closest to Israel (e.g. `eu-central-1`).
3. Wait ~2 minutes for provisioning.

## 2. Run the schema
1. In the Supabase dashboard: **SQL Editor** → **New query**.
2. Paste the entire contents of [`schema.sql`](./schema.sql) from this folder and click **Run**.
3. You should see "Success. No rows returned." This creates all tables, security policies, and the `photos` storage bucket.

## 3. Enable magic-link email login
1. **Authentication → Providers** → confirm **Email** is enabled (it is by default; magic link is part of it, no password required).
2. **Authentication → URL Configuration**:
   - **Site URL**: your GitHub Pages URL (you'll get this in step 5) — for now you can leave the default and I'll remind you to come back and update it.
   - **Redirect URLs**: add `http://localhost:*` (for local testing) and the GitHub Pages URL once you have it.

## 4. Send me your API credentials
**Project Settings → API**, send me:
- **Project URL** (looks like `https://xxxxxxxx.supabase.co`)
- **anon public** key (long string starting with `eyJ...`)

These are safe to embed in the client-side app — they're meant to be public. Security is enforced by the Row Level Security policies in `schema.sql`, not by hiding this key.

## 5. Create a GitHub repo + enable Pages
1. On https://github.com, click **New repository**. Name it e.g. `pikuach-tama38`, keep it **Public** (required for free GitHub Pages), don't add a README/gitignore/license (we already have files).
2. Send me the repo URL (e.g. `https://github.com/<you>/pikuach-tama38.git`) — I'll push the code.
3. Once pushed: **Settings → Pages** → under "Build and deployment", Source = **Deploy from a branch**, Branch = `main`, folder = `/ (root)` → **Save**.
4. After ~1 minute your app is live at `https://<you>.github.io/pikuach-tama38/`. Send me that URL and go back to step 3 above to set it as the Supabase **Site URL** and add it to **Redirect URLs**.

Once I have your Supabase URL + anon key and the GitHub Pages URL, I'll finish wiring everything up and we can test together.
