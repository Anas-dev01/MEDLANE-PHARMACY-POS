import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/debt_provider.dart';
// 1. ADD THIS IMPORT SO WE CAN FIND THE CASHIER
import '../../providers/auth_provider.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DebtProvider>(context, listen: false).loadDebts();
    });
  }

  // A dialog to ask how much the customer is paying right now
  void _showSettleDialog(BuildContext context, Map<String, dynamic> debt) {
    final TextEditingController amountController = TextEditingController();
    final double currentDebt = debt['amount'] as double;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Settle Debt: ${debt['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Owed: ₦${currentDebt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount Paying Now (₦)',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                final double amountPaid = double.tryParse(amountController.text) ?? 0.0;
                if (amountPaid > 0) {
                  // 2. GET THE LOGGED IN CASHIER
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final currentCashier = authProvider.currentUser?['name'] ?? 'Admin';

                  // 3. PASS ALL 5 ARGUMENTS TO THE PROVIDER
                  Provider.of<DebtProvider>(context, listen: false).settleDebt(
                    debt['debt_id'], 
                    currentDebt, 
                    amountPaid,
                    currentCashier, // 4th Arg: Who collected the money?
                    'Cash'          // 5th Arg: How did they pay?
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repayment logged successfully!')));
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Debt Management')),
      body: Consumer<DebtProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // --- TOTAL OUTSTANDING SUMMARY ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Total Outstanding Debt', style: TextStyle(fontSize: 18, color: Colors.red)),
                    const SizedBox(height: 10),
                    Text(
                      '₦${provider.totalOutstanding.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),

              // --- DEBTORS LIST ---
              Expanded(
                child: provider.customerDebts.isEmpty
                    ? const Center(child: Text("Awesome! No customers are currently owing.", style: TextStyle(fontSize: 18, color: Colors.green)))
                    : ListView.builder(
                        itemCount: provider.customerDebts.length,
                        itemBuilder: (context, index) {
                          final debt = provider.customerDebts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.person, color: Colors.white)),
                              title: Text(debt['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Text(debt['phone'] ?? 'No phone number provided'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₦${(debt['amount'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                                  ),
                                  const SizedBox(width: 15),
                                  ElevatedButton(
                                    onPressed: () => _showSettleDialog(context, debt),
                                    child: const Text('Settle'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}