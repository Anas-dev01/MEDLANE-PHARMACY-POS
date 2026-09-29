import 'package:flutter/material.dart';
import '../database/database_service.dart';

class DebtProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _customerDebts = [];
  List<Map<String, dynamic>> get customerDebts => _customerDebts;

  // Calculate the total money stuck outside
  double get totalOutstanding {
    return _customerDebts.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  // 1. Load all unpaid customer debts
  Future<void> loadDebts() async {
    final db = await DatabaseService.instance.database;
    
    // We use a JOIN to get the customer's name and phone number alongside their debt
    final result = await db.rawQuery('''
      SELECT d.id as debt_id, d.amount, d.status, c.name, c.phone 
      FROM Debts d 
      JOIN Customers c ON d.entity_id = c.id 
      WHERE d.status = 'unpaid' AND d.type = 'customer'
      ORDER BY d.amount DESC
    ''');
    
    _customerDebts = result;
    notifyListeners();
  }

  // Update signature to include cashierName and paymentType
  Future<void> settleDebt(int debtId, double currentAmount, double amountPaid, String cashierName, String paymentType) async {
    final db = await DatabaseService.instance.database;
    double newAmount = currentAmount - amountPaid;

    await db.transaction((txn) async {
      // 1. Log the actual payment event!
      await txn.insert('DebtRepayments', {
        'debt_id': debtId,
        'amount': amountPaid,
        'datetime': DateTime.now().toIso8601String(),
        'payment_type': paymentType,
        'cashier_name': cashierName,
      });

      // 2. Reduce the debt balance
      if (newAmount <= 0) {
        await txn.update('Debts', {'amount': 0.0, 'status': 'paid'}, where: 'id = ?', whereArgs: [debtId]);
      } else {
        await txn.update('Debts', {'amount': newAmount}, where: 'id = ?', whereArgs: [debtId]);
      }
    });
    
    await loadDebts();
  }
}