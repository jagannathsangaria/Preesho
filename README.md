
# Preesho V2 - Backend Ready

This package contains the Preesho mobile source plus a backend service interface and production setup specifications.

Already included:
- Home
- Categories
- Product catalogue
- Search
- Cart
- Address
- Login/Signup UI
- Profile
- Backend service abstraction
- Local backend implementation for development
- Admin/API specification
- Production backend/security setup notes

Still requiring your external account/configuration before a real launch:
- Firebase/Supabase project credentials
- Production database
- Real authentication
- Product/admin data
- Android signing key
- Google Play Console
- Payment gateway credentials (when enabled)

Build:
flutter pub get
flutter build apk --release
flutter build appbundle --release
