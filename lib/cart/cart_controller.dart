import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/preesho_models.dart';

// ============================================================
// CART ITEM
// ============================================================

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  // ============================================================
  // PRODUCT DETAILS
  // ============================================================

  String get id => product.id;

  String get name => product.name;

  String get category => product.category;

  String get imageUrl => product.imageUrl;

  double get numericPrice => product.numericPrice;

  double get originalPrice => product.originalPrice;

  dynamic get discountPercent =>
      product.discountPercent;

  // ============================================================
  // TOTAL PRICE
  // ============================================================

  double get totalPrice {
    return numericPrice * quantity;
  }

  // ============================================================
  // AVAILABLE STOCK
  // ============================================================

  int get availableStock {
    return product.stock;
  }

  // ============================================================
  // VENDOR
  // ============================================================

  String get vendorUid {
    return product.vendorUid?.trim() ?? '';
  }

  String get vendorName {
    return product.vendorName?.trim() ?? '';
  }
}

// ============================================================
// CART CONTROLLER
// ============================================================

class CartController {
  static const String _storageKey =
      'preesho_cart_v2';

  static final List<CartItem> items = [];

  static SharedPreferences? _preferences;

  static bool _initialized = false;

  // ============================================================
  // INITIALIZE CART
  // ============================================================

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      _preferences =
          await SharedPreferences.getInstance();

      await _loadCart();

      _initialized = true;
    } catch (_) {
      items.clear();
      _initialized = true;
    }
  }

  // ============================================================
  // ENSURE INITIALIZED
  // ============================================================

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ============================================================
  // LOAD CART
  // ============================================================

  static Future<void> _loadCart() async {
    if (_preferences == null) {
      return;
    }

    try {
      final String? savedCart =
          _preferences!.getString(
        _storageKey,
      );

      if (savedCart == null ||
          savedCart.trim().isEmpty) {
        items.clear();
        return;
      }

      final dynamic decoded =
          jsonDecode(savedCart);

      if (decoded is! List) {
        items.clear();
        return;
      }

      items.clear();

      for (final dynamic item in decoded) {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(item);

        final Map<String, dynamic> productData =
            data['product'] is Map
                ? Map<String, dynamic>.from(
                    data['product'],
                  )
                : data;

        final Product product =
            _productFromMap(productData);

        // --------------------------------------------------------
        // INVALID PRODUCT
        // --------------------------------------------------------

        if (product.id.trim().isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // INACTIVE PRODUCT
        // --------------------------------------------------------

        if (!product.active) {
          continue;
        }

        // --------------------------------------------------------
        // OUT OF STOCK
        // --------------------------------------------------------

        if (product.stock <= 0) {
          continue;
        }

        // --------------------------------------------------------
        // QUANTITY
        // --------------------------------------------------------

        int quantity =
            _toInt(data['quantity']);

        if (quantity <= 0) {
          quantity = 1;
        }

        if (quantity > product.stock) {
          quantity = product.stock;
        }

        items.add(
          CartItem(
            product: product,
            quantity: quantity,
          ),
        );
      }

      await _saveCart();
    } catch (_) {
      // Corrupted cart data should never
      // crash the application.
      items.clear();
    }
  }

  // ============================================================
  // PRODUCT FROM MAP
  // ============================================================

  static Product _productFromMap(
    Map<String, dynamic> data,
  ) {
    return Product(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      category:
          data['category']?.toString() ?? '',
      price: data['price'] ?? 0,
      stock: _toInt(data['stock']),
      imageUrl:
          data['imageUrl']?.toString() ?? '',
      description:
          data['description']?.toString() ?? '',
      active: data['active'] == true,
      mrp: data['mrp'] ?? 0,
      discountPercent:
          data['discountPercent'] ?? 0,

      // --------------------------------------------------------
      // VENDOR
      // --------------------------------------------------------

      vendorUid:
          _nullableString(
        data['vendorUid'] ??
            data['vendorId'] ??
            data['sellerUid'] ??
            data['sellerId'],
      ),

      vendorName:
          _nullableString(
        data['vendorName'] ??
            data['vendor'] ??
            data['sellerName'] ??
            data['seller'],
      ),
    );
  }

  // ============================================================
  // PRODUCT TO MAP
  // ============================================================

  static Map<String, dynamic> _productToMap(
    Product product,
  ) {
    return {
      'id': product.id,
      'name': product.name,
      'category': product.category,
      'price': product.price,
      'stock': product.stock,
      'imageUrl': product.imageUrl,
      'description': product.description,
      'active': product.active,
      'mrp': product.mrp,
      'discountPercent':
          product.discountPercent,

      'vendorUid':
          product.vendorUid?.trim(),

      'vendorName':
          product.vendorName?.trim(),
    };
  }

  // ============================================================
  // SAVE CART
  // ============================================================

  static Future<void> _saveCart() async {
    if (_preferences == null) {
      return;
    }

    try {
      final List<Map<String, dynamic>> data =
          items.map((item) {
        return {
          'product':
              _productToMap(item.product),
          'quantity': item.quantity,
        };
      }).toList();

      await _preferences!.setString(
        _storageKey,
        jsonEncode(data),
      );
    } catch (_) {
      // Storage errors should not crash UI.
    }
  }

  // ============================================================
  // ITEM COUNT
  // ============================================================

  static int get itemCount {
    int count = 0;

    for (final CartItem item in items) {
      count += item.quantity;
    }

    return count;
  }

  // ============================================================
  // TOTAL
  // ============================================================

  static double get total {
    double amount = 0;

    for (final CartItem item in items) {
      amount += item.totalPrice;
    }

    return amount;
  }

  // ============================================================
  // ORIGINAL TOTAL
  // ============================================================

  static double get originalTotal {
    double amount = 0;

    for (final CartItem item in items) {
      amount +=
          item.originalPrice *
          item.quantity;
    }

    return amount;
  }

  // ============================================================
  // PRODUCT SAVINGS
  // ============================================================

  static double get productSavings {
    final double savings =
        originalTotal - total;

    return savings < 0 ? 0 : savings;
  }

  // ============================================================
  // FIND ITEM
  // ============================================================

  static CartItem? findItem(
    String productId,
  ) {
    try {
      return items.firstWhere(
        (item) =>
            item.product.id == productId,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  static Future<bool> addProduct(
    Product product, {
    int quantity = 1,
  }) async {
    await _ensureInitialized();

    if (product.id.trim().isEmpty) {
      return false;
    }

    if (quantity <= 0) {
      return false;
    }

    if (!product.active) {
      return false;
    }

    if (product.stock <= 0) {
      return false;
    }

    final CartItem? existing =
        findItem(product.id);

    // ----------------------------------------------------------
    // PRODUCT ALREADY EXISTS
    // ----------------------------------------------------------

    if (existing != null) {
      final int newQuantity =
          existing.quantity + quantity;

      if (newQuantity > product.stock) {
        existing.quantity =
            product.stock;
      } else {
        existing.quantity =
            newQuantity;
      }

      await _saveCart();

      return true;
    }

    // ----------------------------------------------------------
    // NEW PRODUCT
    // ----------------------------------------------------------

    final int safeQuantity =
        quantity > product.stock
            ? product.stock
            : quantity;

    items.add(
      CartItem(
        product: product,
        quantity: safeQuantity,
      ),
    );

    await _saveCart();

    return true;
  }

  // ============================================================
  // INCREASE QUANTITY
  // ============================================================

  static Future<bool> increaseQuantity(
    String productId,
  ) async {
    await _ensureInitialized();

    final CartItem? item =
        findItem(productId);

    if (item == null) {
      return false;
    }

    if (!item.product.active) {
      return false;
    }

    if (item.availableStock <= 0) {
      return false;
    }

    if (item.quantity >=
        item.availableStock) {
      return false;
    }

    item.quantity++;

    await _saveCart();

    return true;
  }

  // ============================================================
  // DECREASE QUANTITY
  // ============================================================

  static Future<bool> decreaseQuantity(
    String productId,
  ) async {
    await _ensureInitialized();

    final CartItem? item =
        findItem(productId);

    if (item == null) {
      return false;
    }

    if (item.quantity <= 1) {
      return false;
    }

    item.quantity--;

    await _saveCart();

    return true;
  }

  // ============================================================
  // SET QUANTITY
  // ============================================================

  static Future<bool> setQuantity(
    String productId,
    int quantity,
  ) async {
    await _ensureInitialized();

    final CartItem? item =
        findItem(productId);

    if (item == null) {
      return false;
    }

    if (quantity <= 0) {
      return false;
    }

    if (item.availableStock <= 0) {
      return false;
    }

    if (quantity >
        item.availableStock) {
      item.quantity =
          item.availableStock;
    } else {
      item.quantity = quantity;
    }

    await _saveCart();

    return true;
  }

  // ============================================================
  // REMOVE PRODUCT
  // ============================================================

  static Future<void> removeProduct(
    String productId,
  ) async {
    await _ensureInitialized();

    items.removeWhere(
      (item) =>
          item.product.id == productId,
    );

    await _saveCart();
  }

  // ============================================================
  // CLEAR CART
  // ============================================================

  static Future<void> clear() async {
    await _ensureInitialized();

    items.clear();

    await _saveCart();
  }

  // ============================================================
  // CHECK ITEM
  // ============================================================

  static bool contains(
    String productId,
  ) {
    return findItem(productId) != null;
  }

  // ============================================================
  // REFRESH STOCK
  // ============================================================

  static Future<void> refreshProductStock(
    Product updatedProduct,
  ) async {
    await _ensureInitialized();

    final CartItem? item =
        findItem(updatedProduct.id);

    if (item == null) {
      return;
    }

    // ----------------------------------------------------------
    // PRODUCT NO LONGER AVAILABLE
    // ----------------------------------------------------------

    if (!updatedProduct.active ||
        updatedProduct.stock <= 0) {
      await removeProduct(
        updatedProduct.id,
      );

      return;
    }

    // ----------------------------------------------------------
    // REDUCE QUANTITY IF STOCK REDUCED
    // ----------------------------------------------------------

    if (item.quantity >
        updatedProduct.stock) {
      item.quantity =
          updatedProduct.stock;
    }

    await _saveCart();
  }

  // ============================================================
  // REMOVE INVALID ITEMS
  // ============================================================

  static Future<void>
      removeInvalidItems() async {
    await _ensureInitialized();

    items.removeWhere(
      (item) =>
          !item.product.active ||
          item.product.stock <= 0,
    );

    for (final CartItem item
        in items) {
      if (item.quantity >
          item.product.stock) {
        item.quantity =
            item.product.stock;
      }

      if (item.quantity <= 0) {
        item.quantity = 1;
      }
    }

    await _saveCart();
  }

  // ============================================================
  // CLEAR STORAGE COMPLETELY
  // ============================================================

  static Future<void>
      clearStorage() async {
    await _ensureInitialized();

    items.clear();

    await _preferences?.remove(
      _storageKey,
    );
  }

  // ============================================================
  // SAFE INT
  // ============================================================

  static int _toInt(dynamic value) {
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

  // ============================================================
  // NULLABLE STRING
  // ============================================================

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String result =
        value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }
}
