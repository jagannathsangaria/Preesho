
# Preesho V2 Backend Setup

The app is now structured for a real backend.

Recommended production modules:
- Authentication: Firebase Auth or Supabase Auth
- Database: Firestore/Postgres
- Product catalogue
- Categories
- User profiles
- Saved addresses
- Cart
- Orders/order status
- Admin product management
- Push notifications
- Image storage
- Payment gateway later

Security:
- Never put API secrets, service-account JSON, payment secret keys, or signing keys in the Flutter source.
- Configure Android signing separately.
- Add server-side authorization for admin functions.
- Validate prices and order totals on the server.

Required production credentials:
1. Firebase/Supabase project
2. Android app identifier/package name
3. Authentication configuration
4. Database configuration
5. Storage configuration
6. Notification configuration

Payment gateway is intentionally not connected.
