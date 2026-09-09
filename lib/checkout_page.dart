import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _placingOrder = false;

  List<Map<String, dynamic>> _addresses = [];
  String? _selectedAddressId;

  String _customerName = '';
  String _customerEmail = '';
  String _customerMobile = '';

  // COD is enabled by default.
  String _paymentMethod = 'cod';

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  Future<void> _loadCheckoutData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final userSnap =
          await _firestore.collection('users').doc(user.uid).get();

      final userData = userSnap.data() ?? <String, dynamic>{};

      _customerName =
          (userData['name'] ?? user.displayName ?? '').toString().trim();

      _customerEmail =
          (userData['email'] ?? user.email ?? '').toString().trim();

      _customerMobile =
          (userData['mobile'] ?? userData['phone'] ?? '').toString().trim();

      final addressSnap = await _firestore
          .collection('addresses')
          .where('userId', isEqualTo: user.uid)
          .get();

      final loadedAddresses = addressSnap.docs.map((doc) {
        final data = doc.data();

        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Newest/default address first.
      loadedAddresses.sort((a, b) {
        final aDefault = a['isDefault'] == true;
        final bDefault = b['isDefault'] == true;

        if (aDefault && !bDefault) return -1;
        if (!aDefault && bDefault) return 1;

        return 0;
      });

      if (mounted) {
        setState(() {
          _addresses = loadedAddresses;

          if (_addresses.isNotEmpty) {
            _selectedAddressId = _addresses.first['id']?.toString();
          }

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });

        _showMessage(
          'Address load failed. Please try again.',
          isError: true,
        );
      }
    }
  }

  Map<String, dynamic>? get _selectedAddress {
    if (_selectedAddressId == null) return null;

    for (final address in _addresses) {
      if (address['id']?.toString() == _selectedAddressId) {
        return address;
      }
    }

    return null;
  }

  double get _subtotal {
    return CartController.total;
  }

  double get _originalTotal {
    return CartController.originalTotal;
  }

  double get _savings {
    final value = _originalTotal - _subtotal;
    return value > 0 ? value : 0;
  }

  // Currently delivery is free.
  double get _deliveryCharge => 0;

  double get _grandTotal {
    return _subtotal + _deliveryCharge;
  }

  String _addressText(Map<String, dynamic> address) {
    final parts = <String>[];

    final addressLine = (address['address'] ?? '').toString().trim();
    final city = (address['city'] ?? '').toString().trim();
    final state = (address['state'] ?? '').toString().trim();
    final pin = (address['pinCode'] ?? address['pincode'] ?? '')
        .toString()
        .trim();

    if (addressLine.isNotEmpty) parts.add(addressLine);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (pin.isNotEmpty) parts.add(pin);

    return parts.join(', ');
  }

  String _addressName(Map<String, dynamic> address) {
    final value = (address['name'] ?? '').toString().trim();

    if (value.isNotEmpty) return value;

    return _customerName.isNotEmpty ? _customerName : 'Customer';
  }

  String _addressMobile(Map<String, dynamic> address) {
    final value =
        (address['mobile'] ?? address['phone'] ?? '').toString().trim();

    if (value.isNotEmpty) return value;

    return _customerMobile;
  }

  Future<void> _openAddressForm() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return _NewAddressSheet(
          customerName: _customerName,
          customerMobile: _customerMobile,
        );
      },
    );

    if (result == null) return;

    await _saveNewAddress(result);
  }

  Future<void> _saveNewAddress(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login first.',
        isError: true,
      );
      return;
    }

    try {
      final ref = _firestore.collection('addresses').doc();

      final addressData = <String, dynamic>{
        'userId': user.uid,
        'name': (data['name'] ?? _customerName).toString().trim(),
        'mobile': (data['mobile'] ?? _customerMobile).toString().trim(),
        'address': (data['address'] ?? '').toString().trim(),
        'city': (data['city'] ?? '').toString().trim(),
        'state': (data['state'] ?? '').toString().trim(),
        'pinCode': (data['pinCode'] ?? '').toString().trim(),
        'isDefault': _addresses.isEmpty,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await ref.set(addressData);

      final saved = <String, dynamic>{
        'id': ref.id,
        ...addressData,
      };

      if (!mounted) return;

      setState(() {
        _addresses = [
          if (_addresses.isNotEmpty) ..._addresses,
          saved,
        ];

        _selectedAddressId = ref.id;
      });

      _showMessage('Address saved successfully.');
    } catch (e) {
      _showMessage(
        'Unable to save address.',
        isError: true,
      );
    }
  }

  Future<void> _editSelectedAddress() async {
    final selected = _selectedAddress;

    if (selected == null) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return _NewAddressSheet(
          customerName: _addressName(selected),
          customerMobile: _addressMobile(selected),
          existingAddress: selected,
        );
      },
    );

    if (result == null) return;

    await _updateAddress(
      selected['id'].toString(),
      result,
    );
  }

  Future<void> _updateAddress(
    String addressId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('addresses').doc(addressId).update({
        'name': (data['name'] ?? '').toString().trim(),
        'mobile': (data['mobile'] ?? '').toString().trim(),
        'address': (data['address'] ?? '').toString().trim(),
        'city': (data['city'] ?? '').toString().trim(),
        'state': (data['state'] ?? '').toString().trim(),
        'pinCode': (data['pinCode'] ?? '').toString().trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadCheckoutData();

      _showMessage('Address updated.');
    } catch (e) {
      _showMessage(
        'Unable to update address.',
        isError: true,
      );
    }
  }

  Future<void> _deleteSelectedAddress() async {
    final selected = _selectedAddress;

    if (selected == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Delete Address',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to delete this address?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('addresses')
          .doc(selected['id'].toString())
          .delete();

      await _loadCheckoutData();

      _showMessage('Address deleted.');
    } catch (e) {
      _showMessage(
        'Unable to delete address.',
        isError: true,
      );
    }
  }

  Future<void> _placeOrder() async {
    if (_placingOrder) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login before placing the order.',
        isError: true,
      );
      return;
    }

    if (CartController.items.isEmpty) {
      _showMessage(
        'Your cart is empty.',
        isError: true,
      );
      return;
    }

    if (_selectedAddress == null) {
      _showMessage(
        'Please select a delivery address.',
        isError: true,
      );
      return;
    }

    // Verify all cart quantities against available stock
    // before creating the order.
    for (final item in CartController.items) {
      if (item.quantity > item.availableStock) {
        _showMessage(
          '${item.name} has only ${item.availableStock} item(s) available.',
          isError: true,
        );
        return;
      }

      if (item.availableStock <= 0) {
        _showMessage(
          '${item.name} is out of stock.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _placingOrder = true;
    });

    try {
      final orderRef = _firestore.collection('orders').doc();

      final address = _selectedAddress!;

      final orderItems = CartController.items.map((item) {
        return <String, dynamic>{
          'productId': item.product.id,
          'name': item.product.name,
          'category': item.product.category,
          'price': item.numericPrice,
          'originalPrice': item.originalPrice,
          'discountPercent': item.discountPercent,
          'quantity': item.quantity,
          'total': item.totalPrice,
          'imageUrl': item.imageUrl,
        };
      }).toList();

      final orderData = <String, dynamic>{
        // Main order identifiers
        'orderId': orderRef.id,
        'customerId': user.uid,
        'userId': user.uid,

        // Customer information
        'customerName': _addressName(address),
        'customerEmail': _customerEmail,
        'customerMobile': _addressMobile(address),

        // Items
        'items': orderItems,
        'itemCount': CartController.items.length,
        'totalQuantity': CartController.items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        ),

        // Amounts
        'subtotal': _subtotal,
        'originalTotal': _originalTotal,
        'productSavings': _savings,
        'deliveryCharge': _deliveryCharge,
        'totalAmount': _grandTotal,

        // Payment
        'paymentMethod': 'COD',
        'paymentMode': 'cod',
        'paymentStatus': 'pending',

        // Order status
        'status': 'pending',
        'orderStatus': 'pending',

        // Delivery address snapshot
        'deliveryAddress': {
          'addressId': address['id']?.toString() ?? '',
          'name': _addressName(address),
          'mobile': _addressMobile(address),
          'address': (address['address'] ?? '').toString(),
          'city': (address['city'] ?? '').toString(),
          'state': (address['state'] ?? '').toString(),
          'pinCode':
              (address['pinCode'] ?? address['pincode'] ?? '').toString(),
        },

        // Courier/admin fields
        'courierId': null,
        'courierName': null,
        'assignedAt': null,

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await orderRef.set(orderData);

      // IMPORTANT:
      // CartController.clear() is the existing cart method.
      await CartController.clear();

      if (!mounted) return;

      await _showOrderSuccess(orderRef.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _placingOrder = false;
        });
      }

      _showMessage(
        'Order could not be placed. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _showOrderSuccess(String orderId) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            26,
            24,
            18,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 52,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Order Placed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Cash on Delivery order has been placed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffF4F6F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ORDER ID',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orderId,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final items = CartController.items;

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : items.isEmpty
              ? _emptyCart()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          24,
                        ),
                        children: [
                          _sectionTitle(
                            'Delivery Address',
                            Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 10),
                          _addressSection(),
                          const SizedBox(height: 18),
                          _sectionTitle(
                            'Order Summary',
                            Icons.shopping_bag_outlined,
                          ),
                          const SizedBox(height: 10),
                          _orderItems(),
                          const SizedBox(height: 18),
                          _sectionTitle(
                            'Payment Method',
                            Icons.payment_outlined,
                          ),
                          const SizedBox(height: 10),
                          _paymentSection(),
                          const SizedBox(height: 18),
                          _sectionTitle(
                            'Price Details',
                            Icons.receipt_long_outlined,
                          ),
                          const SizedBox(height: 10),
                          _priceDetails(),
                        ],
                      ),
                    ),
                    _bottomOrderBar(),
                  ],
                ),
    );
  }

  Widget _emptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add products to your cart before checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: const Color(0xff1677B9),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _addressSection() {
    if (_addresses.isEmpty) {
      return _addAddressCard();
    }

    return Column(
      children: [
        ..._addresses.map(
          (address) => _addressCard(address),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openAddressForm,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add New Address',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _addAddressCard() {
    return InkWell(
      onTap: _openAddressForm,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xffD7E8F2),
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              size: 42,
              color: Color(0xff1677B9),
            ),
            SizedBox(height: 10),
            Text(
              'Add Delivery Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add an address to continue',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> address) {
    final id = address['id']?.toString() ?? '';
    final selected = id == _selectedAddressId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? const Color(0xff1677B9)
              : const Color(0xffE1E6EA),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAddressId = id;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<String>(
                value: id,
                groupValue: _selectedAddressId,
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedAddressId = value;
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _addressName(address),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (address['isDefault'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(.10),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              'DEFAULT',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _addressMobile(address),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _addressText(address),
                      style: const TextStyle(
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _editSelectedAddress,
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 17,
                            ),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: _deleteSelectedAddress,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 17,
                            ),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderItems() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          ...CartController.items.asMap().entries.map(
            (entry) {
              final item = entry.value;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _productImage(item.imageUrl),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name.isEmpty
                                    ? 'Unnamed Product'
                                    : item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Qty: ${item.quantity}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '₹${item.numericPrice.toStringAsFixed(0)} × ${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${item.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.key != CartController.items.length - 1)
                    const Divider(height: 1),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _productImage(String url) {
    final safeUrl = url.trim();

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xffF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: safeUrl.isEmpty ||
              safeUrl.toLowerCase() == 'undefined' ||
              safeUrl.toLowerCase() == 'null'
          ? const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.black38,
            )
          : Image.network(
              safeUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.black38,
                );
              },
            ),
    );
  }

  Widget _paymentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            value: 'cod',
            groupValue: _paymentMethod,
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _paymentMethod = value;
              });
            },
            title: const Text(
              'Cash on Delivery',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text(
              'Pay when your order is delivered',
            ),
            secondary: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_atm_outlined,
                color: Colors.green,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffF1FAF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: Colors.green,
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'COD is available for this order.',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
  }

  Widget _priceDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _priceRow(
            'MRP',
            '₹${_originalTotal.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 9),
          _priceRow(
            'Product Discount',
            '- ₹${_savings.toStringAsFixed(0)}',
            valueColor: Colors.green,
          ),
          const SizedBox(height: 9),
          _priceRow(
            'Delivery',
            _deliveryCharge == 0
                ? 'FREE'
                : '₹${_deliveryCharge.toStringAsFixed(0)}',
            valueColor: Colors.green,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _priceRow(
            'Total Amount',
            '₹${_grandTotal.toStringAsFixed(0)}',
            large: true,
          ),
          if (_savings > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffF1FAF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'You save ₹${_savings.toStringAsFixed(0)} on this order',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(
    String title,
    String value, {
    Color? valueColor,
    bool large = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: large ? 17 : 14,
            fontWeight: large ? FontWeight.w900 : FontWeight.w600,
            color: large ? Colors.black : Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 20 : 14,
            fontWeight: FontWeight.w900,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _bottomOrderBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _placingOrder ? null : _placeOrder,
                  child: _placingOrder
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Place COD Order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
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
}

// ============================================================
// NEW / EDIT ADDRESS SHEET
// ============================================================

class _NewAddressSheet extends StatefulWidget {
  final String customerName;
  final String customerMobile;
  final Map<String, dynamic>? existingAddress;

  const _NewAddressSheet({
    required this.customerName,
    required this.customerMobile,
    this.existingAddress,
  });

  @override
  State<_NewAddressSheet> createState() => _NewAddressSheetState();
}

class _NewAddressSheetState extends State<_NewAddressSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pinController;

  bool _saving = false;

  bool get _isEdit => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();

    final address = widget.existingAddress;

    _nameController = TextEditingController(
      text: (address?['name'] ?? widget.customerName).toString(),
    );

    _mobileController = TextEditingController(
      text: (address?['mobile'] ??
              address?['phone'] ??
              widget.customerMobile)
          .toString(),
    );

    _addressController = TextEditingController(
      text: (address?['address'] ?? '').toString(),
    );

    _cityController = TextEditingController(
      text: (address?['city'] ?? '').toString(),
    );

    _stateController = TextEditingController(
      text: (address?['state'] ?? '').toString(),
    );

    _pinController = TextEditingController(
      text: (address?['pinCode'] ?? address?['pincode'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _save() {
    if (_saving) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final pin = _pinController.text.trim();

    if (name.isEmpty) {
      _error('Please enter name.');
      return;
    }

    if (mobile.isEmpty) {
      _error('Please enter mobile number.');
      return;
    }

    final digits = mobile.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length < 10) {
      _error('Please enter a valid mobile number.');
      return;
    }

    if (address.isEmpty) {
      _error('Please enter complete address.');
      return;
    }

    if (city.isEmpty) {
      _error('Please enter city.');
      return;
    }

    if (state.isEmpty) {
      _error('Please enter state.');
      return;
    }

    if (pin.length != 6 ||
        int.tryParse(pin) == null) {
      _error('Please enter a valid 6-digit PIN code.');
      return;
    }

    setState(() {
      _saving = true;
    });

    Navigator.pop(
      context,
      <String, dynamic>{
        'name': name,
        'mobile': mobile,
        'address': address,
        'city': city,
        'state': state,
        'pinCode': pin,
      },
    );
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xffF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xff1677B9),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        bottomInset + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isEdit
                  ? 'Edit Address'
                  : 'Add Delivery Address',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                'Full Name',
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 13,
              decoration: _decoration(
                'Mobile Number',
                Icons.phone_outlined,
              ).copyWith(
                counterText: '',
              ),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: _addressController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _decoration(
                'House / Street / Complete Address',
                Icons.home_outlined,
              ),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                'City',
                Icons.location_city_outlined,
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stateController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(
                      'State',
                      Icons.map_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _decoration(
                      'PIN Code',
                      Icons.pin_drop_outlined,
                    ).copyWith(
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit
                            ? 'Update Address'
                            : 'Save Address',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
