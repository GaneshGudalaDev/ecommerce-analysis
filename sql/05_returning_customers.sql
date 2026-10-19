/* =====================================================================
   05 · Who returns?  (PART 1 – the main story)
   Customer-level questions use known customers only (customer_id <> 'Unknown').
   ===================================================================== */
USE online_retail;

-- RCU1: How many customers have returned something at least once?
WITH per_customer AS (
    SELECT customer_id,
           SUM(CASE WHEN line_type = 'Return' THEN 1 ELSE 0 END) AS return_lines
    FROM order_lines
    WHERE customer_id <> 'Unknown'
    GROUP BY customer_id
)
SELECT COUNT(*)                                                         AS customers,
       SUM(CASE WHEN return_lines > 0 THEN 1 ELSE 0 END)                AS customers_with_a_return,
       ROUND(SUM(CASE WHEN return_lines > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_with_a_return
FROM per_customer;

-- RCU2: Which 10 customers return the most, and what is their return rate?
WITH per_customer AS (
    SELECT o.customer_id,
           c.country,
           SUM(CASE WHEN o.line_type = 'Sale'   THEN o.line_value ELSE 0 END)  AS gross_sales,
           -SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END) AS returned_value
    FROM order_lines o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY o.customer_id, c.country
)
SELECT *
FROM (
    SELECT customer_id,
           country,
           ROUND(gross_sales, 2)                                  AS gross_sales,
           ROUND(returned_value, 2)                               AS returned_value,
           ROUND(returned_value / NULLIF(gross_sales, 0) * 100, 1) AS return_rate_pct,
           RANK() OVER (ORDER BY returned_value DESC)             AS returns_rank
    FROM per_customer
) ranked
WHERE returns_rank <= 10
ORDER BY returns_rank;

-- RCU3: How are customers spread across return-rate bands, and how much do they buy?
WITH per_customer AS (
    SELECT customer_id,
           SUM(CASE WHEN line_type = 'Sale'   THEN line_value ELSE 0 END)  AS gross_sales,
           -SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END) AS returned_value
    FROM order_lines
    WHERE customer_id <> 'Unknown'
    GROUP BY customer_id
    HAVING SUM(CASE WHEN line_type = 'Sale' THEN line_value ELSE 0 END) > 0
),
banded AS (
    SELECT customer_id, gross_sales, returned_value,
           CASE WHEN returned_value = 0                    THEN '1. No returns'
                WHEN returned_value / gross_sales < 0.02   THEN '2. Under 2%'
                WHEN returned_value / gross_sales < 0.05   THEN '3. 2-5%'
                WHEN returned_value / gross_sales < 0.10   THEN '4. 5-10%'
                ELSE '5. 10% or more' END                  AS return_band
    FROM per_customer
)
SELECT return_band,
       COUNT(*)                         AS customers,
       ROUND(SUM(gross_sales), 2)       AS gross_sales,
       ROUND(SUM(returned_value), 2)    AS returned_value
FROM banded
GROUP BY return_band
ORDER BY return_band;

-- RCU4: Do customers who buy more often return a bigger share? (customers grouped by number of invoices)
WITH per_customer AS (
    SELECT customer_id,
           COUNT(DISTINCT CASE WHEN line_type = 'Sale' THEN invoice_no END)    AS orders,
           SUM(CASE WHEN line_type = 'Sale'   THEN line_value ELSE 0 END)       AS gross_sales,
           -SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END)      AS returned_value
    FROM order_lines
    WHERE customer_id <> 'Unknown'
    GROUP BY customer_id
)
SELECT CASE WHEN orders <= 1  THEN '1 order'
            WHEN orders <= 5  THEN '2-5 orders'
            WHEN orders <= 20 THEN '6-20 orders'
            ELSE '21+ orders' END                              AS order_frequency,
       COUNT(*)                                                AS customers,
       ROUND(SUM(returned_value) / SUM(gross_sales) * 100, 2)  AS return_rate_pct
FROM per_customer
WHERE gross_sales > 0
GROUP BY order_frequency
ORDER BY MIN(orders);
