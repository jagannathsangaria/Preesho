import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'vendor_documents_page.dart';

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

  int _currentIndex = 0;

  bool _loading = true;
  bool _accessAllowed = false;

  String _vendorUid = '';
  String _vendorName = '';
  String _vendorEmail = '';
  String _vendorPhone = '';
  String _vendorStatus = '';
  bool _vendorActive = false;

  @override
  void initState() {
    super.initState();
    _checkVendorAccess();
  }

  // ============================================================
  // VENDOR ACCESS
  // ============================================================

  Future<void> _checkVendorAccess() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        _denyAccess();
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

      final userData = userDoc.data() ?? {};
      final vendorData = vendorDoc.data() ?? {};

      final roleValue =
          userData['role'] ??
          userData['Role'] ??
          vendorData['role'] ??
          vendorData['Role'];

      final role = roleValue
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      final userStatus = userData['vendorStatus']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      final vendorStatus = vendorData['status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      final status = vendorStatus.isNotEmpty
          ? vendorStatus
          : userStatus;

      final userActive = userData['active'] == true;
      final vendorActive = vendorData['active'] == true;

      final active = userActive || vendorActive;

      if (role != 'vendor' ||
          status != 'approved' ||
          !active) {
        await _auth.signOut();

        _denyAccess(
          message: status == 'pending'
              ? 'Vendor account is pending approval.'
              : status == 'rejected'
                  ? 'Vendor account has been rejected.'
                  : status == 'suspended'
                      ? 'Vendor account is suspended.'
                      : 'Vendor access denied.',
        );

        return;
      }

      _vendorName =
          (vendorData['name'] ??
                  userData['name'] ??
                  userData['Name'] ??
                  '')
              .toString();

      _vendorEmail =
          (vendorData['email'] ??
                  userData['email'] ??
                  user.email ??
                  '')
              .toString();

      _vendorPhone =
          (vendorData['phone'] ??
                  userData['phone'] ??
                  userData['Phone'] ??
                  '')
              .toString();

      _vendorStatus = status;
      _vendorActive = active;

      if (!mounted) return;

      setState(() {
        _accessAllowed = true;
        _loading = false;
      });
    } catch (e) {
      _denyAccess(
        message: 'Unable to verify vendor access.',
      );
    }
  }

  void _denyAccess({
    String message = 'Vendor access denied.',
  }) {
    if (!mounted) return;

    setState(() {
      _accessAllowed = false;
      _loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future.delayed(
      const Duration(milliseconds: 800),
      () {
        if (!mounted) return;
        Navigator.pop(context);
      },
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.pop(context);
  }

  // ============================================================
  // PRODUCT DIALOG
  // ============================================================

  Future<void> _showProductDialog({
    DocumentSnapshot<Map<String, dynamic>>? product,
  }) async {
    final data = product?.data() ?? {};

    final nameController = TextEditingController(
      text: data['Name']?.toString() ?? '',
    );

    final categoryController = TextEditingController(
      text: data['Category']?.toString() ?? '',
    );

    final priceController = TextEditingController(
      text: data['Price']?.toString() ?? '',
    );

    final mrpController = TextEditingController(
      text: data['MRP']?.toString() ?? '',
    );

    final discountController = TextEditingController(
      text: data['DiscountPercent']?.toString() ?? '',
    );

    final stockController = TextEditingController(
      text: data['Stock']?.toString() ?? '',
    );

    final brandController = TextEditingController(
      text: data['Brand']?.toString() ?? '',
    );

    final materialController = TextEditingController(
      text: data['Material']?.toString() ?? '',
    );

    final colorController = TextEditingController(
      text: data['Color']?.toString() ?? '',
    );

    final sizeController = TextEditingController(
      text: data['Size']?.toString() ?? '',
    );

    final weightController = TextEditingController(
      text: data['Weight']?.toString() ?? '',
    );

    final warrantyController = TextEditingController(
      text: data['Warranty']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: data['Description']?.toString() ?? '',
    );

    final remarkController = TextEditingController(
      text: data['Remark']?.toString() ?? '',
    );

    final highlightsController = TextEditingController(
      text: _readList(data['Highlights']),
    );

    final imageUrlsController = TextEditingController(
      text: _readImageUrls(data),
    );

    bool active = data['Active'] != false;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                product == null
                    ? 'Add Product'
                    : 'Edit Product',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        _field(
                          nameController,
                          'Product Name',
                          required: true,
                        ),
                        _field(
                          categoryController,
                          'Category',
                        ),
                        _field(
                          priceController,
                          'Selling Price',
                          keyboard: TextInputType.number,
                        ),
                        _field(
                          mrpController,
                          'MRP',
                          keyboard: TextInputType.number,
                        ),
                        _field(
                          discountController,
                          'Discount %',
                          keyboard: TextInputType.number,
                        ),
                        _field(
                          stockController,
                          'Stock',
                          keyboard: TextInputType.number,
                        ),
                        _field(
                          brandController,
                          'Brand',
                        ),
                        _field(
                          materialController,
                          'Material',
                        ),
                        _field(
                          colorController,
                          'Color',
                        ),
                        _field(
                          sizeController,
                          'Size',
                        ),
                        _field(
                          weightController,
                          'Weight',
                        ),
                        _field(
                          warrantyController,
                          'Warranty',
                        ),
                        _field(
                          descriptionController,
                          'Description',
                          maxLines: 3,
                        ),
                        _field(
                          remarkController,
                          'Remark',
                          maxLines: 2,
                        ),
                        _field(
                          highlightsController,
                          'Highlights',
                          hint: 'One highlight per line',
                          maxLines: 4,
                        ),
                        _field(
                          imageUrlsController,
                          'Image URLs',
                          hint: 'One image URL per line',
                          maxLines: 5,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Product Active',
                          ),
                          value: active,
                          onChanged: (value) {
                            setDialogState(() {
                              active = value;
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
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    Navigator.pop(dialogContext);

                    await _saveProduct(
                      product: product,
                      name: nameController.text.trim(),
                      category: categoryController.text.trim(),
                      price: _number(priceController.text),
                      mrp: _number(mrpController.text),
                      discount: _number(
                        discountController.text,
                      ),
                      stock: _number(stockController.text),
                      brand: brandController.text.trim(),
                      material: materialController.text.trim(),
                      color: colorController.text.trim(),
                      size: sizeController.text.trim(),
                      weight: weightController.text.trim(),
                      warranty: warrantyController.text.trim(),
                      description:
                          descriptionController.text.trim(),
                      remark: remarkController.text.trim(),
                      highlights:
                          _splitLines(highlightsController.text),
                      imageUrls:
                          _splitLines(imageUrlsController.text),
                      active: active,
                    );
                  },
                  child: const Text('Save Product'),
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
    brandController.dispose();
    materialController.dispose();
    colorController.dispose();
    sizeController.dispose();
    weightController.dispose();
    warrantyController.dispose();
    descriptionController.dispose();
    remarkController.dispose();
    highlightsController.dispose();
    imageUrlsController.dispose();
  }

  // ============================================================
  // SAVE PRODUCT
  // ============================================================

  Future<void> _saveProduct({
    DocumentSnapshot<Map<String, dynamic>>? product,
    required String name,
    required String category,
    required double price,
    required double mrp,
    required double discount,
    required double stock,
    required String brand,
    required String material,
    required String color,
    required String size,
    required String weight,
    required String warranty,
    required String description,
    required String remark,
    required List<String> highlights,
    required List<String> imageUrls,
    required bool active,
  }) async {
    try {
      final collection = _firestore.collection('Products');

      if (product != null) {
        final existingData = product.data() ?? {};

        final existingVendorUid =
            existingData['vendorUid']
                ?.toString()
                .trim();

        if (existingVendorUid != _vendorUid) {
          _showMessage(
            'You can only edit your own products.',
          );
          return;
        }
      }

      final productData = <String, dynamic>{
        'Name': name,
        'Category': category,
        'Price': price,
        'MRP': mrp,
        'DiscountPercent': discount,
        'Stock': stock,
        'ImageUrls': imageUrls,
        'Imageurl':
            imageUrls.isNotEmpty ? imageUrls.first : '',
        'Description': description,
        'Remark': remark,
        'Brand': brand,
        'Material': material,
        'Color': color,
        'Size': size,
        'Weight': weight,
        'Warranty': warranty,
        'Highlights': highlights,
        'Active': active,
        'vendorUid': _vendorUid,
        'vendorName': _vendorName,
        'UpdatedAt': FieldValue.serverTimestamp(),
      };

      if (product == null) {
        productData['CreatedAt'] =
            FieldValue.serverTimestamp();

        await collection.add(productData);

        _showMessage(
          'Product added successfully.',
        );
      } else {
        await collection
            .doc(product.id)
            .update(productData);

        _showMessage(
          'Product updated successfully.',
        );
      }
    } catch (e) {
      _showMessage(
        'Unable to save product.',
      );
    }
  }

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  Future<void> _deleteProduct(
    DocumentSnapshot<Map<String, dynamic>> product,
  ) async {
    final data = product.data() ?? {};

    final productVendor =
        data['vendorUid']?.toString().trim();

    if (productVendor != _vendorUid) {
      _showMessage(
        'You can only delete your own products.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text(
            'Are you sure you want to delete this product?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('Products')
          .doc(product.id)
          .delete();

      _showMessage('Product deleted.');
    } catch (e) {
      _showMessage(
        'Unable to delete product.',
      );
    }
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  Widget _buildProducts() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('Products')
          .where(
            'vendorUid',
            isEqualTo: _vendorUid,
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
            child: Text(
              'Unable to load products.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final products = snapshot.data?.docs ?? [];

        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 70,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No products yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your first product to start selling.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _showProductDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final data = product.data();

            final name =
                data['Name']?.toString() ??
                    'Unnamed Product';

            final price =
                data['Price']?.toString() ?? '0';

            final stock =
                data['Stock']?.toString() ?? '0';

            final active =
                data['Active'] != false;

            return Card(
              margin: const EdgeInsets.only(
                bottom: 12,
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.shopping_bag_outlined,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Price: ₹$price\n'
                  'Stock: $stock\n'
                  'Status: ${active ? "Active" : "Inactive"}',
                ),
                isThreeLine: true,
                trailing:
                    PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showProductDialog(
                        product: product,
                      );
                    }

                    if (value == 'delete') {
                      _deleteProduct(product);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
                onTap: () {
                  _showProductDialog(
                    product: product,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ORDERS
  // ============================================================

  Widget _buildOrders() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('orders')
          .where(
            'vendorUids',
            arrayContains: _vendorUid,
          )
          .snapshots(),
      builder: (context, newSnapshot) {
        return StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('orders')
              .where(
                'vendorUid',
                isEqualTo: _vendorUid,
              )
              .snapshots(),
          builder: (context, legacySnapshot) {
            if (newSnapshot.connectionState ==
                    ConnectionState.waiting &&
                legacySnapshot.connectionState ==
                    ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final Map<
                    String,
                    DocumentSnapshot<
                        Map<String, dynamic>>>
                orderMap = {};

            for (final doc
                in newSnapshot.data?.docs ?? []) {
              orderMap[doc.id] = doc;
            }

            for (final doc
                in legacySnapshot.data?.docs ?? []) {
              orderMap[doc.id] = doc;
            }

            final allOrders =
                orderMap.values.toList();

            // --------------------------------------------------
            // Only keep orders containing THIS vendor's items.
            // --------------------------------------------------

            final orders = allOrders.where((order) {
              return _orderBelongsToVendor(
                order.data() ?? {},
              );
            }).toList();

            orders.sort((a, b) {
              final aData = a.data() ?? {};
              final bData = b.data() ?? {};

              final aTime = _timestampValue(
                aData['createdAt'] ??
                    aData['placedAt'],
              );

              final bTime = _timestampValue(
                bData['createdAt'] ??
                    bData['placedAt'],
              );

              return bTime.compareTo(aTime);
            });

            if (orders.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 70,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No orders yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Orders containing your products will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _buildOrderCard(
                  orders[index],
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CHECK WHETHER ORDER BELONGS TO CURRENT VENDOR
  // ============================================================

  bool _orderBelongsToVendor(
    Map<String, dynamic> data,
  ) {
    final orderVendorUid =
        data['vendorUid']?.toString().trim();

    if (orderVendorUid == _vendorUid) {
      return true;
    }

    final vendorUids = data['vendorUids'];

    if (vendorUids is List) {
      return vendorUids.any(
        (uid) =>
            uid?.toString().trim() ==
            _vendorUid,
      );
    }

    return false;
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget _buildOrderCard(
    DocumentSnapshot<Map<String, dynamic>> order,
  ) {
    final data = order.data() ?? {};

    final customer =
        data['customerName'] ??
            data['CustomerName'] ??
            data['name'] ??
            'Customer';

    final phone =
        data['customerMobile'] ??
            data['phone'] ??
            data['Phone'] ??
            '';

    final status =
        data['orderStatus'] ??
            data['status'] ??
            'Placed';

    final List<dynamic> allItems =
        data['items'] is List
            ? List<dynamic>.from(data['items'])
            : [];

    final List<Map<String, dynamic>> vendorItems = [];

    double vendorTotal = 0;
    int vendorQuantity = 0;

    for (final item in allItems) {
      if (item is! Map) continue;

      final itemMap =
          Map<String, dynamic>.from(item);

      final itemVendorUid =
          itemMap['vendorUid']
              ?.toString()
              .trim();

      if (itemVendorUid != _vendorUid) {
        continue;
      }

      final quantity =
          _toInt(itemMap['quantity']);

      final price =
          _toDouble(itemMap['price']);

      final itemTotal =
          _toDouble(itemMap['total']);

      vendorQuantity += quantity;

      vendorTotal += itemTotal > 0
          ? itemTotal
          : price * quantity;

      vendorItems.add(itemMap);
    }

    // Legacy single-vendor order.
    if (vendorItems.isEmpty &&
        data['vendorUid']
                ?.toString()
                .trim() ==
            _vendorUid) {
      for (final item in allItems) {
        if (item is! Map) continue;

        final itemMap =
            Map<String, dynamic>.from(item);

        final quantity =
            _toInt(itemMap['quantity']);

        final price =
            _toDouble(itemMap['price']);

        final itemTotal =
            _toDouble(itemMap['total']);

        vendorQuantity += quantity;

        vendorTotal += itemTotal > 0
            ? itemTotal
            : price * quantity;

        vendorItems.add(itemMap);
      }
    }

    if (vendorItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final date = _formatTimestamp(
      data['createdAt'] ??
          data['placedAt'],
    );

    final isMultiVendor =
        data['isMultiVendor'] == true ||
        ((data['vendorUids'] is List) &&
            (data['vendorUids'] as List).length > 1);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.receipt_long),
        ),
        title: Text(
          'Order #${order.id}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text('Customer: $customer'),
              if (phone.toString().isNotEmpty)
                Text('Phone: $phone'),
              Text(
                'My Items: $vendorQuantity',
              ),
              Text(
                'My Total: ₹${_formatMoney(vendorTotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Status: $status'),
              if (isMultiVendor)
                const Text(
                  'Multi-vendor Order',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (date.isNotEmpty)
                Text(date),
            ],
          ),
        ),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              16,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Products',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                ...vendorItems.map(
                  (item) =>
                      _buildVendorOrderItem(item),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Order Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_formatMoney(vendorTotal)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isMultiVendor) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Other vendors\' products are hidden from you.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER ITEM
  // ============================================================

  Widget _buildVendorOrderItem(
    Map<String, dynamic> item,
  ) {
    final name =
        item['name']?.toString() ??
            item['Name']?.toString() ??
            'Product';

    final quantity =
        _toInt(item['quantity']);

    final price =
        _toDouble(item['price']);

    final total =
        _toDouble(item['total']);

    final imageUrl =
        item['imageUrl']?.toString() ?? '';

    final calculatedTotal =
        total > 0
            ? total
            : price * quantity;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildProductImage(imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Qty: $quantity'),
                Text(
                  'Price: ₹${_formatMoney(price)}',
                ),
                Text(
                  'Total: ₹${_formatMoney(calculatedTotal)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
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
  // PRODUCT IMAGE
  // ============================================================

  Widget _buildProductImage(
    String url,
  ) {
    if (url.trim().isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(8),
          color: Colors.grey.shade200,
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stack) {
          return Container(
            width: 58,
            height: 58,
            color: Colors.grey.shade200,
            child: const Icon(
              Icons.image_not_supported_outlined,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfile() {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('vendors')
          .doc(_vendorUid)
          .snapshots(),
      builder: (context, snapshot) {
        final data =
            snapshot.data?.data() ?? {};

        final status =
            data['status']?.toString() ??
                _vendorStatus;

        final active =
            data['active'] == true ||
                _vendorActive;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      child: Icon(
                        Icons.storefront,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _vendorName.isEmpty
                          ? 'Vendor'
                          : _vendorName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _vendorEmail,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    if (_vendorPhone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _vendorPhone,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        _statusChip(status),
                        const SizedBox(width: 8),
                        _activeChip(active),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.verified_user_outlined,
                  ),
                ),
                title: const Text(
                  'KYC & Documents',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'PAN, Aadhaar, GST, Bank & Address Proof',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const VendorDocumentsPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.badge_outlined,
                  ),
                ),
                title: const Text('Vendor ID'),
                subtitle: Text(_vendorUid),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.check_circle_outline,
                  ),
                ),
                title:
                    const Text('Approval Status'),
                subtitle:
                    Text(status.toUpperCase()),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${_vendorName.isEmpty ? 'Vendor' : _vendorName}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your products and orders from your Vendor Panel.',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _dashboardCount(
                icon:
                    Icons.inventory_2_outlined,
                title: 'Products',
                stream: _firestore
                    .collection('Products')
                    .where(
                      'vendorUid',
                      isEqualTo: _vendorUid,
                    )
                    .snapshots(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOrderCountCard(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.add_business),
            ),
            title: const Text(
              'Add Product',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Add a new product to your store',
            ),
            trailing:
                const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _currentIndex = 1;
              });

              _showProductDialog();
            },
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(
                Icons.verified_user_outlined,
              ),
            ),
            title: const Text(
              'KYC & Documents',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Upload and track your required documents',
            ),
            trailing:
                const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const VendorDocumentsPage(),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: ListTile(
            leading: const Icon(
              Icons.verified,
              color: Colors.green,
            ),
            title: const Text(
              'Vendor Account Approved',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Status: ${_vendorStatus.toUpperCase()} • '
              'Active: ${_vendorActive ? "Yes" : "No"}',
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ORDER COUNT
  // ============================================================

  Widget _buildOrderCountCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('orders')
              .where(
                'vendorUids',
                arrayContains: _vendorUid,
              )
              .snapshots(),
          builder: (context, newSnapshot) {
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
              builder: (
                context,
                legacySnapshot,
              ) {
                final ids = <String>{};

                for (final doc
                    in newSnapshot.data?.docs ?? []) {
                  if (_orderBelongsToVendor(
                    doc.data(),
                  )) {
                    ids.add(doc.id);
                  }
                }

                for (final doc
                    in legacySnapshot.data?.docs ?? []) {
                  if (_orderBelongsToVendor(
                    doc.data(),
                  )) {
                    ids.add(doc.id);
                  }
                }

                return Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${ids.length}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Orders'),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD COUNT
  // ============================================================

  Widget _dashboardCount({
    required IconData icon,
    required String title,
    required Stream<
            QuerySnapshot<
                Map<String, dynamic>>>
        stream,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            final count =
                snapshot.data?.docs.length ?? 0;

            return Column(
              children: [
                Icon(
                  icon,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(title),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusChip(String status) {
    Color color;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;

      case 'rejected':
      case 'suspended':
        color = Colors.red;
        break;

      default:
        color = Colors.orange;
    }

    return Chip(
      avatar: Icon(
        status.toLowerCase() == 'approved'
            ? Icons.check_circle
            : Icons.info_outline,
        size: 18,
        color: color,
      ),
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _activeChip(bool active) {
    return Chip(
      avatar: Icon(
        active
            ? Icons.power
            : Icons.power_off,
        size: 18,
        color:
            active ? Colors.green : Colors.red,
      ),
      label: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color:
              active ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: required
            ? (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '$label is required';
                }

                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }

  double _number(String value) {
    return double.tryParse(
          value.trim(),
        ) ??
        0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  List<String> _splitLines(String value) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _readList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .join('\n');
    }

    return value?.toString() ?? '';
  }

  String _readImageUrls(
    Map<String, dynamic> data,
  ) {
    final urls = data['ImageUrls'];

    if (urls is List) {
      return urls
          .map((e) => e.toString())
          .join('\n');
    }

    return data['Imageurl']?.toString() ?? '';
  }

  DateTime _timestampValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = _timestampValue(value);

    if (date.millisecondsSinceEpoch == 0) {
      return '';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_accessAllowed) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Vendor access denied.',
          ),
        ),
      );
    }

    final pages = [
      _buildDashboard(),
      _buildProducts(),
      _buildOrders(),
      _buildProfile(),
    ];

    final titles = [
      'Vendor Dashboard',
      'My Products',
      'My Orders',
      'Vendor Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_currentIndex],
      floatingActionButton:
          _currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed:
                      _showProductDialog,
                  icon:
                      const Icon(Icons.add),
                  label:
                      const Text('Add Product'),
                )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon:
                Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.inventory_2_outlined,
            ),
            selectedIcon:
                Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon:
                Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
                Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
