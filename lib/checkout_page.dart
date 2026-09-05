import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'model/model.dart';
import 'orders_page.dart';
import 'cart/cart_controller.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  final TextEditingController houseController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController =
      TextEditingController(text: 'Rajasthan');
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();

  final TextEditingController giftMessageController =
      TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CustomerAddress> savedAddresses = [];
  CustomerAddress? selectedAddress;

  bool loading = true;
  bool placingOrder = false;
  bool isGiftOrder = false;

  String paymentMethod = 'COD';

  @override
  void initState() {
    super.initState();
    loadCheckoutData();
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    houseController.dispose();
    streetController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    landmarkController.dispose();
    giftMessageController.dispose();
    super.dispose();
  }

  Future<void> loadCheckoutData() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    try {
      emailController.text = user.email ?? '';

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};

        nameController.text =
            (data['name'] ?? data['displayName'] ?? '').toString();

        mobileController.text =
            (data['mobile'] ?? data['phone'] ?? '').toString();
      }

      await loadSavedAddresses();
    } catch (e) {
      debugPrint('Checkout load error: $e');
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loadSavedAddresses() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .get();

      final List<CustomerAddress> addresses = [];

      for (final doc in snapshot.docs) {
        try {
          addresses.add(
            CustomerAddress.fromMap({
              ...doc.data(),
              'addressId': doc.id,
            }),
          );
        } catch (e) {
          debugPrint('Address parse error: $e');
        }
      }

      addresses.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return 0;
      });

      if (mounted) {
        setState(() {
          savedAddresses = addresses;

          if (addresses.isNotEmpty) {
            selectedAddress = addresses.first;
            fillAddressFromModel(addresses.first);
          }
        });
      }
    } catch (e) {
      debugPrint('Address load error: $e');
    }
  }

  void fillAddressFromModel(CustomerAddress address) {
    nameController.text = address.name;
    mobileController.text = address.phone;

    houseController.text = address.house;
    streetController.text = address.street;
    cityController.text = address.city;
    stateController.text =
        address.state.isEmpty ? 'Rajasthan' : address.state;
    pincodeController.text = address.pincode;
    landmarkController.text = address.landmark;
  }

  void useNewAddress() {
    setState(() {
      selectedAddress = null;

      houseController.clear();
      streetController.clear();
      cityController.clear();
      stateController.text = 'Rajasthan';
      pincodeController.clear();
      landmarkController.clear();
    });
  }

  Future<void> saveCustomerDetails() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'name': nameController.text.trim(),
          'mobile': mobileController.text.trim(),
          'email': emailController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Customer save error: $e');
    }
  }

  Future<void> saveAddressIfNeeded() async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (selectedAddress != null) return;

    if (houseController.text.trim().isEmpty &&
        streetController.text.trim().isEmpty) {
      return;
    }

    try {
      final addressRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc();

      await addressRef.set({
        'addressId': addressRef.id,
        'name': nameController.text.trim(),
        'phone': mobileController.text.trim(),
        'house': houseController.text.trim(),
        'street': streetController.text.trim(),
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'pincode': pincodeController.text.trim(),
        'landmark': landmarkController.text.trim(),
        'isDefault': savedAddresses.isEmpty,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Address save error: $e');
    }
