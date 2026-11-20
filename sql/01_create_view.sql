/* ============================================================================
   Superstore: reusable view v_superstore
   Adds two derived columns on top of the base table:
     Ship_Days = days between Order_Date and Ship_Date
     Disc_Band = discount bucket used by Q4, Q10 and the Power BI model

   Prerequisite: run 00_data_checks_and_fixes.sql first. Discount must be
   decimal(3,2); with float, 20% lines would land in the wrong band.
   Note: SELECT * is expanded when the view is created. If the base table
   changes, run this script again.
   ============================================================================ */

USE SuperstoreDB;
GO

CREATE OR ALTER VIEW dbo.v_superstore AS
SELECT *,
       DATEDIFF(day, Order_Date, Ship_Date) AS Ship_Days,
       CASE WHEN Discount = 0    THEN '1) 0%'
            WHEN Discount <= 0.2 THEN '2) 1-20%'
            WHEN Discount <= 0.4 THEN '3) 21-40%'
            ELSE '4) >40%' END              AS Disc_Band
FROM dbo.superstore;
GO


/* ============================================================================
   VERIFY THE VIEW
   ============================================================================ */

-- Verify 1: row count
SELECT COUNT(*) AS View_Rows FROM v_superstore;
-- Expected: 9,994

-- Verify 2: totals match the baseline (Check 17a)
SELECT ROUND(SUM(Sales), 2)  AS View_Sales,
       ROUND(SUM(Profit), 2) AS View_Profit
FROM v_superstore;
-- Expected: 2,297,200.86 | 286,397.02

-- Verify 3: derived columns work
SELECT TOP 5 Order_ID, Order_Date, Ship_Date, Ship_Days, Discount, Disc_Band
FROM v_superstore
ORDER BY Row_ID;

-- Verify 4: band boundaries (every discount value lands in the right band)
SELECT Discount, Disc_Band, COUNT(*) AS Lines
FROM v_superstore
GROUP BY Discount, Disc_Band
ORDER BY Discount;
-- Expected:
--   0.00                 -> 1) 0%        4,798
--   0.10 / 0.15 / 0.20   -> 2) 1-20%     94 / 52 / 3,657
--   0.30 / 0.32 / 0.40   -> 3) 21-40%    227 / 27 / 206
--   0.45 to 0.80         -> 4) >40%      11 / 66 / 138 / 418 / 300

-- Verify 5 (Check 17f): band distribution, compared with an Excel pivot
SELECT Disc_Band,
       COUNT(*)                                   AS Lines,
       ROUND(SUM(Sales), 0)                       AS Sales,
       ROUND(SUM(Profit), 0)                      AS Profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1) AS Margin_Pct
FROM v_superstore
GROUP BY Disc_Band
ORDER BY Disc_Band;
-- Expected lines: 4,798 | 3,803 | 460 | 933 (total 9,994)
-- Expected margin: +29.5% | +11.9% | -15.3% | -77.4%