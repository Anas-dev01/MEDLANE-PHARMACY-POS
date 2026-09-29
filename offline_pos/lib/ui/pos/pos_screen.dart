import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/receipt_service.dart';
import '../../models/cart_item.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter/services.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final TextEditingController _amountPaidController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _scanController = TextEditingController();
  String _paymentMethod = 'Cash'; // Default payment method

  final TextEditingController _discountController = TextEditingController();
  String _discountType = '₦'; // Default to Flat Amount

  @override
  void dispose() {
    _scanController.dispose();
    _amountPaidController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose(); 
    super.dispose();
  }

  // --- NEW: QUANTITY POPUP DIALOG ---
  // --- UPGRADED: QUANTITY POPUP DIALOG WITH VALIDATION ---
  void _showQuantityDialog(BuildContext context, int index, CartItem item, POSProvider provider) {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    String? errorMessage; // This will hold our red error text

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder allows the dialog to rebuild itself to show the error message!
        return StatefulBuilder(
          builder: (context, setState) {
            
            // We put the validation logic in a neat function so both the "Enter" key and "Set" button can use it
            void submitQuantity() {
              int? newQty = int.tryParse(qtyCtrl.text);
              
              if (newQty == null || newQty < 1) {
                setState(() => errorMessage = "Please enter a valid amount.");
                return;
              }
              
              if (newQty > item.product.quantity) {
                setState(() => errorMessage = "Not enough stock! Max available is ${item.product.quantity}.");
                return;
              }

              // If it passes all tests, set the quantity and close!
              provider.setQuantity(index, newQty);
              Navigator.pop(context);
            }

            return AlertDialog(
              title: Text('Set Quantity: ${item.product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    // --- NEW: STRICTLY ALLOW ONLY DIGITS ---
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Enter Amount (Max: ${item.product.quantity})',
                      border: const OutlineInputBorder(),
                      // --- NEW: DYNAMIC ERROR MESSAGE ---
                      errorText: errorMessage, 
                    ),
                    onSubmitted: (val) => submitQuantity(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: submitQuantity,
                  child: const Text('Set'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // --- MULTIPLE RESULTS DIALOG ---
  void _showProductSelectionDialog(BuildContext context, List<dynamic> products, POSProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Drug'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return ListTile(
                  leading: const Icon(Icons.medical_services, color: Colors.blue),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Stock: ${p.quantity} • ₦${p.priceSingle}'),
                  onTap: () {
                    provider.addToCart(p);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        );
      },
    );
  }

  // NOTE: _handleScan was removed because we are moving the logic directly into the TextField's onSubmitted!

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacy Point of Sale')),
      body: Consumer<POSProvider>(
        builder: (context, posProvider, child) {
          return Column(
            children: [
              // --- SCANNER INPUT ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _scanController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Scan Barcode or Type Drug Name', // Updated Label
                    prefixIcon: const Icon(Icons.qr_code_scanner, size: 30),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (val) async {
                    if (val.trim().isEmpty) return;
                    
                    final provider = Provider.of<POSProvider>(context, listen: false);
                    final results = await provider.searchDrug(val.trim());

                    if (context.mounted) {
                      if (results.isEmpty) {
                        // Not found at all
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drug not found!'), backgroundColor: Colors.red));
                      } else if (results.length == 1) {
                        // Exactly one found! Add instantly.
                        provider.addToCart(results.first);
                      } else {
                        // Multiple found! Show the selection popup.
                        _showProductSelectionDialog(context, results, provider);
                      }
                    }
                    
                    _scanController.clear();
                    // Keep focus on the text field so they can keep scanning/typing!
                  },
                ),
              ),

              // --- CART ITEMS ---
              Expanded(
                child: posProvider.cart.isEmpty
                    ? const Center(child: Text("Cart is empty. Scan a drug to begin.", style: TextStyle(fontSize: 18)))
                    : ListView.builder(
                        itemCount: posProvider.cart.length,
                        itemBuilder: (context, index) {
                          final item = posProvider.cart[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.medication, color: Colors.white)),
                              title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('₦${item.product.priceSingle.toStringAsFixed(2)} each (Stock: ${item.product.quantity})'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // --- DECREMENT BUTTON ---
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: item.quantity > 1 ? Colors.blue : Colors.grey,
                                    onPressed: item.quantity > 1 ? () => posProvider.decrementItem(index) : null,
                                  ),
                                  
                                  // --- UPGRADED QUANTITY DISPLAY (CLICKABLE) ---
                                  InkWell(
                                    onTap: () => _showQuantityDialog(context, index, item, posProvider),
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.blue.shade200),
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        item.quantity.toString(),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                    ),
                                  ),
                                  
                                  // --- INCREMENT BUTTON ---
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    color: item.quantity < item.product.quantity ? Colors.blue : Colors.grey,
                                    onPressed: item.quantity < item.product.quantity ? () => posProvider.incrementItem(index) : null,
                                  ),

                                  // --- WHOLESALE TOGGLE ---
                                  if (item.product.priceWholesale != null && item.product.priceWholesale! > 0)
                                    Row(
                                      children: [
                                        const Text('  WS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                                        Switch(
                                          value: item.isWholesale,
                                          activeColor: Colors.purple,
                                          onChanged: (val) => posProvider.toggleWholesale(index, val),
                                        ),
                                      ],
                                    ),
                                  
                                  const SizedBox(width: 15), 
                                  
                                  // --- TOTAL PRICE ---
                                  SizedBox(
                                    width: 80, 
                                    child: Text(
                                      '₦${item.total.toStringAsFixed(2)}', 
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ),
                                  
                                  // --- DELETE BUTTON ---
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => posProvider.removeItem(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // --- CHECKOUT PANEL ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: const Border(top: BorderSide(color: Colors.blue, width: 2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Side: Totals, Discount, and Amount Paid
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (Provider.of<AuthProvider>(context).isAdmin)
                            Row(
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: TextField(
                                    controller: _discountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Admin Discount', border: OutlineInputBorder(), isDense: true),
                                    onChanged: (val) {
                                      double amount = double.tryParse(val) ?? 0.0;
                                      posProvider.setDiscount(amount, _discountType == '%');
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: _discountType,
                                  items: ['₦', '%'].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (newVal) {
                                    setState(() => _discountType = newVal!);
                                    double amount = double.tryParse(_discountController.text) ?? 0.0;
                                    posProvider.setDiscount(amount, _discountType == '%');
                                  },
                                ),
                              ],
                            ),
                          if (Provider.of<AuthProvider>(context).isAdmin) const SizedBox(height: 10),

                          Text('Subtotal: ₦${posProvider.subTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                          Text('Grand Total: ₦${posProvider.grandTotal.toStringAsFixed(2)}', 
                               style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 10),
                          
                          // Amount Paid Input
                          SizedBox(
                            width: 280, 
                            child: TextField(
                              controller: _amountPaidController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Amount Customer Paid (₦)',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade100,
                                      foregroundColor: Colors.green.shade800,
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      _amountPaidController.text = posProvider.grandTotal.toStringAsFixed(2);
                                      setState(() {}); 
                                    },
                                    child: const Text('EXACT', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              onChanged: (val) => setState(() {}), 
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Dynamic Change / Debt Calculator
                          Builder(
                            builder: (context) {
                              double paid = double.tryParse(_amountPaidController.text) ?? 0.0;
                              double diff = paid - posProvider.grandTotal;
                              
                              if (posProvider.grandTotal == 0) return const SizedBox.shrink();

                              if (diff >= 0) {
                                return Text('Change to return: ₦${diff.toStringAsFixed(2)}', 
                                            style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold));
                              } else {
                                return Text('Customer Owes: ₦${diff.abs().toStringAsFixed(2)}', 
                                            style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold));
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Middle: Customer Info (Only shows if owing)
                    Expanded(
                      flex: 2,
                      child: Builder(
                        builder: (context) {
                          double paid = double.tryParse(_amountPaidController.text) ?? 0.0;
                          if (paid >= posProvider.grandTotal || posProvider.grandTotal == 0) {
                            return const SizedBox.shrink(); 
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Debt Detected! Customer Info Required:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              TextField(
                                controller: _customerNameController,
                                decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                controller: _customerPhoneController,
                                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                              ),
                            ],
                          );
                        }
                      ),
                    ),

                    // Right Side: Complete Button
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          DropdownButton<String>(
                            value: _paymentMethod,
                            items: <String>['Cash', 'Transfer', 'Card (POS)'].map((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                            onChanged: (newValue) => setState(() => _paymentMethod = newValue!),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('COMPLETE SALE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            onPressed: posProvider.cart.isEmpty ? null : () async {
                              double paid = double.tryParse(_amountPaidController.text) ?? 0.0;
                              
                              if (paid < posProvider.grandTotal && _customerNameController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a Customer Name for this debt!'), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              final receiptCart = List<CartItem>.from(posProvider.cart);
                              final receiptTotal = posProvider.grandTotal;
                              final customerName = _customerNameController.text;

                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              final currentCashier = authProvider.currentUser?['name'] ?? 'Unknown';

                              await posProvider.checkout(
                                context, // <--- ADD THIS HERE!
                                _paymentMethod, 
                                amountPaid: paid,
                                customerName: customerName,
                                customerPhone: _customerPhoneController.text,
                                cashierName: currentCashier,
                              );
                              
                              await ReceiptService.printReceipt(
                                cart: receiptCart,
                                grandTotal: receiptTotal,
                                amountPaid: paid,
                                paymentMethod: _paymentMethod,
                                customerName: customerName.isNotEmpty ? customerName : null,
                              );
                              
                              if (!context.mounted) return;
                              
                              _amountPaidController.clear();
                              _customerNameController.clear();
                              _customerPhoneController.clear();
                              _discountController.clear(); 
                              posProvider.setDiscount(0, false); 
                              Provider.of<InventoryProvider>(context, listen: false).loadProducts();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sale & Records Saved Successfully!'), backgroundColor: Colors.green),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}