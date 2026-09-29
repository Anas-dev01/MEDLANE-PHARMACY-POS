import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  bool isWholesale; // 1. ADD THIS FLAG

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isWholesale = false, // Default to retail
  });

  // 2. DYNAMIC TOTAL CALCULATION
  double get total {
    // If wholesale is toggled ON, and a wholesale price exists, use it. Otherwise, use single price.
    double activePrice = isWholesale && product.priceWholesale != null 
        ? product.priceWholesale! 
        : product.priceSingle;
        
    return activePrice * quantity;
  }
}