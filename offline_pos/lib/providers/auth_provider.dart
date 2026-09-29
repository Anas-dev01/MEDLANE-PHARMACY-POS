import 'package:flutter/material.dart';
import '../database/database_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?['role'] == 'admin';

  // 1. Attempt to log in
  Future<String?> login(String username, String password) async {
    final db = await DatabaseService.instance.database;
    
    final result = await db.query(
      'Users',
      where: 'name = ? AND password = ?', // In a real app, hash passwords! But plain text is fine for this offline MVP.
      whereArgs: [username, password],
    );

    if (result.isNotEmpty) {
      _currentUser = result.first;
      notifyListeners();
      return null; // Return null if successful
    }
    return 'Invalid username or password!'; // Return error message if failed
  }

  // --- CHANGE PASSWORD LOGIC ---
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    // 1. Safety check to make sure someone is actually logged in
    if (currentUser == null) return "No user logged in.";

    // 2. Verify the old password matches the database
    if (currentUser!['password'] != currentPassword) {
      return "Incorrect current password.";
    }

    // 3. Update the database
    final db = await DatabaseService.instance.database;
    await db.update(
      'Users',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [currentUser!['id']],
    );

    // 4. Update the live session map so they don't get logged out
    // Note: We create a new map because SQLite maps are usually read-only
    final updatedUser = Map<String, dynamic>.from(currentUser!);
    updatedUser['password'] = newPassword;
    _currentUser = updatedUser; // <--- FIX: Assigned to _currentUser instead of currentUser
    
    notifyListeners();
    
    return null; // Null means absolute success!
  }

  // 2. Log out
  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}