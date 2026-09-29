import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../models/product.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert'; // <--- NEW IMPORT
import 'package:http/http.dart' as http; // <--- NEW IMPORT

class InventoryProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> get products => _products;

  // Remember to change this to the Master Laptop's IP on deployment day!
  final String masterServerUrl = 'http://127.0.0.1:8000/api';

  // --- SEARCHING ---
  String _searchQuery = '';

  List<Product> get filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) => 
      p.barcode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      p.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Configuration for low stock alerts
  final int lowStockThreshold = 5;

  // 1. Load all products from SQLite
  Future<void> loadProducts() async {
    final db = await DatabaseService.instance.database;
    final result = await db.query('Products', orderBy: 'name ASC');
    
    _products = result.map((map) => Product.fromMap(map)).toList();
    notifyListeners(); // Tells the UI to rebuild
  }

  // 2. Add a new product (AND SYNC IT TO MASTER)
  Future<String?> addProduct(Product product) async {
    try {
      final db = await DatabaseService.instance.database;
      
      // 1. Save locally FIRST to get the auto-generated SQLite ID
      final int newId = await db.insert('Products', product.toMap());
      await loadProducts();

      // 2. SILENT BACKGROUND SYNC: Push the new drug to MariaDB
      _syncProductToServer(newId, product);

      return null; // Success!
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed: Products.barcode')) {
        return 'Error: This Barcode is already registered to another drug!';
      }
      return 'An unexpected error occurred: $e';
    }
  }

  // 3. Update existing product / Edit Product (AND SYNC IT TO MASTER)
  Future<String?> editProduct(Product updatedProduct) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.update(
        'Products',
        updatedProduct.toMap(),
        where: 'id = ?',
        whereArgs: [updatedProduct.id],
      );
      await loadProducts();

      // SILENT BACKGROUND SYNC: Push the updated details to MariaDB
      if (updatedProduct.id != null) {
        _syncProductToServer(updatedProduct.id!, updatedProduct);
      }

      return null; // Success!
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed: Products.barcode')) {
        return 'Error: This Barcode is already registered to another drug!';
      }
      return 'An unexpected error occurred: $e';
    }
  }

  // --- NEW: THE BACKGROUND SYNC ENGINE FOR DRUGS ---
  Future<void> _syncProductToServer(int id, Product product) async {
    try {
      final url = Uri.parse('$masterServerUrl/sync-product');
      
      // Extract the map from your product model and forcefully inject the matching ID
      Map<String, dynamic> payload = product.toMap();
      payload['id'] = id; 

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print("✅ Drug '${product.name}' successfully synced to Master Server!");
      } else {
        print("❌ Master Server rejected drug sync: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Network error syncing drug: $e");
    }
  }

  // 4. Barcode Scanner lookup (For the POS screen)
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await DatabaseService.instance.database;
    final result = await db.query(
      'Products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null; // Product not found
  }

  // --- 2. LOG SHRINKAGE & ADJUST STOCK ---
  Future<void> adjustStock(int productId, int oldQty, int newQty, String reason, String cashierName) async {
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      await txn.insert('Adjustments', {
        'product_id': productId,
        'old_quantity': oldQty,
        'new_quantity': newQty,
        'reason': reason,
        'datetime': DateTime.now().toIso8601String(),
        'cashier_name': cashierName,
      });

      await txn.update(
        'Products',
        {'quantity': newQty},
        where: 'id = ?',
        whereArgs: [productId],
      );
    });

    await loadProducts(); // Refresh the screen
  }

  // Dynamically check each product against its OWN minimum stock level!
  List<Product> get lowStockProducts {
    return _products.where((p) => p.quantity <= p.minStock).toList();
  }

  // --- EXPORT INVENTORY TO CSV ---
  Future<String> exportInventoryToCSV() async {
    try {
      final db = await DatabaseService.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('Products');

      if (maps.isEmpty) return 'Error: Inventory is empty!';

      StringBuffer sb = StringBuffer();
      sb.writeln("ID,Drug Name,Category,Barcode,Single Price (N),Wholesale Price (N),Stock Quantity,Min Stock,Expiry Date");

      for (var row in maps) {
        String name = row['name']?.toString().replaceAll('"', '""') ?? '';
        String category = row['category']?.toString().replaceAll('"', '""') ?? '';
        
        sb.writeln(
          "${row['id']},\"$name\",\"$category\",${row['barcode']},${row['price_single']},${row['price_wholesale'] ?? 0},${row['quantity']},${row['min_stock']},${row['expiry_date'] ?? 'N/A'}"
        );
      }

      Directory documents = await getApplicationDocumentsDirectory();
      Directory backupDir = Directory('${documents.path}/Medlane_Backups');
      if (!await backupDir.exists()) {
        await backupDir.create();
      }

      String timestamp = DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      File file = File('${backupDir.path}/Inventory_Backup_$timestamp.csv');
      
      await file.writeAsString(sb.toString());

      return 'Success! Saved to: ${file.path}';
      
    } catch (e) {
      return 'Error generating backup: $e';
    }
  }
}