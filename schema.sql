-- =============================================
-- GRACE COMMUNITY — SUPABASE SCHEMA
-- Run this entire file in Supabase SQL Editor
-- =============================================

-- MEMBERS
create table if not exists members (
  id text primary key,
  first_name text not null,
  last_name text not null,
  email text unique not null,
  password text not null,
  dob text,
  phone text,
  source text,
  ministry text,
  newsletter boolean default false,
  assigned_categories text[] default '{}',
  followed_categories text[] default '{}',
  followed_threads text[] default '{}',
  joined_at timestamptz default now()
);

-- CATEGORIES
create table if not exists categories (
  id text primary key,
  name text unique not null,
  description text,
  color text default '#b8963e',
  created_at timestamptz default now()
);

-- THREADS
create table if not exists threads (
  id text primary key,
  category_id text references categories(id) on delete set null,
  title text not null,
  body text not null,
  author_id text references members(id) on delete cascade,
  author_name text not null,
  replies int default 0,
  views int default 0,
  likes text[] default '{}',
  pinned boolean default false,
  files jsonb default '[]',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- POSTS (replies inside threads)
create table if not exists posts (
  id text primary key,
  thread_id text references threads(id) on delete cascade,
  author_id text references members(id) on delete cascade,
  author_name text not null,
  body text not null,
  likes text[] default '{}',
  files jsonb default '[]',
  created_at timestamptz default now()
);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- Allow all operations via anon key for now
-- Tighten these in production with auth rules
-- =============================================

alter table members enable row level security;
alter table categories enable row level security;
alter table threads enable row level security;
alter table posts enable row level security;

-- Members: allow all via anon key
create policy "allow_all_members" on members for all using (true) with check (true);
create policy "allow_all_categories" on categories for all using (true) with check (true);
create policy "allow_all_threads" on threads for all using (true) with check (true);
create policy "allow_all_posts" on posts for all using (true) with check (true);

-- =============================================
-- STORAGE BUCKET FOR FILE UPLOADS
-- =============================================

-- Run this separately in Supabase Storage settings:
-- 1. Go to Storage in the Supabase dashboard
-- 2. Create a new bucket called: forum-files
-- 3. Set it to PUBLIC
-- 4. Set file size limit to 262144000 (250MB)

-- Or run via SQL:
insert into storage.buckets (id, name, public, file_size_limit)
values ('forum-files', 'forum-files', true, 262144000)
on conflict (id) do nothing;

create policy "allow_upload_forum_files" on storage.objects
  for insert with check (bucket_id = 'forum-files');

create policy "allow_read_forum_files" on storage.objects
  for select using (bucket_id = 'forum-files');

create policy "allow_delete_forum_files" on storage.objects
  for delete using (bucket_id = 'forum-files');
