from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import mysql.connector
import csv
import io
from fastapi import Response # Add Response to your existing fastapi imports
from datetime import datetime

app = FastAPI(title="Medlane Pharmacy Central API")

# --- DATABASE CONFIGURATION ---
# For now, we will test this using a local MySQL database on your Kali machine.
# On deployment day, we just change 'localhost' to '192.168.1.10'
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',      # Changed from 'root'
    'password': 'medlane123', # Changed from ''
    'database': 'medlane_central'
}

def get_db_connection():
    return mysql.connector.connect(**DB_CONFIG)

# --- Pydantic Models (Matching your Flutter structure) ---
class Product(BaseModel):
    id: Optional[int] = None
    barcode: str
    name: str
    category: str
    quantity: int
    price_single: float
    price_wholesale: Optional[float] = None
    min_stock: int

class SaleItem(BaseModel):
    product_id: int
    quantity: int
    price: float

class Sale(BaseModel):
    datetime: str
    total_amount: float
    amount_paid: float
    payment_type: str
    cashier_name: str
    customer_id: Optional[int] = None # Flutter's Local Customer ID
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    discount: Optional[float] = 0.0
    items: List[SaleItem]

class Adjustment(BaseModel):
    product_id: int
    old_quantity: int
    new_quantity: int
    reason: str
    cashier_name: str
    datetime: str

class InventoryLog(BaseModel):
    product_id: int
    action: str
    quantity: int
    datetime: str

# --- API ENDPOINTS ---

@app.get("/")
def read_root():
    return {"status": "Medlane Server is Running!"}

# 1. Endpoint for Laptops to pull the Master Inventory
@app.get("/api/products")
def get_products():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Products")
    products = cursor.fetchall()
    conn.close()
    return {"products": products}

# 1.5. NEW: Endpoint to push products directly to the Master DB from GUI
@app.post("/api/sync-product")
def sync_product(product: Product):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # We explicitly insert the ID so the Laptop and Server match perfectly!
        cursor.execute('''
            INSERT INTO Products (id, barcode, name, category, quantity, price_single, price_wholesale, min_stock)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE 
            name=VALUES(name), quantity=VALUES(quantity), price_single=VALUES(price_single)
        ''', (product.id, product.barcode, product.name, product.category, product.quantity, 
              product.price_single, product.price_wholesale, product.min_stock))
        
        conn.commit()
        return {"status": "success", "message": "Product synced to Master Database"}
        
    except Exception as e:
        import traceback
        print("\n=== PRODUCT SYNC CRASH REPORT ===")
        traceback.print_exc()
        print("=================================\n")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


# 2. Endpoint for Laptops to push offline sales
@app.post("/api/sync-sale")
def sync_sale(sale: Sale):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        master_customer_id = None
        amount_owed = sale.total_amount - sale.amount_paid - sale.discount

        # 1. HANDLE CUSTOMER & DEBT LOGIC
        if sale.customer_name and sale.customer_name.strip():
            # Check if this customer already exists in the Master Database (by Phone or Name)
            cursor.execute("SELECT id FROM Customers WHERE phone = %s OR name = %s LIMIT 1", 
                          (sale.customer_phone, sale.customer_name))
            existing_customer = cursor.fetchone()

            if existing_customer:
                master_customer_id = existing_customer[0]
            else:
                # Create a new Master Customer
                cursor.execute("INSERT INTO Customers (name, phone) VALUES (%s, %s)", 
                              (sale.customer_name, sale.customer_phone))
                master_customer_id = cursor.lastrowid

            # If they owe money, log it in the Master Debts table!
            if amount_owed > 0:
                cursor.execute('''
                    INSERT INTO Debts (type, entity_id, amount, status)
                    VALUES ('customer', %s, %s, 'unpaid')
                ''', (master_customer_id, amount_owed))

        # 2. INSERT THE SALE
        cursor.execute('''
            INSERT INTO Sales (datetime, total_amount, amount_paid, payment_type, cashier_name, customer_id, discount)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        ''', (sale.datetime, sale.total_amount, sale.amount_paid, sale.payment_type, 
              sale.cashier_name, master_customer_id, sale.discount))
        
        master_sale_id = cursor.lastrowid
        
        # 3. INSERT ITEMS & DEDUCT INVENTORY
        for item in sale.items:
            cursor.execute('''
                INSERT INTO SaleItems (sale_id, product_id, quantity, price)
                VALUES (%s, %s, %s, %s)
            ''', (master_sale_id, item.product_id, item.quantity, item.price))
            
            cursor.execute('''
                UPDATE Products SET quantity = quantity - %s WHERE id = %s
            ''', (item.quantity, item.product_id))

        conn.commit()
        return {"status": "success", "master_sale_id": master_sale_id}
        
    except Exception as e:
        import traceback
        print("\n=== SYNC CRASH REPORT ===")
        traceback.print_exc()
        print("=========================\n")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/api/dashboard-metrics")
def get_dashboard_metrics():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        # One single query to calculate all 4 metrics instantly
        cursor.execute('''
            SELECT 
                COUNT(id) AS total_unique_products,
                COALESCE(SUM(quantity), 0) AS total_items_on_hand,
                COALESCE(SUM(quantity * price_single), 0) AS total_retail_value,
                COALESCE(SUM(quantity * IFNULL(price_wholesale, 0)), 0) AS total_wholesale_value
            FROM Products
        ''')
        
        metrics = cursor.fetchone()
        
        # Convert Decimals to floats so FastAPI can return them as JSON safely
        return {
            "status": "success", 
            "metrics": {
                "total_unique_products": metrics["total_unique_products"],
                "total_items_on_hand": int(metrics["total_items_on_hand"]),
                "total_retail_value": float(metrics["total_retail_value"]),
                "total_wholesale_value": float(metrics["total_wholesale_value"])
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/api/export-sales")
def export_sales():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        # TWEAKED QUERY: Now joining Customers to get name and phone!
        cursor.execute('''
            SELECT 
                s.id AS receipt_number,
                s.datetime,
                s.cashier_name,
                s.payment_type,
                c.name AS customer_name,
                c.phone AS customer_phone,
                p.name AS product_name,
                si.quantity,
                si.price AS unit_price,
                (si.quantity * si.price) AS total_item_price,
                s.total_amount AS receipt_total
            FROM Sales s
            JOIN SaleItems si ON s.id = si.sale_id
            JOIN Products p ON si.product_id = p.id
            LEFT JOIN Customers c ON s.customer_id = c.id
            ORDER BY s.id DESC
        ''')
        sales_data = cursor.fetchall()

        output = io.StringIO()
        writer = csv.writer(output)
        
        # TWEAKED HEADERS: Perfectly matching your old Flutter layout + Item details
        writer.writerow([
            'Master Receipt ID', 
            'Date', 
            'Time', 
            'Handled By', 
            'Payment Method', 
            'Customer Name',
            'Customer Phone',
            'Drug Name', 
            'Qty Sold', 
            'Unit Price (NGN)', 
            'Item Total (NGN)', 
            'Full Receipt Total (NGN)'
        ])
        
        for row in sales_data:
            # 3. TWEAK: Safely split Date and Time into separate variables in Python
            try:
                # Handles ISO strings like '2026-04-22T23:23:00.000'
                dt_str = str(row['datetime']).replace('Z', '')
                dt_obj = datetime.fromisoformat(dt_str)
                date_part = dt_obj.strftime('%Y-%m-%d')
                time_part = dt_obj.strftime('%H:%M')
            except:
                # Fallback just in case
                date_part = str(row['datetime'])[:10]
                time_part = str(row['datetime'])[11:16] if len(str(row['datetime'])) > 15 else ""

            writer.writerow([
                row['receipt_number'],
                date_part,
                time_part,
                row['cashier_name'] or 'Admin',       # Default to Admin
                row['payment_type'],
                row['customer_name'] or 'Walk-in',    # Default to Walk-in
                row['customer_phone'] or '',
                row['product_name'],
                row['quantity'],
                float(row['unit_price']),
                float(row['total_item_price']),
                float(row['receipt_total'])
            ])

        return Response(
            content=output.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=Medlane_Master_Sales.csv"}
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.post("/api/sync-adjustment")
def sync_adjustment(adj: Adjustment):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute('''
            INSERT INTO Adjustments (product_id, old_quantity, new_quantity, reason, cashier_name, datetime)
            VALUES (%s, %s, %s, %s, %s, %s)
        ''', (adj.product_id, adj.old_quantity, adj.new_quantity, adj.reason, adj.cashier_name, adj.datetime))
        
        # We DO NOT update the Products table quantity here, because Flutter already updated 
        # the Product quantity locally and will sync the updated Product directly!
        
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.post("/api/sync-inventory-log")
def sync_inventory_log(log: InventoryLog):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute('''
            INSERT INTO InventoryLogs (product_id, action, quantity, datetime)
            VALUES (%s, %s, %s, %s)
        ''', (log.product_id, log.action, log.quantity, log.datetime))
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

# Endpoints for Laptop B to pull data FROM the Master
@app.get("/api/sync-products")
def get_products():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Products") # Ensure table name case matches MariaDB
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return data

@app.get("/api/sync-users")
def get_users():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    # Fetching necessary fields for login and role permissions
    cursor.execute("SELECT id, name, first_name, last_name, role, permissions, password FROM Users")
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return data

@app.get("/api/sync-suppliers")
def get_suppliers():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Suppliers")
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return data








        
# To run this on Kali: uvicorn main:app --host 0.0.0.0 --port 8000 --reload