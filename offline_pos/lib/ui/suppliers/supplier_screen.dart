import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restock_provider.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestockProvider>(context, listen: false).loadSuppliers();
    });
  }

  void _showSupplierDialog(BuildContext context, {Map<String, dynamic>? existingSupplier}) {
    final isEditing = existingSupplier != null;
    final nameCtrl = TextEditingController(text: isEditing ? existingSupplier['name'] : '');
    final phoneCtrl = TextEditingController(text: isEditing ? existingSupplier['phone'] : '');
    final addressCtrl = TextEditingController(text: isEditing ? existingSupplier['address'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Supplier' : 'Add New Supplier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Company/Supplier Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address (Optional)', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                
                final provider = Provider.of<RestockProvider>(context, listen: false);
                
                if (isEditing) {
                  await provider.editSupplier(existingSupplier['id'], nameCtrl.text.trim(), phoneCtrl.text.trim(), addressCtrl.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier Updated!'), backgroundColor: Colors.green));
                  }
                } else {
                  final error = await provider.addSupplier(nameCtrl.text.trim(), phoneCtrl.text.trim(), addressCtrl.text.trim());
                  if (context.mounted) {
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier Added!'), backgroundColor: Colors.green));
                    }
                  }
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Create Supplier'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierDialog(context),
        icon: const Icon(Icons.domain_add),
        label: const Text('Add Supplier'),
      ),
      body: Consumer<RestockProvider>(
        builder: (context, provider, child) {
          if (provider.suppliers.isEmpty) {
            return const Center(child: Text("No suppliers found. Add one below.", style: TextStyle(fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.suppliers.length,
            itemBuilder: (context, index) {
              final supplier = provider.suppliers[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.local_shipping, color: Colors.white)),
                  title: Text(supplier['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('Phone: ${supplier['phone'].toString().isNotEmpty ? supplier['phone'] : 'N/A'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showSupplierDialog(context, existingSupplier: supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          bool confirm = await showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Supplier?'),
                              content: Text('Are you sure you want to remove ${supplier['name']}?'),
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

                          if (confirm && context.mounted) {
                            provider.deleteSupplier(supplier['id']);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier deleted.')));
                          }
                        },
                      ),
                    ],
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