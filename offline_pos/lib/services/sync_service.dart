import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';

class SyncService {
  static const String baseUrl = 'http://10.115.109.200:8000/api';
  static const String masterIp = "10.115.109.200"; // Master Laptop IP
  static Timer? _syncTimer;

  static void startAutoSync() {
    print("🚀 Auto-Sync Engine Started! Checking every 30 seconds...");
    _runAllSyncTasks();

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _runAllSyncTasks();
    });
  }

  static void stopAutoSync() {
    _syncTimer?.cancel();
    print("🛑 Auto-Sync Engine Stopped.");
  }

  // --- Master Function to run all pushes ---
  static Future<void> _runAllSyncTasks() async {
    await pushOfflineSales();
    await pushOfflineAdjustments();
    await pushOfflineInventoryLogs();
  }

  // --- NEW: PULL ENGINE (Triggered on Login) ---
  static Future<void> pullEssentialData() async {
    print("Starting background sync from Master...");
    try {
      // 1. Sync Products
      final prodRes = await http.get(Uri.parse("http://$masterIp:8000/api/sync-products"));
      if (prodRes.statusCode == 200) {
        List products = json.decode(prodRes.body);
        for (var p in products) {
          final db = await DatabaseService.instance.database;
          await db.insert('Products', p, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 2. Sync Users
      final userRes = await http.get(Uri.parse("http://$masterIp:8000/api/sync-users"));
      if (userRes.statusCode == 200) {
        List users = json.decode(userRes.body);
        for (var u in users) {
          final db = await DatabaseService.instance.database;
          await db.insert('Users', u, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 3. Sync Suppliers
      final supRes = await http.get(Uri.parse("http://$masterIp:8000/api/sync-suppliers"));
      if (supRes.statusCode == 200) {
        List suppliers = json.decode(supRes.body);
        for (var s in suppliers) {
          final db = await DatabaseService.instance.database;
          await db.insert('Suppliers', s, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      print("Sync Complete: Products, Users, and Suppliers updated.");
    } catch (e) {
      print("Sync Error: $e");
    }
  }

  // 1. SYNC SALES (Unchanged)
  static Future<void> pushOfflineSales() async {
    final db = await DatabaseService.instance.database;
    final unsyncedSales = await db.rawQuery('''
      SELECT s.*, c.name as customer_name, c.phone as customer_phone
      FROM Sales s
      LEFT JOIN Customers c ON s.customer_id = c.id
      WHERE s.is_synced = 0
    ''');

    if (unsyncedSales.isEmpty) return;

    for (var saleMap in unsyncedSales) {
      final items = await db.query('SaleItems', where: 'sale_id = ?', whereArgs: [saleMap['id']]);
      final saleData = {
        "datetime": saleMap['datetime'],
        "total_amount": saleMap['total_amount'],
        "amount_paid": saleMap['amount_paid'],
        "payment_type": saleMap['payment_type'],
        "cashier_name": saleMap['cashier_name'] ?? "Unknown",
        "customer_id": saleMap['customer_id'],
        "customer_name": saleMap['customer_name'],
        "customer_phone": saleMap['customer_phone'],
        "discount": saleMap['discount'] ?? 0.0,
        "items": items.map((item) => {
          "product_id": item['product_id'],
          "quantity": item['quantity'],
          "price": item['price']
        }).toList()
      };

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-sale'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(saleData),
        );
        if (response.statusCode == 200) {
          await db.update('Sales', {'is_synced': 1}, where: 'id = ?', whereArgs: [saleMap['id']]);
          print("✅ SUCCESS: Sale ID ${saleMap['id']} synced!");
        }
      } catch (e) {
        break; 
      }
    }
  }

  // 2. SYNC ADJUSTMENTS
  static Future<void> pushOfflineAdjustments() async {
    final db = await DatabaseService.instance.database;
    final unsynced = await db.query('Adjustments', where: 'is_synced = ?', whereArgs: [0]);

    if (unsynced.isEmpty) return;

    for (var map in unsynced) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-adjustment'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(map), 
        );
        if (response.statusCode == 200) {
          await db.update('Adjustments', {'is_synced': 1}, where: 'id = ?', whereArgs: [map['id']]);
          print("🛠️ SUCCESS: Adjustment ID ${map['id']} synced!");
        }
      } catch (e) {
        break;
      }
    }
  }

  // 3. SYNC INVENTORY LOGS
  static Future<void> pushOfflineInventoryLogs() async {
    final db = await DatabaseService.instance.database;
    final unsynced = await db.query('InventoryLogs', where: 'is_synced = ?', whereArgs: [0]);

    if (unsynced.isEmpty) return;

    for (var map in unsynced) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-inventory-log'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(map),
        );
        if (response.statusCode == 200) {
          await db.update('InventoryLogs', {'is_synced': 1}, where: 'id = ?', whereArgs: [map['id']]);
          print("📦 SUCCESS: Inventory Log ID ${map['id']} synced!");
        }
      } catch (e) {
        break;
      }
    }
  }
}