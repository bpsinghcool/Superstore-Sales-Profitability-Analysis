/* ============================================================================
   Superstore Sales & Profitability: data fixes and data checks
   ----------------------------------------------------------------------------
   WARNING: PART 1 modifies data (UPDATE on Row_ID 7345, ALTER COLUMN Discount).
            PART 2 and PART 3 are read-only (SELECT only).

   Run order:
     PART 0  create database, import the CSV (manual step in SSMS)
     PART 1  fixes (safe to re-run: every statement is idempotent)
     PART 2  data quality checks
     PART 3  reconciliation queries (compared with the Excel side)
     PART 4  Power BI dimension key checks

   Baseline after the fixes: 9,994 rows | Sales 2,297,200.86 | Profit 286,397.02
   Check numbers match the project log (Checks 13-15 live inside Fix B below).
   ============================================================================ */


/* ============================================================================
   PART 0: SETUP
   ============================================================================ */
SELECT @@VERSION;
GO

IF DB_ID('SuperstoreDB') IS NULL
    CREATE DATABASE SuperstoreDB;
GO

USE SuperstoreDB;
GO

-- MANUAL STEP: import the CSV with SSMS -> right-click SuperstoreDB ->
-- Tasks -> Import Flat File -> table name: superstore.
-- Column names without spaces or hyphens (Order_ID, Order_Date, Ship_Date,
-- Ship_Mode, Sub_Category, Product_Name, Customer_Name, Postal_Code).
-- Types chosen in the wizard: dates = date, Sales/Profit/Discount = float,
-- Quantity = int, Postal_Code = varchar(10); Allow Nulls ticked on Profit.


/* ============================================================================
   PART 1: FIXES (modify data)
   ============================================================================ */

/* ---------- Fix A: Row 7345 Profit imported as NULL (Issue 2) ---------- */

-- Diagnostics (before the fix: 1 NULL row; after the fix: 0 rows)
SELECT COUNT(*) AS Null_Profit FROM superstore WHERE Profit IS NULL;
SELECT Row_ID, Profit FROM superstore WHERE Profit IS NULL;

-- Fix: the value -420 was taken from the raw CSV line for Row_ID 7345
UPDATE superstore SET Profit = -420 WHERE Row_ID = 7345;

-- Verify
SELECT Row_ID, Profit FROM superstore WHERE Row_ID = 7345;

SELECT ROUND(SUM(Sales), 2)                                AS Total_Sales,
       ROUND(SUM(Profit), 2)                               AS Total_Profit,
       COUNT(*)                                            AS Total_Rows,
       SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END)     AS Null_Profit_Count,
       COUNT(*) - COUNT(Profit)                            AS Null_Profit_Count_Alt
FROM superstore;
-- Expected: 2,297,200.86 | 286,397.02 | 9,994 | 0 | 0


/* ---------- Fix B: Discount stored as float (Issue 4; Checks 13-15) ---------- */

-- Check 13: floating point diagnostics. Run BEFORE the ALTER.
-- Before the fix: 0.2 appears as 0.200000002980232 and Exactly_0_2 = 0.
SELECT DISTINCT Discount FROM superstore ORDER BY Discount;

SELECT COUNT(*) AS Exactly_0_2 FROM superstore WHERE Discount = 0.2;

SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('Sales', 'Discount', 'Profit');

-- Why it matters: a band such as "Discount <= 0.2" would put every 20% line
-- into the 21-40% band, because the stored float is slightly above 0.2.

-- Step 1: backup (created only once)
IF OBJECT_ID('dbo.superstore_backup_before_discount_fix', 'U') IS NULL
    EXEC('SELECT * INTO dbo.superstore_backup_before_discount_fix FROM dbo.superstore');
GO

-- Step 2: snapshot of counts per discount value before the change
SELECT ROUND(Discount, 2) AS Disc, COUNT(*) AS Lines
FROM superstore
GROUP BY ROUND(Discount, 2)
ORDER BY Disc;

-- Step 3: the fix
ALTER TABLE superstore ALTER COLUMN Discount decimal(3,2) NOT NULL;
GO
-- If the view v_superstore already exists, re-run its CREATE OR ALTER VIEW
-- script afterwards so the view picks up the new column type.

-- Step 4: after-fix checks
SELECT Discount, COUNT(*) AS Lines
FROM superstore
GROUP BY Discount
ORDER BY Discount;

SELECT COUNT(*) AS Exactly_0_2_After_Fix
FROM superstore
WHERE Discount = 0.2;
-- Expected: 3,657

-- Check 14: no discount value changed (compares with the backup)
SELECT COUNT(*) AS Changed_Rows
FROM superstore s
JOIN superstore_backup_before_discount_fix b ON s.Row_ID = b.Row_ID
WHERE ROUND(b.Discount, 2) <> s.Discount;
-- Expected: 0

-- Check 15: distinct discount values
SELECT COUNT(DISTINCT Discount) AS Distinct_Discounts FROM superstore;
-- Expected: 12

-- Step 5: control totals after both fixes
SELECT ROUND(SUM(Sales), 2)  AS Total_Sales,
       ROUND(SUM(Profit), 2) AS Total_Profit,
       COUNT(*)              AS Total_Rows
FROM superstore;
-- Expected: 2,297,200.86 | 286,397.02 | 9,994

/* ============================================================================
   PART 2: DATA QUALITY CHECKS (read-only)
   ============================================================================ */

-- Check 1: row count
SELECT COUNT(*) AS Total_Rows FROM superstore;
-- Expected: 9,994

-- Check 2: distinct orders
SELECT COUNT(DISTINCT Order_ID) AS Total_Orders FROM superstore;
-- Expected: 5,009

-- Check 3: nulls in key measures and dimensions
SELECT COUNT(*) AS Null_Key_Rows
FROM superstore
WHERE Sales IS NULL OR Profit IS NULL
   OR Discount IS NULL OR Order_Date IS NULL;
-- Expected: 0

-- Check 4: date coverage
SELECT MIN(Order_Date) AS First_Order, MAX(Order_Date) AS Last_Order FROM superstore;
-- Expected: 2014-01-03 to 2017-12-30

-- Check 5: product hierarchy shape
SELECT Category,
       COUNT(DISTINCT Sub_Category) AS Sub_Cats,
       COUNT(DISTINCT Product_Name) AS Products
FROM superstore
GROUP BY Category;
-- Expected: Furniture 4, Office Supplies 9, Technology 4 sub-categories

-- Check 6: distinct product names
SELECT COUNT(DISTINCT Product_Name) AS Products FROM superstore;
-- Expected: 1,850

-- Check 7: dates of Row 7345 (raw CSV mixed two date formats in this line)
SELECT Row_ID, Order_Date, Ship_Date,
       DATEDIFF(day, Order_Date, Ship_Date) AS Ship_Days
FROM superstore
WHERE Row_ID = 7345;
-- Expected: 2017-12-11 | 2017-12-17 | 6

-- Check 8: shipping days sanity
SELECT MIN(DATEDIFF(day, Order_Date, Ship_Date)) AS Min_Days,
       MAX(DATEDIFF(day, Order_Date, Ship_Date)) AS Max_Days
FROM superstore;
-- Expected: 0 to 7. Min_Days >= 0 also confirms that no Ship_Date is earlier
-- than its Order_Date; a large Max_Days would point to a mis-parsed date.

-- Check 9: dimension counts
SELECT COUNT(DISTINCT Customer_ID) AS Customers,
       COUNT(DISTINCT Product_ID)  AS Product_IDs,
       COUNT(DISTINCT State)       AS States,
       COUNT(DISTINCT Region)      AS Regions,
       COUNT(DISTINCT Segment)     AS Segments,
       COUNT(DISTINCT Ship_Mode)   AS Ship_Modes,
       COUNT(DISTINCT Category)    AS Categories
FROM superstore;
-- Expected: 793 / 1,862 / 49 / 4 / 3 / 4 / 3

-- Check 10: value ranges
SELECT MIN(Discount) AS Min_Disc, MAX(Discount) AS Max_Disc,
       MIN(Quantity) AS Min_Qty,  MAX(Quantity) AS Max_Qty,
       MIN(Sales)    AS Min_Sales
FROM superstore;
-- Expected: Discount 0 to 0.80 | Quantity 1 to 14 | Min Sales about 0.44

-- Check 11: column count
SELECT COUNT(*) AS Columns_
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'superstore';
-- Expected: 21

-- Check 12a: Order_ID + Product_ID pairs that appear more than once
SELECT s.Row_ID, s.Order_ID, s.Product_ID, s.Sales, s.Quantity, s.Discount, s.Profit
FROM superstore s
JOIN (SELECT Order_ID, Product_ID
      FROM superstore
      GROUP BY Order_ID, Product_ID
      HAVING COUNT(*) > 1) d
  ON s.Order_ID = d.Order_ID AND s.Product_ID = d.Product_ID
ORDER BY s.Order_ID, s.Product_ID, s.Row_ID;
-- Expected: 16 rows (8 pairs)

-- Check 12b: extra copies that are identical in every column except Row_ID
WITH d AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY Order_ID, Product_ID, Sales, Quantity, Discount, Profit
               ORDER BY Row_ID) AS rn
    FROM superstore)
SELECT COUNT(*)              AS Extra_Identical_Copies,
       ROUND(SUM(Sales), 2)  AS Sales_Impact,
       ROUND(SUM(Profit), 2) AS Profit_Impact
FROM d
WHERE rn > 1;
-- Expected: 1 copy (Row_ID 3406 / 3407), Sales 281.37, Profit -12.06.
-- Decision: kept as in the source; the impact is below 0.02% of every total.

-- Checks 13-15: see Fix B in PART 1.

-- Check 16: year inside Order_ID versus year of Order_Date
SELECT COUNT(*) AS Year_Mismatch
FROM superstore
WHERE TRY_CAST(SUBSTRING(Order_ID, 4, 4) AS int) <> YEAR(Order_Date);

SELECT Row_ID, Order_ID, Order_Date, Ship_Date,
       DATEDIFF(day, Order_Date, Ship_Date) AS Ship_Days
FROM superstore
WHERE TRY_CAST(SUBSTRING(Order_ID, 4, 4) AS int) <> YEAR(Order_Date)
ORDER BY Row_ID;
-- Result: 7 rows (Row_IDs 1153, 1154, 2822, 4613, 4614, 5739, 6342).
-- All have Order_Date = 2016-12-31, an Order_ID from the 2017 series and a
-- ship date in January 2017. Kept as in the source. Likely cause: year-end ID
-- series change (not confirmed). Rule: all time analysis uses Order_Date and
-- never the year inside Order_ID.


/* ============================================================================
   PART 3: SOURCE RECONCILIATION (Check 17; results compared with Excel)
   ============================================================================ */

-- Check 17a: master totals
SELECT COUNT(*)              AS Total_Rows,
       ROUND(SUM(Sales), 2)  AS Total_Sales,
       ROUND(SUM(Profit), 2) AS Total_Profit,
       SUM(Quantity)         AS Total_Quantity
FROM superstore;
-- Expected: 9,994 | 2,297,200.86 | 286,397.02 | 37,873

-- Check 17b: date ranges
SELECT MIN(Order_Date) AS Earliest_Order,
       MAX(Order_Date) AS Latest_Order,
       MIN(Ship_Date)  AS Earliest_Ship,
       MAX(Ship_Date)  AS Latest_Ship
FROM superstore;

-- Check 17c: dimension cardinality
SELECT COUNT(DISTINCT Category)     AS Categories,
       COUNT(DISTINCT Sub_Category) AS Sub_Categories,
       COUNT(DISTINCT Region)       AS Regions,
       COUNT(DISTINCT Segment)      AS Segments,
       COUNT(DISTINCT Ship_Mode)    AS Ship_Modes,
       COUNT(DISTINCT State)        AS States,
       COUNT(DISTINCT City)         AS Cities,
       COUNT(DISTINCT Customer_ID)  AS Unique_Customers,
       COUNT(DISTINCT Product_ID)   AS Unique_Products
FROM superstore;

-- Check 17d: sales and profit by category
SELECT Category,
       COUNT(*)              AS Row_Count,
       ROUND(SUM(Sales), 2)  AS Cat_Sales,
       ROUND(SUM(Profit), 2) AS Cat_Profit
FROM superstore
GROUP BY Category
ORDER BY Cat_Sales DESC;

-- Check 17e: row-level spot check
SELECT Row_ID, Order_ID, Order_Date, Product_Name, Sales, Profit
FROM superstore
WHERE Row_ID IN (1000, 2500, 5000, 7345, 9000)
ORDER BY Row_ID;

-- Check 17f (discount-band distribution) is in the view script,
-- Check 18: 01_create_view.sql, because it uses v_superstore.Disc_Band.

/* ============================================================================
   PART 4: POWER BI DIMENSION KEY CHECKS (read-only; Location needs Fix C)
   A relationship "one to many" needs a unique key in the dimension table.
   ============================================================================ */
 
-- Check 19: Dim_Customer, key Customer_ID
SELECT COUNT(*) AS Rows_, COUNT(DISTINCT Customer_ID) AS Keys_
FROM (SELECT DISTINCT Customer_ID, Customer_Name, Segment FROM superstore) t;
-- Result: 793 / 793, the key is unique.
 
-- Check 20: Dim_Product, Product_ID alone
SELECT COUNT(*) AS Rows_, COUNT(DISTINCT Product_ID) AS Keys_
FROM (SELECT DISTINCT Product_ID, Category, Sub_Category, Product_Name
      FROM superstore) t;
-- Result: 1,894 / 1,862. Product_ID is NOT a unique key (some IDs carry more
-- than one product name), so a composite key is needed.
 
-- Check 20b: composite key Product_ID + Product_Name (both numbers must match)
SELECT COUNT(*) AS Rows_,
       COUNT(DISTINCT CONCAT(Product_ID, '|', Product_Name)) AS Keys_
FROM (SELECT DISTINCT Product_ID, Category, Sub_Category, Product_Name
      FROM superstore) t;
-- Result: 1,894 / 1,894

-- Check 20c: which Product_IDs carry more than one name
SELECT Product_ID, COUNT(DISTINCT Product_Name) AS Names
FROM superstore
GROUP BY Product_ID
HAVING COUNT(DISTINCT Product_Name) > 1
ORDER BY Product_ID;
-- Result: 32 Rows with double Product_Name

-- Check 21: Postal Code
SELECT COUNT(DISTINCT Postal_Code) AS Postal_Codes FROM superstore;
-- Expected Result: 631

-- Check 22: Dim_Location, key Postal_Code + City (both numbers must match)
SELECT COUNT(*) AS Rows_,
       COUNT(DISTINCT CONCAT(Postal_Code, '-', City)) AS Keys_
FROM (SELECT DISTINCT Postal_Code, City, Country, Region, State
      FROM superstore) t;
-- Result: 632 / 632