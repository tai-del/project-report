-- ═══════════════════════════════════════════════════════════
-- פיקוח בנייה תמ"א 38 — Supabase schema
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query → Run).
-- Safe to re-run: everything is CREATE ... IF NOT EXISTS / CREATE OR REPLACE.
-- ═══════════════════════════════════════════════════════════

-- ── profiles ──────────────────────────────────────────────
-- One row per supervisor, auto-created on first sign-in via trigger below.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── projects ──────────────────────────────────────────────
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text default '',
  custom_stages jsonb not null default '[]'::jsonb, -- [{cat:0-7, name:'...'}]
  milestones jsonb not null default '[]'::jsonb, -- [{cat:0-7, planned:'YYYY-MM-DD', actual:'YYYY-MM-DD'}]
  main_image_path text, -- storage path in the 'photos' bucket, shown on report page 1
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);


-- ── shared visit fields, reused by drafts + visits ──────────
-- (documented here; both tables repeat these columns since Postgres has no
--  table inheritance friendly to Supabase's PostgREST/Realtime layer)

-- ── drafts: one active in-progress visit per project ────────
create table if not exists public.drafts (
  project_id uuid primary key references public.projects(id) on delete cascade,
  visit_date date,
  visit_time text,
  supervisor_name text,
  site_manager text,
  project_type text,
  stages jsonb not null default '{}'::jsonb,
  stage_notes jsonb not null default '{}'::jsonb,
  hidden_stages jsonb not null default '{}'::jsonb,
  issues jsonb not null default '[]'::jsonb,
  plan_week1 jsonb not null default '[]'::jsonb,
  plan_week1_other text default '',
  plan_week2 jsonb not null default '[]'::jsonb, -- unused (kept for old rows), replaced by plan_range
  plan_week2_other text default '',
  plan_range text not null default 'week',
  next_visit_date date,
  overall_progress text default '',
  general_notes text default '',
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

-- ── visits: archived/finalized visits (insert-only) ─────────
create table if not exists public.visits (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  visit_date date,
  visit_time text,
  supervisor_name text,
  site_manager text,
  project_type text,
  stages jsonb not null default '{}'::jsonb,
  stage_notes jsonb not null default '{}'::jsonb,
  hidden_stages jsonb not null default '{}'::jsonb,
  issues jsonb not null default '[]'::jsonb,
  plan_week1 jsonb not null default '[]'::jsonb,
  plan_week1_other text default '',
  plan_week2 jsonb not null default '[]'::jsonb, -- unused (kept for old rows), replaced by plan_range
  plan_week2_other text default '',
  plan_range text not null default 'week',
  next_visit_date date,
  overall_progress text default '',
  general_notes text default '',
  progress_pct int,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists visits_project_idx on public.visits(project_id, created_at desc);

-- ── visit_photos ──────────────────────────────────────────
create table if not exists public.visit_photos (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  visit_id uuid references public.visits(id) on delete cascade, -- null while still a draft
  kind text not null check (kind in ('stage','issue','general')),
  ref_key text, -- stage name or issue id; null for 'general'
  storage_path text not null,
  description text default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists visit_photos_project_idx on public.visit_photos(project_id, kind, ref_key);
create index if not exists visit_photos_visit_idx on public.visit_photos(visit_id);

-- ── app_settings: single shared row ──────────────────────────
create table if not exists public.app_settings (
  id int primary key default 1,
  stage_categories jsonb not null default '[]'::jsonb,
  api_key text default '',
  pin text default '1234',
  constraint app_settings_singleton check (id = 1)
);

insert into public.app_settings (id) values (1) on conflict (id) do nothing;

-- ═══════════════════════════════════════════════════════════
-- Row Level Security — small trusted team: any signed-in user
-- can read/write everything. Not multi-tenant; intentional.
-- ═══════════════════════════════════════════════════════════
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.drafts enable row level security;
alter table public.visits enable row level security;
alter table public.visit_photos enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists "team read profiles" on public.profiles;
create policy "team read profiles" on public.profiles for select to authenticated using (true);
drop policy if exists "self update profile" on public.profiles;
create policy "self update profile" on public.profiles for update to authenticated using (auth.uid() = id);

drop policy if exists "team all projects" on public.projects;
create policy "team all projects" on public.projects for all to authenticated using (true) with check (true);

drop policy if exists "team all drafts" on public.drafts;
create policy "team all drafts" on public.drafts for all to authenticated using (true) with check (true);

drop policy if exists "team all visits" on public.visits;
create policy "team all visits" on public.visits for all to authenticated using (true) with check (true);

drop policy if exists "team all visit_photos" on public.visit_photos;
create policy "team all visit_photos" on public.visit_photos for all to authenticated using (true) with check (true);

drop policy if exists "team all app_settings" on public.app_settings;
create policy "team all app_settings" on public.app_settings for all to authenticated using (true) with check (true);

-- ═══════════════════════════════════════════════════════════
-- Realtime — enable change broadcasts for live team sync
-- ═══════════════════════════════════════════════════════════
do $$
declare t text;
begin
  foreach t in array array['projects','drafts','visits','visit_photos'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════
-- Storage bucket for photos
-- ═══════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "public read photos" on storage.objects;
create policy "public read photos" on storage.objects
  for select using (bucket_id = 'photos');

drop policy if exists "team upload photos" on storage.objects;
create policy "team upload photos" on storage.objects
  for insert to authenticated with check (bucket_id = 'photos');

drop policy if exists "team delete photos" on storage.objects;
create policy "team delete photos" on storage.objects
  for delete to authenticated using (bucket_id = 'photos');

-- ═══════════════════════════════════════════════════════════
-- Migrations for columns added after the initial schema — safe
-- to re-run, only apply once tables already exist above.
-- ═══════════════════════════════════════════════════════════
alter table public.projects add column if not exists milestones jsonb not null default '[]'::jsonb;
alter table public.drafts add column if not exists plan_range text not null default 'week';
alter table public.visits add column if not exists plan_range text not null default 'week';
alter table public.projects add column if not exists main_image_path text;
