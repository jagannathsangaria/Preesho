
# Preesho Admin/API Specification

Suggested endpoints:
GET    /products
POST   /products
PUT    /products/:id
DELETE /products/:id
GET    /categories
POST   /categories
POST   /auth/login
POST   /auth/signup
GET    /users/me
GET    /addresses
POST   /addresses
PUT    /addresses/:id
DELETE /addresses/:id
POST   /cart
GET    /cart
POST   /orders
GET    /orders
GET    /orders/:id
PUT    /orders/:id/status

Admin roles:
- admin: products, categories, orders, users
- staff: orders and catalogue operations as permitted
- customer: own profile, addresses, cart and orders

Order statuses:
pending -> confirmed -> packed -> shipped -> delivered
Cancellation/refund should be handled by server-side business rules.
