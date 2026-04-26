-- ============================================================
--         ☕ Cafe Sales Data Cleaning Project
-- ============================================================
-- Database  : COFFE_SALES
-- Table     : cafe_sales
-- Tool      : MySQL Workbench 8.0
-- Method    : LOAD DATA INFILE
-- Rows      : 10,000
-- ============================================================


-- ============================================================
-- STEP 0: Create & Select The Database
-- ============================================================

CREATE DATABASE IF NOT EXISTS COFFE_SALES;
USE COFFE_SALES;


-- ============================================================
-- STEP 1: Create The Table
-- ============================================================
-- Note: We Start With Loose Column Sizes Then Fix Them After

CREATE TABLE cafe_sales (
    Transaction_ID   VARCHAR(40),
    Item             VARCHAR(50),
    Quantity         INT,
    Price_Per_Unit   DECIMAL(10, 2),
    Total_Spent      DECIMAL(10, 2),
    Payment_Method   VARCHAR(50),
    Location         VARCHAR(220),
    Transaction_Date DATE
);


-- ============================================================
-- STEP 2: Fix Column Sizes Using ALTER TABLE
-- ============================================================
-- Transaction_ID : VARCHAR(40) → VARCHAR(20)  (IDs are short e.g. TXN_1961373)
-- Location       : VARCHAR(220) → VARCHAR(50) (Values are just 'In-store', 'Takeaway')

ALTER TABLE cafe_sales
    MODIFY COLUMN Transaction_ID   VARCHAR(20),
    MODIFY COLUMN Item             VARCHAR(50),
    MODIFY COLUMN Quantity         INT,
    MODIFY COLUMN Price_Per_Unit   DECIMAL(10, 2),
    MODIFY COLUMN Total_Spent      DECIMAL(10, 2),
    MODIFY COLUMN Payment_Method   VARCHAR(50),
    MODIFY COLUMN Location         VARCHAR(50),
    MODIFY COLUMN Transaction_Date DATE;

-- Verify The Table Structure
DESCRIBE cafe_sales;


-- ============================================================
-- STEP 3: Check MySQL Secure Upload Folder Path
-- ============================================================
-- MySQL Only Allows LOAD DATA INFILE From This Folder
-- Place Your CSV File Inside The Path Returned Below

SHOW VARIABLES LIKE 'secure_file_priv';


-- ============================================================
-- STEP 4: Load Data Using LOAD DATA INFILE
-- ============================================================
-- We Use @variables To Safely Handle Dirty Values During Import:
--   - Numeric Columns → Validated With REGEXP Before CAST
--   - Date Column     → Converted From MM/DD/YYYY To MySQL DATE
--   - ERROR/UNKNOWN   → Automatically Become NULL During Load

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dirty_cafe_sales.csv'
INTO TABLE cafe_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, item, @qty, @price, @total, payment_method, location, @txn_date)
SET
    quantity         = IF(@qty   REGEXP '^[0-9]+$',          CAST(@qty   AS UNSIGNED),        NULL),
    price_per_unit   = IF(@price REGEXP '^[0-9]+\\.?[0-9]*$', CAST(@price AS DECIMAL(10, 2)), NULL),
    total_spent      = IF(@total REGEXP '^[0-9]+\\.?[0-9]*$', CAST(@total AS DECIMAL(10, 2)), NULL),
    transaction_date = IF(TRIM(@txn_date) REGEXP '^[0-9]',
                          STR_TO_DATE(TRIM(@txn_date), '%m/%d/%Y'), NULL);

-- Verify Total Rows Loaded
SELECT COUNT(*) AS Total_Rows FROM cafe_sales;

-- Preview First 10 Rows
SELECT * FROM cafe_sales LIMIT 10;


-- ============================================================
-- STEP 5: Replace ERROR & UNKNOWN With NULL On Text Columns
-- ============================================================
-- Why? We Want ONE Consistent Value (NULL) To Work With
-- Then We Will Fill All NULLs Together In The Next Step

UPDATE cafe_sales
SET
    item           = NULLIF(NULLIF(TRIM(item),           'ERROR'), 'UNKNOWN'),
    payment_method = NULLIF(NULLIF(TRIM(payment_method), 'ERROR'), 'UNKNOWN'),
    location       = NULLIF(NULLIF(TRIM(location),       'ERROR'), 'UNKNOWN');


-- ============================================================
-- STEP 6: Recalculate Wrong Total_Spent (Quantity × Price)
-- ============================================================
-- Some Total_Spent Values Were NULL Or Wrong
-- We Recalculate Them Using Quantity × Price_Per_Unit

UPDATE cafe_sales
SET Total_Spent = ROUND(Quantity * Price_Per_Unit, 2)
WHERE Total_Spent  IS NULL
  AND Quantity     IS NOT NULL
  AND Price_Per_Unit IS NOT NULL;


-- ============================================================
-- STEP 7: Check How Many NULLs Remain
-- ============================================================

SELECT
    SUM(CASE WHEN transaction_id   IS NULL THEN 1 ELSE 0 END) AS null_transaction_id,
    SUM(CASE WHEN item             IS NULL THEN 1 ELSE 0 END) AS null_item,
    SUM(CASE WHEN quantity         IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN price_per_unit   IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN total_spent      IS NULL THEN 1 ELSE 0 END) AS null_total,
    SUM(CASE WHEN payment_method   IS NULL THEN 1 ELSE 0 END) AS null_payment,
    SUM(CASE WHEN location         IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN transaction_date IS NULL THEN 1 ELSE 0 END) AS null_date
FROM cafe_sales;


-- ============================================================
-- STEP 8: Replace NULL With 'Unknown' On Text Columns
-- ============================================================

UPDATE cafe_sales
SET
    Item           = COALESCE(Item,           'Unknown'),
    Payment_Method = COALESCE(Payment_Method, 'Unknown'),
    Location       = COALESCE(Location,       'Unknown');


-- ============================================================
-- STEP 9: Replace Empty Strings '' With 'Unknown'
-- ============================================================
-- Some Empty Values Slipped Through As '' Not NULL
-- We Catch And Fix Them Here

UPDATE cafe_sales
SET
    item           = CASE WHEN TRIM(item)           = '' THEN 'Unknown' ELSE item           END,
    payment_method = CASE WHEN TRIM(payment_method) = '' THEN 'Unknown' ELSE payment_method END,
    location       = CASE WHEN TRIM(location)       = '' THEN 'Unknown' ELSE location       END;


-- ============================================================
-- STEP 10: Replace NULL With 0 On Numeric Columns
-- ============================================================

UPDATE cafe_sales
SET
    Quantity       = COALESCE(Quantity,       0),
    Price_Per_Unit = COALESCE(Price_Per_Unit, 0),
    Total_Spent    = COALESCE(Total_Spent,    0);


-- ============================================================
-- STEP 11: Final Verification — Check Everything Is Clean
-- ============================================================
-- All Values Below Should Be 0

SELECT
    COUNT(*)                                                    AS total_rows,
    SUM(CASE WHEN TRIM(item)           = '' THEN 1 ELSE 0 END) AS empty_item,
    SUM(CASE WHEN TRIM(payment_method) = '' THEN 1 ELSE 0 END) AS empty_payment,
    SUM(CASE WHEN TRIM(location)       = '' THEN 1 ELSE 0 END) AS empty_location,
    SUM(CASE WHEN item           IS NULL THEN 1 ELSE 0 END)    AS null_item,
    SUM(CASE WHEN quantity       IS NULL THEN 1 ELSE 0 END)    AS null_quantity,
    SUM(CASE WHEN price_per_unit IS NULL THEN 1 ELSE 0 END)    AS null_price,
    SUM(CASE WHEN total_spent    IS NULL THEN 1 ELSE 0 END)    AS null_total,
    SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END)    AS null_payment,
    SUM(CASE WHEN location       IS NULL THEN 1 ELSE 0 END)    AS null_location
FROM cafe_sales;

-- ============================================================
-- ✅ Data Is 100% Clean — Ready For Analysis!
-- ============================================================
