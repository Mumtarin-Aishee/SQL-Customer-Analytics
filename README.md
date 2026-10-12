# Ecommerce Customer Analytics: Repeat Purchase, RFM Segmentation & Customer Value

**PostgreSQL (Supabase) · RFM segmentation · Customer lifetime value (CLV) · Churn · Repeat-purchase analysis**

## 🧭 Business Problem

An ecommerce business sells six product categories (Toys, Automotive, Home, Electronics, Fashion and Books), online and in-store, to customers in 10 cities. It has two years of order data (March 2021 to March 2023) but **no clear view of who its customers are or how they behave**. Every customer is treated the same, so retention and marketing budget is spread evenly instead of going where it matters most.


**The problem in one picture: where 1,000 registered customers end up**

```mermaid
flowchart LR
    A["👥 Registered customers<br/><b>1,000</b>"] ==>|954 bought| B["🛒 Bought at least once<br/><b>954</b>"]
    A -.->|46 never bought| C["🚫 Never bought<br/><b>46</b> · 4.6%"]
    B ==>|504| D["🟩 Active<br/>ordered in last 6 months<br/><b>504</b> · 52.8%"]
    B ==>|276| E["🟨 Lapsing<br/>last order 6-12 months ago<br/><b>276</b> · 28.9%"]
    B ==>|174| F["🟥 Churned<br/>no order for 12+ months<br/><b>174</b> · 18.2%"]

    classDef reg fill:#1E88E5,stroke:#0D47A1,color:#FFFFFF
    classDef buy fill:#8E24AA,stroke:#4A148C,color:#FFFFFF
    classDef never fill:#9E9E9E,stroke:#424242,color:#FFFFFF
    classDef active fill:#43A047,stroke:#1B5E20,color:#FFFFFF
    classDef lapsing fill:#FBC02D,stroke:#F57F17,color:#000000
    classDef churned fill:#E53935,stroke:#B71C1C,color:#FFFFFF
    class A reg
    class B buy
    class C never
    class D active
    class E lapsing
    class F churned
```


The business needs answers to four questions:

1. **Who comes back?** How many customers stop after one order, and how many return?
2. **Who is worth the most?** Which customers and segments generate most of the value?
3. **Who is slipping away?** Which valuable customers have stopped buying recently?
4. **Where is value being lost?** Which customers return most of what they buy?

**Why it is urgent**
* **Returns are extremely high.** About half of all orders (**50.27%**) were returned. Sales figures look healthy (2.12 million net), but the store kept only **1.07 million**. Judging customers on sales alone overstates their value.
* **Revenue depends on returning customers.** If a small group of high-value buyers drifts away, revenue falls quickly.
* **Activity is fading.** Many buyers have not ordered in months, but without segmentation the business cannot tell a lapsed high-value customer from an occasional shopper.

## 🎯 Objectives

* Analyze customer and transaction data to find distinct purchasing behavior patterns
* Separate **one-time buyers** from **repeat customers** and measure the repeat rate
* Build **RFM segments** using transparent SQL scoring rules
* Measure **customer lifetime value (CLV)** and make a simple 3-year projection
* Identify customers **at risk of churning** (no recent purchase)
* Turn the findings into practical recommendations for retention and targeted marketing

---

## 📊 Key Features

### Customer Analysis Components

* ✅ **Repeat Purchase Analysis**: one-time vs repeat buyers and orders per customer
* ✅ **RFM Segmentation**: Recency, Frequency and Monetary scoring (1–5) for every buying customer
* ✅ **Customer Lifetime Value**: historical CLV (money kept) plus a 3-year projection per customer
* ✅ **Churn Risk Assessment**: customers with no purchase in the last 6 or 12 months
* ✅ **Behavioral Segmentation**: first-purchase category, return behavior, non-buyers
* ✅ **Demographic Analysis**: non-buyers by age group and gender; top customers by profile

---

## 📈 Key Results & Insights

### Customer Behavior & Value ✅

* **Repeat buying is strong (Q1):** 808 of 954 buyers (**84.7%**) ordered more than once. They bring in **95.21%** of net revenue and **95.87%** of kept revenue.
* **Most customers order 2–3 times (Q2):** 2 orders (23.4% of all customers), 3 orders (23.3%). Only 13 customers have 8 or more.
* **CLV is skewed (Q3A):** median kept CLV is **830.15** against an average of **1,120.88**. The 25th / 75th / 90th percentiles are 154.19 / 1,788.11 / 2,656.43.
* **CLV is concentrated:** the top 20% of customers hold **52.1%** of kept CLV.
* **3-year projection (Q3B):** 3,177,842.87 based on net spend, or **1,605,081.66** based on money kept. Both are simple estimates; see [Limitations](#-limitations--future-improvements).
* **Top customers can be misleading (Q4):** customer 430 is #16 by net revenue but kept 0, because all 7 orders were returned.
* **First category doesn't predict loyalty (Q5):** repeat rates range only from 83.0% (Books) to 88.4% (Home), which is within chance.
* **Non-buyers lean older (Q7):** 14 of the 46 customers who never ordered are aged 56–65.
* **Returns erase value (Q8):** 179 customers (18.8%) returned every order, so their kept CLV is 0.
* **Churn risk (Q9):** **47.2%** of buyers had no purchase in the last 6 months; **18.2%** none in 12 months.

---

## 💻 Technologies Used

* **SQL (PostgreSQL)**: advanced queries for data extraction, transformation and analysis:
* **Supabase**: hosted PostgreSQL database, SQL Editor for running queries and exporting results
* **Claude Code**: AI assistant used for query drafting, validation and documentation
* **GitHub Mermaid**: charts in this README, drawn from the query results
  
### SQL Techniques
 * **Reusable views:** `CREATE VIEW` (7 views) built inside a `BEGIN … COMMIT` transaction
  * **Multi-step logic:** CTEs (`WITH`) to build results step by step
  * **Window functions:** `NTILE(5) OVER` for RFM scoring, `SUM(…) OVER ()` for percent-of-total, `MIN(…) OVER ()` for full-month flags
  * **Conditional aggregation:** `COUNT(*) FILTER (WHERE …)` and `CASE WHEN` for segment rules and bands
  * **Statistics:** `PERCENTILE_CONT … WITHIN GROUP` for CLV quartiles and the median
  * **Subtotals:** `GROUP BY ROLLUP` for age group and gender subtotals
  * **First-row selection:** `DISTINCT ON` to find each customer's first purchase
  * **Joins:** `LEFT JOIN` (keeps non-buyers), `JOIN … USING`, `CROSS JOIN` (attaches a reference date), `CROSS JOIN LATERAL (VALUES …)` (unpivots dimensions)
  * **Dates:** `TO_DATE` (text dates in DD-MM-YYYY), `DATE_TRUNC`, `EXTRACT`, `INTERVAL` arithmetic, `generate_series` for a calendar table
  * **Data cleaning:** `CAST` / `::numeric`, `COALESCE` (missing values to 0), `NULLIF` (safe division)
  
### Segmentation Techniques
* ✅ SQL-based RFM scoring with `NTILE(5)` (splits customers into 5 equal groups)
* ✅ Rule-based segment assignment (Champions, Loyal, At Risk and others)
* ✅ Percentile analysis of CLV (25th, 50th, 75th and 90th percentiles)

---

## ❓ Business Questions

| # | Question | SQL file | Status |
|---|---|---|---|
| Q1 | How many customers are one-time vs repeat buyers, and what is the repeat rate? | Purchase behavior | ✅ |
| Q2 | What is the distribution of orders per customer? | Purchase behavior | ✅ |
| Q3A | What is customer lifetime value (CLV), and how is it distributed? | Purchase behavior | ✅ |
| Q3B | What is each customer's CLV, plus a simple 3-year projection? | Purchase behavior | ✅ |
| Q4 | Who are the top 20 customers by net revenue? | Purchase behavior | ✅ |
| Q5 | Does a customer's first purchase category predict repeat purchase? | Purchase behavior | ✅ |
| Q6A | What is the RFM segmentation, with segment sizes and revenue? | RFM segmentation | ✅ |
| Q6B | What are the RFM scores and segment for every customer? | RFM segmentation | ✅ |
| Q7 | Who are the 46 customers with no purchases, and what do they look like? | Risk & retention | ✅ |
| Q8 | Which customers have the highest return rates (possible abuse)? | Risk & retention | ✅ |
| Q9 | What is the churn rate (no purchase in the last 6 or 12 months)? | Risk & retention | ✅ |

---

## 🛒 Repeat Purchase Analysis

### Q1 · One-time vs repeat buyers ✅

```mermaid
pie showData title Share of customers (954 buyers)
    "Repeat (808)" : 84.70
    "One-time (146)" : 15.30
```

```mermaid
pie showData title Share of net revenue
    "Repeat" : 95.21
    "One-time" : 4.79
```

**What it shows:**
* The **repeat rate is 84.7%**: most customers come back after their first order.
* One-time buyers are **15.3% of customers** but bring in only **4.8% of revenue**, while repeat buyers bring in **95.2%**. The business depends on returning customers.
* Turning even part of the 146 one-time buyers into repeat buyers is the clearest growth opportunity.

> Revenue here is net (returned orders included). Based on money kept, repeat buyers bring in 95.87%.

### Q2 · Distribution of orders per customer ✅

```mermaid
xychart-beta
    title "Number of customers by orders placed (all 1,000 registered customers)"
    x-axis "Orders per customer" ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
    y-axis "Customers" 0 --> 250
    bar [46, 146, 234, 233, 156, 100, 50, 22, 9, 3, 1]
```

**What it shows:**
* The most common behavior is **2 or 3 orders** (467 customers, 46.7%). Together with 4 orders, **62.3%** of customers placed 2–4 orders.
* The distribution is **right-skewed**: it drops off quickly after 4 orders. Only **13 customers (1.3%)** placed 8 or more.
* Buyers average **3.14 orders** each (3,000 orders ÷ 954 buyers), and the median buyer placed **3**.
* **46 registered customers (4.6%) never ordered**. They are counted here but excluded from RFM and CLV (see Q7).
* Growth lever: move customers from 2–3 orders to 4+, where Champions and Loyal customers sit.

---

## 🧩 RFM Segmentation

The `customer_rfm` view gives each of the **954 customers who bought something** a score from 1 to 5 on three measures, then a segment label such as Champions or Lost. **Champions are 18% of buyers and bring in 33% of net revenue.**

| Letter | Question | Column | Better when |
|---|---|---|---|
| **R**ecency | How long since they last bought? | `recency_days` | fewer days |
| **F**requency | How many times have they bought? | `frequency` | more orders |
| **M**onetary | How much have they spent? | `monetary` | more spend |

---

### Result · customer segment sizes and revenue


| Segment | Customers | % of buyers | Net revenue | Share of revenue | Avg spend per customer | Avg days since last order |
|---|---|---|---|---|---|---|
| **Champions** | 169 | 17.7% | 701,013.94 | **33.1%** | 4,148 | 57 |
| **Loyal** | 250 | 26.2% | 590,144.33 | **27.9%** | 2,361 | 116 |
| **At Risk** | 77 | 8.1% | 262,424.11 | 12.4% | 3,408 | 317 |
| **Lost** | 229 | 24.0% | 241,311.51 | 11.4% | 1,054 | 411 |
| **Needs Attention** | 136 | 14.3% | 208,941.65 | 9.9% | 1,536 | 260 |
| **New / Promising** | 93 | 9.7% | 113,276.24 | 5.4% | 1,218 | 61 |
| **Total** | **954** | 100% | **2,117,111.78** | 100% | 2,219 | – |

```mermaid
pie showData title Customers by RFM segment (954 buyers)
    "Champions" : 169
    "Loyal" : 250
    "At Risk" : 77
    "Lost" : 229
    "Needs Attention" : 136
    "New / Promising" : 93
```

```mermaid
pie showData title Share of net revenue by RFM segment (%)
    "Champions" : 33.1
    "Loyal" : 27.9
    "At Risk" : 12.4
    "Lost" : 11.4
    "Needs Attention" : 9.9
    "New / Promising" : 5.4
```

```mermaid
xychart-beta
    title "Average net spend per customer by RFM segment"
    x-axis ["Champions", "At Risk", "Loyal", "Needs Attention", "New/Promising", "Lost"]
    y-axis "Net spend" 0 --> 4500
    bar [4148, 3408, 2361, 1536, 1218, 1054]
```

**What it shows:**
* **Champions and Loyal** customers together are **44% of buyers** and bring in **61% of net revenue**.
* The **77 At Risk** customers spent an average of about **3,400** each, more than any segment except Champions, but last bought about 317 days ago on average. They are the group most worth contacting before they become Lost.
* **Lost** is the largest segment by headcount (229 customers, 24%) but brings in only 11.4% of revenue.

> `monetary` is net spend **before returns**. About half of all orders were returned, so the money the store kept is roughly half of these figures.
> Full per-customer scores: [results/q6b_rfm_scores.csv](results/q6b_rfm_scores.csv)

---

### · Customer Lifetime Value (CLV) ✅

CLV here is the **money kept** (`realised_amount`: net spend with returned orders taken off) by each of the 954 buying customers over the 2 years of data.

####  How CLV is distributed

| Purchasing customers | 25th percentile | Median | 75th percentile | 90th percentile | Max | Average (kept) | Average before returns |
|---|---|---|---|---|---|---|---|
| 954 | 154.19 | **830.15** | 1,788.11 | 2,656.43 | 7,051.90 | 1,120.88 | 2,219.19 |

**Histogram: customers by kept CLV**

| Kept CLV | 0 | 1–500 | 500–1k | 1k–1.5k | 1.5k–2k | 2k–2.5k | 2.5k–3k | 3k–4k | 4k–8k |
|---|---|---|---|---|---|---|---|---|---|
| Customers | **179** | 201 | 142 | 131 | 99 | 91 | 42 | 48 | 21 |

```mermaid
xychart-beta
    title "Customers by kept CLV (954 buyers)"
    x-axis "Kept CLV range" ["0", "1-500", "500-1k", "1k-1.5k", "1.5k-2k", "2k-2.5k", "2.5k-3k", "3k-4k", "4k-8k"]
    y-axis "Customers" 0 --> 220
    bar [179, 201, 142, 131, 99, 91, 42, 48, 21]
```

**What it shows:**
* **A spike at 0:** 179 customers (18.8%) returned every order, so their kept CLV is 0.
* **A long right tail:** most customers kept under 1,500, while a few kept up to 7,052. The average (1,120.88) is pulled up by these big spenders, so the **median (830.15)** is the better "typical customer" figure.
* **Value is concentrated:** the **top 20% of customers hold 52.1%** of kept CLV and the top half hold 89.3%. The bottom 20% hold none.
* **Returns halve customer value:** average CLV before returns is 2,219.19, against 1,120.88 kept.

#### Q3B · 3-year projection

| Measure | Total (954 customers) |
|---|---|
| Historical CLV (kept, 2 years) | 1,069,322.03 |
| 3-year projection (built from net spend) | 3,177,842.87 |
| 3-year projection (built from money kept) | 1,605,081.66 |

```mermaid
xychart-beta
    title "Historical CLV vs 3-year projection (thousands)"
    x-axis ["Historical (kept, 2 yrs)", "Projection (net)", "Projection (kept)"]
    y-axis "Amount (thousands)" 0 --> 3500
    bar [1069, 3178, 1605]
```

**How to read it:**
* Projection = average spend per order × orders per year × 3, where orders per year use the real 730-day span of the data.
* The **net-based projection (3.18 million) is optimistic**: it is built from spending before returns, and about half of all orders were returned. The **kept-based projection (1.61 million)** is the more realistic figure.
* Both are straight-line estimates that assume every customer keeps buying at the same pace, including customers who have gone quiet. Treat them as simple projections, not predictions.
* Full per-customer output: `results/q3b_clv_projection.csv` *(to upload)*

---

## ⚠️ Risk & Retention Results

### Customer journey at a glance

Where all 1,000 registered customers end up: who never bought (Q7), and how recently the buyers last ordered (Q9).

### Q8 · Customers with the highest return rates ✅

Only customers with **5 or more orders (185)** are included, so a single returned item doesn't count as 100%.

| Return rate | 0–39% | 40–59% | 60–79% | 80–100% |
|---|---|---|---|---|
| Customers | 🟩 42 | 🟨 76 | 🟧 50 | 🟥 **17** |

```mermaid
%%{init: {"theme": "base", "themeVariables": {"pie1": "#FBC02D", "pie2": "#FB8C00", "pie3": "#43A047", "pie4": "#E53935", "pieStrokeColor": "#FFFFFF", "pieOuterStrokeWidth": "0px"}}}%%
pie showData title Customers with 5+ orders by return rate (185)
    "40-59% returned" : 76
    "60-79% returned" : 50
    "0-39% returned" : 42
    "80-100% returned" : 17
```

<sub>x = value returned (0 to 7,000) · y = return rate (50% to 100%)</sub>

| Customer_ID | Orders | Returned | Return rate | Value returned |
|---|---|---|---|---|
| 430 | 7 | 7 | 🟥 100% | 6,948.57 |
| 350 | 5 | 5 | 🟥 100% | 5,808.05 |
| 291 | 5 | 5 | 🟥 100% | 2,348.51 |
| 652 | 5 | 5 | 🟥 100% | 1,895.67 |
| 706 | 7 | 6 | 🟥 85.7% | 6,415.48 |
| 589 | 7 | 6 | 🟥 85.7% | 4,547.42 |
| 123 | 7 | 6 | 🟥 85.7% | 4,342.77 |
| 122 | 6 | 5 | 🟥 83.3% | 1,847.30 |
| 22 | 5 | 4 | 🟥 80.0% | 3,082.57 |
| 282 | 5 | 4 | 🟥 80.0% | 2,642.93 |

**What it shows:**
* Most frequent buyers return **40–79%** of their orders, in line with the store-wide 50% return rate.
* **17 customers return 80% or more.** Customers **430** (7 of 7 returned, 6,949) and **706** (6 of 7, 6,415) combine a very high rate with high value: review these first.
* **Be careful calling it fraud.** With a 50% return rate, some 100% returners are expected by chance alone. Customer 430 (7 of 7) is the clearest outlier. Treat this as a review list, not proof of abuse.

### Q9 · Churn: customers with no recent purchase ✅

| Status | Last order | Customers | % of buyers | Kept value at stake |
|---|---|---|---|---|
| 🟩 **Active** | within 6 months | 504 | 52.8% | 655,382 |
| 🟨 **Lapsing** | 6–12 months ago | 276 | 28.9% | 286,895 |
| 🟥 **Churned** | 12+ months ago | 174 | 18.2% | 127,045 |
| **Total** | | **954** | 100% | 1,069,322 |

```mermaid
%%{init: {"theme": "base", "themeVariables": {"pie1": "#43A047", "pie2": "#FBC02D", "pie3": "#E53935", "pieStrokeColor": "#FFFFFF", "pieOuterStrokeWidth": "0px"}}}%%
pie showData title Buyers by time since last order (954)
    "Active: last 6 months" : 504
    "Lapsing: 6-12 months" : 276
    "Churned: 12+ months" : 174
```

```mermaid
%%{init: {"theme": "base", "themeVariables": {"xyChart": {"plotColorPalette": "#FB8C00"}}}}%%
xychart-beta
    title "Kept customer value by status (thousands)"
    x-axis ["Active (0-6m)", "Lapsing (6-12m)", "Churned (12m+)"]
    y-axis "Kept value (thousands)" 0 --> 700
    bar [655, 287, 127]
```

**What it shows:**
* **6-month churn is 47.2%** (450 of 954 buyers) and **12-month churn is 18.2%** (174).
* The **Lapsing** group is the priority: 276 customers holding **286,895** in kept value, including **45 Champions or Loyal** customers and **55 At Risk** customers. They have gone quiet but are not lost yet.
* The **Churned** group holds less value (127,045) and is harder to win back: a low-cost campaign fits better than personal outreach.

---


## 💡 Recommendations

### Based on the results above
1. **Win back At Risk customers** (77 customers, 12.4% of net revenue, ~3,400 average spend) with personalized offers.
2. **Reward Champions and Loyal customers** (61% of net revenue together) with a VIP or loyalty tier.
3. **Nurture New / Promising customers** (93, very recent but few orders) toward a 2nd and 3rd order.
4. **Re-engage inactive buyers** (47.2% with no order in 6 months), starting with those who had high past spend.
5. **Judge value on money kept, not sales.** Review the 179 customers who returned everything before targeting them.


## 🚧 Limitations & Future Improvements

### Known limitations
* **The projection is a simple straight-line estimate.** The original version uses net order value, which includes returned orders (3,177,842.87 in total). The kept-money version, `projected_3yr_kept`, is about half (1,605,081.66). Both assume every customer keeps buying at the same rate, even customers who have gone quiet. For example, customer 398, the #1 by kept CLV, is "At Risk" but is still projected 10,585.10.
* **No cost data:** CLV is based on revenue, not profit.
* **No return reasons or campaign data:** the analysis shows *who* and *how much*, not *why*.
* **RFM is relative:** scores rank customers against each other, and the Monetary score uses net spend, so it includes returned orders.
* **Partial months:** March 2021 and March 2023 are incomplete.

---

## 🔧 Technical Architecture

### Data Flow

1. **Raw data** → `tbl_customers` and `tbl_transaction` in Supabase (PostgreSQL)
2. **Data validation** → nulls, duplicates, join check, date conversion, value ranges
3. **SQL views** → order-level `sales` view with calculated fields (net, realised, age group, month)
4. **Customer metrics** → `customer_summary`: orders, spend, returns, first/last purchase, channel mix
5. **Segmentation** → `customer_rfm`: R/F/M scores and segment labels
6. **Analysis** → repeat rate, CLV, projection, churn, returns, non-buyers
7. **Business insights** → recommendations for retention and targeted marketing

### Customer Segmentation Pipeline

```
Transaction Data → Validation → SQL Views → Customer Metrics → RFM Scoring → Segment Analysis → Recommendations

```  

📦 Project Deliverables

| Deliverable | Link | Status |
|---|---|---|
| Purchase behavior & CLV (views + Q1–Q5) | [SQL/customer_purchas##e_behaviour.sql](SQL/customer_purchase_behaviour.sql) | ✅ |
| RFM segmentation (Q6A–Q6B) | [SQL/segmentation_queries.sql](SQL/segmentation_queries.sql) | ✅ |
| Risk & retention (Q7–Q9) | [SQL/customer_risk_retention_analysis.sql](SQL/customer_risk_retention_analysis.sql) | ✅ |
| RFM scores for all customers | [results/q6b_rfm_scores.csv](results/q6b_rfm_scores.csv) | ✅ |

---
### 🔒 Privacy

Names, emails and phone numbers are **never selected or published**. Customers appear only as `Customer_ID`, and raw data files are not included in this repository.

---

## 🧮 SQL Analysis

The queries are split into three files, run in this order. Each file starts with any views it needs; the analysis queries are read-only `SELECT` statements with their result written below them.

| File | Queries | Topic |
|---|---|---|
| [customer_purchase_behaviour.sql](SQL/customer_purchase_behaviour.sql) | Q1–Q5 | Repeat purchase, orders per customer, CLV, 3-year projection, top customers, first category |
| [segmentation_queries.sql](SQL/segmentation_queries.sql) | Q6A–Q6B | RFM segmentation |
| [customer_risk_retention_analysis.sql](SQL/customer_risk_retention_analysis.sql) | Q7–Q9 | Non-buyers, high return rates, churn |

> ⚠️ Run the files in order. Re-running the first file drops `sales` with `CASCADE`, which also removes `customer_rfm`, so run `segmentation_queries.sql` again afterwards.

```

## 👤 Author

**`[Mumtarin Aishee Rabeya]`**
* GitHub: [@Mumtarin-Aishee](https://github.com/Mumtarin-Aishee)
* LinkedIn: `[https://www.linkedin.com/in/mumtarin/]`
* Portfolio / contact: `[aimumtarin@gmail.com]`

**Methods:**
- Reusable SQL views and customer-level metrics
- Repeat-purchase and order-frequency analysis
- RFM segmentation (Recency, Frequency, Monetary)
- Historical CLV with a simple 3-year projection
- Churn windows, and channel, category and return analysis

All of it was written in PostgreSQL.


