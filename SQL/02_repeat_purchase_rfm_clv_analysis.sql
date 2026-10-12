-- =====================================================================
-- Ecommerce Customer Analytics: Repeat Purchase, RFM Segmentation & Customer Value
-- Database: PostgreSQL (Supabase), schema public
-- Data:     25-03-2021 to 25-03-2023 · 1,000 customers · 3,000 orders
--
-- Requires the views in views/create_views.sql
--   (sales, customer_summary, customer_rfm).
-- Every query here is read-only (SELECT).
-- No query selects Customer_Name, Customer_Email or Customer_Number.
--
-- Value terms used below:
--   net_amount      = Units * Price - Discounts (returned orders still counted)
--   realised_amount = net_amount, but 0 when the order was returned (money kept)
--
-- "Result" comments show the output from the run on the project database.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. How many customers are one-time vs repeat buyers,
--     and what is the repeat rate?
-- ---------------------------------------------------------------------
SELECT CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END        AS customer_type,
       COUNT(*)                                                       AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)             AS pct_of_customers,
       ROUND(SUM(net_amount), 2)                                      AS net_revenue,
       ROUND(100.0 * SUM(net_amount) / SUM(SUM(net_amount)) OVER (), 2) AS pct_of_revenue
FROM customer_summary
GROUP BY 1;

-- Result: One-time 146 customers (15.30%), 101,377.50 net revenue (4.79%)
--         Repeat   808 customers (84.70%), 2,015,734.28 net revenue (95.21%)


-- ---------------------------------------------------------------------
-- Q2. What is the distribution of orders per customer?
--     Starts from all registered customers, so non-buyers show as 0 orders.
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
-- Q3. What is customer lifetime value (CLV), and how is it distributed?
--     CLV here = money kept (realised_amount) over the 2 years of data.
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
-- Q4. CLV per customer plus a simple 3-year projection
--     projection = avg net per order x orders per year x 3
--     Orders per year use the real span of the data (730 days = 1.9986 years).
--     Note: avg net per order includes returned orders, so the projection
--     is optimistic (see README, Limitations).
-- ---------------------------------------------------------------------
WITH obs AS (
  SELECT (MAX(purchase_date) - MIN(purchase_date)) / 365.25 AS years_observed
  FROM sales
)
SELECT cs."Customer_ID",
       cs.orders,
       ROUND(cs.realised_amount, 2)                                                   AS historical_clv_realised,
       ROUND(cs.net_amount / cs.orders, 2)                                            AS avg_net_per_order,
       ROUND(cs.orders / obs.years_observed, 2)                                       AS orders_per_year,
       ROUND((cs.net_amount / cs.orders) * (cs.orders / obs.years_observed) * 3, 2)   AS projected_3yr_revenue
FROM customer_summary cs
CROSS JOIN obs
ORDER BY historical_clv_realised DESC;

-- Result: 954 rows · historical CLV total 1,069,322.03 · projected 3-year total 3,177,842.87
--         Full output: results/customer_clv_projection.csv


-- ---------------------------------------------------------------------
-- Q5. RFM scores and segment for every buying customer
--     Scores 1-5 (5 = best) and segment rules are defined in customer_rfm.
-- ---------------------------------------------------------------------
SELECT "Customer_ID",
       recency_days,
       frequency,
       ROUND(monetary, 2) AS monetary,
       r_score,
       f_score,
       m_score,
       rfm_segment
FROM customer_rfm
ORDER BY rfm_segment, monetary DESC;

-- Result: 954 rows (one per buying customer)


-- ---------------------------------------------------------------------
-- Q6. Customers with the highest return rates (minimum 5 orders)
--     A minimum order count avoids flagging customers who returned 1 of 1.
--     With a 50% overall return rate, some 100% returners are expected by
--     chance alone, so treat this as a review list, not proof of abuse.
-- ---------------------------------------------------------------------
SELECT cs."Customer_ID",
       cs.orders,
       cs.returned_orders,
       ROUND(100.0 * cs.returned_orders / cs.orders, 1) AS return_rate_pct,
       ROUND(cs.net_amount - cs.realised_amount, 2)     AS returned_value
FROM customer_summary cs
WHERE cs.orders >= 5
ORDER BY return_rate_pct DESC, returned_value DESC
LIMIT 50;

-- Result: 185 customers have 5+ orders; top 50 shown.
--         Highest: ID 430 (7 of 7 returned, 6,948.57), ID 350 (5 of 5, 5,808.05)
