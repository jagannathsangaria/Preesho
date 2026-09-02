import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../checkout_page.dart';
import '../login_page.dart';
import '../orders_page.dart';
import 'cart_controller.dart';

// ============================================================
// ORDER TRACKING CONSTANTS
// ============================================================

const List<String> activeOrderStatuses = [
  'Placed',
  'Confirmed',
  'Processing',
  'Packed',
  'Shipped',
  'Picked by Courier',
  'Out for Delivery',
];

const List<String> fullOrderStatuses = [
  'Placed',
  'Confirmed',
  'Processing',
  'Packed',
  'Shipped',
  'Picked by Courier',
  'Out for Delivery',
  'Delivered',
];

// ============================================================
// ACTIVE ORDER TRACKING
// ============================================================

class ActiveOrderTracking extends StatelessWidget {
  const ActiveOrderTracking({
    super.key,
  });

  String normalizeStatus(
    Map<String, dynamic> data,
  ) {
    final value =
        data['orderStatus'] ??
        data['status'] ??
        'Placed';

    final status = value.toString().trim();

    if (status.isEmpty) {
      return 'Placed';
    }

    return status;
  }

  DateTime? timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  DateTime orderDate(
    Map<String, dynamic> data,
  ) {
    final created =
        timestampToDate(data['createdAt']);

    final placed =
        timestampToDate(data['placedAt']);

    return created ??
        placed ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int statusIndex(String status) {
    final index =
        fullOrderStatuses.indexOf(status);

    return index < 0 ? 0 : index;
  }

  bool isActive(String status) {
    return activeOrderStatuses.contains(status);
  }

  Color statusColor(String status) {
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
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
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
      default:
        return Icons.circle_outlined;
    }
  }

  String shortOrderId(String id) {
    if (id.length <= 10) {
      return id;
    }

    return id.substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where(
            'userId',
            isEqualTo: user.uid,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              4,
            ),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Checking active orders...',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        final activeOrders = docs
            .map(
              (doc) => MapEntry(
                doc.id,
                doc.data(),
              ),
            )
            .where(
              (entry) =>
                  isActive(
                    normalizeStatus(entry.value),
                  ),
            )
            .toList();

        activeOrders.sort(
          (a, b) => orderDate(b.value)
              .compareTo(
                orderDate(a.value),
              ),
        );

        if (activeOrders.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            4,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Active Order Tracking',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ...activeOrders.map(
                (entry) => _buildOrderCard(
                  context,
                  entry.key,
                  entry.value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final currentStatus =
        normalizeStatus(data);

    final currentIndex =
        statusIndex(currentStatus);

    final total =
        data['total'] ??
        data['grandTotal'] ??
        data['amount'] ??
        data['totalAmount'] ??
        0;

    final courierName =
        data['courierPersonName']?.toString() ??
        data['courierName']?.toString() ??
        '';

    final courierMobile =
        data['courierPhone']?.toString() ??
        data['courierMobile']?.toString() ??
        '';

    final courierPartner =
        data['courierPartner']?.toString() ?? '';

    final trackingNumber =
        data['trackingNumber']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: statusColor(
              currentStatus,
            ).withOpacity(0.10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor:
                      statusColor(currentStatus),
                  child: Icon(
                    statusIcon(currentStatus),
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
                      const SizedBox(height: 2),
                      Text(
                        currentStatus,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              statusColor(currentStatus),
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
                      '#${shortOrderId(orderId)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order Progress',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '₹${double.tryParse(total.toString())?.toStringAsFixed(0) ?? total}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _TrackingTimeline(
                  currentIndex: currentIndex,
                ),

                if (courierName.isNotEmpty ||
                    courierMobile.isNotEmpty ||
                    courierPartner.isNotEmpty ||
                    trackingNumber.isNotEmpty) ...[
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(12),
                      color:
                          Colors.teal.withOpacity(0.08),
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
                            SizedBox(width: 10),
                            Text(
                              'Courier Details',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        if (courierPartner.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Partner: $courierPartner',
                          ),
                        ],

                        if (courierName.isNotEmpty)
                          Text(
                            'Name: $courierName',
                          ),

                        if (courierMobile.isNotEmpty)
                          Text(
                            'Phone: $courierMobile',
                          ),

                        if (trackingNumber.isNotEmpty)
                          Text(
                            'Tracking: $trackingNumber',
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const OrdersPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.receipt_long,
                    ),
                    label: const Text(
                      'View Full Order Details',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TRACKING TIMELINE
// ============================================================

class _TrackingTimeline extends StatelessWidget {
  final int currentIndex;

  const _TrackingTimeline({
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        fullOrderStatuses.length,
        (index) {
          final status =
              fullOrderStatuses[index];

          final completed =
              index <= currentIndex;

          final isCurrent =
              index == currentIndex;

          final last =
              index == fullOrderStatuses.length - 1;

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
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
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
                            color: index < currentIndex
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
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrent
                                  ? Colors.deepPurple
                                  : completed
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                            ),
                          ),
                        ),

                        if (isCurrent)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Colors.deepPurple
                                      .withOpacity(0.10),
                              borderRadius:
                                  BorderRadius.circular(20),
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
}

// ============================================================
// CART PAGE
// ============================================================

class CartPage extends StatefulWidget {
  final VoidCallback onCartChanged;

  const CartPage({
    super.key,
    required this.onCartChanged,
  });

  @override
  State<CartPage> createState() =>
      _CartPageState();
}

class _CartPageState extends State<CartPage> {
  void refreshPage() {
    if (!mounted) return;

    setState(() {});
    widget.onCartChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = CartController.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (items.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${CartController.itemCount} item${CartController.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.only(
          bottom: 20,
        ),
        children: [
          const ActiveOrderTracking(),

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                30,
                20,
                40,
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.remove_shopping_cart_outlined,
                    size: 70,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Add products to your cart to continue shopping.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                0,
              ),
              child: Column(
                children: [
                  ...items.map(
                    (item) {
                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(
                                    10,
                                  ),
                                  child: item.imageUrl
                                          .isNotEmpty
                                      ? Image.network(
                                          item.imageUrl,
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

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 5,
                                    ),

                                    if (item.originalPrice >
                                        item.numericPrice)
                                      Text(
                                        '₹${item.originalPrice.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: Colors
                                              .grey
                                              .shade600,
                                          decoration:
                                              TextDecoration
                                                  .lineThrough,
                                        ),
                                      ),

                                    Text(
                                      '₹${item.numericPrice.toStringAsFixed(0)}',
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),

                                    if (item.discountPercent >
                                        0)
                                      Text(
                                        '${item.discountPercent.toStringAsFixed(0)}% OFF',
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.green,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                    const SizedBox(
                                      height: 8,
                                    ),

                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed:
                                              () async {
                                            await CartController
                                                .decreaseQuantity(
                                              item.id,
                                            );

                                            refreshPage();
                                          },
                                          icon:
                                              const Icon(
                                            Icons
                                                .remove_circle_outline,
                                          ),
                                        ),

                                        Text(
                                          '${item.quantity}',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),

                                        IconButton(
                                          onPressed:
                                              item.quantity >=
                                                      item.availableStock
                                                  ? null
                                                  : () async {
                                                      await CartController
                                                          .increaseQuantity(
                                                        item.id,
                                                      );

                                                      refreshPage();
                                                    },
                                          icon:
                                              const Icon(
                                            Icons
                                                .add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                onPressed:
                                    () async {
                                  await CartController
                                      .removeProduct(
                                    item.id,
                                  );

                                  refreshPage();
                                },
                                icon:
                                    const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ==================================================
            // CART SUMMARY
            // ==================================================

            Container(
              margin:
                  const EdgeInsets.only(top: 4),
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (CartController.productSavings >
                      0)
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Product Savings',
                        ),
                        Text(
                          '- ₹${CartController.productSavings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${CartController.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () async {
                        final user =
                            FirebaseAuth.instance.currentUser;

                        if (user == null) {
                          final loginResult =
                              await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const LoginPage(),
                            ),
                          );

                          if (loginResult != true ||
                              FirebaseAuth.instance
                                      .currentUser ==
                                  null) {
                            return;
                          }
                        }

                        final result =
                            await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CheckoutPage(),
                          ),
                        );

                        if (result == true) {
                          if (!mounted) return;

                          setState(() {});
                          widget.onCartChanged();
                        }
                      },
                      child: const Text(
                        'Proceed to Checkout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
