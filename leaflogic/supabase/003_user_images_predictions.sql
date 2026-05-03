-- Run AFTER 001_reference_schema.sql and 002_storage_bucket_policies_trigger_seed.sql.
-- Adds prediction columns to user_images so the Tracker tab and per-image
-- "Classify" buttons can persist results across sessions and devices.

alter table public.user_images
  add column if not exists predicted_label text,
  add column if not exists predicted_confidence real,
  add column if not exists predicted_at timestamptz;

-- Speeds up Tracker's "predictions newest-first" query.
create index if not exists user_images_predicted_at_idx
  on public.user_images (user_id, predicted_at desc)
  where predicted_label is not null;
