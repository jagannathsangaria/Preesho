# Preesho V2 — APK Ready Flutter Project

Preesho is a mobile-first shopping app starter with:
- Home
- Categories
- Product catalogue
- Search
- Cart
- Delivery address form
- Login / Sign Up UI
- Profile
- Release APK GitHub Actions workflow

## Build locally

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

## Build from GitHub Actions (recommended for phone-only workflow)

1. Upload/push the whole project to the `main` branch.
2. Open **Actions** → **Build Preesho APK**.
3. Tap **Run workflow** if it has not started automatically.
4. Open the completed workflow run.
5. Under **Artifacts**, download `preesho-release-apk`.
6. Extract it and install `app-release.apk` on Android.

The workflow installs Flutter, refreshes Android platform files, runs dependency install and analysis, then builds the release APK.

## Important

This version does not include a live payment gateway. Authentication, production database, real product/admin API, Firebase/Supabase credentials, and Play Store signing configuration still need to be connected before a production commerce launch.
