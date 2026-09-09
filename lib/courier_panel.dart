import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CourierPanel extends StatefulWidget {
  const CourierPanel({super.key});

  @override
  State<CourierPanel> createState() => _CourierPanelState();
}

class _CourierPanelState extends State<CourierPanel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  final List<String> _statusFlow = const [
    'Placed',
    'Confirmed',
    'Packed',
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
  ];

  bool _updating = false;

  String? get _courierUid => FirebaseAuth.instance.currentUser?.uid;

  // ------------------------------------------------------------
  // BACK BUTTON
  // ------------------------------------------------------------

  void _goBack() {
    if (_updating) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> _logout() async {
    if (_updating) return;

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // ORDER STREAM
  // ------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return _firestore.collection('orders').snapshots();
  }

  bool _isCourierOrder(Map<String, dynamic> data) {
    final uid = _courierUid;

    if (uid == null) return false;

    final courierId = data['courierId']?.toString();
    final courierUid = data['courierUid']?.toString();
    final assignedCourierId = data['assignedCourierId']?.toString();

    final courierDetails = data['courierDetails'];

    String? detailsUid;

    if (courierDetails is Map) {
      detailsUid = courierDetails['uid']?.toString();
    }

    return courierId == uid ||
        courierUid == uid ||
        assignedCourierId == uid ||
        detailsUid == uid;
  }

  // ------------------------------------------------------------
  // STATUS UPDATE
  // ------------------------------------------------------------

  Future<void> _updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    if (_updating) return;

    setState(() {
      _updating = true;
    });

    try {
      final callable = _functions.httpsCallable(
        'updateCourierOrderStatus',
      );

      await callable.call({
        'orderId': orderId,
        'status': newStatus,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order status updated to $newStatus',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to update order status',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating order: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // STATUS COLOR
  // ------------------------------------------------------------

  Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;

      case 'Out for Delivery':
        return Colors.orange;

      case 'Picked by Courier':
        return Colors.deepPurple;

      case 'Shipped':
        return Colors.blue;

      case 'Packed':
        return Colors.teal;

      case 'Confirmed':
        return Colors.indigo;

      case 'Placed':
      default:
        return Colors.grey;
    }
  }

  // ------------------------------------------------------------
  // COD
  // ------------------------------------------------------------

  bool _isCOD(Map<String, dynamic> data) {
    final isCOD = data['isCOD'];

    if (isCOD == true) {
      return true;
    }

    final paymentMethod =
        data['paymentMethod']?.toString().toLowerCase();

    final paymentType =
        data['paymentType']?.toString().toLowerCase();

    return paymentMethod == 'cod' ||
        paymentMethod == 'cash on delivery' ||
        paymentType == 'cod' ||
        paymentType == 'cash on delivery';
  }

  double _codAmount(Map<String, dynamic> data) {
    final value =
        data['codAmount'] ??
        data['totalAmount'] ??
        data['total'] ??
        data['amount'] ??
        0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ------------------------------------------------------------
  // DATE
  // ------------------------------------------------------------

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return '';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour12 = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final amPm = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year  $hour12:$minute $amPm';
  }

  // ------------------------------------------------------------
  // ORDER DETAILS
  // ------------------------------------------------------------

  void _showOrderDetails(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final customerName =
        data['customerName']?.toString() ??
        data['name']?.toString() ??
        data['userName']?.toString() ??
        'Customer';

    final phone =
        data['phone']?.toString() ??
        data['mobile']?.toString() ??
        data['customerPhone']?.toString() ??
        '';

    final address =
        data['address']?.toString() ??
        data['deliveryAddress']?.toString() ??
        data['shippingAddress']?.toString() ??
        '';

    final status =
        data['status']?.toString() ?? 'Placed';

    final items = data['items'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Order ID: $orderId',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 18),

                  _detailRow(
                    Icons.person_outline,
                    'Customer',
                    customerName,
                  ),

                  if (phone.isNotEmpty)
                    _detailRow(
                      Icons.phone_outlined,
                      'Phone',
                      phone,
                    ),

                  if (address.isNotEmpty)
                    _detailRow(
                      Icons.location_on_outlined,
                      'Address',
                      address,
                    ),

                  _detailRow(
                    Icons.local_shipping_outlined,
                    'Status',
                    status,
                  ),

                  const SizedBox(height: 10),

                  if (_isCOD(data))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cash on Delivery\n'
                              'Collect ₹${_codAmount(data).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 18),

                  const Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  _itemsWidget(items),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsWidget(dynamic items) {
    if (items is! List || items.isEmpty) {
      return const Text(
        'No item details available.',
      );
    }

    return Column(
      children: items.map<Widget>((item) {
        if (item is Map) {
          final name =
              item['name']?.toString() ??
              item['productName']?.toString() ??
              'Product';

          final quantity =
              item['quantity']?.toString() ??
              item['qty']?.toString() ??
              '1';

          final price =
              item['price'] ??
              item['total'] ??
              '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(
                  Icons.shopping_bag_outlined,
                ),
              ),
              title: Text(name),
              subtitle: Text(
                'Quantity: $quantity',
              ),
              trailing: Text(
                price == ''
                    ? ''
                    : '₹$price',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return Card(
          child: ListTile(
            title: Text(
              item.toString(),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ------------------------------------------------------------
  // STATUS DROPDOWN
  // ------------------------------------------------------------

  Widget _statusSelector(
    String orderId,
    String currentStatus,
  ) {
    final currentIndex =
        _statusFlow.indexOf(currentStatus);

    final safeIndex =
        currentIndex < 0 ? 0 : currentIndex;

    final allowedStatuses =
        _statusFlow.sublist(safeIndex);

    return DropdownButtonFormField<String>(
      initialValue: currentStatus.isEmpty ||
              !_statusFlow.contains(currentStatus)
          ? _statusFlow.first
          : currentStatus,
      decoration: const InputDecoration(
        labelText: 'Update Status',
        border: OutlineInputBorder(),
        prefixIcon: Icon(
          Icons.sync_alt,
        ),
      ),
      items: allowedStatuses.map((status) {
        return DropdownMenuItem<String>(
          value: status,
          child: Text(status),
        );
      }).toList(),
      onChanged: _updating
          ? null
          : (value) {
              if (value == null ||
                  value == currentStatus) {
                return;
              }

              _updateOrderStatus(
                orderId,
                value,
              );
            },
    );
  }

  // ------------------------------------------------------------
  // ORDER CARD
  // ------------------------------------------------------------

  Widget _orderCard(
    String orderId,
    Map<String, dynamic> data,
  ) {
    final customerName =
        data['customerName']?.toString() ??
        data['name']?.toString() ??
        data['userName']?.toString() ??
        'Customer';

    final phone =
        data['phone']?.toString() ??
        data['mobile']?.toString() ??
        data['customerPhone']?.toString() ??
        '';

    final address =
        data['address']?.toString() ??
        data['deliveryAddress']?.toString() ??
        data['shippingAddress']?.toString() ??
        '';

    final status =
        data['status']?.toString() ?? 'Placed';

    final createdAt = _formatDate(
      data['createdAt'],
    );

    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                    'Order #$orderId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                createdAt,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],

            const Divider(height: 24),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(phone),
                  ),
                ],
              ),
            ],

            if (address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(address),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            if (_isCOD(data))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius:
                      BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: Colors.orange,
                      size: 21,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'COD — Collect ₹${_codAmount(data).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            _statusSelector(
              orderId,
              status,
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showOrderDetails(
                    context,
                    orderId,
                    data,
                  );
                },
                icon: const Icon(
                  Icons.visibility_outlined,
                ),
                label: const Text(
                  'View Order Details',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 70,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No orders assigned',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assigned courier orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_updating,
      onPopInvokedWithResult:
          (didPop, result) {
        if (didPop) return;

        if (!_updating) {
          _goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _updating
                ? null
                : _goBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),
          title: const Text(
            'Courier Panel',
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _updating
                  ? null
                  : () {
                      setState(() {});
                    },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: _updating
                  ? null
                  : _logout,
              icon: const Icon(
                Icons.logout_rounded,
              ),
            ),
          ],
        ),
        body: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _ordersStream(),
          builder: (
            context,
            snapshot,
          ) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 55,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final documents =
                snapshot.data?.docs ?? [];

            final courierOrders = documents
                .where(
                  (doc) =>
                      _isCourierOrder(
                    doc.data(),
                  ),
                )
                .toList();

            courierOrders.sort((a, b) {
              final aData = a.data();
              final bData = b.data();

              final aCreated =
                  aData['createdAt'];

              final bCreated =
                  bData['createdAt'];

              DateTime aDate = DateTime(1970);
              DateTime bDate = DateTime(1970);

              if (aCreated is Timestamp) {
                aDate = aCreated.toDate();
              }

              if (bCreated is Timestamp) {
                bDate = bCreated.toDate();
              }

              return bDate.compareTo(aDate);
            });

            if (courierOrders.isEmpty) {
              return _emptyState();
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  14,
                  14,
                  14,
                  30,
                ),
                itemCount: courierOrders.length,
                itemBuilder: (
                  context,
                  index,
                ) {
                  final doc =
                      courierOrders[index];

                  return _orderCard(
                    doc.id,
                    doc.data(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
