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
  // CANCEL ORDER CONFIRMATION
  // ============================================================

  Future<void> confirmCancelOrder(
    BuildContext context,
    String orderId,
  ) async {
    final result = await showDialog<bool>(
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
          content: const Text(
            'Are you sure you want to cancel this order?\n\n'
            'Once cancelled, the order cannot be continued.',
            textAlign: TextAlign.center,
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

    if (result != true) {
      return;
    }

    await cancelOrder(
      context,
      orderId,
    );
  }

  // ============================================================
  // CANCEL ORDER
  // ============================================================

  Future<void> cancelOrder(
    BuildContext context,
    String orderId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        context,
        'Please login to cancel the order.',
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

          final currentStatus =
              data['status']?.toString() ??
                  'Placed';

          // ======================================================
          // CANCELLATION RULE
          //
          // Customer can cancel only:
          // Placed
          // Confirmed
          //
          // Cannot cancel:
          // Packed
          // Shipped
          // Delivered
          // Cancelled
          // ======================================================

          if (currentStatus != 'Placed' &&
              currentStatus != 'Confirmed') {
            throw Exception(
              'This order can no longer be cancelled.',
            );
          }

          // ======================================================
          // ITEMS
          // ======================================================

          final items =
              data['items'] is List
                  ? List<dynamic>.from(
                      data['items'],
                    )
                  : <dynamic>[];

          // ======================================================
          // RESTORE STOCK
          // ======================================================

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

            final productSnapshot =
                await transaction.get(productRef);

            if (!productSnapshot.exists) {
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
                currentStock + quantity;

            transaction.update(
              productRef,
              {
                'Stock': restoredStock,
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

    ScaffoldMessenger.of(context)
        .showSnackBar(
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

              final status =
                  data['status']
                          ?.toString() ??
                      'Placed';

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
                  status == 'Placed' ||
                      status == 'Confirmed';

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 16,
                ),
                color: Colors.white,
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
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            'Order',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

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

                      const SizedBox(height: 8),

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

                      const SizedBox(height: 5),

                      Text(
                        'Date: ${formatDate(createdAt)}',
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                        ),
                      ),

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

                      const SizedBox(height: 10),

                      // ==========================================
                      // DELIVERY ADDRESS
                      // ==========================================

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
                                            .isNotEmpty,
                                  )
                                  .join(', '),
                              maxLines: 3,
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
                            color: Colors
                                .purple
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
                              color: Colors
                                  .purple
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
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
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

                        const Text(
                          'You can cancel this order before it is packed.',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],

                      // ==========================================
                      // CANCELLED MESSAGE
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
                          child:
                              const Row(
                            children: [
                              Icon(
                                Icons
                                    .cancel,
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
