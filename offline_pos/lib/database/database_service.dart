import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_system.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7, // BUMPED VERSION TO 7 FOR SYNC FLAGS
      onCreate: _createDB,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'), 
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await db.execute('ALTER TABLE Sales ADD COLUMN cashier_name TEXT DEFAULT "Admin"');
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE Sales ADD COLUMN amount_paid REAL DEFAULT 0.0');
          await db.execute('UPDATE Sales SET amount_paid = total_amount WHERE amount_paid = 0.0');
          await db.execute('''
            CREATE TABLE DebtRepayments (
              id INTEGER PRIMARY KEY AUTOINCREMENT, debt_id INTEGER, amount REAL, datetime TEXT, payment_type TEXT, cashier_name TEXT,
              FOREIGN KEY (debt_id) REFERENCES Debts (id) ON DELETE CASCADE
            )
          ''');
        }
        // Add min_stock to Products
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE Products ADD COLUMN min_stock INTEGER DEFAULT 5');
        }
        // Add Staff Details to Users table
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE Users ADD COLUMN first_name TEXT DEFAULT 'System'");
          await db.execute("ALTER TABLE Users ADD COLUMN last_name TEXT DEFAULT 'Admin'");
          await db.execute("ALTER TABLE Users ADD COLUMN phone TEXT DEFAULT ''");
        }
        
        // 2. NEW MIGRATION: Enterprise Restock & Shrinkage Tables
        if (oldVersion < 6) {
          // A. Suppliers Table (Drops the old basic one if it exists, creates the new detailed one)
          await db.execute('DROP TABLE IF EXISTS Suppliers');
          await db.execute('''
            CREATE TABLE Suppliers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              phone TEXT,
              address TEXT
            )
          ''');

          // B. Purchases (Restock) Table
          await db.execute('''
            CREATE TABLE Purchases (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER,
              product_id INTEGER,
              quantity INTEGER,
              total_cost REAL,
              amount_paid REAL,
              datetime TEXT,
              cashier_name TEXT,
              FOREIGN KEY (supplier_id) REFERENCES Suppliers (id) ON DELETE SET NULL,
              FOREIGN KEY (product_id) REFERENCES Products (id) ON DELETE CASCADE
            )
          ''');

          // C. Adjustments (Shrinkage) Table
          await db.execute('''
            CREATE TABLE Adjustments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL,
              old_quantity INTEGER,
              new_quantity INTEGER,
              reason TEXT NOT NULL,
              datetime TEXT NOT NULL,
              cashier_name TEXT,
              FOREIGN KEY (product_id) REFERENCES Products (id) ON DELETE CASCADE
            )
          ''');
        }

        // 3. NEW MIGRATION: Sync flags for multi-system architecture
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE Sales ADD COLUMN is_synced INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE SaleItems ADD COLUMN is_synced INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE InventoryLogs ADD COLUMN is_synced INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE Purchases ADD COLUMN is_synced INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE Adjustments ADD COLUMN is_synced INTEGER DEFAULT 0');
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const realNullable = 'REAL';

    // 1. Users Table
    await db.execute('''
      CREATE TABLE Users (
        id $idType,
        name $textType, -- We will use this specifically for the Username
        first_name TEXT DEFAULT '', -- ADDED
        last_name TEXT DEFAULT '',  -- ADDED
        phone TEXT DEFAULT '',      -- ADDED
        role $textType,
        permissions $textType,
        password $textType
      )
    ''');

    // 2. Products Table
    await db.execute('''
      CREATE TABLE Products (
        id $idType,
        barcode $textType UNIQUE,
        name $textType,
        category $textType,
        quantity $intType,
        price_single $realType,
        price_wholesale $realNullable,
        expiry_date $textNullable,
        image_path $textNullable,
        min_stock INTEGER NOT NULL DEFAULT 5 -- ADD THIS LINE FOR NEW INSTALLS
      )
    ''');

    // 3. Customers Table
    await db.execute('''
      CREATE TABLE Customers (
        id $idType,
        name $textType,
        phone $textNullable,
        birthday $textNullable
      )
    ''');

    // 4. Suppliers Table (UPDATED to match Version 6 Schema)
    await db.execute('''
      CREATE TABLE Suppliers (
        id $idType,
        name $textType,
        phone $textNullable,
        address $textNullable
      )
    ''');

    // 5. Sales Table
    await db.execute('''
      CREATE TABLE Sales (
        id $idType,
        datetime $textType,
        total_amount $realType,
        amount_paid $realType, -- NEW COLUMN FOR FRESH INSTALLS
        payment_type $textType,
        customer_id INTEGER,
        discount $realType,
        cashier_name $textNullable,
        is_synced INTEGER DEFAULT 0, -- ADDED
        FOREIGN KEY (customer_id) REFERENCES Customers (id) ON DELETE SET NULL
      )
    ''');

    // 6. SaleItems Table
    await db.execute('''
      CREATE TABLE SaleItems (
        id $idType,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity $intType,
        price $realType,
        is_synced INTEGER DEFAULT 0, -- ADDED
        FOREIGN KEY (sale_id) REFERENCES Sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES Products (id) ON DELETE RESTRICT
      )
    ''');

    // 7. InventoryLogs Table
    await db.execute('''
      CREATE TABLE InventoryLogs (
        id $idType,
        product_id INTEGER NOT NULL,
        action $textType,
        quantity $intType,
        datetime $textType,
        is_synced INTEGER DEFAULT 0, -- ADDED
        FOREIGN KEY (product_id) REFERENCES Products (id) ON DELETE CASCADE
      )
    ''');

    // 8. Expenses Table
    await db.execute('''
      CREATE TABLE Expenses (
        id $idType,
        description $textType,
        amount $realType,
        datetime $textType
      )
    ''');

    // 9. Debts Table
    await db.execute('''
      CREATE TABLE Debts (
        id $idType,
        type $textType, 
        entity_id INTEGER NOT NULL,
        amount $realType,
        status $textType,
        due_date $textNullable
      )
    ''');

    // 10. DebtRepayments Table
    await db.execute('''
      CREATE TABLE DebtRepayments (
        id $idType,
        debt_id INTEGER NOT NULL,
        amount $realType,
        datetime $textType,
        payment_type $textType,
        cashier_name $textNullable,
        FOREIGN KEY (debt_id) REFERENCES Debts (id) ON DELETE CASCADE
      )
    ''');
    
    // 11. Purchases (Restock) Table
    await db.execute('''
      CREATE TABLE Purchases (
        id $idType,
        supplier_id INTEGER,
        product_id INTEGER,
        quantity $intType,
        total_cost $realType,
        amount_paid $realType,
        datetime $textType,
        cashier_name $textNullable,
        is_synced INTEGER DEFAULT 0, -- ADDED
        FOREIGN KEY (supplier_id) REFERENCES Suppliers (id) ON DELETE SET NULL,
        FOREIGN KEY (product_id) REFERENCES Products (id) ON DELETE CASCADE
      )
    ''');

    // 12. Adjustments (Shrinkage) Table
    await db.execute('''
      CREATE TABLE Adjustments (
        id $idType,
        product_id INTEGER NOT NULL,
        old_quantity $intType,
        new_quantity $intType,
        reason $textType,
        datetime $textType,
        cashier_name $textNullable,
        is_synced INTEGER DEFAULT 0, -- ADDED
        FOREIGN KEY (product_id) REFERENCES Products (id) ON DELETE CASCADE
      )
    ''');

    // Insert default Admin user
    await db.rawInsert(
      "INSERT INTO Users(name, first_name, last_name, role, permissions, password) VALUES('Admin', 'Super', 'Admin', 'admin', 'all', '1234')"
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}