import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';

class AddProductDialog extends StatefulWidget {
  final String? initialBarcode;
  
  const AddProductDialog({super.key, this.initialBarcode});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _barcodeController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController(text: '5'); 
  final TextEditingController _expiryController = TextEditingController(); 
  
  // --- ADDED: WHOLESALE PRICE CONTROLLER ---
  final TextEditingController _wholesalePriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.initialBarcode ?? '');
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _minStockController.dispose(); 
    _expiryController.dispose(); 
    _wholesalePriceController.dispose(); // --- ADDED DISPOSE ---
    super.dispose();
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      
      // AUTO-GENERATE BARCODE IF EMPTY
      String finalBarcode = _barcodeController.text.trim();
      if (finalBarcode.isEmpty) {
        finalBarcode = "SYS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
      }

      // --- SAFELY PARSE OPTIONAL WHOLESALE PRICE ---
      double? parsedWholesalePrice;
      if (_wholesalePriceController.text.trim().isNotEmpty) {
        parsedWholesalePrice = double.tryParse(_wholesalePriceController.text.trim());
      }

      final newProduct = Product(
        barcode: finalBarcode,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        quantity: int.parse(_quantityController.text),
        priceSingle: double.parse(_priceController.text),
        priceWholesale: parsedWholesalePrice, // --- PASS IT HERE ---
        minStock: int.parse(_minStockController.text),
        expiryDate: _expiryController.text.trim(), 
      );

      final errorMsg = await Provider.of<InventoryProvider>(context, listen: false).addProduct(newProduct);

      if (mounted) {
        if (errorMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        } else {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added successfully!'), backgroundColor: Colors.green));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Drug'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode (Leave blank to auto-generate)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              
               TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Drug Name', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              
              // --- THE NEW CALENDAR PICKER FIELD ---
              TextFormField(
                controller: _expiryController,
                readOnly: true, // Prevents keyboard from popping up!
                decoration: const InputDecoration(
                  labelText: 'Expiry Date', 
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month, color: Colors.blue), // Added a nice icon
                ),
                validator: (value) => value!.isEmpty ? 'Expiry Date is required!' : null,
                onTap: () async {
                  // Show the calendar dialog when they click the field
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(), // Expiry date can't be in the past!
                    lastDate: DateTime(2050),
                  );

                  if (pickedDate != null) {
                    // Instantly format and insert the date into the text field
                    String formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    setState(() {
                      _expiryController.text = formattedDate;
                    });
                  }
                },
              ),
              // -------------------------------------
              
              const SizedBox(height: 10),
              TextFormField(
                controller: _minStockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min Stock Warning', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (int.tryParse(value) == null || int.parse(value) < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 10),
             
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category (e.g., Painkiller)', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Initial Quantity', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Selling Price (₦)', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // --- ADDED: WHOLESALE PRICE INPUT ---
              TextFormField(
                controller: _wholesalePriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Wholesale Price (₦) - Optional', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                // No validator needed, it's optional!
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveProduct,
          child: const Text('Save Product'),
        ),
      ],
    );
  }
}