-- =====================================================================
-- Ecommerce Customer Analytics
-- File 1 of 3: customer_analysis.sql
--   Who buys, how often, and what each customer is worth.
--
-- Database: PostgreSQL (Supabase), schema public
-- Data:     25-03-2021 to 25-03-2023 · 1,000 customers · 3,000 orders
--
-- RUN ORDER: customer_analysis.sql -> rfm_analysis.sql -> segmentation_queries.sql
--   Part 1 below builds the base views the other two files depend on.
--   Re-running Part 1 drops sales with CASCADE, which also removes
--   customer_rfm, so run rfm_analysis.sql again afterwards.
--
-- Part 1 creates views only (it never changes table data).
-- Part 2 is read-only (SELECT). No query selects Customer_Name,
-- Customer_Email or Customer_Number.
--
-- Value terms:
--   net_amount      = Units * Price - Discounts (returned orders still counted)
--   realised_amount = net_amount, but 0 when the order was returned (money kept)
--
-- "Result" comments show the output from the run on the project database.
-- =====================================================================


-- #####################################################################
-- PART 1. SETUP: base views
-- #####################################################################

BEGIN;

DROP VIEW IF EXISTS sales CASCADE;

-- sales: one row per order, joined to its customer, with calculated fields
CREATE VIEW sales AS
WITH base AS (
  SELECT t."Transaction_ID"::integer AS "Transaction_ID",
         t."Date_of_Purchase", t."Customer_ID", t."Product_Category", t."Product_Name", t."Units",
         t."Price"::numeric     AS "Price",
         t."Discounts"::numeric AS "Discounts",
         t."Returned", t."Mode_of_Payment", t."Purchase_Channel",
         c."Customer_Name", c."Customer_Email", c."Customer_Number", c."Age", c."Gender", c."Location",
         TO_DATE(t."Date_of_Purchase", 'DD-MM-YYYY')    AS purchase_date,
         t."Units" * t."Price"::numeric                 AS gross_amount,
         CASE WHEN t."Returned" THEN 1 ELSE 0 END       AS returned_flag
  FROM tbl_transaction t
  LEFT JOIN tbl_customers c ON c."Customer_ID" = t."Customer_ID"
),
enriched AS (
  SELECT base.*,
         gross_amount - "Discounts"                                              AS net_amount,
         CASE WHEN returned_flag = 0 THEN gross_amount - "Discounts" ELSE 0 END  AS realised_amount,
         "Discounts" / NULLIF(gross_amount, 0)                                   AS discount_pct,
         CASE WHEN "Discounts" / NULLIF(gross_amount, 0) < 0.10 THEN '0-10%'
              WHEN "Discounts" / NULLIF(gross_amount, 0) < 0.25 THEN '10-25%'
              ELSE '25%+' END                                                    AS discount_band,
         CASE WHEN "Age" BETWEEN 18 AND 25 THEN '18-25'
              WHEN "Age" BETWEEN 26 AND 35 THEN '26-35'
              WHEN "Age" BETWEEN 36 AND 45 THEN '36-45'
              WHEN "Age" BETWEEN 46 AND 55 THEN '46-55'
              ELSE '56-65' END                                                   AS age_group,
         CAST(DATE_TRUNC('month', purchase_date) AS DATE)                        AS purchase_month,
         CAST(DATE_TRUNC('quarter', purchase_date) AS DATE)                      AS purchase_quarter,
         CAST(EXTRACT(YEAR FROM purchase_date) AS INT)                           AS calendar_year,
         CAST(1 + FLOOR((purchase_date - MIN(purchase_date) OVER ()) / 365.25) AS INT) AS business_year
  FROM base
)
SELECT enriched.*,
       (purchase_month > MIN(purchase_month) OVER () AND purchase_month < MAX(purchase_month) OVER ()) AS is_full_month
FROM enriched;

-- customer_summary: one row per customer who bought something
CREATE VIEW customer_summary AS
SELECT "Customer_ID",
       COUNT(*)                                              AS orders,
       SUM("Units")                                          AS units,
       SUM(gross_amount)                                     AS gross_amount,
       SUM(net_amount)                                       AS net_amount,
       SUM(realised_amount)                                  AS realised_amount,
       SUM(returned_flag)                                    AS returned_orders,
       COUNT(*) FILTER (WHERE "Purchase_Channel" = 'Online') AS online_orders,
       MIN(purchase_date)                                    AS first_purchase,
       MAX(purchase_date)                                    AS last_purchase,
       COUNT(DISTINCT "Product_Category")                    AS categories,
       COUNT(DISTINCT "Mode_of_Payment")                     AS payment_modes
FROM sales
GROUP BY "Customer_ID";

-- customer_profile: every registered customer, buyers and non-buyers
CREATE VIEW customer_profile AS
SELECT c.*,
       CASE WHEN c."Age" BETWEEN 18 AND 25 THEN '18-25'
            WHEN c."Age" BETWEEN 26 AND 35 THEN '26-35'
            WHEN c."Age" BETWEEN 36 AND 45 THEN '36-45'
            WHEN c."Age" BETWEEN 46 AND 55 THEN '46-55'
            ELSE '56-65' END                                 AS age_group,
       COALESCE(cs.orders, 0)                                AS orders,
       COALESCE(cs.net_amount, 0)                            AS net_amount,
       COALESCE(cs.realised_amount, 0)                       AS realised_amount,
       cs.first_purchase,
       cs.last_purchase,
       CASE WHEN cs."Customer_ID" IS NULL THEN 0 ELSE 1 END  AS is_active
FROM tbl_customers c
LEFT JOIN customer_summary cs ON cs."Customer_ID" = c."Customer_ID";

-- calendar: one row per day from the first to the last purchase (for BI tools)
CREATE VIEW calendar AS
SELECT g.d::date AS calendar_date
FROM generate_series((SELECT MIN(purchase_date)::timestamp FROM sales),
                     (SELECT MAX(purchase_date)::timestamp FROM sales),
                     INTERVAL '1 day') AS g(d);

-- product_month_units: every product x every full month (0 if no sales)
CREATE VIEW product_month_units AS
WITH months AS (SELECT DISTINCT purchase_month FROM sales WHERE is_full_month),
     prods  AS (SELECT DISTINCT "Product_Category", "Product_Name" FROM sales)
SELECT p."Product_Category", p."Product_Name", m.purchase_month,
       COALESCE(SUM(s."Units"), 0)    AS units,
       COALESCE(SUM(s.net_amount), 0) AS net_revenue
FROM prods p
CROSS JOIN months m
LEFT JOIN sales s ON s."Product_Category" = p."Product_Category"
                 AND s."Product_Name"     = p."Product_Name"
                 AND s.purchase_month     = m.purchase_month
GROUP BY p."Product_Category", p."Product_Name", m.purchase_month;

-- sales_dims: each order repeated once per dimension (for BI slicers)
CREATE VIEW sales_dims AS
SELECT s.*, d.dimension, d.dim_value
FROM sales s
CROSS JOIN LATERAL (VALUES
  ('Category',      CAST(s."Product_Category" AS VARCHAR)),
  ('Product',       CAST(s."Product_Name" AS VARCHAR)),
  ('Channel',       CAST(s."Purchase_Channel" AS VARCHAR)),
  ('Payment Mode',  CAST(s."Mode_of_Payment" AS VARCHAR)),
  ('City',          CAST(s."Location" AS VARCHAR)),
  ('Age Group',     CAST(s.age_group AS VARCHAR)),
  ('Gender',        CAST(s."Gender" AS VARCHAR)),
  ('Discount Band', CAST(s.discount_band AS VARCHAR)),
  ('Month',         CAST(s.purchase_month AS VARCHAR)),
  ('Overall',       'All')
) AS d(dimension, dim_value);

COMMIT;

-- CHECK: expected row counts
SELECT 'sales' AS view_name, COUNT(*) FROM sales                           -- expect 3000
UNION ALL SELECT 'customer_summary', COUNT(*) FROM customer_summary         -- expect 954
UNION ALL SELECT 'customer_profile', COUNT(*) FROM customer_profile         -- expect 1000
UNION ALL SELECT 'calendar', COUNT(*) FROM calendar                         -- expect 731
UNION ALL SELECT 'product_month_units', COUNT(*) FROM product_month_units   -- expect 690
UNION ALL SELECT 'sales_dims', COUNT(*) FROM sales_dims;                    -- expect 30000

SELECT ROUND(SUM(net_amount), 2) AS net_revenue FROM sales;                 -- expect 2117111.78


-- #####################################################################
-- PART 2. ANALYSIS
-- #####################################################################

-- ---------------------------------------------------------------------
-- Q1. How many customers are one-time vs repeat buyers,
--      and what is the repeat rate?
-- ---------------------------------------------------------------------
SELECT CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END          AS customer_type,
       COUNT(*)                                                         AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)               AS pct_of_customers,
       ROUND(SUM(net_amount), 2)                                        AS net_revenue,
       ROUND(100.0 * SUM(net_amount) / SUM(SUM(net_amount)) OVER (), 2) AS pct_of_revenue
FROM customer_summary
GROUP BY 1;

-- Result: One-time 146 customers (15.30%), 101,377.50 net revenue (4.79%)
--         Repeat   808 customers (84.70%), 2,015,734.28 net revenue (95.21%)


-- ---------------------------------------------------------------------
-- Q2. What is the distribution of orders per customer?
--      Starts from all registered customers, so non-buyers show as 0 orders.
-- ---------------------------------------------------------------------
WITH o AS (
  SELECT c."Customer_ID", COALESCE(cs.orders, 0) AS orders
  FROM tbl_customers c
  LEFT JOIN customer_summary cs ON cs."Customer_ID" = c."Customer_ID"
)
SELECT orders,
       COUNT(*)                                           AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM o
GROUP BY orders
ORDER BY orders;

-- Result: 0 orders 46 (4.6%) | 1: 146 (14.6%) | 2: 234 (23.4%) | 3: 233 (23.3%)
--         4: 156 (15.6%) | 5: 100 (10.0%) | 6: 50 | 7: 22 | 8: 9 | 9: 3 | 10: 1


-- ---------------------------------------------------------------------
-- Q3A. What is customer lifetime value (CLV), and how is it distributed?
--       CLV here = money kept (realised_amount) over the 2 years of data.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                                                   AS purchasing_customers,
       ROUND(CAST(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY realised_amount) AS NUMERIC), 2)   AS p25,
       ROUND(CAST(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY realised_amount) AS NUMERIC), 2)   AS median,
       ROUND(CAST(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY realised_amount) AS NUMERIC), 2)   AS p75,
       ROUND(CAST(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY realised_amount) AS NUMERIC), 2)   AS p90,
       ROUND(MAX(realised_amount), 2)                                                             AS max_clv,
       ROUND(AVG(realised_amount), 2)                                                             AS avg_clv_realised,
       ROUND(AVG(net_amount), 2)                                                                  AS avg_net_before_returns
FROM customer_summary;

-- Result: 954 customers · p25 154.19 · median 830.15 · p75 1,788.11 · p90 2,656.43
--         max 7,051.90 · average kept 1,120.88 · average before returns 2,219.19


-- ---------------------------------------------------------------------
-- Q3B. CLV per customer plus a simple 3-year projection
--       projection = avg per order x orders per year x 3
--       Orders per year use the real span of the data (730 days = 1.9986 years).
--
--       Two projections are shown:
--         projected_3yr_revenue : built from net (before returns)
--         projected_3yr_kept    : built from realised (money kept)
--
--       Three things to know before trusting the projection:
--       1. Kept vs before-returns money. historical_clv_realised has returns
--          taken off, but projected_3yr_revenue is built from spending before
--          returns. About half of all orders were returned, so it runs high
--          (e.g. customer 383 kept 5,963.53 of 7,820.25).
--          projected_3yr_kept fixes this by using realised_amount.
--       2. It assumes everyone keeps shopping. Customer 398, the #1 by kept
--          CLV, last bought on 12-06-2022 (286 days before the data ends) and
--          is in the RFM "At Risk" segment, yet is projected another 10,585.10.
--       3. It is a straight-line estimate ("spend per year x 3"). It ignores
--          customers stopping, slowing down or growing. Call it a simple
--          projection, not a prediction.
-- ---------------------------------------------------------------------
WITH obs AS (
  SELECT (MAX(purchase_date) - MIN(purchase_date)) / 365.25 AS years_observed
  FROM sales
)
SELECT cs."Customer_ID",
       cs.orders,
       ROUND(cs.realised_amount, 2)                                                       AS historical_clv_realised,
       ROUND(cs.net_amount / cs.orders, 2)                                                AS avg_net_per_order,
       ROUND(cs.orders / obs.years_observed, 2)                                           AS orders_per_year,
       ROUND((cs.net_amount / cs.orders) * (cs.orders / obs.years_observed) * 3, 2)       AS projected_3yr_revenue,
       ROUND((cs.realised_amount / cs.orders) * (cs.orders / obs.years_observed) * 3, 2)  AS projected_3yr_kept
FROM customer_summary cs
CROSS JOIN obs
ORDER BY historical_clv_realised DESC;

-- Result: 954 rows · historical CLV total 1,069,322.03
--         projected_3yr_revenue total 3,177,842.87
--         projected_3yr_kept    total 1,605,081.66 (median 1,246.08)
--         Full output: results/customer_clv_projection.csv


-- ---------------------------------------------------------------------
-- Q4. Who are the top 20 customers by net revenue?
--      Shows ID and demographics only. realised shows what was kept.
-- ---------------------------------------------------------------------
SELECT cs."Customer_ID",
       c."Age",
       c."Gender",
       c."Location",
       cs.orders,
       ROUND(cs.net_amount, 2)      AS net_revenue,
       ROUND(cs.realised_amount, 2) AS realised
FROM customer_summary cs
JOIN tbl_customers c USING ("Customer_ID")
ORDER BY cs.net_amount DESC
LIMIT 20;

-- Result: #1 is ID 510 (net 8,772.34, kept 3,823.83).
--         ID 430 is #16 on net revenue (6,948.57) but kept 0.00, because all 7 orders were returned.
--         ID 706 kept only 263.06 of 6,678.54. Ranking by realised_amount gives a fairer top 20.
