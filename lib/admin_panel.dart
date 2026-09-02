import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _formKey = GlobalKey<FormState>();

  // ============================================================
  // PRODUCT CONTROLLERS
  // ============================================================

  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();

  final imageUrlsController = TextEditingController();

  final descriptionController = TextEditingController();
  final remarkController = TextEditingController();

  final brandController = TextEditingController();
  final materialController = TextEditingController();
  final colorController = TextEditingController();
  final sizeController = TextEditingController();
  final weightController = TextEditingController();
  final warrantyController = TextEditingController();
  final highlightsController = TextEditingController();

  bool active = true;
  bool saving = false;
  bool uploadingExcel = false;
  bool downloadingTemplate = false;

  final productsRef =
      FirebaseFirestore.instance.collection('products');

  final ordersRef =
      FirebaseFirestore.instance.collection('orders');

  // ============================================================
  // ORDER LIFECYCLE
  // ============================================================

  static const List<String> orderStatuses = [
    'Placed',
    'Confirmed',
    'Processing',
    'Packed',
    'Shipped',
    'Cancelled',
  ];

  static const List<String> lifecycleStatuses = [
    'Placed',
    'Confirmed',
    'Processing',
    'Packed',
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
  ];

  // Admin can manually control only up to Shipped.
  // Courier owns the stages after Shipped.
  // This complete map is kept here as the single source
  // of truth for valid sequential transitions.

  static const Map<String, String> nextLifecycleStatus = {
    'Placed': 'Confirmed',
    'Confirmed': 'Processing',
    'Processing': 'Packed',
    'Packed': 'Shipped',
    'Shipped': 'Picked by Courier',
    'Picked by Courier': 'Out for Delivery',
    'Out for Delivery': 'Delivered',
  };

  static const Map<String, String> nextAdminStatus = {
    'Placed': 'Confirmed',
    'Confirmed': 'Processing',
    'Processing': 'Packed',
    'Packed': 'Shipped',
  };

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    stockController.dispose();
    imageUrlsController.dispose();
    descriptionController.dispose();
    remarkController.dispose();

    brandController.dispose();
    materialController.dispose();
    colorController.dispose();
    sizeController.dispose();
    weightController.dispose();
    warrantyController.dispose();
    highlightsController.dispose();

    super.dispose();
  }

  // ============================================================
  // MULTIPLE IMAGE URL PARSER
  // ============================================================

  List<String> parseImageUrls(String text) {
    return text
        .split(RegExp(r'[\n,]+'))
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  // ============================================================
  // SAVE SINGLE PRODUCT
  // ============================================================

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final stock =
          int.tryParse(stockController.text.trim()) ?? 0;

      final price =
          double.tryParse(priceController.text.trim());

      if (price == null) {
        throw Exception('Please enter a valid price.');
      }

      final imageUrls =
          parseImageUrls(imageUrlsController.text);

      if (imageUrls.isEmpty) {
        throw Exception(
          'Please enter at least one valid image URL.',
        );
      }

      await productsRef.add({
        'Name': nameController.text.trim(),
        'Category': categoryController.text.trim(),
        'Price': price,
        'Stock': stock < 0 ? 0 : stock,
        'ImageUrls': imageUrls,
        'Imageurl': imageUrls.first,
        'Description':
            descriptionController.text.trim(),
        'Remark':
            remarkController.text.trim(),
        'Brand':
            brandController.text.trim(),
        'Material':
            materialController.text.trim(),
        'Color':
            colorController.text.trim(),
        'Size':
            sizeController.text.trim(),
        'Weight':
            weightController.text.trim(),
        'Warranty':
            warrantyController.text.trim(),
        'Highlights':
            highlightsController.text.trim(),
        'Active': active,
        'CreatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      clearForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product added successfully',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error adding product:\n'
            '${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error adding product:\n$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }
            // ============================================================
          // STATUS HISTORY
          // ============================================================

          final history =
              <Map<String, dynamic>>[];

          final oldHistory =
              data['statusHistory'];

          if (oldHistory is List) {
            for (final item in oldHistory) {
              if (item is Map) {
                history.add(
                  Map<String, dynamic>.from(
                    item,
                  ),
                );
              }
            }
          }

          history.add({
            'status': newStatus,
            'timestamp': Timestamp.now(),
            'updatedBy': 'Admin',
          });

          // ============================================================
          // COMMON UPDATE
          // ============================================================

          final updateData =
              <String, dynamic>{
            'orderStatus': newStatus,
            'status': newStatus,
            'statusHistory': history,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

          // ============================================================
          // STAGE TIMESTAMP
          // ============================================================

          switch (newStatus) {
            case 'Confirmed':
              updateData['confirmedAt'] =
                  FieldValue.serverTimestamp();
              break;

            case 'Processing':
              updateData['processingAt'] =
                  FieldValue.serverTimestamp();
              break;

            case 'Packed':
              updateData['packedAt'] =
                  FieldValue.serverTimestamp();
              break;

            case 'Shipped':
              updateData['shippedAt'] =
                  FieldValue.serverTimestamp();

              // Courier flow starts from here.
              updateData['trackingEnabled'] = true;
              updateData['trackingStatus'] = 'Shipped';
              break;

            case 'Picked by Courier':
              updateData['courierPickedAt'] =
                  FieldValue.serverTimestamp();
              updateData['trackingEnabled'] = true;
              updateData['trackingStatus'] =
                  'Picked by Courier';
              break;

            case 'Out for Delivery':
              updateData['outForDeliveryAt'] =
                  FieldValue.serverTimestamp();
              updateData['trackingEnabled'] = true;
              updateData['trackingStatus'] =
                  'Out for Delivery';
              break;

            case 'Delivered':
              updateData['deliveredAt'] =
                  FieldValue.serverTimestamp();
              updateData['trackingEnabled'] = true;
              updateData['trackingStatus'] =
                  'Delivered';
              break;

            case 'Cancelled':
              updateData['cancelled'] = true;

              updateData['cancelledAt'] =
                  FieldValue.serverTimestamp();

              updateData['cancelledBy'] = 'Admin';

              updateData['cancellationReason'] =
                  'Cancelled by Admin';

              updateData['trackingEnabled'] = false;

              break;
          }

          transaction.update(
            docRef,
            updateData,
          );
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Order status updated to $newStatus',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Status update failed:\n'
            '${e.message ?? e.code}',
          ),
          duration:
              const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Status update failed:\n$e',
          ),
          duration:
              const Duration(seconds: 5),
        ),
      );
    }
  }

  // ============================================================
  // COURIER STATUS UPDATE (GROUNDWORK)
  // ============================================================
  // This method is intentionally separate from admin control.
  // Courier may only move one step at a time after Shipped.

  Future<void> updateCourierStatus(
    String orderId,
    String newStatus,
  ) async {
    try {
      final docRef =
          ordersRef.doc(orderId);

      await FirebaseFirestore.instance
          .runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(docRef);

          if (!snapshot.exists) {
            throw Exception(
              'Order no longer exists.',
            );
          }

          final data =
              snapshot.data() ??
                  <String, dynamic>{};

          final currentStatus =
              normalizedOrderStatus(data);

          if (!canCourierUpdateStatus(
            currentStatus,
            newStatus,
          )) {
            throw Exception(
              'Invalid courier transition. '
              '$currentStatus → $newStatus '
              'is not allowed.',
            );
          }

          final history =
              <Map<String, dynamic>>[];

          final oldHistory =
              data['statusHistory'];

          if (oldHistory is List) {
            for (final item in oldHistory) {
              if (item is Map) {
                history.add(
                  Map<String, dynamic>.from(item),
                );
              }
            }
          }

          history.add({
            'status': newStatus,
            'timestamp': Timestamp.now(),
            'updatedBy': 'Courier',
          });

          final updateData =
              <String, dynamic>{
            'orderStatus': newStatus,
            'status': newStatus,
            'trackingStatus': newStatus,
            'trackingEnabled': true,
            'statusHistory': history,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

          switch (newStatus) {
            case 'Picked by Courier':
              updateData['courierPickedAt'] =
                  FieldValue.serverTimestamp();
              break;

            case 'Out for Delivery':
              updateData['outForDeliveryAt'] =
                  FieldValue.serverTimestamp();
              break;

            case 'Delivered':
              updateData['deliveredAt'] =
                  FieldValue.serverTimestamp();
              break;
          }

          transaction.update(
            docRef,
            updateData,
          );
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Courier status updated to $newStatus',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Courier status update failed:\n'
            '${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Courier status update failed:\n$e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'out for delivery':
        return Colors.indigo;

      case 'picked by courier':
        return Colors.deepOrange;

      case 'shipped':
        return Colors.blue;

      case 'packed':
        return Colors.teal;

      case 'processing':
        return Colors.amber.shade800;

      case 'confirmed':
        return Colors.orange;

      case 'placed':
        return Colors.deepPurple;

      default:
        return Colors.deepPurple;
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData statusIcon(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Icons.receipt_long;

      case 'confirmed':
        return Icons.check_circle_outline;

      case 'processing':
        return Icons.settings;

      case 'packed':
        return Icons.inventory_2_outlined;

      case 'shipped':
        return Icons.local_shipping_outlined;

      case 'picked by courier':
        return Icons.delivery_dining;

      case 'out for delivery':
        return Icons.directions_bike;

      case 'delivered':
        return Icons.home_filled;

      case 'cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.info_outline;
    }
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(dynamic value) {
    if (value is num) {
      return '₹${value.toStringAsFixed(0)}';
    }

    final number =
        double.tryParse(
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

  String formatDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      final date = value.toDate();

      final day =
          date.day.toString().padLeft(2, '0');

      final month =
          date.month.toString().padLeft(2, '0');

      final year =
          date.year.toString();

      final hour =
          date.hour.toString().padLeft(2, '0');

      final minute =
          date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year '
          '$hour:$minute';
    }

    if (value is DateTime) {
      final day =
          value.day.toString().padLeft(2, '0');

      final month =
          value.month.toString().padLeft(2, '0');

      final year =
          value.year.toString();

      final hour =
          value.hour.toString().padLeft(2, '0');

      final minute =
          value.minute.toString().padLeft(2, '0');

      return '$day/$month/$year '
          '$hour:$minute';
    }

    return 'Date unavailable';
  }

  // ============================================================
  // GET TIMESTAMP
  // ============================================================

  Timestamp? getTimestamp(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value;
    }

    return null;
  }
                            // ----------------------------------
                            // TRACKING
                            // ----------------------------------

                            orderTimeline(
                              data,
                              status,
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            // ----------------------------------
                            // STATUS HISTORY
                            // ----------------------------------

                            statusHistorySection(
                              data,
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            // ----------------------------------
                            // COURIER
                            // ----------------------------------

                            courierInfoSection(
                              data,
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            // ----------------------------------
                            // ORDER ACTIONS
                            // ----------------------------------
                            // ----------------------------------
                            // ADMIN STATUS CONTROL
                            // ----------------------------------

                            if (status ==
                                'Shipped')
                              Container(
                                width:
                                    double.infinity,
                                padding:
                                    const EdgeInsets
                                        .all(
                                  13,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      Colors.blue
                                          .withOpacity(
                                    0.08,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                    12,
                                  ),
                                  border:
                                      Border.all(
                                    color:
                                        Colors.blue
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
                                          .local_shipping_outlined,
                                      color:
                                          Colors.blue,
                                    ),
                                    SizedBox(
                                      width:
                                          10,
                                    ),
                                    Expanded(
                                      child:
                                          Text(
                                        'Shipped. Admin control completed. '
                                        'Next stages are handled by Courier.',
                                        style:
                                            TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (status ==
                                'Cancelled')
                              Container(
                                width:
                                    double.infinity,
                                padding:
                                    const EdgeInsets
                                        .all(
                                  13,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      Colors.red
                                          .withOpacity(
                                    0.08,
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
                                      width:
                                          10,
                                    ),
                                    Expanded(
                                      child:
                                          Text(
                                        'Order cancelled. No further status changes allowed.',
                                        style:
                                            TextStyle(
                                          color:
                                              Colors.red,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (canChange)
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  const Text(
                                    'Admin Order Control',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize:
                                          17,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        8,
                                  ),
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      12,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(
                                        12,
                                      ),
                                      color:
                                          statusColor(
                                        nextStatus!,
                                      ).withOpacity(
                                        0.07,
                                      ),
                                    ),
                                    child:
                                        Row(
                                      children: [
                                        Icon(
                                          statusIcon(
                                            nextStatus,
                                          ),
                                          color:
                                              statusColor(
                                            nextStatus,
                                          ),
                                        ),
                                        const SizedBox(
                                          width:
                                              10,
                                        ),
                                        Expanded(
                                          child:
                                              Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              const Text(
                                                'Next stage',
                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      11,
                                                ),
                                              ),
                                              Text(
                                                nextStatus,
                                                style:
                                                    TextStyle(
                                                  color:
                                                      statusColor(
                                                    nextStatus,
                                                  ),
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize:
                                                      16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        10,
                                  ),
                                  SizedBox(
                                    width:
                                        double.infinity,
                                    child:
                                        FilledButton.icon(
                                      onPressed:
                                          () {
                                        updateOrderStatus(
                                          doc.id,
                                          nextStatus,
                                        );
                                      },
                                      icon:
                                          Icon(
                                        statusIcon(
                                          nextStatus,
                                        ),
                                      ),
                                      label:
                                          Text(
                                        'Move to $nextStatus',
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(
                              height: 10,
                            ),

                            // ----------------------------------
                            // ADMIN CANCEL OPTION
                            // ----------------------------------

                            if (canCancelOrder(status))
                              SizedBox(
                                width:
                                    double.infinity,
                                child:
                                    OutlinedButton.icon(
                                  onPressed:
                                      () async {
                                    final confirm =
                                        await showDialog<
                                            bool>(
                                      context:
                                          context,
                                      builder:
                                          (dialogContext) {
                                        return AlertDialog(
                                          title:
                                              const Text(
                                            'Cancel Order?',
                                          ),
                                          content:
                                              const Text(
                                            'Are you sure you want to cancel this order?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () {
                                                Navigator.pop(
                                                  dialogContext,
                                                  false,
                                                );
                                              },
                                              child:
                                                  const Text(
                                                'No',
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed:
                                                  () {
                                                Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                );
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

                                    if (confirm ==
                                        true) {
                                      await updateOrderStatus(
                                        doc.id,
                                        'Cancelled',
                                      );
                                    }
                                  },
                                  icon:
                                      const Icon(
                                    Icons
                                        .cancel_outlined,
                                    color:
                                        Colors.red,
                                  ),
                                  label:
                                      const Text(
                                    'Cancel Order',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ).toList(),
              );
            },
          ),

          const SizedBox(
            height: 30,
          ),
        ],
      ),
    );
  }
}
