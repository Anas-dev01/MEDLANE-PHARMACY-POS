import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ExportService {
  // Remember to change this to the Master Laptop's IP on deployment day!
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<String?> exportSalesToCSV() async {
    try {
      print("Requesting Master CSV from Server...");
      
      final response = await http.get(Uri.parse('$baseUrl/export-sales'));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
        final filePath = '${directory.path}/Medlane_Master_Sales_$timestamp.csv';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        print("CSV successfully saved to $filePath");
        return filePath; 
        
      } else {
        print("Server rejected export request: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Network Error during export: $e");
      return null;
    }
  }
}