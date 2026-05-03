# LeafLogic — build checklist (ordered)

Work top to bottom. Check items off as you complete each module. The Flutter app lives in `leaflogic/`.

---

## Phase 0 — Scaffold (done)

- [x] Flutter project `leaflogic` (Android), package `com.leaflogic.leaflogic`
- [x] Dependencies: `supabase_flutter`, `go_router`, `google_sign_in`, `image_picker`
- [x] Navigation shell: Dashboard · Library · Scan
- [x] Placeholder screens + compile-time Supabase config (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- [x] `AndroidManifest.xml`: `INTERNET`, `CAMERA`; app label **LeafLogic**

---

## Phase 1 — Supabase project

- [ ] Create a project at [https://supabase.com](https://supabase.com)
- [ ] Copy **Project URL** and **anon public** key (Settings → API)
- [ ] Run locally:  
  `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`  
  (or add the same defines to your IDE run configuration)

---

## Phase 2 — Database schema + RLS

- [ ] In Supabase **SQL Editor**, run **`leaflogic/supabase/001_reference_schema.sql`** (tables + table RLS only)
- [ ] Then run **`leaflogic/supabase/002_storage_bucket_policies_trigger_seed.sql`** (private bucket `leaf-images`, Storage RLS, `profiles` trigger on signup, sample diseases, `dashboard_stats` RPC)
- [ ] Confirm tables: `profiles`, `diseases`, `user_images`
- [ ] **Authentication → Policies** (optional): table RLS is already in `001`; Storage policies are in `002`
- [ ] **Deferred (you asked to remember):** full disease/treatment editorial plan — revisit when you design content (seed rows come from `002`)

---

## Phase 3 — Storage (leaf images)

- [ ] Covered by **`002_...sql`** (`leaf-images` bucket + path rule `{user_id}/{filename}`)
- [ ] In **Storage → leaf-images**, confirm the bucket exists and is **not** public
- [ ] Free tier: fine for coursework; compress or resize if you hit quotas

---

## Phase 4 — Email authentication

- [ ] Supabase **Authentication → Providers → Email**: enable; set “Confirm email” as needed for class demos
- [ ] Wire `LoginScreen`: `signUp` / `signInWithPassword`, loading/error UI, navigate on session
- [ ] Optional: **Database → Triggers** or signup flow to insert `profiles` row for new `auth.users`

---

## Phase 5 — Google Sign-In (Android)

- [ ] Google Cloud Console: OAuth client **Android** (package `com.leaflogic.leaflogic`, SHA-1 from debug keystore)
- [ ] OAuth client **Web** for Supabase Google provider (Client ID + Secret in Supabase)
- [ ] Supabase Auth URL / redirect settings per [Supabase Flutter Google guide](https://supabase.com/docs/guides/auth/social-login/auth-google?platform=flutter)
- [ ] Wire `LoginScreen` Google button: `signInWithOAuth` / PKCE flow for Android

---

## Phase 6 — Capture module

- [ ] Request runtime **camera** (and gallery) permissions on Android
- [ ] Implement **Take photo** / **Choose from gallery** with `image_picker` (or `camera` + preview if you upgrade the scaffold)
- [ ] Optional: leaf **framing overlay** on live preview (proposal alignment)
- [ ] Upload bytes to Storage at `{user_id}/{uuid}.jpg` (or `.webp`)
- [ ] Insert `user_images` row with `storage_path`, `user_id`, timestamps

---

## Phase 7 — Library module

- [ ] Query `user_images` for `auth.uid()`
- [ ] Resolve thumbnails: **signed URLs** or **public** transformed URLs per your bucket policy
- [ ] Grid or list UI; empty / error / loading states
- [ ] Tap → detail (optional midterm)

---

## Phase 8 — Dashboard module

- [ ] Fetch counts: total **user** images (global or per user — pick one and label the card), `diseases` count, `profiles` count
- [ ] Replace `—` placeholders with live numbers (pull-to-refresh optional)
- [ ] Wire **Sign out** → `signOut()` and router refresh

---

## Phase 9 — Diagnostics (stub → real)

- [ ] **Stub:** show last scan from DB or placeholder species/disease/confidence until ML exists
- [ ] **TFLite path (later):** add `tflite_flutter`, bundle `.tflite` + `labels.txt`, preprocess to model input, run interpreter, map argmax to label; then persist prediction on `user_images` or a `scans` table
- [ ] Keep UI truthful: only show “confidence” when a real model or API produced it

---

## Phase 10 — Hardening & handoff

- [ ] Never commit anon key in git; use `--dart-define` or CI secrets
- [ ] `flutter analyze` / `flutter test` clean before submission
- [ ] **iOS** (when you expand): new bundle id, `GoogleService` / OAuth iOS client, permissions in `Info.plist`
- [ ] **Offline / SQLite** (proposal §6): optional later — local cache of recent scans + sync rules

---

## Phase 11 — Backend API (proposal §5)

- [ ] **FastAPI** + model hosting when the course requires server-side inference or shared training pipelines — not required for the current Flutter+Supabase milestone

---

### Quick commands

```text
cd leaflogic
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

---

### Dependency note

If `flutter pub get` warns about pub.dev advisories decoding, it is a tooling/pub.dev quirk; dependencies still resolved. Upgrade Flutter/SDK when convenient.
