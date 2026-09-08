import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CourierPanel extends StatefulWidget {
  const CourierPanel({super.key});

  @override
  State<CourierPanel> createState() => _CourierPanelState();
}

class _CourierPanelState extends State<CourierPanel> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final FirebaseFunctions _functions;

  bool _loading = false;

  final List<String> _statusFlow = const [
    'Placed',
    'Confirmed',
    'Packed',
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  }

  String get _uid => _auth.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return _firestore.collection('orders').snapshots();
  }

  bool _isAssignedToCourier(Map<String, dynamic> data) {
    if (_uid.isEmpty) return false;

    final courierId = data['courierId']?.toString() ?? '';
    final courierUid = data['courierUid']?.toString() ?? '';
    final assignedCourierId =
        data['assignedCourierId']?.toString() ?? '';

    final courierDetails = data['courierDetails'];

    String detailsUid = '';

    if (courierDetails is Map) {
      detailsUid = courierDetails['uid']?.toString() ?? '';
    }

    return courierId == _uid ||
        courierUid == _uid ||
        assignedCourierId == _uid ||
        detailsUid == _uid;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _assignedOrders(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final orders = snapshot.docs
        .where((doc) => _isAssignedToCourier(doc.data()))
        .toList();

    orders.sort((a, b) {
      final aTime = _getTimestamp(a.data()['createdAt']);
      final bTime = _getTimestamp(b.data()['createdAt']);

      return bTime.compareTo(aTime);
    });

    return orders;
  }

  DateTime _getTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String status,
  ) async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final callable =
          _functions.httpsCallable('updateCourierOrderStatus');

      await callable.call({
        'orderId': orderId,
        'status': status,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $status'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to update order status.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _orderStatus(Map<String, dynamic> data) {
    return data['status']?.toString() ?? 'Placed';
  }

  String _customerName(Map<String, dynamic> data) {
    return data['customerName']?.toString() ??
        data['userName']?.toString() ??
        data['name']?.toString() ??
        'Customer';
  }

  String _customerPhone(Map<String, dynamic> data) {
    return data['customerPhone']?.toString() ??
        data['phone']?.toString() ??
        data['mobile']?.toString() ??
        '';
  }

  String _address(Map<String, dynamic> data) {
    final address = data['shippingAddress'] ?? data['address'];

    if (address is Map) {
      final parts = <String>[
        address['name']?.toString() ?? '',
        address['address']?.toString() ?? '',
        address['addressLine1']?.toString() ?? '',
        address['addressLine2']?.toString() ?? '',
        address['city']?.toString() ?? '',
        address['state']?.toString() ?? '',
        address['pincode']?.toString() ?? '',
      ].where((e) => e.trim().isNotEmpty).toList();

      return parts.join(', ');
    }

    return address?.toString() ?? 'Address not available';
  }

  double _codAmount(Map<String, dynamic> data) {
    final value = data['codAmount'] ?? data['totalAmount'];

    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  bool _isCOD(Map<String, dynamic> data) {
    return data['isCOD'] == true ||
        data['paymentMethod']?.toString().toUpperCase() == 'COD' ||
        data['paymentType']?.toString().toLowerCase().contains('cash') ==
            true;
  }

  String _formatDate(dynamic value) {
    final date = _getTimestamp(value);

    if (date.millisecondsSinceEpoch == 0) {
      return '';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }

  int _statusIndex(String status) {
    final index = _statusFlow.indexOf(status);
    return index < 0 ? 0 : index;
  }

  String _nextStatus(String status) {
    final index = _statusIndex(status);

    if (index >= _statusFlow.length - 1) {
      return '';
    }

    return _statusFlow[index + 1];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Out for Delivery':
        return Colors.orange;
      case 'Picked by Courier':
        return Colors.indigo;
      case 'Shipped':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.indigo,
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final orderId = document.id;
    final status = _orderStatus(data);
    final nextStatus = _nextStatus(status);
    final isCOD = _isCOD(data);
    final amount = _codAmount(data);

    final customer = _customerName(data);
    final phone = _customerPhone(data);
    final address = _address(data);
    final createdAt = _formatDate(data['createdAt']);

    final items = data['items'];

    int itemCount = 0;

    if (items is List) {
      itemCount = items.length;
    }

    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (createdAt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          createdAt,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 20,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customer,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  tooltip: 'Customer phone',
                  onPressed: () {},
                  icon: const Icon(
                    Icons.phone_outlined,
                    size: 20,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              _smallInfo(
                Icons.shopping_bag_outlined,
                '$itemCount items',
              ),
              const SizedBox(width: 10),
              if (isCOD)
                _smallInfo(
                  Icons.payments_outlined,
                  'COD ₹${amount.toStringAsFixed(0)}',
                  highlight: true,
                )
              else
                _smallInfo(
                  Icons.credit_card_outlined,
                  data['paymentMethod']?.toString() ?? 'Paid',
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (status != 'Delivered' &&
              status != 'Cancelled' &&
              nextStatus.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _updateOrderStatus(
                          orderId,
                          nextStatus,
                        ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  'Mark as $nextStatus',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            )
          else if (status == 'Delivered')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Order Delivered',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          OutlinedButton(
            onPressed: () => _showOrderDetails(
              document,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                46,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              'View Order Details',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfo(
    IconData icon,
    String text, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.orange.withOpacity(.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight ? Colors.orange.shade800 : Colors.grey.shade700,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? Colors.orange.shade800
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final items = data['items'];

    final List<dynamic> itemList =
        items is List ? items : <dynamic>[];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * .82,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Order Details',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      5,
                      20,
                      30,
                    ),
                    children: [
                      _detailBox(
                        'Order ID',
                        document.id,
                      ),
                      _detailBox(
                        'Customer',
                        _customerName(data),
                      ),
                      _detailBox(
                        'Phone',
                        _customerPhone(data).isEmpty
                            ? 'Not available'
                            : _customerPhone(data),
                      ),
                      _detailBox(
                        'Address',
                        _address(data),
                      ),
                      _detailBox(
                        'Payment',
                        _isCOD(data)
                            ? 'Cash on Delivery'
                            : data['paymentMethod']?.toString() ??
                                'Paid',
                      ),
                      if (_isCOD(data))
                        _detailBox(
                          'COD Amount',
                          '₹${_codAmount(data).toStringAsFixed(2)}',
                        ),
                      _detailBox(
                        'Status',
                        _orderStatus(data),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (itemList.isEmpty)
                        const Text(
                          'No item details available.',
                        )
                      else
                        ...itemList.map(
                          (item) => _itemTile(item),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailBox(
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(dynamic item) {
    if (item is! Map) {
      return const SizedBox.shrink();
    }

    final name =
        item['name']?.toString() ??
        item['productName']?.toString() ??
        'Product';

    final quantity =
        item['quantity']?.toString() ??
        item['qty']?.toString() ??
        '1';

    final price =
        item['price'] ??
        item['sellingPrice'] ??
        item['totalPrice'] ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Colors.indigo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'x$quantity',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹$price',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Courier Panel',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await _auth.signOut();

              if (!mounted) return;

              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load orders.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final assignedOrders = snapshot.hasData
              ? _assignedOrders(snapshot.data!)
              : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final activeOrders = assignedOrders.where((doc) {
            final status = _orderStatus(doc.data());
            return status != 'Delivered' &&
                status != 'Cancelled';
          }).length;

          final deliveredOrders = assignedOrders.where((doc) {
            return _orderStatus(doc.data()) == 'Delivered';
          }).length;

          final codOrders = assignedOrders.where((doc) {
            return _isCOD(doc.data());
          }).length;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                30,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff1a237e),
                        Color(0xff3949ab),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, Courier',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage your assigned deliveries',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    _statCard(
                      'Active',
                      activeOrders.toString(),
                      Icons.local_shipping_outlined,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Delivered',
                      deliveredOrders.toString(),
                      Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'COD',
                      codOrders.toString(),
                      Icons.payments_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Assigned Orders',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${assignedOrders.length} orders',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (assignedOrders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(35),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 55,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'No orders assigned',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'New assigned orders will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...assignedOrders.map(
                    (document) => _orderCard(document),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
