-- Run AFTER `001_reference_schema.sql` in Supabase → SQL → New query.
-- Creates private bucket `leaf-images`, RLS policies, profile trigger, sample diseases.

-- ---------------------------------------------------------------------------
-- 1) Storage bucket (private)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('leaf-images', 'leaf-images', false)
on conflict (id) do update set public = excluded.public;

-- ---------------------------------------------------------------------------
-- 2) Policies on storage.objects (paths must be: {auth.uid()}/{filename})
-- ---------------------------------------------------------------------------
drop policy if exists "leaf_images_select_own" on storage.objects;
create policy "leaf_images_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'leaf-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "leaf_images_insert_own" on storage.objects;
create policy "leaf_images_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'leaf-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "leaf_images_update_own" on storage.objects;
create policy "leaf_images_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'leaf-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'leaf-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "leaf_images_delete_own" on storage.objects;
create policy "leaf_images_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'leaf-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- 3) Auto-create public.profiles row when a user signs up
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(coalesce(new.email, 'user'), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 4) Seed disease catalog (safe to re-run — skips existing names)
-- ---------------------------------------------------------------------------
insert into public.diseases (name, description)
select v.name, v.description
from (
  values
    ('Powdery mildew', 'White fungal patches on leaf surfaces.'),
    ('Leaf rust', 'Orange or brown pustules on leaves.'),
    ('Early blight', 'Dark spots with concentric rings on older foliage.'),
    ('Bacterial leaf spot', 'Small water-soaked lesions that enlarge.'),
    ('Healthy leaf', 'No obvious disease signs — use as a reference class.')
) as v(name, description)
where not exists (
  select 1 from public.diseases d where d.name = v.name
);

-- ---------------------------------------------------------------------------
-- 5) RPC: dashboard counts (global catalog + profiles; your images only)
-- ---------------------------------------------------------------------------
create or replace function public.dashboard_stats()
returns json
language sql
security definer
set search_path = public
stable
as $$
  select json_build_object(
    'catalog_diseases', (select count(*)::int from public.diseases),
    'registered_profiles', (select count(*)::int from public.profiles),
    'my_leaf_images', (
      select count(*)::int from public.user_images where user_id = auth.uid()
    )
  );
$$;

revoke all on function public.dashboard_stats() from public;
grant execute on function public.dashboard_stats() to authenticated;
