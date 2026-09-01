import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'main.dart';
import 'login_page.dart';
import 'models/preesho_models.dart';
import 'orders_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  // ============================================================
  // CUSTOMER DETAILS
  // ============================================================

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final pincodeController = TextEditingController();
  final emailController = TextEditingController();

  // ============================================================
  // GIFT DETAILS
  // ============================================================

  final giftNameController = TextEditingController();
  final giftMobileController = TextEditingController();
  final giftAddressController = TextEditingController();
  final giftCityController = TextEditingController();
  final giftPincodeController = TextEditingController();

  bool placingOrder = false;
  bool isGift = false;

  // ============================================================
  // ADDRESS BOOK
  // ============================================================

  List<CustomerAddress> savedAddresses = [];
  String? selectedAddressId;

  bool loadingAddresses = false;
  bool savingAddress = false;
  bool loadingUserDetails = true;

  // ============================================================
  // LOCATION
  // ============================================================

  bool gettingLocation = false;
  double? latitude;
  double? longitude;

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser =>
      FirebaseAuth.instance.currentUser;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadCurrentUser();
  }

  // ============================================================
  // LOAD CURRENT USER
  // ============================================================

  Future<void> loadCurrentUser() async {
    if (mounted) {
      setState(() {
        loadingUserDetails = true;
      });
    }

    try {
      final user = currentUser;

      if (user == null) {
        return;
      }

      // Firebase Authentication details.
      final authName =
          user.displayName?.trim() ?? '';

      final authEmail =
          user.email?.trim() ?? '';

      final authPhone =
          user.phoneNumber?.trim() ?? '';

      if (authName.isNotEmpty) {
        nameController.text = authName;
      }

      if (authEmail.isNotEmpty) {
        emailController.text = authEmail;
      }

      if (authPhone.isNotEmpty) {
        mobileController.text =
            cleanPhoneNumber(authPhone);
      }

      // Firestore details.
      await loadUserDetails(user.uid);

      // Saved address book.
      await loadAddressBook(user.uid);
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not load saved customer details.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingUserDetails = false;
        });
      }
    }
  }

  // ============================================================
  // CLEAN PHONE NUMBER
  // ============================================================

  String cleanPhoneNumber(String phone) {
    String cleaned = phone
        .replaceAll('+91', '')
        .replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );

    if (cleaned.length > 10) {
      cleaned = cleaned.substring(
        cleaned.length - 10,
      );
    }

    return cleaned;
  }

  // ============================================================
  // LOAD USER DETAILS
  // ============================================================

  Future<void> loadUserDetails(
    String uid,
  ) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

      if (!doc.exists) {
        return;
      }

      final data =
          doc.data();

      if (data == null) {
        return;
      }

      final savedName =
          data['name']?.toString().trim() ?? '';

      if (savedName.isNotEmpty) {
        nameController.text = savedName;
      }

      final savedMobile =
          data['mobile']?.toString().trim() ?? '';

      if (savedMobile.isNotEmpty) {
        mobileController.text =
            cleanPhoneNumber(savedMobile);
      }

      final savedEmail =
          data['email']?.toString().trim() ?? '';

      if (savedEmail.isNotEmpty) {
        emailController.text = savedEmail;
      }

      final savedAddress =
          data['address']?.toString().trim() ?? '';

      if (savedAddress.isNotEmpty) {
        addressController.text =
            savedAddress;
      }

      final savedCity =
          data['city']?.toString().trim() ?? '';

      if (savedCity.isNotEmpty) {
        cityController.text =
            savedCity;
      }

      final savedPincode =
          data['pincode']?.toString().trim() ?? '';

      if (savedPincode.isNotEmpty) {
        pincodeController.text =
            savedPincode;
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not read saved customer details.',
        );
      }
    }
  }

  // ============================================================
  // CREATE SAFE ADDRESS ID
  // ============================================================

  String createAddressId() {
    return 'addr_${DateTime.now().microsecondsSinceEpoch}';
  }

  // ============================================================
  // NORMALIZE ADDRESS
  // ============================================================

  CustomerAddress normalizeAddress(
    CustomerAddress address, {
    required String defaultId,
  }) {
    final id =
        address.addressId.trim().isEmpty
            ? createAddressId()
            : address.addressId.trim();

    return CustomerAddress(
      addressId: id,
      name: address.name.trim(),
      phone: cleanPhoneNumber(
        address.phone,
      ),
      house: address.house.trim(),
      street: address.street.trim(),
      city: address.city.trim(),
      state:
          address.state.trim().isEmpty
              ? 'Rajasthan'
              : address.state.trim(),
      pincode: address.pincode.trim(),
      landmark: address.landmark.trim(),
      isDefault: id == defaultId,
    );
  }

  // ============================================================
  // LOAD ADDRESS BOOK
  // ============================================================

  Future<void> loadAddressBook(
    String uid,
  ) async {
    if (mounted) {
      setState(() {
        loadingAddresses = true;
      });
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

      if (!doc.exists) {
        return;
      }

      final data =
          doc.data() ?? <String, dynamic>{};

      final parsed =
          <CustomerAddress>[];

      // ----------------------------------------------------------
      // READ NEW ADDRESS LIST
      // ----------------------------------------------------------

      final rawAddresses =
          data['addresses'];

      if (rawAddresses is List) {
        for (final item in rawAddresses) {
          if (item is Map) {
            final map =
                Map<String, dynamic>.from(item);

            CustomerAddress address =
                CustomerAddress.fromMap(map);

            // Fix old/empty address ID.
            if (address.addressId
                .trim()
                .isEmpty) {
              address = CustomerAddress(
                addressId:
                    createAddressId(),
                name: address.name,
                phone:
                    cleanPhoneNumber(
                  address.phone,
                ),
                house: address.house,
                street: address.street,
                city: address.city,
                state: address.state,
                pincode: address.pincode,
                landmark: address.landmark,
                isDefault:
                    address.isDefault,
              );
            }

            parsed.add(address);
          }
        }
      }

      // ----------------------------------------------------------
      // OLD ADDRESS FORMAT MIGRATION
      // ----------------------------------------------------------

      if (parsed.isEmpty) {
        final oldAddress =
            (data['address'] ?? '')
                .toString()
                .trim();

        final oldCity =
            (data['city'] ?? '')
                .toString()
                .trim();

        final oldPin =
            (data['pincode'] ??
                    data['pin'] ??
                    '')
                .toString()
                .trim();

        final oldName =
            (data['name'] ??
                    data['fullName'] ??
                    '')
                .toString()
                .trim();

        final oldPhone =
            (data['mobile'] ??
                    data['phone'] ??
                    '')
                .toString()
                .trim();

        final oldState =
            (data['state'] ??
                    'Rajasthan')
                .toString()
                .trim();

        if (oldAddress.isNotEmpty ||
            oldCity.isNotEmpty ||
            oldPin.isNotEmpty) {
          parsed.add(
            CustomerAddress(
              addressId:
                  createAddressId(),
              name:
                  oldName.isNotEmpty
                      ? oldName
                      : nameController.text
                          .trim(),
              phone:
                  oldPhone.isNotEmpty
                      ? cleanPhoneNumber(
                          oldPhone,
                        )
                      : mobileController
                          .text
                          .trim(),
              street: oldAddress,
              city: oldCity,
              state:
                  oldState.isNotEmpty
                      ? oldState
                      : 'Rajasthan',
              pincode: oldPin,
              isDefault: true,
            ),
          );
        }
      }

      if (parsed.isEmpty) {
        if (mounted) {
          setState(() {
            savedAddresses = [];
            selectedAddressId = null;
          });
        }
        return;
      }

      // ----------------------------------------------------------
      // FIND DEFAULT
      // ----------------------------------------------------------

      final storedDefaultId =
          (data['defaultAddressId'] ?? '')
              .toString()
              .trim();

      String defaultId = '';

      if (storedDefaultId.isNotEmpty &&
          parsed.any(
            (a) =>
                a.addressId ==
                storedDefaultId,
          )) {
        defaultId = storedDefaultId;
      } else {
        final marked =
            parsed.where(
              (a) => a.isDefault,
            );

        if (marked.isNotEmpty) {
          defaultId =
              marked.first.addressId;
        } else {
          defaultId =
              parsed.first.addressId;
        }
      }

      // ----------------------------------------------------------
      // NORMALIZE ALL ADDRESSES
      // ----------------------------------------------------------

      final normalized =
          parsed.map((address) {
        return normalizeAddress(
          address,
          defaultId: defaultId,
        );
      }).toList();

      final actualDefaultId =
          normalized.firstWhere(
        (a) => a.isDefault,
        orElse: () =>
            normalized.first,
      ).addressId;

      if (mounted) {
        setState(() {
          savedAddresses = normalized;
          selectedAddressId =
              actualDefaultId;
        });
      }

      // ----------------------------------------------------------
      // AUTOMATICALLY REPAIR FIRESTORE
      // ----------------------------------------------------------

      await _saveAddressBook(
        uid,
        normalized,
        actualDefaultId,
      );

      // ----------------------------------------------------------
      // APPLY DEFAULT ADDRESS TO FORM
      // ----------------------------------------------------------

      final defaultAddress =
          normalized.firstWhere(
        (a) =>
            a.addressId ==
            actualDefaultId,
        orElse: () =>
            normalized.first,
      );

      _applyAddressToForm(
        defaultAddress,
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not load saved addresses.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingAddresses = false;
        });
      }
    }
  }

  // ============================================================
  // APPLY ADDRESS TO FORM
  // ============================================================

  void _applyAddressToForm(
    CustomerAddress address,
  ) {
    nameController.text =
        address.name;

    mobileController.text =
        cleanPhoneNumber(
      address.phone,
    );

    addressController.text =
        address.fullAddress;

    cityController.text =
        address.city;

    pincodeController.text =
        address.pincode;
  }

  // ============================================================
  // ADDRESS FROM FORM
  // ============================================================

  CustomerAddress _addressFromForm({
    required String addressId,
    required bool isDefault,
  }) {
    return CustomerAddress(
      addressId:
          addressId.trim().isEmpty
              ? createAddressId()
              : addressId.trim(),
      name:
          nameController.text.trim(),
      phone:
          cleanPhoneNumber(
        mobileController.text.trim(),
      ),
      street:
          addressController.text.trim(),
      city:
          cityController.text.trim(),
      state: 'Rajasthan',
      pincode:
          pincodeController.text.trim(),
      isDefault: isDefault,
    );
  }

  // ============================================================
  // SAVE ADDRESS BOOK
  // ============================================================

  Future<void> _saveAddressBook(
    String uid,
    List<CustomerAddress> addresses,
    String defaultId,
  ) async {
    final normalized =
        addresses.map((address) {
      return CustomerAddress(
        addressId:
            address.addressId.trim().isEmpty
                ? createAddressId()
                : address.addressId.trim(),
        name:
            address.name.trim(),
        phone:
            cleanPhoneNumber(
          address.phone,
        ),
        house:
            address.house.trim(),
        street:
            address.street.trim(),
        city:
            address.city.trim(),
        state:
            address.state.trim().isEmpty
                ? 'Rajasthan'
                : address.state.trim(),
        pincode:
            address.pincode.trim(),
        landmark:
            address.landmark.trim(),
        isDefault:
            address.addressId ==
                defaultId,
      );
    }).toList();

    // Make sure exactly one address is default.
    String finalDefaultId =
        defaultId.trim();

    if (finalDefaultId.isEmpty ||
        !normalized.any(
          (a) =>
              a.addressId ==
              finalDefaultId,
        )) {
      finalDefaultId =
          normalized.isNotEmpty
              ? normalized.first.addressId
              : '';
    }

    final finalAddresses =
        normalized.map((address) {
      return CustomerAddress(
        addressId:
            address.addressId,
        name: address.name,
        phone: address.phone,
        house: address.house,
        street: address.street,
        city: address.city,
        state: address.state,
        pincode: address.pincode,
        landmark: address.landmark,
        isDefault:
            address.addressId ==
                finalDefaultId,
      );
    }).toList();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(
      {
        'addresses':
            finalAddresses
                .map(
                  (address) =>
                      address.toMap(),
                )
                .toList(),
        'defaultAddressId':
            finalDefaultId,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ============================================================
  // SELECT ADDRESS
  // ============================================================

  Future<void> selectAddress(
    CustomerAddress address,
  ) async {
    final user = currentUser;

    if (user == null) {
      await goToLogin();
      return;
    }

    try {
      final normalized =
          savedAddresses.map((a) {
        return CustomerAddress(
          addressId:
              a.addressId,
          name: a.name,
          phone: a.phone,
          house: a.house,
          street: a.street,
          city: a.city,
          state: a.state,
          pincode: a.pincode,
          landmark: a.landmark,
          isDefault:
              a.addressId ==
                  address.addressId,
        );
      }).toList();

      await _saveAddressBook(
        user.uid,
        normalized,
        address.addressId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        savedAddresses =
            normalized;
        selectedAddressId =
            address.addressId;
      });

      _applyAddressToForm(
        normalized.firstWhere(
          (a) =>
              a.addressId ==
              address.addressId,
        ),
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not select address.',
        );
      }
    }
  }

  // ============================================================
  // ADD / EDIT ADDRESS
  // ============================================================

  Future<void> openAddressEditor({
    CustomerAddress? existing,
  }) async {
    final result =
        await showDialog<CustomerAddress>(
      context: context,
      builder: (_) =>
          _AddressEditorDialog(
        existing: existing,
        defaultName:
            nameController.text.trim(),
        defaultPhone:
            mobileController.text.trim(),
      ),
    );

    if (result == null ||
        !mounted) {
      return;
    }

    final user = currentUser;

    if (user == null) {
      await goToLogin();
      return;
    }

    setState(() {
      savingAddress = true;
    });

    try {
      final resultId =
          result.addressId.trim().isEmpty
              ? createAddressId()
              : result.addressId.trim();

      final cleanedResult =
          CustomerAddress(
        addressId: resultId,
        name: result.name.trim(),
        phone:
            cleanPhoneNumber(
          result.phone,
        ),
        house: result.house.trim(),
        street:
            result.street.trim(),
        city: result.city.trim(),
        state:
            result.state.trim().isEmpty
                ? 'Rajasthan'
                : result.state.trim(),
        pincode:
            result.pincode.trim(),
        landmark:
            result.landmark.trim(),
        isDefault:
            result.isDefault,
      );

      final list =
          [...savedAddresses];

      final index =
          list.indexWhere(
        (a) =>
            a.addressId ==
            resultId,
      );

      if (index >= 0) {
        list[index] =
            cleanedResult;
      } else {
        list.add(
          cleanedResult,
        );
      }

      // ----------------------------------------------------------
      // DEFAULT ADDRESS DECISION
      // ----------------------------------------------------------

      String defaultId;

      if (cleanedResult.isDefault) {
        defaultId =
            resultId;
      } else if (selectedAddressId !=
              null &&
          list.any(
            (a) =>
                a.addressId ==
                selectedAddressId,
          )) {
        defaultId =
            selectedAddressId!;
      } else {
        defaultId =
            list.first.addressId;
      }

      await _saveAddressBook(
        user.uid,
        list,
        defaultId,
      );

      // ----------------------------------------------------------
      // NORMALIZE LOCAL LIST
      // ----------------------------------------------------------

      final normalized =
          list.map((a) {
        return CustomerAddress(
          addressId:
              a.addressId,
          name: a.name,
          phone: a.phone,
          house: a.house,
          street: a.street,
          city: a.city,
          state: a.state,
          pincode: a.pincode,
          landmark: a.landmark,
          isDefault:
              a.addressId ==
                  defaultId,
        );
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        savedAddresses =
            normalized;
        selectedAddressId =
            defaultId;
      });

      _applyAddressToForm(
        normalized.firstWhere(
          (a) =>
              a.addressId ==
              defaultId,
        ),
      );

      showMessage(
        existing == null
            ? 'Address added successfully.'
            : 'Address updated successfully.',
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not save address.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          savingAddress = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE ADDRESS
  // ============================================================

  Future<void> deleteAddress(
    CustomerAddress address,
  ) async {
    if (savedAddresses.length <= 1) {
      showMessage(
        'At least one saved address is required.',
      );
      return;
    }

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Delete address?',
          ),
          content:
              const Text(
            'This saved address will be removed from your account.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final user = currentUser;

    if (user == null) {
      return;
    }

    try {
      final list =
          savedAddresses
              .where(
                (a) =>
                    a.addressId !=
                    address.addressId,
              )
              .toList();

      if (list.isEmpty) {
        showMessage(
          'At least one saved address is required.',
        );
        return;
      }

      String defaultId;

      if (address.addressId ==
          selectedAddressId) {
        defaultId =
            list.first.addressId;
      } else {
        defaultId =
            list
                .firstWhere(
                  (a) =>
                      a.isDefault,
                  orElse: () =>
                      list.first,
                )
                .addressId;
      }

      await _saveAddressBook(
        user.uid,
        list,
        defaultId,
      );

      final normalized =
          list.map((a) {
        return CustomerAddress(
          addressId:
              a.addressId,
          name: a.name,
          phone: a.phone,
          house: a.house,
          street: a.street,
          city: a.city,
          state: a.state,
          pincode: a.pincode,
          landmark: a.landmark,
          isDefault:
              a.addressId ==
                  defaultId,
        );
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        savedAddresses =
            normalized;
        selectedAddressId =
            defaultId;
      });

      _applyAddressToForm(
        normalized.firstWhere(
          (a) =>
              a.addressId ==
              defaultId,
        ),
      );

      showMessage(
        'Address deleted.',
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not delete address.',
        );
      }
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> goToLogin() async {
    final result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginPage(),
      ),
    );

    if (result == true) {
      await loadCurrentUser();
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> getCurrentLocation() async {
    if (gettingLocation) {
      return;
    }

    setState(() {
      gettingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage(
          'Location service is turned off.',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator
              .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        showMessage(
          'Location permission denied.',
        );
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        showMessage(
          'Location permission permanently denied.',
        );
        return;
      }

      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        latitude =
            position.latitude;
        longitude =
            position.longitude;
      });

      showMessage(
        'Location captured successfully.',
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not get location.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          gettingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE CUSTOMER DETAILS
  // ============================================================

  Future<void> saveCustomerDetails(
    String uid,
  ) async {
    final firestore =
        FirebaseFirestore.instance;

    final customerData =
        <String, dynamic>{
      'uid': uid,
      'name':
          nameController.text.trim(),
      'mobile':
          cleanPhoneNumber(
        mobileController.text.trim(),
      ),
      'email':
          emailController.text.trim(),
      'address':
          addressController.text.trim(),
      'city':
          cityController.text.trim(),
      'pincode':
          pincodeController.text.trim(),
      'updatedAt':
          FieldValue.serverTimestamp(),
    };

    await firestore
        .collection('users')
        .doc(uid)
        .set(
      customerData,
      SetOptions(merge: true),
    );

    // ----------------------------------------------------------
    // SAVE CURRENT ADDRESS
    // ----------------------------------------------------------

    final addressId =
        selectedAddressId != null &&
                selectedAddressId!
                    .trim()
                    .isNotEmpty
            ? selectedAddressId!
            : createAddressId();

    final current =
        _addressFromForm(
      addressId: addressId,
      isDefault:
          savedAddresses.isEmpty,
    );

    final list =
        [...savedAddresses];

    final index =
        list.indexWhere(
      (a) =>
          a.addressId ==
          current.addressId,
    );

    if (index >= 0) {
      list[index] = current;
    } else {
      list.add(current);
    }

    final defaultId =
        selectedAddressId != null &&
                list.any(
                  (a) =>
                      a.addressId ==
                      selectedAddressId,
                )
            ? selectedAddressId!
            : list.first.addressId;

    await _saveAddressBook(
      uid,
      list,
      defaultId,
    );

    final normalized =
        list.map((a) {
      return CustomerAddress(
        addressId:
            a.addressId,
        name: a.name,
        phone: a.phone,
        house: a.house,
        street: a.street,
        city: a.city,
        state: a.state,
        pincode: a.pincode,
        landmark: a.landmark,
        isDefault:
            a.addressId ==
                defaultId,
      );
    }).toList();

    if (mounted) {
      setState(() {
        savedAddresses =
            normalized;
        selectedAddressId =
            defaultId;
      });
    }
  }

  // ============================================================
  // VALIDATE ADDRESS
  // ============================================================

  bool validateAddress() {
    final name =
        nameController.text.trim();

    final mobile =
        cleanPhoneNumber(
      mobileController.text.trim(),
    );

    final address =
        addressController.text.trim();

    final city =
        cityController.text.trim();

    final pincode =
        pincodeController.text.trim();

    if (name.length < 2) {
      showMessage(
        'Please enter your full name.',
      );
      return false;
    }

    if (!RegExp(r'^\d{10}$')
        .hasMatch(mobile)) {
      showMessage(
        'Please enter a valid 10-digit mobile number.',
      );
      return false;
    }

    if (address.length < 3) {
      showMessage(
        'Please enter your complete address.',
      );
      return false;
    }

    if (city.isEmpty) {
      showMessage(
        'Please enter your city.',
      );
      return false;
    }

    if (!RegExp(r'^\d{6}$')
        .hasMatch(pincode)) {
      showMessage(
        'Please enter a valid 6-digit PIN code.',
      );
      return false;
    }

    // ----------------------------------------------------------
    // GIFT VALIDATION
    // ----------------------------------------------------------

    if (isGift) {
      if (giftNameController
              .text
              .trim()
              .length <
          2) {
        showMessage(
          'Please enter gift receiver name.',
        );
        return false;
      }

      final giftMobile =
          cleanPhoneNumber(
        giftMobileController
            .text
            .trim(),
      );

      if (!RegExp(r'^\d{10}$')
          .hasMatch(giftMobile)) {
        showMessage(
          'Please enter a valid gift receiver mobile number.',
        );
        return false;
      }

      if (giftAddressController
              .text
              .trim()
              .length <
          3) {
        showMessage(
          'Please enter gift delivery address.',
        );
        return false;
      }

      if (giftCityController
          .text
          .trim()
          .isEmpty) {
        showMessage(
          'Please enter gift city.',
        );
        return false;
      }

      if (!RegExp(r'^\d{6}$').hasMatch(
        giftPincodeController
            .text
            .trim(),
      )) {
        showMessage(
          'Please enter a valid gift PIN code.',
        );
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  Future<void> placeOrder() async {
    final user = currentUser;

    if (user == null) {
      await goToLogin();
      return;
    }

    if (placingOrder) {
      return;
    }

    if (!validateAddress()) {
      return;
    }

    final cartItems =
        CartController.items;

    if (cartItems.isEmpty) {
      showMessage(
        'Your cart is empty.',
      );
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      // --------------------------------------------------------
      // SAVE CUSTOMER + ADDRESS
      // --------------------------------------------------------

      await saveCustomerDetails(
        user.uid,
      );

      CustomerAddress selectedAddress;

      if (selectedAddressId !=
              null &&
          savedAddresses.any(
            (a) =>
                a.addressId ==
                selectedAddressId,
          )) {
        selectedAddress =
            savedAddresses.firstWhere(
          (a) =>
              a.addressId ==
              selectedAddressId,
        );
      } else {
        selectedAddress =
            _addressFromForm(
          addressId:
              createAddressId(),
          isDefault: true,
        );
      }

      // --------------------------------------------------------
      // CREATE ORDER ITEMS
      // --------------------------------------------------------

      double total = 0;

      final items =
          cartItems.map((cartItem) {
        final quantity =
            cartItem.quantity;

        final price =
            cartItem.numericPrice;

        final itemTotal =
            price * quantity;

        total += itemTotal;

        return {
          'productId':
              cartItem.product.id,
          'name':
              cartItem.product.name,
          'category':
              cartItem.product.category,
          'price':
              price,
          'quantity':
              quantity,
          'total':
              itemTotal,
          'imageUrl':
              cartItem.product.imageUrl,
        };
      }).toList();

      // --------------------------------------------------------
      // CREATE ORDER
      // --------------------------------------------------------

      final orderRef =
          FirebaseFirestore.instance
              .collection('orders')
              .doc();

      final orderData =
          <String, dynamic>{
        'orderId':
            orderRef.id,

        'userId':
            user.uid,

        'customerName':
            nameController.text
                .trim(),

        'customerMobile':
            cleanPhoneNumber(
          mobileController.text
              .trim(),
        ),

        'customerEmail':
            emailController.text
                .trim(),

        // Complete address snapshot.
        'deliveryAddress':
            selectedAddress.toMap(),

        // Compatibility fields.
        'address':
            selectedAddress.fullAddress,

        'city':
            selectedAddress.city,

        'state':
            selectedAddress.state,

        'pincode':
            selectedAddress.pincode,

        'items':
            items,

        'totalAmount':
            total,

        'paymentMethod':
            'COD',

        'paymentStatus':
            'Pending',

        'orderStatus':
            'Confirmed',

        'cancelled':
            false,

        'cancellationReason':
            null,

        'cancelledAt':
            null,

        'latitude':
            latitude,

        'longitude':
            longitude,

        'isGift':
            isGift,

        'giftDetails':
            isGift
                ? {
                    'name':
                        giftNameController
                            .text
                            .trim(),
                    'mobile':
                        cleanPhoneNumber(
                      giftMobileController
                          .text
                          .trim(),
                    ),
                    'address':
                        giftAddressController
                            .text
                            .trim(),
                    'city':
                        giftCityController
                            .text
                            .trim(),
                    'pincode':
                        giftPincodeController
                            .text
                            .trim(),
                  }
                : null,

        'createdAt':
            FieldValue
                .serverTimestamp(),

        'updatedAt':
            FieldValue
                .serverTimestamp(),
      };

      await orderRef.set(
        orderData,
      );

      // --------------------------------------------------------
      // CLEAR CART
      // --------------------------------------------------------

      CartController.clear();

      if (!mounted) {
        return;
      }

      showMessage(
        'Order placed successfully.',
      );

      // --------------------------------------------------------
      // ORDERS PAGE
      // --------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const OrdersPage(),
        ),
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not place order. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          placingOrder = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================

  Widget addressCard(
    CustomerAddress address,
  ) {
    final selected =
        address.addressId ==
            selectedAddressId;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      elevation:
          selected ? 3 : 1,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? Theme.of(context)
                  .colorScheme
                  .primary
              : Colors.transparent,
          width:
              selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(14),
        onTap: () =>
            selectAddress(address),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons
                            .radio_button_checked
                        : Icons
                            .radio_button_off,
                    color: selected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                        : Colors.grey,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Text(
                      address.name,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (address.isDefault)
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                        color:
                            Theme.of(
                          context,
                        )
                                .colorScheme
                                .primary
                                .withValues(
                          alpha: .1,
                        ),
                      ),
                      child:
                          const Text(
                        'DEFAULT',
                        style:
                            TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                address.fullAddress,
                style:
                    const TextStyle(
                  height: 1.4,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                '📞 ${address.phone}',
                style:
                    const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        openAddressEditor(
                      existing:
                          address,
                    ),
                    icon:
                        const Icon(
                      Icons
                          .edit_outlined,
                      size: 18,
                    ),
                    label:
                        const Text(
                      'Edit',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        deleteAddress(
                      address,
                    ),
                    icon:
                        const Icon(
                      Icons
                          .delete_outline,
                      size: 18,
                    ),
                    label:
                        const Text(
                      'Delete',
                    ),
                  ),
                ],
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
    final user = currentUser;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Checkout',
        ),
        centerTitle: true,
      ),
      body:
          loadingUserDetails
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : Form(
                  key: _formKey,
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets
                            .all(16),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        if (user == null)
                          Card(
                            child:
                                Padding(
                              padding:
                                  const EdgeInsets
                                      .all(14),
                              child:
                                  Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .account_circle_outlined,
                                    size: 36,
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  const Expanded(
                                    child:
                                        Text(
                                      'Please login to continue with your order.',
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        goToLogin,
                                    child:
                                        const Text(
                                      'Login',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (user == null)
                          const SizedBox(
                            height: 16,
                          ),

                        // ==================================================
                        // SAVED ADDRESSES
                        // ==================================================

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                              'Delivery Address',
                              style:
                                  TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  user == null
                                      ? goToLogin
                                      : savingAddress
                                          ? null
                                          : () =>
                                              openAddressEditor(),
                              icon:
                                  const Icon(
                                Icons.add,
                              ),
                              label:
                                  const Text(
                                'Add New',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        if (loadingAddresses)
                          const Padding(
                            padding:
                                EdgeInsets.all(
                              20,
                            ),
                            child:
                                Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          ),

                        if (!loadingAddresses &&
                            savedAddresses
                                .isNotEmpty)
                          ...savedAddresses.map(
                            addressCard,
                          ),

                        if (!loadingAddresses &&
                            savedAddresses
                                .isEmpty)
                          Card(
                            child:
                                Padding(
                              padding:
                                  const EdgeInsets
                                      .all(16),
                              child:
                                  Column(
                                children: [
                                  const Icon(
                                    Icons
                                        .location_on_outlined,
                                    size: 42,
                                  ),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  const Text(
                                    'No saved address',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  const Text(
                                    'Add your delivery address to continue.',
                                    textAlign:
                                        TextAlign
                                            .center,
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  FilledButton
                                      .icon(
                                    onPressed:
                                        user == null
                                            ? goToLogin
                                            : () =>
                                                openAddressEditor(),
                                    icon:
                                        const Icon(
                                      Icons.add,
                                    ),
                                    label:
                                        const Text(
                                      'Add Address',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(
                          height: 18,
                        ),

                        // ==================================================
                        // SELECTED ADDRESS
                        // ==================================================

                        const Text(
                          'Selected Address Details',
                          style:
                              TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        TextFormField(
                          controller:
                              nameController,
                          textCapitalization:
                              TextCapitalization
                                  .words,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Full Name',
                            prefixIcon:
                                Icon(
                              Icons
                                  .person_outline,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextFormField(
                          controller:
                              mobileController,
                          keyboardType:
                              TextInputType
                                  .phone,
                          maxLength:
                              10,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Mobile Number',
                            prefixIcon:
                                Icon(
                              Icons
                                  .phone_outlined,
                            ),
                            border:
                                OutlineInputBorder(),
                            counterText:
                                '',
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextFormField(
                          controller:
                              emailController,
                          keyboardType:
                              TextInputType
                                  .emailAddress,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Email',
                            prefixIcon:
                                Icon(
                              Icons
                                  .email_outlined,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextFormField(
                          controller:
                              addressController,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Complete Address',
                            hintText:
                                'House no., street, area',
                            prefixIcon:
                                Icon(
                              Icons
                                  .home_outlined,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextFormField(
                          controller:
                              cityController,
                          textCapitalization:
                              TextCapitalization
                                  .words,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'City',
                            prefixIcon:
                                Icon(
                              Icons
                                  .location_city_outlined,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextFormField(
                          controller:
                              pincodeController,
                          keyboardType:
                              TextInputType
                                  .number,
                          maxLength:
                              6,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'PIN Code',
                            prefixIcon:
                                Icon(
                              Icons
                                  .pin_drop_outlined,
                            ),
                            border:
                                OutlineInputBorder(),
                            counterText:
                                '',
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        // ==================================================
                        // LOCATION
                        // ==================================================

                        OutlinedButton
                            .icon(
                          onPressed:
                              gettingLocation
                                  ? null
                                  : getCurrentLocation,
                          icon:
                              gettingLocation
                                  ? const SizedBox(
                                      width:
                                          18,
                                      height:
                                          18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .my_location,
                                    ),
                          label:
                              Text(
                            gettingLocation
                                ? 'Getting Location...'
                                : latitude !=
                                        null
                                    ? 'Location Captured'
                                    : 'Use Current Location',
                          ),
                        ),

                        const SizedBox(
                          height: 24,
                        ),

                        // ==================================================
                        // GIFT
                        // ==================================================

                        Card(
                          child:
                              Column(
                            children: [
                              SwitchListTile(
                                value:
                                    isGift,
                                onChanged:
                                    (value) {
                                  setState(() {
                                    isGift =
                                        value;
                                  });
                                },
                                title:
                                    const Text(
                                  'This is a gift',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                subtitle:
                                    const Text(
                                  'Deliver to a different person',
                                ),
                              ),
                              if (isGift)
                                Padding(
                                  padding:
                                      const EdgeInsets
                                          .fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child:
                                      Column(
                                    children: [
                                      TextField(
                                        controller:
                                            giftNameController,
                                        decoration:
                                            const InputDecoration(
                                          labelText:
                                              'Gift Receiver Name',
                                        ),
                                      ),
                                      TextField(
                                        controller:
                                            giftMobileController,
                                        keyboardType:
                                            TextInputType
                                                .phone,
                                        maxLength:
                                            10,
                                        decoration:
                                            const InputDecoration(
                                          labelText:
                                              'Gift Receiver Mobile',
                                          counterText:
                                              '',
                                        ),
                                      ),
                                      TextField(
                                        controller:
                                            giftAddressController,
                                        maxLines:
                                            2,
                                        decoration:
                                            const InputDecoration(
                                          labelText:
                                              'Gift Delivery Address',
                                        ),
                                      ),
                                      TextField(
                                        controller:
                                            giftCityController,
                                        decoration:
                                            const InputDecoration(
                                          labelText:
                                              'Gift City',
                                        ),
                                      ),
                                      TextField(
                                        controller:
                                            giftPincodeController,
                                        keyboardType:
                                            TextInputType
                                                .number,
                                        maxLength:
                                            6,
                                        decoration:
                                            const InputDecoration(
                                          labelText:
                                              'Gift PIN Code',
                                          counterText:
                                              '',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        // ==================================================
                        // PAYMENT
                        // ==================================================

                        const Text(
                          'Payment Method',
                          style:
                              TextStyle(
                            fontSize: 21,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Card(
                          child:
                              RadioListTile<
                                  String>(
                            value:
                                'COD',
                            groupValue:
                                'COD',
                            onChanged:
                                null,
                            title:
                                const Text(
                              'Cash on Delivery',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            subtitle:
                                const Text(
                              'Pay when your order is delivered',
                            ),
                            secondary:
                                const Icon(
                              Icons
                                  .payments_outlined,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        // ==================================================
                        // ORDER SUMMARY
                        // ==================================================

                        const Text(
                          'Order Summary',
                          style:
                              TextStyle(
                            fontSize: 21,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Card(
                          child:
                              Padding(
                            padding:
                                const EdgeInsets
                                    .all(16),
                            child:
                                Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    const Text(
                                      'Items',
                                    ),
                                    Text(
                                      '${CartController.items.length}',
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                const Divider(
                                  height:
                                      28,
                                ),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    const Text(
                                      'Payment',
                                    ),
                                    const Text(
                                      'Cash on Delivery',
                                      style:
                                          TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                const Divider(
                                  height:
                                      28,
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
                                      '₹${CartController.total.toStringAsFixed(0)}',
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            20,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        // ==================================================
                        // PLACE ORDER
                        // ==================================================

                        SizedBox(
                          width:
                              double.infinity,
                          height: 55,
                          child:
                              FilledButton
                                  .icon(
                            onPressed:
                                placingOrder ||
                                        loadingUserDetails
                                    ? null
                                    : placeOrder,
                            icon:
                                placingOrder
                                    ? const SizedBox(
                                        width:
                                            22,
                                        height:
                                            22,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : Icon(
                                        user == null
                                            ? Icons
                                                .login
                                            : Icons
                                                .shopping_bag_outlined,
                                      ),
                            label:
                                Text(
                              placingOrder
                                  ? 'Placing Order...'
                                  : user == null
                                      ? 'Login to Place Order'
                                      : 'Place Order',
                              style:
                                  const TextStyle(
                                fontSize:
                                    17,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 30,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    addressController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    emailController.dispose();

    giftNameController.dispose();
    giftMobileController.dispose();
    giftAddressController.dispose();
    giftCityController.dispose();
    giftPincodeController.dispose();

    super.dispose();
  }
}

// =================================================================
// ADDRESS EDITOR DIALOG
// =================================================================

class _AddressEditorDialog
    extends StatefulWidget {
  final CustomerAddress? existing;
  final String defaultName;
  final String defaultPhone;

  const _AddressEditorDialog({
    this.existing,
    required this.defaultName,
    required this.defaultPhone,
  });

  @override
  State<_AddressEditorDialog>
      createState() =>
          _AddressEditorDialogState();
}

class _AddressEditorDialogState
    extends State<_AddressEditorDialog> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController house;
  late final TextEditingController street;
  late final TextEditingController city;
  late final TextEditingController state;
  late final TextEditingController pin;
  late final TextEditingController landmark;

  bool isDefault = false;

  @override
  void initState() {
    super.initState();

    final a = widget.existing;

    name =
        TextEditingController(
      text:
          a?.name ??
              widget.defaultName,
    );

    phone =
        TextEditingController(
      text:
          a?.phone ??
              widget.defaultPhone,
    );

    house =
        TextEditingController(
      text: a?.house ?? '',
    );

    street =
        TextEditingController(
      text: a?.street ?? '',
    );

    city =
        TextEditingController(
      text: a?.city ?? '',
    );

    state =
        TextEditingController(
      text:
          a != null &&
                  a.state.isNotEmpty
              ? a.state
              : 'Rajasthan',
    );

    pin =
        TextEditingController(
      text:
          a?.pincode ?? '',
    );

    landmark =
        TextEditingController(
      text:
          a?.landmark ?? '',
    );

    isDefault =
        a?.isDefault ?? false;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    house.dispose();
    street.dispose();
    city.dispose();
    state.dispose();
    pin.dispose();
    landmark.dispose();

    super.dispose();
  }

  String cleanPhone(
    String value,
  ) {
    String result =
        value.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (result.startsWith('91') &&
        result.length == 12) {
      result =
          result.substring(2);
    }

    if (result.length > 10) {
      result =
          result.substring(
        result.length - 10,
      );
    }

    return result;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          Text(
        widget.existing == null
            ? 'Add New Address'
            : 'Edit Address',
      ),
      content:
          SizedBox(
        width:
            double.maxFinite,
        child:
            SingleChildScrollView(
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    name,
                textCapitalization:
                    TextCapitalization
                        .words,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Full Name',
                  prefixIcon:
                      Icon(
                    Icons
                        .person_outline,
                  ),
                ),
              ),

              TextField(
                controller:
                    phone,
                keyboardType:
                    TextInputType
                        .phone,
                maxLength:
                    10,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Mobile Number',
                  prefixIcon:
                      Icon(
                    Icons
                        .phone_outlined,
                  ),
                  counterText:
                      '',
                ),
              ),

              TextField(
                controller:
                    house,
                decoration:
                    const InputDecoration(
                  labelText:
                      'House / Flat No.',
                  prefixIcon:
                      Icon(
                    Icons
                        .home_outlined,
                  ),
                ),
              ),

              TextField(
                controller:
                    street,
                maxLines: 2,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Street / Area / Address',
                  prefixIcon:
                      Icon(
                    Icons
                        .location_on_outlined,
                  ),
                ),
              ),

              TextField(
                controller:
                    landmark,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Landmark (Optional)',
                  prefixIcon:
                      Icon(
                    Icons
                        .place_outlined,
                  ),
                ),
              ),

              TextField(
                controller:
                    city,
                textCapitalization:
                    TextCapitalization
                        .words,
                decoration:
                    const InputDecoration(
                  labelText:
                      'City',
                  prefixIcon:
                      Icon(
                    Icons
                        .location_city_outlined,
                  ),
                ),
              ),

              TextField(
                controller:
                    state,
                decoration:
                    const InputDecoration(
                  labelText:
                      'State',
                  prefixIcon:
                      Icon(
                    Icons
                        .map_outlined,
                  ),
                ),
              ),

              TextField(
                controller:
                    pin,
                keyboardType:
                    TextInputType
                        .number,
                maxLength:
                    6,
                decoration:
                    const InputDecoration(
                  labelText:
                      'PIN Code',
                  prefixIcon:
                      Icon(
                    Icons
                        .pin_drop_outlined,
                  ),
                  counterText:
                      '',
                ),
              ),

              CheckboxListTile(
                contentPadding:
                    EdgeInsets.zero,
                value:
                    isDefault,
                onChanged:
                    (value) {
                  setState(() {
                    isDefault =
                        value ??
                            false;
                  });
                },
                title:
                    const Text(
                  'Set as default address',
                ),
                controlAffinity:
                    ListTileControlAffinity
                        .leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              () =>
                  Navigator.pop(
            context,
          ),
          child:
              const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: () {
            final cleanedPhone =
                cleanPhone(
              phone.text.trim(),
            );

            final validName =
                name.text
                        .trim()
                        .length >=
                    2;

            final validPhone =
                RegExp(
              r'^\d{10}$',
            ).hasMatch(
              cleanedPhone,
            );

            final validStreet =
                street.text
                        .trim()
                        .length >=
                    3;

            final validCity =
                city.text
                    .trim()
                    .isNotEmpty;

            final validPin =
                RegExp(
              r'^\d{6}$',
            ).hasMatch(
              pin.text.trim(),
            );

            if (!validName ||
                !validPhone ||
                !validStreet ||
                !validCity ||
                !validPin) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content:
                      Text(
                    'Please enter valid name, 10-digit mobile, address, city and 6-digit PIN.',
                  ),
                ),
              );
              return;
            }

            final result =
                CustomerAddress(
              addressId:
                  widget.existing
                          ?.addressId
                          .trim()
                          .isNotEmpty ==
                      true
                  ? widget.existing!
                      .addressId
                  : 'addr_${DateTime.now().microsecondsSinceEpoch}',
              name:
                  name.text.trim(),
              phone:
                  cleanedPhone,
              house:
                  house.text.trim(),
              street:
                  street.text.trim(),
              city:
                  city.text.trim(),
              state:
                  state.text.trim().isEmpty
                      ? 'Rajasthan'
                      : state.text.trim(),
              pincode:
                  pin.text.trim(),
              landmark:
                  landmark.text.trim(),
              isDefault:
                  isDefault,
            );

            Navigator.pop(
              context,
              result,
            );
          },
          child:
              const Text(
            'Save Address',
          ),
        ),
      ],
    );
  }
}
