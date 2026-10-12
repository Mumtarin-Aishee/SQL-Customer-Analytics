-- =====================================================================
-- Ecommerce Customer Analytics
-- File 2 of 3: rfm_analysis.sql
--   RFM segmentation: Recency, Frequency and Monetary scores (1-5)
--   and a segment label for every buying customer.
--
-- Database: PostgreSQL (Supabase), schema public
--
-- RUN ORDER: customer_analysis.sql -> rfm_analysis.sql -> segmentation_queries.sql
--   Needs the views sales and customer_summary from customer_analysis.sql.
--
-- Part 1 creates a view only (it never changes table data).
-- Part 2 is read-only (SELECT). No personal data is selected.
-- =====================================================================


-- #####################################################################
-- PART 1. SETUP: customer_rfm view
--   ref           = last date in the data (25-03-2023), used as "today"
--   recency_days  = days since the customer's last order
--   frequency     = number of orders
--   monetary      = net spend (returned orders included)
--   NTILE(5) splits customers into 5 equal groups; 5 = best.
--   Frequency ties are broken by monetary.
--   Segment rules are checked top to bottom; the first match wins.
-- #####################################################################

DROP VIEW IF EXISTS customer_rfm;

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

-- CHECK: expected row count
SELECT COUNT(*) AS customer_rfm_rows FROM customer_rfm;   -- expect 954


-- #####################################################################
-- PART 2. ANALYSIS
-- #####################################################################

-- ---------------------------------------------------------------------
-- 5A. What is the RFM segmentation, with segment sizes and revenue?
-- ---------------------------------------------------------------------
SELECT rfm_segment,
       COUNT(*)                                                     AS customers,
       ROUND(SUM(monetary), 2)                                      AS net_revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_share_pct
FROM customer_rfm
GROUP BY rfm_segment
ORDER BY net_revenue DESC;

-- Result:
--   Champions        169 customers   701,013.94   33.1%
--   Loyal            250 customers   590,144.33   27.9%
--   At Risk           77 customers   262,424.11   12.4%
--   Lost             229 customers   241,311.51   11.4%
--   Needs Attention  136 customers   208,941.65    9.9%
--   New / Promising   93 customers   113,276.24    5.4%


-- ---------------------------------------------------------------------
-- 5B. RFM scores and segment for every buying customer
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
