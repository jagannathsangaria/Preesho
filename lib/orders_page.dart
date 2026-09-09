import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Order Placed';
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Shipped';
      case 'out_for_delivery':
      case 'out for delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status.isEmpty ? 'Pending' : status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.receipt_long;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'processing':
        return Icons.settings_outlined;
      case 'packed':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'out_for_delivery':
      case 'out for delivery':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return Colors.red;
      case 'shipped':
      case 'out_for_delivery':
      case 'out for delivery':
        return Colors.blue;
      case 'confirmed':
      case 'packed':
        return Colors.teal;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.deepOrange;
    }
  }

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return 'Date not available';
    }

    final localDate = date.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    int hour = localDate.hour;
    final minute = localDate.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '${localDate.day} ${months[localDate.month - 1]} '
        '${localDate.year}, '
        '$hour:$minute $period';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  String _money(dynamic value) {
    final amount = _toDouble(value);

    if (amount == amount.roundToDouble()) {
      return '₹${amount.toInt()}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
        ),
        body: const Center(
          child: Text(
            'Please login to view your orders.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('orders')
            .where(
              'customerId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _errorView(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents =
              snapshot.data?.docs.toList() ?? [];

          documents.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final aDate = _dateValue(aData['createdAt']);
            final bDate = _dateValue(bData['createdAt']);

            return bDate.compareTo(aDate);
          });

          if (documents.isEmpty) {
            return _emptyOrdersView();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(
                const Duration(milliseconds: 500),
              );
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                24,
              ),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final order = documents[index];

                return _OrderCard(
                  data: order.data(),
                  orderId: order.id,
                  statusText: _statusText,
                  statusIcon: _statusIcon,
                  statusColor: _statusColor,
                  formatDate: _formatDate,
                  money: _money,
                  items: _items,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsPage(
                          data: order.data(),
                          orderId: order.id,
                          statusText: _statusText,
                          statusIcon: _statusIcon,
                          statusColor: _statusColor,
                          formatDate: _formatDate,
                          money: _money,
                          items: _items,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _emptyOrdersView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 50,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your placed orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.red,
            ),
            const SizedBox(height: 15),
            const Text(
              'Unable to load orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;

  final String Function(String) statusText;
  final IconData Function(String) statusIcon;
  final Color Function(String) statusColor;
  final String Function(dynamic) formatDate;
  final String Function(dynamic) money;
  final List<Map<String, dynamic>> Function(dynamic) items;
  final VoidCallback onTap;

  const _OrderCard({
    required this.data,
    required this.orderId,
    required this.statusText,
    required this.statusIcon,
    required this.statusColor,
    required this.formatDate,
    required this.money,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        (data['status'] ??
                data['orderStatus'] ??
                'pending')
            .toString();

    final itemList = items(data['items']);

    final totalQuantity =
        data['totalQuantity'] ??
        data['itemCount'] ??
        itemList.fold<int>(
          0,
          (sum, item) =>
              sum +
              ((item['quantity'] as num?)?.toInt() ?? 1),
        );

    final amount =
        data['totalAmount'] ??
        data['total'] ??
        0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${orderId.length > 12 ? orderId.substring(0, 12) : orderId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(data['createdAt']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusColor(status).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon(status),
                      size: 17,
                      color: statusColor(status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText(status),
                      style: TextStyle(
                        color: statusColor(status),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalQuantity item${totalQuantity == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    money(amount),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Divider(height: 1),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Details',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;

  final String Function(String) statusText;
  final IconData Function(String) statusIcon;
  final Color Function(String) statusColor;
  final String Function(dynamic) formatDate;
  final String Function(dynamic) money;
  final List<Map<String, dynamic>> Function(dynamic) items;

  const OrderDetailsPage({
    super.key,
    required this.data,
    required this.orderId,
    required this.statusText,
    required this.statusIcon,
    required this.statusColor,
    required this.formatDate,
    required this.money,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        (data['status'] ??
                data['orderStatus'] ??
                'pending')
            .toString();

    final itemList = items(data['items']);

    final deliveryAddress =
        data['deliveryAddress'] is Map
            ? Map<String, dynamic>.from(
                data['deliveryAddress'],
              )
            : <String, dynamic>{};

    final subtotal = data['subtotal'] ?? 0;
    final originalTotal =
        data['originalTotal'] ?? subtotal;
    final productSavings =
        data['productSavings'] ?? 0;
    final deliveryCharge =
        data['deliveryCharge'] ?? 0;
    final totalAmount =
        data['totalAmount'] ?? subtotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor(status)
                            .withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        statusIcon(status),
                        color: statusColor(status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText(status),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  statusColor(status),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDate(data['createdAt']),
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  'Order ID',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  orderId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _sectionCard(
            title: 'Order Items',
            child: itemList.isEmpty
                ? const Text(
                    'No item details available.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0;
                          i < itemList.length;
                          i++) ...[
                        _OrderItem(
                          item: itemList[i],
                          money: money,
                        ),
                        if (i != itemList.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          _sectionCard(
            title: 'Delivery Address',
            child: deliveryAddress.isEmpty
                ? const Text(
                    'Address information not available.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  )
                : Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        (deliveryAddress['name'] ??
                                data['customerName'] ??
                                '')
                            .toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if ((deliveryAddress['mobile'] ??
                              data['customerMobile'] ??
                              '')
                          .toString()
                          .isNotEmpty)
                        Text(
                          (deliveryAddress['mobile'] ??
                                  data['customerMobile'] ??
                                  '')
                              .toString(),
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          deliveryAddress['address'],
                          deliveryAddress['city'],
                          deliveryAddress['state'],
                          deliveryAddress['pinCode'],
                        ]
                            .where(
                              (e) =>
                                  e != null &&
                                  e.toString().trim().isNotEmpty,
                            )
                            .join(', '),
                        style: const TextStyle(
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          _sectionCard(
            title: 'Payment',
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.10),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash on Delivery',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Pay when your order is delivered',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  (data['paymentStatus'] ?? 'pending')
                      .toString()
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _sectionCard(
            title: 'Price Details',
            child: Column(
              children: [
                _priceRow(
                  'MRP',
                  money(originalTotal),
                ),
                const SizedBox(height: 10),
                _priceRow(
                  'Product Discount',
                  '- ${money(productSavings)}',
                  valueColor: Colors.green,
                ),
                const SizedBox(height: 10),
                _priceRow(
                  'Delivery',
                  _toDouble(deliveryCharge) == 0
                      ? 'FREE'
                      : money(deliveryCharge),
                  valueColor: Colors.green,
                ),
                const Divider(height: 24),
                _priceRow(
                  'Total Amount',
                  money(totalAmount),
                  bold: true,
                  fontSize: 18,
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  Widget _sectionCard({
    String? title,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _priceRow(
    String title,
    String value, {
    Color? valueColor,
    bool bold = false,
    double fontSize = 14,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight:
                bold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight:
                bold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}

class _OrderItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) money;

  const _OrderItem({
    required this.item,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        (item['name'] ??
                item['Name'] ??
                item['productName'] ??
                'Product')
            .toString();

    final quantity =
        (item['quantity'] as num?)?.toInt() ??
        int.tryParse(
          (item['quantity'] ?? '1').toString(),
        ) ??
        1;

    final price =
        item['price'] ??
        item['numericPrice'] ??
        item['unitPrice'] ??
        0;

    final totalPrice =
        item['totalPrice'] ??
        item['total'] ??
        (_toDouble(price) * quantity);

    final imageUrl =
        (item['imageUrl'] ??
                item['Imageurl'] ??
                item['ImageUrl'] ??
                '')
            .toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      );
                    },
                  ),
                )
              : const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.grey,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Qty: $quantity',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                money(price),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          money(totalPrice),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }
}
