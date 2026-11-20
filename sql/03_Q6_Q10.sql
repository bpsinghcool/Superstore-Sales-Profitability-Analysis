/* ============================================================================
   Superstore: analysis queries Q6 to Q10 (read-only, SELECT only)
   Prerequisites: 00_data_checks_and_fixes.sql and 01_create_view.sql
   Rule: all time analysis uses Order_Date, never the year inside Order_ID.
   ============================================================================ */

USE SuperstoreDB;
GO

-- Q6: Top 3 products per category by sales (ROW_NUMBER), with their profit
SELECT Category, Product_Name, Sales, Profit, Margin_Pct, Rank
FROM (
    SELECT Category,
           Product_Name,
           ROUND(SUM(Sales), 0)                       AS Sales,
           ROUND(SUM(Profit), 0)                      AS Profit,
           ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1) AS Margin_Pct,
           ROW_NUMBER() OVER (PARTITION BY Category
                              ORDER BY SUM(Sales) DESC) AS Rank
    FROM superstore
    GROUP BY Category, Product_Name
) t
WHERE Rank <= 3
ORDER BY Category, Rank;

-- Sanity: 9 rows (3 per category). A plain TOP 3 would return only 3 rows in
-- total, which is why ROW_NUMBER with PARTITION BY is used.


-- Q7: Year-over-year sales, profit and margin
WITH y AS (
    SELECT YEAR(Order_Date) AS Yr,
           SUM(Sales)       AS Sales,
           SUM(Profit)      AS Profit
    FROM superstore
    GROUP BY YEAR(Order_Date)
)
SELECT Yr,
       ROUND(Sales, 0)                                   AS Sales,
       ROUND(Profit, 0)                                  AS Profit,
       ROUND(Profit * 100.0 / Sales, 1)                  AS Margin_Pct,
       ROUND((Sales - LAG(Sales) OVER (ORDER BY Yr)) * 100.0
             / LAG(Sales) OVER (ORDER BY Yr), 1)         AS Sales_Growth_Pct,
       ROUND((Profit - LAG(Profit) OVER (ORDER BY Yr)) * 100.0
             / LAG(Profit) OVER (ORDER BY Yr), 1)        AS Profit_Growth_Pct
FROM y
ORDER BY Yr;
-- Sanity: 4 rows (2014 to 2017); sales add up to about 2,297,201 and profit
-- to about 286,397. The first year has NULL growth.


-- Q8: The cost of discounts above 20%
SELECT CASE WHEN Discount > 0.2 THEN 'Above 20%' ELSE 'Up to 20%' END AS Grp,
       COUNT(*)                                   AS Lines,
       ROUND(SUM(Sales), 0)                       AS Sales,
       ROUND(SUM(Profit), 0)                      AS Profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1) AS Margin_Pct
FROM superstore
GROUP BY CASE WHEN Discount > 0.2 THEN 'Above 20%' ELSE 'Up to 20%' END
ORDER BY Grp;
-- Sanity (from the Q4 bands): 'Above 20%' = bands 3 + 4, about 1,393 lines,
-- sales about 362,770 and profit about -135,376; 'Up to 20%' = bands 1 + 2,
-- about 8,601 lines, sales about 1,934,430 and profit about 421,773.


-- Q9: Ten least profitable states
SELECT TOP 10
       State,
       Region,
       ROUND(SUM(Sales), 0)                       AS Sales,
       ROUND(SUM(Profit), 0)                      AS Profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1) AS Margin_Pct,
       ROUND(AVG(Discount), 2)                    AS Avg_Discount
FROM superstore
GROUP BY State, Region
ORDER BY SUM(Profit) ASC;
-- Sanity: 10 rows. Region is shown so that the region-level view (Q2) can be
-- linked to the state-level view. Avg_Discount helps to see whether heavy
-- discounting goes together with the losses; do not read it as proof.


-- Q10: Profit by sub-category and discount band (pivot, 17 rows)
SELECT Sub_Category,
       ROUND(SUM(CASE WHEN Disc_Band = '1) 0%'     THEN Profit END), 0) AS Band_0,
       ROUND(SUM(CASE WHEN Disc_Band = '2) 1-20%'  THEN Profit END), 0) AS Band_1_20,
       ROUND(SUM(CASE WHEN Disc_Band = '3) 21-40%' THEN Profit END), 0) AS Band_21_40,
       ROUND(SUM(CASE WHEN Disc_Band = '4) >40%'   THEN Profit END), 0) AS Band_Over_40,
       ROUND(SUM(Profit), 0)                                           AS Total_Profit
FROM v_superstore
GROUP BY Sub_Category
ORDER BY Total_Profit;
-- Sanity: 17 rows. A band with no sales for a sub-category shows NULL, not 0.
-- Each band column adds up to the profit of that band in Q4 (about 320,988 /
-- 100,785 / -35,817 / -99,559), and Total_Profit matches Q1.

-- # CHECK POINTS
SELECT ROUND(AVG(Discount), 2) AS Avg_Discount_All FROM superstore;

SELECT MONTH(Order_Date) AS Mon, ROUND(SUM(Sales), 0) AS Sales
FROM superstore GROUP BY MONTH(Order_Date) ORDER BY Mon;