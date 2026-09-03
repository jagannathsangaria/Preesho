import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  late final TabController tabController;

  final FirebaseFunctions functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  // ==========================================================
  // PRODUCT CONTROLLERS
  // ==========================================================

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

    super.dispose();
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  List<String> parseImageUrls(String text) {
    return text
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String normalizedOrderStatus(Map<String, dynamic> data) {
    final raw = data['orderStatus'] ?? data['status'];
    final value = raw?.toString().trim() ?? '';

    for (final status in lifecycleStatuses) {
      if (status.toLowerCase() == value.toLowerCase()) {
        return status;
      }
    }

    if (value.toLowerCase() == 'cancelled') {
      return 'Cancelled';
    }

    return 'Placed';
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

  // ==========================================================
  // PRODUCT SAVE
  // ==========================================================

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

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
        'Price': double.tryParse(priceController.text.trim()) ?? 0,
        'MRP': double.tryParse(mrpController.text.trim()) ?? 0,
        'DiscountPercent':
            double.tryParse(discountController.text.trim()) ?? 0,
        'Stock': int.tryParse(stockController.text.trim()) ?? 0,
        'ImageUrls': imageUrls,
        'Imageurl': imageUrls.isNotEmpty ? imageUrls.first : '',
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

      showMessage('Product successfully save ho gaya.');
    } catch (e) {
      showMessage('Product save nahi hua: $e');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ==========================================================
  // EDIT PRODUCT
  // ==========================================================

  Future<void> editProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final key = GlobalKey<FormState>();

    final name = TextEditingController(
      text: data['Name']?.toString() ?? '',
    );

    final category = TextEditingController(
      text: data['Category']?.toString() ?? '',
    );

    final price = TextEditingController(
      text: data['Price']?.toString() ?? '',
    );

    final mrp = TextEditingController(
      text: data['MRP']?.toString() ??
          data['Mrp']?.toString() ??
          '',
    );

    final discount = TextEditingController(
      text: data['DiscountPercent']?.toString() ??
          data['Discount']?.toString() ??
          '',
    );

    final stock = TextEditingController(
      text: data['Stock']?.toString() ?? '',
    );

    final imageUrls = <String>[];

    final rawImages = data['ImageUrls'];

    if (rawImages is List) {
      for (final item in rawImages) {
        final value = item.toString().trim();

        if (value.isNotEmpty) {
          imageUrls.add(value);
        }
      }
    }

    final legacyImage =
        data['Imageurl']?.toString() ??
        data['ImageUrl']?.toString() ??
        '';

    if (imageUrls.isEmpty && legacyImage.trim().isNotEmpty) {
      imageUrls.add(legacyImage.trim());
    }

    final imageController = TextEditingController(
      text: imageUrls.join('\n'),
    );

    final description = TextEditingController(
      text: data['Description']?.toString() ?? '',
    );

    final remark = TextEditingController(
      text: data['Remark']?.toString() ?? '',
    );

    final brand = TextEditingController(
      text: data['Brand']?.toString() ?? '',
    );

    final material = TextEditingController(
      text: data['Material']?.toString() ?? '',
    );

    final color = TextEditingController(
      text: data['Color']?.toString() ?? '',
    );

    final size = TextEditingController(
      text: data['Size']?.toString() ?? '',
    );

    final weight = TextEditingController(
      text: data['Weight']?.toString() ?? '',
    );

    final warranty = TextEditingController(
      text: data['Warranty']?.toString() ?? '',
    );

    final highlights = TextEditingController(
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
                  width: 520,
                  child: SingleChildScrollView(
                    child: Form(
                      key: key,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _editField(
                            name,
                            'Product Name',
                            required: true,
                          ),
                          _editField(category, 'Category'),
                          _editField(
                            price,
                            'Selling Price',
                            number: true,
                          ),
                          _editField(
                            mrp,
                            'MRP',
                            number: true,
                          ),
                          _editField(
                            discount,
                            'Discount %',
                            number: true,
                          ),
                          _editField(
                            stock,
                            'Stock',
                            number: true,
                          ),
                          _editField(
                            imageController,
                            'Image URLs',
                            maxLines: 4,
                          ),
                          _editField(
                            description,
                            'Description',
                            maxLines: 3,
                          ),
                          _editField(remark, 'Remark'),
                          _editField(brand, 'Brand'),
                          _editField(material, 'Material'),
                          _editField(color, 'Color'),
                          _editField(size, 'Size'),
                          _editField(weight, 'Weight'),
                          _editField(warranty, 'Warranty'),
                          _editField(
                            highlights,
                            'Highlights',
                            maxLines: 3,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Product Active'),
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
                      Navigator.pop(dialogContext, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (!key.currentState!.validate()) return;

                      try {
                        final images = parseImageUrls(
                          imageController.text,
                        );

                        await productsRef.doc(productId).update({
                          'Name': name.text.trim(),
                          'Category': category.text.trim(),
                          'Price':
                              double.tryParse(price.text.trim()) ?? 0,
                          'MRP': double.tryParse(mrp.text.trim()) ?? 0,
                          'DiscountPercent':
                              double.tryParse(discount.text.trim()) ?? 0,
                          'Stock':
                              int.tryParse(stock.text.trim()) ?? 0,
                          'ImageUrls': images,
                          'Imageurl':
                              images.isNotEmpty ? images.first : '',
                          'Description': description.text.trim(),
                          'Remark': remark.text.trim(),
                          'Brand': brand.text.trim(),
                          'Material': material.text.trim(),
                          'Color': color.text.trim(),
                          'Size': size.text.trim(),
                          'Weight': weight.text.trim(),
                          'Warranty': warranty.text.trim(),
                          'Highlights': highlights.text.trim(),
                          'Active': editActive,
                          'UpdatedAt': FieldValue.serverTimestamp(),
                        });

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        showMessage('Product update nahi hua: $e');
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Update Product'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true) {
        showMessage('Product successfully update ho gaya.');
      }
    } finally {
      name.dispose();
      category.dispose();
      price.dispose();
      mrp.dispose();
      discount.dispose();
      stock.dispose();
      imageController.dispose();
      description.dispose();
      remark.dispose();
      brand.dispose();
      material.dispose();
      color.dispose();
      size.dispose();
      weight.dispose();
      warranty.dispose();
      highlights.dispose();
    }
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType:
            number ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  // ==========================================================
  // DELETE PRODUCT
  // ==========================================================

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
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await productsRef.doc(productId).delete();

      showMessage('Product successfully delete ho gaya.');
    } catch (e) {
      showMessage('Product delete nahi hua: $e');
    }
  }

  // ==========================================================
  // EXCEL UPLOAD
  // ==========================================================

  Future<void> uploadExcel() async {
    try {
      setState(() {
        uploadingExcel = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null) return;

      final bytes = result.files.single.bytes;

      if (bytes == null) {
        showMessage('Excel file read nahi ho paayi.');
        return;
      }

      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        showMessage('Excel sheet nahi mili.');
        return;
      }

      final sheet = excel.tables.values.first;

      if (sheet.rows.isEmpty) {
        showMessage('Excel empty hai.');
        return;
      }

      final headers = sheet.rows.first
          .map(
            (cell) => cell?.value.toString().trim() ?? '',
          )
          .toList();

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        dynamic getValue(String header) {
          final index = headers.indexOf(header);

          if (index == -1 || index >= row.length) {
            return null;
          }

          return row[index]?.value;
        }

        final name = getValue('Name')?.toString().trim() ?? '';

        if (name.isEmpty) continue;

        final imageText =
            getValue('ImageUrls')?.toString() ??
            getValue('Imageurl')?.toString() ??
            '';

        final images = parseImageUrls(imageText);

        await productsRef.add({
          'Name': name,
          'Category': getValue('Category')?.toString() ?? '',
          'Price':
              double.tryParse(getValue('Price')?.toString() ?? '') ?? 0,
          'MRP':
              double.tryParse(getValue('MRP')?.toString() ?? '') ?? 0,
          'DiscountPercent':
              double.tryParse(
                getValue('DiscountPercent')?.toString() ??
                    getValue('Discount')?.toString() ??
                    '',
              ) ??
              0,
          'Stock':
              int.tryParse(getValue('Stock')?.toString() ?? '') ?? 0,
          'ImageUrls': images,
          'Imageurl': images.isNotEmpty ? images.first : '',
          'Description':
              getValue('Description')?.toString() ?? '',
          'Remark': getValue('Remark')?.toString() ?? '',
          'Brand': getValue('Brand')?.toString() ?? '',
          'Material': getValue('Material')?.toString() ?? '',
          'Color': getValue('Color')?.toString() ?? '',
          'Size': getValue('Size')?.toString() ?? '',
          'Weight': getValue('Weight')?.toString() ?? '',
          'Warranty': getValue('Warranty')?.toString() ?? '',
          'Highlights': getValue('Highlights')?.toString() ?? '',
          'Active': true,
          'CreatedAt': FieldValue.serverTimestamp(),
        });
      }

      showMessage('Excel products successfully upload ho gaye.');
    } catch (e) {
      showMessage('Excel upload error: $e');
    } finally {
      if (mounted) {
        setState(() {
          uploadingExcel = false;
        });
      }
    }
  }

  // ==========================================================
  // EXCEL TEMPLATE
  // ==========================================================

  Future<void> downloadTemplate() async {
    try {
      setState(() {
        downloadingTemplate = true;
      });

      final excel = Excel.createExcel();

      final sheet = excel[
        excel.getDefaultSheet() ?? 'Sheet1'
      ];

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
        headers.map((e) => TextCellValue(e)).toList(),
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
        TextCellValue('Sample product description'),
        TextCellValue('New'),
        TextCellValue('Preesho'),
        TextCellValue('Plastic'),
        TextCellValue('Black'),
        TextCellValue('M'),
        TextCellValue('500g'),
        TextCellValue('1 Year'),
        TextCellValue('Good quality product'),
      ]);

      final bytes = excel.encode();

      if (bytes == null) {
        showMessage('Excel generate nahi hui.');
        return;
      }

      await FileSaver.instance.saveFile(
        name: 'preesho_product_template',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      showMessage('Excel template download ho gayi.');
    } catch (e) {
      showMessage('Template error: $e');
    } finally {
      if (mounted) {
        setState(() {
          downloadingTemplate = false;
        });
      }
    }
  }

  // ==========================================================
  // ADMIN ORDER STATUS - BACKEND
  // ==========================================================

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    try {
      final callable = functions.httpsCallable(
        'updateOrderStatus',
      );

      await callable.call({
        'orderId': orderId,
        'newStatus': newStatus,
      });

      showMessage('Order $newStatus successfully.');
    } on FirebaseFunctionsException catch (e) {
      showMessage(
        e.message ?? 'Order status update failed.',
      );
    } catch (e) {
      showMessage(
        'Order status update failed: $e',
      );
    }
  }

  // ==========================================================
  // SHIP ORDER DIALOG
  // ==========================================================

  Future<void> showShipmentDialog(
    String orderId,
  ) async {
    final partnerController = TextEditingController();
    final trackingController = TextEditingController();
    final trackingUrlController = TextEditingController();
    final personNameController = TextEditingController();
    final phoneController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.local_shipping),
                SizedBox(width: 8),
                Text('Ship Order'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: partnerController,
                        decoration: const InputDecoration(
                          labelText: 'Courier Partner *',
                          hintText: 'Delhivery / Blue Dart / DTDC',
                          border: OutlineInputBorder(),
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
                        controller: trackingController,
                        decoration: const InputDecoration(
                          labelText: 'Tracking / AWB Number *',
                          border: OutlineInputBorder(),
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
                        controller: trackingUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Tracking URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: personNameController,
                        decoration: const InputDecoration(
                          labelText: 'Courier Person Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Courier Phone',
                          border: OutlineInputBorder(),
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
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.local_shipping),
                label: const Text('Ship Order'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      try {
        final callable = functions.httpsCallable(
          'shipOrder',
        );

        await callable.call({
          'orderId': orderId,
          'courierPartner': partnerController.text.trim(),
          'trackingNumber': trackingController.text.trim(),
          'trackingUrl': trackingUrlController.text.trim(),
          'courierPersonName': personNameController.text.trim(),
          'courierPhone': phoneController.text.trim(),
        });

        showMessage(
          'Order successfully Shipped.',
        );
      } on FirebaseFunctionsException catch (e) {
        showMessage(
          e.message ?? 'Ship order failed.',
        );
      } catch (e) {
        showMessage(
          'Ship order failed: $e',
        );
      }
    } finally {
      partnerController.dispose();
      trackingController.dispose();
      trackingUrlController.dispose();
      personNameController.dispose();
      phoneController.dispose();
    }
  }

  // ==========================================================
  // CANCEL ORDER - BACKEND
  // ==========================================================

  Future<void> confirmCancellation(
    String orderId,
  ) async {
    final controller = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cancel Order?'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('No'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Cancel Order'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      try {
        final callable = functions.httpsCallable(
          'cancelOrder',
        );

        await callable.call({
          'orderId': orderId,
          'reason': controller.text.trim().isEmpty
              ? 'Cancelled by Admin'
              : controller.text.trim(),
        });

        showMessage('Order cancel ho gaya.');
      } on FirebaseFunctionsException catch (e) {
        showMessage(
          e.message ?? 'Order cancellation failed.',
        );
      } catch (e) {
        showMessage(
          'Order cancellation failed: $e',
        );
      }
    } finally {
      controller.dispose();
    }
  }

  // ==========================================================
  // COURIER ASSIGNMENT
  // ==========================================================

  Future<void> assignCourier(
    String orderId,
  ) async {
    try {
      final courierSnapshot = await FirebaseFirestore.instance
          .collection('couriers')
          .where(
            'active',
            isEqualTo: true,
          )
          .get();

      if (!mounted) return;

      if (courierSnapshot.docs.isEmpty) {
        showMessage(
          'Koi active courier available nahi hai.',
        );
        return;
      }

      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Assign Courier'),
            content: SizedBox(
              width: 450,
              child: ListView(
                shrinkWrap: true,
                children: courierSnapshot.docs.map(
                  (doc) {
                    final data = doc.data();

                    final name =
                        data['name']?.toString() ??
                        'Courier';

                    final phone =
                        data['phone']?.toString() ??
                        '';

                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(
                          Icons.delivery_dining,
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        phone.isEmpty
                            ? 'Active Courier'
                            : phone,
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.pop(
                          dialogContext,
                          doc.id,
                        );
                      },
                    );
                  },
                ).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (selected == null || selected.isEmpty) {
        return;
      }

      final callable = functions.httpsCallable(
        'assignOrderToCourier',
      );

      await callable.call({
        'orderId': orderId,
        'courierId': selected,
      });

      showMessage(
        'Courier successfully assign ho gaya.',
      );
    } on FirebaseFunctionsException catch (e) {
      showMessage(
        e.message ?? 'Courier assignment failed.',
      );
    } catch (e) {
      showMessage(
        'Courier assignment failed: $e',
      );
    }
  }

  // ==========================================================
  // ORDER LIST
  // ==========================================================

  Widget orderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: ordersRef.snapshots(),
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
              padding: const EdgeInsets.all(20),
              child: Text(
                'Orders load error:\n${snapshot.error}',
              ),
            ),
          );
        }

        final docs = [
          ...(snapshot.data?.docs ?? []),
        ];

        docs.sort((a, b) {
          final ad =
              a.data() as Map<String, dynamic>;

          final bd =
              b.data() as Map<String, dynamic>;

          final at =
              ad['createdAt'];

          final bt =
              bd['createdAt'];

          final adate =
              at is Timestamp
                  ? at.toDate()
                  : DateTime(1970);

          final bdate =
              bt is Timestamp
                  ? bt.toDate()
                  : DateTime(1970);

          return bdate.compareTo(adate);
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text('No orders found.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
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

  // ==========================================================
  // ORDER CARD
  // ==========================================================

  Widget orderCard(
    String orderId,
    Map<String, dynamic> data,
  ) {
    final status = normalizedOrderStatus(data);

    final next = nextAdminStatus[status];

    final courierId =
        data['courierId']?.toString() ?? '';

    final items =
        data['items'] is List
            ? List.from(data['items'])
            : <dynamic>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
                    'Order: $orderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                statusChip(status),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Customer: '
              '${data['customerName'] ?? data['name'] ?? '-'}',
            ),

            const SizedBox(height: 4),

            Text(
              'Total: '
              '${money(data['totalAmount'] ?? data['total'] ?? data['grandTotal'])}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            if (items.isNotEmpty)
              orderItemsSection(items),

            const SizedBox(height: 12),

            orderTimeline(
              status,
              data,
            ),

            const SizedBox(height: 12),

            courierInfoSection(data),

            const SizedBox(height: 12),

            if (status == 'Shipped' &&
                courierId.isEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    assignCourier(orderId);
                  },
                  icon: const Icon(
                    Icons.delivery_dining,
                  ),
                  label: const Text(
                    'Assign Courier',
                  ),
                ),
              ),

            if (status == 'Shipped' &&
                courierId.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Text(
                  'Courier Assigned\n'
                  '${data['courierPersonName'] ?? '-'}'
                  '${data['courierPhone'] != null ? '\n${data['courierPhone']}' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            statusHistorySection(data),

            const SizedBox(height: 12),

            if (status == 'Cancelled')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Text(
                  'Order Cancelled.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (status == 'Delivered')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Text(
                  'Order Delivered successfully.',
                ),
              )
            else if (next != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (next == 'Shipped') {
                      showShipmentDialog(orderId);
                    } else {
                      updateOrderStatus(
                        orderId,
                        next,
                      );
                    }
                  },
                  icon: Icon(
                    next == 'Shipped'
                        ? Icons.local_shipping
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    next == 'Shipped'
                        ? 'Ship Order'
                        : 'Move to $next',
                  ),
                ),
              ),

            if (status == 'Placed' ||
                status == 'Confirmed' ||
                status == 'Processing')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      confirmCancellation(orderId);
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                    ),
                    label: const Text(
                      'Cancel Order',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ORDER ITEMS
  // ==========================================================

  Widget orderItemsSection(
    List<dynamic> items,
  ) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: false,
      title: Text(
        'Order Items (${items.length})',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      children: items.map(
        (item) {
          final map = item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{};

          final name =
              map['name']?.toString() ??
              map['Name']?.toString() ??
              'Product';

          final qty =
              map['quantity'] ??
              map['qty'] ??
              1;

          final price =
              map['price'] ??
              map['Price'] ??
              0;

          final vendor =
              map['vendorName']?.toString() ??
              '';

          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.shopping_bag_outlined,
            ),
            title: Text(name),
            subtitle: Text(
              'Qty: $qty • ${money(price)}'
              '${vendor.isNotEmpty ? '\nVendor: $vendor' : ''}',
            ),
          );
        },
      ).toList(),
    );
  }

  // ==========================================================
  // STATUS CHIP
  // ==========================================================

  Widget statusChip(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon(status),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TIMELINE
  // ==========================================================

  Widget orderTimeline(
    String currentStatus,
    Map<String, dynamic> data,
  ) {
    if (currentStatus == 'Cancelled') {
      return _timelineItem(
        'Cancelled',
        true,
        Colors.red,
        null,
      );
    }

    final currentIndex =
        lifecycleStatuses.indexOf(currentStatus);

    return Column(
      children: List.generate(
        lifecycleStatuses.length,
        (index) {
          final status =
              lifecycleStatuses[index];

          dynamic timestamp;

          switch (status) {
            case 'Placed':
              timestamp =
                  data['placedAt'] ??
                  data['createdAt'];
              break;

            case 'Confirmed':
              timestamp =
                  data['confirmedAt'];
              break;

            case 'Processing':
              timestamp =
                  data['processingAt'];
              break;

            case 'Packed':
              timestamp =
                  data['packedAt'];
              break;

            case 'Shipped':
              timestamp =
                  data['shippedAt'];
              break;

            case 'Picked by Courier':
              timestamp =
                  data['courierPickedAt'];
              break;

            case 'Out for Delivery':
              timestamp =
                  data['outForDeliveryAt'];
              break;

            case 'Delivered':
              timestamp =
                  data['deliveredAt'];
              break;
          }

          return _timelineItem(
            status,
            index <= currentIndex,
            statusColor(status),
            timestamp,
          );
        },
      ),
    );
  }

  Widget _timelineItem(
    String status,
    bool completed,
    Color color,
    dynamic timestamp,
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
                  completed ? color : Colors.grey,
              size: 21,
            ),
            if (status != 'Delivered')
              Container(
                width: 2,
                height: 24,
                color: completed
                    ? color.withOpacity(0.4)
                    : Colors.grey.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      fontWeight: completed
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: completed
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
                if (timestamp != null)
                  Text(
                    formatDate(timestamp),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // STATUS HISTORY
  // ==========================================================

  Widget statusHistorySection(
    Map<String, dynamic> data,
  ) {
    final rawHistory = data['statusHistory'];

    final history = rawHistory is List
        ? rawHistory
            .whereType<Map>()
            .map(
              (e) => Map<String, dynamic>.from(e),
            )
            .toList()
        : <Map<String, dynamic>>[];

    if (history.isEmpty) {
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
      children: history.reversed.map(
        (item) {
          final status =
              item['status']?.toString() ?? '';

          return ListTile(
            dense: true,
            leading: Icon(
              statusIcon(status),
              color: statusColor(status),
            ),
            title: Text(status),
            subtitle: Text(
              '${item['updatedBy'] ?? '-'} • '
              '${formatDate(item['timestamp'])}',
            ),
          );
        },
      ).toList(),
    );
  }

  // ==========================================================
  // COURIER INFO
  // ==========================================================

  Widget courierInfoSection(
    Map<String, dynamic> data,
  ) {
    final courierId =
        data['courierId']?.toString() ?? '';

    final courierName =
        data['courierPersonName']?.toString() ?? '';

    final courierPhone =
        data['courierPhone']?.toString() ?? '';

    final partner =
        data['courierPartner']?.toString() ?? '';

    final tracking =
        data['trackingNumber']?.toString() ?? '';

    final trackingStatus =
        data['trackingStatus']?.toString() ?? '';

    final trackingUrl =
        data['trackingUrl']?.toString() ?? '';

    if (courierId.isEmpty &&
        courierName.isEmpty &&
        courierPhone.isEmpty &&
        partner.isEmpty &&
        tracking.isEmpty &&
        trackingStatus.isEmpty &&
        trackingUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Courier / Tracking',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          if (courierId.isNotEmpty)
            Text('Courier ID: $courierId'),

          if (courierName.isNotEmpty)
            Text('Courier: $courierName'),

          if (courierPhone.isNotEmpty)
            Text('Phone: $courierPhone'),

          if (partner.isNotEmpty)
            Text('Courier Partner: $partner'),

          if (tracking.isNotEmpty)
            Text('AWB: $tracking'),

          if (trackingStatus.isNotEmpty)
            Text(
              'Tracking Status: $trackingStatus',
            ),

          if (trackingUrl.isNotEmpty)
            Text(
              'Tracking URL: $trackingUrl',
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // PRODUCT FORM
  // ==========================================================

  Widget productForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _mainField(
              nameController,
              'Product Name',
              required: true,
            ),
            _mainField(
              categoryController,
              'Category',
            ),
            _mainField(
              priceController,
              'Price',
              number: true,
            ),
            _mainField(
              mrpController,
              'MRP',
              number: true,
            ),
            _mainField(
              discountController,
              'Discount %',
              number: true,
            ),
            _mainField(
              stockController,
              'Stock',
              number: true,
            ),
            _mainField(
              imageUrlsController,
              'Image URLs',
              maxLines: 3,
            ),
            _mainField(
              descriptionController,
              'Description',
              maxLines: 3,
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
              title: const Text('Active'),
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
                icon: const Icon(
                  Icons.upload_file,
                ),
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

  Widget _mainField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType:
            number
                ? TextInputType.number
                : TextInputType.text,
        maxLines: maxLines,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ).copyWith(
          labelText: label,
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

  // ==========================================================
  // PRODUCT LIST
  // ==========================================================

  Widget productList() {
    return StreamBuilder<QuerySnapshot>(
      stream: productsRef.snapshots(),
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
              padding: const EdgeInsets.all(20),
              child: Text(
                'Product list error:\n${snapshot.error}',
              ),
            ),
          );
        }

        final docs = [
          ...(snapshot.data?.docs ?? []),
        ];

        docs.sort((a, b) {
          final ad =
              a.data()
                  as Map<String, dynamic>;

          final bd =
              b.data()
                  as Map<String, dynamic>;

          final at = ad['CreatedAt'];
          final bt = bd['CreatedAt'];

          final adate =
              at is Timestamp
                  ? at.toDate()
                  : DateTime(1970);

          final bdate =
              bt is Timestamp
                  ? bt.toDate()
                  : DateTime(1970);

          return bdate.compareTo(adate);
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text('No products found.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];

            final data =
                doc.data()
                    as Map<String, dynamic>;

            final images = <String>[];

            final raw = data['ImageUrls'];

            if (raw is List) {
              for (final item in raw) {
                final url =
                    item.toString().trim();

                if (url.isNotEmpty) {
                  images.add(url);
                }
              }
            }

            if (images.isEmpty) {
              final legacy =
                  data['Imageurl']
                          ?.toString()
                          .trim() ??
                      data['ImageUrl']
                          ?.toString()
                          .trim() ??
                      '';

              if (legacy.isNotEmpty) {
                images.add(legacy);
              }
            }

            final productName =
                data['Name']?.toString() ??
                'Unnamed';

            final isActive =
                data['Active'] != false;

            return Card(
              margin: const EdgeInsets.only(
                bottom: 10,
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                leading: images.isNotEmpty
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          8,
                        ),
                        child: Image.network(
                          images.first,
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
                    Text(
                      isActive
                          ? 'Active'
                          : 'Inactive',
                      style: TextStyle(
                        color: isActive
                            ? Colors.green
                            : Colors.red,
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 11,
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
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        editProduct(
                          doc.id,
                          data,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
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

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preesho Admin Panel',
        ),
        actions: [
          IconButton(
            tooltip: 'Vendor Management',
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

          IconButton(
            tooltip: 'Courier Management',
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
                Icons.receipt_long,
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
