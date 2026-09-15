
/// Production backend interface.
/// Connect this interface to Firebase/Supabase/API after project credentials are supplied.
abstract class BackendService {
  Future<void> signIn(String mobile, String password);
  Future<void> signOut();
  Future<List<Map<String, dynamic>>> products();
  Future<void> saveAddress(Map<String, dynamic> address);
  Future<void> createOrder(Map<String, dynamic> order);
  Future<List<Map<String, dynamic>>> orders();
}

/// Local development implementation so the UI can be tested before a real backend is connected.
class LocalBackendService implements BackendService {
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _addresses = [];

  @override
  Future<void> signIn(String mobile, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<List<Map<String, dynamic>>> products() async => [];

  @override
  Future<void> saveAddress(Map<String, dynamic> address) async => _addresses.add(address);

  @override
  Future<void> createOrder(Map<String, dynamic> order) async => _orders.add(order);

  @override
  Future<List<Map<String, dynamic>>> orders() async => List.unmodifiable(_orders);
}
