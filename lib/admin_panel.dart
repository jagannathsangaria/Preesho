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

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ============================================================
  // FIRESTORE
  // ============================================================

  final productsRef =
      FirebaseFirestore.instance.collection('products');

  final ordersRef =
      FirebaseFirestore.instance.collection('orders');

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

  late final TabController tabController;

  // ============================================================
  // ORDER STATUS
  // ============================================================

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

  static const Map<String, String> nextLifecycleStatus = {
    'Placed': 'Confirmed',
    'Confirmed': 'Processing',
    'Processing': 'Packed',
    'Packed': 'Shipped',
    'Shipped': 'Picked by Courier',
    'Picked by Courier': 'Out for Delivery',
    'Out for Delivery': 'Delivered',
  };

  // Admin controls only till Shipped.
  static const Map<String, String> nextAdminStatus = {
    'Placed': 'Confirmed',
    'Confirmed': 'Processing',
    'Processing': 'Packed',
    'Packed': 'Shipped',
  };

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    tabController = TabController(
      length: 3,
      vsync: this,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    tabController.dispose();

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
  // IMAGE URL PARSER
  // ============================================================

  List<String> parseImageUrls(String text) {
    return text
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ============================================================
  // SAVE PRODUCT
  // ============================================================

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final price =
          double.tryParse(priceController.text.trim());

      final stock =
          int.tryParse(stockController.text.trim()) ?? 0;

      if (price == null) {
        throw Exception('Please enter a valid price.');
      }

      final imageUrls =
          parseImageUrls(imageUrlsController.text);

      if (imageUrls.isEmpty) {
        throw Exception(
          'Please enter at least one image URL.',
        );
      }

      await productsRef.add({
        'Name': nameController.text.trim(),
        'Category': categoryController.text.trim(),
        'Price': price,
        'Stock': stock < 0 ? 0 : stock,
        'ImageUrls': imageUrls,
        'Imageurl': imageUrls.first,
        'Description': descriptionController.text.trim(),
        'Remark': remarkController.text.trim(),
        'Brand': brandController.text.trim(),
        'Material': materialController.text.trim(),
        'Color': colorController.text.trim(),
        'Size': sizeController.text.trim(),
        'Weight': weightController.text.trim(),
        'Warranty': warrantyController.text.trim(),
        'Highlights': highlightsController.text.trim(),
        'Active': active,
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      clearForm();

      showMessage(
        'Product added successfully',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Error adding product: $e',
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

  // ============================================================
  // CLEAR PRODUCT FORM
  // ============================================================

  void clearForm() {
    nameController.clear();
    categoryController.clear();
    priceController.clear();
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
  // EXCEL UPLOAD
  // ============================================================

  Future<void> uploadExcel() async {
    try {
      setState(() {
        uploadingExcel = true;
      });

      final result =
          await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'xlsx',
          'xls',
        ],
        withData: true,
      );

      if (result == null) {
        return;
      }

      final Uint8List? bytes =
          result.files.single.bytes;

      if (bytes == null) {
        throw Exception(
          'Unable to read selected Excel file.',
        );
      }

      final excel = Excel.decodeBytes(bytes);

      int added = 0;

      for (final table in excel.tables.values) {
        final rows = table.rows;

        if (rows.isEmpty) {
          continue;
        }

        final headers = rows.first
            .map(
              (cell) =>
                  cell?.value?.toString().trim() ?? '',
            )
            .toList();

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];

          if (row.isEmpty) {
            continue;
          }

          String value(String key) {
            final index =
                headers.indexWhere(
              (h) =>
                  h.toLowerCase() ==
                  key.toLowerCase(),
            );

            if (index == -1 ||
                index >= row.length) {
              return '';
            }

            return row[index]?.value
                    ?.toString()
                    .trim() ??
                '';
          }

          final name = value('Name');

          if (name.isEmpty) {
            continue;
          }

          final price =
              double.tryParse(
                    value('Price'),
                  ) ??
                  0;

          final stock =
              int.tryParse(
                    value('Stock'),
                  ) ??
                  0;

          final imageUrls =
              parseImageUrls(
            value('ImageUrls'),
          );

          final image =
              value('Imageurl');

          if (imageUrls.isEmpty &&
              image.isNotEmpty) {
            imageUrls.add(image);
          }

          await productsRef.add({
            'Name': name,
            'Category': value('Category'),
            'Price': price,
            'Stock': stock < 0 ? 0 : stock,
            'ImageUrls': imageUrls,
            'Imageurl': imageUrls.isNotEmpty
                ? imageUrls.first
                : '',
            'Description':
                value('Description'),
            'Remark': value('Remark'),
            'Brand': value('Brand'),
            'Material': value('Material'),
            'Color': value('Color'),
            'Size': value('Size'),
            'Weight': value('Weight'),
            'Warranty': value('Warranty'),
            'Highlights':
                value('Highlights'),
            'Active': true,
            'CreatedAt':
                FieldValue.serverTimestamp(),
          });

          added++;
        }
      }

      if (!mounted) return;

      showMessage(
        '$added products uploaded successfully',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Excel upload failed: $e',
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
    try {
      setState(() {
        downloadingTemplate = true;
      });

      final excel = Excel.createExcel();

      final sheet =
          excel['Products'];

      final headers = [
        'Name',
        'Category',
        'Price',
        'Stock',
        'ImageUrls',
        'Imageurl',
        'Description',
        'Remark',
        'Brand',
        'Material',
        'Color',
        'Size',
        'Weight',
        'Warranty',
        'Highlights',
      ];

      sheet.appendRow(
        headers
            .map(
              (e) => TextCellValue(e),
            )
            .toList(),
      );

      sheet.appendRow([
        TextCellValue('Sample Product'),
        TextCellValue('Category'),
        TextCellValue('999'),
        TextCellValue('10'),
        TextCellValue('https://example.com/image.jpg'),
        TextCellValue('https://example.com/image.jpg'),
        TextCellValue('Description'),
        TextCellValue('Remark'),
        TextCellValue('Brand'),
        TextCellValue('Material'),
        TextCellValue('Black'),
        TextCellValue('M'),
        TextCellValue('500g'),
        TextCellValue('1 Year'),
        TextCellValue('Feature 1, Feature 2'),
      ]);

      final data = excel.encode();

      if (data == null) {
        throw Exception(
          'Unable to create Excel file.',
        );
      }

      await FileSaver.instance.saveFile(
        name: 'product_template.xlsx',
        bytes: Uint8List.fromList(data),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;

      showMessage(
        'Excel template saved successfully',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Template download failed: $e',
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
  // NORMALIZE ORDER STATUS
  // ============================================================

  String normalizedOrderStatus(
    Map<String, dynamic> data,
  ) {
    final value =
        data['orderStatus'] ??
        data['status'] ??
        'Placed';

    final status =
        value.toString().trim();

    if (status.isEmpty) {
      return 'Placed';
    }

    if (lifecycleStatuses.contains(status)) {
      return status;
    }

    if (status.toLowerCase() ==
        'cancelled') {
      return 'Cancelled';
    }

    return 'Placed';
  }

  // ============================================================
  // ADMIN STATUS VALIDATION
  // ============================================================

  bool canAdminUpdateStatus(
    String current,
    String next,
  ) {
    if (current == 'Cancelled' ||
        current == 'Delivered') {
      return false;
    }

    return nextAdminStatus[current] == next;
  }

  // ============================================================
  // COURIER VALIDATION
  // ============================================================

  bool canCourierUpdateStatus(
    String current,
    String next,
  ) {
    return nextLifecycleStatus[current] == next;
  }

  // ============================================================
  // CANCELLATION
  // ============================================================

  bool canCancelOrder(
    String status,
  ) {
    return status == 'Placed' ||
        status == 'Confirmed' ||
        status == 'Processing';
  }

  // ============================================================
  // UPDATE ORDER STATUS
  // ============================================================

  Future<void> updateOrderStatus(
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

          if (newStatus == 'Cancelled') {
            if (!canCancelOrder(
              currentStatus,
            )) {
              throw Exception(
                'Order cannot be cancelled at '
                '$currentStatus stage.',
              );
            }
          } else {
            if (!canAdminUpdateStatus(
              currentStatus,
              newStatus,
            )) {
              throw Exception(
                'Invalid status transition: '
                '$currentStatus → $newStatus',
              );
            }
          }

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

          final updateData =
              <String, dynamic>{
            'orderStatus': newStatus,
            'status': newStatus,
            'statusHistory': history,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

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
              updateData['trackingEnabled'] =
                  true;
              updateData['trackingStatus'] =
                  'Shipped';
              break;

            case 'Cancelled':
              updateData['cancelled'] = true;
              updateData['cancelledAt'] =
                  FieldValue.serverTimestamp();
              updateData['cancelledBy'] =
                  'Admin';
              updateData['cancellationReason'] =
                  'Cancelled by Admin';
              updateData['trackingEnabled'] =
                  false;
              break;
          }

          transaction.update(
            docRef,
            updateData,
          );
        },
      );

      if (!mounted) return;

      showMessage(
        'Order status updated to $newStatus',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Status update failed: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // COURIER STATUS UPDATE
  // ============================================================

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
              'Invalid courier transition: '
              '$currentStatus → $newStatus',
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

      showMessage(
        'Courier status updated to $newStatus',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Courier update failed: $e',
        error: true,
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
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) {
      return 'Date unavailable';
    }

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

    return '$day/$month/$year $hour:$minute';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor:
            error ? Colors.red : null,
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // PRODUCT FORM
  // ============================================================

  Widget productForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Product',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            field(
              nameController,
              'Product Name',
              required: true,
            ),

            field(
              categoryController,
              'Category',
            ),

            Row(
              children: [
                Expanded(
                  child: field(
                    priceController,
                    'Price',
                    keyboardType:
                        TextInputType.number,
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(
                    stockController,
                    'Stock',
                    keyboardType:
                        TextInputType.number,
                  ),
                ),
              ],
            ),

            field(
              imageUrlsController,
              'Image URLs',
              maxLines: 4,
              hint:
                  'One URL per line or comma separated',
              required: true,
            ),

            field(
              descriptionController,
              'Description',
              maxLines: 4,
            ),

            field(
              remarkController,
              'Remark',
            ),

            field(
              brandController,
              'Brand',
            ),

            field(
              materialController,
              'Material',
            ),

            Row(
              children: [
                Expanded(
                  child: field(
                    colorController,
                    'Color',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(
                    sizeController,
                    'Size',
                  ),
                ),
              ],
            ),

            field(
              weightController,
              'Weight',
            ),

            field(
              warrantyController,
              'Warranty',
            ),

            field(
              highlightsController,
              'Highlights',
              maxLines: 3,
            ),

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,
              title: const Text(
                'Product Active',
              ),
              value: active,
              onChanged: (value) {
                setState(() {
                  active = value;
                });
              },
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    saving ? null : saveProduct,
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
                        Icons.save,
                      ),
                label: Text(
                  saving
                      ? 'Saving...'
                      : 'Save Product',
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploadingExcel
                    ? null
                    : uploadExcel,
                icon: uploadingExcel
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.upload_file,
                      ),
                label: Text(
                  uploadingExcel
                      ? 'Uploading...'
                      : 'Upload Excel',
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    downloadingTemplate
                        ? null
                        : downloadTemplate,
                icon: const Icon(
                  Icons.download,
                ),
                label: Text(
                  downloadingTemplate
                      ? 'Preparing...'
                      : 'Download Excel Template',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GENERIC FIELD
  // ============================================================

  Widget field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '$label is required';
                }

                return null;
              }
            : null,
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
            'CreatedAt',
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
              'Products error:\n${snapshot.error}',
            ),
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
          return const Center(
            child: Text(
              'No products found.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (
            context,
            index,
          ) {
            final doc = docs[index];
            final data = doc.data();

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.shopping_bag,
                  ),
                ),
                title: Text(
                  data['Name']?.toString() ??
                      'Unnamed Product',
                ),
                subtitle: Text(
                  '${money(data['Price'])}  •  '
                  'Stock: ${data['Stock'] ?? 0}',
                ),
                trailing: Icon(
                  data['Active'] == true
                      ? Icons.check_circle
                      : Icons.block,
                  color:
                      data['Active'] == true
                          ? Colors.green
                          : Colors.red,
                ),
              ),
            );
          },
        );
      },
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
            child: Text(
              'Orders error:\n${snapshot.error}',
            ),
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
          return const Center(
            child: Text(
              'No orders found.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (
            context,
            index,
          ) {
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

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget orderCard(
    String orderId,
    Map<String, dynamic> data,
  ) {
    final status =
        normalizedOrderStatus(data);

    final nextStatus =
        nextAdminStatus[status];

    final canChange =
        nextStatus != null;

    return Card(
      margin:
          const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${orderId.substring(
                      0,
                      orderId.length > 8
                          ? 8
                          : orderId.length,
                    )}',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                statusChip(status),
              ],
            ),

            const SizedBox(height: 10),

            if (data['customerName'] != null)
              Text(
                'Customer: ${data['customerName']}',
              ),

            if (data['totalAmount'] != null)
              Text(
                'Amount: ${money(
                  data['totalAmount'],
                )}',
              ),

            const SizedBox(height: 12),

            orderTimeline(
              data,
              status,
            ),

            const SizedBox(height: 12),

            statusHistorySection(
              data,
            ),

            const SizedBox(height: 12),

            courierInfoSection(
              data,
            ),

            const SizedBox(height: 16),

            if (status == 'Shipped')
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color:
                      Colors.blue.withOpacity(
                    .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons
                          .local_shipping_outlined,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Shipped. Admin control completed. '
                        'Next stages are handled by Courier.',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (status == 'Delivered')
              const Text(
                'Order delivered successfully.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight:
                      FontWeight.bold,
                ),
              )
            else if (status == 'Cancelled')
              const Text(
                'Order cancelled. No further changes allowed.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight:
                      FontWeight.bold,
                ),
              )
            else if (canChange)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Order Control',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child:
                        FilledButton.icon(
                      onPressed: () {
                        updateOrderStatus(
                          orderId,
                          nextStatus!,
                        );
                      },
                      icon: Icon(
                        statusIcon(
                          nextStatus!,
                        ),
                      ),
                      label: Text(
                        'Move to $nextStatus',
                      ),
                    ),
                  ),
                ],
              ),

            if (canCancelOrder(status))
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: () =>
                        confirmCancellation(
                      orderId,
                    ),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Cancel Order',
                      style: TextStyle(
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

  // ============================================================
  // CANCEL CONFIRMATION
  // ============================================================

  Future<void> confirmCancellation(
    String orderId,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Cancel Order?'),
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

    if (result == true) {
      await updateOrderStatus(
        orderId,
        'Cancelled',
      );
    }
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget statusChip(
    String status,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
            statusColor(status).withOpacity(
          .12,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor(status),
          fontWeight:
              FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // ORDER TIMELINE
  // ============================================================

  Widget orderTimeline(
    Map<String, dynamic> data,
    String currentStatus,
  ) {
    final cancelled =
        currentStatus == 'Cancelled';

    return Column(
      children: [
        for (int i = 0;
            i < lifecycleStatuses.length;
            i++)
          _timelineItem(
            data,
            lifecycleStatuses[i],
            currentStatus,
            i,
          ),

        if (cancelled)
          ListTile(
            contentPadding:
                EdgeInsets.zero,
            leading: Icon(
              Icons.cancel,
              color: Colors.red,
            ),
            title: const Text(
              'Cancelled',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: Colors.red,
              ),
            ),
            subtitle: Text(
              formatDate(
                data['cancelledAt'],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // TIMELINE ITEM
  // ============================================================

  Widget _timelineItem(
    Map<String, dynamic> data,
    String status,
    String currentStatus,
    int index,
  ) {
    final currentIndex =
        lifecycleStatuses.indexOf(
      currentStatus,
    );

    final completed =
        index <= currentIndex;

    String? timestampField;

    switch (status) {
      case 'Confirmed':
        timestampField = 'confirmedAt';
        break;
      case 'Processing':
        timestampField = 'processingAt';
        break;
      case 'Packed':
        timestampField = 'packedAt';
        break;
      case 'Shipped':
        timestampField = 'shippedAt';
        break;
      case 'Picked by Courier':
        timestampField =
            'courierPickedAt';
        break;
      case 'Out for Delivery':
        timestampField =
            'outForDeliveryAt';
        break;
      case 'Delivered':
        timestampField =
            'deliveredAt';
        break;
    }

    final timestamp =
        timestampField == null
            ? data['createdAt']
            : data[timestampField];

    return ListTile(
      contentPadding:
          EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            completed
                ? statusColor(status)
                : Colors.grey.shade300,
        child: Icon(
          statusIcon(status),
          size: 18,
          color: completed
              ? Colors.white
              : Colors.grey,
        ),
      ),
      title: Text(
        status,
        style: TextStyle(
          fontWeight:
              completed
                  ? FontWeight.bold
                  : FontWeight.normal,
          color:
              completed
                  ? statusColor(status)
                  : Colors.grey,
        ),
      ),
      subtitle: Text(
        completed
            ? formatDate(timestamp)
            : 'Pending',
      ),
    );
  }

  // ============================================================
  // STATUS HISTORY
  // ============================================================

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
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Status History',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      children: history.reversed
          .map<Widget>((item) {
        if (item is! Map) {
          return const SizedBox.shrink();
        }

        final map =
            Map<String, dynamic>.from(
          item,
        );

        return ListTile(
          contentPadding:
              EdgeInsets.zero,
          leading: Icon(
            statusIcon(
              map['status']
                      ?.toString() ??
                  '',
            ),
            color: statusColor(
              map['status']
                      ?.toString() ??
                  '',
            ),
          ),
          title: Text(
            map['status']
                    ?.toString() ??
                'Unknown',
          ),
          subtitle: Text(
            '${map['updatedBy'] ?? 'System'} • '
            '${formatDate(map['timestamp'])}',
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // COURIER INFO
  // ============================================================

  Widget courierInfoSection(
    Map<String, dynamic> data,
  ) {
    final trackingEnabled =
        data['trackingEnabled'] == true;

    final trackingStatus =
        data['trackingStatus']
                ?.toString() ??
            '';

    if (!trackingEnabled &&
        trackingStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Colors.orange.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Courier Tracking',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Status: ${trackingStatus.isEmpty ? "Not available" : trackingStatus}',
          ),
          if (data['trackingNumber'] !=
              null)
            Text(
              'Tracking No: ${data['trackingNumber']}',
            ),
        ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
        ),
        bottom: TabBar(
          controller: tabController,
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
                Icons.shopping_cart_outlined,
              ),
              text: 'Orders',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          productForm(),
          productList(),
          orderList(),
        ],
      ),
    );
  }
}
