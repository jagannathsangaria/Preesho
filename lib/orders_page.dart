import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersPage extends StatelessWidget {
const OrdersPage({super.key});

// =====================================================
// MONEY FORMAT
// =====================================================

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

// =====================================================
// DATE FORMAT
// =====================================================

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

// =====================================================
// STATUS COLOR
// =====================================================

Color statusColor(String status) {
switch (status.toLowerCase()) {
case 'delivered':
return Colors.green;

  case 'cancelled':
    return Colors.red;

  case 'shipped':
    return Colors.blue;

  case 'confirmed':
    return Colors.orange;

  case 'packed':
    return Colors.deepOrange;

  case 'out for delivery':
    return Colors.indigo;

  default:
    return Colors.deepPurple;
}

}

// =====================================================
// CAN CUSTOMER CANCEL?
// =====================================================

bool canCancelOrder(String status) {
return status.toLowerCase() == 'placed';
}

// =====================================================
// CANCEL ORDER
// RESTORE STOCK SAFELY
// =====================================================

Future<void> cancelOrder(
BuildContext context,
String orderId,
) async {
try {
final firestore = FirebaseFirestore.instance;

  final orderRef =
      firestore.collection('orders').doc(orderId);

  await firestore.runTransaction(
    (transaction) async {
      // =================================================
      // GET LATEST ORDER DATA
      // =================================================

      final orderSnapshot =
          await transaction.get(orderRef);

      if (!orderSnapshot.exists) {
        throw Exception('Order not found.');
      }

      final orderData =
          orderSnapshot.data() ?? {};

      final currentStatus =
          orderData['status']?.toString() ??
              'Placed';

      // =================================================
      // DOUBLE CHECK STATUS
      // =================================================

      if (currentStatus.toLowerCase() !=
          'placed') {
        throw Exception(
          'This order can no longer be cancelled.',
        );
      }

      // =================================================
      // GET ORDER ITEMS
      // =================================================

      final items =
          orderData['items'] is List
              ? List<dynamic>.from(
                  orderData['items'],
                )
              : <dynamic>[];

      // =================================================
      // RESTORE PRODUCT STOCK
      // =================================================

      for (final item in items) {
        if (item is! Map) {
          continue;
        }

        final productId =
            item['productId']?.toString();

        if (productId == null ||
            productId.isEmpty) {
          continue;
        }

        final quantity =
            int.tryParse(
                  item['quantity']
                          ?.toString() ??
                      '0',
                ) ??
                0;

        if (quantity <= 0) {
          continue;
        }

        final productRef =
            firestore.collection('products').doc(
                  productId,
                );

        final productSnapshot =
            await transaction.get(productRef);

        // Product deleted by admin?
        // In that case skip stock restore.
        if (!productSnapshot.exists) {
          continue;
        }

        final productData =
            productSnapshot.data() ?? {};

        final currentStock =
            int.tryParse(
                  productData['Stock']
                          ?.toString() ??
                      '0',
                ) ??
                0;

        // Restore stock
        transaction.update(
          productRef,
          {
            'Stock':
                currentStock + quantity,
          },
        );
      }

      // =================================================
      // UPDATE ORDER STATUS
      // =================================================

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

  if (!context.mounted) return;

  ScaffoldMessenger.of(context)
      .hideCurrentSnackBar();

  ScaffoldMessenger.of(context)
      .showSnackBar(
    const SnackBar(
      content: Text(
        'Order cancelled successfully. Stock has been restored.',
      ),
      backgroundColor: Colors.green,
    ),
  );
} on FirebaseException catch (e) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      content: Text(
        'Cancellation failed: ${e.message ?? e.code}',
      ),
      backgroundColor: Colors.red,
    ),
  );
} catch (e) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      content: Text(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      ),
      backgroundColor: Colors.red,
    ),
  );
}

}

// =====================================================
// CANCEL CONFIRMATION
// =====================================================

Future<void> showCancelDialog(
BuildContext context,
String orderId,
) async {
final confirm =
await showDialog<bool>(
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
'The order will be cancelled and the products will be returned to stock.',
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
child: const Text(
'No, Keep Order',
),
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
child: const Text(
'Yes, Cancel',
),
),
],
);
},
);

if (confirm == true && context.mounted) {
  await cancelOrder(
    context,
    orderId,
  );
}

}

// =====================================================
// BUILD
// =====================================================

@override
Widget build(BuildContext context) {
final user = FirebaseAuth.instance.currentUser;

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
      if (snapshot.connectionState ==
          ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

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

      if (orders.isEmpty) {
        return const EmptyOrders();
      }

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

          // ===============================================
          // ADDRESS
          // SUPPORT OLD + NEW FIELD NAMES
          // ===============================================

          final address =
              data['customerAddress']
                      ?.toString() ??
                  data['address']
                      ?.toString() ??
                  '';

          final city =
              data['customerCity']
                      ?.toString() ??
                  data['city']
                      ?.toString() ??
                  '';

          final pincode =
              data['customerPincode']
                      ?.toString() ??
                  data['pincode']
                      ?.toString() ??
                  '';

          final isGift =
              data['isGift'] == true;

          // ===============================================
          // GIFT ADDRESS
          // ===============================================

          final giftAddress =
              data['giftReceiverAddress']
                      ?.toString() ??
                  '';

          final giftCity =
              data['giftReceiverCity']
                      ?.toString() ??
                  '';

          final giftPincode =
              data['giftReceiverPincode']
                      ?.toString() ??
                  '';

          final deliveryAddress =
              isGift
                  ? [
                      giftAddress,
                      giftCity,
                      giftPincode,
                    ]
                      .where(
                        (value) =>
                            value.isNotEmpty,
                      )
                      .join(', ')
                  : [
                      address,
                      city,
                      pincode,
                    ]
                      .where(
                        (value) =>
                            value.isNotEmpty,
                      )
                      .join(', ');

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
                  BorderRadius.circular(
                18,
              ),
            ),

            child: Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [

                  // =========================================
                  // ORDER HEADER
                  // =========================================

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
                          color:
                              statusColor(
                            status,
                          ).withOpacity(
                            0.12,
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
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
                        TextOverflow
                            .ellipsis,
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

                  if (isGift) ...[
                    const SizedBox(height: 8),

                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.purple
                            .withOpacity(
                          0.10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(12),
                      ),
                      child: const Text(
                        '🎁 Gift Order',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],

                  const Divider(
                    height: 24,
                  ),

                  // =========================================
                  // ITEMS
                  // =========================================

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

                  // =========================================
                  // TOTAL
                  // =========================================

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

                  // =========================================
                  // DELIVERY ADDRESS
                  // =========================================

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

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          deliveryAddress.isEmpty
                              ? 'Delivery address unavailable'
                              : deliveryAddress,
                          maxLines: 3,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // =========================================
                  // CANCEL BUTTON
                  // =========================================

                  if (canCancelOrder(
                    status,
                  )) ...[
                    const SizedBox(
                      height: 18,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 46,

                      child:
                          OutlinedButton.icon(
                        onPressed: () {
                          showCancelDialog(
                            context,
                            doc.id,
                          );
                        },

                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: Colors.red,
                        ),

                        label: const Text(
                          'Cancel Order',
                          style: TextStyle(
                            color:
                                Colors.red,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        style:
                            OutlinedButton
                                .styleFrom(
                          side:
                              const BorderSide(
                            color:
                                Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // =========================================
                  // CANCELLED MESSAGE
                  // =========================================

                  if (status
                          .toLowerCase() ==
                      'cancelled') ...[
                    const SizedBox(
                      height: 14,
                    ),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),

                      decoration:
                          BoxDecoration(
                        color: Colors.red
                            .withOpacity(
                          0.08,
                        ),

                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color:
                                Colors.red,
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child: Text(
                              'This order has been cancelled.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.red
                                        .shade700,
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

// =====================================================
// EMPTY ORDERS
// =====================================================

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
          color: Colors.grey.shade400,
        ),

        const SizedBox(height: 20),

        const Text(
          'No orders yet',
          style: TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Your placed orders will appear here.',
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(height: 24),

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
