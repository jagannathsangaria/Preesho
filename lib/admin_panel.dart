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
  final _formKey = GlobalKey<FormState>();

  final productsRef =
      FirebaseFirestore.instance.collection('products');

  final ordersRef =
      FirebaseFirestore.instance.collection('orders');

  late TabController tabController;

  final functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  static const String adminUid =
      'RkjeRGOd1xdCNFjVR7bB7GXtmAG2';

  // Product controllers
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

  final List<String> lifecycleStatuses = [
    'Placed',
    'Confirmed',
    'Processing',
    'Packed',
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  final Map<String, String> nextAdminStatus = {
    'Placed': 'Confirmed',
    'Confirmed': 'Processing',
    'Processing': 'Packed',
    'Packed': 'Shipped',
  };

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

  List<String> parseImageUrls(String value) {
    return value
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String normalizedOrderStatus(
    Map<String, dynamic> data,
  ) {
    final value =
        data['orderStatus'] ??
        data['status'] ??
        'Placed';

    return value.toString().trim();
  }

  String money(dynamic value) {
    final number =
        value is num
            ? value
            : num.tryParse(value?.toString() ?? '') ?? 0;

    return '₹${number.toStringAsFixed(0)}';
  }

  String formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) {
      return '-';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Color statusColor(String status) {
    switch (status) {
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
        return Colors.amber.shade800;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.shopping_bag_outlined;
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Processing':
        return Icons.settings_outlined;
      case 'Packed':
        return Icons.inventory_2_outlined;
      case 'Shipped':
        return Icons.local_shipping_outlined;
      case 'Picked by Courier':
        return Icons.delivery_dining;
      case 'Out for Delivery':
        return Icons.directions_bike;
      case 'Delivered':
        return Icons.done_all;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final price =
          double.tryParse(priceController.text.trim()) ?? 0;

      final mrp =
          double.tryParse(mrpController.text.trim()) ?? 0;

      final discount =
          double.tryParse(discountController.text.trim()) ?? 0;

      final stock =
          int.tryParse(stockController.text.trim()) ?? 0;

      await productsRef.add({
        'name': nameController.text.trim(),
        'category': categoryController.text.trim(),
        'price': price,
        'mrp': mrp,
        'discount': discount,
        'stock': stock,
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
        'highlights': highlightsController.text
            .split(RegExp(r'[\n,]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _clearProductForm();

      showMessage('Product saved successfully.');
    } catch (e) {
      showMessage('Product save failed.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void _clearProductForm() {
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

  Future<void> editProduct(
    String id,
    Map<String, dynamic> data,
  ) async {
    nameController.text =
        data['name']?.toString() ?? '';

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

    final highlights = data['highlights'];

    if (highlights is List) {
      highlightsController.text =
          highlights.map((e) => e.toString()).join('\n');
    } else {
      highlightsController.text =
          data['highlights']?.toString() ?? '';
    }

    active = data['active'] != false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: productForm(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) {
                  return;
                }

                try {
                  await productsRef.doc(id).update({
                    'name': nameController.text.trim(),
                    'category': categoryController.text.trim(),
                    'price':
                        double.tryParse(
                              priceController.text.trim(),
                            ) ??
                            0,
                    'mrp':
                        double.tryParse(
                              mrpController.text.trim(),
                            ) ??
                            0,
                    'discount':
                        double.tryParse(
                              discountController.text.trim(),
                            ) ??
                            0,
                    'stock':
                        int.tryParse(
                              stockController.text.trim(),
                            ) ??
                            0,
                    'imageUrls': parseImageUrls(
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
                    'highlights': highlightsController.text
                        .split(RegExp(r'[\n,]+'))
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    'active': active,
                    'updatedAt':
                        FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(dialogContext);
                  }

                  showMessage(
                    'Product updated successfully.',
                  );
                } catch (e) {
                  showMessage(
                    'Product update failed.\n$e',
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> deleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text(
            'Are you sure you want to delete this product?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await productsRef.doc(id).delete();
      showMessage('Product deleted.');
    } catch (e) {
      showMessage('Delete failed.\n$e');
    }
  }

  Future<void> uploadExcel() async {
    if (uploadingExcel) {
      return;
    }

    setState(() {
      uploadingExcel = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) {
        return;
      }

      final bytes = result.files.single.bytes;

      if (bytes == null) {
        showMessage('Excel file read nahi ho saki.');
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
              (cell) =>
                  cell?.value?.toString().trim().toLowerCase() ?? '',
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

          if (name.isEmpty) {
            continue;
          }

          await productsRef.add({
            'name': name,
            'category': value('category'),
            'price':
                double.tryParse(value('price')) ?? 0,
            'mrp':
                double.tryParse(value('mrp')) ?? 0,
            'discount':
                double.tryParse(value('discount')) ?? 0,
            'stock':
                int.tryParse(value('stock')) ?? 0,
            'imageUrls': parseImageUrls(
              value('imageurls').isNotEmpty
                  ? value('imageurls')
                  : value('imageurls'),
            ),
            'description': value('description'),
            'remark': value('remark'),
            'brand': value('brand'),
            'material': value('material'),
            'color': value('color'),
            'size': value('size'),
            'weight': value('weight'),
            'warranty': value('warranty'),
            'highlights': value('highlights')
                .split(RegExp(r'[\n,]+'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          count++;
        }
      }

      showMessage(
        '$count products Excel se upload ho gaye.',
      );
    } catch (e) {
      showMessage(
        'Excel upload failed.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingExcel = false;
        });
      }
    }
  }

  Future<void> downloadTemplate() async {
    if (downloadingTemplate) {
      return;
    }

    setState(() {
      downloadingTemplate = true;
    });

    try {
      final excel = Excel.createExcel();

      final sheet =
          excel['Products'];

      sheet.appendRow([
        TextCellValue('name'),
        TextCellValue('category'),
        TextCellValue('price'),
        TextCellValue('mrp'),
        TextCellValue('discount'),
        TextCellValue('stock'),
        TextCellValue('imageUrls'),
        TextCellValue('description'),
        TextCellValue('remark'),
        TextCellValue('brand'),
        TextCellValue('material'),
        TextCellValue('color'),
        TextCellValue('size'),
        TextCellValue('weight'),
        TextCellValue('warranty'),
        TextCellValue('highlights'),
      ]);

      sheet.appendRow([
        TextCellValue('Sample Product'),
        TextCellValue('Fashion'),
        TextCellValue('499'),
        TextCellValue('799'),
        TextCellValue('300'),
        IntCellValue(20),
        TextCellValue('https://example.com/image.jpg'),
        TextCellValue('Sample product description'),
        TextCellValue('New'),
        TextCellValue('Preesho'),
        TextCellValue('Cotton'),
        TextCellValue('Black'),
        TextCellValue('M'),
        TextCellValue('500g'),
        TextCellValue('1 Year'),
        TextCellValue('Premium\nBest Seller'),
      ]);

      final bytes = excel.encode();

      if (bytes == null) {
        showMessage('Template create nahi hua.');
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
      showMessage(
        'Template download failed.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          downloadingTemplate = false;
        });
      }
    }
  }

  Future<void> updateOrderStatus(
    String orderId,
    String nextStatus,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Admin login required.');
      return;
    }

    if (user.uid != adminUid) {
      showMessage('Admin permission denied.');
      return;
    }

    try {
      final orderRef =
          ordersRef.doc(orderId.trim());

      await FirebaseFirestore.instance
          .runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(orderRef);

          if (!snapshot.exists) {
            throw Exception(
              'Order not found: $orderId',
            );
          }

          final data =
              snapshot.data() ??
                  <String, dynamic>{};

          final currentStatus =
              normalizedOrderStatus(data);

          final history =
              data['statusHistory'] is List
                  ? List<dynamic>.from(
                      data['statusHistory'],
                    )
                  : <dynamic>[];

          history.add({
            'status': nextStatus,
            'updatedBy': user.uid,
            'timestamp': Timestamp.now(),
          });

          transaction.update(
            orderRef,
            {
              'orderStatus': nextStatus,
              'status': nextStatus,
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'updatedBy': user.uid,
              'statusHistory': history,
            },
          );

          debugPrint(
            'Order $orderId: '
            '$currentStatus -> $nextStatus',
          );
        },
      );

      showMessage(
        'Order status updated to $nextStatus.',
      );
    } catch (e) {
      showMessage(
        'Status update failed.\n$e',
      );
    }
  }

  // ============================================================
  // SHIP ORDER
  // Packed -> Shipped is handled DIRECTLY through Firestore.
  // No shipOrder Cloud Function is required.
  // ============================================================

  Future<void> showShipmentDialog(
    String orderId,
  ) async {
    final partnerController =
        TextEditingController();

    final trackingController =
        TextEditingController();

    final trackingUrlController =
        TextEditingController();

    final personNameController =
        TextEditingController();

    final phoneController =
        TextEditingController();

    final formKey =
        GlobalKey<FormState>();

    try {
      final confirmed =
          await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.local_shipping,
                ),
                SizedBox(width: 8),
                Text('Ship Order'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child:
                  SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller:
                            partnerController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Courier Partner *',
                          hintText:
                              'Delhivery / Blue Dart / DTDC',
                          border:
                              OutlineInputBorder(),
                        ),
                        validator:
                            (value) {
                          if (value ==
                                  null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Courier Partner required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                            trackingController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Tracking / AWB Number *',
                          hintText:
                              'Enter AWB / Tracking Number',
                          border:
                              OutlineInputBorder(),
                        ),
                        validator:
                            (value) {
                          if (value ==
                                  null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Tracking number required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                            trackingUrlController,
                        keyboardType:
                            TextInputType.url,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Tracking URL',
                          hintText:
                              'https://...',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                            personNameController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Courier Person Name',
                          hintText:
                              'Courier delivery person',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                            phoneController,
                        keyboardType:
                            TextInputType.phone,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Courier Phone',
                          hintText:
                              'Courier phone number',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (!formKey
                      .currentState!
                      .validate()) {
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                icon: const Icon(
                  Icons.local_shipping,
                ),
                label: const Text(
                  'Ship Order',
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      final cleanOrderId =
          orderId.trim();

      if (cleanOrderId.isEmpty) {
        showMessage(
          'Order ID empty hai.',
        );
        return;
      }

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage(
          'Admin login required.',
        );
        return;
      }

      if (user.uid != adminUid) {
        showMessage(
          'Admin permission denied.',
        );
        return;
      }

      final orderRef =
          FirebaseFirestore.instance
              .collection('orders')
              .doc(cleanOrderId);

      await FirebaseFirestore.instance
          .runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            orderRef,
          );

          if (!snapshot.exists) {
            throw Exception(
              'ORDER_NOT_FOUND:$cleanOrderId',
            );
          }

          final data =
              snapshot.data() ??
                  <String, dynamic>{};

          final currentStatus =
              normalizedOrderStatus(
            data,
          );

          if (currentStatus !=
              'Packed') {
            throw Exception(
              'INVALID_SHIP_STATUS:$currentStatus',
            );
          }

          final history =
              data['statusHistory']
                      is List
                  ? List<dynamic>.from(
                      data[
                          'statusHistory'],
                    )
                  : <dynamic>[];

          history.add({
            'status':
                'Shipped',
            'updatedBy':
                user.uid,
            'timestamp':
                Timestamp.now(),
          });

          transaction.update(
            orderRef,
            {
              'orderStatus':
                  'Shipped',
              'status':
                  'Shipped',
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
              'updatedBy':
                  user.uid,
              'shippedAt':
                  FieldValue
                      .serverTimestamp(),
              'courierPartner':
                  partnerController
                      .text
                      .trim(),
              'trackingNumber':
                  trackingController
                      .text
                      .trim(),
              'trackingUrl':
                  trackingUrlController
                      .text
                      .trim(),
              'courierPersonName':
                  personNameController
                      .text
                      .trim(),
              'courierPhone':
                  phoneController
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

      showMessage(
        'Order successfully Shipped.',
      );
    } on FirebaseException catch (e) {
      showMessage(
        'Firebase error\n'
        'Code: ${e.code}\n'
        'Message: ${e.message ?? 'Unknown error'}',
      );
    } catch (e) {
      final error =
          e.toString();

      if (error.startsWith(
        'Exception: ORDER_NOT_FOUND:',
      )) {
        final id =
            error.replaceFirst(
          'Exception: ORDER_NOT_FOUND:',
          '',
        );

        showMessage(
          'Order Firestore mein nahi mila.\n'
          'ID: $id',
        );

        return;
      }

      if (error.startsWith(
        'Exception: INVALID_SHIP_STATUS:',
      )) {
        final currentStatus =
            error.replaceFirst(
          'Exception: INVALID_SHIP_STATUS:',
          '',
        );

        showMessage(
          'Order ko Shipped karne ke liye '
          'current status Packed hona chahiye.\n'
          'Current status: $currentStatus',
        );

        return;
      }

      showMessage(
        'Ship order failed.\n$error',
      );
    } finally {
      partnerController.dispose();
      trackingController.dispose();
      trackingUrlController.dispose();
      personNameController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> confirmCancellation(
    String orderId,
  ) async {
    final reasonController =
        TextEditingController();

    try {
      final reason =
          await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Cancel Order',
            ),
            content: TextField(
              controller: reasonController,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                labelText:
                    'Cancellation reason',
                border:
                    OutlineInputBorder(),
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
                  'Close',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    reasonController.text
                        .trim(),
                  );
                },
                child: const Text(
                  'Cancel Order',
                ),
              ),
            ],
          );
        },
      );

      if (reason == null) {
        return;
      }

      final callable =
          functions.httpsCallable(
        'cancelOrder',
      );

      await callable.call({
        'orderId': orderId,
        'reason': reason,
      });

      showMessage(
        'Order cancelled successfully.',
      );
    } on FirebaseFunctionsException catch (e) {
      showMessage(
        'Cancel failed\n'
        'Code: ${e.code}\n'
        'Message: ${e.message ?? 'Unknown error'}',
      );
    } catch (e) {
      showMessage(
        'Cancel failed.\n$e',
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> assignCourier(
    String orderId,
  ) async {
    try {
      final callable =
          functions.httpsCallable(
        'assignOrderToCourier',
      );

      final result =
          await callable.call({
        'orderId': orderId,
      });

      showMessage(
        result.data?.toString() ??
            'Courier assigned successfully.',
      );
    } on FirebaseFunctionsException catch (e) {
      showMessage(
        'Courier assignment failed\n'
        'Code: ${e.code}\n'
        'Message: ${e.message ?? 'Unknown error'}',
      );
    } catch (e) {
      showMessage(
        'Courier assignment failed.\n$e',
      );
    }
  }

  Widget orderList() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: ordersRef
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
                  const EdgeInsets.all(16),
              child: Text(
                'Orders load failed.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No orders found.',
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder:
              (context, index) {
            final doc = docs[index];

            return orderCard(
              doc.id,
              doc.data(),
            );
          },
        );
      },
    );
  }

  Widget orderCard(
    String orderId,
    Map<String, dynamic> data,
  ) {
    final status =
        normalizedOrderStatus(data);

    final next =
        nextAdminStatus[status];

    final customerName =
        data['customerName']?.toString() ??
            data['name']?.toString() ??
            'Customer';

    final total =
        data['totalAmount'] ??
        data['total'] ??
        data['amount'] ??
        0;

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ID: $orderId',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customer: $customerName',
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${money(total)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${formatDate(data['createdAt'])}',
            ),
            const SizedBox(height: 12),
            orderItemsSection(data),
            const SizedBox(height: 12),
            orderTimeline(status),
            const SizedBox(height: 12),
            statusHistorySection(data),
            const SizedBox(height: 12),
            courierInfoSection(data),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (next != null)
                  ElevatedButton.icon(
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
                      statusIcon(next),
                    ),
                    label: Text(
                      next == 'Shipped'
                          ? 'Ship Order'
                          : 'Mark $next',
                    ),
                  ),
                if (status ==
                    'Shipped')
                  OutlinedButton.icon(
                    onPressed: () {
                      assignCourier(
                        orderId,
                      );
                    },
                    icon: const Icon(
                      Icons.person_add_alt_1,
                    ),
                    label: const Text(
                      'Assign Courier',
                    ),
                  ),
                if (status !=
                        'Delivered' &&
                    status !=
                        'Cancelled')
                  OutlinedButton.icon(
                    onPressed: () {
                      confirmCancellation(
                        orderId,
                      );
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                    ),
                    label: const Text(
                      'Cancel',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget orderItemsSection(
    Map<String, dynamic> data,
  ) {
    final items = data['items'];

    if (items is! List ||
        items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) {
              if (item is! Map) {
                return Text(
                  item.toString(),
                );
              }

              final name =
                  item['name']?.toString() ??
                      item['productName']
                          ?.toString() ??
                      'Product';

              final quantity =
                  item['quantity'] ??
                      item['qty'] ??
                      1;

              final price =
                  item['price'] ??
                      item['sellingPrice'] ??
                      0;

              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                      ),
                    ),
                    Text(
                      'Qty: $quantity',
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Text(
                      money(price),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget statusChip(String status) {
    final color =
        statusColor(status);

    return Chip(
      avatar: Icon(
        statusIcon(status),
        size: 18,
        color: color,
      ),
      label: Text(status),
    );
  }

  Widget orderTimeline(String currentStatus) {
    final currentIndex =
        lifecycleStatuses.indexOf(
      currentStatus,
    );

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            lifecycleStatuses.length -
                1,
        itemBuilder:
            (context, index) {
          final status =
              lifecycleStatuses[index];

          final completed =
              currentIndex >= index &&
                  currentIndex >= 0;

          return _timelineItem(
            status,
            completed,
          );
        },
      ),
    );
  }

  Widget _timelineItem(
    String status,
    bool completed,
  ) {
    final color =
        completed
            ? statusColor(status)
            : Colors.grey;

    return SizedBox(
      width: 105,
      child: Column(
        children: [
          Icon(
            statusIcon(status),
            color: color,
            size: 26,
          ),
          const SizedBox(height: 5),
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  completed
                      ? FontWeight.bold
                      : FontWeight.normal,
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
      children: history.reversed.map(
        (item) {
          if (item is! Map) {
            return ListTile(
              title: Text(
                item.toString(),
              ),
            );
          }

          final status =
              item['status']?.toString() ??
                  '-';

          return ListTile(
            dense: true,
            leading: Icon(
              statusIcon(status),
              color:
                  statusColor(status),
            ),
            title: Text(status),
            subtitle: Text(
              formatDate(
                item['timestamp'],
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  Widget courierInfoSection(
    Map<String, dynamic> data,
  ) {
    final partner =
        data['courierPartner']
                ?.toString() ??
            '';

    final tracking =
        data['trackingNumber']
                ?.toString() ??
            '';

    final trackingUrl =
        data['trackingUrl']
                ?.toString() ??
            '';

    final person =
        data['courierPersonName']
                ?.toString() ??
            '';

    final phone =
        data['courierPhone']
                ?.toString() ??
            '';

    if (partner.isEmpty &&
        tracking.isEmpty &&
        trackingUrl.isEmpty &&
        person.isEmpty &&
        phone.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Courier / Shipment',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (partner.isNotEmpty)
            Text(
              'Courier Partner: $partner',
            ),
          if (tracking.isNotEmpty)
            Text(
              'Tracking / AWB: $tracking',
            ),
          if (trackingUrl.isNotEmpty)
            Text(
              'Tracking URL: $trackingUrl',
            ),
          if (person.isNotEmpty)
            Text(
              'Courier Person: $person',
            ),
          if (phone.isNotEmpty)
            Text(
              'Courier Phone: $phone',
            ),
        ],
      ),
    );
  }

  Widget productForm() {
    return Column(
      children: [
        _mainField(
          'Product Name *',
          nameController,
          required: true,
        ),
        _mainField(
          'Category',
          categoryController,
        ),
        _mainField(
          'Price',
          priceController,
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
        _mainField(
          'MRP',
          mrpController,
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
        _mainField(
          'Discount',
          discountController,
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
        _mainField(
          'Stock',
          stockController,
          keyboardType:
              TextInputType.number,
        ),
        _mainField(
          'Image URLs',
          imageUrlsController,
          maxLines: 4,
          hint:
              'One URL per line',
        ),
        _mainField(
          'Description',
          descriptionController,
          maxLines: 4,
        ),
        _mainField(
          'Remark',
          remarkController,
        ),
        _mainField(
          'Brand',
          brandController,
        ),
        _mainField(
          'Material',
          materialController,
        ),
        _mainField(
          'Color',
          colorController,
        ),
        _mainField(
          'Size',
          sizeController,
        ),
        _mainField(
          'Weight',
          weightController,
        ),
        _mainField(
          'Warranty',
          warrantyController,
        ),
        _mainField(
          'Highlights',
          highlightsController,
          maxLines: 4,
          hint:
              'One highlight per line',
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
      ],
    );
  }

  Widget _mainField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border:
              const OutlineInputBorder(),
        ),
        validator: required
            ? (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '$label required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget productList() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: productsRef
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Products load failed.\n'
              '${snapshot.error}',
              textAlign:
                  TextAlign.center,
            ),
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
              const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder:
              (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final name =
                data['name']
                        ?.toString() ??
                    'Product';

            final price =
                data['price'] ?? 0;

            final stock =
                data['stock'] ?? 0;

            final isActive =
                data['active'] != false;

            return Card(
              child: ListTile(
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${money(price)} • '
                  'Stock: $stock • '
                  '${isActive ? 'Active' : 'Inactive'}',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip:
                          'Edit Product',
                      icon: const Icon(
                        Icons.edit,
                      ),
                      onPressed: () {
                        editProduct(
                          doc.id,
                          data,
                        );
                      },
                    ),
                    IconButton(
                      tooltip:
                          'Delete Product',
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      onPressed: () {
                        deleteProduct(
                          doc.id,
                        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preesho Admin Panel',
        ),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(
              icon:
                  Icon(Icons.add_box_outlined),
              text: 'Products',
            ),
            Tab(
              icon:
                  Icon(Icons.inventory_2_outlined),
              text: 'Product List',
            ),
            Tab(
              icon:
                  Icon(Icons.shopping_bag_outlined),
              text: 'Orders',
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:
                'Vendor Management',
            icon: const Icon(
              Icons.storefront_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const VendorManagementPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip:
                'Courier Management',
            icon: const Icon(
              Icons.local_shipping_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CourierManagementPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          SingleChildScrollView(
            padding:
                const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  productForm(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child:
                            ElevatedButton.icon(
                          onPressed: saving
                              ? null
                              : saveProduct,
                          icon: saving
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
                                  Icons.save,
                                ),
                          label: Text(
                            saving
                                ? 'Saving...'
                                : 'Save Product',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                              const Icon(
                            Icons.upload_file,
                          ),
                          label: Text(
                            uploadingExcel
                                ? 'Uploading...'
                                : 'Upload Excel',
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              downloadingTemplate
                                  ? null
                                  : downloadTemplate,
                          icon:
                              const Icon(
                            Icons.download,
                          ),
                          label: Text(
                            downloadingTemplate
                                ? 'Creating...'
                                : 'Excel Template',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          productList(),
          orderList(),
        ],
      ),
    );
  }
}
