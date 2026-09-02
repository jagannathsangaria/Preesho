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
  // DOWNLOAD EXCEL TEMPLATE
  // ============================================================

  Future<void> downloadExcelTemplate() async {
    setState(() {
      downloadingTemplate = true;
    });

    try {
      final excel = Excel.createExcel();

      final sheet = excel['Products'];

      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Category'),
        TextCellValue('Price'),
        TextCellValue('Stock'),
        TextCellValue('ImageUrls'),
        TextCellValue('Description'),
        TextCellValue('Remark'),
        TextCellValue('Brand'),
        TextCellValue('Material'),
        TextCellValue('Color'),
        TextCellValue('Size'),
        TextCellValue('Weight'),
        TextCellValue('Warranty'),
        TextCellValue('Highlights'),
        TextCellValue('Active'),
      ]);

      sheet.appendRow([
        TextCellValue('Water Bottle'),
        TextCellValue('Home & Kitchen'),
        DoubleCellValue(299),
        IntCellValue(50),
        TextCellValue(
          'https://example.com/bottle1.jpg\n'
          'https://example.com/bottle2.jpg\n'
          'https://example.com/bottle3.jpg',
        ),
        TextCellValue(
          'Premium stainless steel water bottle',
        ),
        TextCellValue(
          'Limited time offer',
        ),
        TextCellValue(
          'Preesho',
        ),
        TextCellValue(
          'Stainless Steel',
        ),
        TextCellValue(
          'Silver',
        ),
        TextCellValue(
          '1000 ml',
        ),
        TextCellValue(
          '450 g',
        ),
        TextCellValue(
          '1 Year',
        ),
        TextCellValue(
          'Leak Proof, BPA Free, Premium Quality',
        ),
        TextCellValue('TRUE'),
      ]);

      sheet.appendRow([
        TextCellValue('Premium Pen'),
        TextCellValue('Stationery'),
        DoubleCellValue(99),
        IntCellValue(100),
        TextCellValue(
          'https://example.com/pen1.jpg\n'
          'https://example.com/pen2.jpg',
        ),
        TextCellValue(
          'Smooth writing premium pen',
        ),
        TextCellValue(
          'Best seller',
        ),
        TextCellValue(
          'Preesho',
        ),
        TextCellValue(
          'Metal',
        ),
        TextCellValue(
          'Black',
        ),
        TextCellValue(
          'Medium',
        ),
        TextCellValue(
          '20 g',
        ),
        TextCellValue(
          '6 Months',
        ),
        TextCellValue(
          'Smooth Writing, Premium Finish',
        ),
        TextCellValue('TRUE'),
      ]);

      final List<int>? bytes =
          excel.encode();

      if (bytes == null) {
        throw Exception(
          'Unable to create Excel file',
        );
      }

      await FileSaver.instance.saveFile(
        name: 'Preesho_Product_Template',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Excel template downloaded successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Template download failed:\n$e',
          ),
        ),
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
  // UPLOAD EXCEL PRODUCTS
  // ============================================================

  Future<void> uploadExcelProducts() async {
    try {
      final result =
          await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'xlsx',
          'xls',
        ],
        withData: true,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception(
          'Unable to read selected Excel file.',
        );
      }

      setState(() {
        uploadingExcel = true;
      });

      final excel =
          Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception(
          'Excel file contains no sheet.',
        );
      }

      final sheetName =
          excel.tables.keys.first;

      final sheet =
          excel.tables[sheetName];

      if (sheet == null ||
          sheet.rows.length < 2) {
        throw Exception(
          'Excel file has no product data.',
        );
      }

      final headers = <String, int>{};

      for (
        int i = 0;
        i < sheet.rows.first.length;
        i++
      ) {
        final cell =
            sheet.rows.first[i];

        final value =
            cell?.value
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        if (value.isNotEmpty) {
          headers[value] = i;
        }
      }

      const requiredHeaders = [
        'name',
        'category',
        'price',
        'stock',
      ];

      for (final header
          in requiredHeaders) {
        if (!headers.containsKey(header)) {
          throw Exception(
            'Required column "$header" is missing.\n\n'
            'Please use the Preesho Excel Template.',
          );
        }
      }

      String getCell(
        List<Data?> row,
        String columnName,
      ) {
        final columnIndex =
            headers[columnName];

        if (columnIndex == null ||
            columnIndex >= row.length) {
          return '';
        }

        return row[columnIndex]
                ?.value
                ?.toString()
                .trim() ??
            '';
      }

      int successCount = 0;
      int skippedCount = 0;

      WriteBatch batch =
          FirebaseFirestore.instance.batch();

      int batchCount = 0;

      for (
        int rowIndex = 1;
        rowIndex < sheet.rows.length;
        rowIndex++
      ) {
        final row =
            sheet.rows[rowIndex];

        final name =
            getCell(row, 'name');

        final category =
            getCell(row, 'category');

        final priceText =
            getCell(row, 'price');

        final stockText =
            getCell(row, 'stock');

        final imageUrlsText =
            getCell(row, 'imageurls');

        final oldImageUrl =
            getCell(row, 'imageurl');

        final description =
            getCell(row, 'description');

        final remark =
            getCell(row, 'remark');

        final brand =
            getCell(row, 'brand');

        final material =
            getCell(row, 'material');

        final color =
            getCell(row, 'color');

        final size =
            getCell(row, 'size');

        final weight =
            getCell(row, 'weight');

        final warranty =
            getCell(row, 'warranty');

        final highlights =
            getCell(row, 'highlights');

        final activeText =
            getCell(row, 'active');

        if (name.isEmpty &&
            category.isEmpty &&
            priceText.isEmpty &&
            stockText.isEmpty) {
          continue;
        }

        if (name.isEmpty ||
            category.isEmpty ||
            priceText.isEmpty) {
          skippedCount++;
          continue;
        }

        final numericPrice =
            double.tryParse(
          priceText.replaceAll(
            RegExp(r'[^0-9.]'),
            '',
          ),
        );

        if (numericPrice == null) {
          skippedCount++;
          continue;
        }

        final stock =
            int.tryParse(stockText) ?? 0;

        String imageText =
            imageUrlsText;

        if (imageText.isEmpty) {
          imageText = oldImageUrl;
        }

        final imageUrls =
            parseImageUrls(imageText);

        bool isActive = true;

        if (activeText.isNotEmpty) {
          final normalized =
              activeText
                  .toLowerCase()
                  .trim();

          isActive =
              normalized == 'true' ||
                  normalized == 'yes' ||
                  normalized == '1' ||
                  normalized == 'active';
        }

        final productDoc =
            productsRef.doc();

        batch.set(
          productDoc,
          {
            'Name': name,
            'Category': category,
            'Price': numericPrice,
            'Stock':
                stock < 0 ? 0 : stock,
            'ImageUrls': imageUrls,
            'Imageurl':
                imageUrls.isNotEmpty
                    ? imageUrls.first
                    : '',
            'Description':
                description,
            'Remark':
                remark,
            'Brand':
                brand,
            'Material':
                material,
            'Color':
                color,
            'Size':
                size,
            'Weight':
                weight,
            'Warranty':
                warranty,
            'Highlights':
                highlights,
            'Active':
                isActive,
            'CreatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        batchCount++;
        successCount++;

        if (batchCount >= 450) {
          await batch.commit();

          batch =
              FirebaseFirestore
                  .instance
                  .batch();

          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.upload_file,
                  color: Colors.green,
                ),
                SizedBox(width: 10),
                Text(
                  'Upload Complete',
                ),
              ],
            ),
            content: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully Added: '
                  '$successCount products',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.green,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Skipped: '
                  '$skippedCount rows',
                  style: TextStyle(
                    color:
                        skippedCount > 0
                            ? Colors.orange
                            : Colors.grey,
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                const Text(
                  'Products are now '
                  'available in Firestore.',
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                child:
                    const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Excel upload failed:\n$e',
          ),
          duration:
              const Duration(
            seconds: 5,
          ),
        ),
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
  // CLEAR FORM
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
  // DELETE PRODUCT
  // ============================================================

  Future<void> deleteProduct(
    String id,
    String name,
  ) async {
    try {
      await productsRef
          .doc(id)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '"$name" deleted successfully',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed:\n'
            '${e.message ?? e.code}',
          ),
        ),
      );
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

    return status;
  }

  // ============================================================
  // GET NEXT ADMIN STATUS
  // ============================================================

  String? getNextAdminStatus(
    String currentStatus,
  ) {
    return nextAdminStatus[
        currentStatus];
  }

  // ============================================================
  // STATUS CAN BE UPDATED?
  // ============================================================

  bool canAdminUpdateStatus(
    String currentStatus,
    String newStatus,
  ) {
    if (currentStatus ==
            'Cancelled' ||
        currentStatus ==
            'Shipped' ||
        currentStatus ==
            'Picked by Courier' ||
        currentStatus ==
            'Out for Delivery' ||
        currentStatus ==
            'Delivered') {
      return false;
    }

    final expected =
        nextAdminStatus[
            currentStatus];

    return expected == newStatus;
  }

  // ============================================================
  // UPDATE ORDER STATUS
  //
  // ADMIN FLOW:
  //
  // Placed
  //   ↓
  // Confirmed
  //   ↓
  // Processing
  //   ↓
  // Packed
  //   ↓
  // Shipped
  //
  // AFTER SHIPPED = COURIER FLOW
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
              await transaction.get(
            docRef,
          );

          if (!snapshot.exists) {
            throw Exception(
              'Order no longer exists.',
            );
          }

          final data =
              snapshot.data() ??
                  <String, dynamic>{};

          final currentStatus =
              normalizedOrderStatus(
            data,
          );

          // ----------------------------------------------------
          // PREVENT INVALID TRANSITIONS
          // ----------------------------------------------------

          if (newStatus ==
              'Cancelled') {
            if (currentStatus ==
                    'Shipped' ||
                currentStatus ==
                    'Picked by Courier' ||
                currentStatus ==
                    'Out for Delivery' ||
                currentStatus ==
                    'Delivered') {
              throw Exception(
                'This order cannot be cancelled at this stage.',
              );
            }
          } else {
            if (!canAdminUpdateStatus(
              currentStatus,
              newStatus,
            )) {
              throw Exception(
                'Invalid status transition.\n'
                '$currentStatus → $newStatus is not allowed.',
              );
            }
          }

          // ----------------------------------------------------
          // STATUS HISTORY
          // ----------------------------------------------------

          final history =
              <Map<String, dynamic>>[];

          final oldHistory =
              data['statusHistory'];

          if (oldHistory is List) {
            for (final item
                in oldHistory) {
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
            'timestamp':
                Timestamp.now(),
            'updatedBy': 'Admin',
          });

          // ----------------------------------------------------
          // COMMON UPDATE
          // ----------------------------------------------------

          final updateData =
              <String, dynamic>{
            'orderStatus': newStatus,
            'status': newStatus,
            'statusHistory': history,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

          // ----------------------------------------------------
          // STAGE TIMESTAMP
          // ----------------------------------------------------

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
              updateData['trackingEnabled'] =
                  true;

              updateData['trackingStatus'] =
                  'Shipped';
              break;

            case 'Cancelled':
              updateData['cancelled'] =
                  true;

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
              const Duration(
            seconds: 5,
          ),
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
              const Duration(
            seconds: 5,
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
      final date =
          value.toDate();

      final day =
          date.day
              .toString()
              .padLeft(2, '0');

      final month =
          date.month
              .toString()
              .padLeft(2, '0');

      final year =
          date.year.toString();

      final hour =
          date.hour
              .toString()
              .padLeft(2, '0');

      final minute =
          date.minute
              .toString()
              .padLeft(2, '0');

      return '$day/$month/$year '
          '$hour:$minute';
    }

    if (value is DateTime) {
      final day =
          value.day
              .toString()
              .padLeft(2, '0');

      final month =
          value.month
              .toString()
              .padLeft(2, '0');

      final year =
          value.year.toString();

      final hour =
          value.hour
              .toString()
              .padLeft(2, '0');

      final minute =
          value.minute
              .toString()
              .padLeft(2, '0');

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

  // ============================================================
  // PRODUCT INPUT FIELD
  // ============================================================

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType:
            keyboardType,
        maxLines: maxLines,
        validator:
            validator,
        decoration:
            InputDecoration(
          labelText: label,
          helperText:
              helperText,
          prefixIcon:
              Icon(icon),
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<void> confirmDelete(
    String id,
    String name,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Product?',
          ),
          content: Text(
            'Are you sure you want '
            'to delete "$name"?\n\n'
            'This product will also '
            'disappear from the '
            'customer app.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await deleteProduct(
        id,
        name,
      );
    }
  }

  // ============================================================
  // PRODUCT IMAGE PREVIEW
  // ============================================================

  Widget productImagePreview(
    List<String> imageUrls,
  ) {
    if (imageUrls.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            10,
          ),
        ),
        child: const Icon(
          Icons.image_not_supported,
        ),
      );
    }

    return SizedBox(
      width: 70,
      height: 70,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        child: Image.network(
          imageUrls.first,
          fit: BoxFit.cover,
          errorBuilder:
              (
            context,
            error,
            stack,
          ) {
            return const Icon(
              Icons.image_not_supported,
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // ORDER CUSTOMER DETAILS
  // ============================================================

  Widget customerDetailsSection(
    String name,
    String mobile,
    String email,
    String address,
    String city,
    String pincode,
  ) {
    final addressParts = [
      address,
      city,
      pincode,
    ].where(
      (value) =>
          value.trim().isNotEmpty,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Details',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 17,
          ),
        ),
        const SizedBox(
          height: 9,
        ),
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.person_outline,
              size: 21,
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                name.isEmpty
                    ? 'Customer'
                    : name,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (mobile.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 6,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 20,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    mobile,
                  ),
                ),
              ],
            ),
          ),
        if (email.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 6,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 20,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    email,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(
          height: 14,
        ),
        const Text(
          'Delivery Address',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 21,
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                addressParts.isEmpty
                    ? 'Address not available'
                    : addressParts.join(
                        ', ',
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // ORDER ITEMS
  // ============================================================

  Widget orderItemsSection(
    List<dynamic> items,
  ) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Items',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 17,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        ...items.map(
          (item) {
            if (item is! Map) {
              return const SizedBox
                  .shrink();
            }

            final itemName =
                item['name']
                        ?.toString() ??
                    item['Name']
                        ?.toString() ??
                    'Product';

            final quantity =
                item['quantity']
                        ?.toString() ??
                    item['qty']
                        ?.toString() ??
                    '1';

            final itemTotal =
                item['total'] ??
                    item['price'] ??
                    0;

            final imageUrl =
                item['imageUrl']
                        ?.toString() ??
                    item['image']
                        ?.toString() ??
                    '';

            return Container(
              margin:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              padding:
                  const EdgeInsets.all(
                9,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
                border:
                    Border.all(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                      child:
                          Image.network(
                        imageUrl,
                        width: 48,
                        height: 48,
                        fit:
                            BoxFit.cover,
                        errorBuilder:
                            (
                          context,
                          error,
                          stack,
                        ) {
                          return const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons
                                  .image_not_supported,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons
                            .shopping_bag_outlined,
                      ),
                    ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          itemName,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Qty: $quantity',
                          style:
                              const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money(itemTotal),
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
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

  // ============================================================
  // ORDER STATUS TIMELINE
  // ============================================================

  Widget orderTimeline(
    Map<String, dynamic> data,
    String currentStatus,
  ) {
    if (currentStatus ==
        'Cancelled') {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(12),
        decoration:
            BoxDecoration(
          color:
              Colors.red.withOpacity(
            0.08,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.cancel,
              color: Colors.red,
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'This order has been cancelled.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    int currentIndex =
        lifecycleStatuses
            .indexOf(currentStatus);

    if (currentIndex < 0) {
      currentIndex = 0;
    }

    final timestampFields = [
      'placedAt',
      'confirmedAt',
      'processingAt',
      'packedAt',
      'shippedAt',
      'courierPickedAt',
      'outForDeliveryAt',
      'deliveredAt',
    ];

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Tracking',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 17,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        ...List.generate(
          lifecycleStatuses.length,
          (index) {
            final status =
                lifecycleStatuses[index];

            final completed =
                index <= currentIndex;

            final isCurrent =
                index == currentIndex;

            final timestamp =
                getTimestamp(
              data[
                  timestampFields[
                      index]],
            );

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  SizedBox(
                    width: 30,
                    child: Column(
                      children: [
                        Container(
                          width: 25,
                          height: 25,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            color:
                                completed
                                    ? statusColor(
                                        status,
                                      )
                                    : Colors
                                        .grey
                                        .shade300,
                          ),
                          child:
                              Icon(
                            completed
                                ? Icons.check
                                : statusIcon(
                                    status,
                                  ),
                            size: 14,
                            color:
                                completed
                                    ? Colors
                                        .white
                                    : Colors
                                        .grey
                                        .shade600,
                          ),
                        ),
                        if (index <
                            lifecycleStatuses
                                    .length -
                                1)
                          Expanded(
                            child:
                                Container(
                              width: 2,
                              color:
                                  completed
                                      ? statusColor(
                                          status,
                                        ).withOpacity(
                                          0.5,
                                        )
                                      : Colors
                                          .grey
                                          .shade300,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child:
                        Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 16,
                      ),
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            status,
                            style:
                                TextStyle(
                              fontWeight:
                                  isCurrent
                                      ? FontWeight
                                          .bold
                                      : FontWeight
                                          .w600,
                              color:
                                  completed
                                      ? statusColor(
                                          status,
                                        )
                                      : Colors
                                          .grey
                                          .shade600,
                            ),
                          ),
                          if (timestamp !=
                              null)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 3,
                              ),
                              child:
                                  Text(
                                formatDate(
                                  timestamp,
                                ),
                                style:
                                    const TextStyle(
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
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // STATUS HISTORY
  // ============================================================

  Widget statusHistorySection(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['statusHistory'];

    if (raw is! List ||
        raw.isEmpty) {
      return const SizedBox
          .shrink();
    }

    final history =
        <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is Map) {
        history.add(
          Map<String, dynamic>.from(
            item,
          ),
        );
      }
    }

    history.sort(
      (a, b) {
        final aTime =
            a['timestamp'];

        final bTime =
            b['timestamp'];

        if (aTime is Timestamp &&
            bTime is Timestamp) {
          return bTime
              .compareTo(aTime);
        }

        return 0;
      },
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Status History',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 17,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        ...history.take(10).map(
          (entry) {
            final status =
                entry['status']
                        ?.toString() ??
                    '';

            final updatedBy =
                entry['updatedBy']
                        ?.toString() ??
                    'System';

            final timestamp =
                entry['timestamp'];

            return Container(
              margin:
                  const EdgeInsets.only(
                bottom: 7,
              ),
              padding:
                  const EdgeInsets.all(
                9,
              ),
              decoration:
                  BoxDecoration(
                color: statusColor(
                  status,
                ).withOpacity(
                  0.07,
                ),
                borderRadius:
                    BorderRadius.circular(
                  9,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    statusIcon(
                      status,
                    ),
                    size: 19,
                    color:
                        statusColor(
                      status,
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Text(
                      '$status • $updatedBy',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                  if (timestamp
                      is Timestamp)
                    Text(
                      formatDate(
                        timestamp,
                      ),
                      style:
                          const TextStyle(
                        fontSize: 10,
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

  // ============================================================
  // COURIER INFORMATION
  // ============================================================

  Widget courierInfoSection(
    Map<String, dynamic> data,
  ) {
    final courierName =
        data['courierName']
                ?.toString() ??
            '';

    final courierMobile =
        data['courierMobile']
                ?.toString() ??
            '';

    final courierId =
        data['courierId']
                ?.toString() ??
            '';

    if (courierName.isEmpty &&
        courierMobile.isEmpty &&
        courierId.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(12),
        decoration:
            BoxDecoration(
          color:
              Colors.orange.withOpacity(
            0.07,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          border:
              Border.all(
            color:
                Colors.orange.withOpacity(
              0.25,
            ),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              color: Colors.orange,
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'Courier not assigned yet.',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            Colors.blue.withOpacity(
          0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Courier',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          if (courierName.isNotEmpty)
            Text(
              'Name: $courierName',
            ),
          if (courierMobile.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 3,
              ),
              child: Text(
                'Mobile: $courierMobile',
              ),
            ),
          if (courierId.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 3,
              ),
              child: Text(
                'Courier ID: $courierId',
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preesho Admin Panel',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          // ======================================================
          // EXCEL BULK UPLOAD
          // ======================================================

          Container(
            padding:
                const EdgeInsets.all(20),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xff00695C),
                  Color(0xff26A69A),
                ],
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
                      Icons.table_chart,
                      color:
                          Colors.white,
                      size: 30,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'Bulk Product Upload',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 22,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Add multiple products '
                  'with photos and detailed '
                  'information using Excel.',
                  style: TextStyle(
                    color:
                        Colors.white70,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton
                          .icon(
                    onPressed:
                        downloadingTemplate
                            ? null
                            : downloadExcelTemplate,
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          Colors.white,
                      side:
                          const BorderSide(
                        color:
                            Colors.white,
                      ),
                    ),
                    icon:
                        downloadingTemplate
                            ? const SizedBox(
                                width:
                                    20,
                                height:
                                    20,
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .download,
                              ),
                    label: Text(
                      downloadingTemplate
                          ? 'Preparing Template...'
                          : 'Download Excel Template',
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton
                          .icon(
                    onPressed:
                        uploadingExcel
                            ? null
                            : uploadExcelProducts,
                    style:
                        FilledButton
                            .styleFrom(
                      backgroundColor:
                          Colors.white,
                      foregroundColor:
                          Colors
                              .teal
                              .shade800,
                    ),
                    icon:
                        uploadingExcel
                            ? const SizedBox(
                                width:
                                    20,
                                height:
                                    20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .upload_file,
                              ),
                    label: Text(
                      uploadingExcel
                          ? 'Uploading Products...'
                          : 'Upload Excel Products',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 25,
          ),

          // ======================================================
          // ADD PRODUCT HEADER
          // ======================================================

          Container(
            padding:
                const EdgeInsets.all(20),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xff5E35B1),
                  Color(0xff8E24AA),
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Add Single Product',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 6,
                ),
                Text(
                  'Add product photos '
                  'and complete details.',
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 22,
          ),

          // ======================================================
          // PRODUCT FORM
          // ======================================================

          Form(
            key: _formKey,
            child: Column(
              children: [
                inputField(
                  controller:
                      nameController,
                  label:
                      'Product Name',
                  icon: Icons
                      .shopping_bag_outlined,
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter product name';
                    }
                    return null;
                  },
                ),
                inputField(
                  controller:
                      categoryController,
                  label:
                      'Category',
                  icon: Icons
                      .category_outlined,
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter category';
                    }
                    return null;
                  },
                ),
                inputField(
                  controller:
                      priceController,
                  label:
                      'Price',
                  icon: Icons
                      .currency_rupee,
                  keyboardType:
                      TextInputType
                          .number,
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter price';
                    }

                    if (double
                            .tryParse(
                          value.trim(),
                        ) ==
                        null) {
                      return 'Enter a valid price';
                    }

                    return null;
                  },
                ),
                inputField(
                  controller:
                      stockController,
                  label:
                      'Stock',
                  icon: Icons
                      .inventory_2_outlined,
                  keyboardType:
                      TextInputType
                          .number,
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter stock';
                    }

                    final stock =
                        int.tryParse(
                      value.trim(),
                    );

                    if (stock ==
                            null ||
                        stock < 0) {
                      return 'Stock cannot be below 0';
                    }

                    return null;
                  },
                ),
                inputField(
                  controller:
                      imageUrlsController,
                  label:
                      'Product Image URLs',
                  icon: Icons
                      .collections_outlined,
                  keyboardType:
                      TextInputType.url,
                  maxLines: 5,
                  helperText:
                      'Enter multiple image URLs. '
                      'One URL per line or separate with comma.',
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter at least one image URL';
                    }

                    final urls =
                        parseImageUrls(
                      value,
                    );

                    if (urls.isEmpty) {
                      return 'Enter valid image URL';
                    }

                    for (
                      final url
                          in urls
                    ) {
                      if (!url
                          .startsWith(
                        'http',
                      )) {
                        return 'Every image URL must start with http';
                      }
                    }

                    return null;
                  },
                ),
                inputField(
                  controller:
                      descriptionController,
                  label:
                      'Product Description',
                  icon: Icons
                      .description_outlined,
                  maxLines: 5,
                ),
                inputField(
                  controller:
                      remarkController,
                  label:
                      'Remark / Offer',
                  icon: Icons
                      .campaign_outlined,
                  maxLines: 2,
                ),

                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Padding(
                    padding:
                        EdgeInsets.only(
                      top: 8,
                      bottom: 12,
                    ),
                    child: Text(
                      'Additional Product Details',
                      style:
                          TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                inputField(
                  controller:
                      brandController,
                  label:
                      'Brand',
                  icon: Icons
                      .verified_outlined,
                ),
                inputField(
                  controller:
                      materialController,
                  label:
                      'Material',
                  icon: Icons
                      .texture_outlined,
                ),
                inputField(
                  controller:
                      colorController,
                  label:
                      'Color',
                  icon: Icons
                      .palette_outlined,
                ),
                inputField(
                  controller:
                      sizeController,
                  label:
                      'Size / Capacity',
                  icon: Icons
                      .straighten_outlined,
                ),
                inputField(
                  controller:
                      weightController,
                  label:
                      'Weight',
                  icon: Icons
                      .scale_outlined,
                ),
                inputField(
                  controller:
                      warrantyController,
                  label:
                      'Warranty',
                  icon: Icons
                      .security_outlined,
                ),
                inputField(
                  controller:
                      highlightsController,
                  label:
                      'Product Highlights',
                  icon: Icons
                      .star_outline,
                  maxLines: 4,
                  helperText:
                      'Example: Premium quality, '
                      'Waterproof, Lightweight',
                ),

                Card(
                  child:
                      SwitchListTile(
                    title:
                        const Text(
                      'Product Active',
                    ),
                    subtitle:
                        const Text(
                      'Active products will appear '
                      'in customer app.',
                    ),
                    value: active,
                    onChanged:
                        (value) {
                      setState(() {
                        active =
                            value;
                      });
                    },
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 52,
                  child:
                      FilledButton
                          .icon(
                    onPressed:
                        saving
                            ? null
                            : saveProduct,
                    icon:
                        saving
                            ? const SizedBox(
                                width:
                                    20,
                                height:
                                    20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .save_outlined,
                              ),
                    label: Text(
                      saving
                          ? 'Saving...'
                          : 'Save Product',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton
                          .icon(
                    onPressed:
                        saving
                            ? null
                            : clearForm,
                    icon:
                        const Icon(
                      Icons.clear_all,
                    ),
                    label:
                        const Text(
                      'Clear Form',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          // ======================================================
          // PRODUCTS
          // ======================================================

          const Text(
            'Products in Firestore',
            style: TextStyle(
              fontSize: 21,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          StreamBuilder<
              QuerySnapshot<
                  Map<String,
                      dynamic>>>(
            stream: productsRef
                .orderBy(
                  'CreatedAt',
                  descending:
                      true,
                )
                .snapshots(),
            builder:
                (context, snapshot) {
              if (snapshot
                      .connectionState ==
                  ConnectionState
                      .waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot
                  .hasError) {
                return Card(
                  child:
                      Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      16,
                    ),
                    child: Text(
                      'Products error:\n'
                      '${snapshot.error}',
                    ),
                  ),
                );
              }

              final docs =
                  snapshot.data
                          ?.docs ??
                      [];

              if (docs.isEmpty) {
                return const Card(
                  child:
                      Padding(
                    padding:
                        EdgeInsets.all(
                      24,
                    ),
                    child:
                        Center(
                      child:
                          Text(
                        'No products found',
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children:
                    docs.map(
                  (doc) {
                    final data =
                        doc.data();

                    final name =
                        data['Name']
                                ?.toString() ??
                            '';

                    final category =
                        data['Category']
                                ?.toString() ??
                            '';

                    final price =
                        data['Price'];

                    final stock =
                        int.tryParse(
                              data['Stock']
                                      ?.toString() ??
                                  '0',
                            ) ??
                            0;

                    final isActive =
                        data['Active'] ==
                            true;

                    List<String>
                        imageUrls =
                        [];

                    if (data[
                            'ImageUrls']
                        is List) {
                      imageUrls =
                          List<String>.from(
                        (data[
                                    'ImageUrls']
                                as List)
                            .map(
                          (e) =>
                              e.toString(),
                        ),
                      );
                    } else {
                      final oldImage =
                          data['Imageurl']
                                  ?.toString() ??
                              '';

                      if (oldImage
                          .isNotEmpty) {
                        imageUrls =
                            [oldImage];
                      }
                    }

                    final remark =
                        data['Remark']
                                ?.toString() ??
                            '';

                    return Card(
                      margin:
                          const EdgeInsets
                              .only(
                        bottom: 12,
                      ),
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          10,
                        ),
                        child: Row(
                          children: [
                            productImagePreview(
                              imageUrls,
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
                                    name.isEmpty
                                        ? 'Unnamed Product'
                                        : name,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize:
                                          16,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        4,
                                  ),
                                  Text(
                                    category,
                                  ),
                                  const SizedBox(
                                    height:
                                        4,
                                  ),
                                  Text(
                                    money(
                                      price,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        5,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        stock <=
                                                0
                                            ? 'OUT OF STOCK'
                                            : 'Stock: $stock',
                                        style:
                                            TextStyle(
                                          color: stock <=
                                                  0
                                              ? Colors.red
                                              : Colors.green,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        width:
                                            10,
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal:
                                              8,
                                          vertical:
                                              3,
                                        ),
                                        decoration:
                                            BoxDecoration(
                                          color: isActive
                                              ? Colors.green
                                                  .withOpacity(
                                                  0.1,
                                                )
                                              : Colors.grey
                                                  .withOpacity(
                                                  0.1,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child:
                                            Text(
                                          isActive
                                              ? 'Active'
                                              : 'Inactive',
                                          style:
                                              TextStyle(
                                            color: isActive
                                                ? Colors.green
                                                : Colors.grey,
                                            fontSize:
                                                11,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (imageUrls
                                          .length >
                                      1)
                                    Padding(
                                      padding:
                                          const EdgeInsets
                                              .only(
                                        top:
                                            4,
                                      ),
                                      child:
                                          Text(
                                        '${imageUrls.length} product photos',
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              11,
                                          color:
                                              Colors.blue,
                                        ),
                                      ),
                                    ),
                                  if (remark
                                      .trim()
                                      .isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets
                                              .only(
                                        top:
                                            4,
                                      ),
                                      child:
                                          Text(
                                        'Remark: $remark',
                                        maxLines:
                                            1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.orange,
                                          fontSize:
                                              12,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Delete Product',
                              icon:
                                  const Icon(
                                Icons
                                    .delete_outline,
                                color:
                                    Colors.red,
                              ),
                              onPressed:
                                  () {
                                confirmDelete(
                                  doc.id,
                                  name,
                                );
                              },
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
            height: 35,
          ),

          // ======================================================
          // ORDERS HEADER
          // ======================================================

          Container(
            padding:
                const EdgeInsets.all(20),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xff1565C0),
                  Color(0xff42A5F5),
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Customer Orders',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 6,
                ),
                Text(
                  'View and manage customer orders',
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          // ======================================================
          // ORDERS
          // ======================================================

          StreamBuilder<
              QuerySnapshot<
                  Map<String,
                      dynamic>>>(
            stream: ordersRef
                .orderBy(
                  'createdAt',
                  descending:
                      true,
                )
                .snapshots(),
            builder:
                (context, snapshot) {
              if (snapshot
                      .connectionState ==
                  ConnectionState
                      .waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot
                  .hasError) {
                return Card(
                  child:
                      Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      16,
                    ),
                    child: Text(
                      'Orders error:\n'
                      '${snapshot.error}',
                    ),
                  ),
                );
              }

              final orders =
                  snapshot.data
                          ?.docs ??
                      [];

              if (orders.isEmpty) {
                return const Card(
                  child:
                      Padding(
                    padding:
                        EdgeInsets.all(
                      24,
                    ),
                    child:
                        Center(
                      child:
                          Text(
                        'No customer orders yet.',
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children:
                    orders.map(
                  (doc) {
                    final data =
                        doc.data();

                    final status =
                        normalizedOrderStatus(
                      data,
                    );

                    final name =
                        data['customerName']
                                ?.toString() ??
                            data['name']
                                ?.toString() ??
                            'Customer';

                    final mobile =
                        data['customerMobile']
                                ?.toString() ??
                            data['mobile']
                                ?.toString() ??
                            data['phone']
                                ?.toString() ??
                            '';

                    final email =
                        data['customerEmail']
                                ?.toString() ??
                            data['email']
                                ?.toString() ??
                            '';

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

                    final total =
                        data['totalAmount'];

                    final createdAt =
                        data['createdAt'];

                    final paymentMethod =
                        data['paymentMethod']
                                ?.toString() ??
                            data['payment']
                                ?.toString() ??
                            data['paymentMode']
                                ?.toString() ??
                            'COD';

                    final items =
                        data['items'] is List
                            ? List<dynamic>.from(
                                data[
                                    'items'],
                              )
                            : <dynamic>[];

                    final nextStatus =
                        getNextAdminStatus(
                      status,
                    );

                    final canChange =
                        nextStatus !=
                                null &&
                            status !=
                                'Cancelled';

                    return Card(
                      margin:
                          const EdgeInsets
                              .only(
                        bottom: 16,
                      ),
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          16,
                        ),
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            // ----------------------------------
                            // ORDER HEADER
                            // ----------------------------------

                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        'Order #${doc.id}',
                                        maxLines:
                                            1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize:
                                              17,
                                        ),
                                      ),
                                      const SizedBox(
                                        height:
                                            5,
                                      ),
                                      Text(
                                        formatDate(
                                          createdAt,
                                        ),
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        10,
                                    vertical:
                                        7,
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
                                        BorderRadius.circular(
                                      20,
                                    ),
                                  ),
                                  child:
                                      Row(
                                    mainAxisSize:
                                        MainAxisSize
                                            .min,
                                    children: [
                                      Icon(
                                        statusIcon(
                                          status,
                                        ),
                                        size:
                                            16,
                                        color:
                                            statusColor(
                                          status,
                                        ),
                                      ),
                                      const SizedBox(
                                        width:
                                            5,
                                      ),
                                      Text(
                                        status,
                                        style:
                                            TextStyle(
                                          color:
                                              statusColor(
                                            status,
                                          ),
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(
                              height: 25,
                            ),

                            // ----------------------------------
                            // CUSTOMER
                            // ----------------------------------

                            customerDetailsSection(
                              name,
                              mobile,
                              email,
                              address,
                              city,
                              pincode,
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            const Divider(),

                            const SizedBox(
                              height: 12,
                            ),

                            // ----------------------------------
                            // ITEMS
                            // ----------------------------------

                            orderItemsSection(
                              items,
                            ),

                            if (items
                                .isNotEmpty)
                              const SizedBox(
                                height:
                                    12,
                              ),

                            // ----------------------------------
                            // PAYMENT + TOTAL
                            // ----------------------------------

                            Container(
                              padding:
                                  const EdgeInsets
                                      .all(
                                12,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.grey
                                        .withOpacity(
                                  0.07,
                                ),
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child:
                                  Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      const Text(
                                        'Payment',
                                        style:
                                            TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        paymentMethod,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height:
                                        8,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      const Text(
                                        'Order Total',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              18,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        money(
                                          total,
                                        ),
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              21,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

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

                            if (status !=
                                    'Cancelled' &&
                                status !=
                                    'Shipped' &&
                                status !=
                                    'Picked by Courier' &&
                                status !=
                                    'Out for Delivery' &&
                                status !=
                                    'Delivered')
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
