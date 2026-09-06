import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'courier_management_page.dart';
import 'vendor_management_page.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CollectionReference<Map<String, dynamic>> productsRef =
      FirebaseFirestore.instance.collection('products');

  final CollectionReference<Map<String, dynamic>> ordersRef =
      FirebaseFirestore.instance.collection('orders');

  final FirebaseFunctions functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  final String adminUid = 'RkjeRGOd1xdCNFjVR7bB7GXtmAG2';

  late TabController tabController;

  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final mrpController = TextEditingController();
  final discountController = TextEditingController();
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

  final List<String> lifecycleStatuses = const [
    'Placed',
    'Confirmed',
    'Processing',
    'Packed',
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
  ];

  String? nextAdminStatus(String current) {
    final normalized = normalizedOrderStatus(current);

    const adminFlow = [
      'Placed',
      'Confirmed',
      'Processing',
      'Packed',
      'Shipped',
    ];

    final index = adminFlow.indexOf(normalized);

    if (index == -1 || index >= adminFlow.length - 1) {
      return null;
    }

    return adminFlow[index + 1];
  }

  @override
  void initState() {
    super.initState();

    tabController = TabController(
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    tabController.dispose();

    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    mrpController.dispose();
    discountController.dispose();
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
  // HELPERS
  // ============================================================

  List<String> parseImageUrls(String value) {
    return value
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String normalizedOrderStatus(dynamic value) {
    if (value == null) return 'Placed';

    final status = value.toString().trim();

    switch (status.toLowerCase()) {
      case 'placed':
        return 'Placed';

      case 'confirmed':
        return 'Confirmed';

      case 'processing':
        return 'Processing';

      case 'packed':
        return 'Packed';

      case 'shipped':
        return 'Shipped';

      case 'picked by courier':
      case 'picked_by_courier':
      case 'picked':
        return 'Picked by Courier';

      case 'out for delivery':
      case 'out_for_delivery':
      case 'outfordelivery':
        return 'Out for Delivery';

      case 'delivered':
        return 'Delivered';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      default:
        return status;
    }
  }

  String money(dynamic value) {
    if (value == null) return '₹0';

    if (value is num) {
      return '₹${value.toStringAsFixed(0)}';
    }

    final parsed = double.tryParse(
      value.toString().replaceAll(',', '').trim(),
    );

    if (parsed == null) {
      return '₹${value.toString()}';
    }

    return '₹${parsed.toStringAsFixed(0)}';
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    }

    if (value is DateTime) {
      final date = value.toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day/$month/$year';
    }

    return '';
  }

  Color statusColor(String status) {
    switch (normalizedOrderStatus(status)) {
      case 'Placed':
        return Colors.orange;

      case 'Confirmed':
        return Colors.blue;

      case 'Processing':
        return Colors.indigo;

      case 'Packed':
        return Colors.deepPurple;

      case 'Shipped':
        return Colors.teal;

      case 'Picked by Courier':
        return Colors.cyan;

      case 'Out for Delivery':
        return Colors.deepOrange;

      case 'Delivered':
        return Colors.green;

      case 'Cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (normalizedOrderStatus(status)) {
      case 'Placed':
        return Icons.receipt_long_outlined;

      case 'Confirmed':
        return Icons.check_circle_outline;

      case 'Processing':
        return Icons.settings_outlined;

      case 'Packed':
        return Icons.inventory_2_outlined;

      case 'Shipped':
        return Icons.local_shipping_outlined;

      case 'Picked by Courier':
        return Icons.delivery_dining_outlined;

      case 'Out for Delivery':
        return Icons.directions_bike_outlined;

      case 'Delivered':
        return Icons.done_all;

      case 'Cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.circle_outlined;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // PRODUCT
  // ============================================================

  Future<void> saveProduct() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      showMessage('Product name is required.');
      return;
    }

    final price = double.tryParse(
      priceController.text.trim(),
    );

    if (price == null) {
      showMessage('Enter a valid price.');
      return;
    }

    final mrp = double.tryParse(
      mrpController.text.trim(),
    );

    final discount = double.tryParse(
      discountController.text.trim(),
    );

    final stock = int.tryParse(
      stockController.text.trim(),
    );

    setState(() {
      saving = true;
    });

    try {
      await productsRef.add({
        'name': name,
        'category': categoryController.text.trim(),
        'price': price,
        'mrp': mrp ?? price,
        'discount': discount ?? 0,
        'stock': stock ?? 0,
        'imageUrls': parseImageUrls(
          imageUrlsController.text,
        ),
        'description': descriptionController.text.trim(),
        'remark': remarkController.text.trim(),
        'brand': brandController.text.trim(),
        'material': materialController.text.trim(),
        'color': colorController.text.trim(),
        'size': sizeController.text.trim(),
        'weight': weightController.text.trim(),
        'warranty': warrantyController.text.trim(),
        'highlights': highlightsController.text.trim(),
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      clearProductForm();

      showMessage('Product added successfully.');
    } catch (e) {
      showMessage('Unable to save product.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void clearProductForm() {
    nameController.clear();
    categoryController.clear();
    priceController.clear();
    mrpController.clear();
    discountController.clear();
    stockController.clear();
    imageUrlsController.clear();
    descriptionController.clear();
    remarkController.clear();
    brandController.clear();
    materialController.clear();
    colorController.clear();
    sizeController.clear();
    weightController.clear();
    warrantyController.clear();
    highlightsController.clear();

    setState(() {
      active = true;
    });
  }

  void editProduct(
    String productId,
    Map<String, dynamic> data,
  ) {
    nameController.text = data['name']?.toString() ?? '';
    categoryController.text =
        data['category']?.toString() ?? '';
    priceController.text =
        data['price']?.toString() ?? '';
    mrpController.text =
        data['mrp']?.toString() ?? '';
    discountController.text =
        data['discount']?.toString() ?? '';
    stockController.text =
        data['stock']?.toString() ?? '';

    final images = data['imageUrls'];

    if (images is List) {
      imageUrlsController.text =
          images.map((e) => e.toString()).join('\n');
    } else {
      imageUrlsController.text =
          data['imageUrl']?.toString() ?? '';
    }

    descriptionController.text =
        data['description']?.toString() ?? '';
    remarkController.text =
        data['remark']?.toString() ?? '';
    brandController.text =
        data['brand']?.toString() ?? '';
    materialController.text =
        data['material']?.toString() ?? '';
    colorController.text =
        data['color']?.toString() ?? '';
    sizeController.text =
        data['size']?.toString() ?? '';
    weightController.text =
        data['weight']?.toString() ?? '';
    warrantyController.text =
        data['warranty']?.toString() ?? '';
    highlightsController.text =
        data['highlights']?.toString() ?? '';

    setState(() {
      active = data['active'] != false;
    });

    showDialog(
      context: context,
      builder: (context) {
        bool updating = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Edit Product',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: productForm(
                    includeButton: false,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: updating
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: updating
                      ? null
                      : () async {
                          final name =
                              nameController.text.trim();

                          final price =
                              double.tryParse(
                            priceController.text.trim(),
                          );

                          if (name.isEmpty ||
                              price == null) {
                            showMessage(
                              'Product name and valid price are required.',
                            );
                            return;
                          }

                          setDialogState(() {
                            updating = true;
                          });

                          try {
                            await productsRef
                                .doc(productId)
                                .update({
                              'name': name,
                              'category':
                                  categoryController.text.trim(),
                              'price': price,
                              'mrp': double.tryParse(
                                    mrpController.text.trim(),
                                  ) ??
                                  price,
                              'discount':
                                  double.tryParse(
                                        discountController
                                            .text
                                            .trim(),
                                      ) ??
                                      0,
                              'stock':
                                  int.tryParse(
                                        stockController
                                            .text
                                            .trim(),
                                      ) ??
                                      0,
                              'imageUrls':
                                  parseImageUrls(
                                imageUrlsController.text,
                              ),
                              'description':
                                  descriptionController.text.trim(),
                              'remark':
                                  remarkController.text.trim(),
                              'brand':
                                  brandController.text.trim(),
                              'material':
                                  materialController.text.trim(),
                              'color':
                                  colorController.text.trim(),
                              'size':
                                  sizeController.text.trim(),
                              'weight':
                                  weightController.text.trim(),
                              'warranty':
                                  warrantyController.text.trim(),
                              'highlights':
                                  highlightsController.text.trim(),
                              'active': active,
                              'updatedAt':
                                  FieldValue.serverTimestamp(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                            }

                            showMessage(
                              'Product updated successfully.',
                            );
                          } catch (e) {
                            showMessage(
                              'Unable to update product.\n$e',
                            );
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                updating = false;
                              });
                            }
                          }
                        },
                  child: updating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: const Text(
            'This product will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await productsRef.doc(productId).delete();

      showMessage('Product deleted.');
    } catch (e) {
      showMessage('Unable to delete product.\n$e');
    }
  }

  // ============================================================
  // EXCEL
  // ============================================================

  Future<void> uploadExcel() async {
    if (uploadingExcel) return;

    try {
      setState(() {
        uploadingExcel = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) return;

      final bytes = result.files.single.bytes;

      if (bytes == null) {
        showMessage('Unable to read Excel file.');
        return;
      }

      final excel = Excel.decodeBytes(bytes);

      int count = 0;

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];

        if (sheet == null || sheet.rows.isEmpty) {
          continue;
        }

        final headers = sheet.rows.first
            .map(
              (cell) => cell?.value
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  '',
            )
            .toList();

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];

          String value(String key) {
            final index = headers.indexOf(key);

            if (index < 0 || index >= row.length) {
              return '';
            }

            return row[index]?.value?.toString().trim() ?? '';
          }

          final name = value('name');

          if (name.isEmpty) continue;

          final price =
              double.tryParse(value('price')) ?? 0;

          final mrp =
              double.tryParse(value('mrp')) ?? price;

          final stock =
              int.tryParse(value('stock')) ?? 0;

          final imageUrls =
              parseImageUrls(value('imageurls'));

          await productsRef.add({
            'name': name,
            'category': value('category'),
            'price': price,
            'mrp': mrp,
            'discount':
                double.tryParse(value('discount')) ?? 0,
            'stock': stock,
            'imageUrls': imageUrls,
            'description': value('description'),
            'remark': value('remark'),
            'brand': value('brand'),
            'material': value('material'),
            'color': value('color'),
            'size': value('size'),
            'weight': value('weight'),
            'warranty': value('warranty'),
            'highlights': value('highlights'),
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          count++;
        }
      }

      showMessage('$count product(s) uploaded successfully.');
    } catch (e) {
      showMessage('Excel upload failed.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          uploadingExcel = false;
        });
      }
    }
  }

  Future<void> downloadTemplate() async {
    if (downloadingTemplate) return;

    try {
      setState(() {
        downloadingTemplate = true;
      });

      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      final headers = [
        'name',
        'category',
        'price',
        'mrp',
        'discount',
        'stock',
        'imageurls',
        'description',
        'remark',
        'brand',
        'material',
        'color',
        'size',
        'weight',
        'warranty',
        'highlights',
      ];

      sheet.appendRow(
        headers.map((e) => TextCellValue(e)).toList(),
      );

      sheet.appendRow(
        [
          'Sample Product',
          'Fashion',
          '499',
          '699',
          '28',
          '10',
          'https://example.com/image.jpg',
          'Product description',
          'Best Seller',
          'Brand',
          'Cotton',
          'Black',
          'M',
          '500g',
          '1 Year',
          'Comfortable, Durable',
        ].map((e) => TextCellValue(e)).toList(),
      );

      final bytes = excel.encode();

      if (bytes == null) {
        showMessage('Unable to create template.');
        return;
      }

      await FileSaver.instance.saveFile(
        name: 'preesho_product_template',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      showMessage('Excel template downloaded.');
    } catch (e) {
      showMessage('Unable to download template.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          downloadingTemplate = false;
        });
      }
    }
  }

  // ============================================================
  // ORDER STATUS
  // ============================================================

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage('Please login again as Admin.');
        return;
      }

      if (user.uid != adminUid) {
        showMessage('Only Admin can update order status.');
        return;
      }

      final orderRef = ordersRef.doc(orderId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot = await transaction.get(orderRef);

          if (!snapshot.exists) {
            throw Exception('Order not found.');
          }

          final data = snapshot.data() ?? {};

          final oldStatus = normalizedOrderStatus(
            data['orderStatus'] ?? data['status'],
          );

          final history =
              List<Map<String, dynamic>>.from(
            (data['statusHistory'] as List? ?? [])
                .map(
                  (item) => Map<String, dynamic>.from(
                    item as Map,
                  ),
                ),
          );

          history.add({
            'status': newStatus,
            'timestamp': Timestamp.now(),
            'updatedBy': user.uid,
          });

          transaction.update(orderRef, {
            'orderStatus': newStatus,
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': user.uid,
            'statusHistory': history,
            'previousStatus': oldStatus,
          });
        },
      );

      showMessage(
        'Order status updated to $newStatus.',
      );
    } catch (e) {
      showMessage(
        'Unable to update order status.\n$e',
      );
    }
  }

  // ============================================================
  // SHIPMENT
  // ============================================================

  Future<void> showShipmentDialog(
    String orderId,
  ) async {
    final courierPartnerController =
        TextEditingController();

    final trackingNumberController =
        TextEditingController();

    final trackingUrlController =
        TextEditingController();

    final courierPersonNameController =
        TextEditingController();

    final courierPhoneController =
        TextEditingController();

    bool submitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Ship Order',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _editField(
                        courierPartnerController,
                        'Courier Partner *',
                      ),
                      _editField(
                        trackingNumberController,
                        'Tracking / AWB Number *',
                      ),
                      _editField(
                        trackingUrlController,
                        'Tracking URL',
                      ),
                      _editField(
                        courierPersonNameController,
                        'Courier Person Name',
                      ),
                      _editField(
                        courierPhoneController,
                        'Courier Phone',
                        keyboardType:
                            TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                          ),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final partner =
                              courierPartnerController
                                  .text
                                  .trim();

                          final tracking =
                              trackingNumberController
                                  .text
                                  .trim();

                          if (partner.isEmpty ||
                              tracking.isEmpty) {
                            showMessage(
                              'Courier Partner and Tracking Number are required.',
                            );
                            return;
                          }

                          setDialogState(() {
                            submitting = true;
                          });

                          try {
                            final user =
                                FirebaseAuth.instance.currentUser;

                            if (user == null ||
                                user.uid != adminUid) {
                              throw Exception(
                                'Only Admin can ship orders.',
                              );
                            }

                            final orderRef =
                                ordersRef.doc(orderId);

                            await _firestore.runTransaction(
                              (transaction) async {
                                final snapshot =
                                    await transaction.get(
                                  orderRef,
                                );

                                if (!snapshot.exists) {
                                  throw Exception(
                                    'Order not found.',
                                  );
                                }

                                final data =
                                    snapshot.data() ?? {};

                                final currentStatus =
                                    normalizedOrderStatus(
                                  data['orderStatus'] ??
                                      data['status'],
                                );

                                if (currentStatus !=
                                    'Packed') {
                                  throw Exception(
                                    'Only Packed orders can be shipped.',
                                  );
                                }

                                final history =
                                    List<Map<String, dynamic>>.from(
                                  (data['statusHistory']
                                              as List? ??
                                          [])
                                      .map(
                                    (item) =>
                                        Map<String, dynamic>.from(
                                      item as Map,
                                    ),
                                  ),
                                );

                                history.add({
                                  'status': 'Shipped',
                                  'timestamp':
                                      Timestamp.now(),
                                  'updatedBy':
                                      user.uid,
                                });

                                transaction.update(
                                  orderRef,
                                  {
                                    'orderStatus':
                                        'Shipped',
                                    'status': 'Shipped',
                                    'previousStatus':
                                        'Packed',
                                    'updatedAt':
                                        FieldValue.serverTimestamp(),
                                    'updatedBy':
                                        user.uid,
                                    'shippedAt':
                                        FieldValue.serverTimestamp(),
                                    'courierPartner':
                                        partner,
                                    'trackingNumber':
                                        tracking,
                                    'trackingUrl':
                                        trackingUrlController
                                            .text
                                            .trim(),
                                    'courierPersonName':
                                        courierPersonNameController
                                            .text
                                            .trim(),
                                    'courierPhone':
                                        courierPhoneController
                                            .text
                                            .trim(),
                                    'trackingStatus':
                                        'Shipped',
                                    'shippedBy':
                                        user.uid,
                                    'statusHistory':
                                        history,
                                  },
                                );
                              },
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(
                                dialogContext,
                              );
                            }

                            showMessage(
                              'Order shipped successfully.',
                            );
                          } catch (e) {
                            showMessage(
                              'Unable to ship order.\n$e',
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                submitting = false;
                              });
                            }
                          }
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.local_shipping_outlined,
                        ),
                  label: Text(
                    submitting
                        ? 'Shipping...'
                        : 'Ship Order',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    courierPartnerController.dispose();
    trackingNumberController.dispose();
    trackingUrlController.dispose();
    courierPersonNameController.dispose();
    courierPhoneController.dispose();
  }

  // ============================================================
  // DIRECT COURIER ASSIGNMENT
  // ============================================================

  Future<void> assignCourier(
    String orderId,
    String courierId,
  ) async {
    try {
      final adminUser =
          FirebaseAuth.instance.currentUser;

      if (adminUser == null) {
        showMessage(
          'Please login again as Admin.',
        );
        return;
      }

      if (adminUser.uid != adminUid) {
        showMessage(
          'Only Admin can assign courier.',
        );
        return;
      }

      final orderRef =
          ordersRef.doc(orderId);

      final courierRef =
          _firestore.collection('couriers').doc(courierId);

      final courierSnapshot =
          await courierRef.get();

      if (!courierSnapshot.exists) {
        showMessage('Courier not found.');
        return;
      }

      final courierData =
          courierSnapshot.data() ?? {};

      final courierActive =
          courierData['active'] == true;

      if (!courierActive) {
        showMessage(
          'This courier is inactive.',
        );
        return;
      }

      final courierName =
          courierData['name']
                  ?.toString()
                  .trim() ??
              '';

      final courierEmail =
          courierData['email']
                  ?.toString()
                  .trim() ??
              '';

      final courierPhone =
          courierData['phone']
                  ?.toString()
                  .trim() ??
              '';

      if (courierName.isEmpty) {
        showMessage(
          'Courier name is missing.',
        );
        return;
      }

      await _firestore.runTransaction(
        (transaction) async {
          final orderSnapshot =
              await transaction.get(orderRef);

          if (!orderSnapshot.exists) {
            throw Exception(
              'Order not found.',
            );
          }

          final orderData =
              orderSnapshot.data() ?? {};

          final currentStatus =
              normalizedOrderStatus(
            orderData['orderStatus'] ??
                orderData['status'],
          );

          if (currentStatus != 'Shipped') {
            throw Exception(
              'Only Shipped orders can be assigned to courier.',
            );
          }

          transaction.update(
            orderRef,
            {
              'courierId': courierId,
              'courierPersonName':
                  courierName,
              'courierEmail':
                  courierEmail,
              'courierPhone':
                  courierPhone,
              'courierAssignedAt':
                  FieldValue.serverTimestamp(),
              'courierAssignedBy':
                  adminUser.uid,

              // Keep shipment status unchanged.
              'trackingStatus':
                  'Shipped',

              'updatedAt':
                  FieldValue.serverTimestamp(),
              'updatedBy':
                  adminUser.uid,
            },
          );
        },
      );

      showMessage(
        'Courier assigned successfully.\n$courierName',
      );
    } catch (e) {
      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(
          'Exception: '.length,
        );
      }

      showMessage(
        'Courier assignment failed.\n$message',
      );
    }
  }

  Future<void> showAssignCourierDialog(
    DocumentSnapshot<Map<String, dynamic>> orderDoc,
  ) async {
    final orderData =
        orderDoc.data() ?? {};

    final orderId =
        orderData['orderId']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? orderData['orderId'].toString()
        : orderDoc.id;

    final currentCourierId =
        orderData['courierId']
                ?.toString()
                .trim() ??
            '';

    final currentStatus =
        normalizedOrderStatus(
      orderData['orderStatus'] ??
          orderData['status'],
    );

    if (currentStatus != 'Shipped') {
      showMessage(
        'Only Shipped orders can be assigned to a courier.',
      );
      return;
    }

    try {
      final courierSnapshot =
          await _firestore
              .collection('couriers')
              .where(
                'active',
                isEqualTo: true,
              )
              .get();

      if (!mounted) return;

      final couriers =
          courierSnapshot.docs;

      if (couriers.isEmpty) {
        showMessage(
          'No active couriers available.',
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              'Courier Assignment\nOrder #$orderId',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: couriers.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(),
                itemBuilder:
                    (context, index) {
                  final courier =
                      couriers[index];

                  final data =
                      courier.data();

                  final name =
                      data['name']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? data['name'].toString()
                      : 'Courier';

                  final email =
                      data['email']
                              ?.toString()
                              .trim() ??
                          '';

                  final phone =
                      data['phone']
                              ?.toString()
                              .trim() ??
                          '';

                  final selected =
                      currentCourierId ==
                          courier.id;

                  return ListTile(
                    leading:
                        CircleAvatar(
                      child: Icon(
                        Icons
                            .local_shipping_outlined,
                        color: selected
                            ? Colors.green
                            : null,
                      ),
                    ),
                    title: Text(
                      name,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (email.isNotEmpty)
                          email,
                        if (phone.isNotEmpty)
                          phone,
                        'Courier ID: ${courier.id}',
                      ].join('\n'),
                    ),
                    trailing:
                        selected
                            ? const Icon(
                                Icons
                                    .check_circle,
                                color:
                                    Colors.green,
                              )
                            : const Icon(
                                Icons
                                    .radio_button_unchecked,
                              ),
                    onTap: () async {
                      Navigator.pop(
                        dialogContext,
                      );

                      await assignCourier(
                        orderId,
                        courier.id,
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                ),
                child:
                    const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      showMessage(
        'Unable to load active couriers.\n$e',
      );
    }
  }

  // ============================================================
  // CANCELLATION
  // ============================================================

  Future<void> confirmCancellation(
    String orderId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Cancel Order?',
          ),
          content: const Text(
            'Are you sure you want to cancel this order?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('No'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text('Cancel Order'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final callable =
          functions.httpsCallable(
        'cancelOrder',
      );

      await callable.call({
        'orderId': orderId,
      });

      showMessage(
        'Order cancelled successfully.',
      );
    } on FirebaseFunctionsException catch (e) {
      showMessage(
        e.message ??
            'Unable to cancel order.',
      );
    } catch (e) {
      showMessage(
        'Unable to cancel order.\n$e',
      );
    }
  }

  Future<void> assignOrderToCourier(
    String orderId,
    String courierId,
  ) async {
    await assignCourier(
      orderId,
      courierId,
    );
  }

  // ============================================================
  // ORDER LIST
  // ============================================================

  Widget orderList() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: ordersRef
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Text(
                'Unable to load orders.\n\n'
                '${snapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No orders found.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder:
              (context, index) {
            return orderCard(
              docs[index],
            );
          },
        );
      },
    );
  }

  Widget orderCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data =
        doc.data() ?? {};

    final orderId =
        data['orderId']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? data['orderId'].toString()
        : doc.id;

    final customerName =
        data['customerName']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? data['customerName'].toString()
        : data['name']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? data['name'].toString()
        : 'Customer';

    final currentStatus =
        normalizedOrderStatus(
      data['orderStatus'] ??
          data['status'],
    );

    final next =
        nextAdminStatus(
      currentStatus,
    );

    final assignedCourier =
        data['courierPersonName']
                ?.toString()
                .trim() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderId',
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                statusChip(
                  currentStatus,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              customerName,
              style:
                  const TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            orderItemsSection(data),
            const SizedBox(height: 12),
            orderTimeline(
              currentStatus,
            ),
            const SizedBox(height: 12),
            courierInfoSection(data),
            const SizedBox(height: 12),
            statusHistorySection(data),
            const SizedBox(height: 14),
            Row(
              children: [
                if (next != null &&
                    currentStatus != 'Shipped')
                  Expanded(
                    child:
                        FilledButton.icon(
                      onPressed: () {
                        if (next ==
                            'Shipped') {
                          showShipmentDialog(
                            orderId,
                          );
                        } else {
                          updateOrderStatus(
                            orderId,
                            next,
                          );
                        }
                      },
                      icon: Icon(
                        statusIcon(
                          next,
                        ),
                      ),
                      label: Text(
                        next ==
                                'Shipped'
                            ? 'Ship Order'
                            : 'Mark $next',
                      ),
                    ),
                  ),
                if (currentStatus ==
                    'Shipped')
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        showAssignCourierDialog(
                          doc,
                        );
                      },
                      icon: const Icon(
                        Icons
                            .local_shipping_outlined,
                      ),
                      label: Text(
                        assignedCourier.isEmpty
                            ? 'Assign Courier'
                            : 'Change Courier',
                      ),
                    ),
                  ),
              ],
            ),
            if (currentStatus !=
                    'Delivered' &&
                currentStatus !=
                    'Cancelled' &&
                currentStatus !=
                    'Shipped')
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 8,
                ),
                child: SizedBox(
                  width:
                      double.infinity,
                  child:
                      TextButton.icon(
                    onPressed: () {
                      confirmCancellation(
                        orderId,
                      );
                    },
                    icon: const Icon(
                      Icons
                          .cancel_outlined,
                      color: Colors.red,
                    ),
                    label:
                        const Text(
                      'Cancel Order',
                      style:
                          TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget orderItemsSection(
    Map<String, dynamic> data,
  ) {
    final items =
        data['items'];

    if (items is! List ||
        items.isEmpty) {
      return const Text(
        'No item details available.',
        style: TextStyle(
          color: Colors.grey,
        ),
      );
    }

    return Column(
      children: items.map<Widget>(
        (item) {
          final map =
              item is Map
                  ? Map<String, dynamic>.from(
                      item,
                    )
                  : <String, dynamic>{};

          final name =
              map['name']
                      ?.toString() ??
                  'Product';

          final quantity =
              map['quantity'] ??
                  map['qty'] ??
                  1;

          final price =
              map['price'];

          return Padding(
            padding:
                const EdgeInsets.only(
              bottom: 7,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .shopping_bag_outlined,
                  size: 19,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    '$name × $quantity',
                  ),
                ),
                Text(
                  money(price),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  Widget statusChip(
    String status,
  ) {
    final color =
        statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: color.withOpacity(
          0.12,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            statusIcon(status),
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style:
                TextStyle(
              color: color,
              fontWeight:
                  FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget orderTimeline(
    String currentStatus,
  ) {
    final currentIndex =
        lifecycleStatuses.indexOf(
      normalizedOrderStatus(
        currentStatus,
      ),
    );

    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      child: Row(
        children: List.generate(
          lifecycleStatuses.length,
          (index) {
            final status =
                lifecycleStatuses[index];

            final completed =
                currentIndex >= index;

            return Row(
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor:
                          completed
                              ? statusColor(
                                  status,
                                )
                              : Colors
                                  .grey
                                  .shade300,
                      child: Icon(
                        statusIcon(
                          status,
                        ),
                        size: 17,
                        color:
                            completed
                                ? Colors
                                    .white
                                : Colors
                                    .grey,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        status,
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                if (index <
                    lifecycleStatuses.length -
                        1)
                  Container(
                    width: 28,
                    height: 2,
                    color:
                        currentIndex >
                                index
                            ? statusColor(
                                status,
                              )
                            : Colors
                                .grey
                                .shade300,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _timelineItem(
    String status,
    dynamic timestamp,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Icon(
            statusIcon(status),
            size: 18,
            color: statusColor(
              status,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              status,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatDate(
              timestamp,
            ),
            style:
                const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget statusHistorySection(
    Map<String, dynamic> data,
  ) {
    final history =
        data['statusHistory'];

    if (history is! List ||
        history.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding:
          EdgeInsets.zero,
      title: const Text(
        'Status History',
        style: TextStyle(
          fontWeight:
              FontWeight.bold,
        ),
      ),
      children: history.reversed
          .map<Widget>(
            (item) {
              if (item is! Map) {
                return const SizedBox.shrink();
              }

              final map =
                  Map<String, dynamic>.from(
                item,
              );

              return _timelineItem(
                normalizedOrderStatus(
                  map['status'],
                ),
                map['timestamp'],
              );
            },
          )
          .toList(),
    );
  }

  Widget courierInfoSection(
    Map<String, dynamic> data,
  ) {
    final courierId =
        data['courierId']
                ?.toString()
                .trim() ??
            '';

    final courierName =
        data['courierPersonName']
                ?.toString()
                .trim() ??
            '';

    final courierPhone =
        data['courierPhone']
                ?.toString()
                .trim() ??
            '';

    final courierEmail =
        data['courierEmail']
                ?.toString()
                .trim() ??
            '';

    final partner =
        data['courierPartner']
                ?.toString()
                .trim() ??
            '';

    final tracking =
        data['trackingNumber']
                ?.toString()
                .trim() ??
            '';

    if (courierId.isEmpty &&
        courierName.isEmpty &&
        courierPhone.isEmpty &&
        courierEmail.isEmpty &&
        partner.isEmpty &&
        tracking.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border:
            Border.all(
          color:
              Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipment / Courier',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          if (partner.isNotEmpty)
            Text(
              'Courier Partner: $partner',
            ),
          if (tracking.isNotEmpty)
            Text(
              'Tracking / AWB: $tracking',
            ),
          if (courierName.isNotEmpty)
            Text(
              'Courier: $courierName',
            ),
          if (courierPhone.isNotEmpty)
            Text(
              'Phone: $courierPhone',
            ),
          if (courierEmail.isNotEmpty)
            Text(
              'Email: $courierEmail',
            ),
          if (courierId.isNotEmpty)
            Text(
              'Courier ID: $courierId',
              style:
                  const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // PRODUCT FORM
  // ============================================================

  Widget productForm({
    bool includeButton = true,
  }) {
    return Column(
      children: [
        _mainField(
          nameController,
          'Product Name',
        ),
        _mainField(
          categoryController,
          'Category',
        ),
        _mainField(
          priceController,
          'Price',
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
        _mainField(
          mrpController,
          'MRP',
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
        _mainField(
          discountController,
          'Discount %',
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
        _mainField(
          stockController,
          'Stock',
          keyboardType:
              TextInputType.number,
        ),
        _mainField(
          imageUrlsController,
          'Image URLs',
          maxLines: 4,
          hint:
              'One URL per line or comma separated',
        ),
        _mainField(
          descriptionController,
          'Description',
          maxLines: 4,
        ),
        _mainField(
          remarkController,
          'Remark',
        ),
        _mainField(
          brandController,
          'Brand',
        ),
        _mainField(
          materialController,
          'Material',
        ),
        _mainField(
          colorController,
          'Color',
        ),
        _mainField(
          sizeController,
          'Size',
        ),
        _mainField(
          weightController,
          'Weight',
        ),
        _mainField(
          warrantyController,
          'Warranty',
        ),
        _mainField(
          highlightsController,
          'Highlights',
          maxLines: 3,
        ),
        SwitchListTile(
          contentPadding:
              EdgeInsets.zero,
          title: const Text(
            'Active Product',
          ),
          value: active,
          onChanged: (value) {
            setState(() {
              active = value;
            });
          },
        ),
        if (includeButton)
          const SizedBox(
            height: 8,
          ),
        if (includeButton)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  saving
                      ? null
                      : saveProduct,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.add,
                    ),
              label: Text(
                saving
                    ? 'Saving...'
                    : 'Add Product',
              ),
            ),
          ),
      ],
    );
  }

  Widget _mainField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextField(
        controller:
            controller,
        keyboardType:
            keyboardType,
        maxLines:
            maxLines,
        decoration:
            InputDecoration(
          labelText:
              label,
          hintText:
              hint,
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT LIST
  // ============================================================

  Widget productList() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: productsRef
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load products.\n'
              '${snapshot.error}',
              textAlign:
                  TextAlign.center,
            ),
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No products found.',
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.all(16),
          itemCount:
              docs.length,
          itemBuilder:
              (context, index) {
            final doc =
                docs[index];

            final data =
                doc.data();

            final name =
                data['name']
                        ?.toString() ??
                    'Product';

            final category =
                data['category']
                        ?.toString() ??
                    '';

            final price =
                data['price'];

            final stock =
                data['stock'] ?? 0;

            final isActive =
                data['active'] !=
                    false;

            final images =
                data['imageUrls'];

            String imageUrl = '';

            if (images is List &&
                images.isNotEmpty) {
              imageUrl =
                  images.first
                      .toString();
            }

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                        color: Colors
                            .grey
                            .shade100,
                      ),
                      child:
                          imageUrl.isEmpty
                              ? const Icon(
                                  Icons
                                      .image_outlined,
                                )
                              : ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(
                                    10,
                                  ),
                                  child:
                                      Image.network(
                                    imageUrl,
                                    fit: BoxFit
                                        .cover,
                                    errorBuilder:
                                        (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return const Icon(
                                        Icons
                                            .broken_image_outlined,
                                      );
                                    },
                                  ),
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
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize:
                                  16,
                            ),
                          ),
                          if (category
                              .isNotEmpty)
                            Text(
                              category,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.grey,
                              ),
                            ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            '${money(price)} • Stock: $stock',
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            isActive
                                ? 'ACTIVE'
                                : 'INACTIVE',
                            style:
                                TextStyle(
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight.bold,
                              color: isActive
                                  ? Colors
                                      .green
                                  : Colors
                                      .red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<
                        String>(
                      onSelected:
                          (value) {
                        if (value ==
                            'edit') {
                          editProduct(
                            doc.id,
                            data,
                          );
                        }

                        if (value ==
                            'delete') {
                          deleteProduct(
                            doc.id,
                          );
                        }
                      },
                      itemBuilder:
                          (context) {
                        return [
                          const PopupMenuItem(
                            value:
                                'edit',
                            child:
                                Row(
                              children: [
                                Icon(
                                  Icons
                                      .edit_outlined,
                                ),
                                SizedBox(
                                  width:
                                      10,
                                ),
                                Text(
                                  'Edit',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value:
                                'delete',
                            child:
                                Row(
                              children: [
                                Icon(
                                  Icons
                                      .delete_outline,
                                  color:
                                      Colors.red,
                                ),
                                SizedBox(
                                  width:
                                      10,
                                ),
                                Text(
                                  'Delete',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preesho Admin Panel',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        bottom:
            TabBar(
          controller:
              tabController,
          tabs: const [
            Tab(
              icon: Icon(
                Icons.add_box_outlined,
              ),
              text: 'Products',
            ),
            Tab(
              icon: Icon(
                Icons.inventory_2_outlined,
              ),
              text: 'Product List',
            ),
            Tab(
              icon: Icon(
                Icons.receipt_long_outlined,
              ),
              text: 'Orders',
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:
                'Vendor Management',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const VendorManagementPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.storefront_outlined,
            ),
          ),
          IconButton(
            tooltip:
                'Courier Management',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CourierManagementPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.local_shipping_outlined,
            ),
          ),
        ],
      ),
      body:
          TabBarView(
        controller:
            tabController,
        children: [
          SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child:
                      Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    child:
                        productForm(),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Card(
                  child:
                      Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Excel Products',
                          style:
                              TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text(
                          'Bulk upload products using an Excel file.',
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  OutlinedButton.icon(
                                onPressed:
                                    uploadingExcel
                                        ? null
                                        : uploadExcel,
                                icon:
                                    uploadingExcel
                                        ? const SizedBox(
                                            width:
                                                18,
                                            height:
                                                18,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons
                                                .upload_file_outlined,
                                          ),
                                label:
                                    Text(
                                  uploadingExcel
                                      ? 'Uploading...'
                                      : 'Upload Excel',
                                ),
                              ),
                            ),
                            const SizedBox(
                              width:
                                  10,
                            ),
                            Expanded(
                              child:
                                  OutlinedButton.icon(
                                onPressed:
                                    downloadingTemplate
                                        ? null
                                        : downloadTemplate,
                                icon:
                                    downloadingTemplate
                                        ? const SizedBox(
                                            width:
                                                18,
                                            height:
                                                18,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons
                                                .download_outlined,
                                          ),
                                label:
                                    Text(
                                  downloadingTemplate
                                      ? 'Preparing...'
                                      : 'Template',
                                ),
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

          productList(),

          orderList(),
        ],
      ),
    );
  }
}
