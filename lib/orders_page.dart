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
  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _subscription;

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
        .where(
          'userId',
          isEqualTo: currentUser.uid,
        )
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.toList();

        list.sort(
          (a, b) => _orderDate(
            b.data(),
          ).compareTo(
            _orderDate(
              a.data(),
            ),
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
          .where(
            'userId',
            isEqualTo: currentUser.uid,
          )
          .get();

      final list = snapshot.docs.toList();

      list.sort(
        (a, b) => _orderDate(
          b.data(),
        ).compareTo(
          _orderDate(
            a.data(),
          ),
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

  DateTime _orderDate(
    Map<String, dynamic> data,
  ) {
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

  String _status(
    Map<String, dynamic> data,
  ) {
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
        return Icons.receipt_long;
      case 'Confirmed':
        return Icons.verified_outlined;
      case 'Processing':
        return Icons.settings_outlined;
      case 'Packed':
        return Icons.inventory_2_outlined;
      case 'Shipped':
        return Icons.local_shipping_outlined;
      case 'Picked by Courier':
        return Icons.delivery_dining;
      case 'Out for Delivery':
        return Icons.directions_bike_outlined;
      case 'Delivered':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel_outlined;
      case 'Returned':
        return Icons.keyboard_return;
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

    final period = date.hour >= 12
        ? 'PM'
        : 'AM';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} • '
        '$hour12:$minute $period';
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

  String _itemName(
    Map<String, dynamic> item,
  ) {
    return (
      item['name'] ??
      item['productName'] ??
      item['title'] ??
      'Product'
    ).toString();
  }

  double _itemPrice(
    Map<String, dynamic> item,
  ) {
    return _number(
      item['price'] ??
          item['salePrice'] ??
          item['amount'] ??
          0,
    );
  }

  int _itemQuantity(
    Map<String, dynamic> item,
  ) {
    final quantity = item['quantity'];

    if (quantity is num) {
      return quantity.toInt();
    }

    return int.tryParse(
          quantity?.toString() ?? '',
        ) ??
        1;
  }

  String _itemImage(
    Map<String, dynamic> item,
  ) {
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
          backgroundColor:
              error ? Colors.red : null,
          behavior: SnackBarBehavior.floating,
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

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        const reasons = [
          'Changed my mind',
          'Ordered by mistake',
          'Found a better price',
          'Delivery time is too long',
          'Want to change the order',
          'Other',
        ];

        return AlertDialog(
          title: const Text(
            'Cancel Order',
          ),
          content: const Text(
            'Please select a reason for cancellation.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
            ...reasons.map(
              (reason) => TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    reason,
                  );
                },
                child: Text(reason),
              ),
            ),
          ],
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
        throw Exception(
          'Please login again.',
        );
      }

      final ref = firestore
          .collection('orders')
          .doc(orderId);

      await firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw Exception(
              'Order not found.',
            );
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

          final history = <Map<String, dynamic>>[];

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
            'timestamp':
                FieldValue.serverTimestamp(),
            'updatedBy': 'Customer',
            'updatedByUid':
                currentUser.uid,
            'reason': reason,
          });

          transaction.update(
            ref,
            {
              'orderStatus': 'Cancelled',
              'status': 'Cancelled',
              'cancelled': true,
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

  Widget _buildTimeline(
    String currentStatus,
  ) {
    final currentIndex =
        _statusIndex(currentStatus);

    return Column(
      children: List.generate(
        statuses.length,
        (index) {
          final status = statuses[index];

          final completed =
              index <= currentIndex;

          final current =
              index == currentIndex;

          final last =
              index == statuses.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration:
                            BoxDecoration(
                          shape: BoxShape.circle,
                          color: completed
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                        ),
                        child: Icon(
                          completed
                              ? Icons.check
                              : Icons.circle_outlined,
                          size: 15,
                          color: completed
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (!last)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin:
                                const EdgeInsets.symmetric(
                              vertical: 2,
                            ),
                            color:
                                index < currentIndex
                                    ? Colors.deepPurple
                                    : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontWeight: current
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: current
                                  ? Colors.deepPurple
                                  : completed
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (current)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.deepPurple.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: const Text(
                              'NOW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Colors.deepPurple,
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
      return const Text(
        'No item details available.',
        style: TextStyle(
          color: Colors.grey,
        ),
      );
    }

    return Column(
      children: items.map(
        (item) {
          final image =
              _itemImage(item);

          final quantity =
              _itemQuantity(item);

          final price =
              _itemPrice(item);

          return Container(
            margin:
                const EdgeInsets.only(
              bottom: 10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      8,
                    ),
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
                          ),
                  ),
                ),
                const SizedBox(width: 10),
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
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: $quantity × ₹${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildCourier(
    Map<String, dynamic> data,
  ) {
    final partner =
        data['courierPartner']
                ?.toString() ??
            '';

    final name =
        data['courierPersonName']
                ?.toString() ??
            data['courierName']
                ?.toString() ??
            '';

    final phone =
        data['courierPhone']
                ?.toString() ??
            data['courierMobile']
                ?.toString() ??
            '';

    final tracking =
        data['trackingNumber']
                ?.toString() ??
            '';

    if (partner.isEmpty &&
        name.isEmpty &&
        phone.isEmpty &&
        tracking.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.delivery_dining,
                color: Colors.teal,
              ),
              SizedBox(width: 8),
              Text(
                'Courier Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (partner.isNotEmpty)
            Text(
              'Partner: $partner',
            ),

          if (name.isNotEmpty)
            Text(
              'Name: $name',
            ),

          if (phone.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Phone: $phone',
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () {
                    _copyText(
                      phone,
                      'Courier number copied.',
                    );
                  },
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 20,
                  ),
                ),
              ],
            ),

          if (tracking.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tracking: $tracking',
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () {
                    _copyText(
                      tracking,
                      'Tracking number copied.',
                    );
                  },
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 20,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
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

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      clipBehavior:
          Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            color: _statusColor(status)
                .withValues(
              alpha: 0.10,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor:
                      _statusColor(status),
                  child: Icon(
                    _statusIcon(status),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              _statusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Order',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '#${_shortOrderId(orderId)}',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  _formatDate(
                    data['createdAt'] ??
                        data['placedAt'],
                  ),
                  style:
                      const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Order Tracking',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 12),

                if (status == 'Cancelled' ||
                    status == 'Returned')
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.red.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Text(
                      status == 'Cancelled'
                          ? 'This order has been cancelled.'
                          : 'This order has been returned.',
                      style:
                          const TextStyle(
                        color: Colors.red,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  )
                else
                  _buildTimeline(status),

                const SizedBox(height: 12),

                const Divider(),

                const SizedBox(height: 8),

                const Text(
                  'Items',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 10),

                _buildOrderItems(items),

                const SizedBox(height: 8),

                _buildCourier(data),

                if (data['deliveryAddress'] !=
                    null) ...[
                  const SizedBox(height: 14),
                  _buildDeliveryAddress(data),
                ],

                if (data['paymentMethod'] !=
                    null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Payment: ${data['paymentMethod']}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],

                if (data['cancellationReason'] !=
                    null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.red.withValues(
                        alpha: 0.06,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Text(
                      'Cancellation reason: '
                      '${data['cancellationReason']}',
                    ),
                  ),
                ],

                if (_canCancel(status)) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
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
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .cancel_outlined,
                                  color: Colors.red,
                                ),
                      label: Text(
                        cancellingOrderId ==
                                orderId
                            ? 'Cancelling...'
                            : 'Cancel Order',
                        style:
                            const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['deliveryAddress'];

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

    final pincode =
        address['pincode']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (name.isNotEmpty)
            Text(name),
          if (phone.isNotEmpty)
            Text(phone),
          if (full.isNotEmpty)
            Text(full),
          if (city.isNotEmpty ||
              pincode.isNotEmpty)
            Text(
              '$city ${pincode.isNotEmpty ? '- $pincode' : ''}',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Orders',
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
      appBar: AppBar(
        title: const Text(
          'My Orders',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _refreshOrders,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : orders.isEmpty
              ? RefreshIndicator(
                  onRefresh:
                      _refreshOrders,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 180,
                      ),
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 70,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No orders yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Your placed orders will appear here.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh:
                      _refreshOrders,
                  child: ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      30,
                    ),
                    itemCount:
                        orders.length,
                    itemBuilder:
                        (context, index) {
                      return _buildOrderCard(
                        orders[index],
                      );
                    },
                  ),
                ),
    );
  }
}
