import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool loading = true;
  bool cancellingOrder = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> orders = [];

  User? get currentUser =>
      FirebaseAuth.instance.currentUser;

  static const List<String> orderStatuses = [
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
    loadOrders();
  }

  Future<void> loadOrders() async {
    final user = currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          loading = false;
          orders = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final snapshot = await _firestore
          .collection('orders')
          .where(
            'userId',
            isEqualTo: user.uid,
          )
          .get();

      final result = snapshot.docs.toList();

      result.sort((a, b) {
        final aTime = _timestampToDate(
          a.data()['createdAt'],
        );

        final bTime = _timestampToDate(
          b.data()['createdAt'],
        );

        return bTime.compareTo(aTime);
      });

      if (!mounted) return;

      setState(() {
        orders = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Could not load your orders.',
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

  String formatDate(dynamic value) {
    final date = _timestampToDate(value);

    if (date.millisecondsSinceEpoch == 0) {
      return 'Date unavailable';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    int hour = date.hour;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$day/$month/$year • $hour:$minute $period';
  }

  String normalizedStatus(
    Map<String, dynamic> data,
  ) {
    return (
      data['orderStatus'] ??
      data['status'] ??
      'Placed'
    ).toString().trim();
  }

  Future<void> cancelOrder(
    QueryDocumentSnapshot<Map<String, dynamic>> order,
  ) async {
    if (cancellingOrder) return;

    final data = order.data();

    final status = normalizedStatus(data)
        .toLowerCase();

    if (!_canCancel(status)) {
      showMessage(
        'This order can no longer be cancelled.',
      );
      return;
    }

    final reason = await showCancellationDialog();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    final user = currentUser;

    if (user == null) {
      showMessage(
        'Please login to cancel your order.',
      );
      return;
    }

    setState(() {
      cancellingOrder = true;
    });

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final orderRef = _firestore
              .collection('orders')
              .doc(order.id);

          final freshSnapshot =
              await transaction.get(orderRef);

          if (!freshSnapshot.exists) {
            throw Exception(
              'Order does not exist.',
            );
          }

          final freshData =
              freshSnapshot.data() ?? {};

          final freshStatus = (
            freshData['orderStatus'] ??
            freshData['status'] ??
            'Placed'
          ).toString().trim().toLowerCase();

          if (!_canCancel(freshStatus)) {
            throw Exception(
              'ORDER_NOT_CANCELLABLE',
            );
          }

          final existingHistory =
              freshData['statusHistory'];

          final history =
              existingHistory is List
                  ? List<dynamic>.from(
                      existingHistory,
                    )
                  : <dynamic>[];

          history.add({
            'status': 'Cancelled',
            'timestamp': Timestamp.now(),
            'updatedBy': 'Customer',
            'updatedByUid': user.uid,
            'reason': reason.trim(),
          });

          transaction.update(
            orderRef,
            {
              'orderStatus': 'Cancelled',
              'status': 'Cancelled',
              'cancelled': true,
              'cancellationReason':
                  reason.trim(),
              'cancelledAt':
                  FieldValue.serverTimestamp(),
              'cancelledBy': user.uid,
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'statusHistory': history,
            },
          );
        },
      );

      if (!mounted) return;

      await loadOrders();

      showMessage(
        'Order cancelled successfully.',
      );
    } catch (e) {
      if (mounted) {
        if (e.toString().contains(
              'ORDER_NOT_CANCELLABLE',
            )) {
          showMessage(
            'This order can no longer be cancelled.',
          );
        } else {
          showMessage(
            'Could not cancel the order. Please try again.',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          cancellingOrder = false;
        });
      }
    }
  }

  bool _canCancel(String status) {
    return status == 'placed' ||
        status == 'confirmed' ||
        status == 'pending' ||
        status == 'processing' ||
        status == 'packed';
  }

  Future<String?> showCancellationDialog() async {
    String selectedReason = 'Changed my mind';

    final reasons = <String>[
      'Changed my mind',
      'Ordered by mistake',
      'Found a better price',
      'Delivery time is too long',
      'Want to change the order',
      'Other',
    ];

    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Cancel Order?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select a reason for cancelling this order.',
                    ),
                    const SizedBox(height: 16),
                    ...reasons.map(
                      (reason) {
                        return RadioListTile<String>(
                          contentPadding:
                              EdgeInsets.zero,
                          dense: true,
                          value: reason,
                          groupValue:
                              selectedReason,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setDialogState(() {
                              selectedReason =
                                  value;
                            });
                          },
                          title: Text(reason),
                        );
                      },
                    ),
                    if (selectedReason ==
                        'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Enter reason',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Keep Order',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedReason ==
                        'Other') {
                      final other =
                          controller.text.trim();

                      if (other.isEmpty) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a cancellation reason.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        other,
                      );
                    } else {
                      Navigator.pop(
                        dialogContext,
                        selectedReason,
                      );
                    }
                  },
                  child: const Text(
                    'Cancel Order',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    return result;
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'confirmed':
        return Colors.blue;

      case 'processing':
      case 'packed':
        return Colors.orange;

      case 'shipped':
      case 'picked by courier':
        return Colors.indigo;

      case 'out for delivery':
        return Colors.deepPurple;

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'returned':
        return Colors.deepOrange;

      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Icons.shopping_bag_outlined;

      case 'confirmed':
        return Icons.check_circle_outline;

      case 'processing':
        return Icons.sync;

      case 'packed':
        return Icons.inventory_2_outlined;

      case 'shipped':
        return Icons.local_shipping_outlined;

      case 'picked by courier':
        return Icons.person_pin_circle_outlined;

      case 'out for delivery':
        return Icons.delivery_dining_outlined;

      case 'delivered':
        return Icons.done_all;

      case 'cancelled':
        return Icons.cancel_outlined;

      case 'returned':
        return Icons.assignment_return_outlined;

      default:
        return Icons.info_outline;
    }
  }

  String itemName(dynamic item) {
    if (item is! Map) {
      return 'Product';
    }

    return (
      item['name'] ??
      item['productName'] ??
      item['title'] ??
      'Product'
    ).toString();
  }

  double itemPrice(dynamic item) {
    if (item is! Map) return 0;

    final value = item['price'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int itemQuantity(dynamic item) {
    if (item is! Map) return 1;

    final value = item['quantity'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        1;
  }

  String? itemImage(dynamic item) {
    if (item is! Map) return null;

    final image =
        item['imageUrl'] ??
        item['image'] ??
        item['productImage'];

    if (image == null) return null;

    final value = image.toString().trim();

    return value.isEmpty ? null : value;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? buildLoginRequired()
          : RefreshIndicator(
              onRefresh: loadOrders,
              child: buildOrdersBody(),
            ),
    );
  }

  Widget buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please login',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Login to view your orders.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOrdersBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (orders.isEmpty) {
      return buildEmptyOrders();
    }

    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        30,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return buildOrderCard(
          orders[index],
        );
      },
    );
  }

  Widget buildEmptyOrders() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height:
              MediaQuery.of(context).size.height *
                  .28,
        ),
        Icon(
          Icons.shopping_bag_outlined,
          size: 90,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Your placed orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildOrderCard(
    QueryDocumentSnapshot<Map<String, dynamic>> order,
  ) {
    final data = order.data();

    final orderId =
        (data['orderId'] ?? order.id).toString();

    final status = normalizedStatus(data);

    final paymentMethod =
        (data['paymentMethod'] ?? 'COD')
            .toString();

    final paymentStatus =
        (data['paymentStatus'] ?? 'Pending')
            .toString();

    final total =
        (data['totalAmount'] as num?)
                ?.toDouble() ??
            0;

    final items = data['items'] is List
        ? List<dynamic>.from(data['items'])
        : <dynamic>[];

    final canCancel =
        _canCancel(status.toLowerCase());

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(
          16,
          8,
          12,
          8,
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Order #${shortOrderId(orderId)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            statusBadge(status),
          ],
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(
                  data['createdAt'],
                ),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '₹${total.toStringAsFixed(2)} • ${items.length} item${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),

          buildCurrentStatusBanner(
            data,
          ),

          const SizedBox(height: 14),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Order Items',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          if (items.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No item details available.',
              ),
            ),

          ...items.map(buildOrderItem),

          const SizedBox(height: 12),

          Container(
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                summaryRow(
                  'Payment Method',
                  paymentMethod,
                ),
                const SizedBox(height: 8),
                summaryRow(
                  'Payment Status',
                  paymentStatus,
                ),
                const Divider(height: 20),
                summaryRow(
                  'Order Total',
                  '₹${total.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          buildDeliveryAddress(data),

          const SizedBox(height: 14),

          buildStatusSection(
            data,
          ),

          const SizedBox(height: 14),

          if (status.toLowerCase() ==
              'cancelled')
            buildCancellationInfo(data),

          if (status.toLowerCase() ==
              'cancelled')
            const SizedBox(height: 10),

          if (canCancel)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: cancellingOrder
                    ? null
                    : () => cancelOrder(
                          order,
                        ),
                icon: cancellingOrder
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.cancel_outlined,
                      ),
                label: Text(
                  cancellingOrder
                      ? 'Cancelling...'
                      : 'Cancel Order',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      Colors.red,
                  side: const BorderSide(
                    color: Colors.red,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 13,
                  ),
                ),
              ),
            ),

          if (!canCancel &&
              status.toLowerCase() !=
                  'cancelled' &&
              status.toLowerCase() !=
                  'delivered')
            const Padding(
              padding:
                  EdgeInsets.only(top: 2),
              child: Text(
                'This order cannot be cancelled at its current stage.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildCurrentStatusBanner(
    Map<String, dynamic> data,
  ) {
    final status = normalizedStatus(data);

    final color = statusColor(status);

    String message;

    switch (status.toLowerCase()) {
      case 'placed':
        message =
            'Your order has been placed. Waiting for confirmation.';
        break;

      case 'confirmed':
        message =
            'Your order has been confirmed by Admin.';
        break;

      case 'processing':
        message =
            'Your order is being processed.';
        break;

      case 'packed':
        message =
            'Your order has been packed and is ready for shipping.';
        break;

      case 'shipped':
        message =
            'Your order has been shipped. Waiting for courier pickup.';
        break;

      case 'picked by courier':
        message =
            'Courier has picked up your order.';
        break;

      case 'out for delivery':
        message =
            'Your order is out for delivery.';
        break;

      case 'delivered':
        message =
            'Your order has been delivered successfully.';
        break;

      case 'cancelled':
        message =
            'This order has been cancelled.';
        break;

      default:
        message =
            'Your order status is $status.';
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: .08,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(
            alpha: .25,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon(status),
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String shortOrderId(String orderId) {
    if (orderId.length <= 10) {
      return orderId;
    }

    return orderId.substring(0, 10);
  }

  Widget statusBadge(String status) {
    final color = statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: .10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            statusIcon(status),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOrderItem(dynamic item) {
    final name = itemName(item);
    final price = itemPrice(item);
    final quantity =
        itemQuantity(item);
    final image =
        itemImage(item);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              color:
                  Colors.grey.shade100,
            ),
            clipBehavior:
                Clip.antiAlias,
            child: image == null
                ? const Icon(
                    Icons.image_outlined,
                    color:
                        Colors.grey,
                  )
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Icon(
                        Icons
                            .image_outlined,
                        color:
                            Colors.grey,
                      );
                    },
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
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Qty: $quantity',
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${(price * quantity).toStringAsFixed(2)}',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget summaryRow(
    String title,
    String value, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign:
                TextAlign.end,
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDeliveryAddress(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['deliveryAddress'];

    String name =
        (data['customerName'] ??
                '')
            .toString();

    String phone =
        (data['customerMobile'] ??
                '')
            .toString();

    String address =
        (data['address'] ?? '')
            .toString();

    String city =
        (data['city'] ?? '')
            .toString();

    String pincode =
        (data['pincode'] ?? '')
            .toString();

    if (raw is Map) {
      name =
          (raw['name'] ?? name)
              .toString();

      phone =
          (raw['phone'] ?? phone)
              .toString();

      address = (
        raw['fullAddress'] ??
        raw['street'] ??
        address
      ).toString();

      city =
          (raw['city'] ?? city)
              .toString();

      pincode =
          (raw['pincode'] ??
                  pincode)
              .toString();

      final house =
          (raw['house'] ?? '')
              .toString()
              .trim();

      final landmark =
          (raw['landmark'] ?? '')
              .toString()
              .trim();

      if (house.isNotEmpty &&
          !address.contains(house)) {
        address =
            '$house, $address';
      }

      if (landmark.isNotEmpty) {
        address =
            '$address, Landmark: $landmark';
      }
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              Colors.grey.shade300,
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
                Icons
                    .location_on_outlined,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                'Delivery Address',
                style:
                    TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (name.isNotEmpty)
            Text(
              name,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          if (phone.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 4,
              ),
              child: Text(
                '📞 $phone',
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                ),
              ),
            ),
          if (address.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 6,
              ),
              child: Text(
                address,
                style:
                    const TextStyle(
                  height: 1.4,
                ),
              ),
            ),
          if (city.isNotEmpty ||
              pincode.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 4,
              ),
              child: Text(
                '$city${city.isNotEmpty && pincode.isNotEmpty ? ' - ' : ''}$pincode',
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildStatusSection(
    Map<String, dynamic> data,
  ) {
    final status =
        normalizedStatus(data);

    final normalized =
        status.toLowerCase();

    if (normalized ==
        'cancelled') {
      return buildCancelledStatus();
    }

    final currentIndex =
        _statusIndex(normalized);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Order Tracking',
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color:
                      statusColor(status),
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...List.generate(
            orderStatuses.length,
            (index) {
              final stage =
                  orderStatuses[index];

              final completed =
                  index <= currentIndex;

              final isCurrent =
                  index ==
                      currentIndex;

              final isLast =
                  index ==
                      orderStatuses.length -
                          1;

              final stageTime =
                  _stageTimestamp(
                    data,
                    stage,
                  );

              return Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Column(
                    children: [
                      AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds: 250,
                        ),
                        width: 28,
                        height: 28,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color: completed
                              ? statusColor(
                                  stage,
                                )
                              : Colors
                                  .grey
                                  .shade300,
                          border:
                              isCurrent
                                  ? Border.all(
                                      color:
                                          statusColor(
                                        stage,
                                      ),
                                      width:
                                          3,
                                    )
                                  : null,
                        ),
                        child: Icon(
                          completed
                              ? Icons.check
                              : Icons
                                  .circle,
                          size: completed
                              ? 16
                              : 8,
                          color: completed
                              ? Colors
                                  .white
                              : Colors
                                  .grey
                                  .shade600,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 42,
                          color: index <
                                  currentIndex
                              ? statusColor(
                                  orderStatuses[
                                      index],
                                )
                              : Colors
                                  .grey
                                  .shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 1,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  stage,
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        completed
                                            ? FontWeight
                                                .bold
                                            : FontWeight
                                                .normal,
                                    color:
                                        completed
                                            ? null
                                            : Colors
                                                .grey,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        7,
                                    vertical:
                                        3,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        statusColor(
                                      stage,
                                    ).withValues(
                                      alpha:
                                          .10,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                  ),
                                  child:
                                      Text(
                                    'CURRENT',
                                    style:
                                        TextStyle(
                                      color:
                                          statusColor(
                                        stage,
                                      ),
                                      fontSize:
                                          9,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (stageTime !=
                              null)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 3,
                              ),
                              child: Text(
                                formatDate(
                                  stageTime,
                                ),
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.grey,
                                  fontSize:
                                      11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          buildHistorySection(
            data,
          ),

          if (normalized ==
              'picked by courier')
            buildCourierInfo(data),

          if (normalized ==
              'out for delivery')
            buildCourierInfo(data),
        ],
      ),
    );
  }

  Widget buildCancelledStatus() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(
          alpha: .08,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(
            alpha: .25,
          ),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.cancel_outlined,
            color: Colors.red,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This order has been cancelled.',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHistorySection(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['statusHistory'];

    if (raw is! List ||
        raw.isEmpty) {
      return const SizedBox.shrink();
    }

    final history =
        List<dynamic>.from(raw);

    history.sort(
      (a, b) {
        if (a is! Map ||
            b is! Map) {
          return 0;
        }

        final aDate =
            _timestampToDate(
          a['timestamp'],
        );

        final bDate =
            _timestampToDate(
          b['timestamp'],
        );

        return aDate.compareTo(bDate);
      },
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Divider(
          height: 28,
        ),
        const Text(
          'Status History',
          style:
              TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...history.reversed
            .take(10)
            .map(
          (entry) {
            if (entry is! Map) {
              return const SizedBox
                  .shrink();
            }

            final historyStatus =
                (entry['status'] ??
                        '')
                    .toString();

            final updatedBy =
                (entry['updatedBy'] ??
                        '')
                    .toString();

            final timestamp =
                entry['timestamp'];

            final reason =
                (entry['reason'] ??
                        '')
                    .toString();

            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Icon(
                    statusIcon(
                      historyStatus,
                    ),
                    size: 17,
                    color:
                        statusColor(
                      historyStatus,
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          historyStatus,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        if (timestamp !=
                            null)
                          Text(
                            formatDate(
                              timestamp,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  Colors.grey,
                              fontSize:
                                  11,
                            ),
                          ),
                        if (updatedBy
                            .isNotEmpty)
                          Text(
                            'Updated by: $updatedBy',
                            style:
                                const TextStyle(
                              color:
                                  Colors.grey,
                              fontSize:
                                  11,
                            ),
                          ),
                        if (reason
                            .isNotEmpty)
                          Text(
                            'Reason: $reason',
                            style:
                                const TextStyle(
                              color:
                                  Colors.grey,
                              fontSize:
                                  11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildCourierInfo(
    Map<String, dynamic> data,
  ) {
    final courierName =
        (data['courierName'] ?? '')
            .toString()
            .trim();

    final courierMobile =
        (data['courierMobile'] ?? '')
            .toString()
            .trim();

    if (courierName.isEmpty &&
        courierMobile.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin:
          const EdgeInsets.only(top: 12),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo
            .withValues(alpha: .06),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.delivery_dining,
            color: Colors.indigo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  'Courier',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                if (courierName
                    .isNotEmpty)
                  Text(
                    courierName,
                  ),
                if (courierMobile
                    .isNotEmpty)
                  Text(
                    '📞 $courierMobile',
                    style:
                        const TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _statusIndex(
    String status,
  ) {
    switch (status) {
      case 'placed':
      case 'pending':
        return 0;

      case 'confirmed':
        return 1;

      case 'processing':
        return 2;

      case 'packed':
        return 3;

      case 'shipped':
        return 4;

      case 'picked by courier':
        return 5;

      case 'out for delivery':
        return 6;

      case 'delivered':
        return 7;

      default:
        return 0;
    }
  }

  dynamic _stageTimestamp(
    Map<String, dynamic> data,
    String stage,
  ) {
    switch (stage) {
      case 'Placed':
        return data['placedAt'] ??
            data['createdAt'];

      case 'Confirmed':
        return data['confirmedAt'];

      case 'Processing':
        return data['processingAt'];

      case 'Packed':
        return data['packedAt'];

      case 'Shipped':
        return data['shippedAt'];

      case 'Picked by Courier':
        return data['courierPickedAt'];

      case 'Out for Delivery':
        return data['outForDeliveryAt'];

      case 'Delivered':
        return data['deliveredAt'];

      default:
        return null;
    }
  }

  Widget buildCancellationInfo(
    Map<String, dynamic> data,
  ) {
    final reason =
        (data['cancellationReason'] ??
                'No reason provided')
            .toString();

    final cancelledAt =
        data['cancelledAt'];

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(
          alpha: .06,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(
            alpha: .25,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Text(
                'Cancellation Details',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Reason: $reason',
          ),
          if (cancelledAt != null)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 5,
              ),
              child: Text(
                'Cancelled on: ${formatDate(cancelledAt)}',
                style:
                    const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
