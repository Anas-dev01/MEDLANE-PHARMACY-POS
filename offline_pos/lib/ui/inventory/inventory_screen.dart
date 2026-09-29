import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart'; // REQUIRED FOR ADMIN CHECK
import '../../models/product.dart'; // REQUIRED FOR EDIT/ADJUST
import 'add_product_dialog.dart';

// 1. Change to StatefulWidget so we can manage a TextController for the scanner
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _scanController = TextEditingController();

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  // --- NEW DIALOG: QUICK ADJUST (SHRINKAGE LOGGING) ---
  void _showAdjustDialog(BuildContext context, Product product) {
    final qtyController = TextEditingController(text: product.quantity.toString());
    String selectedReason = 'Damaged/Broken';
    final List<String> reasons = ['Damaged/Broken', 'Expired', 'Stolen', 'Internal Use', 'Data Correction'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Adjust Stock: ${product.name}', style: const TextStyle(color: Colors.orange)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Stock: ${product.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'New Actual Quantity', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: const InputDecoration(labelText: 'Reason for Adjustment', border: OutlineInputBorder()),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => selectedReason = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () async {
                    int? newQty = int.tryParse(qtyController.text);
                    if (newQty != null && newQty != product.quantity) {
                      final cashierName = Provider.of<AuthProvider>(context, listen: false).currentUser?['name'] ?? 'Admin';
                      await Provider.of<InventoryProvider>(context, listen: false)
                          .adjustStock(product.id!, product.quantity, newQty, selectedReason, cashierName);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock Adjusted & Logged!'), backgroundColor: Colors.orange));
                      }
                    }
                  },
                  child: const Text('Save Log'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // --- NEW DIALOG: EDIT EXISTING DRUG ---
  void _showEditDialog(BuildContext context, Product product) {
    final priceCtrl = TextEditingController(text: product.priceSingle.toString());
    final wsCtrl = TextEditingController(text: product.priceWholesale?.toString() ?? '');
    final nameCtrl = TextEditingController(text: product.name);
    final minCtrl = TextEditingController(text: product.minStock.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit: ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Drug Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Retail Price (₦)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: wsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Wholesale Price (₦)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Stock Warning', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final updatedProduct = Product(
                  id: product.id,
                  barcode: product.barcode, 
                  name: nameCtrl.text,
                  category: product.category,
                  quantity: product.quantity, 
                  priceSingle: double.tryParse(priceCtrl.text) ?? product.priceSingle,
                  priceWholesale: double.tryParse(wsCtrl.text),
                  minStock: int.tryParse(minCtrl.text) ?? product.minStock,
                  expiryDate: product.expiryDate,
                );

                final error = await Provider.of<InventoryProvider>(context, listen: false).editProduct(updatedProduct);
                if (context.mounted) {
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated!'), backgroundColor: Colors.green));
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- SECURITY CHECK: Get current user role ---
    final isAdmin = Provider.of<AuthProvider>(context).isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          // --- NEW: BACKUP BUTTON ---
          IconButton(
            icon: const Icon(Icons.download, size: 28),
            tooltip: 'Download CSV Backup',
            onPressed: () async {
              // 1. Show a quick loading message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating Backup...'), duration: Duration(seconds: 1)),
              );
              
              // 2. Trigger the export
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              final resultMessage = await provider.exportInventoryToCSV();
              
              // 3. Show the result to the user
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(resultMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: resultMessage.contains('Success') ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 5), // Keep it open a bit longer so they can read the path
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {},
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // --- THE SCANNER / SEARCH BAR ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _scanController,
                  autofocus: true, // Automatically focuses so it's ready for the scanner!
                  decoration: InputDecoration(
                    labelText: 'Scan Barcode or Search Drug Name',
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _scanController.clear();
                        provider.search('');
                      },
                    ),
                  ),
                  onChanged: (value) {
                    provider.search(value); // Instantly filters the table below!
                  },
                  // --- 2. THE NEW MAGIC SCANNER TRIGGER ---
                  onSubmitted: (value) {
                    if (value.trim().isEmpty) return;
                    
                    // Check if this exact barcode exists in the current inventory
                    final bool drugExists = provider.products.any((p) => p.barcode == value.trim());

                    if (!drugExists) {
                      // It's a new drug! Pop the dialog and pre-fill the barcode
                      showDialog(
                        context: context,
                        builder: (context) => AddProductDialog(initialBarcode: value.trim()),
                      ).then((_) {
                        // Clear the search box after they finish adding the drug
                        _scanController.clear();
                        provider.search('');
                      });
                    } else {
                      // If it does exist, show a quick toast so they know they scanned successfully
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Drug found in inventory!'), 
                          backgroundColor: Colors.green, 
                          duration: Duration(seconds: 1)
                        ),
                      );
                    }
                  },
                ),
              ),
              // --------------------------------

              Expanded(
                child: provider.filteredProducts.isEmpty 
                    ? Center(
                        child: Text(
                          _scanController.text.isNotEmpty 
                            ? "Drug not found. Click '+' to add it." 
                            : "No drugs in inventory. Add some!"
                        )
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('Barcode')),
                              const DataColumn(label: Text('Drug Name')),
                              const DataColumn(label: Text('Category')),
                              const DataColumn(label: Text('Stock')),
                              const DataColumn(label: Text('Price')),
                              const DataColumn(label: Text('Expiry')),
                              // SECURITY GATE: Only show 'Actions' column to Admin
                              if (isAdmin) const DataColumn(label: Text('Actions')), 
                            ],
                            rows: provider.filteredProducts.map((product) { 
                              return DataRow(cells: [
                                DataCell(Text(product.barcode)),
                                DataCell(Text(product.name)),
                                DataCell(Text(product.category)),
                                DataCell(
                                  Text(
                                    product.quantity.toString(),
                                    style: TextStyle(
                                      // FIXED: Now uses the dynamic minStock!
                                      color: product.quantity <= product.minStock 
                                          ? Colors.red 
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(Text('₦${product.priceSingle.toStringAsFixed(2)}')),
                                DataCell(
                                  Text(
                                    product.expiryDate ?? 'NOT SET',
                                    style: TextStyle(
                                      color: product.expiryDate == null ? Colors.red : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // SECURITY GATE: Only show the buttons to Admin
                                if (isAdmin)
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          tooltip: 'Edit Details & Price',
                                          onPressed: () => _showEditDialog(context, product),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                          tooltip: 'Log Shrinkage / Quick Adjust',
                                          onPressed: () => _showAdjustDialog(context, product),
                                        ),
                                      ],
                                    ),
                                  ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddProductDialog(
              initialBarcode: _scanController.text.isNotEmpty ? _scanController.text : null,
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Drug'),
      ),
    );
  }
}