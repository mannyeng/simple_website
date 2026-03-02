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

-- =============================================
-- TIMELINE EVENTS
-- =============================================

create table if not exists timeline_events (
  id text primary key,
  year integer not null,
  era text not null check (era in ('ancient','classical','medieval','early-modern','modern')),
  title text not null,
  description text not null,
  author_id text references members(id) on delete set null, -- nullable: NULL = admin import
  author_name text not null,
  approved boolean default false,
  created_at timestamptz default now()
);

-- If table already exists, run these to allow admin bulk imports:
-- alter table timeline_events alter column author_id drop not null;
-- alter table timeline_events drop constraint if exists timeline_events_author_id_fkey;
-- alter table timeline_events add constraint timeline_events_author_id_fkey
--   foreign key (author_id) references members(id) on delete set null;

alter table timeline_events enable row level security;
create policy "allow_all_timeline" on timeline_events for all using (true) with check (true);

-- =============================================
-- ARTICLES
-- =============================================

create table if not exists articles (
  id text primary key,
  title text not null,
  slug text unique not null,
  excerpt text not null,
  body text not null,
  image_url text,
  author_name text not null default 'Admin',
  published boolean default true,
  likes integer default 0,
  created_at timestamptz default now()
);

alter table articles enable row level security;
create policy "allow_all_articles" on articles for all using (true) with check (true);

create table if not exists article_comments (
  id text primary key,
  article_id text references articles(id) on delete cascade,
  member_id text references members(id) on delete cascade,
  member_name text not null,
  body text not null,
  created_at timestamptz default now()
);

alter table article_comments enable row level security;
create policy "allow_all_article_comments" on article_comments for all using (true) with check (true);

create table if not exists article_likes (
  id text primary key,
  article_id text references articles(id) on delete cascade,
  fingerprint text not null,
  created_at timestamptz default now(),
  unique(article_id, fingerprint)
);

alter table article_likes enable row level security;
create policy "allow_all_article_likes" on article_likes for all using (true) with check (true);

-- Storage bucket for article images (run in Supabase dashboard):
-- insert into storage.buckets (id, name, public) values ('article-images', 'article-images', true);
-- create policy "allow_article_image_upload" on storage.objects for insert with check (bucket_id = 'article-images');
-- create policy "allow_article_image_read" on storage.objects for select using (bucket_id = 'article-images');
-- create policy "allow_article_image_delete" on storage.objects for delete using (bucket_id = 'article-images');

-- =============================================
-- MIGRATION: Remove date of birth column
-- Run this in Supabase SQL Editor if the
-- members table already exists:
-- =============================================
-- alter table members drop column if exists dob;
