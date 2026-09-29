import 'package:flutter/material.dart';
import '../database/database_service.dart';

class ReportProvider extends ChangeNotifier {
  double _todayRevenue = 0.0;
  int _todaySalesCount = 0;
  List<Map<String, dynamic>> _recentSales = [];
  
  // 1. ADD A VARIABLE TO TRACK THE SELECTED DATE
  DateTime _selectedDate = DateTime.now();

  // --- NEW INVENTORY VARIABLES ---
  int totalUniqueProducts = 0;
  int totalItemsOnHand = 0;
  double totalRetailValue = 0.0;
  double totalWholesaleValue = 0.0;

  double get todayRevenue => _todayRevenue;
  int get todaySalesCount => _todaySalesCount;
  List<Map<String, dynamic>> get recentSales => _recentSales;
  DateTime get selectedDate => _selectedDate; // Expose it to the UI

  // 2. ALLOW PASSING A CUSTOM DATE
  Future<void> loadReport({DateTime? date}) async {
    if (date != null) {
      _selectedDate = date; // Update the date if the user picked a new one
    }

    final db = await DatabaseService.instance.database;
    
    // 3. USE THE SELECTED DATE INSTEAD OF "NOW"
    final String datePrefix = _selectedDate.toIso8601String().substring(0, 10);

    // Calculate Total Revenue for Selected Date
    final revenueResult = await db.rawQuery(
      "SELECT SUM(total_amount) as total FROM Sales WHERE datetime LIKE '$datePrefix%'"
    );
    _todayRevenue = (revenueResult.first['total'] as double?) ?? 0.0;

    // Count Total Transactions for Selected Date
    final countResult = await db.rawQuery(
      "SELECT COUNT(id) as count FROM Sales WHERE datetime LIKE '$datePrefix%'"
    );
    _todaySalesCount = (countResult.first['count'] as int?) ?? 0;

    // The Ultimate Master Ledger Query (Sales + Debt Recoveries + Supplier Payments + Shrinkage)
    _recentSales = await db.rawQuery('''
      SELECT 
        'SALE' as log_type, s.id, s.datetime, s.total_amount, s.amount_paid, s.payment_type, s.discount, 
        c.name as entity_name, s.cashier_name,
        (SELECT SUM(quantity) FROM SaleItems WHERE sale_id = s.id) as item_count,
        NULL as product_name
      FROM Sales s
      LEFT JOIN Customers c ON s.customer_id = c.id
      WHERE s.datetime LIKE '$datePrefix%'
      
      UNION ALL
      
      SELECT 
        'REPAYMENT' as log_type, r.id, r.datetime, d.amount as total_amount, r.amount as amount_paid, r.payment_type, 0.0 as discount, 
        c.name as entity_name, r.cashier_name, 0 as item_count,
        NULL as product_name
      FROM DebtRepayments r
      JOIN Debts d ON r.debt_id = d.id
      JOIN Customers c ON d.entity_id = c.id
      WHERE r.datetime LIKE '$datePrefix%'

      UNION ALL

      SELECT 
        'RESTOCK' as log_type, p.id, p.datetime, p.total_cost as total_amount, p.amount_paid, 'Cash' as payment_type, 0.0 as discount, 
        sup.name as entity_name, p.cashier_name, p.quantity as item_count,
        pr.name as product_name
      FROM Purchases p
      LEFT JOIN Suppliers sup ON p.supplier_id = sup.id
      LEFT JOIN Products pr ON p.product_id = pr.id
      WHERE p.datetime LIKE '$datePrefix%'

      UNION ALL

      SELECT 
        'SHRINKAGE' as log_type, a.id, a.datetime, 0.0 as total_amount, 0.0 as amount_paid, a.reason as payment_type, 0.0 as discount, 
        pr.name as entity_name, a.cashier_name, (a.old_quantity - a.new_quantity) as item_count,
        NULL as product_name
      FROM Adjustments a
      JOIN Products pr ON a.product_id = pr.id
      WHERE a.datetime LIKE '$datePrefix%'
      
      ORDER BY datetime DESC
      LIMIT 25
    ''');

    // --- INVENTORY METRICS ENGINE ---
    final inventoryResult = await db.rawQuery('''
      SELECT 
        COUNT(id) AS total_unique,
        COALESCE(SUM(quantity), 0) AS total_items,
        COALESCE(SUM(quantity * price_single), 0) AS retail_value,
        COALESCE(SUM(quantity * IFNULL(price_wholesale, 0)), 0) AS wholesale_value
      FROM Products
    ''');

    if (inventoryResult.isNotEmpty) {
      totalUniqueProducts = (inventoryResult.first['total_unique'] as num).toInt();
      totalItemsOnHand = (inventoryResult.first['total_items'] as num).toInt();
      totalRetailValue = (inventoryResult.first['retail_value'] as num).toDouble();
      totalWholesaleValue = (inventoryResult.first['wholesale_value'] as num).toDouble();
    }

    notifyListeners();
  }
}