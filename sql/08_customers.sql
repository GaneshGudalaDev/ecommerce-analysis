/* =====================================================================
   08 · Customers  (PART 2 – smaller second part)
   Known customers only (customer_id <> 'Unknown').
   ===================================================================== */
USE online_retail;

-- C1: What share of customers come back and order again?
WITH per_customer AS (
    SELECT customer_id,
           COUNT(DISTINCT invoice_no) AS orders,
           SUM(line_value)            AS net_sales
    FROM order_lines
    WHERE customer_id <> 'Unknown' AND line_type = 'Sale'
    GROUP BY customer_id
)
SELECT COUNT(*)                                                                    AS customers,
       SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END)                                AS repeat_customers,
       ROUND(SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)   AS repeat_customer_pct,
       ROUND(SUM(CASE WHEN orders >= 2 THEN net_sales ELSE 0 END) / SUM(net_sales) * 100, 1) AS repeat_sales_pct
FROM per_customer;

-- C2: Who are our 10 biggest customers by net sales?
SELECT *
FROM (
    SELECT o.customer_id,
           c.country,
           COUNT(DISTINCT CASE WHEN o.line_type = 'Sale' THEN o.invoice_no END) AS orders,
           ROUND(SUM(o.line_value), 2)                                         AS net_sales,
           RANK() OVER (ORDER BY SUM(o.line_value) DESC)                       AS customer_rank
    FROM order_lines o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY o.customer_id, c.country
) ranked
WHERE customer_rank <= 10
ORDER BY customer_rank;

-- C3: How many new customers did we win each month? (Dec-2009 is high because the data starts there)
SELECT DATE_FORMAT(first_purchase_date, '%Y-%m') AS month,
       COUNT(*)                                  AS new_customers
FROM customers
WHERE first_purchase_date IS NOT NULL
GROUP BY DATE_FORMAT(first_purchase_date, '%Y-%m')
ORDER BY month;
