# ☕ Cafe Sales Data Cleaning — MySQL Project

> Cleaning 10,000 rows of dirty cafe sales data using MySQL Workbench and LOAD DATA INFILE

---

## 📋 Project Overview

This project focuses on importing and cleaning a dirty Cafe Sales CSV dataset using **MySQL**.  
The raw data contained **10,000 rows** with multiple quality issues including invalid text values, missing data, wrong data types, and inconsistent date formats.  
All issues were resolved entirely using **SQL inside MySQL Workbench**.

---

## 📂 Dataset Information

| Column | Data Type | Description |
|---|---|---|
| `Transaction_ID` | VARCHAR(20) | Unique transaction identifier (e.g. TXN_1961373) |
| `Item` | VARCHAR(50) | Product sold (Coffee, Tea, Cake, etc.) |
| `Quantity` | INT | Number of items purchased |
| `Price_Per_Unit` | DECIMAL(10,2) | Price of a single unit |
| `Total_Spent` | DECIMAL(10,2) | Total transaction value |
| `Payment_Method` | VARCHAR(50) | Payment type (Cash, Credit Card, Digital Wallet) |
| `Location` | VARCHAR(50) | Where the sale occurred (In-store, Takeaway) |
| `Transaction_Date` | DATE | Date of the transaction |

---

## 🐛 Dirty Data Issues Found

| Column | Issue | Count |
|---|---|---|
| `Item` | NULL values + `'UNKNOWN'` + `'ERROR'` text | 333 empty |
| `Quantity` | NULL values + `'ERROR'` text values | 479 NULLs |
| `Price_Per_Unit` | NULL values + `'ERROR'` text values | 533 NULLs |
| `Total_Spent` | NULL + `'ERROR'` + `'UNKNOWN'` (stored as text) | 173 NULLs |
| `Payment_Method` | NULL + `'UNKNOWN'` + `'ERROR'` | 2,579 NULLs |
| `Location` | NULL + `'UNKNOWN'` + `'ERROR'` | 3,265 NULLs |
| `Transaction_Date` | NULL values + wrong format (MM/DD/YYYY) | 460 NULLs |

---

## 🔢 Step-by-Step Process

### Step 1 — Create the Database & Table

```sql
CREATE TABLE cafe_sales (
    transaction_id    VARCHAR(20),
    item              VARCHAR(50),
    quantity          INT,
    price_per_unit    DECIMAL(10, 2),
    total_spent       DECIMAL(10, 2),
    payment_method    VARCHAR(50),
    location          VARCHAR(50),
    transaction_date  DATE
);
```

---

### Step 2 — Load Data Using LOAD DATA INFILE

The CSV was placed in MySQL's secure upload folder (`secure_file_priv` path).  
Variables were used to safely handle dirty values during import:

```sql
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dirty_cafe_sales.csv'
INTO TABLE cafe_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, item, @qty, @price, @total, payment_method, location, @txn_date)
SET
    quantity         = IF(@qty REGEXP '^[0-9]+$', CAST(@qty AS UNSIGNED), NULL),
    price_per_unit   = IF(@price REGEXP '^[0-9]+\\.?[0-9]*$', CAST(@price AS DECIMAL(10,2)), NULL),
    total_spent      = IF(@total REGEXP '^[0-9]+\\.?[0-9]*$', CAST(@total AS DECIMAL(10,2)), NULL),
    transaction_date = IF(TRIM(@txn_date) REGEXP '^[0-9]', STR_TO_DATE(TRIM(@txn_date), '%m/%d/%Y'), NULL);
```

---

### Step 3 — Clean Text Columns

Convert `ERROR` and `UNKNOWN` strings to NULL, then fill with `'Unknown'`:

```sql
-- Convert bad text values to NULL
UPDATE cafe_sales
SET
    item           = NULLIF(NULLIF(TRIM(item), 'ERROR'), 'UNKNOWN'),
    payment_method = NULLIF(NULLIF(TRIM(payment_method), 'ERROR'), 'UNKNOWN'),
    location       = NULLIF(NULLIF(TRIM(location), 'ERROR'), 'UNKNOWN');

-- Fill NULLs with 'Unknown'
UPDATE cafe_sales
SET
    item           = COALESCE(item, 'Unknown'),
    payment_method = COALESCE(payment_method, 'Unknown'),
    location       = COALESCE(location, 'Unknown');
```

---

### Step 4 — Fix Numeric NULLs

```sql
UPDATE cafe_sales
SET
    quantity       = COALESCE(quantity, 0),
    price_per_unit = COALESCE(price_per_unit, 0),
    total_spent    = COALESCE(total_spent, 0);
```

---

### Step 5 — Recalculate Wrong Total_Spent

```sql
UPDATE cafe_sales
SET total_spent = ROUND(quantity * price_per_unit, 2)
WHERE total_spent = 0
  AND quantity > 0
  AND price_per_unit > 0;
```

---

### Step 6 — Fix Hidden Empty Strings

```sql
UPDATE cafe_sales
SET
    item           = CASE WHEN TRIM(item)           = '' THEN 'Unknown' ELSE item END,
    payment_method = CASE WHEN TRIM(payment_method) = '' THEN 'Unknown' ELSE payment_method END,
    location       = CASE WHEN TRIM(location)       = '' THEN 'Unknown' ELSE location END;
```

---

## ✅ Final Result

| Metric | Value |
|---|---|
| Total Rows Loaded | 10,000 |
| NULL Values Remaining | 0 |
| Empty String Values Remaining | 0 |
| Warnings During Load | 0 |
| Date Format | YYYY-MM-DD (MySQL standard) |
| Missing Dates | Kept as NULL (honest representation) |

> 🎉 Data is 100% clean — ready for analysis!

---

## 💡 Key Design Decisions

- Used **LOAD DATA INFILE** for performance on large datasets instead of row-by-row INSERT
- Loaded dirty columns into **@variables** during import to safely validate before casting
- Converted `ERROR`/`UNKNOWN` text → `NULL` first, then filled NULLs → `'Unknown'` for consistency
- Left `Transaction_Date` as **NULL** — NULL honestly means "date unknown"
- Used **REGEXP** to validate numeric values before CAST to avoid SQL errors
- Used **forward slashes** in file path — MySQL requires this even on Windows
- Placed CSV in **secure_file_priv** folder — MySQL security requirement for LOAD DATA INFILE

---

## 🛠️ Tools Used

| Tool | Purpose |
|---|---|
| MySQL Workbench 8.0 | Database creation, SQL execution, data inspection |
| LOAD DATA INFILE | Fast bulk import of CSV data |
| UPDATE + COALESCE | NULL value replacement |
| REGEXP | Validation of dirty numeric and date values |
| STR_TO_DATE | Date format conversion from MM/DD/YYYY to DATE |
| NULLIF / COALESCE / IF | Conditional value handling during cleaning |
