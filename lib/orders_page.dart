import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  bool loading = true;
  String? cancellingOrderId;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> orders = [];

  static const List<String> statuses = [
    'Placed',
    'Confirmed',
    'Processing',
    'Packed',
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _startOrdersListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  User? get user => FirebaseAuth.instance.currentUser;

  void _startOrdersListener() {
    final currentUser = user;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          loading = false;
          orders = [];
        });
      }
      return;
    }

    _subscription?.cancel();

    _subscription = firestore
        .collection('orders')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.toList();

        list.sort(
          (a, b) => _orderDate(b.data()).compareTo(
            _orderDate(a.data()),
          ),
        );

        if (!mounted) return;

        setState(() {
          orders = list;
          loading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          loading = false;
        });

        _showMessage(
          'Unable to load orders.',
          error: true,
        );
      },
    );
  }

  Future<void> _refreshOrders() async {
    final currentUser = user;

    if (currentUser == null) return;

    try {
      final snapshot = await firestore
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final list = snapshot.docs.toList();

      list.sort(
        (a, b) => _orderDate(b.data()).compareTo(
          _orderDate(a.data()),
        ),
      );

      if (!mounted) return;

      setState(() {
        orders = list;
        loading = false;
      });
    } catch (_) {
      _showMessage(
        'Unable to refresh orders.',
        error: true,
      );
    }
  }

  DateTime _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _orderDate(Map<String, dynamic> data) {
    return _timestampToDate(
      data['createdAt'] ??
          data['placedAt'] ??
          data['updatedAt'],
    );
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '') ?? '',
        ) ??
        0;
  }

  String _status(Map<String, dynamic> data) {
    final value =
        data['orderStatus'] ??
        data['status'] ??
        'Placed';

    final text = value.toString().trim();

    if (text.isEmpty) {
      return 'Placed';
    }

    for (final status in statuses) {
      if (status.toLowerCase() == text.toLowerCase()) {
        return status;
      }
    }

    return text;
  }

  int _statusIndex(String status) {
    final index = statuses.indexWhere(
      (value) =>
          value.toLowerCase() ==
          status.toLowerCase(),
    );

    return index < 0 ? 0 : index;
  }

  bool _canCancel(String status) {
    final value = status.toLowerCase();

    return value == 'placed' ||
        value == 'confirmed' ||
        value == 'processing';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Confirmed':
        return Colors.indigo;
      case 'Processing':
        return Colors.orange;
      case 'Packed':
        return Colors.deepOrange;
      case 'Shipped':
        return Colors.purple;
      case 'Picked by Courier':
        return Colors.teal;
      case 'Out for Delivery':
        return Colors.green;
      case 'Delivered':
        return Colors.green.shade700;
      case 'Cancelled':
        return Colors.red;
      case 'Returned':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.receipt_long_rounded;
      case 'Confirmed':
        return Icons.verified_rounded;
      case 'Processing':
        return Icons.settings_rounded;
      case 'Packed':
        return Icons.inventory_2_rounded;
      case 'Shipped':
        return Icons.local_shipping_rounded;
      case 'Picked by Courier':
        return Icons.delivery_dining_rounded;
      case 'Out for Delivery':
        return Icons.directions_bike_rounded;
      case 'Delivered':
        return Icons.check_circle_rounded;
      case 'Cancelled':
        return Icons.cancel_rounded;
      case 'Returned':
        return Icons.keyboard_return_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  String _formatDate(dynamic value) {
    final date = _timestampToDate(value);

    if (date.millisecondsSinceEpoch == 0) {
      return 'Date unavailable';
    }

    final hour12 = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} • $hour12:$minute $period';
  }

  String _shortOrderId(String id) {
    if (id.length <= 10) return id;
    return id.substring(0, 10);
  }

  List<Map<String, dynamic>> _items(
    Map<String, dynamic> data,
  ) {
    final raw = data['items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  String _itemName(Map<String, dynamic> item) {
    return (
      item['name'] ??
      item['productName'] ??
      item['title'] ??
      'Product'
    ).toString();
  }

  double _itemPrice(Map<String, dynamic> item) {
    return _number(
      item['price'] ??
          item['salePrice'] ??
          item['amount'] ??
          0,
    );
  }

  int _itemQuantity(Map<String, dynamic> item) {
    final quantity = item['quantity'];

    if (quantity is num) {
      return quantity.toInt();
    }

    return int.tryParse(
          quantity?.toString() ?? '',
        ) ??
        1;
  }

  String _itemImage(Map<String, dynamic> item) {
    return (
      item['imageUrl'] ??
      item['image'] ??
      item['productImage'] ??
      ''
    ).toString();
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : null,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _copyText(
    String text,
    String message,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: text),
    );

    _showMessage(message);
  }

  Future<void> _cancelOrder(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final status = _status(data);

    if (!_canCancel(status)) {
      _showMessage(
        'This order can no longer be cancelled.',
        error: true,
      );
      return;
    }

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        const reasons = [
          'Changed my mind',
          'Ordered by mistake',
          'Found a better price',
          'Delivery time is too long',
          'Want to change the order',
          'Other',
        ];

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Cancel Order',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Please select a reason',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map(
                    (reason) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(
                        reason,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context, reason);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (reason == null || reason.isEmpty) {
      return;
    }

    setState(() {
      cancellingOrderId = orderId;
    });

    try {
      final currentUser = user;

      if (currentUser == null) {
        throw Exception('Please login again.');
      }

      final ref = firestore
          .collection('orders')
          .doc(orderId);

      await firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw Exception('Order not found.');
          }

          final freshData = snapshot.data();

          if (freshData == null) {
            throw Exception(
              'Order data unavailable.',
            );
          }

          final owner =
              freshData['userId']?.toString();

          if (owner != currentUser.uid) {
            throw Exception(
              'You cannot cancel this order.',
            );
          }

          final freshStatus =
              _status(freshData);

          if (!_canCancel(freshStatus)) {
            throw Exception(
              'This order can no longer be cancelled.',
            );
          }

          final existingHistory =
              freshData['statusHistory'];

          final history =
              <Map<String, dynamic>>[];

          if (existingHistory is List) {
            for (final entry in existingHistory) {
              if (entry is Map) {
                history.add(
                  Map<String, dynamic>.from(entry),
                );
              }
            }
          }

          history.add({
            'status': 'Cancelled',
            'timestamp': Timestamp.now(),
            'updatedBy': 'Customer',
            'updatedByUid': currentUser.uid,
            'reason': reason,
          });

          transaction.update(
            ref,
            {
              'orderStatus': 'Cancelled',
              'status': 'Cancelled',
              'cancelled': true,
              'isCancelled': true,
              'cancellationReason': reason,
              'cancelledAt':
                  FieldValue.serverTimestamp(),
              'cancelledBy': 'Customer',
              'cancelledByUid':
                  currentUser.uid,
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'statusHistory': history,
            },
          );
        },
      );

      _showMessage(
        'Order cancelled successfully.',
      );
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          cancellingOrderId = null;
        });
      }
    }
  }

  Widget _buildTimeline(String currentStatus) {
    final currentIndex =
        _statusIndex(currentStatus);

    return Column(
      children: List.generate(
        statuses.length,
        (index) {
          final status = statuses[index];
          final completed = index <= currentIndex;
          final current = index == currentIndex;
          final last = index == statuses.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: completed
                              ? _statusColor(currentStatus)
                              : Colors.grey.shade200,
                        ),
                        child: Icon(
                          completed
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 16,
                          color: completed
                              ? Colors.white
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (!last)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin:
                                const EdgeInsets.symmetric(
                              vertical: 3,
                            ),
                            color: index < currentIndex
                                ? _statusColor(currentStatus)
                                : Colors.grey.shade200,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: current
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: current
                                  ? _statusColor(currentStatus)
                                  : completed
                                      ? Colors.black87
                                      : Colors.grey.shade500,
                            ),
                          ),
                        ),
                        if (current)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(
                                currentStatus,
                              ).withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              'CURRENT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _statusColor(
                                  currentStatus,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderItems(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No item details available.',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        final image = _itemImage(item);
        final quantity = _itemQuantity(item);
        final price = _itemPrice(item);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(14),
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stack) {
                            return Container(
                              color: Colors.grey.shade100,
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _itemName(item),
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Qty $quantity × ₹${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${(price * quantity).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCourier(
    Map<String, dynamic> data,
  ) {
    final partner =
        data['courierPartner']?.toString() ?? '';

    final name =
        data['courierPersonName']?.toString() ??
            data['courierName']?.toString() ??
            '';

    final phone =
        data['courierPhone']?.toString() ??
            data['courierMobile']?.toString() ??
            '';

    final tracking =
        data['trackingNumber']?.toString() ?? '';

    final trackingId =
        data['trackingId']?.toString() ?? '';

    final trackingValue =
        tracking.isNotEmpty ? tracking : trackingId;

    if (partner.isEmpty &&
        name.isEmpty &&
        phone.isEmpty &&
        trackingValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withValues(alpha: 0.12),
            Colors.teal.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.delivery_dining_rounded,
                color: Colors.teal,
              ),
              SizedBox(width: 9),
              Text(
                'Courier Details',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (partner.isNotEmpty)
            _infoRow(
              Icons.business_rounded,
              'Partner',
              partner,
            ),
          if (name.isNotEmpty)
            _infoRow(
              Icons.person_outline_rounded,
              'Courier',
              name,
            ),
          if (phone.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: _infoRow(
                    Icons.phone_outlined,
                    'Phone',
                    phone,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _copyText(
                      phone,
                      'Courier number copied.',
                    );
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 19,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          if (trackingValue.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: _infoRow(
                    Icons.qr_code_2_rounded,
                    'Tracking',
                    trackingValue,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _copyText(
                      trackingValue,
                      'Tracking number copied.',
                    );
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 19,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.teal,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress(
    Map<String, dynamic> data,
  ) {
    final raw = data['deliveryAddress'];

    if (raw is! Map) {
      return const SizedBox.shrink();
    }

    final address =
        Map<String, dynamic>.from(raw);

    final name =
        address['name']?.toString() ?? '';

    final phone =
        address['phone']?.toString() ?? '';

    final full =
        address['fullAddress']?.toString() ??
            address['street']?.toString() ??
            '';

    final city =
        address['city']?.toString() ?? '';

    final state =
        address['state']?.toString() ?? '';

    final pincode =
        address['pincode']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.indigo.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: Colors.indigo,
              ),
              SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (name.isNotEmpty)
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          if (phone.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(top: 3),
              child: Text(phone),
            ),
          if (full.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(top: 5),
              child: Text(
                full,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ),
          if (city.isNotEmpty ||
              state.isNotEmpty ||
              pincode.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(top: 3),
              child: Text(
                [
                  city,
                  state,
                  pincode,
                ]
                    .where((e) => e.isNotEmpty)
                    .join(' • '),
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    QueryDocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final data = document.data();
    final orderId = document.id;
    final status = _status(data);

    final total = _number(
      data['total'] ??
          data['grandTotal'] ??
          data['amount'] ??
          data['totalAmount'] ??
          0,
    );

    final items = _items(data);
    final itemCount = items.fold<int>(
      0,
      (sum, item) =>
          sum + _itemQuantity(item),
    );

    final isCod =
        data['isCOD'] == true ||
        data['paymentMethod']
                ?.toString()
                .toUpperCase() ==
            'COD' ||
        data['paymentType']
                ?.toString()
                .toLowerCase()
                .contains('cash') ==
            true;

    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.13),
                    color.withValues(alpha: 0.035),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _statusIcon(status),
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORDER STATUS',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.1,
                            fontWeight:
                                FontWeight.w800,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusBadge(status),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius:
                        BorderRadius.circular(12),
                    onTap: () {
                      _copyText(
                        orderId,
                        'Order ID copied.',
                      );
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            '#${_shortOrderId(orderId)}',
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'COPY',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _summaryBox(
                          Icons.calendar_today_rounded,
                          'ORDERED',
                          _formatDate(
                            data['createdAt'] ??
                                data['placedAt'],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryBox(
                          Icons.shopping_bag_rounded,
                          'ITEMS',
                          '$itemCount item${itemCount == 1 ? '' : 's'}',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple
                                .withValues(
                              alpha: 0.10,
                            ),
                            borderRadius:
                                BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL AMOUNT',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  fontWeight:
                                      FontWeight.w700,
                                  letterSpacing: .7,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₹${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCod)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green
                                  .withValues(
                                alpha: 0.10,
                              ),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons
                                      .payments_rounded,
                                  size: 15,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'COD',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (items.isNotEmpty)
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection:
                            Axis.horizontal,
                        itemCount: items.length > 5
                            ? 5
                            : items.length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(width: 8),
                        itemBuilder:
                            (context, index) {
                          final image =
                              _itemImage(
                            items[index],
                          );

                          return Container(
                            width: 72,
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.grey.shade100,
                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                            ),
                            clipBehavior:
                                Clip.antiAlias,
                            child: image.isNotEmpty
                                ? Image.network(
                                    image,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                      context,
                                      error,
                                      stack,
                                    ) {
                                      return const Icon(
                                        Icons
                                            .shopping_bag_outlined,
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons
                                        .shopping_bag_outlined,
                                    color: Colors.grey,
                                  ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showOrderDetails(
                              document,
                            );
                          },
                          icon: const Icon(
                            Icons.visibility_rounded,
                            size: 18,
                          ),
                          label:
                              const Text('VIEW DETAILS'),
                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                Colors.deepPurple,
                            side: BorderSide(
                              color: Colors.deepPurple
                                  .withValues(
                                alpha: 0.25,
                              ),
                            ),
                            minimumSize:
                                const Size(0, 48),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            _showTracking(
                              document,
                            );
                          },
                          icon: const Icon(
                            Icons.route_rounded,
                            size: 18,
                          ),
                          label:
                              const Text('TRACK ORDER'),
                          style:
                              FilledButton.styleFrom(
                            backgroundColor:
                                Colors.deepPurple,
                            minimumSize:
                                const Size(0, 48),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_canCancel(status))
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton.icon(
                          onPressed:
                              cancellingOrderId ==
                                      orderId
                                  ? null
                                  : () =>
                                      _cancelOrder(
                                        orderId,
                                        data,
                                      ),
                          icon:
                              cancellingOrderId ==
                                      orderId
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.red,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .cancel_outlined,
                                      size: 18,
                                    ),
                          label: Text(
                            cancellingOrderId ==
                                    orderId
                                ? 'Cancelling...'
                                : 'Cancel Order',
                          ),
                          style:
                              TextButton.styleFrom(
                            foregroundColor:
                                Colors.red,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (status == 'Cancelled' ||
                      status == 'Returned')
                    Container(
                      width: double.infinity,
                      margin:
                          const EdgeInsets.only(top: 10),
                      padding:
                          const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(
                          alpha: 0.06,
                        ),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.red,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status == 'Cancelled'
                                  ? 'This order has been cancelled.'
                                  : 'This order has been returned.',
                              style:
                                  const TextStyle(
                                color: Colors.red,
                                fontWeight:
                                    FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.deepPurple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTracking(
    QueryDocumentSnapshot<Map<String, dynamic>>
        document,
  ) async {
    final data = document.data();
    final status = _status(data);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                    .82,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                25,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Track Your Order',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '#${_shortOrderId(document.id)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildStatusBadge(status),
                  const SizedBox(height: 22),
                  if (status == 'Cancelled' ||
                      status == 'Returned')
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(
                          alpha: 0.07,
                        ),
                        borderRadius:
                            BorderRadius.circular(18),
                      ),
                      child: Text(
                        status == 'Cancelled'
                            ? 'This order has been cancelled.'
                            : 'This order has been returned.',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    _buildTimeline(status),
                  const SizedBox(height: 12),
                  _buildCourier(data),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOrderDetails(
    QueryDocumentSnapshot<Map<String, dynamic>>
        document,
  ) async {
    final data = document.data();

    final items = _items(data);

    final total = _number(
      data['total'] ??
          data['grandTotal'] ??
          data['amount'] ??
          data['totalAmount'] ??
          0,
    );

    final payment =
        data['paymentType']?.toString() ??
            data['paymentMethod']?.toString() ??
            'COD';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                    .90,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                30,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Order Details',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _copyText(
                            document.id,
                            'Order ID copied.',
                          );
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${document.id}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _detailSection(
                    title: 'Order Summary',
                    icon: Icons.receipt_long_rounded,
                    child: Column(
                      children: [
                        _detailRow(
                          'Status',
                          _status(data),
                        ),
                        _detailRow(
                          'Order Date',
                          _formatDate(
                            data['createdAt'] ??
                                data['placedAt'],
                          ),
                        ),
                        _detailRow(
                          'Items',
                          '${data['totalItems'] ?? items.length}',
                        ),
                        _detailRow(
                          'Payment',
                          payment,
                        ),
                        _detailRow(
                          'Total',
                          '₹${total.toStringAsFixed(0)}',
                          bold: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  _detailSection(
                    title: 'Items',
                    icon: Icons.shopping_bag_rounded,
                    child:
                        _buildOrderItems(items),
                  ),

                  const SizedBox(height: 14),

                  _buildDeliveryAddress(data),

                  const SizedBox(height: 14),

                  _buildCourier(data),

                  if (data['cancellationReason'] !=
                          null &&
                      data['cancellationReason']
                          .toString()
                          .isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 14),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color:
                              Colors.red.withValues(
                            alpha: 0.06,
                          ),
                          borderRadius:
                              BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Cancellation reason: '
                          '${data['cancellationReason']}',
                          style:
                              const TextStyle(
                            color: Colors.red,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.deepPurple,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold
                    ? FontWeight.w900
                    : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final activeCount = orders.where((document) {
      final status = _status(document.data());
      return status != 'Delivered' &&
          status != 'Cancelled' &&
          status != 'Returned';
    }).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff5B21B6),
            Color(0xff7C3AED),
            Color(0xff9333EA),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(
              alpha: 0.22,
            ),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeCount == 0
                      ? 'All caught up!'
                      : '$activeCount active order${activeCount == 1 ? '' : 's'} on the way',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.82,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.14,
              ),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  '${orders.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'ORDERS',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.75,
                    ),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(
                  alpha: 0.07,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 60,
                color: Colors.deepPurple,
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Center(
            child: Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 35,
              ),
              child: Text(
                'Your placed orders will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 17,
                    color: Colors.green,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Secure COD available',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xffF7F7FA),
        appBar: AppBar(
          title: const Text(
            'My Orders',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Please login to view your orders.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF7F7FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xffF7F7FA),
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshOrders,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
              ),
            )
          : orders.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: Colors.deepPurple,
                  onRefresh: _refreshOrders,
                  child: ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      bottom: 30,
                    ),
                    itemCount: orders.length + 1,
                    itemBuilder:
                        (context, index) {
                      if (index == 0) {
                        return _buildHeader();
                      }

                      return _buildOrderCard(
                        orders[index - 1],
                      );
                    },
                  ),
                ),
    );
  }
}
