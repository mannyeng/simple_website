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
  grade text,
  years_teaching text,
  parish_id integer,
  parish_name text,
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

-- =============================================
-- PARISHES TABLE
-- =============================================

create table if not exists parishes (
  id serial primary key,
  name text not null,
  address text,
  created_at timestamptz default now()
);

alter table parishes enable row level security;
create policy "allow_read_parishes" on parishes for select using (true);
create policy "allow_admin_parishes" on parishes for all using (true) with check (true);

-- Insert all parishes
insert into parishes (name, address) values
  ('Holy Family Syro-Malabar Catholic Church, Phoenix, AZ', '3221 N. 24th Street, Phoenix, AZ 85016, USA'),
  ('Infant Jesus Syro-Malabar Catholic Church, Sacramento, CA', '6200 McMahon Drive, Sacramento, CA 95824, USA'),
  ('St. Alphonsa Syro-Malabar Catholic Church, Los Angeles, CA', '215 N MacNeil St., San Fernando, CA 91340, USA'),
  ('St. Chavara Syro-Malabar Catholic Church, Bakersfield, CA', '4500 Buena Vista Rd, Bakersfield, CA 93311, USA'),
  ('St. John Paul II Syro-Malabar Knanaya Catholic Mission, Sacramento, CA', '8720 Florin Rd., Sacramento, CA 95828, USA'),
  ('St. Joseph Syro-Malabar Catholic Mission, San Diego, CA', '15546 Pomerado Rd, Poway, CA 92064, USA'),
  ('St. Joseph Syro-Malabar Knanaya Catholic Mission, Tracy, CA', '163 W Easton, Tracy, CA 95376, USA'),
  ('St. Jude Syro-Malabar Catholic Mission, San Bernardino, CA', '12745 Oriole Ave, Grand Terrace, CA 92314, USA'),
  ('St. Mary‚Äôs Syro-Malabar Knanaya Catholic Forane Church, San Jose, CA', '324 Gloria Ave, San Jose, CA 95127, USA'),
  ('St. Pius X Syro-Malabar Knanaya Catholic Church, Los Angeles, CA', '124 N 5th St, Montebello, CA 90640, USA'),
  ('St. Teresa of Calcutta Syro-Malabar Catholic Mission, Livermore, CA', '1315 Lomitas Ave, Livermore, CA 94550, USA'),
  ('St. Thomas Apostle Syro-Malabar Catholic Forane Church, Orange, CA', '743 N. Eckoff St., Orange, CA 92868, USA'),
  ('St. Thomas Syro-Malabar Catholic Church, San Francisco, CA', '42500 Gatewood St., Fremont, CA 94538, USA'),
  ('St. Thomas Syro-Malabar Catholic Church, Denver, CO', '3601 N Humboldt St., Denver, CO 80205, USA'),
  ('Our Lady of Assumption Syro-Malabar Catholic Mission, Norwalk, CT', '25 Cliff St., Norwalk, CT 06854, USA'),
  ('St. Thomas Syro-Malabar Catholic Church, Hartford, CT', '30 Echo Lane, West Hartford, CT 06107, USA'),
  ('Holy Trinity Syro-Malabar Catholic Mission, Delaware', '345 Bear Christiana Rd, Bear, DE 19701, USA'),
  ('Our Lady of Health Syro-Malabar Forane Catholic Church, Coral Springs, FL', '201 North University Dr, Coral Springs, FL 33071, USA'),
  ('Sacred Heart Syro-Malabar Knanaya Catholic Forane Church, Tampa, FL', '3920 S. King Avenue, Brandon, FL 33511, USA'),
  ('St. George Syro-Malabar Catholic Mission, Miami, FL', '9200 SW 107th Ave., Miami, FL 33176, USA'),
  ('St. Joseph Syro-Malabar Catholic Church, Tampa, FL', '5501 Williams Rd, Seffner, FL 33584, USA'),
  ('St. Jude Syro-Malabar Knanaya Catholic Church, Miami, FL', '1105 NW 6th Avenue, Fort Lauderdale, FL 33311, USA'),
  ('St. Mary‚Äôs Syro-Malabar Catholic Church, Orlando, FL', '2581 S. Sanford Ave, Sanford, FL 32773, USA'),
  ('St. Mary‚Äôs Syro-Malabar Catholic Mission, Jacksonville, FL', '4650 Kernan Blvd. S, Jacksonville, FL 32224, USA'),
  ('St. Stephen‚Äôs Syro-Malabar Knanaya Catholic Church, Orlando, FL', '14801 Sussex Dr., Orlando, FL 32826, USA'),
  ('Holy Family Syro-Malabar Knanaya Catholic Church, Atlanta, GA', '3885 Rosebud Road, Loganville, GA 30052, USA'),
  ('St. Alphonsa Syro-Malabar Catholic Forane Church, Atlanta, GA', '4561 Rosebud Road, Loganville, GA 30052, USA'),
  ('St. John Paul II Syro-Malabar Catholic Mission, Cumming, GA', '4599 Rosebud Road, Loganville, GA 30052, USA'),
  ('Mar Thoma Sleeha Syro-Malabar Cathedral, Chicago, IL', '5000 St Charles Rd, Bellwood, IL 60104, USA'),
  ('Sacred Heart Syro-Malabar Knanaya Catholic Forane Church, Bensenville, IL', '145 E. Grand Ave., Bensenville, IL 60106, USA'),
  ('St. Mary‚Äôs Syro-Malabar Knanaya Catholic Church, Chicago, IL', '7800 W. Lyons Street, Morton Grove, IL 60053, USA'),
  ('St. Thomas Syro-Malabar Catholic Diocese of Chicago, IL', '372 S Prairie Ave, Elmhurst, IL 60126, USA'),
  ('Divine Mercy Syro-Malabar Catholic Mission, Louisville, KY', '3926 Poplar Level Road, Louisville, KY 40213, USA'),
  ('St. Thomas Syro-Malabar Catholic Church, Boston, MA', '41 Brook St., Framingham, MA 01701, USA'),
  ('Our Lady of Perpetual Help Syro-Malabar Catholic Church, Washington, DC', '20533 Zion Rd, Gaithersburg, MD 20882, USA'),
  ('St. Alphonsa Syro-Malabar Catholic Church, Baltimore, MD', '5709 Oakland Road, Halethorpe, MD 21227, USA'),
  ('St. Mary‚Äôs Syro-Malabar Knanaya Catholic Church, Detroit, MI', '3238 Royal Ave, Berkley, MI 48072, USA'),
  ('St. Thomas Syro-Malabar Catholic Church, Detroit, MI', '17235 Mt. Vernon Street, Southfield, MI 48075, USA'),
  ('St. Alphonsa Syro-Malabar Catholic Mission, Minneapolis, MN', '651 Virginia St., St. Paul, MN 55103, USA'),
  ('St. Paul Syro-Malabar Knanaya Catholic Mission, Minneapolis, MN', '629 2nd St. NE, Minneapolis, MN 55413, USA'),
  ('Sacred Heart Syro-Malabar Catholic Mission, St. Louis, MO', '615 Dunn Rd., Hazelwood, MO 63042, USA'),
  ('St. Therese of Lisieux Syro-Malabar Catholic Mission, Kansas City, MO', '4101 E. 105th Terrace, Kansas City, MO 64137, USA'),
  ('Lourdes Matha Syro-Malabar Catholic Church, Raleigh/Durham, NC', '1400 Vision Dr, Apex, NC 27523, USA'),
  ('Our Lady of Fatima Syro-Malabar Catholic Mission, Raleigh, NC', '103 Holmhurst Ct., Cary, NC 27519, USA'),
  ('St. Mary‚Äôs Syro-Malabar Catholic Church, Charlotte, NC', '715 E Arrowood Rd, Charlotte, NC 28217, USA'),
  ('Christ the King Syro-Malabar Knanaya Catholic Church, Carteret, NJ', '67 Fitch St., Carteret, NJ 07008, USA'),
  ('St. George Syro-Malabar Catholic Church, Paterson, NJ', '408 Getty Ave., Paterson, NJ 07503, USA'),
  ('St. Jude Syro-Malabar Catholic Church, South Jersey, NJ', '250 South Route 73, Hammonton, NJ 08037, USA'),
  ('St. Thomas Syro-Malabar Catholic Forane Church, Somerset, NJ', '508 Elizabeth Avenue, Somerset, NJ 08873, USA'),
  ('St. Mother Teresa of Calcutta Syro-Malabar Catholic Church, Las Vegas, NV', '240 S. Cholla Street, Henderson, NV 89015, USA'),
  ('St. Stephen Syro-Malabar Knanaya Catholic Mission, Las Vegas, NV', '2461 E. Flamingo Rd., Las Vegas, NV 89121, USA'),
  ('Bl. Kunjachan Syro-Malabar Catholic Mission, Staten Island, NY', '463 Tompkins Ave., Staten Island, NY 10305, USA'),
  ('Holy Family Syro-Malabar Catholic Church, Rockland, NY', '5 Willow Tree Road, Monsey, NY 10952, USA'),
  ('St. Joseph Syro-Malabar Catholic Mission, Hudson Valley, NY', '3094 Albany Post Rd, Buchanan, NY 10511, USA'),
  ('St. Joseph Syro-Malabar Knanaya Catholic Mission, Westchester, NY', '18 Trinity St., Yonkers, NY 10701, USA'),
  ('St. Mary Syro-Malabar Catholic Church, Long Island, NY', '926 Round Swamp Rd, Old Bethpage, NY 11804, USA'),
  ('St. Mary‚Äôs Syro-Malabar Knanaya Catholic Church, Haverstraw, NY', '46 Conklin Ave., Haverstraw, NY 10927, USA'),
  ('St. Stephen Syro-Malabar Knanaya Catholic Forane Church, Hempstead, NY', '384 Clinton St., Hempstead, NY 11550, USA'),
  ('St. Thomas Syro-Malabar Catholic Forane Church, Bronx, NY', '810 E 221 St., Bronx, NY 10467, USA'),
  ('St. Thomas Syro-Malabar Catholic Mission, Brooklyn, NY', '198 Euclid Ave, Brooklyn, NY 11208, USA'),
  ('St. Chavara Syro-Malabar Catholic Mission, Cincinnati, OH', '7600 Winton Rd, Cincinnati, OH 45224, USA'),
  ('St. Mary Syro-Malabar Catholic Mission, Columbus, OH', '893 Hamlet St., Columbus, OH 43021, USA'),
  ('St. Raphael Syro-Malabar Catholic Mission, Cleveland, OH', '12503 Buckingham Ave, Cleveland, OH 44120, USA'),
  ('Holy Family Syro-Malabar Catholic Church, Oklahoma City, OK', '7501 NW Expressway, Oklahoma City, OK 73132, USA'),
  ('St. John Neumann Syro-Malabar Knanaya Catholic Mission, Philadelphia, PA', '1900 Meadowbrook Rd., Feasterville, PA 19053, USA'),
  ('St. Joseph Syro-Malabar Catholic Mission, Harrisburg, PA', '300 West Pine St, Palmyra, PA 17078, USA'),
  ('St. Mary‚Äôs Syro-Malabar Catholic Mission, Pittsburgh, PA', '1607 Greentree Rd., Pittsburgh, PA 15220, USA'),
  ('St. Sebastian Syro-Malabar Catholic Mission, Exton, PA', '608 Welsh Rd, Philadelphia, PA 19115, USA'),
  ('St. Thomas Syro-Malabar Catholic Forane Church, Philadelphia, PA', '608 Welsh Rd, Philadelphia, PA 19115, USA'),
  ('St. Theresa of Calcutta Syro-Malabar Catholic Mission, Nashville, TN', '1227 7th Ave., Nashville, TN 37208, USA'),
  ('Christ the King Syro-Malabar Knanaya Catholic Church, Dallas DFW, TX', '13565 Webb Chapel Rd., Farmers Branch, TX 75234, USA'),
  ('Divine Mercy Syro-Malabar Catholic Parish, Edinburg, TX', '300 W. Cano St., Edinburg, TX 78539, USA'),
  ('St. Alphonsa Syro-Malabar Catholic Church, Austin, TX', '3600 County Road 175, Leander, TX 78641, USA'),
  ('St. Alphonsa Syro-Malabar Catholic Church, Coppell, TX', '200 S Heartz Rd, Coppell, TX 75019, USA'),
  ('St. Antony Syro-Malabar Knanaya Catholic Church, San Antonio, TX', '9345 Oakland Road, San Antonio, TX 78240, USA'),
  ('St. Chavara Syro-Malabar Catholic Mission, North Houston, TX', '231 Boardwalk Parkway, Stafford, TX 77477, USA'),
  ('St. Joseph Syro-Malabar Catholic Forane Church, Houston, TX', '211 Present St, Missouri City, TX 77489, USA'),
  ('St. Mariam Thresia Syro-Malabar Mission, Dallas, TX', '8668 John Hickman Parkway Ste. 903, Frisco, TX 75034, USA'),
  ('St. Mary Syro-Malabar Catholic Church, Pearland, TX', '1610 O‚ÄôDay Rd, Pearland, TX 77581, USA'),
  ('St. Mary Syro-Malabar Knanaya Catholic Forane Church, Houston, TX', '6400 W. Fuqua Drive, Missouri City, TX 77489, USA'),
  ('St. Thomas Syro-Malabar Catholic Church, San Antonio, TX', '8333 Braun Rd, San Antonio, TX 78254, USA'),
  ('St. Thomas The Apostle Syro-Malabar Catholic Forane Church, Garland, TX', '4922 Rosehill Rd, Garland, TX 75043, USA');

-- MIGRATION: Add new columns to members table
-- Run if members table already exists:
-- alter table members drop column if exists ministry;
-- alter table members add column if not exists grade text;
-- alter table members add column if not exists years_teaching text;
-- alter table members add column if not exists parish_id integer references parishes(id) on delete set null;
-- alter table members add column if not exists parish_name text;