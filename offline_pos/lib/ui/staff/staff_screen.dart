import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StaffProvider>(context, listen: false).loadCashiers();
    });
  }

  void _showAddCashierDialog(BuildContext context) {
    final fNameCtrl = TextEditingController();
    final lNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Register New Cashier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: fNameCtrl, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: lNameCtrl, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Login Username', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Login Password', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (fNameCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                
                final error = await Provider.of<StaffProvider>(context, listen: false).addCashier(
                  userCtrl.text.trim(), fNameCtrl.text.trim(), lNameCtrl.text.trim(), phoneCtrl.text.trim(), passCtrl.text
                );
                
                if (context.mounted) {
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cashier added!'), backgroundColor: Colors.green));
                  }
                }
              },
              child: const Text('Create Account'),
            ),
          ],
        );
      },
    );
  }

  void _showStaffProfile(BuildContext context, Map<String, dynamic> cashier) {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${cashier['first_name']} ${cashier['last_name']} (Profile)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone: ${cashier['phone'].isNotEmpty ? cashier['phone'] : 'N/A'}', style: const TextStyle(fontSize: 16)),
              Text('Username: ${cashier['name']}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              const Text('Reset Password:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 5),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Force Reset Password'),
                onPressed: () async {
                  if (passCtrl.text.isNotEmpty) {
                    await Provider.of<StaffProvider>(context, listen: false).resetPassword(cashier['id'], passCtrl.text);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green));
                    }
                  }
                },
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCashierDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('New Cashier'),
      ),
      body: Consumer<StaffProvider>(
        builder: (context, provider, child) {
          if (provider.cashiers.isEmpty) return const Center(child: Text("No cashiers registered."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.cashiers.length,
            itemBuilder: (context, index) {
              final cashier = provider.cashiers[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                  title: Text('${cashier['first_name']} ${cashier['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('Username: ${cashier['name']}'),
                  // Make the whole tile clickable!
                  onTap: () => _showStaffProfile(context, cashier),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: 'Delete Account',
                    onPressed: () async {
                      // 1. Show Confirmation Dialog
                      bool confirm = await showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete Staff Account?'),
                          content: Text('Are you sure you want to permanently delete the account for ${cashier['first_name']}? They will immediately lose access to the POS.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ?? false;

                      // 2. Execute Deletion if confirmed
                      if (confirm && context.mounted) {
                        await provider.deleteCashier(cashier['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Staff account deleted successfully!'), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}