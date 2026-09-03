import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
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

  final productsRef = FirebaseFirestore.instance.collection('products');

  final ordersRef = FirebaseFirestore.instance.collection('orders');

  // ================= PRODUCT CONTROLLERS =================

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

  // ================= SHIPMENT CONTROLLERS =================

  final courierPartnerController = TextEditingController();
  final trackingNumberController = TextEditingController();
  final trackingUrlController = TextEditingController();
  final courierPersonController = TextEditingController();
  final courierPhoneController = TextEditingController();

  bool active = true;
  bool saving = false;
  bool uploadingExcel = false;
  bool downloadingTemplate = false;

  late final TabController tabController;

  // ================= STATUS FLOW =================

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

  static const Map<String, String> nextAdminStatus = {
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

    courierPartnerController.dispose();
    trackingNumberController.dispose();
    trackingUrlController.dispose();
    courierPersonController.dispose();
    courierPhoneController.dispose();

    super.dispose();
  }

  // ================= HELPERS =================

  List<String> parseImageUrls(String text) {
    return text
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String normalizedOrderStatus(
    Map<String, dynamic> data,
  ) {
    final value = data['orderStatus'] ?? data['status'];

    if (value is String && lifecycleStatuses.contains(value)) {
      return value;
    }

    if (value == 'Cancelled') {
      return 'Cancelled';
    }

    return 'Placed';
  }

  bool canAdminUpdateStatus(
    String current,
    String next,
  ) {
    return nextAdminStatus[current] == next;
  }

  bool canCourierUpdateStatus(
    String current,
    String next,
  ) {
    return nextLifecycleStatus[current] == next &&
        current != 'Placed' &&
        current != 'Confirmed' &&
        current != 'Processing' &&
        current != 'Packed';
  }

  bool canCancelOrder(String status) {
    return status == 'Placed' ||
        status == 'Confirmed' ||
        status == 'Processing';
  }

  String money(dynamic value) {
    if (value == null) return '₹0';

    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;

    return '₹${number.toStringAsFixed(0)}';
  }

  String formatDate(dynamic value) {
    if (value == null) return '-';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Color statusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Confirmed':
        return Colors.indigo;
      case 'Processing':
        return Colors.orange;
      case 'Packed':
        return Colors.deepOrange;
      case 'Shipped':
        return Colors.purple;
      case 'Picked by Courier':
        return Colors.teal;
      case 'Out for Delivery':
        return Colors.cyan;
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
        return Icons.shopping_cart;
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Processing':
        return Icons.settings;
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
        return Icons.circle;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================================================
  // PRODUCT MANAGEMENT - ADD
  // =========================================================

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final imageUrls = parseImageUrls(
        imageUrlsController.text,
      );

      await productsRef.add({
        'Name': nameController.text.trim(),
        'Category': categoryController.text.trim(),
        'Price':
            double.tryParse(priceController.text.trim()) ?? 0,
        'MRP':
            double.tryParse(mrpController.text.trim()) ?? 0,
        'DiscountPercent':
            double.tryParse(discountController.text.trim()) ?? 0,
        'Stock':
            int.tryParse(stockController.text.trim()) ?? 0,
        'ImageUrls': imageUrls,
        'Imageurl':
            imageUrls.isNotEmpty ? imageUrls.first : '',
        'Description':
            descriptionController.text.trim(),
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

      showMessage(
        'Product successfully save ho gaya.',
      );
    } catch (e) {
      showMessage(
        'Product save nahi hua: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // =========================================================
  // EDIT PRODUCT
  // =========================================================

  Future<void> editProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final editFormKey = GlobalKey<FormState>();

    final editNameController = TextEditingController(
      text: data['Name']?.toString() ?? '',
    );

    final editCategoryController = TextEditingController(
      text: data['Category']?.toString() ?? '',
    );

    final editPriceController = TextEditingController(
      text: data['Price']?.toString() ?? '',
    );

    final editMrpController = TextEditingController(
      text: data['MRP']?.toString() ??
          data['Mrp']?.toString() ??
          '',
    );

    final editDiscountController = TextEditingController(
      text: data['DiscountPercent']?.toString() ??
          data['Discount']?.toString() ??
          '',
    );

    final editStockController = TextEditingController(
      text: data['Stock']?.toString() ?? '',
    );

    final existingImageUrls = <String>[];

    final rawImageUrls = data['ImageUrls'];

    if (rawImageUrls is List) {
      for (final item in rawImageUrls) {
        final url = item.toString().trim();

        if (url.isNotEmpty) {
          existingImageUrls.add(url);
        }
      }
    }

    final legacyImage =
        data['Imageurl']?.toString() ??
            data['ImageUrl']?.toString() ??
            '';

    if (existingImageUrls.isEmpty &&
        legacyImage.trim().isNotEmpty) {
      existingImageUrls.add(
        legacyImage.trim(),
      );
    }

    final editImageController = TextEditingController(
      text: existingImageUrls.join('\n'),
    );

    final editDescriptionController = TextEditingController(
      text: data['Description']?.toString() ?? '',
    );

    final editRemarkController = TextEditingController(
      text: data['Remark']?.toString() ?? '',
    );

    final editBrandController = TextEditingController(
      text: data['Brand']?.toString() ?? '',
    );

    final editMaterialController = TextEditingController(
      text: data['Material']?.toString() ?? '',
    );

    final editColorController = TextEditingController(
      text: data['Color']?.toString() ?? '',
    );

    final editSizeController = TextEditingController(
      text: data['Size']?.toString() ?? '',
    );

    final editWeightController = TextEditingController(
      text: data['Weight']?.toString() ?? '',
    );

    final editWarrantyController = TextEditingController(
      text: data['Warranty']?.toString() ?? '',
    );

    final editHighlightsController = TextEditingController(
      text: data['Highlights']?.toString() ?? '',
    );

    bool editActive = data['Active'] != false;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit Product'),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Form(
                      key: editFormKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: editNameController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Product Name',
                              prefixIcon:
                                  Icon(Icons.shopping_bag),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Product name required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editCategoryController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Category',
                              prefixIcon:
                                  Icon(Icons.category),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: editPriceController,
                            keyboardType:
                                TextInputType.number,
                            decoration:
                                const InputDecoration(
                              labelText: 'Selling Price',
                              prefixIcon:
                                  Icon(Icons.currency_rupee),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: editMrpController,
                            keyboardType:
                                TextInputType.number,
                            decoration:
                                const InputDecoration(
                              labelText: 'MRP',
                              prefixIcon:
                                  Icon(Icons.sell_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editDiscountController,
                            keyboardType:
                                TextInputType.number,
                            decoration:
                                const InputDecoration(
                              labelText: 'Discount %',
                              prefixIcon:
                                  Icon(Icons.percent),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: editStockController,
                            keyboardType:
                                TextInputType.number,
                            decoration:
                                const InputDecoration(
                              labelText: 'Stock',
                              prefixIcon:
                                  Icon(Icons.inventory_2),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: editImageController,
                            maxLines: 4,
                            decoration:
                                const InputDecoration(
                              labelText: 'Image URLs',
                              hintText:
                                  'One URL per line',
                              prefixIcon:
                                  Icon(Icons.image),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editDescriptionController,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(
                              labelText: 'Description',
                              prefixIcon:
                                  Icon(Icons.description),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editRemarkController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Remark',
                              prefixIcon:
                                  Icon(Icons.note),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editBrandController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Brand',
                              prefixIcon:
                                  Icon(Icons.branding_watermark),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editMaterialController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Material',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editColorController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Color',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editSizeController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Size',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editWeightController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Weight',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editWarrantyController,
                            decoration:
                                const InputDecoration(
                              labelText: 'Warranty',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                editHighlightsController,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(
                              labelText: 'Highlights',
                            ),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            title: const Text(
                              'Product Active',
                            ),
                            subtitle: Text(
                              editActive
                                  ? 'Customer ko product dikhega'
                                  : 'Customer ko product nahi dikhega',
                            ),
                            value: editActive,
                            onChanged: (value) {
                              setDialogState(() {
                                editActive = value;
                              });
                            },
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
                    onPressed: () async {
                      if (!editFormKey.currentState!
                          .validate()) {
                        return;
                      }

                      try {
                        final imageUrls =
                            parseImageUrls(
                          editImageController.text,
                        );

                        final price =
                            double.tryParse(
                                  editPriceController
                                      .text
                                      .trim(),
                                ) ??
                                0;

                        final mrp =
                            double.tryParse(
                                  editMrpController
                                      .text
                                      .trim(),
                                ) ??
                                0;

                        final discount =
                            double.tryParse(
                                  editDiscountController
                                      .text
                                      .trim(),
                                ) ??
                                0;

                        final stock =
                            int.tryParse(
                                  editStockController
                                      .text
                                      .trim(),
                                ) ??
                                0;

                        await productsRef
                            .doc(productId)
                            .update({
                          'Name':
                              editNameController.text.trim(),
                          'Category':
                              editCategoryController
                                  .text
                                  .trim(),
                          'Price': price,
                          'MRP': mrp,
                          'DiscountPercent': discount,
                          'Stock': stock,
                          'ImageUrls': imageUrls,
                          'Imageurl':
                              imageUrls.isNotEmpty
                                  ? imageUrls.first
                                  : '',
                          'Description':
                              editDescriptionController
                                  .text
                                  .trim(),
                          'Remark':
                              editRemarkController
                                  .text
                                  .trim(),
                          'Brand':
                              editBrandController
                                  .text
                                  .trim(),
                          'Material':
                              editMaterialController
                                  .text
                                  .trim(),
                          'Color':
                              editColorController
                                  .text
                                  .trim(),
                          'Size':
                              editSizeController
                                  .text
                                  .trim(),
                          'Weight':
                              editWeightController
                                  .text
                                  .trim(),
                          'Warranty':
                              editWarrantyController
                                  .text
                                  .trim(),
                          'Highlights':
                              editHighlightsController
                                  .text
                                  .trim(),
                          'Active': editActive,
                          'UpdatedAt':
                              FieldValue.serverTimestamp(),
                        });

                        if (dialogContext.mounted) {
                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        }
                      } catch (e) {
                        showMessage(
                          'Product update nahi hua: $e',
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label:
                        const Text('Update Product'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true) {
        showMessage(
          'Product successfully update ho gaya.',
        );
      }
    } finally {
      editNameController.dispose();
      editCategoryController.dispose();
      editPriceController.dispose();
      editMrpController.dispose();
      editDiscountController.dispose();
      editStockController.dispose();
      editImageController.dispose();
      editDescriptionController.dispose();
      editRemarkController.dispose();
      editBrandController.dispose();
      editMaterialController.dispose();
      editColorController.dispose();
      editSizeController.dispose();
      editWeightController.dispose();
      editWarrantyController.dispose();
      editHighlightsController.dispose();
    }
  }

  // =========================================================
  // DELETE PRODUCT
  // =========================================================

  Future<void> deleteProduct(
    String productId,
    String productName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: Text(
            'Kya aap "$productName" ko permanently delete karna chahte hain?',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await productsRef.doc(productId).delete();

      showMessage(
        'Product successfully delete ho gaya.',
      );
    } catch (e) {
      showMessage(
        'Product delete nahi hua: $e',
      );
    }
  }

  // =========================================================
  // EXCEL UPLOAD
  // =========================================================

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

      final bytes = result.files.single.bytes;

      if (bytes == null) {
        showMessage(
          'Excel file read nahi ho paayi.',
        );
        return;
      }

      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        showMessage(
          'Excel sheet nahi mili.',
        );
        return;
      }

      final sheet = excel.tables.values.first;

      if (sheet.rows.isEmpty) {
        showMessage(
          'Excel empty hai.',
        );
        return;
      }

      final headers = sheet.rows.first
          .map(
            (cell) =>
                cell?.value.toString().trim() ?? '',
          )
          .toList();

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        dynamic getValue(String header) {
          final index = headers.indexOf(header);

          if (index == -1 ||
              index >= row.length) {
            return null;
          }

          return row[index]?.value;
        }

        final name =
            getValue('Name')?.toString().trim() ?? '';

        if (name.isEmpty) {
          continue;
        }

        final imageUrlsText =
            getValue('ImageUrls')?.toString() ??
                getValue('Imageurl')?.toString() ??
                '';

        final imageUrls =
            parseImageUrls(imageUrlsText);

        await productsRef.add({
          'Name': name,
          'Category':
              getValue('Category')?.toString() ?? '',
          'Price':
              double.tryParse(
                    getValue('Price')?.toString() ?? '',
                  ) ??
                  0,
          'MRP':
              double.tryParse(
                    getValue('MRP')?.toString() ?? '',
                  ) ??
                  0,
          'DiscountPercent':
              double.tryParse(
                    getValue('DiscountPercent')
                            ?.toString() ??
                        getValue('Discount')?.toString() ??
                        '',
                  ) ??
                  0,
          'Stock':
              int.tryParse(
                    getValue('Stock')?.toString() ?? '',
                  ) ??
                  0,
          'ImageUrls': imageUrls,
          'Imageurl':
              imageUrls.isNotEmpty
                  ? imageUrls.first
                  : '',
          'Description':
              getValue('Description')?.toString() ?? '',
          'Remark':
              getValue('Remark')?.toString() ?? '',
          'Brand':
              getValue('Brand')?.toString() ?? '',
          'Material':
              getValue('Material')?.toString() ?? '',
          'Color':
              getValue('Color')?.toString() ?? '',
          'Size':
              getValue('Size')?.toString() ?? '',
          'Weight':
              getValue('Weight')?.toString() ?? '',
          'Warranty':
              getValue('Warranty')?.toString() ?? '',
          'Highlights':
              getValue('Highlights')?.toString() ?? '',
          'Active': true,
          'CreatedAt': FieldValue.serverTimestamp(),
        });
      }

      showMessage(
        'Excel products successfully upload ho gaye.',
      );
    } catch (e) {
      showMessage(
        'Excel upload error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingExcel = false;
        });
      }
    }
  }

  // =========================================================
  // EXCEL TEMPLATE
  // =========================================================

  Future<void> downloadTemplate() async {
    try {
      setState(() {
        downloadingTemplate = true;
      });

      final excel = Excel.createExcel();

      final sheet = excel[
          excel.getDefaultSheet() ?? 'Sheet1'];

      final headers = [
        'Name',
        'Category',
        'Price',
        'MRP',
        'DiscountPercent',
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
        TextCellValue('Electronics'),
        TextCellValue('799'),
        TextCellValue('999'),
        TextCellValue('20'),
        TextCellValue('10'),
        TextCellValue(
          'https://picsum.photos/seed/preesho1/600/600',
        ),
        TextCellValue(
          'https://picsum.photos/seed/preesho1/600/600',
        ),
        TextCellValue(
          'Sample product description',
        ),
        TextCellValue('New'),
        TextCellValue('Preesho'),
        TextCellValue('Plastic'),
        TextCellValue('Black'),
        TextCellValue('M'),
        TextCellValue('500g'),
        TextCellValue('1 Year'),
        TextCellValue(
          'Good quality product',
        ),
      ]);

      final data = excel.encode();

      if (data == null) {
        showMessage(
          'Excel generate nahi hui.',
        );
        return;
      }

      await FileSaver.instance.saveFile(
        name: 'preesho_product_template',
        bytes: Uint8List.fromList(data),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      showMessage(
        'Excel template download ho gayi.',
      );
    } catch (e) {
      showMessage(
        'Template error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          downloadingTemplate = false;
        });
      }
    }
  }

  // =========================================================
  // ADMIN ORDER STATUS
  // =========================================================

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final ref = ordersRef.doc(orderId);

          final snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw Exception(
              'Order nahi mila.',
            );
          }

          final data =
              snapshot.data()
                  as Map<String, dynamic>;

          final currentStatus =
              normalizedOrderStatus(data);

          if (newStatus == 'Shipped') {
            throw Exception(
              'Shipped ke liye shipment details required hain.',
            );
          }

          if (newStatus == 'Cancelled') {
            if (!canCancelOrder(currentStatus)) {
              throw Exception(
                'Is stage par order cancel nahi kiya ja sakta.',
              );
            }
          } else {
            if (!canAdminUpdateStatus(
              currentStatus,
              newStatus,
            )) {
              throw Exception(
                'Invalid status transition.',
              );
            }
          }

          final history =
              List<Map<String, dynamic>>.from(
            (data['statusHistory'] as List?)
                    ?.map(
                      (e) =>
                          Map<String, dynamic>.from(e),
                    ) ??
                [],
          );

          final now = Timestamp.now();

          history.add({
            'status': newStatus,
            'timestamp': now,
            'updatedBy': 'Admin',
          });

          final updates = <String, dynamic>{
            'orderStatus': newStatus,
            'status': newStatus,
            'statusHistory': history,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

          if (newStatus == 'Confirmed') {
            updates['confirmedAt'] =
                FieldValue.serverTimestamp();
          }

          if (newStatus == 'Processing') {
            updates['processingAt'] =
                FieldValue.serverTimestamp();
          }

          if (newStatus == 'Packed') {
            updates['packedAt'] =
                FieldValue.serverTimestamp();
          }

          if (newStatus == 'Cancelled') {
            updates['cancelled'] = true;

            updates['cancelledAt'] =
                FieldValue.serverTimestamp();

            updates['cancelledBy'] = 'Admin';

            updates['cancellationReason'] =
                'Cancelled by Admin';

            updates['trackingEnabled'] = false;
          }

          transaction.update(
            ref,
            updates,
          );
        },
      );

      showMessage(
        'Order status successfully update ho gaya.',
      );
    } catch (e) {
      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // =========================================================
  // SHIPMENT DIALOG
  // =========================================================

  Future<void> showShipmentDialog(
    String orderId,
  ) async {
    courierPartnerController.clear();
    trackingNumberController.clear();
    trackingUrlController.clear();
    courierPersonController.clear();
    courierPhoneController.clear();

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Order Shipped Karein',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller:
                        courierPartnerController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Courier Partner *',
                      hintText:
                          'Delhivery / BlueDart etc.',
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Courier Partner required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller:
                        trackingNumberController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'AWB / Tracking Number *',
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Tracking number required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller:
                        trackingUrlController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Tracking URL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller:
                        courierPersonController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Courier Person Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller:
                        courierPhoneController,
                    keyboardType:
                        TextInputType.phone,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Courier Phone',
                    ),
                  ),
                ],
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
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!
                    .validate()) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Ship Order',
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    await shipOrderWithDetails(orderId);
  }

  // =========================================================
  // SHIP ORDER WITH COURIER DETAILS
  // =========================================================

  Future<void> shipOrderWithDetails(
    String orderId,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final ref = ordersRef.doc(orderId);

          final snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw Exception(
              'Order nahi mila.',
            );
          }

          final data =
              snapshot.data()
                  as Map<String, dynamic>;

          final currentStatus =
              normalizedOrderStatus(data);

          if (!canAdminUpdateStatus(
            currentStatus,
            'Shipped',
          )) {
            throw Exception(
              'Order ko abhi Shipped nahi kiya ja sakta.',
            );
          }

          final history =
              List<Map<String, dynamic>>.from(
            (data['statusHistory'] as List?)
                    ?.map(
                      (e) =>
                          Map<String, dynamic>.from(e),
                    ) ??
                [],
          );

          final now = Timestamp.now();

          history.add({
            'status': 'Shipped',
            'timestamp': now,
            'updatedBy': 'Admin',
          });

          transaction.update(
            ref,
            {
              'orderStatus': 'Shipped',
              'status': 'Shipped',
              'statusHistory': history,
              'trackingEnabled': true,
              'trackingStatus': 'Shipped',
              'trackingNumber':
                  trackingNumberController.text.trim(),
              'trackingUrl':
                  trackingUrlController.text.trim(),
              'courierPartner':
                  courierPartnerController.text.trim(),
              'courierPersonName':
                  courierPersonController.text.trim(),
              'courierPhone':
                  courierPhoneController.text.trim(),
              'shippedAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      showMessage(
        'Order Shipped successfully. Courier details save ho gayi.',
      );
    } catch (e) {
      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // =========================================================
  // COURIER STATUS
  // =========================================================

  Future<void> updateCourierStatus(
    String orderId,
    String newStatus,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final ref = ordersRef.doc(orderId);

          final snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw Exception(
              'Order nahi mila.',
            );
          }

          final data =
              snapshot.data()
                  as Map<String, dynamic>;

          final currentStatus =
              normalizedOrderStatus(data);

          if (!canCourierUpdateStatus(
            currentStatus,
            newStatus,
          )) {
            throw Exception(
              'Invalid courier status transition.',
            );
          }

          final history =
              List<Map<String, dynamic>>.from(
            (data['statusHistory'] as List?)
                    ?.map(
                      (e) =>
                          Map<String, dynamic>.from(e),
                    ) ??
                [],
          );

          final now = Timestamp.now();

          history.add({
            'status': newStatus,
            'timestamp': now,
            'updatedBy': 'Courier',
          });

          final updates = <String, dynamic>{
            'orderStatus': newStatus,
            'status': newStatus,
            'trackingStatus': newStatus,
            'trackingEnabled': true,
            'statusHistory': history,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

          if (newStatus ==
              'Picked by Courier') {
            updates['courierPickedAt'] =
                FieldValue.serverTimestamp();
          }

          if (newStatus ==
              'Out for Delivery') {
            updates['outForDeliveryAt'] =
                FieldValue.serverTimestamp();
          }

          if (newStatus == 'Delivered') {
            updates['deliveredAt'] =
                FieldValue.serverTimestamp();

            updates['trackingEnabled'] = false;
          }

          transaction.update(
            ref,
            updates,
          );
        },
      );

      showMessage(
        'Courier status successfully update ho gaya.',
      );
    } catch (e) {
      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // =========================================================
  // PRODUCT FORM
  // =========================================================

  Widget productForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              decoration:
                  const InputDecoration(
                labelText: 'Product Name',
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Product name required';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: categoryController,
              decoration:
                  const InputDecoration(
                labelText: 'Category',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: priceController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText: 'Price',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: mrpController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText: 'MRP',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: discountController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText: 'Discount %',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: stockController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText: 'Stock',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: imageUrlsController,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                labelText: 'Image URLs',
                hintText:
                    'One URL per line ya comma separated',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: descriptionController,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                labelText: 'Description',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: remarkController,
              decoration:
                  const InputDecoration(
                labelText: 'Remark',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: brandController,
              decoration:
                  const InputDecoration(
                labelText: 'Brand',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: materialController,
              decoration:
                  const InputDecoration(
                labelText: 'Material',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: colorController,
              decoration:
                  const InputDecoration(
                labelText: 'Color',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: sizeController,
              decoration:
                  const InputDecoration(
                labelText: 'Size',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: weightController,
              decoration:
                  const InputDecoration(
                labelText: 'Weight',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: warrantyController,
              decoration:
                  const InputDecoration(
                labelText: 'Warranty',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: highlightsController,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                labelText: 'Highlights',
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Active'),
              value: active,
              onChanged: (value) {
                setState(() {
                  active = value;
                });
              },
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    saving ? null : saveProduct,
                icon: const Icon(Icons.save),
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
                onPressed:
                    uploadingExcel
                        ? null
                        : uploadExcel,
                icon:
                    const Icon(Icons.upload_file),
                label: Text(
                  uploadingExcel
                      ? 'Uploading...'
                      : 'Upload Excel',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    downloadingTemplate
                        ? null
                        : downloadTemplate,
                icon:
                    const Icon(Icons.download),
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

  // =========================================================
  // PRODUCT LIST
  // =========================================================

  Widget productList() {
    return StreamBuilder<QuerySnapshot>(
      stream: productsRef
          .orderBy(
            'CreatedAt',
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
                  const EdgeInsets.all(20),
              child: Text(
                'Product list error:\n'
                '${snapshot.error}',
              ),
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

            final data =
                doc.data()
                    as Map<String, dynamic>;

            final imageUrls = <String>[];

            final rawImageUrls =
                data['ImageUrls'];

            if (rawImageUrls is List) {
              for (final item
                  in rawImageUrls) {
                final url =
                    item.toString().trim();

                if (url.isNotEmpty) {
                  imageUrls.add(url);
                }
              }
            }

            if (imageUrls.isEmpty) {
              final legacy =
                  data['Imageurl']
                          ?.toString()
                          .trim() ??
                      data['ImageUrl']
                          ?.toString()
                          .trim() ??
                      '';

              if (legacy.isNotEmpty) {
                imageUrls.add(legacy);
              }
            }

            final isActive =
                data['Active'] != false;

            final productName =
                data['Name']
                        ?.toString() ??
                    'Unnamed';

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                leading:
                    imageUrls.isNotEmpty
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                            child:
                                Image.network(
                              imageUrls.first,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                _,
                                __,
                                ___,
                              ) =>
                                      const Icon(
                                Icons
                                    .image_not_supported,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.image,
                            size: 40,
                          ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration:
                          BoxDecoration(
                        color: isActive
                            ? Colors.green
                                .withOpacity(0.1)
                            : Colors.red
                                .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                      child: Text(
                        isActive
                            ? 'Active'
                            : 'Inactive',
                        style:
                            TextStyle(
                          color: isActive
                              ? Colors.green
                              : Colors.red,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${data['Category'] ?? ''}\n'
                  '${money(data['Price'])} | '
                  'MRP: ${money(data['MRP'])} | '
                  'Stock: ${data['Stock'] ?? 0}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          const Icon(
                        Icons.edit,
                        color: Colors.blue,
                      ),
                      tooltip:
                          'Edit Product',
                      onPressed: () {
                        editProduct(
                          doc.id,
                          data,
                        );
                      },
                    ),
                    IconButton(
                      icon:
                          const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      tooltip:
                          'Delete Product',
                      onPressed: () {
                        deleteProduct(
                          doc.id,
                          productName,
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

  // =========================================================
  // ORDER LIST
  // =========================================================

  Widget orderList() {
    return StreamBuilder<QuerySnapshot>(
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
                  const EdgeInsets.all(20),
              child: Text(
                'Orders load error:\n'
                '${snapshot.error}',
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
              doc.data()
                  as Map<String, dynamic>,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // ORDER CARD
  // =========================================================

  Widget orderCard(
    String orderId,
    Map<String, dynamic> data,
  ) {
    final status =
        normalizedOrderStatus(data);

    final nextStatus =
        nextAdminStatus[status];

    final canChange =
        nextStatus != null &&
            canAdminUpdateStatus(
              status,
              nextStatus,
            );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
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
                    'Order: $orderId',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                statusChip(status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Customer: '
              '${data['customerName'] ?? data['name'] ?? '-'}',
            ),
            const SizedBox(height: 4),
            Text(
              'Total: '
              '${money(data['totalAmount'] ?? data['total'])}',
            ),
            const SizedBox(height: 15),
            orderTimeline(status),
            const SizedBox(height: 15),
            statusHistorySection(data),
            const SizedBox(height: 10),
            courierInfoSection(data),
            const SizedBox(height: 12),
            if (status == 'Shipped')
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(
                  color: Colors.purple
                      .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child:
                    const Text(
                  'Shipped complete.\n'
                  'Ab next stages Courier handle karega.',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              )
            else if (status == 'Delivered')
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(
                  color: Colors.green
                      .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child:
                    const Text(
                  'Order Delivered successfully.',
                ),
              )
            else if (status == 'Cancelled')
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(
                  color: Colors.red
                      .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child:
                    const Text(
                  'Order Cancelled.',
                ),
              )
            else if (canChange)
              SizedBox(
                width: double.infinity,
                child:
                    ElevatedButton.icon(
                  onPressed: () {
                    if (nextStatus ==
                        'Shipped') {
                      showShipmentDialog(
                        orderId,
                      );
                    } else {
                      updateOrderStatus(
                        orderId,
                        nextStatus,
                      );
                    }
                  },
                  icon:
                      Icon(
                    nextStatus ==
                            'Shipped'
                        ? Icons
                            .local_shipping
                        : Icons
                            .arrow_forward,
                  ),
                  label:
                      Text(
                    nextStatus ==
                            'Shipped'
                        ? 'Ship Order'
                        : 'Move to $nextStatus',
                  ),
                ),
              ),
            if (canCancelOrder(status)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    confirmCancellation(
                      orderId,
                    );
                  },
                  icon:
                      const Icon(
                    Icons.cancel_outlined,
                  ),
                  label:
                      const Text(
                    'Cancel Order',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CANCEL DIALOG
  // =========================================================

  Future<void> confirmCancellation(
    String orderId,
  ) async {
    final controller =
        TextEditingController();

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel Order?',
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration:
                const InputDecoration(
              labelText:
                  'Cancellation Reason',
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
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
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

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    try {
      await FirebaseFirestore.instance
          .runTransaction(
        (transaction) async {
          final ref =
              ordersRef.doc(orderId);

          final snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw Exception(
              'Order nahi mila.',
            );
          }

          final data =
              snapshot.data()
                  as Map<String, dynamic>;

          final currentStatus =
              normalizedOrderStatus(data);

          if (!canCancelOrder(
            currentStatus,
          )) {
            throw Exception(
              'Is stage par cancellation allowed nahi hai.',
            );
          }

          final history =
              List<Map<String, dynamic>>.from(
            (data['statusHistory']
                        as List?)
                    ?.map(
                      (e) =>
                          Map<String, dynamic>.from(
                        e,
                      ),
                    ) ??
                [],
          );

          history.add({
            'status': 'Cancelled',
            'timestamp': Timestamp.now(),
            'updatedBy': 'Admin',
          });

          transaction.update(
            ref,
            {
              'orderStatus': 'Cancelled',
              'status': 'Cancelled',
              'cancelled': true,
              'cancelledAt':
                  FieldValue.serverTimestamp(),
              'cancelledBy': 'Admin',
              'cancellationReason':
                  controller.text.trim().isEmpty
                      ? 'Cancelled by Admin'
                      : controller.text.trim(),
              'trackingEnabled': false,
              'statusHistory': history,
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      showMessage(
        'Order cancel ho gaya.',
      );
    } catch (e) {
      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // =========================================================
  // STATUS CHIP
  // =========================================================

  Widget statusChip(
    String status,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: statusColor(status)
            .withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            statusIcon(status),
            size: 16,
            color:
                statusColor(status),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style:
                TextStyle(
              color:
                  statusColor(status),
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER TIMELINE
  // =========================================================

  Widget orderTimeline(
    String currentStatus,
  ) {
    if (currentStatus == 'Cancelled') {
      return _timelineItem(
        'Cancelled',
        true,
        statusColor('Cancelled'),
      );
    }

    final currentIndex =
        lifecycleStatuses.indexOf(
      currentStatus,
    );

    return Column(
      children:
          List.generate(
        lifecycleStatuses.length,
        (index) {
          final status =
              lifecycleStatuses[index];

          return _timelineItem(
            status,
            index <= currentIndex,
            statusColor(status),
          );
        },
      ),
    );
  }

  Widget _timelineItem(
    String status,
    bool completed,
    Color color,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color:
                  completed
                      ? color
                      : Colors.grey,
              size: 22,
            ),
            if (status != 'Delivered')
              Container(
                width: 2,
                height: 22,
                color: completed
                    ? color.withOpacity(0.4)
                    : Colors.grey
                        .withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Padding(
          padding:
              const EdgeInsets.only(
            top: 2,
          ),
          child: Text(
            status,
            style:
                TextStyle(
              fontWeight:
                  completed
                      ? FontWeight.w600
                      : FontWeight.normal,
              color:
                  completed
                      ? Colors.black87
                      : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // STATUS HISTORY
  // =========================================================

  Widget statusHistorySection(
    Map<String, dynamic> data,
  ) {
    final history =
        (data['statusHistory'] as List?)
                ?.map(
                  (e) =>
                      Map<String, dynamic>.from(e),
                )
                .toList() ??
            [];

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding:
          EdgeInsets.zero,
      title:
          const Text(
        'Status History',
        style:
            TextStyle(
          fontWeight:
              FontWeight.bold,
        ),
      ),
      children:
          history.reversed.map(
        (item) {
          return ListTile(
            dense: true,
            leading:
                Icon(
              statusIcon(
                item['status']
                        ?.toString() ??
                    '',
              ),
              color:
                  statusColor(
                item['status']
                        ?.toString() ??
                    '',
              ),
            ),
            title:
                Text(
              item['status']
                      ?.toString() ??
                  '-',
            ),
            subtitle:
                Text(
              '${item['updatedBy'] ?? '-'} • '
              '${formatDate(item['timestamp'])}',
            ),
          );
        },
      ).toList(),
    );
  }

  // =========================================================
  // COURIER INFO
  // =========================================================

  Widget courierInfoSection(
    Map<String, dynamic> data,
  ) {
    final trackingStatus =
        data['trackingStatus']
            ?.toString();

    final trackingNumber =
        data['trackingNumber']
            ?.toString();

    final courierPartner =
        data['courierPartner']
            ?.toString();

    final courierPerson =
        data['courierPersonName']
            ?.toString();

    final courierPhone =
        data['courierPhone']
            ?.toString();

    if (trackingStatus == null &&
        trackingNumber == null &&
        courierPartner == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        border: Border.all(
          color:
              Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Courier / Tracking',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (trackingStatus != null)
            Text(
              'Tracking Status: '
              '$trackingStatus',
            ),
          if (trackingNumber != null &&
              trackingNumber.isNotEmpty)
            Text(
              'AWB: '
              '$trackingNumber',
            ),
          if (courierPartner != null &&
              courierPartner.isNotEmpty)
            Text(
              'Courier: '
              '$courierPartner',
            ),
          if (courierPerson != null &&
              courierPerson.isNotEmpty)
            Text(
              'Person: '
              '$courierPerson',
            ),
          if (courierPhone != null &&
              courierPhone.isNotEmpty)
            Text(
              'Phone: '
              '$courierPhone',
            ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preesho Admin Panel',
        ),

        // ================= ADMIN MANAGEMENT =================

        actions: [
          IconButton(
            tooltip:
                'Vendor Management',
            icon: const Icon(
              Icons.storefront,
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

          // ================= COURIER MANAGEMENT =================

          IconButton(
            tooltip:
                'Courier Management',
            icon: const Icon(
              Icons.delivery_dining,
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

        bottom: TabBar(
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
                Icons.receipt_long,
              ),
              text: 'Orders',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller:
            tabController,
        children: [
          productForm(),
          productList(),
          orderList(),
        ],
      ),
    );
  }
}
