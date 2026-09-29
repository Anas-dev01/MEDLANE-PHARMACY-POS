import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../models/product.dart';

class SupplyProvider extends ChangeNotifier {
  
  // Log an incoming supply of drugs
  Future<void> logSupply({
    required Product product,
    required int quantityAdded,
    required double totalCost,
    required double amountPaidToSupplier,
    required String supplierName,
    String? supplierContact,
  }) async {
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      int? supplierId;

      // 1. Create or find the Supplier
      supplierId = await txn.insert('Suppliers', {
        'name': supplierName,
        'contact_info': supplierContact,
      });

      // 2. Calculate if the Pharmacy owes the Supplier money
      double amountOwed = totalCost - amountPaidToSupplier;
      if (amountOwed > 0) {
        await txn.insert('Debts', {
          'type': 'supplier', // Notice this is 'supplier' instead of 'customer'!
          'entity_id': supplierId,
          'amount': amountOwed,
          'status': 'unpaid',
          'due_date': null,
        });
      }

      // 3. Update the Product Inventory (Increase Stock)
      await txn.rawUpdate(
        'UPDATE Products SET quantity = quantity + ? WHERE id = ?',
        [quantityAdded, product.id]
      );

      // 4. Record the Expense (Money leaving the pharmacy)
      if (amountPaidToSupplier > 0) {
        await txn.insert('Expenses', {
          'description': 'Restock: ${product.name} from $supplierName',
          'amount': amountPaidToSupplier,
          'datetime': now,
        });
      }

      // 5. Log the Inventory Action
      await txn.insert('InventoryLogs', {
        'product_id': product.id,
        'action': 'restock',
        'quantity': quantityAdded,
        'datetime': now,
      });
    });

    notifyListeners();
  }
}