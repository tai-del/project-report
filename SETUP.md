# Setup — one-time steps

These steps use your own accounts, so I can't do them for you. Do them in order; send me what's asked for at the end of each step and I'll continue.

The code is already pushed to https://github.com/tai-del/project-report — that repo is just for source control/history, not for hosting. The app itself is hosted straight out of Supabase Storage (see step 5), so it's all in one place.

## 1. Create a Supabase project
1. Go to https://supabase.com → sign in / sign up → **New project**.
2. Pick any name (e.g. `pikuach-tama38`), a database password (save it somewhere, you likely won't need it again), and the region closest to Israel (e.g. `eu-central-1`).
3. Wait ~2 minutes for provisioning.

## 2. Run the schema
1. In the Supabase dashboard: **SQL Editor** → **New query**.
2. Paste the entire contents of [`schema.sql`](./schema.sql) from this folder and click **Run**.
3. You should see "Success. No rows returned." This creates all tables, security policies, the `photos` bucket (for stage/issue/general photos), and the `site` bucket (for hosting the app files themselves).
   - If you already ran an older version of `schema.sql`, it's safe to re-run — every statement is idempotent (`if not exists` / `on conflict do nothing`).

## 3. Send me your API credentials
**Project Settings → API**, send me:
- **Project URL** (looks like `https://xxxxxxxx.supabase.co`)
- **anon public** key (long string starting with `eyJ...`)

These are safe to embed in the client-side app — they're meant to be public. Security is enforced by the Row Level Security policies in `schema.sql`, not by hiding this key.

## 4. Enable magic-link email login
1. **Authentication → Providers** → confirm **Email** is enabled (it is by default; magic link is part of it, no password required).
2. **Authentication → URL Configuration** — leave this for now, we'll come back once you have the hosted app URL from step 5.

## 5. Upload the app files to Storage
Once I've plugged your Project URL/anon key into `index.html`:
1. In the Supabase dashboard: **Storage → site** bucket (created by the schema script).
2. Upload `index.html`, `sw.js`, and `manifest.json` from this folder (drag-and-drop or the Upload button).
3. Your app is now live at:
   `https://<your-project-ref>.supabase.co/storage/v1/object/public/site/index.html`
4. Go back to **Authentication → URL Configuration** and set both **Site URL** and **Redirect URLs** to that exact URL (add `http://localhost:*` too, for local testing with me).

Note: unlike GitHub Pages, this isn't auto-deploying — whenever the app code changes, you (or I'll remind you) re-upload the changed file(s) to the `site` bucket to update the live version.

Once I have your Supabase URL + anon key, I'll finish wiring everything up, tell you exactly what to upload, and we'll test together.
