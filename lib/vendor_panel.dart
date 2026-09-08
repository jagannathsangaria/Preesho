import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'vendor_documents_page.dart';

class VendorPanel extends StatefulWidget {
  final String? vendorUid;

  const VendorPanel({
    super.key,
    this.vendorUid,
  });

  @override
  State<VendorPanel> createState() => _VendorPanelState();
}

class _VendorPanelState extends State<VendorPanel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedIndex = 0;
  bool _loading = true;

  Map<String, dynamic> _vendorData = {};
  String _vendorName = 'Vendor';
  String _vendorStatus = 'pending_approval';
  bool _approvedByAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  String get _uid => widget.vendorUid ?? _auth.currentUser?.uid ?? '';

  Future<void> _loadVendor() async {
    if (_uid.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      DocumentSnapshot vendorSnap =
          await _firestore.collection('vendors').doc(_uid).get();

      Map<String, dynamic> data = {};

      if (vendorSnap.exists) {
        data = Map<String, dynamic>.from(
          vendorSnap.data() as Map<String, dynamic>,
        );
      } else {
        final userSnap =
            await _firestore.collection('users').doc(_uid).get();

        if (userSnap.exists) {
          data = Map<String, dynamic>.from(
            userSnap.data() as Map<String, dynamic>,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _vendorData = data;

        _vendorName = (data['businessName'] ??
                data['shopName'] ??
                data['vendorName'] ??
                data['name'] ??
                'Vendor')
            .toString();

        _vendorStatus = (data['status'] ?? 'pending_approval').toString();

        _approvedByAdmin = data['approvedByAdmin'] == true;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage(
        'Vendor information load nahi ho paayi.',
        isError: true,
      );
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } catch (e) {
      _showMessage(
        'Logout failed.',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Color _statusColor() {
    switch (_vendorStatus) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'suspended':
        return Colors.orange;
      case 'pending_documents':
        return Colors.deepOrange;
      case 'pending_approval':
      default:
        return Colors.blue;
    }
  }

  String _statusText() {
    switch (_vendorStatus) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      case 'pending_documents':
        return 'Documents Required';
      case 'pending_approval':
      default:
        return 'Under Review';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream() {
    return _firestore
        .collection('products')
        .where('vendorUid', isEqualTo: _uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return _firestore
        .collection('orders')
        .where('vendorUid', isEqualTo: _uid)
        .snapshots();
  }

  Future<void> _openDocuments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorDocumentsPage(
          vendorUid: _uid,
        ),
      ),
    );

    _loadVendor();
  }

  Future<void> _addProduct() async {
    if (!_canManageProducts) {
      _showMessage(
        'Admin approval ke baad hi products add kar sakte hain.',
        isError: true,
      );
      return;
    }

    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final mrpController = TextEditingController();
    final stockController = TextEditingController();
    final imageController = TextEditingController();
    final descriptionController = TextEditingController();

    bool active = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Product',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(
                        controller: nameController,
                        label: 'Product Name *',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: categoryController,
                        label: 'Category *',
                        icon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: priceController,
                        label: 'Selling Price *',
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: mrpController,
                        label: 'MRP',
                        icon: Icons.price_change_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: stockController,
                        label: 'Stock',
                        icon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: imageController,
                        label: 'Image URL',
                        icon: Icons.image_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: descriptionController,
                        label: 'Description',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Product Active'),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        categoryController.text.trim().isEmpty ||
                        priceController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Product name, category aur price required hai.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      final price =
                          double.tryParse(priceController.text.trim()) ?? 0;

                      final mrp =
                          double.tryParse(mrpController.text.trim()) ?? price;

                      final stock =
                          int.tryParse(stockController.text.trim()) ?? 0;

                      final productRef =
                          _firestore.collection('products').doc();

                      await productRef.set({
                        'id': productRef.id,
                        'name': nameController.text.trim(),
                        'category': categoryController.text.trim(),
                        'price': price,
                        'sellingPrice': price,
                        'mrp': mrp,
                        'originalPrice': mrp,
                        'stock': stock,
                        'imageUrl': imageController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'active': active,
                        'vendorUid': _uid,
                        'vendorId': _uid,
                        'vendorName': _vendorName,
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Product save failed: $e',
                            ),
                          ),
                        );
                      }
                    }
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
    stockController.dispose();
    imageController.dispose();
    descriptionController.dispose();

    if (result == true) {
      _showMessage('Product successfully add ho gaya.');
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: const Text(
            'Kya aap is product ko permanently delete karna chahte hain?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('products').doc(productId).delete();

      _showMessage('Product deleted.');
    } catch (e) {
      _showMessage(
        'Product delete nahi hua.',
        isError: true,
      );
    }
  }

  Future<void> _toggleProduct(
    String productId,
    bool currentValue,
  ) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'active': !currentValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage(
        currentValue
            ? 'Product inactive kar diya gaya.'
            : 'Product active kar diya gaya.',
      );
    } catch (e) {
      _showMessage(
        'Product status update failed.',
        isError: true,
      );
    }
  }

  bool get _canManageProducts {
    return _vendorStatus == 'approved' && _approvedByAdmin;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade900,
            Colors.indigo.shade700,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preesho Vendor',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadVendor,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _statusColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _vendorStatus == 'approved'
                  ? Icons.verified_rounded
                  : Icons.hourglass_top_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vendor Account',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusText(),
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_vendorStatus != 'approved')
            OutlinedButton(
              onPressed: _openDocuments,
              child: const Text('KYC'),
            ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Colors.indigo.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsStream(),
      builder: (context, productSnapshot) {
        final products = productSnapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ordersStream(),
          builder: (context, orderSnapshot) {
            final orders = orderSnapshot.data?.docs ?? [];

            double revenue = 0;
            int pendingOrders = 0;
            int deliveredOrders = 0;

            for (final doc in orders) {
              final data = doc.data();

              final totalValue = data['totalAmount'] ??
                  data['total'] ??
                  data['amount'] ??
                  0;

              if (totalValue is num) {
                revenue += totalValue.toDouble();
              } else {
                revenue +=
                    double.tryParse(totalValue.toString()) ?? 0;
              }

              final status =
                  data['status']?.toString().toLowerCase() ?? '';

              if (status == 'delivered') {
                deliveredOrders++;
              }

              if (status == 'placed' ||
                  status == 'confirmed' ||
                  status == 'processing' ||
                  status == 'packed') {
                pendingOrders++;
              }
            }

            return RefreshIndicator(
              onRefresh: _loadVendor,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _buildStatusCard(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.75,
                      children: [
                        _statCard(
                          title: 'Total Products',
                          value: products.length.toString(),
                          icon: Icons.inventory_2_outlined,
                        ),
                        _statCard(
                          title: 'Total Orders',
                          value: orders.length.toString(),
                          icon: Icons.shopping_cart_outlined,
                        ),
                        _statCard(
                          title: 'Pending Orders',
                          value: pendingOrders.toString(),
                          icon: Icons.pending_actions_outlined,
                        ),
                        _statCard(
                          title: 'Delivered',
                          value: deliveredOrders.toString(),
                          icon: Icons.local_shipping_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade700,
                          Colors.teal.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Value',
                                style: TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${revenue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Total orders value',
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
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(
                    'Quick Actions',
                    Icons.flash_on_rounded,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _quickAction(
                            icon: Icons.add_box_rounded,
                            title: 'Add Product',
                            onTap: _addProduct,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickAction(
                            icon: Icons.verified_user_rounded,
                            title: 'KYC Documents',
                            onTap: _openDocuments,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(
                    'Account Information',
                    Icons.person_outline_rounded,
                  ),
                  _accountCard(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.indigo.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: Colors.indigo.shade700,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard() {
    final email =
        _vendorData['email'] ??
            _auth.currentUser?.email ??
            'Not available';

    final phone =
        _vendorData['phone'] ??
            _vendorData['mobile'] ??
            'Not available';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.storefront_outlined,
            'Business',
            _vendorName,
          ),
          const Divider(height: 22),
          _infoRow(
            Icons.email_outlined,
            'Email',
            email.toString(),
          ),
          const Divider(height: 22),
          _infoRow(
            Icons.phone_outlined,
            'Mobile',
            phone.toString(),
          ),
          const Divider(height: 22),
          _infoRow(
            Icons.verified_outlined,
            'Admin Approval',
            _approvedByAdmin ? 'Approved' : 'Pending',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.indigo.shade600,
          size: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProducts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Products',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FloatingActionButton.small(
                  heroTag: 'add_product_fab',
                  onPressed: _addProduct,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${docs.length} products',
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              _emptyCard(
                icon: Icons.inventory_2_outlined,
                title: 'No Products Yet',
                subtitle: 'Apna pehla product add karein.',
                buttonText: 'Add Product',
                onPressed: _addProduct,
              )
            else
              ...docs.map(
                (doc) => _productCard(
                  doc.id,
                  doc.data(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _productCard(
    String id,
    Map<String, dynamic> data,
  ) {
    final name =
        (data['name'] ?? 'Unnamed Product').toString();

    final category =
        (data['category'] ?? 'General').toString();

    final imageUrl =
        (data['imageUrl'] ?? '').toString();

    final price = _numberValue(
      data['sellingPrice'] ??
          data['price'] ??
          0,
    );

    final stock =
        int.tryParse(
              (data['stock'] ?? 0).toString(),
            ) ??
            0;

    final active = data['active'] != false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 72,
              width: 72,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return _imagePlaceholder();
                      },
                    )
                  : _imagePlaceholder(),
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '₹${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Stock: $stock',
                      style: TextStyle(
                        color: stock > 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle') {
                _toggleProduct(id, active);
              } else if (value == 'delete') {
                _deleteProduct(id);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  active ? 'Deactivate' : 'Activate',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey.shade500,
        size: 30,
      ),
    );
  }

  Widget _buildOrders() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])];

        docs.sort((a, b) {
          final aTime = a.data()['createdAt'];
          final bTime = b.data()['createdAt'];

          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }

          return 0;
        });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
          children: [
            const Text(
              'Orders',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${docs.length} total orders',
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              _emptyCard(
                icon: Icons.shopping_bag_outlined,
                title: 'No Orders Yet',
                subtitle: 'Customer orders yahan dikhenge.',
              )
            else
              ...docs.map(
                (doc) => _orderCard(
                  doc.id,
                  doc.data(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _orderCard(
    String orderId,
    Map<String, dynamic> data,
  ) {
    final status =
        (data['status'] ?? 'Placed').toString();

    final paymentMethod =
        (data['paymentMethod'] ??
                data['paymentType'] ??
                '')
            .toString();

    final amount = _numberValue(
      data['totalAmount'] ??
          data['total'] ??
          data['amount'] ??
          0,
    );

    final isCOD =
        data['isCOD'] == true ||
        paymentMethod.toLowerCase().contains('cod') ||
        paymentMethod.toLowerCase().contains('cash');

    final customerName =
        (data['customerName'] ??
                data['userName'] ??
                data['name'] ??
                'Customer')
            .toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 19,
                color: Colors.black54,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.currency_rupee,
                size: 19,
                color: Colors.black54,
              ),
              const SizedBox(width: 5),
              Text(
                amount.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              if (isCOD)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'COD',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();

    Color color;

    if (lower == 'delivered') {
      color = Colors.green;
    } else if (lower == 'cancelled' ||
        lower == 'rejected') {
      color = Colors.red;
    } else if (lower == 'out for delivery') {
      color = Colors.orange;
    } else {
      color = Colors.indigo;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 55,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
          if (buttonText != null &&
              onPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ],
      ),
    );
  }

  double _numberValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return _buildProducts();
      case 2:
        return _buildOrders();
      default:
        return _buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
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
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}
