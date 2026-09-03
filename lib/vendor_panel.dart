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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedIndex = 0;

  String? _vendorUid;
  String _vendorName = 'Vendor';
  String _vendorEmail = '';
  String _vendorPhone = '';

  bool _loadingAccess = true;
  bool _accessGranted = false;

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
        if (mounted) {
          setState(() {
            _loadingAccess = false;
            _accessGranted = false;
          });
        }
        return;
      }

      final uid = user.uid;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final vendorDoc = await _firestore.collection('vendors').doc(uid).get();

      final userData = userDoc.data() ?? {};
      final vendorData = vendorDoc.data() ?? {};

      final role =
          (userData['role'] ?? userData['Role'] ?? '').toString().toLowerCase();

      final vendorStatus = (
        vendorData['status'] ??
        userData['vendorStatus'] ??
        ''
      ).toString().toLowerCase();

      final userActive = userData['active'] == true;
      final vendorActive = vendorData['active'] == true;

      final isVendor = role == 'vendor';

      final isApproved =
          vendorStatus == 'approved' &&
          (userActive || vendorActive);

      if (!isVendor || !isApproved) {
        await _auth.signOut();

        if (!mounted) return;

        setState(() {
          _loadingAccess = false;
          _accessGranted = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vendor access is not active or approval is pending.',
            ),
          ),
        );

        return;
      }

      final name = (
        vendorData['name'] ??
        vendorData['vendorName'] ??
        userData['name'] ??
        userData['Name'] ??
        user.displayName ??
        'Vendor'
      ).toString();

      final email = (
        vendorData['email'] ??
        userData['email'] ??
        user.email ??
        ''
      ).toString();

      final phone = (
        vendorData['phone'] ??
        vendorData['mobile'] ??
        userData['phone'] ??
        userData['mobile'] ??
        ''
      ).toString();

      if (!mounted) return;

      setState(() {
        _vendorUid = uid;
        _vendorName = name;
        _vendorEmail = email;
        _vendorPhone = phone;
        _accessGranted = true;
        _loadingAccess = false;
      });
    } catch (e) {
      debugPrint('Vendor access error: $e');

      if (!mounted) return;

      setState(() {
        _loadingAccess = false;
        _accessGranted = false;
      });
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  // ============================================================
  // PRODUCT MANAGEMENT
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream() {
    return _firestore
        .collection('Products')
        .where('vendorUid', isEqualTo: _vendorUid)
        .snapshots();
  }

  Future<void> _showProductDialog({
    DocumentSnapshot<Map<String, dynamic>>? existingProduct,
  }) async {
    final data = existingProduct?.data() ?? {};

    final nameController = TextEditingController(
      text: (data['Name'] ?? data['name'] ?? '').toString(),
    );

    final categoryController = TextEditingController(
      text: (data['Category'] ?? data['category'] ?? '').toString(),
    );

    final priceController = TextEditingController(
      text: (data['Price'] ?? data['price'] ?? '').toString(),
    );

    final mrpController = TextEditingController(
      text: (data['MRP'] ?? data['mrp'] ?? '').toString(),
    );

    final discountController = TextEditingController(
      text: (data['DiscountPercent'] ?? data['discountPercent'] ?? '')
          .toString(),
    );

    final stockController = TextEditingController(
      text: (data['Stock'] ?? data['stock'] ?? '').toString(),
    );

    final imageController = TextEditingController(
      text: ((data['ImageUrls'] is List && (data['ImageUrls'] as List).isNotEmpty)
              ? (data['ImageUrls'] as List).first
              : data['Imageurl'] ?? '')
          .toString(),
    );

    final descriptionController = TextEditingController(
      text: (data['Description'] ?? data['description'] ?? '').toString(),
    );

    final remarkController = TextEditingController(
      text: (data['Remark'] ?? data['remark'] ?? '').toString(),
    );

    final brandController = TextEditingController(
      text: (data['Brand'] ?? data['brand'] ?? '').toString(),
    );

    final materialController = TextEditingController(
      text: (data['Material'] ?? data['material'] ?? '').toString(),
    );

    final colorController = TextEditingController(
      text: (data['Color'] ?? data['color'] ?? '').toString(),
    );

    final sizeController = TextEditingController(
      text: (data['Size'] ?? data['size'] ?? '').toString(),
    );

    final weightController = TextEditingController(
      text: (data['Weight'] ?? data['weight'] ?? '').toString(),
    );

    final warrantyController = TextEditingController(
      text: (data['Warranty'] ?? data['warranty'] ?? '').toString(),
    );

    final highlightsController = TextEditingController(
      text: (data['Highlights'] ?? data['highlights'] ?? '').toString(),
    );

    bool active = data['Active'] == null
        ? true
        : data['Active'] == true;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existingProduct == null
                    ? 'Add Product'
                    : 'Edit Product',
              ),
              content: SizedBox(
                width: 500,
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
                          required: true,
                        ),
                        _field(
                          priceController,
                          'Price',
                          keyboardType: TextInputType.number,
                          required: true,
                        ),
                        _field(
                          mrpController,
                          'MRP',
                          keyboardType: TextInputType.number,
                        ),
                        _field(
                          discountController,
                          'Discount %',
                          keyboardType: TextInputType.number,
                        ),
                        _field(
                          stockController,
                          'Stock',
                          keyboardType: TextInputType.number,
                        ),
                        _field(
                          imageController,
                          'Image URL',
                        ),
                        _field(
                          descriptionController,
                          'Description',
                          maxLines: 3,
                        ),
                        _field(
                          remarkController,
                          'Remark',
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
                          highlightsController,
                          'Highlights',
                          maxLines: 3,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    await _saveProduct(
                      existingProduct: existingProduct,
                      name: nameController.text.trim(),
                      category: categoryController.text.trim(),
                      price: double.tryParse(priceController.text.trim()) ?? 0,
                      mrp: double.tryParse(mrpController.text.trim()) ?? 0,
                      discountPercent:
                          double.tryParse(discountController.text.trim()) ?? 0,
                      stock: int.tryParse(stockController.text.trim()) ?? 0,
                      imageUrl: imageController.text.trim(),
                      description: descriptionController.text.trim(),
                      remark: remarkController.text.trim(),
                      brand: brandController.text.trim(),
                      material: materialController.text.trim(),
                      color: colorController.text.trim(),
                      size: sizeController.text.trim(),
                      weight: weightController.text.trim(),
                      warranty: warrantyController.text.trim(),
                      highlights: highlightsController.text.trim(),
                      active: active,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(
                    existingProduct == null ? 'Add' : 'Save',
                  ),
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
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _saveProduct({
    DocumentSnapshot<Map<String, dynamic>>? existingProduct,
    required String name,
    required String category,
    required double price,
    required double mrp,
    required double discountPercent,
    required int stock,
    required String imageUrl,
    required String description,
    required String remark,
    required String brand,
    required String material,
    required String color,
    required String size,
    required String weight,
    required String warranty,
    required String highlights,
    required bool active,
  }) async {
    try {
      if (_vendorUid == null) return;

      final productRef = existingProduct == null
          ? _firestore.collection('Products').doc()
          : _firestore.collection('Products').doc(existingProduct.id);

      if (existingProduct != null) {
        final oldData = existingProduct.data() ?? {};

        final oldVendorUid =
            (oldData['vendorUid'] ?? oldData['vendorId'] ?? '').toString();

        if (oldVendorUid != _vendorUid) {
          throw Exception('You can only edit your own products.');
        }
      }

      final now = FieldValue.serverTimestamp();

      final imageUrls =
          imageUrl.isEmpty ? <String>[] : <String>[imageUrl];

      final productData = <String, dynamic>{
        'Name': name,
        'Category': category,
        'Price': price,
        'MRP': mrp,
        'DiscountPercent': discountPercent,
        'Stock': stock,
        'ImageUrls': imageUrls,
        'Imageurl': imageUrl,
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
        'UpdatedAt': now,
      };

      if (existingProduct == null) {
        productData['CreatedAt'] = now;
      }

      await productRef.set(
        productData,
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingProduct == null
                ? 'Product added successfully.'
                : 'Product updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product save failed: $e'),
        ),
      );
    }
  }

  Future<void> _deleteProduct(
    DocumentSnapshot<Map<String, dynamic>> product,
  ) async {
    try {
      final data = product.data() ?? {};

      final vendorUid =
          (data['vendorUid'] ?? data['vendorId'] ?? '').toString();

      if (vendorUid != _vendorUid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only delete your own product.'),
          ),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Product?'),
            content: const Text(
              'Are you sure you want to delete this product?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      await product.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deleted.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
        ),
      );
    }
  }

  Widget _buildProducts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading products: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final products = snapshot.data?.docs ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Products (${products.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showProductDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? const Center(
                      child: Text('No products added yet.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        16,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final data = product.data();

                        final name =
                            (data['Name'] ?? data['name'] ?? 'Product')
                                .toString();

                        final category =
                            (data['Category'] ?? data['category'] ?? '')
                                .toString();

                        final price =
                            data['Price'] ?? data['price'] ?? 0;

                        final stock =
                            data['Stock'] ?? data['stock'] ?? 0;

                        final active = data['Active'] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: _productImage(data),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$category\n₹$price • Stock: $stock',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                Icon(
                                  active
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: active
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _showProductDialog(
                                    existingProduct: product,
                                  ),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteProduct(product),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _productImage(Map<String, dynamic> data) {
    String image = '';

    final urls = data['ImageUrls'];

    if (urls is List && urls.isNotEmpty) {
      image = urls.first.toString();
    }

    if (image.isEmpty) {
      image = (
        data['Imageurl'] ??
        data['imageUrl'] ??
        data['image'] ??
        ''
      ).toString();
    }

    if (image.isEmpty) {
      return const CircleAvatar(
        child: Icon(Icons.inventory_2_outlined),
      );
    }

    return CircleAvatar(
      backgroundImage: NetworkImage(image),
    );
  }

  // ============================================================
  // ORDER HELPERS
  // ============================================================

  String _itemVendorUid(Map<String, dynamic> item) {
    return (
      item['vendorUid'] ??
      item['vendorId'] ??
      ''
    ).toString();
  }

  String _itemName(Map<String, dynamic> item) {
    return (
      item['name'] ??
      item['Name'] ??
      item['productName'] ??
      item['ProductName'] ??
      'Product'
    ).toString();
  }

  double _itemPrice(Map<String, dynamic> item) {
    final value = item['price'] ?? item['Price'] ?? 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  int _itemQuantity(Map<String, dynamic> item) {
    final value = item['quantity'] ?? item['Quantity'] ?? 1;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 1;
  }

  double _itemTotal(Map<String, dynamic> item) {
    final total =
        item['total'] ??
        item['Total'] ??
        item['itemTotal'];

    if (total is num) {
      return total.toDouble();
    }

    final parsed = double.tryParse(total?.toString() ?? '');

    if (parsed != null) {
      return parsed;
    }

    return _itemPrice(item) * _itemQuantity(item);
  }

  String _itemImage(Map<String, dynamic> item) {
    return (
      item['imageUrl'] ??
      item['Imageurl'] ??
      item['image'] ??
      item['Image'] ??
      ''
    ).toString();
  }

  List<Map<String, dynamic>> _vendorItemsFromOrder(
    Map<String, dynamic> orderData,
  ) {
    final rawItems = orderData['items'];

    if (rawItems is! List) {
      return [];
    }

    final result = <Map<String, dynamic>>[];

    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;

      final item = Map<String, dynamic>.from(rawItem);

      if (_itemVendorUid(item) == _vendorUid) {
        result.add(item);
      }
    }

    return result;
  }

  bool _orderBelongsToVendor(
    Map<String, dynamic> orderData,
  ) {
    // New multi-vendor structure:
    // vendorUid is stored inside every item.
    final vendorItems = _vendorItemsFromOrder(orderData);

    if (vendorItems.isNotEmpty) {
      return true;
    }

    // Legacy single-vendor order support.
    final orderVendorUid =
        (orderData['vendorUid'] ?? orderData['vendorId'] ?? '').toString();

    return orderVendorUid == _vendorUid;
  }

  double _vendorOrderTotal(
    Map<String, dynamic> orderData,
    List<Map<String, dynamic>> vendorItems,
  ) {
    if (vendorItems.isNotEmpty) {
      return vendorItems.fold<double>(
        0,
        (sum, item) => sum + _itemTotal(item),
      );
    }

    // Legacy order:
    final total =
        orderData['totalAmount'] ??
        orderData['total'] ??
        orderData['grandTotal'] ??
        0;

    if (total is num) {
      return total.toDouble();
    }

    return double.tryParse(total.toString()) ?? 0;
  }

  // ============================================================
  // ORDERS
  // ============================================================

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
      _loadVendorOrders() async {
    if (_vendorUid == null) return [];

    final Map<String, DocumentSnapshot<Map<String, dynamic>>> merged = {};

    try {
      final newQuery = await _firestore
          .collection('orders')
          .where(
            'vendorUids',
            arrayContains: _vendorUid,
          )
          .get();

      for (final doc in newQuery.docs) {
        merged[doc.id] = doc;
      }
    } catch (e) {
      debugPrint('New vendor order query failed: $e');
    }

    try {
      final legacyQuery = await _firestore
          .collection('orders')
          .where(
            'vendorUid',
            isEqualTo: _vendorUid,
          )
          .get();

      for (final doc in legacyQuery.docs) {
        merged[doc.id] = doc;
      }
    } catch (e) {
      debugPrint('Legacy vendor order query failed: $e');
    }

    final orders = merged.values.toList();

    orders.removeWhere(
      (order) => !_orderBelongsToVendor(order.data() ?? {}),
    );

    orders.sort((a, b) {
      final aData = a.data() ?? {};
      final bData = b.data() ?? {};

      final aDate = _dateValue(
        aData['createdAt'] ?? aData['CreatedAt'],
      );

      final bDate = _dateValue(
        bData['createdAt'] ?? bData['CreatedAt'],
      );

      return bDate.compareTo(aDate);
    });

    return orders;
  }

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildOrders() {
    return FutureBuilder<
        List<DocumentSnapshot<Map<String, dynamic>>>>(
      future: _loadVendorOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading orders: ${snapshot.error}',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final orders = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'My Orders (${orders.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders found for your products.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        16,
                      ),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(orders[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderCard(
    DocumentSnapshot<Map<String, dynamic>> order,
  ) {
    final data = order.data() ?? {};

    final vendorItems = _vendorItemsFromOrder(data);

    final isLegacyVendorOrder = vendorItems.isEmpty &&
        (
          data['vendorUid'] ??
          data['vendorId'] ??
          ''
        ).toString() == _vendorUid;

    final displayItems = vendorItems.isNotEmpty
        ? vendorItems
        : (isLegacyVendorOrder
            ? _allOrderItems(data)
            : <Map<String, dynamic>>[]);

    final orderStatus = (
      data['orderStatus'] ??
      data['status'] ??
      'Placed'
    ).toString();

    final customerName = (
      data['customerName'] ??
      data['name'] ??
      data['userName'] ??
      'Customer'
    ).toString();

    final orderDate = _dateValue(
      data['createdAt'] ?? data['CreatedAt'],
    );

    final total = _vendorOrderTotal(
      data,
      vendorItems,
    );

    final orderNumber = (
      data['orderNumber'] ??
      data['orderId'] ??
      order.id
    ).toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _statusChip(orderStatus),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customer: $customerName',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (orderDate.millisecondsSinceEpoch > 0)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'Date: ${_formatDate(orderDate)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            const Divider(height: 20),
            ...displayItems.map(
              (item) => _buildVendorOrderItem(item),
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Text(
                  'Your Order Total:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _allOrderItems(
    Map<String, dynamic> orderData,
  ) {
    final rawItems = orderData['items'];

    if (rawItems is! List) return [];

    return rawItems
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Widget _buildVendorOrderItem(
    Map<String, dynamic> item,
  ) {
    final name = _itemName(item);
    final quantity = _itemQuantity(item);
    final price = _itemPrice(item);
    final total = _itemTotal(item);
    final image = _itemImage(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _orderItemImage(image),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${price.toStringAsFixed(2)} × $quantity',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Item Total: ₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderItemImage(String image) {
    if (image.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        image,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 58,
            height: 58,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _statusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'packed':
        return Colors.purple;
      case 'shipped':
        return Colors.teal;
      case 'picked by courier':
        return Colors.cyan.shade700;
      case 'out for delivery':
        return Colors.deepOrange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year $hour:$minute $period';
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<int> _getProductCount() async {
    if (_vendorUid == null) return 0;

    final snapshot = await _firestore
        .collection('Products')
        .where('vendorUid', isEqualTo: _vendorUid)
        .get();

    return snapshot.docs.length;
  }

  Future<int> _getOrderCount() async {
    final orders = await _loadVendorOrders();
    return orders.length;
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        if (mounted) setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome, $_vendorName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vendor Dashboard',
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _dashboardCard(
                  title: 'Products',
                  icon: Icons.inventory_2_outlined,
                  future: _getProductCount(),
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dashboardCard(
                  title: 'Orders',
                  icon: Icons.shopping_bag_outlined,
                  future: _getOrderCount(),
                  onTap: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.verified_user_outlined),
              ),
              title: const Text(
                'KYC & Documents',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'View your submitted vendor documents.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (_vendorUid == null) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VendorDocumentsPage(
                      vendorUid: _vendorUid!,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.support_agent_outlined),
              ),
              title: const Text(
                'Vendor Support',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'For account or order-related support, contact admin.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required String title,
    required IconData icon,
    required Future<int> future,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              FutureBuilder<int>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    );
                  }

                  return Text(
                    '${snapshot.data ?? 0}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfile() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        const CircleAvatar(
          radius: 42,
          child: Icon(
            Icons.storefront,
            size: 42,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            _vendorName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _vendorEmail,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.store_outlined),
                title: const Text('Vendor ID'),
                subtitle: Text(_vendorUid ?? '-'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Phone'),
                subtitle: Text(
                  _vendorPhone.isEmpty ? '-' : _vendorPhone,
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                title: Text('Approval Status'),
                subtitle: Text('Approved & Active'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text(
              'KYC & Documents',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'PAN, Aadhaar, GST, Bank and Address Proof',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (_vendorUid == null) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VendorDocumentsPage(
                    vendorUid: _vendorUid!,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _currentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();

      case 1:
        return _buildProducts();

      case 2:
        return _buildOrders();

      case 3:
        return _buildProfile();

      default:
        return _buildDashboard();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_accessGranted || _vendorUid == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Vendor access is not available.\n'
              'Please contact Admin.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Panel'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _currentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
