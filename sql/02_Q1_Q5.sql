/* ============================================================================
   Superstore: analysis queries Q1 to Q5 (read-only, SELECT only)
   Prerequisites: 00_data_checks_and_fixes.sql and 01_create_view.sql
   Rule: all time analysis uses Order_Date, never the year inside Order_ID.
   ============================================================================ */

USE SuperstoreDB;
GO

-- Q1: Category and sub-category profitability (worst margin first)
SELECT Category,
       Sub_Category,
       ROUND(SUM(Sales), 0)                       AS Sales,
       ROUND(SUM(Profit), 0)                      AS Profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2) AS Margin_Pct
FROM superstore
GROUP BY Category, Sub_Category
ORDER BY Margin_Pct ASC;
-- Sanity: 17 rows; Sales and Profit add up to about 2,297,201 and 286,397.


-- Q2: Region-wise sales, profit, orders and margin
SELECT Region,
       ROUND(SUM(Sales), 0)                       AS Sales,
       ROUND(SUM(Profit), 0)                      AS Profit,
       COUNT(DISTINCT Order_ID)                   AS Orders,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2) AS Margin_Pct
FROM superstore
GROUP BY Region
ORDER BY SUM(Profit) DESC;
-- Sanity: 4 rows; Sales and Profit add up to about 2,297,201 and 286,397
-- (each row is rounded to whole dollars, so a difference of a few dollars is
-- normal). Orders add up to 5,009, the total from Check 2.


-- Q3: Monthly sales trend with month-over-month growth (LAG)
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1) AS Mth,
           SUM(Sales) AS Sales
    FROM superstore
    GROUP BY YEAR(Order_Date), MONTH(Order_Date)
)
SELECT Mth,
       ROUND(Sales, 0) AS Sales,
       ROUND((Sales - LAG(Sales) OVER (ORDER BY Mth)) * 100.0
             / LAG(Sales) OVER (ORDER BY Mth), 1) AS MoM_Pct
FROM m
ORDER BY Mth;
-- Sanity: 48 rows (Jan 2014 to Dec 2017); MoM_Pct is NULL for the first month.


-- Q3b (helper): the 3 best months by sales and the 3 steepest MoM drops
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1) AS Mth,
           SUM(Sales) AS Sales
    FROM superstore
    GROUP BY YEAR(Order_Date), MONTH(Order_Date)
),
g AS (
    SELECT Mth, Sales,
           (Sales - LAG(Sales) OVER (ORDER BY Mth)) * 100.0
               / LAG(Sales) OVER (ORDER BY Mth) AS MoM_Pct
    FROM m
),
r AS (
    SELECT Mth, Sales, MoM_Pct,
           RANK() OVER (ORDER BY Sales DESC) AS Sales_Rank,
           RANK() OVER (ORDER BY CASE WHEN MoM_Pct IS NULL THEN 1 ELSE 0 END,
                                 MoM_Pct ASC) AS Drop_Rank
    FROM g
)
SELECT Mth,
       ROUND(Sales, 0)   AS Sales,
       ROUND(MoM_Pct, 1) AS MoM_Pct,
       Sales_Rank,
       Drop_Rank
FROM r
WHERE Sales_Rank <= 3 OR Drop_Rank <= 3
ORDER BY Mth;
-- Reading it: Sales_Rank 1 = best month; Drop_Rank 1 = steepest fall vs the
-- previous month. Compare with Q3 by eye before using the numbers.


-- Q4: Margin and profit across discount bands (uses the view)
SELECT Disc_Band,
       COUNT(*)                                   AS Lines,
       ROUND(SUM(Sales), 0)                       AS Sales,
       ROUND(SUM(Profit), 0)                      AS Profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1) AS Margin_Pct
FROM v_superstore
GROUP BY Disc_Band
ORDER BY Disc_Band;
-- Expected (already verified in the view script):
-- 4,798 / 3,803 / 460 / 933 lines; margin +29.5 / +11.9 / -15.3 / -77.4 %


-- Q5: Loss-making sub-categories, biggest loss first
SELECT Sub_Category,
       ROUND(SUM(Sales), 0)                       AS Sales,
       ROUND(SUM(Profit), 0)                      AS Profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2) AS Margin_Pct
FROM superstore
GROUP BY Sub_Category
HAVING SUM(Profit) < 0
ORDER BY SUM(Profit) ASC;
-- Sanity: every row must also appear with a negative Profit in Q1.