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

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  // ============================================================
  // LOAD ORDERS
  // ============================================================

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

      final result =
          snapshot.docs.toList();

      result.sort((a, b) {
        final aData = a.data();
        final bData = b.data();

        final aTime =
            _timestampToDate(aData['createdAt']);

        final bTime =
            _timestampToDate(bData['createdAt']);

        return bTime.compareTo(aTime);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        orders = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      showMessage(
        'Could not load your orders.',
      );
    }
  }

  // ============================================================
  // DATE HELPER
  // ============================================================

  DateTime _timestampToDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      0,
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String formatDate(
    dynamic value,
  ) {
    final date =
        _timestampToDate(value);

    if (date.millisecondsSinceEpoch ==
        0) {
      return 'Date unavailable';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year =
        date.year.toString();

    int hour = date.hour;

    final minute =
        date.minute.toString().padLeft(
              2,
              '0',
            );

    final period =
        hour >= 12 ? 'PM' : 'AM';

    hour =
        hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$day/$month/$year • $hour:$minute $period';
  }

  // ============================================================
  // CANCEL ORDER
  // ============================================================

  Future<void> cancelOrder(
    QueryDocumentSnapshot<
        Map<String, dynamic>> order,
  ) async {
    if (cancellingOrder) {
      return;
    }

    final data = order.data();

    final status =
        (data['orderStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (!_canCancel(status)) {
      showMessage(
        'This order can no longer be cancelled.',
      );
      return;
    }

    final reason =
        await showCancellationDialog();

    if (reason == null ||
        reason.trim().isEmpty) {
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
      await _firestore
          .collection('orders')
          .doc(order.id)
          .update({
        'orderStatus':
            'Cancelled',
        'cancellationReason':
            reason.trim(),
        'cancelledAt':
            FieldValue.serverTimestamp(),
        'cancelledBy':
            user.uid,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      // Update local order immediately.
      final index =
          orders.indexWhere(
        (item) =>
            item.id ==
            order.id,
      );

      if (index >= 0) {
        await loadOrders();
      }

      showMessage(
        'Order cancelled successfully.',
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not cancel the order. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          cancellingOrder = false;
        });
      }
    }
  }

  // ============================================================
  // CAN CANCEL
  // ============================================================

  bool _canCancel(
    String status,
  ) {
    return status == 'confirmed' ||
        status == 'pending' ||
        status == 'placed' ||
        status == 'processing';
  }

  // ============================================================
  // CANCELLATION DIALOG
  // ============================================================

  Future<String?> showCancellationDialog() async {
    String selectedReason =
        'Changed my mind';

    final reasons = <String>[
      'Changed my mind',
      'Ordered by mistake',
      'Found a better price',
      'Delivery time is too long',
      'Want to change the order',
      'Other',
    ];

    final controller =
        TextEditingController();

    final result =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title:
                  const Text(
                'Cancel Order?',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select a reason for cancelling this order.',
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    ...reasons.map(
                      (reason) {
                        return RadioListTile<
                            String>(
                          contentPadding:
                              EdgeInsets.zero,
                          dense: true,
                          value: reason,
                          groupValue:
                              selectedReason,
                          onChanged:
                              (value) {
                            if (value ==
                                null) {
                              return;
                            }

                            setDialogState(() {
                              selectedReason =
                                  value;
                            });
                          },
                          title:
                              Text(reason),
                        );
                      },
                    ),

                    if (selectedReason ==
                        'Other') ...[
                      const SizedBox(
                        height: 8,
                      ),
                      TextField(
                        controller:
                            controller,
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
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'Keep Order',
                  ),
                ),
                FilledButton(
                  onPressed:
                      () {
                    if (selectedReason ==
                        'Other') {
                      final other =
                          controller
                              .text
                              .trim();

                      if (other.isEmpty) {
                        ScaffoldMessenger
                            .of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content:
                                Text(
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
                  child:
                      const Text(
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

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'placed':
        return Colors.blue;

      case 'processing':
      case 'packed':
        return Colors.orange;

      case 'shipped':
      case 'out for delivery':
        return Colors.indigo;

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

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData statusIcon(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'placed':
        return Icons.check_circle_outline;

      case 'processing':
        return Icons.sync;

      case 'packed':
        return Icons.inventory_2_outlined;

      case 'shipped':
        return Icons.local_shipping_outlined;

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

  // ============================================================
  // ITEM NAME
  // ============================================================

  String itemName(
    dynamic item,
  ) {
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

  // ============================================================
  // ITEM PRICE
  // ============================================================

  double itemPrice(
    dynamic item,
  ) {
    if (item is! Map) {
      return 0;
    }

    final value =
        item['price'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ============================================================
  // ITEM QUANTITY
  // ============================================================

  int itemQuantity(
    dynamic item,
  ) {
    if (item is! Map) {
      return 1;
    }

    final value =
        item['quantity'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        1;
  }

  // ============================================================
  // IMAGE URL
  // ============================================================

  String? itemImage(
    dynamic item,
  ) {
    if (item is! Map) {
      return null;
    }

    final image =
        item['imageUrl'] ??
        item['image'] ??
        item['productImage'];

    if (image == null) {
      return null;
    }

    final value =
        image.toString().trim();

    return value.isEmpty
        ? null
        : value;
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final user = currentUser;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'My Orders',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? buildLoginRequired()
          : RefreshIndicator(
              onRefresh:
                  loadOrders,
              child:
                  buildOrdersBody(),
            ),
    );
  }

  // ============================================================
  // LOGIN REQUIRED
  // ============================================================

  Widget buildLoginRequired() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .account_circle_outlined,
              size: 80,
              color:
                  Theme.of(context)
                      .colorScheme
                      .primary,
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'Please login',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Login to view your orders.',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDERS BODY
  // ============================================================

  Widget buildOrdersBody() {
    if (loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (orders.isEmpty) {
      return buildEmptyOrders();
    }

    return ListView.builder(
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
        final order =
            orders[index];

        return buildOrderCard(
          order,
        );
      },
    );
  }

  // ============================================================
  // EMPTY ORDERS
  // ============================================================

  Widget buildEmptyOrders() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  .28,
        ),
        Icon(
          Icons
              .shopping_bag_outlined,
          size: 90,
          color:
              Colors.grey.shade400,
        ),
        const SizedBox(
          height: 18,
        ),
        const Center(
          child: Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        const Center(
          child: Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal: 30,
            ),
            child: Text(
              'Your placed orders will appear here.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget buildOrderCard(
    QueryDocumentSnapshot<
        Map<String, dynamic>> order,
  ) {
    final data =
        order.data();

    final orderId =
        (data['orderId'] ??
                order.id)
            .toString();

    final status =
        (data['orderStatus'] ??
                'Pending')
            .toString();

    final paymentMethod =
        (data['paymentMethod'] ??
                'COD')
            .toString();

    final paymentStatus =
        (data['paymentStatus'] ??
                'Pending')
            .toString();

    final total =
        (data['totalAmount']
                as num?)
            ?.toDouble() ??
        0;

    final items =
        data['items'] is List
            ? List<dynamic>.from(
                data['items'],
              )
            : <dynamic>[];

    final canCancel =
        _canCancel(
      status.toLowerCase(),
    );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      clipBehavior:
          Clip.antiAlias,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child:
          ExpansionTile(
        tilePadding:
            const EdgeInsets.fromLTRB(
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
        title:
            Row(
          children: [
            Expanded(
              child:
                  Text(
                'Order #${shortOrderId(orderId)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            statusBadge(
              status,
            ),
          ],
        ),
        subtitle:
            Padding(
          padding:
              const EdgeInsets.only(
            top: 7,
          ),
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(
                  data['createdAt'],
                ),
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                '₹${total.toStringAsFixed(2)} • ${items.length} item${items.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(
            height: 1,
          ),

          const SizedBox(
            height: 14,
          ),

          // ------------------------------------------------------
          // ORDER ITEMS
          // ------------------------------------------------------

          Align(
            alignment:
                Alignment.centerLeft,
            child:
                Text(
              'Order Items',
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          if (items.isEmpty)
            const Align(
              alignment:
                  Alignment.centerLeft,
              child:
                  Text(
                'No item details available.',
              ),
            ),

          ...items.map(
            buildOrderItem,
          ),

          const SizedBox(
            height: 12,
          ),

          // ------------------------------------------------------
          // TOTAL
          // ------------------------------------------------------

          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child:
                Column(
              children: [
                summaryRow(
                  'Payment Method',
                  paymentMethod,
                ),
                const SizedBox(
                  height: 8,
                ),
                summaryRow(
                  'Payment Status',
                  paymentStatus,
                ),
                const Divider(
                  height: 20,
                ),
                summaryRow(
                  'Order Total',
                  '₹${total.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          // ------------------------------------------------------
          // DELIVERY ADDRESS
          // ------------------------------------------------------

          buildDeliveryAddress(
            data,
          ),

          const SizedBox(
            height: 14,
          ),

          // ------------------------------------------------------
          // ORDER STATUS
          // ------------------------------------------------------

          buildStatusSection(
            status,
          ),

          const SizedBox(
            height: 14,
          ),

          // ------------------------------------------------------
          // CANCELLATION INFO
          // ------------------------------------------------------

          if (status.toLowerCase() ==
              'cancelled')
            buildCancellationInfo(
              data,
            ),

          // ------------------------------------------------------
          // CANCEL BUTTON
          // ------------------------------------------------------

          if (canCancel)
            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed:
                    cancellingOrder
                        ? null
                        : () =>
                            cancelOrder(
                          order,
                        ),
                icon:
                    cancellingOrder
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .cancel_outlined,
                          ),
                label:
                    Text(
                  cancellingOrder
                      ? 'Cancelling...'
                      : 'Cancel Order',
                ),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      Colors.red,
                  side:
                      const BorderSide(
                    color:
                        Colors.red,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
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
                  EdgeInsets.only(
                top: 2,
              ),
              child:
                  Text(
                'This order cannot be cancelled at its current stage.',
                style:
                    TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SHORT ORDER ID
  // ============================================================

  String shortOrderId(
    String orderId,
  ) {
    if (orderId.length <= 10) {
      return orderId;
    }

    return orderId.substring(
      0,
      10,
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget statusBadge(
    String status,
  ) {
    final color =
        statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color: color.withValues(
          alpha: .10,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            statusIcon(status),
            size: 14,
            color: color,
          ),
          const SizedBox(
            width: 4,
          ),
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

  // ============================================================
  // ORDER ITEM
  // ============================================================

  Widget buildOrderItem(
    dynamic item,
  ) {
    final name =
        itemName(item);

    final price =
        itemPrice(item);

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
          const EdgeInsets.all(
        10,
      ),
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color:
              Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Row(
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
            child:
                image == null
                    ? const Icon(
                        Icons
                            .image_outlined,
                        color:
                            Colors.grey,
                      )
                    : Image.network(
                        image,
                        fit:
                            BoxFit.cover,
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

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
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
                const SizedBox(
                  height: 5,
                ),
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

          const SizedBox(
            width: 8,
          ),

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

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget summaryRow(
    String title,
    String value, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
      children: [
        Text(
          title,
          style:
              TextStyle(
            fontWeight:
                bold
                    ? FontWeight.bold
                    : FontWeight.normal,
          ),
        ),
        Flexible(
          child:
              Text(
            value,
            textAlign:
                TextAlign.end,
            style:
                TextStyle(
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DELIVERY ADDRESS
  // ============================================================

  Widget buildDeliveryAddress(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['deliveryAddress'];

    String name =
        (data['customerName'] ?? '')
            .toString();

    String phone =
        (data['customerMobile'] ?? '')
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
          (raw['name'] ??
                  name)
              .toString();

      phone =
          (raw['phone'] ??
                  phone)
              .toString();

      address =
          (raw['fullAddress'] ??
                  raw['street'] ??
                  address)
              .toString();

      city =
          (raw['city'] ??
                  city)
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
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color:
              Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Column(
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
              SizedBox(
                width: 6,
              ),
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

          const SizedBox(
            height: 10,
          ),

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
              child:
                  Text(
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
              child:
                  Text(
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
              child:
                  Text(
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

  // ============================================================
  // STATUS SECTION
  // ============================================================

  Widget buildStatusSection(
    String status,
  ) {
    final normalized =
        status.toLowerCase();

    final steps = <String>[
      'Confirmed',
      'Processing',
      'Shipped',
      'Out for Delivery',
      'Delivered',
    ];

    if (normalized ==
        'cancelled') {
      return Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.red.withValues(
            alpha: .08,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child:
            const Row(
          children: [
            Icon(
              Icons
                  .cancel_outlined,
              color:
                  Colors.red,
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child:
                  Text(
                'This order has been cancelled.',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }

    int currentIndex =
        _statusIndex(
      normalized,
    );

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color:
              Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          ...List.generate(
            steps.length,
            (index) {
              final completed =
                  index <=
                      currentIndex;

              final isLast =
                  index ==
                      steps.length -
                          1;

              return Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,
                          color: completed
                              ? Theme.of(
                                  context,
                                )
                                    .colorScheme
                                    .primary
                              : Colors
                                  .grey
                                  .shade300,
                        ),
                        child:
                            Icon(
                          completed
                              ? Icons
                                  .check
                              : Icons
                                  .circle,
                          size:
                              completed
                                  ? 15
                                  : 8,
                          color:
                              completed
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
                          height: 30,
                          color: index <
                                  currentIndex
                              ? Theme.of(
                                  context,
                                )
                                    .colorScheme
                                    .primary
                              : Colors
                                  .grey
                                  .shade300,
                        ),
                    ],
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 2,
                    ),
                    child:
                        Text(
                      steps[index],
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
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS INDEX
  // ============================================================

  int _statusIndex(
    String status,
  ) {
    switch (status) {
      case 'confirmed':
      case 'pending':
      case 'placed':
        return 0;

      case 'processing':
      case 'packed':
        return 1;

      case 'shipped':
        return 2;

      case 'out for delivery':
        return 3;

      case 'delivered':
        return 4;

      default:
        return 0;
    }
  }

  // ============================================================
  // CANCELLATION INFO
  // ============================================================

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
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.red.withValues(
          alpha: .06,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border:
            Border.all(
          color:
              Colors.red.withValues(
            alpha: .25,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .cancel_outlined,
                color:
                    Colors.red,
              ),
              SizedBox(
                width: 8,
              ),
              Text(
                'Cancellation Details',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            'Reason: $reason',
          ),

          if (cancelledAt !=
              null)
            Padding(
              padding:
                  const EdgeInsets
                      .only(
                top: 5,
              ),
              child:
                  Text(
                'Cancelled on: ${formatDate(cancelledAt)}',
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
