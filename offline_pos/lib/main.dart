import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'database/database_service.dart';
import 'providers/inventory_provider.dart';
import 'providers/pos_provider.dart'; 
import 'providers/report_provider.dart';
import 'providers/debt_provider.dart';
import 'ui/home_screen.dart'; 
import 'providers/auth_provider.dart';
import 'ui/login_screen.dart';
import 'providers/supply_provider.dart';
import 'providers/staff_provider.dart';
import 'providers/restock_provider.dart';
import 'providers/notification_provider.dart';
import 'package:offline_pos/services/sync_service.dart'; // Added SyncService import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for Windows desktop SQLite support
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize the database
  final db = await DatabaseService.instance.database;

  // START THE ENGINE
  SyncService.startAutoSync();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()..loadProducts()),
        ChangeNotifierProvider(create: (_) => POSProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => SupplyProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => RestockProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const POSApp(),
    ),
  );
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // --- THE MAGIC LINE TO REMOVE THE RED BANNER ---
      title: 'Medlane Healthcare Pharmacy', // --- UPDATED TITLE ---
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoggedIn) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}