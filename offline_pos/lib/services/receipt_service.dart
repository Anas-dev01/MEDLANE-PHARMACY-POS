import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/cart_item.dart';

class ReceiptService {
  static Future<void> printReceipt({
    required List<CartItem> cart,
    required double grandTotal,
    required double amountPaid,
    required String paymentMethod,
    String? customerName,
  }) async {
    final pdf = pw.Document();

    // Helper function to build the receipt layout so we can print it twice!
    pw.Widget buildReceipt(pw.Context context, String copyType) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          pw.Center(
            child: pw.Text(
              'MEDLANE HEALTHCARE PHARMACY', 
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), // Shrunk from 20 to 16
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Opp. Living Faith Church, Eika Adagu, along Okene Lokoja Road, Okehi L.G.A Kogi State',
              textAlign: pw.TextAlign.center, // Forces proper centering when it wraps
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.Center(child: pw.Text('Tel: 07041523293, 09038950421', style: const pw.TextStyle(fontSize: 10))),
          pw.Center(child: pw.Text('Email: pharmacymediane@gmail.com', style: const pw.TextStyle(fontSize: 10))),
          pw.SizedBox(height: 10),
          
          // --- COPY TYPE IDENTIFIER ---
          pw.Center(
            child: pw.Text(
              '*** $copyType ***', 
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)
            ),
          ),
          pw.Divider(thickness: 1),
          
          // --- DATE & INFO ---
          pw.Text('Date: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Payment: $paymentMethod', style: const pw.TextStyle(fontSize: 10)),
          if (customerName != null && customerName.isNotEmpty) 
            pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(thickness: 1),

          // --- ITEMS TABLE ---
          // FIXED FLEX RATIOS: 3 for Item (widest), 1 for Qty (smallest), 2 for Total (needs room for "NGN")
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            ],
          ),
          pw.SizedBox(height: 5),
          
          ...cart.map((item) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 10))),
                  pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
                  pw.Expanded(flex: 2, child: pw.Text('NGN ${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                ],
              ),
            );
          }),
          
          pw.Divider(thickness: 1),

          // --- TOTALS ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text('NGN ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Amount Paid:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('NGN ${amountPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          
          // Change or Debt logic
          if (amountPaid > grandTotal)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Change:', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('NGN ${(amountPaid - grandTotal).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
              ],
            )
          else if (amountPaid < grandTotal)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Balance Owed:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('NGN ${(grandTotal - amountPaid).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),

          pw.SizedBox(height: 15),
          
          // --- FOOTER ---
          pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Thank you for your patronage!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
                pw.SizedBox(height: 2),
                pw.Text('Wishing you good health.', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 5), 
                pw.Text('Received the above goods in good condition.', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('No return of goods after payment.', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('No refund of money after payment.', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
          pw.SizedBox(height: 10), // A little extra breathing room at the bottom of the cut
        ],
      );
    }

    // ADD PAGE 1: The Customer Copy
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) => buildReceipt(context, "CUSTOMER COPY"),
      ),
    );

    // ADD PAGE 2: The Pharmacy Copy
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) => buildReceipt(context, "PHARMACY COPY"),
      ),
    );

    // Trigger Print
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Pharmacy_Receipt_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}