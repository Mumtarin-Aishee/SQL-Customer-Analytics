# Ecommerce Customer Analytics: Repeat Purchase, RFM Segmentation & Customer Value

**PostgreSQL (Supabase) · RFM segmentation · Customer lifetime value (CLV) · Churn · Repeat-purchase analysis**

## Executive Summary
**What was analyzed:** 3,000 orders placed by 954 buying customers (out of 1,000 registered) of an ecommerce business. The data covers 25 March 2021 to 25 March 2023.

## Business Problem
An ecommerce business sells six product categories (Toys, Automotive, Home, Electronics, Fashion, Books). It sells online and in-store, to customers in 10 cities. It wants to know:

- **Who comes back?** How many customers stop after one order, and how many return?
- **Who is worth the most?** Which customers and segments generate most of the value?
- **Who is slipping away?** Which valuable customers have stopped buying recently?

Answering these lets the business spend retention and marketing budget on the right customers, instead of treating everyone the same.

A key complication: **about half of all orders were returned (50.27%)**. So a customer's sales total and the money the business actually keeps can be very different. This analysis tracks both.

**Methods:**
- Reusable SQL views and customer-level metrics
- Repeat-purchase and order-frequency analysis
- RFM segmentation (Recency, Frequency, Monetary)
- Historical CLV with a simple 3-year projection
- Churn windows, and channel, category and return analysis

All of it was written in PostgreSQL.

**Headline results ✅**
- **84.7%** of buyers ordered more than once. Repeat buyers account for **95.87%** of kept revenue.
- **Champions** (169 customers) generate **33.1%** of net revenue. **At Risk** customers (77) still hold **12.4%**.
- The top **20%** of customers hold **52.1%** of kept CLV.
- **179 customers (18.8%) returned every order**, so their kept CLV is 0.
- **47.2%** of buyers made no purchase in the last 6 months of the data.

**Deliverables:** SQL view definitions, documented analysis queries, a per-customer CLV output file, and a summary dashboard and Q&A chatbot ([Project Deliverables](#project-deliverables)).


