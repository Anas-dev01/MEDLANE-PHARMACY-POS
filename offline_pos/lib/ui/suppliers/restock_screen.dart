import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restock_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final TextEditingController _scanController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  
  Product? _scannedProduct;
  int? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestockProvider>(context, listen: false).loadSuppliers();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  void _showAddSupplierDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Company/Supplier Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await Provider.of<RestockProvider>(context, listen: false).addSupplier(nameCtrl.text, phoneCtrl.text, '');
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restock & Purchases')),
      body: Consumer<RestockProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. THE SCANNER
                TextField(
                  controller: _scanController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Scan Drug Barcode to Restock',
                    prefixIcon: Icon(Icons.qr_code_scanner, size: 30),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (val) async {
                    if (val.isEmpty) return;
                    final product = await provider.getProductByBarcode(val.trim());
                    if (product != null) {
                      setState(() => _scannedProduct = product);
                      _scanController.clear();
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drug not found! Add it in Inventory first.'), backgroundColor: Colors.red));
                      }
                      _scanController.clear();
                    }
                  },
                ),
                const SizedBox(height: 30),

                // 2. THE FORM (Only shows if a drug is scanned)
                if (_scannedProduct != null) ...[
                  Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2, color: Colors.blue, size: 40),
                      title: Text('Restocking: ${_scannedProduct!.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      subtitle: Text('Current Stock in System: ${_scannedProduct!.quantity}', style: const TextStyle(fontSize: 16)),
                      trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() => _scannedProduct = null)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Select Supplier', border: OutlineInputBorder()),
                          value: _selectedSupplierId,
                          items: provider.suppliers.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                          onChanged: (val) => setState(() => _selectedSupplierId = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showAddSupplierDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('New Supplier'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                      )
                    ],
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity Received (Boxes/Cards)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.add_box)),
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(child: TextField(controller: _costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Invoice Cost (₦)', border: OutlineInputBorder()))),
                      const SizedBox(width: 15),
                      Expanded(child: TextField(controller: _paidController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Paid to Supplier Now (₦)', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      icon: const Icon(Icons.save),
                      label: const Text('SAVE RESTOCK RECORD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (_selectedSupplierId == null || _qtyController.text.isEmpty || _costController.text.isEmpty || _paidController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields!'), backgroundColor: Colors.red));
                          return;
                        }

                        final cashierName = Provider.of<AuthProvider>(context, listen: false).currentUser?['name'] ?? 'Admin';
                        
                        await provider.processRestock(
                          product: _scannedProduct!,
                          supplierId: _selectedSupplierId!,
                          quantityReceived: int.parse(_qtyController.text),
                          totalCost: double.parse(_costController.text),
                          amountPaid: double.parse(_paidController.text),
                          cashierName: cashierName,
                        );

                        if (context.mounted) {
                          Provider.of<InventoryProvider>(context, listen: false).loadProducts(); // Update inventory table
                          setState(() {
                            _scannedProduct = null;
                            _qtyController.clear();
                            _costController.clear();
                            _paidController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock successfully updated!'), backgroundColor: Colors.green));
                        }
                      },
                    ),
                  )
                ] else 
                  const Center(child: Padding(padding: EdgeInsets.only(top: 50.0), child: Text('Waiting for scanner...', style: TextStyle(fontSize: 20, color: Colors.grey)))),
              ],
            ),
          );
        },
      ),
    );
  }
}