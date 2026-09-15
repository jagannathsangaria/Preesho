
class AppUser {
  final String id, name, mobile;
  const AppUser({required this.id, required this.name, required this.mobile});
}

class Address {
  final String id, name, mobile, address, city, pin;
  const Address({required this.id, required this.name, required this.mobile, required this.address, required this.city, required this.pin});
}

class Order {
  final String id, status;
  final double total;
  const Order({required this.id, required this.status, required this.total});
}
