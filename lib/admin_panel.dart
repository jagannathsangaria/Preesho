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
  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);
  static const Color background = Color(0xFFF7F7FA);

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
  // BACK / HOME NAVIGATION
  // ============================================================

  void _goBack() {
    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  Future<bool> _handleSystemBack() async {
    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      return true;
    }

    navigator.pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );

    return false;
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
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate().toLocal();
    } else if (value is DateTime) {
      date = value.toLocal();
    }

    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String? nextAdminStatus(String current) {
    const flow = [
      'Placed',
      'Confirmed',
      'Processing',
      'Packed',
      'Shipped',
    ];

    final index = flow.indexOf(
      normalizedOrderStatus(current),
    );

    if (index == -1 || index >= flow.length - 1) {
      return null;
    }

    return flow[index + 1];
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

  void showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT SAVE
  // ============================================================

  Future<void> saveProduct() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      showMessage(
        'Product name is required.',
        error: true,
      );
      return;
    }

    final price = double.tryParse(
      priceController.text.trim(),
    );

    if (price == null) {
      showMessage(
        'Enter a valid price.',
        error: true,
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final mrp = double.tryParse(
        mrpController.text.trim(),
      );

      final discount = double.tryParse(
        discountController.text.trim(),
      );

      final stock = int.tryParse(
        stockController.text.trim(),
      );

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
      showMessage(
        'Unable to save product.\n$e',
        error: true,
      );
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

  // ============================================================
  // PRODUCT DELETE
  // ============================================================

  Future<void> deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete Product?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This product will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await productsRef.doc(productId).delete();

      showMessage('Product deleted successfully.');
    } catch (e) {
      showMessage(
        'Unable to delete product.\n$e',
        error: true,
      );
    }
  }

  // ============================================================
  // PRODUCT EDIT
  // ============================================================

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

    active = data['active'] != false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool updating = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Edit Product',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
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
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
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
                              error: true,
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

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            showMessage(
                              'Product updated successfully.',
                            );
                          } catch (e) {
                            showMessage(
                              'Unable to update product.\n$e',
                              error: true,
                            );
                          }
                        },
                  icon: updating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    updating
                        ? 'Saving...'
                        : 'Save Changes',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EXCEL UPLOAD
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
        showMessage(
          'Unable to read Excel file.',
          error: true,
        );
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
                  cell?.value?.toString().trim().toLowerCase() ??
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

          await productsRef.add({
            'name': name,
            'category': value('category'),
            'price': price,
            'mrp': mrp,
            'discount':
                double.tryParse(value('discount')) ?? 0,
            'stock': stock,
            'imageUrls':
                parseImageUrls(value('imageurls')),
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

      showMessage(
        '$count product(s) uploaded successfully.',
      );
    } catch (e) {
      showMessage(
        'Excel upload failed.\n$e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingExcel = false;
        });
      }
    }
  }

  // ============================================================
  // EXCEL TEMPLATE
  // ============================================================

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
        headers
            .map((e) => TextCellValue(e))
            .toList(),
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
        showMessage(
          'Unable to create template.',
          error: true,
        );
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
        'Unable to download template.\n$e',
        error: true,
      );
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
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage(
          'Please login again as Admin.',
          error: true,
        );
        return;
      }

      if (user.uid != adminUid) {
        showMessage(
          'Only Admin can update order status.',
          error: true,
        );
        return;
      }

      final orderRef = ordersRef.doc(orderId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(orderRef);

          if (!snapshot.exists) {
            throw Exception('Order not found.');
          }

          final data =
              snapshot.data() ?? {};

          final oldStatus =
              normalizedOrderStatus(
            data['orderStatus'] ??
                data['status'],
          );

          final history =
              List<Map<String, dynamic>>.from(
            (data['statusHistory'] as List? ?? [])
                .map(
                  (item) =>
                      Map<String, dynamic>.from(
                    item as Map,
                  ),
                ),
          );

          history.add({
            'status': newStatus,
            'timestamp': Timestamp.now(),
            'updatedBy': user.uid,
          });

          transaction.update(
            orderRef,
            {
              'orderStatus': newStatus,
              'status': newStatus,
              'previousStatus': oldStatus,
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'updatedBy': user.uid,
              'statusHistory': history,
            },
          );
        },
      );

      showMessage(
        'Order status updated to $newStatus.',
      );
    } catch (e) {
      showMessage(
        'Unable to update order status.\n$e',
        error: true,
      );
    }
  }

  // ============================================================
  // SHIPMENT
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

    final courierNameController =
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Ship Order',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _dialogField(
                        partnerController,
                        'Courier Partner *',
                        Icons.local_shipping_outlined,
                      ),
                      _dialogField(
                        trackingController,
                        'Tracking / AWB Number *',
                        Icons.qr_code_2_outlined,
                      ),
                      _dialogField(
                        trackingUrlController,
                        'Tracking URL',
                        Icons.link_outlined,
                      ),
                      _dialogField(
                        courierNameController,
                        'Courier Person Name',
                        Icons.person_outline,
                      ),
                      _dialogField(
                        courierPhoneController,
                        'Courier Phone',
                        Icons.phone_outlined,
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
                      : () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final partner =
                              partnerController.text.trim();

                          final tracking =
                              trackingController.text.trim();

                          if (partner.isEmpty ||
                              tracking.isEmpty) {
                            showMessage(
                              'Courier Partner and Tracking Number are required.',
                              error: true,
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
                                    'status':
                                        'Shipped',
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
                                        courierNameController
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
                              error: true,
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

    partnerController.dispose();
    trackingController.dispose();
    trackingUrlController.dispose();
    courierNameController.dispose();
    courierPhoneController.dispose();
  }

  // ============================================================
  // COURIER ASSIGNMENT
  // ============================================================

  Future<void> assignCourier(
    String orderId,
    String courierId,
  ) async {
    try {
      final admin =
          FirebaseAuth.instance.currentUser;

      if (admin == null ||
          admin.uid != adminUid) {
        showMessage(
          'Only Admin can assign courier.',
          error: true,
        );
        return;
      }

      final courierSnapshot =
          await _firestore
              .collection('couriers')
              .doc(courierId)
              .get();

      if (!courierSnapshot.exists) {
        showMessage(
          'Courier not found.',
          error: true,
        );
        return;
      }

      final courier =
          courierSnapshot.data() ?? {};

      if (courier['active'] != true) {
        showMessage(
          'This courier is inactive.',
          error: true,
        );
        return;
      }

      final name =
          courier['name']?.toString().trim() ?? '';

      if (name.isEmpty) {
        showMessage(
          'Courier name is missing.',
          error: true,
        );
        return;
      }

      final orderRef =
          ordersRef.doc(orderId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(orderRef);

          if (!snapshot.exists) {
            throw Exception('Order not found.');
          }

          final data =
              snapshot.data() ?? {};

          final status =
              normalizedOrderStatus(
            data['orderStatus'] ??
                data['status'],
          );

          if (status != 'Shipped') {
            throw Exception(
              'Only Shipped orders can be assigned to courier.',
            );
          }

          transaction.update(
            orderRef,
            {
              'courierId': courierId,
              'courierPersonName': name,
              'courierEmail':
                  courier['email']?.toString().trim() ?? '',
              'courierPhone':
                  courier['phone']?.toString().trim() ?? '',
              'courierAssignedAt':
                  FieldValue.serverTimestamp(),
              'courierAssignedBy': admin.uid,
              'trackingStatus': 'Shipped',
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'updatedBy': admin.uid,
            },
          );
        },
      );

      showMessage(
        'Courier assigned successfully.\n$name',
      );
    } catch (e) {
      showMessage(
        'Courier assignment failed.\n$e',
        error: true,
      );
    }
  }

  Future<void> showAssignCourierDialog(
    DocumentSnapshot<Map<String, dynamic>> orderDoc,
  ) async {
    final data = orderDoc.data() ?? {};

    final orderId =
        data['orderId']?.toString().trim().isNotEmpty == true
            ? data['orderId'].toString()
            : orderDoc.id;

    final status =
        normalizedOrderStatus(
      data['orderStatus'] ??
          data['status'],
    );

    if (status != 'Shipped') {
      showMessage(
        'Only Shipped orders can be assigned to a courier.',
        error: true,
      );
      return;
    }

    try {
      final snapshot =
          await _firestore
              .collection('couriers')
              .where(
                'active',
                isEqualTo: true,
              )
              .get();

      if (!mounted) return;

      final couriers = snapshot.docs;

      if (couriers.isEmpty) {
        showMessage(
          'No active couriers available.',
          error: true,
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Assign Courier\nOrder #$orderId',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 500,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: couriers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final courier =
                      couriers[index];

                  final courierData =
                      courier.data();

                  final name =
                      courierData['name']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? courierData['name'].toString()
                      : 'Courier';

                  final phone =
                      courierData['phone']
                              ?.toString()
                              .trim() ??
                          '';

                  final selected =
                      data['courierId']?.toString() ==
                          courier.id;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          primary.withOpacity(.10),
                      child: Icon(
                        Icons.delivery_dining_outlined,
                        color: primary,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      phone.isEmpty
                          ? 'Courier ID: ${courier.id}'
                          : phone,
                    ),
                    trailing: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons
                              .radio_button_unchecked,
                      color: selected
                          ? Colors.green
                          : Colors.grey,
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
          );
        },
      );
    } catch (e) {
      showMessage(
        'Unable to load couriers.\n$e',
        error: true,
      );
    }
  }

  // ============================================================
  // CANCEL ORDER
  // ============================================================

  Future<void> confirmCancellation(
    String orderId,
  ) async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Cancel Order?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Are you sure you want to cancel this order?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Cancel Order'),
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
        e.message ?? 'Unable to cancel order.',
        error: true,
      );
    } catch (e) {
      showMessage(
        'Unable to cancel order.\n$e',
        error: true,
      );
    }
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
          Icons.shopping_bag_outlined,
        ),
        _mainField(
          categoryController,
          'Category',
          Icons.category_outlined,
        ),
        Row(
          children: [
            Expanded(
              child: _mainField(
                priceController,
                'Selling Price',
                Icons.currency_rupee,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mainField(
                mrpController,
                'MRP',
                Icons.sell_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _mainField(
                discountController,
                'Discount %',
                Icons.percent,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mainField(
                stockController,
                'Stock',
                Icons.inventory_2_outlined,
                keyboardType:
                    TextInputType.number,
              ),
            ),
          ],
        ),
        _mainField(
          imageUrlsController,
          'Image URLs',
          Icons.image_outlined,
          maxLines: 4,
          hint: 'One URL per line or comma separated',
        ),
        _mainField(
          descriptionController,
          'Description',
          Icons.description_outlined,
          maxLines: 4,
        ),
        _mainField(
          remarkController,
          'Remark',
          Icons.star_border_rounded,
        ),
        _mainField(
          brandController,
          'Brand',
          Icons.branding_watermark_outlined,
        ),
        Row(
          children: [
            Expanded(
              child: _mainField(
                materialController,
                'Material',
                Icons.texture_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mainField(
                colorController,
                'Color',
                Icons.palette_outlined,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _mainField(
                sizeController,
                'Size',
                Icons.straighten_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mainField(
                weightController,
                'Weight',
                Icons.scale_outlined,
              ),
            ),
          ],
        ),
        _mainField(
          warrantyController,
          'Warranty',
          Icons.verified_outlined,
        ),
        _mainField(
          highlightsController,
          'Highlights',
          Icons.auto_awesome_outlined,
          maxLines: 3,
        ),
        Container(
          margin: const EdgeInsets.only(
            top: 3,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: SwitchListTile(
            title: const Text(
              'Active Product',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Visible to customers',
            ),
            value: active,
            activeColor: primary,
            onChanged: (value) {
              setState(() {
                active = value;
              });
            },
          ),
        ),
        if (includeButton)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed:
                  saving ? null : saveProduct,
              icon: saving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.add_circle_outline,
                    ),
              label: Text(
                saving
                    ? 'Saving Product...'
                    : 'Add Product',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mainField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: primary,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
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
          return _emptyState(
            'Unable to load products',
            snapshot.error.toString(),
            Icons.error_outline,
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyState(
            'No Products',
            'Add your first product from the Products tab.',
            Icons.inventory_2_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            30,
          ),
          itemCount: docs.length,
          itemBuilder: (
            context,
            index,
          ) {
            return _productCard(
              docs[index],
            );
          },
        );
      },
    );
  }

  Widget _productCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    final name =
        data['name']?.toString() ?? 'Product';

    final category =
        data['category']?.toString() ?? '';

    final price = data['price'];

    final stock =
        data['stock'] ?? 0;

    final isActive =
        data['active'] != false;

    String imageUrl = '';

    final images =
        data['imageUrls'];

    if (images is List &&
        images.isNotEmpty) {
      imageUrl =
          images.first.toString();
    }

    return Container(
      margin: const EdgeInsets.only(
        bottom: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: imageUrl.isEmpty
                  ? Icon(
                      Icons.image_outlined,
                      color: Colors.grey.shade500,
                    )
                  : ClipRRect(
                      borderRadius:
                          BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) {
                          return Icon(
                            Icons.broken_image_outlined,
                            color:
                                Colors.grey.shade500,
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(width: 13),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      category,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        money(price),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Stock: $stock',
                        style: TextStyle(
                          color: stock > 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight:
                              FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _statusBadge(
                    isActive
                        ? 'ACTIVE'
                        : 'INACTIVE',
                    isActive
                        ? Colors.green
                        : Colors.red,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(15),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  editProduct(
                    doc.id,
                    data,
                  );
                } else if (value == 'delete') {
                  deleteProduct(doc.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                      ),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDERS
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
          return _emptyState(
            'Unable to load orders',
            snapshot.error.toString(),
            Icons.error_outline,
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyState(
            'No Orders',
            'Customer orders will appear here.',
            Icons.receipt_long_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            30,
          ),
          itemCount: docs.length,
          itemBuilder: (_, index) {
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
    final data = doc.data() ?? {};

    final orderId =
        data['orderId']?.toString().trim().isNotEmpty == true
            ? data['orderId'].toString()
            : doc.id;

    final customerName =
        data['customerName']?.toString().trim().isNotEmpty == true
            ? data['customerName'].toString()
            : 'Customer';

    final status =
        normalizedOrderStatus(
      data['orderStatus'] ??
          data['status'],
    );

    final next =
        nextAdminStatus(status);

    final courier =
        data['courierPersonName']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 43,
                  width: 43,
                  decoration: BoxDecoration(
                    color:
                        primary.withOpacity(.10),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$orderId',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customerName,
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(
                  status,
                  statusColor(status),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _orderItems(data),
            const SizedBox(height: 14),
            _timeline(status),
            if (courier.isNotEmpty) ...[
              const SizedBox(height: 13),
              _infoBox(
                Icons.local_shipping_outlined,
                'Courier Assigned',
                courier,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (next != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (next == 'Shipped') {
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
                        size: 19,
                      ),
                      label: Text(
                        next == 'Shipped'
                            ? 'Ship Order'
                            : 'Mark $next',
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (status == 'Shipped')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showAssignCourierDialog(
                          doc,
                        );
                      },
                      icon: const Icon(
                        Icons
                            .delivery_dining_outlined,
                        size: 19,
                      ),
                      label: Text(
                        courier.isEmpty
                            ? 'Assign Courier'
                            : 'Change Courier',
                      ),
                    ),
                  ),
              ],
            ),
            if (status != 'Delivered' &&
                status != 'Cancelled' &&
                status != 'Shipped')
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    confirmCancellation(
                      orderId,
                    );
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Cancel Order',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _orderItems(
    Map<String, dynamic> data,
  ) {
    final items = data['items'];

    if (items is! List ||
        items.isEmpty) {
      return const Text(
        'No item details available.',
      );
    }

    return Column(
      children: items.take(4).map<Widget>(
        (item) {
          final map =
              item is Map
                  ? Map<String, dynamic>.from(item)
                  : <String, dynamic>{};

          final name =
              map['name']?.toString() ??
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
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name × $quantity',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  money(price),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _timeline(String currentStatus) {
    final currentIndex =
        lifecycleStatuses.indexOf(
      normalizedOrderStatus(
        currentStatus,
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
                      radius: 15,
                      backgroundColor:
                          completed
                              ? statusColor(status)
                              : Colors.grey.shade200,
                      child: Icon(
                        statusIcon(status),
                        size: 15,
                        color: completed
                            ? Colors.white
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 66,
                      child: Text(
                        status,
                        textAlign:
                            TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (index <
                    lifecycleStatuses.length - 1)
                  Container(
                    width: 18,
                    height: 2,
                    margin:
                        const EdgeInsets.only(
                      bottom: 22,
                    ),
                    color:
                        currentIndex > index
                            ? statusColor(status)
                            : Colors.grey.shade200,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _statusBadge(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoBox(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: primary.withOpacity(.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        5,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primary,
            primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(.23),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Preesho Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manage products, orders & delivery',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleSystemBack,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,

          // NEW: Always visible Back button.
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
            ),
          ),

          title: const Text(
            'Admin Panel',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Vendor Management',
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
              tooltip: 'Courier Management',
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
        body: Column(
          children: [
            _adminHeader(),

            const SizedBox(height: 8),

            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.035),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TabBar(
                controller: tabController,
                labelColor: primary,
                unselectedLabelColor:
                    Colors.grey.shade600,
                indicatorColor: primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon:
                        Icon(Icons.add_box_outlined),
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
            ),

            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  SingleChildScrollView(
                    physics:
                        const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      30,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.all(17),
                          decoration:
                              BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                              23,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(.045),
                                blurRadius: 20,
                                offset:
                                    const Offset(
                                  0,
                                  8,
                                ),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add New Product',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add product details for your Preesho catalogue.',
                                style: TextStyle(
                                  color: Colors
                                      .grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 18),
                              productForm(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        Container(
                          padding:
                              const EdgeInsets.all(17),
                          decoration:
                              BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                              23,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(.045),
                                blurRadius: 20,
                                offset:
                                    const Offset(
                                  0,
                                  8,
                                ),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bulk Products',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Upload multiple products using Excel.',
                                style: TextStyle(
                                  color: Colors
                                      .grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 15),
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
                                                      .upload_file_outlined,
                                                ),
                                      label: Text(
                                        uploadingExcel
                                            ? 'Uploading'
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
                                          downloadingTemplate
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
                                                      .download_outlined,
                                                ),
                                      label: const Text(
                                        'Template',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  productList(),

                  orderList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
