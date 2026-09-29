import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../models/product.dart';

class RestockProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> get suppliers => _suppliers;

  Future<void> loadSuppliers() async {
    final db = await DatabaseService.instance.database;
    _suppliers = await db.query('Suppliers', orderBy: 'name ASC');
    notifyListeners();
  }

  Future<String?> addSupplier(String name, String phone, String address) async {
    final db = await DatabaseService.instance.database;
    final check = await db.query('Suppliers', where: 'name = ?', whereArgs: [name]);
    if (check.isNotEmpty) return "Supplier already exists!";

    await db.insert('Suppliers', {'name': name, 'phone': phone, 'address': address});
    await loadSuppliers();
    return null;
  }

  // --- EDIT SUPPLIER ---
  Future<void> editSupplier(int id, String name, String phone, String address) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'Suppliers',
      {'name': name, 'phone': phone, 'address': address},
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadSuppliers();
  }

  // --- DELETE SUPPLIER ---
  Future<void> deleteSupplier(int id) async {
    final db = await DatabaseService.instance.database;
    // Note: Because we used 'ON DELETE SET NULL' in the Purchases table, 
    // deleting a supplier won't delete their past restock history! It just safely removes them from this list.
    await db.delete('Suppliers', where: 'id = ?', whereArgs: [id]);
    await loadSuppliers();
  }

  // Find a drug strictly by barcode for the scanner
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query('Products', where: 'barcode = ?', whereArgs: [barcode]);
    if (maps.isNotEmpty) return Product.fromMap(maps.first);
    return null;
  }

  // The Official Restock Transaction
  Future<void> processRestock({
    required Product product,
    required int supplierId,
    required int quantityReceived,
    required double totalCost,
    required double amountPaid,
    required String cashierName,
  }) async {
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      // 1. Log the Purchase
      await txn.insert('Purchases', {
        'supplier_id': supplierId,
        'product_id': product.id,
        'quantity': quantityReceived,
        'total_cost': totalCost,
        'amount_paid': amountPaid,
        'datetime': DateTime.now().toIso8601String(),
        'cashier_name': cashierName,
      });

      // 2. Update the Inventory Stock
      await txn.update(
        'Products',
        {'quantity': product.quantity + quantityReceived},
        where: 'id = ?',
        whereArgs: [product.id],
      );
    });
  }
}