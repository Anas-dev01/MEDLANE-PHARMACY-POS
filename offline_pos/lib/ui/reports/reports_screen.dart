import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import '../../services/export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Analytics Dashboard'),
        actions: [
          Consumer<ReportProvider>(
            builder: (context, provider, child) {
              final dateText = "${provider.selectedDate.year}-${provider.selectedDate.month.toString().padLeft(2, '0')}-${provider.selectedDate.day.toString().padLeft(2, '0')}";
              
              return OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                icon: const Icon(Icons.calendar_month),
                label: Text('Viewing: $dateText', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: provider.selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && picked != provider.selectedDate) {
                    Provider.of<ReportProvider>(context, listen: false).loadReport(date: picked);
                  }
                },
              );
            }
          ),
          const SizedBox(width: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel (CSV)'),
            onPressed: () async {
              final path = await ExportService.exportSalesToCSV();
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Success! Saved to: $path'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 6),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export failed.'), backgroundColor: Colors.red),
                );
              }
            },
          ),
          const SizedBox(width: 10),
          
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
            onPressed: () => Provider.of<ReportProvider>(context, listen: false).loadReport(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          // 1. Changed Padding + Column to a scrollable ListView
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- ROW 1: SALES METRICS ---
              Row(
                children: [
                  Expanded(child: _buildStatCard('Today\'s Revenue', '₦${provider.todayRevenue.toStringAsFixed(2)}', Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Transactions Today', provider.todaySalesCount.toString(), Colors.blue)),
                ],
              ),
              const SizedBox(height: 16),

              // --- ROW 2: FINANCIAL INVENTORY METRICS ---
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Value (Retail)', '₦${provider.totalRetailValue.toStringAsFixed(2)}', Colors.purple)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Total Value (Wholesale)', '₦${provider.totalWholesaleValue.toStringAsFixed(2)}', Colors.teal)),
                ],
              ),
              const SizedBox(height: 16),

              // --- ROW 3: PHYSICAL INVENTORY METRICS ---
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Unique Drugs', provider.totalUniqueProducts.toString(), Colors.orange)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Total Stock (Units)', provider.totalItemsOnHand.toString(), Colors.indigo)),
                ],
              ),
              const SizedBox(height: 30),

              // --- RECENT SALES TABLE ---
              const Text('Recent Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              
              // 2. Removed "Expanded" and added shrinkWrap/physics to the inner ListView
              provider.recentSales.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text("No sales recorded.")),
                    )
                  : ListView.builder(
                      shrinkWrap: true, // <--- THE MAGIC FIX
                      physics: const NeverScrollableScrollPhysics(), // <--- Lets the main dashboard handle the scrolling
                      itemCount: provider.recentSales.length,
                      itemBuilder: (context, index) {
                        final log = provider.recentSales[index];
                        
                        final dateObj = DateTime.parse(log['datetime']);
                        final timeStr = "${dateObj.hour.toString().padLeft(2, '0')}:${dateObj.minute.toString().padLeft(2, '0')}";
                        
                        final logType = log['log_type']; 
                        final totalAmount = log['total_amount'] as double;
                        final amountPaid = log['amount_paid'] as double;
                        final entityName = log['entity_name'] ?? 'Walk-in';
                        final productName = log['product_name']; // <--- ADD THIS LINE

                        Color cardColor = Colors.white;
                        Color iconBgColor = Colors.blue.shade50;
                        Color iconColor = Colors.blue.shade700;
                        IconData cardIcon = Icons.receipt_long;
                        String titlePrefix = 'Sale #${log['id']}';

                        if (logType == 'REPAYMENT') {
                          cardColor = Colors.green.shade50; iconBgColor = Colors.green.shade100; iconColor = Colors.green;
                          cardIcon = Icons.price_check; titlePrefix = 'Debt Recovery';
                        } else if (logType == 'RESTOCK') {
                          cardColor = Colors.orange.shade50; iconBgColor = Colors.orange.shade100; iconColor = Colors.orange;
                          cardIcon = Icons.local_shipping; titlePrefix = 'Restock Paid';
                        } else if (logType == 'SHRINKAGE') {
                          cardColor = Colors.red.shade50; iconBgColor = Colors.red.shade100; iconColor = Colors.red;
                          cardIcon = Icons.warning_amber; titlePrefix = 'Stock Loss';
                        }

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(backgroundColor: iconBgColor, child: Icon(cardIcon, color: iconColor)),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$titlePrefix • $entityName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text('$timeStr • By ${log['cashier_name']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // If it's a restock AND we have the name, show the drug name!
                                    if (logType == 'RESTOCK' && productName != null)
                                      Text(
                                        '$productName', 
                                        style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade800),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else
                                      // Otherwise, just show the normal item count
                                      Text('${log['item_count']} items', style: const TextStyle(fontWeight: FontWeight.w500)),
                                    
                                    const SizedBox(height: 4),
                                    
                                    // For restocks, show the quantity added. For sales, show Cash/POS.
                                    Text(
                                      logType == 'RESTOCK' ? 'Qty Added: ${log['item_count']}' : '${log['payment_type'] ?? ''}', 
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                                
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (logType == 'SHRINKAGE')
                                        const Text('LOSS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red))
                                    else 
                                      Text(
                                        logType == 'RESTOCK' ? '- ₦${amountPaid.toStringAsFixed(2)}' : '+ ₦${amountPaid.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: logType == 'RESTOCK' ? Colors.orange : (amountPaid < totalAmount ? Colors.orange : Colors.green)),
                                      ),
                                      
                                    if (logType == 'SALE' && amountPaid < totalAmount)
                                      Text('Debt: ₦${(totalAmount - amountPaid).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                                    if (logType == 'RESTOCK' && amountPaid < totalAmount)
                                      Text('Owed: ₦${(totalAmount - amountPaid).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                                      
                                    if (logType == 'SALE' && log['discount'] != null && log['discount'] > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                                        child: Text('Discount: ₦${(log['discount'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                                      )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          );
        },
      ),
    );
  }

  // Helper widget to draw the compact, sleek stat cards
  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12), // Shrink padding from 24 to 12
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8), // Tighter corners
        border: Border.all(color: color.withOpacity(0.5), width: 1.5), // Slightly thinner border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Forces the column to wrap tightly
        children: [
          Text(
            title, 
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold), // Shrunk from 18 to 13
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4), // Shrunk spacing from 10 to 4
          Text(
            value, 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87), // Shrunk from 32 to 20
            maxLines: 1, // Prevents giant numbers from pushing the card height down
            overflow: TextOverflow.ellipsis, 
          ),
        ],
      ),
    );
  }
}