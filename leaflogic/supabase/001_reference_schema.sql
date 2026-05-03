-- Reference schema for LeafLogic + Supabase.
-- Run in Supabase SQL Editor, then add Storage bucket + policies separately.

-- Profiles (1:1 with auth.users; simple "registered users" count)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id);

-- Disease catalog (minimal seed for counts; expand later per your content plan)
create table if not exists public.diseases (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

alter table public.diseases enable row level security;

create policy "diseases_select_authenticated"
  on public.diseases for select
  to authenticated
  using (true);

-- Metadata for images in Storage (private bucket paths)
create table if not exists public.user_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create index if not exists user_images_user_id_idx on public.user_images (user_id);

alter table public.user_images enable row level security;

create policy "user_images_select_own"
  on public.user_images for select
  using (auth.uid() = user_id);

create policy "user_images_insert_own"
  on public.user_images for insert
  with check (auth.uid() = user_id);

create policy "user_images_delete_own"
  on public.user_images for delete
  using (auth.uid() = user_id);

-- Example seed (optional)
-- insert into public.diseases (name, description) values
--   ('Powdery mildew', 'Fungal coating on leaf surfaces.'),
--   ('Leaf rust', 'Orange pustules on leaves.');
