# Setup — one-time steps

Current setup (as actually deployed):
- **Hosting**: GitHub Pages, serving from this repo — https://tai-del.github.io/project-report/
- **Backend**: Supabase (Postgres + Auth + Storage + Realtime)
- **Login**: Google OAuth (via Supabase Auth)

## 1. Supabase project
Already created. Schema lives in [`schema.sql`](./schema.sql) — safe to re-run any time (every statement is idempotent). Whenever a new migration is added at the bottom of the file, paste the whole file into the Supabase **SQL Editor** and run it again.

## 2. API credentials
Already wired into `index.html` (`SUPABASE_URL` / `SUPABASE_ANON_KEY` constants near the top of the `<script>` block). These are meant to be public — security comes from the Row Level Security policies in `schema.sql`, not from hiding this key.

## 3. Google sign-in
Set up once in:
- **Google Cloud Console**: OAuth client (type: Web application), with an Authorized redirect URI of
  `https://qzalhcwaqkdnmwriyupc.supabase.co/auth/v1/callback`
- **Supabase → Authentication → Providers → Google**: Client ID + Client Secret from the step above
- **Supabase → Authentication → URL Configuration**: Site URL + Redirect URLs include
  `https://tai-del.github.io/project-report/`

## 4. Hosting (GitHub Pages)
- Repo: https://github.com/tai-del/project-report (public — required for free GitHub Pages)
- **Settings → Pages**: Source = Deploy from a branch, Branch = `main`, folder = `/ (root)`
- Every `git push` to `main` auto-deploys within ~1 minute; the app also auto-refreshes itself in the browser once a new version is live (no manual cache-clearing needed under normal circumstances)

## Local testing
No local dev server is set up in this environment (no Node/Python available), so changes are pushed straight to `main` and verified against the live GitHub Pages URL.
