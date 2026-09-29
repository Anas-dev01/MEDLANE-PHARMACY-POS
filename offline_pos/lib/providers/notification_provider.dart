import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../models/product.dart';

class NotificationProvider extends ChangeNotifier {
  List<Product> _lowStockProducts = [];
  List<Product> _expiringProducts = [];

  List<Product> get lowStockProducts => _lowStockProducts;
  List<Product> get expiringProducts => _expiringProducts;

  int get totalAlerts => _lowStockProducts.length + _expiringProducts.length;

  Future<void> checkAlerts() async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query('Products');
    
    final allProducts = maps.map((map) => Product.fromMap(map)).toList();
    
    _lowStockProducts = [];
    _expiringProducts = [];
    
    final now = DateTime.now();

    for (var product in allProducts) {
      // 1. CHECK LOW STOCK (Using your dynamic minStock!)
      if (product.quantity <= product.minStock) {
        _lowStockProducts.add(product);
      }

      // 2. CHECK EXPIRY DATES (Within 90 days)
      if (product.expiryDate != null && product.expiryDate!.isNotEmpty) {
        try {
          final expiry = DateTime.parse(product.expiryDate!);
          final difference = expiry.difference(now).inDays;
          
          // If it expires in 90 days or less (including already expired negative numbers)
          if (difference <= 90) {
            _expiringProducts.add(product);
          }
        } catch (e) {
          // Skip if date format is invalid
        }
      }
    }
    
    notifyListeners();
  }
}