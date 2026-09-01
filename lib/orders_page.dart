import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  // ============================================================
  // MONEY
  // ============================================================

  String money(dynamic value) {
    if (value is num) {
      return '₹${value.toStringAsFixed(0)}';
    }

    final number = double.tryParse(
      value?.toString() ?? '',
    );

    if (number == null) {
      return '₹0';
    }

    return '₹${number.toStringAsFixed(0)}';
  }

  // ============================================================
  // DATE
  // ============================================================

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Date unavailable';
    }

    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  // ============================================================
  // DATE + TIME
  // ============================================================

  String formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Date unavailable';
    }

    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    return '$day/$month/$year $hour:$minute $period';
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'shipped':
        return Colors.blue;

      case 'packed':
        return Colors.teal;

      case 'confirmed':
        return Colors.orange;

      case 'placed':
        return Colors.deepPurple;

      default:
        return Colors.deepPurple;
    }
  }

  // ============================================================
  // NORMALIZE STATUS
  // ============================================================

  String normalizeStatus(String status) {
    final value = status.trim().toLowerCase();

    switch (value) {
      case 'placed':
        return 'Placed';

      case 'confirmed':
        return 'Confirmed';

      case 'packed':
        return 'Packed';

      case 'shipped':
        return 'Shipped';

      case 'delivered':
        return 'Delivered';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      default:
        return status.trim().isEmpty ? 'Placed' : status.trim();
    }
  }

  // ============================================================
  // CAN CUSTOMER CANCEL?
  // ============================================================

  bool canCustomerCancel(String status) {
    final normalized = normalizeStatus(status);

    return normalized == 'Placed' ||
        normalized == 'Confirmed';
  }

  // ============================================================
  // CANCELLATION REASON
  // ============================================================

  Future<String?> selectCancellationReason(
    BuildContext context,
  ) async {
    const reasons = [
      'Ordered by mistake',
      'Found a better price',
      'Delivery time is too long',
      'No longer needed',
      'Want to change the order',
      'Other',
    ];

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Why are you cancelling?',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: reasons.length,
              separatorBuilder: (_, __) {
                return const Divider(height: 1);
              },
              itemBuilder: (context, index) {
                final reason = reasons[index];

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  leading: Icon(
                    Icons.radio_button_unchecked,
                    color: Colors.grey.shade600,
                  ),
                  title: Text(reason),
                  onTap: () {
                    Navigator.pop(
                      dialogContext,
                      reason,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  null,
                );
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CANCEL CONFIRMATION
  // ============================================================

  Future<void> confirmCancelOrder(
    BuildContext context,
    String orderId,
  ) async {
    final reason =
        await selectCancellationReason(context);

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.cancel_outlined,
            color: Colors.red,
            size: 42,
          ),
          title: const Text(
            'Cancel Order?',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are you sure you want to cancel this order?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cancellation reason',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(reason),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Once cancelled, this order cannot be continued.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('No'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await cancelOrder(
      context,
      orderId,
      reason,
    );
  }

  // ============================================================
  // CANCEL ORDER
  // ============================================================

  Future<void> cancelOrder(
    BuildContext context,
    String orderId,
    String cancellationReason,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        context,
        'Please login to cancel the order.',
      );
      return;
    }

    if (orderId.trim().isEmpty) {
      showMessage(
        context,
        'Invalid order.',
      );
      return;
    }

    try {
      final firestore =
          FirebaseFirestore.instance;

      final orderRef =
          firestore.collection('orders').doc(orderId);

      await firestore.runTransaction(
        (transaction) async {
          // ======================================================
          // READ ORDER
          // ======================================================

          final orderSnapshot =
              await transaction.get(orderRef);

          if (!orderSnapshot.exists) {
            throw Exception(
              'Order not found.',
            );
          }

          final data =
              orderSnapshot.data();

          if (data == null) {
            throw Exception(
              'Order information not found.',
            );
          }

          // ======================================================
          // SECURITY CHECK
          // ======================================================

          final orderUserId =
              data['userId']?.toString() ?? '';

          if (orderUserId != user.uid) {
            throw Exception(
              'You are not allowed to cancel this order.',
            );
          }

          // ======================================================
          // CURRENT STATUS
          // ======================================================

          final rawStatus =
              data['status']?.toString() ?? 'Placed';

          final currentStatus =
              normalizeStatus(rawStatus);

          // ======================================================
          // DUPLICATE CANCELLATION PROTECTION
          // ======================================================

          if (currentStatus == 'Cancelled') {
            throw Exception(
              'This order has already been cancelled.',
            );
          }

          // ======================================================
          // CANCELLATION RULE
          //
          // Customer can cancel:
          // Placed
          // Confirmed
          //
          // Customer cannot cancel:
          // Packed
          // Shipped
          // Delivered
          // Cancelled
          // ======================================================

          if (!canCustomerCancel(
            currentStatus,
          )) {
            throw Exception(
              'This order can no longer be cancelled because it has already been processed.',
            );
          }

          // ======================================================
          // ITEMS
          // ======================================================

          final rawItems = data['items'];

          final items = rawItems is List
              ? List<dynamic>.from(rawItems)
              : <dynamic>[];

          // ======================================================
          // PRODUCT STOCK REFERENCES
          //
          // First read all products.
          // Then update them.
          // ======================================================

          final productUpdates =
              <DocumentReference<Map<String, dynamic>>,
                  int>{};

          for (final item in items) {
            if (item is! Map) {
              continue;
            }

            final productId =
                item['productId']?.toString() ?? '';

            final quantity =
                int.tryParse(
                      item['quantity']?.toString() ??
                          '0',
                    ) ??
                    0;

            if (productId.isEmpty ||
                quantity <= 0) {
              continue;
            }

            final productRef =
                firestore
                    .collection('products')
                    .doc(productId);

            productUpdates[productRef] =
                (productUpdates[productRef] ?? 0) +
                    quantity;
          }

          final productSnapshots =
              <DocumentReference<Map<String, dynamic>>,
                  DocumentSnapshot<Map<String, dynamic>>>{};

          for (final productRef
              in productUpdates.keys) {
            final productSnapshot =
                await transaction.get(productRef);

            productSnapshots[productRef] =
                productSnapshot;
          }

          // ======================================================
          // RESTORE STOCK
          // ======================================================

          for (final entry
              in productUpdates.entries) {
            final productRef = entry.key;
            final quantityToRestore = entry.value;

            final productSnapshot =
                productSnapshots[productRef];

            if (productSnapshot == null ||
                !productSnapshot.exists) {
              continue;
            }

            final productData =
                productSnapshot.data();

            final currentStock =
                int.tryParse(
                      productData?['Stock']
                              ?.toString() ??
                          '0',
                    ) ??
                    0;

            final restoredStock =
                currentStock + quantityToRestore;

            transaction.update(
              productRef,
              {
                'Stock': restoredStock,
                'updatedAt':
                    FieldValue.serverTimestamp(),
              },
            );
          }

          // ======================================================
          // UPDATE ORDER
          // ======================================================

          transaction.update(
            orderRef,
            {
              'status': 'Cancelled',
              'cancelledBy': 'Customer',
              'cancelledAt':
                  FieldValue.serverTimestamp(),
              'cancellationReason':
                  cancellationReason.trim(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!context.mounted) {
        return;
      }

      showMessage(
        context,
        'Order cancelled successfully. Stock has been restored.',
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) {
        return;
      }

      showMessage(
        context,
        'Cancellation failed:\n${e.message ?? e.code}',
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      showMessage(
        context,
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration:
            const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    // ============================================================
    // NOT LOGGED IN
    // ============================================================

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Orders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Please login to view your orders.',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // ============================================================
    // ORDERS PAGE
    // ============================================================

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          // ======================================================
          // LOADING
          // ======================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ======================================================
          // ERROR
          // ======================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'If this is a Firestore index error, create the index shown in the Firebase error message.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders =
              snapshot.data?.docs ?? [];

          // ======================================================
          // EMPTY
          // ======================================================

          if (orders.isEmpty) {
            return const EmptyOrders();
          }

          // ======================================================
          // ORDER LIST
          // ======================================================

          return ListView.builder(
            padding:
                const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder:
                (context, index) {
              final doc =
                  orders[index];

              final data =
                  doc.data();

              final rawStatus =
                  data['status']
                          ?.toString() ??
                      'Placed';

              final status =
                  normalizeStatus(
                rawStatus,
              );

              final total =
                  data['totalAmount'];

              final createdAt =
                  data['createdAt']
                      as Timestamp?;

              final items =
                  data['items'] is List
                      ? List<dynamic>.from(
                          data['items'],
                        )
                      : <dynamic>[];

              // ==================================================
              // CAN CANCEL?
              // ==================================================

              final canCancel =
                  canCustomerCancel(status);

              final cancellationReason =
                  data['cancellationReason']
                          ?.toString() ??
                      '';

              final cancelledAt =
                  data['cancelledAt']
                      as Timestamp?;

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 16,
                ),
                elevation: 2,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ==========================================
                      // ORDER HEADER
                      // ==========================================

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ID: ${doc.id}',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration:
                                BoxDecoration(
                              color: statusColor(
                                status,
                              ).withOpacity(0.12),
                              borderRadius:
                                  BorderRadius
                                      .circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color:
                                    statusColor(
                                  status,
                                ),
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Date: ${formatDate(createdAt)}',
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                        ),
                      ),

                      if (createdAt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Time: ${formatDateTime(createdAt)}',
                          style: TextStyle(
                            color:
                                Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      const Divider(
                        height: 24,
                      ),

                      // ==========================================
                      // ITEMS
                      // ==========================================

                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (items.isEmpty)
                        Text(
                          'No item details available.',
                          style: TextStyle(
                            color:
                                Colors.grey.shade600,
                          ),
                        ),

                      ...items.map(
                        (item) {
                          if (item is! Map) {
                            return const SizedBox
                                .shrink();
                          }

                          final name =
                              item['name']
                                      ?.toString() ??
                                  'Product';

                          final quantity =
                              item['quantity']
                                      ?.toString() ??
                                  '1';

                          final itemTotal =
                              item['total'];

                          return Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 7,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$name × $quantity',
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  money(
                                    itemTotal,
                                  ),
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const Divider(
                        height: 24,
                      ),

                      // ==========================================
                      // TOTAL
                      // ==========================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            money(total),
                            style:
                                const TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ==========================================
                      // DELIVERY ADDRESS
                      // ==========================================

                      const Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Icon(
                            Icons
                                .local_shipping_outlined,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              [
                                data[
                                        'customerAddress']
                                    ?.toString() ??
                                    data[
                                        'address']
                                        ?.toString() ??
                                    '',
                                data[
                                        'customerCity']
                                    ?.toString() ??
                                    data['city']
                                        ?.toString() ??
                                    '',
                                data[
                                        'customerPincode']
                                    ?.toString() ??
                                    data[
                                        'pincode']
                                        ?.toString() ??
                                    '',
                              ]
                                  .where(
                                    (value) =>
                                        value
                                            .trim()
                                            .isNotEmpty,
                                  )
                                  .join(', '),
                              maxLines: 4,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // ==========================================
                      // GIFT DETAILS
                      // ==========================================

                      if (data['isGift'] ==
                          true) ...[
                        const SizedBox(
                          height: 15,
                        ),
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(12),
                          decoration:
                              BoxDecoration(
                            color: Colors.purple
                                .withOpacity(
                              0.06,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            border:
                                Border.all(
                              color: Colors.purple
                                  .withOpacity(
                                0.2,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                '🎁 Gift Order',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              Text(
                                data[
                                            'giftReceiverName']
                                        ?.toString() ??
                                    'Receiver',
                              ),
                              if ((data[
                                          'giftReceiverMobile']
                                      ?.toString() ??
                                  '')
                                  .isNotEmpty)
                                Text(
                                  'Mobile: ${data['giftReceiverMobile']}',
                                ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                [
                                  data[
                                          'giftReceiverAddress']
                                      ?.toString() ??
                                      '',
                                  data[
                                          'giftReceiverCity']
                                      ?.toString() ??
                                      '',
                                  data[
                                          'giftReceiverPincode']
                                      ?.toString() ??
                                      '',
                                ]
                                    .where(
                                      (value) =>
                                          value
                                              .trim()
                                              .isNotEmpty,
                                    )
                                    .join(', '),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ==========================================
                      // CANCEL ORDER BUTTON
                      // ==========================================

                      if (canCancel) ...[
                        const SizedBox(
                          height: 18,
                        ),
                        SizedBox(
                          width:
                              double.infinity,
                          height: 48,
                          child:
                              OutlinedButton.icon(
                            style:
                                OutlinedButton.styleFrom(
                              foregroundColor:
                                  Colors.red,
                              side:
                                  const BorderSide(
                                color:
                                    Colors.red,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                            ),
                            onPressed: () {
                              confirmCancelOrder(
                                context,
                                doc.id,
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .cancel_outlined,
                            ),
                            label:
                                const Text(
                              'Cancel Order',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        const Center(
                          child: Text(
                            'You can cancel this order before it is packed.',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ),
                      ],

                      // ==========================================
                      // CANCELLED DETAILS
                      // ==========================================

                      if (status ==
                          'Cancelled') ...[
                        const SizedBox(
                          height: 15,
                        ),
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(12),
                          decoration:
                              BoxDecoration(
                            color: Colors.red
                                .withOpacity(
                              0.06,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            border:
                                Border.all(
                              color: Colors.red
                                  .withOpacity(
                                0.2,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    color:
                                        Colors.red,
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'This order has been cancelled.',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.red,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (cancellationReason
                                  .isNotEmpty) ...[
                                const SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  'Reason: $cancellationReason',
                                  style:
                                      const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              ],

                              if (cancelledAt !=
                                  null) ...[
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'Cancelled on: ${formatDateTime(cancelledAt)}',
                                  style:
                                      TextStyle(
                                    fontSize: 12,
                                    color: Colors
                                        .grey
                                        .shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================
// EMPTY ORDERS
// =============================================================

class EmptyOrders extends StatelessWidget {
  const EmptyOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 90,
              color:
                  Colors.grey.shade400,
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Your placed orders will appear here.',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(
              height: 24,
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Start Shopping',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
