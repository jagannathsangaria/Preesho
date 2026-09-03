import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorPanel extends StatefulWidget {
  const VendorPanel({super.key});

  @override
  State<VendorPanel> createState() => _VendorPanelState();
}

class _VendorPanelState extends State<VendorPanel> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool _loading = true;
  bool _authorized = false;

  String _vendorName = 'Vendor';
  String _vendorEmail = '';
  String _vendorPhone = '';
  String _vendorStatus = '';
  String _vendorUid = '';

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkVendorAccess();
  }

  // ============================================================
  // VENDOR ACCESS CHECK
  // ============================================================

  Future<void> _checkVendorAccess() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        if (mounted) {
          _showAccessDenied(
            'Please login with your vendor account.',
          );
        }
        return;
      }

      _vendorUid = user.uid;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final vendorDoc = await _firestore
          .collection('vendors')
          .doc(user.uid)
          .get();

      final userData =
          userDoc.data() ?? {};

      final vendorData =
          vendorDoc.data() ?? {};

      final roleValue =
          userData['role'] ?? userData['Role'];

      final role = roleValue
          ?.toString()
          .trim()
          .toLowerCase();

      final statusValue =
          userData['vendorStatus'] ??
              vendorData['status'];

      final status = statusValue
          ?.toString()
          .trim()
          .toLowerCase();

      final active =
          userData['active'] == true ||
              vendorData['active'] == true;

      if (role != 'vendor') {
        await _logoutAndShowMessage(
          'Access denied. This account is not a vendor account.',
        );
        return;
      }

      if (status != 'approved') {
        await _logoutAndShowMessage(
          'Vendor account is not approved yet.',
        );
        return;
      }

      if (!active) {
        await _logoutAndShowMessage(
          'Vendor account is inactive.',
        );
        return;
      }

      _vendorName =
          String(
            userData['name'] ??
                vendorData['name'] ??
                user.displayName ??
                'Vendor',
          );

      _vendorEmail =
          String(
            userData['email'] ??
                vendorData['email'] ??
                user.email ??
                '',
          );

      _vendorPhone =
          String(
            userData['phone'] ??
                vendorData['phone'] ??
                '',
          );

      _vendorStatus = status;

      if (!mounted) return;

      setState(() {
        _authorized = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Unable to verify vendor access.\n$e',
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  Future<void> _logoutAndShowMessage(
    String message,
  ) async {
    await _auth.signOut();

    if (!mounted) return;

    setState(() {
      _loading = false;
      _authorized = false;
    });

    _showMessage(message);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAccessDenied(String message) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _authorized = false;
    });

    _showMessage(message);
  }

  // ============================================================
  // PRODUCT HELPERS
  // ============================================================

  String _productName(
    Map<String, dynamic> data,
  ) {
    return String(
      data['Name'] ??
          data['name'] ??
          'Unnamed Product',
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString().replaceAll(',', ''),
        ) ??
        0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().replaceAll(',', ''),
        ) ??
        0;
  }

  List<String> _imageUrls(
    Map<String, dynamic> data,
  ) {
    final result = <String>[];

    final imageUrls =
        data['ImageUrls'];

    if (imageUrls is List) {
      for (final item in imageUrls) {
        final url = item.toString().trim();

        if (url.isNotEmpty) {
          result.add(url);
        }
      }
    }

    final singleImage =
        data['Imageurl']?.toString().trim();

    if (result.isEmpty &&
        singleImage != null &&
        singleImage.isNotEmpty) {
      result.add(singleImage);
    }

    return result;
  }

  String _discountText(
    Map<String, dynamic> data,
  ) {
    final discount =
        _toDouble(data['DiscountPercent']);

    if (discount <= 0) {
      return '';
    }

    return '${discount.toStringAsFixed(0)}% OFF';
  }

  // ============================================================
  // ADD / EDIT PRODUCT
  // ============================================================

  Future<void> _showProductDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data =
        document?.data() ?? {};

    final nameController =
        TextEditingController(
      text: String(
        data['Name'] ?? '',
      ),
    );

    final categoryController =
        TextEditingController(
      text: String(
        data['Category'] ?? '',
      ),
    );

    final priceController =
        TextEditingController(
      text: data['Price']?.toString() ?? '',
    );

    final mrpController =
        TextEditingController(
      text: data['MRP']?.toString() ?? '',
    );

    final discountController =
        TextEditingController(
      text:
          data['DiscountPercent']?.toString() ?? '',
    );

    final stockController =
        TextEditingController(
      text: data['Stock']?.toString() ?? '',
    );

    final imageController =
        TextEditingController(
      text: _imageUrls(data).join('\n'),
    );

    final descriptionController =
        TextEditingController(
      text: String(
        data['Description'] ?? '',
      ),
    );

    final remarkController =
        TextEditingController(
      text: String(
        data['Remark'] ?? '',
      ),
    );

    final brandController =
        TextEditingController(
      text: String(
        data['Brand'] ?? '',
      ),
    );

    final materialController =
        TextEditingController(
      text: String(
        data['Material'] ?? '',
      ),
    );

    final colorController =
        TextEditingController(
      text: String(
        data['Color'] ?? '',
      ),
    );

    final sizeController =
        TextEditingController(
      text: String(
        data['Size'] ?? '',
      ),
    );

    final weightController =
        TextEditingController(
      text: String(
        data['Weight'] ?? '',
      ),
    );

    final warrantyController =
        TextEditingController(
      text: String(
        data['Warranty'] ?? '',
      ),
    );

    final highlightsController =
        TextEditingController(
      text: String(
        data['Highlights'] ?? '',
      ),
    );

    bool active =
        data['Active'] != false;

    final isEdit =
        document != null;

    final result =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                isEdit
                    ? 'Edit Product'
                    : 'Add Product',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      _dialogField(
                        controller:
                            nameController,
                        label: 'Product Name',
                        icon:
                            Icons.shopping_bag_outlined,
                      ),

                      const SizedBox(height: 12),

                      _dialogField(
                        controller:
                            categoryController,
                        label: 'Category',
                        icon:
                            Icons.category_outlined,
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              controller:
                                  priceController,
                              label: 'Price',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              controller:
                                  mrpController,
                              label: 'MRP',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              controller:
                                  discountController,
                              label:
                                  'Discount %',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              controller:
                                  stockController,
                              label: 'Stock',
                              keyboardType:
                                  TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _dialogField(
                        controller:
                            imageController,
                        label:
                            'Image URLs (one per line)',
                        maxLines: 4,
                        icon:
                            Icons.image_outlined,
                      ),

                      const SizedBox(height: 12),

                      _dialogField(
                        controller:
                            descriptionController,
                        label: 'Description',
                        maxLines: 4,
                      ),

                      const SizedBox(height: 12),

                      _dialogField(
                        controller:
                            remarkController,
                        label: 'Remark',
                        maxLines: 2,
                      ),

                      const SizedBox(height: 12),

                      _dialogField(
                        controller:
                            brandController,
                        label: 'Brand',
                      ),

                      const SizedBox(height: 12),

                      _dialogField(
                        controller:
                            materialController,
                        label: 'Material',
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              controller:
                                  colorController,
                              label: 'Color',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              controller:
                                  sizeController,
                              label: 'Size',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              controller:
                                  weightController,
                              label: 'Weight',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              controller:
                                  warrantyController,
                              label: 'Warranty',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _dialogField(
                        controller:
                            highlightsController,
                        label: 'Highlights',
                        maxLines: 4,
                      ),

                      const SizedBox(height: 8),

                      SwitchListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        title: const Text(
                          'Product Active',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        value: active,
                        onChanged:
                            (value) {
                          setDialogState(() {
                            active =
                                value;
                          });
                        },
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
                  child:
                      const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: Icon(
                    isEdit
                        ? Icons.save
                        : Icons.add,
                  ),
                  label: Text(
                    isEdit
                        ? 'Update'
                        : 'Add Product',
                  ),
                  onPressed: () async {
                    final name =
                        nameController
                            .text
                            .trim();

                    final category =
                        categoryController
                            .text
                            .trim();

                    final price =
                        _toDouble(
                      priceController
                          .text
                          .trim(),
                    );

                    final mrp =
                        _toDouble(
                      mrpController
                          .text
                          .trim(),
                    );

                    final discount =
                        _toDouble(
                      discountController
                          .text
                          .trim(),
                    );

                    final stock =
                        _toInt(
                      stockController
                          .text
                          .trim(),
                    );

                    if (name.isEmpty) {
                      _showMessage(
                        'Product name is required.',
                      );
                      return;
                    }

                    if (category.isEmpty) {
                      _showMessage(
                        'Category is required.',
                      );
                      return;
                    }

                    if (price <= 0) {
                      _showMessage(
                        'Enter a valid price.',
                      );
                      return;
                    }

                    if (stock < 0) {
                      _showMessage(
                        'Stock cannot be negative.',
                      );
                      return;
                    }

                    final imageUrls =
                        imageController
                            .text
                            .split('\n')
                            .map(
                              (e) =>
                                  e.trim(),
                            )
                            .where(
                              (e) =>
                                  e.isNotEmpty,
                            )
                            .toList();

                    final productData =
                        <String, dynamic>{
                      'Name': name,
                      'Category':
                          category,
                      'Price': price,
                      'MRP': mrp,
                      'DiscountPercent':
                          discount,
                      'Stock': stock,
                      'ImageUrls':
                          imageUrls,
                      'Imageurl':
                          imageUrls.isNotEmpty
                              ? imageUrls.first
                              : '',
                      'Description':
                          descriptionController
                              .text
                              .trim(),
                      'Remark':
                          remarkController
                              .text
                              .trim(),
                      'Brand':
                          brandController
                              .text
                              .trim(),
                      'Material':
                          materialController
                              .text
                              .trim(),
                      'Color':
                          colorController
                              .text
                              .trim(),
                      'Size':
                          sizeController
                              .text
                              .trim(),
                      'Weight':
                          weightController
                              .text
                              .trim(),
                      'Warranty':
                          warrantyController
                              .text
                              .trim(),
                      'Highlights':
                          highlightsController
                              .text
                              .trim(),
                      'Active': active,

                      // IMPORTANT:
                      // Vendor ownership.
                      'vendorUid':
                          _vendorUid,
                      'vendorName':
                          _vendorName,

                      'UpdatedAt':
                          FieldValue
                              .serverTimestamp(),
                    };

                    if (!isEdit) {
                      productData[
                              'CreatedAt'] =
                          FieldValue
                              .serverTimestamp();
                    }

                    try {
                      if (isEdit) {
                        await _firestore
                            .collection(
                                'Products')
                            .doc(
                              document!.id,
                            )
                            .update(
                              productData,
                            );
                      } else {
                        await _firestore
                            .collection(
                                'Products')
                            .add(
                              productData,
                            );
                      }

                      if (!mounted) return;

                      Navigator.pop(
                        dialogContext,
                        true,
                      );

                      _showMessage(
                        isEdit
                            ? 'Product updated successfully.'
                            : 'Product added successfully.',
                      );
                    } catch (e) {
                      _showMessage(
                        'Unable to save product.\n$e',
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    mrpController.dispose();
    discountController.dispose();
    stockController.dispose();
    imageController.dispose();
    descriptionController.dispose();
    remarkController.dispose();
    brandController.dispose();
    materialController.dispose();
    colorController.dispose();
    sizeController.dispose();
    weightController.dispose();
    warrantyController.dispose();
    highlightsController.dispose();

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            icon == null
                ? null
                : Icon(icon),
        border:
            const OutlineInputBorder(),
      ),
    );
  }

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  Future<void> _deleteProduct(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) async {
    final data =
        document.data() ?? {};

    final name =
        _productName(data);

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Delete Product'),
          content: Text(
            'Are you sure you want to delete "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('Products')
          .doc(document.id)
          .delete();

      _showMessage(
        'Product deleted successfully.',
      );
    } catch (e) {
      _showMessage(
        'Unable to delete product.\n$e',
      );
    }
  }

  // ============================================================
  // PRODUCT CARD
  // ============================================================

  Widget _productCard(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final data =
        document.data() ?? {};

    final name =
        _productName(data);

    final category =
        String(
      data['Category'] ?? '',
    );

    final price =
        _toDouble(data['Price']);

    final mrp =
        _toDouble(data['MRP']);

    final stock =
        _toInt(data['Stock']);

    final active =
        data['Active'] != false;

    final discount =
        _discountText(data);

    final images =
        _imageUrls(data);

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
                color:
                    Colors.grey.shade100,
              ),
              child:
                  images.isNotEmpty
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          child:
                              Image.network(
                            images.first,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const Icon(
                                Icons
                                    .image_not_supported_outlined,
                                size: 35,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons
                              .shopping_bag_outlined,
                          size: 35,
                        ),
            ),

            const SizedBox(width: 12),

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
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  if (category
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      category,
                      style:
                          const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 6,
                  ),

                  Row(
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(2)}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (mrp > price &&
                          mrp > 0) ...[
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          '₹${mrp.toStringAsFixed(2)}',
                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
                            decoration:
                                TextDecoration
                                    .lineThrough,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _smallChip(
                        'Stock: $stock',
                        stock > 0
                            ? Colors.green
                            : Colors.red,
                      ),
                      if (discount
                          .isNotEmpty)
                        _smallChip(
                          discount,
                          Colors.orange,
                        ),
                      _smallChip(
                        active
                            ? 'ACTIVE'
                            : 'INACTIVE',
                        active
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              onSelected:
                  (value) {
                if (value ==
                    'edit') {
                  _showProductDialog(
                    document:
                        document,
                  );
                } else if (value ==
                    'delete') {
                  _deleteProduct(
                    document,
                  );
                }
              },
              itemBuilder:
                  (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                      ),
                      SizedBox(width: 8),
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
                      ),
                      SizedBox(width: 8),
                      Text('Delete'),
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

  Widget _smallChip(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            TextStyle(
          color: color,
          fontSize: 10,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCTS PAGE
  // ============================================================

  Widget _productsPage() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('Products')
          .where(
            'vendorUid',
            isEqualTo: _vendorUid,
          )
          .snapshots(),
      builder:
          (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Text(
                'Unable to load products.\n\n${snapshot.error}',
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

        return RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(
              const Duration(
                milliseconds: 300,
              ),
            );
          },
          child:
              docs.isEmpty
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(
                          height: 120,
                        ),
                        const Icon(
                          Icons
                              .inventory_2_outlined,
                          size: 70,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        const Center(
                          child: Text(
                            'No products found.',
                            style:
                                TextStyle(
                              fontSize:
                                  18,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Center(
                          child: Text(
                            'Add your first product.',
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Center(
                          child:
                              FilledButton.icon(
                            onPressed:
                                () {
                              _showProductDialog();
                            },
                            icon:
                                const Icon(
                              Icons.add,
                            ),
                            label:
                                const Text(
                              'Add Product',
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(
                        12,
                        12,
                        12,
                        90,
                      ),
                      itemCount:
                          docs.length,
                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        return _productCard(
                          docs[index],
                        );
                      },
                    ),
        );
      },
    );
  }

  // ============================================================
  // ORDERS PAGE
  // ============================================================

  Widget _ordersPage() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('orders')
          .where(
            'vendorUid',
            isEqualTo: _vendorUid,
          )
          .snapshots(),
      builder:
          (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Text(
                'Unable to load vendor orders.\n\n${snapshot.error}',
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
            child: Padding(
              padding:
                  EdgeInsets.all(20),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .receipt_long_outlined,
                    size: 70,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No orders found.',
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vendor orders will appear here.',
                    textAlign:
                        TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.all(12),
          itemCount:
              docs.length,
          itemBuilder:
              (context, index) {
            return _orderCard(
              docs[index],
            );
          },
        );
      },
    );
  }

  Widget _orderCard(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final data =
        document.data() ?? {};

    final orderId =
        document.id;

    final status =
        String(
      data['status'] ??
          data['Status'] ??
          'Placed',
    );

    final total =
        _toDouble(
      data['totalAmount'] ??
          data['TotalAmount'] ??
          data['total'],
    );

    final customerName =
        String(
      data['customerName'] ??
          data['CustomerName'] ??
          '',
    );

    final customerPhone =
        String(
      data['customerPhone'] ??
          data['phone'] ??
          '',
    );

    final createdAt =
        data['createdAt'] ??
            data['CreatedAt'];

    String dateText = '';

    if (createdAt
        is Timestamp) {
      final date =
          createdAt.toDate();

      dateText =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: ExpansionTile(
        leading:
            CircleAvatar(
          child: const Icon(
            Icons.receipt_long,
          ),
        ),
        title: Text(
          'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle:
            Padding(
          padding:
              const EdgeInsets.only(
            top: 5,
          ),
          child: Row(
            children: [
              _statusChip(
                status,
              ),
              const SizedBox(
                width: 8,
              ),
              if (dateText
                  .isNotEmpty)
                Text(
                  dateText,
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        children: [
          if (customerName
              .isNotEmpty)
            _infoRow(
              'Customer',
              customerName,
            ),
          if (customerPhone
              .isNotEmpty)
            _infoRow(
              'Phone',
              customerPhone,
            ),
          _infoRow(
            'Status',
            status,
          ),
          _infoRow(
            'Order Total',
            '₹${total.toStringAsFixed(2)}',
          ),
          _infoRow(
            'Order ID',
            orderId,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child:
                SelectableText(
              value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
    String status,
  ) {
    final lower =
        status.toLowerCase();

    Color color;

    if (lower ==
            'delivered' ||
        lower == 'completed') {
      color = Colors.green;
    } else if (lower ==
        'cancelled') {
      color = Colors.red;
    } else if (lower ==
            'shipped' ||
        lower ==
            'out for delivery') {
      color = Colors.blue;
    } else if (lower ==
        'processing') {
      color = Colors.orange;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(
          color: color,
          fontSize: 10,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _profilePage() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        const SizedBox(
          height: 20,
        ),

        CircleAvatar(
          radius: 42,
          child: Text(
            _vendorName.isNotEmpty
                ? _vendorName[0]
                    .toUpperCase()
                : 'V',
            style:
                const TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        Center(
          child: Text(
            _vendorName,
            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Center(
          child:
              _statusChip(
            'approved',
          ),
        ),

        const SizedBox(
          height: 24,
        ),

        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: Column(
              children: [
                _profileRow(
                  Icons.email_outlined,
                  'Email',
                  _vendorEmail,
                ),
                const Divider(),
                _profileRow(
                  Icons.phone_outlined,
                  'Mobile',
                  _vendorPhone,
                ),
                const Divider(),
                _profileRow(
                  Icons.badge_outlined,
                  'Vendor UID',
                  _vendorUid,
                ),
                const Divider(),
                _profileRow(
                  Icons.verified_outlined,
                  'Status',
                  'APPROVED',
                ),
                const Divider(),
                _profileRow(
                  Icons.toggle_on_outlined,
                  'Account',
                  'ACTIVE',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 20,
        ),

        Card(
          child: ListTile(
            leading:
                const Icon(
              Icons.info_outline,
            ),
            title:
                const Text(
              'Vendor Account',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            subtitle:
                const Text(
              'Your account has been approved by Admin. You can manage your products from the Products section.',
            ),
          ),
        ),

        const SizedBox(
          height: 20,
        ),

        OutlinedButton.icon(
          onPressed: _logout,
          icon:
              const Icon(
            Icons.logout,
          ),
          label:
              const Text(
            'Logout',
          ),
        ),
      ],
    );
  }

  Widget _profileRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
          ),
          const SizedBox(
            width: 12,
          ),
          SizedBox(
            width: 90,
            child: Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child:
                SelectableText(
              value.isEmpty
                  ? '-'
                  : value,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _dashboardPage() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('Products')
          .where(
            'vendorUid',
            isEqualTo: _vendorUid,
          )
          .snapshots(),
      builder:
          (context, productSnapshot) {
        final productCount =
            productSnapshot
                    .data
                    ?.docs
                    .length ??
                0;

        return StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: _firestore
              .collection('orders')
              .where(
                'vendorUid',
                isEqualTo: _vendorUid,
              )
              .snapshots(),
          builder:
              (context, orderSnapshot) {
            final orderCount =
                orderSnapshot
                        .data
                        ?.docs
                        .length ??
                    0;

            return ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: [
                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Welcome, $_vendorName',
                  style:
                      const TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                const Text(
                  'Manage your Preesho vendor account.',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          _dashboardCard(
                        icon:
                            Icons.inventory_2_outlined,
                        title:
                            'Products',
                        value:
                            productCount
                                .toString(),
                        onTap:
                            () {
                          setState(() {
                            _currentIndex =
                                1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child:
                          _dashboardCard(
                        icon:
                            Icons.receipt_long_outlined,
                        title:
                            'Orders',
                        value:
                            orderCount
                                .toString(),
                        onTap:
                            () {
                          setState(() {
                            _currentIndex =
                                2;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                Card(
                  child: ListTile(
                    leading:
                        const Icon(
                      Icons.verified,
                      color:
                          Colors.green,
                    ),
                    title:
                        const Text(
                      'Vendor Approved',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle:
                        const Text(
                      'Your vendor account is active and approved.',
                    ),
                    trailing:
                        const Icon(
                      Icons.check_circle,
                      color:
                          Colors.green,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Card(
                  child: ListTile(
                    leading:
                        const Icon(
                      Icons.add_box_outlined,
                    ),
                    title:
                        const Text(
                      'Add New Product',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle:
                        const Text(
                      'Add products to your vendor catalogue.',
                    ),
                    trailing:
                        const Icon(
                      Icons.chevron_right,
                    ),
                    onTap:
                        () {
                      _showProductDialog();
                    },
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Card(
                  child: ListTile(
                    leading:
                        const Icon(
                      Icons.manage_search,
                    ),
                    title:
                        const Text(
                      'Manage Products',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle:
                        const Text(
                      'Edit price, stock, images and product details.',
                    ),
                    trailing:
                        const Icon(
                      Icons.chevron_right,
                    ),
                    onTap:
                        () {
                      setState(() {
                        _currentIndex =
                            1;
                      });
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 30,
              ),
              const SizedBox(
                height: 14,
              ),
              Text(
                value,
                style:
                    const TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                title,
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                ),
              ),
            ],
          ),
        ),
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
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text(
            'Vendor Panel',
          ),
        ),
        body: const Center(
          child: Padding(
            padding:
                EdgeInsets.all(24),
            child: Text(
              'Vendor access is not available.',
              textAlign:
                  TextAlign.center,
            ),
          ),
        ),
      );
    }

    final pages = [
      _dashboardPage(),
      _productsPage(),
      _ordersPage(),
      _profilePage(),
    ];

    final titles = [
      'Vendor Dashboard',
      'My Products',
      'My Orders',
      'Vendor Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title:
            Text(titles[_currentIndex]),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon:
                const Icon(
              Icons.logout,
            ),
            onPressed: _logout,
          ),
        ],
      ),
      body:
          IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton:
          _currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed:
                      _showProductDialog,
                  icon:
                      const Icon(
                    Icons.add,
                  ),
                  label:
                      const Text(
                    'Add Product',
                  ),
                )
              : null,
      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            _currentIndex,
        onDestinationSelected:
            (index) {
          setState(() {
            _currentIndex =
                index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.dashboard,
            ),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.inventory_2_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.inventory_2,
            ),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.receipt_long,
            ),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
                Icon(
              Icons.person,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
