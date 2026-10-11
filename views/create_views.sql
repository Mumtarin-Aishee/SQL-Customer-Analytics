-- =====================================================================
-- SQL Customer Analytics: view definitions
-- Database: Supabase (PostgreSQL), schema public
-- Source tables: tbl_transaction (3,000 orders), tbl_customers (1,000 customers)
-- Data covers 25-03-2021 to 25-03-2023
--
-- Views built here:
--   sales                one row per order, joined to its customer, with calculated fields
--   customer_summary     one row per customer who bought something (954)
--   customer_profile     one row per registered customer (1,000), including non-buyers
--   customer_rfm         Recency / Frequency / Monetary scores (1-5) and a segment label
--   calendar             one row per day between the first and last purchase
--   product_month_units  units and revenue per product per full month
--
-- Note: this script DROPS and rebuilds the views. It is kept here for reference.
-- It is not in supabase/migrations/, so it never runs automatically.
-- =====================================================================

BEGIN;

DROP VIEW IF EXISTS sales CASCADE;

-- ---------------------------------------------------------------------
-- sales: transaction-level view
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- customer_summary: one row per buying customer
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- customer_profile: every registered customer, buyers and non-buyers
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- customer_rfm: RFM scores (5 = best) and segment label
--   ref = last date in the data, used as "today"
--   r   = raw recency (days), frequency (orders), monetary (net spend)
--   s   = NTILE(5) scores for each measure
-- ---------------------------------------------------------------------
CREATE VIEW customer_rfm AS
WITH ref AS (SELECT MAX(purchase_date) AS as_of FROM sales),
r AS (
  SELECT cs."Customer_ID", ref.as_of - cs.last_purchase AS recency_days,
         cs.orders AS frequency, cs.net_amount AS monetary
  FROM customer_summary cs CROSS JOIN ref
),
s AS (
  SELECT r.*,
         NTILE(5) OVER (ORDER BY recency_days DESC)   AS r_score,
         NTILE(5) OVER (ORDER BY frequency, monetary) AS f_score,
         NTILE(5) OVER (ORDER BY monetary)            AS m_score
  FROM r
)
SELECT s.*,
       CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
            WHEN r_score <= 2 AND f_score >= 4                  THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost'
            ELSE 'Needs Attention' END AS rfm_segment
FROM s;

-- ---------------------------------------------------------------------
-- calendar: one row per day from the first to the last purchase
-- ---------------------------------------------------------------------
CREATE VIEW calendar AS
SELECT g.d::date AS calendar_date
FROM generate_series((SELECT MIN(purchase_date)::timestamp FROM sales),
                     (SELECT MAX(purchase_date)::timestamp FROM sales),
                     INTERVAL '1 day') AS g(d);

-- ---------------------------------------------------------------------
-- product_month_units: every product x every full month (0 if no sales)
-- ---------------------------------------------------------------------
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

COMMIT;

-- =====================================================================
-- CHECK (run after the script): expected row counts
-- =====================================================================
SELECT 'sales' AS view_name, COUNT(*) FROM sales                           -- expect 3000
UNION ALL SELECT 'customer_summary', COUNT(*) FROM customer_summary         -- expect 954
UNION ALL SELECT 'customer_profile', COUNT(*) FROM customer_profile         -- expect 1000
UNION ALL SELECT 'customer_rfm', COUNT(*) FROM customer_rfm                 -- expect 954
UNION ALL SELECT 'calendar', COUNT(*) FROM calendar                         -- expect 731
UNION ALL SELECT 'product_month_units', COUNT(*) FROM product_month_units;  -- expect 690

SELECT ROUND(SUM(net_amount), 2) AS net_revenue FROM sales;                 -- expect 2117111.78
