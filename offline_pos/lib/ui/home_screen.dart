import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; 
import '../providers/notification_provider.dart'; // NEW IMPORT
import 'package:offline_pos/services/sync_service.dart'; // --- NEW SYNC SERVICE IMPORT ---
import 'staff/staff_screen.dart';
import 'inventory/inventory_screen.dart';
import 'pos/pos_screen.dart';
import 'reports/reports_screen.dart';
import 'debts/debts_screen.dart';
import 'suppliers/restock_screen.dart';
import 'suppliers/supplier_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).checkAlerts();
    });
  }

  void _showNotificationPanel(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // 1. ADD A CUSTOM HEADER WITH AN X BUTTON
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.red),
                  const SizedBox(width: 10),
                  Text('System Alerts (${provider.totalAlerts})'),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context), // QUICK X BUTTON
                splashRadius: 20,
              ),
            ],
          ),
          // 2. CROP THE WIDTH TO THE MIDDLE
          content: SizedBox(
            width: 500, // Fixed width so it stays centered and professional
            height: 450, 
            child: provider.totalAlerts == 0
                ? const Center(
                    child: Text(
                      'All good! No low stock or expiry warnings.', 
                      style: TextStyle(color: Colors.green, fontSize: 16)
                    ),
                  )
                : ListView(
                    children: [
                      // --- EXPIRY WARNINGS ---
                      if (provider.expiringProducts.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(5)),
                          child: const Text('⚠️ EXPIRING SOON (Next 90 Days)', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ),
                        ...provider.expiringProducts.map((p) => ListTile(
                          leading: const Icon(Icons.event_note, color: Colors.orange),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Expires: ${p.expiryDate} (Stock: ${p.quantity})'),
                          isThreeLine: true,
                        )),
                        const Divider(),
                      ],

                      const SizedBox(height: 10),

                      // --- LOW STOCK WARNINGS ---
                      if (provider.lowStockProducts.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(5)),
                          child: const Text('🚨 LOW STOCK ALERT', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                        ...provider.lowStockProducts.map((p) => ListTile(
                          leading: const Icon(Icons.inventory_2_outlined, color: Colors.red),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Current Stock: ${p.quantity} (Min Required: ${p.minStock})'),
                        )),
                      ],
                    ],
                  ),
          ),
          // Clean up by removing the footer actions since we have the X button
          actions: null, 
        );
      },
    );
  }

  // --- UI: CHANGE PASSWORD POPUP ---
  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Force them to hit cancel or submit
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            
            void submitChange() async {
              // 1. Basic Validation
              if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
                setState(() => errorMessage = "All fields are required.");
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                setState(() => errorMessage = "New passwords do not match.");
                return;
              }
              if (newCtrl.text.length < 4) {
                setState(() => errorMessage = "Password must be at least 4 characters.");
                return;
              }

              // 2. Process the change
              setState(() {
                isLoading = true;
                errorMessage = null;
              });

              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final resultError = await authProvider.changePassword(currentCtrl.text, newCtrl.text);

              if (context.mounted) {
                if (resultError != null) {
                  // Failed (Probably wrong current password)
                  setState(() {
                    isLoading = false;
                    errorMessage = resultError;
                  });
                } else {
                  // Success!
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.red.shade100,
                      child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: currentCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context), 
                  child: const Text('Cancel')
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : submitChange,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update Security'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    // Dynamically build the screens based on role
    final List<Widget> screens = [
      const InventoryScreen(),
      const POSScreen(),
      if (isAdmin) const RestockScreen(), 
      if (isAdmin) const SupplierScreen(),
      if (isAdmin) const ReportsScreen(), 
      if (isAdmin) const DebtsScreen(),   
      if (isAdmin) const StaffScreen(),
    ];

    // Dynamically build the menu icons based on role
    final List<NavigationRailDestination> destinations = [
      const NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Inventory')),
      const NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('POS')),
      if (isAdmin) const NavigationRailDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: Text('Restock')), 
      if (isAdmin) const NavigationRailDestination(icon: Icon(Icons.domain_outlined), selectedIcon: Icon(Icons.domain), label: Text('Suppliers')),
      if (isAdmin) const NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Reports')),
      if (isAdmin) const NavigationRailDestination(icon: Icon(Icons.money_off_csred_outlined), selectedIcon: Icon(Icons.money_off), label: Text('Debts')),
      if (isAdmin) const NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Staff')), 
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MEDLANE HEALTHCARE PHARMACY'),
        actions: [
          // --- UPGRADED LIVE NOTIFICATION BELL ---
          Consumer<NotificationProvider>( 
            builder: (context, notifProvider, child) {
              
              // Get the current number of notifications using your actual variable
              int notifCount = notifProvider.totalAlerts; 
              
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, size: 28),
                    onPressed: () {
                      // Refresh alerts right before opening just to be safe
                      notifProvider.checkAlerts().then((_) {
                        _showNotificationPanel(context);
                      });
                    },
                  ),
                  // Only show the red dot if there are actually notifications!
                  if (notifCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          notifCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
          // --- NEW: PROFILE & SETTINGS DROPDOWN ---
          // --- UPGRADED: ROLE-BASED PROFILE DROPDOWN ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, size: 30),
            tooltip: 'Account Settings',
            onSelected: (value) {
              if (value == 'change_password') {
                _showChangePasswordDialog(context);
              } else if (value == 'logout') {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Dynamically show Admin or Staff label
              PopupMenuItem<String>(
                value: 'header',
                enabled: false,
                child: Text(isAdmin ? 'Admin Account' : 'Staff Account', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              const PopupMenuDivider(),
              
              // --- ONLY SHOW IF ADMIN ---
              if (isAdmin)
                const PopupMenuItem<String>(
                  value: 'change_password',
                  child: ListTile(
                    leading: Icon(Icons.lock_reset),
                    title: Text('Change Password'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex >= destinations.length ? 0 : _selectedIndex, 
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: destinations,
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: 'Log Out',
                    onPressed: () {
                      authProvider.logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: screens[_selectedIndex >= screens.length ? 0 : _selectedIndex]),
        ],
      ),
    );
  }
}