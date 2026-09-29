import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // --- NEW IMPORT ---
import '../database/database_service.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/notification_provider.dart'; // --- NEW IMPORT (Ensure path is correct) ---

class POSProvider extends ChangeNotifier {
  List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;

  // --- DISCOUNT VARIABLES ---
  double _discountValue = 0.0;
  bool _isDiscountPercentage = false;

  double get discountValue => _discountValue;
  bool get isDiscountPercentage => _isDiscountPercentage;

  // 1. Method to apply discount
  void setDiscount(double value, bool isPercentage) {
    _discountValue = value;
    _isDiscountPercentage = isPercentage;
    notifyListeners();
  }

  // 2. Method to toggle wholesale on a specific cart item
  void toggleWholesale(int index, bool value) {
    _cart[index].isWholesale = value;
    notifyListeners();
  }

  // 3. UPGRADED TOTAL CALCULATION
  double get subTotal => _cart.fold(0.0, (sum, item) => sum + item.total);
  
  double get calculatedDiscount {
    if (_isDiscountPercentage) {
      return subTotal * (_discountValue / 100);
    }
    return _discountValue;
  }

  double get grandTotal {
    double total = subTotal - calculatedDiscount;
    return total > 0 ? total : 0.0; // Prevent negative totals!
  }

  // 1. Scan a barcode and add it to the cart
  Future<String?> scanAndAddToCart(String barcode) async {
    final db = await DatabaseService.instance.database;

    // Find the drug in the database
    final result = await db.query(
      'Products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (result.isEmpty) {
      return 'Drug not found in inventory!';
    }

    final product = Product.fromMap(result.first);

    // Check if it's already in the cart, if so, just increase quantity
    final existingItemIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingItemIndex >= 0) {
      // Check stock before adding
      if (_cart[existingItemIndex].quantity < product.quantity) {
        _cart[existingItemIndex].quantity += 1;
      } else {
        return 'Not enough stock!';
      }
    } else {
      if (product.quantity > 0) {
        _cart.add(CartItem(product: product));
      } else {
        return 'Out of stock!';
      }
    }

    notifyListeners();
    return null; // Null means success (no error message)
  }

  // 2. Remove an item from the cart
  void removeItem(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  // --- NEW: Safely Increase Quantity ---
  void incrementItem(int index) {
    final item = _cart[index];
    // Rule: Cannot sell more than what is in stock!
    if (item.quantity < item.product.quantity) {
      item.quantity++;
      notifyListeners();
    }
  }

  // --- SMART SEARCH (BARCODE OR NAME) ---
  Future<List<Product>> searchDrug(String query) async {
    final db = await DatabaseService.instance.database;
    
    // 1. First, check for an EXACT barcode match (for the scanner)
    var maps = await db.query('Products', where: 'barcode = ?', whereArgs: [query]);
    
    if (maps.isNotEmpty) {
      return maps.map((m) => Product.fromMap(m)).toList();
    }
    
    // 2. If no barcode matches, search by Drug Name (for manual typing)
    maps = await db.query('Products', where: 'name LIKE ?', whereArgs: ['%$query%']);
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  // --- ADD DIRECT PRODUCT TO CART (For Smart Search) ---
  void addToCart(var product) {
    // 1. Check if this exact drug is already sitting in the cart
    int existingIndex = _cart.indexWhere((item) => item.product.name == product.name);

    if (existingIndex != -1) {
      // 2. If it is already in the cart, just trigger your existing increment logic!
      if (_cart[existingIndex].quantity < product.quantity) {
        incrementItem(existingIndex);
      }
    } else {
      // 3. If it's brand new, pack it into a CartItem and drop it in
      _cart.add(CartItem(
        product: product,
        quantity: 1,
      ));
      notifyListeners();
    }
  }

  // --- NEW: Safely Decrease Quantity ---
  void decrementItem(int index) {
    final item = _cart[index];
    // Rule: Cannot go below 1 (Use the delete button to remove it completely)
    if (item.quantity > 1) {
      item.quantity--;
      notifyListeners();
    }
  }

  // --- NEW: SET EXACT QUANTITY ---
  void setQuantity(int index, int newQty) {
    if (newQty < 1) newQty = 1; // Don't allow 0 or negative
    
    // Don't allow them to type more than the available stock
    if (newQty > _cart[index].product.quantity) {
      _cart[index].quantity = _cart[index].product.quantity;
    } else {
      _cart[index].quantity = newQty;
    }
    
    notifyListeners();
  }

  // 3. Process the Checkout (Upgraded for Debts/Owing)
  Future<bool> checkout(
    BuildContext context, // --- NEW: ADDED CONTEXT HERE ---
    String paymentMethod, {
    required double amountPaid,
    String? customerName,
    String? customerPhone,
    required String cashierName,
  }) async {
    if (_cart.isEmpty) return false;

    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      int? customerId;

      // A. If they are owing, we MUST attach a customer
      double amountOwed = grandTotal - amountPaid;

      if (amountOwed > 0 && customerName != null && customerName.isNotEmpty) {
        // 1. Create or find the customer
        customerId = await txn.insert('Customers', {
          'name': customerName,
          'phone': customerPhone,
        });

        // 2. Record the Debt
        await txn.insert('Debts', {
          'type': 'customer',
          'entity_id': customerId,
          'amount': amountOwed,
          'status': 'unpaid',
          'due_date': null, // Can add a date picker later
        });
      }

      // B. Create the Sale Record
      final saleId = await txn.insert('Sales', {
        'datetime': now,
        'total_amount': grandTotal,
        'amount_paid': amountPaid,
        'payment_type': paymentMethod,
        'customer_id': customerId, 
        'discount': calculatedDiscount, // <-- SAVE THE DISCOUNT HERE
        'cashier_name': cashierName, 
      });

      // C. Loop through the cart to save items and deduct stock
      for (var item in _cart) {
        await txn.insert('SaleItems', {
          'sale_id': saleId,
          'product_id': item.product.id,
          'quantity': item.quantity,
          'price': item.total / item.quantity, // Save the actual applied price per unit (handles wholesale correctly)
        });

        await txn.rawUpdate(
          'UPDATE Products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.product.id],
        );

        await txn.insert('InventoryLogs', {
          'product_id': item.product.id,
          'action': 'sale',
          'quantity': item.quantity,
          'datetime': now,
        });
      }
    });

    _cart.clear();
    _discountValue = 0.0; // Reset the discount for the next customer!
    
    // --- TRIGGER NOTIFICATION RECALCULATION ---
    if (context.mounted) {
      Provider.of<NotificationProvider>(context, listen: false)..checkAlerts();
    }
    
    notifyListeners();
    return true;
  }
}