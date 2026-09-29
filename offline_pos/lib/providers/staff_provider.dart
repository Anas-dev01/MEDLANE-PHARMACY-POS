import 'package:flutter/material.dart';
import '../database/database_service.dart';

class StaffProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _cashiers = [];
  List<Map<String, dynamic>> get cashiers => _cashiers;

  // 1. Load all cashiers (We exclude the Admin so they can't accidentally delete themselves)
  Future<void> loadCashiers() async {
    final db = await DatabaseService.instance.database;
    _cashiers = await db.query(
      'Users',
      where: 'role = ?',
      whereArgs: ['cashier'],
      orderBy: 'name ASC',
    );
    notifyListeners();
  }

  // 2. Add a new Cashier
  Future<String?> addCashier(String username, String firstName, String lastName, String phone, String password) async {
    final db = await DatabaseService.instance.database;

    // Check if username already exists
    final check = await db.query('Users', where: 'name = ?', whereArgs: [username]);
    if (check.isNotEmpty) return "Username already exists!";

    // CREATE STAFF
    await db.insert('Users', {
      'name': username,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role': 'cashier',
      'permissions': 'sales',
      'password': password,
    });

    await loadCashiers();
    return null; // Success!
  }

  // 2. NEW METHOD: Reset Password
  Future<void> resetPassword(int userId, String newPassword) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'Users',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await loadCashiers(); // Refresh the list
  }

  // 3. Delete a Cashier
  Future<void> deleteCashier(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('Users', where: 'id = ?', whereArgs: [id]);
    await loadCashiers();
  }
}