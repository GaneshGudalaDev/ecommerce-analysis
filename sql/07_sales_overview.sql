/* =====================================================================
   07 · Sales overview  (PART 2 – smaller second part)
   Net sales = sales minus returns = SUM(line_value) over all lines.
   ===================================================================== */
USE online_retail;

-- S1: What are the headline sales numbers?
SELECT
    ROUND(SUM(line_value), 2)                                                     AS net_sales,
    COUNT(DISTINCT CASE WHEN line_type = 'Sale' THEN invoice_no END)              AS orders,
    ROUND(SUM(CASE WHEN line_type = 'Sale' THEN line_value ELSE 0 END)
          / COUNT(DISTINCT CASE WHEN line_type = 'Sale' THEN invoice_no END), 2)  AS avg_order_value,
    COUNT(DISTINCT CASE WHEN customer_id <> 'Unknown' THEN customer_id END)       AS known_customers,
    COUNT(DISTINCT stock_code)                                                    AS products_sold
FROM order_lines;

-- S2: How do monthly net sales change from one month to the next? (LAG)
WITH monthly AS (
    SELECT DATE_FORMAT(invoice_date, '%Y-%m') AS month,
           SUM(line_value)                    AS net_sales
    FROM order_lines
    GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
)
SELECT month,
       ROUND(net_sales, 2)                                                            AS net_sales,
       ROUND((net_sales - LAG(net_sales) OVER (ORDER BY month))
             / LAG(net_sales) OVER (ORDER BY month) * 100, 1)                         AS change_vs_last_month_pct,
       ROUND((net_sales - LAG(net_sales, 12) OVER (ORDER BY month))
             / LAG(net_sales, 12) OVER (ORDER BY month) * 100, 1)                     AS change_vs_same_month_last_year_pct
FROM monthly
ORDER BY month;

-- S3: Which categories bring in the most net sales, and what share of the total?
WITH by_category AS (
    SELECT p.category, SUM(o.line_value) AS net_sales
    FROM order_lines o
    JOIN products p ON p.stock_code = o.stock_code
    GROUP BY p.category
),
total AS (
    SELECT SUM(net_sales) AS all_sales FROM by_category
)
SELECT b.category,
       ROUND(b.net_sales, 2)                       AS net_sales,
       ROUND(b.net_sales / t.all_sales * 100, 1)   AS pct_of_sales
FROM by_category b
CROSS JOIN total t
ORDER BY b.net_sales DESC;

-- S4: What are the top 10 products by net sales?
SELECT *
FROM (
    SELECT p.description,
           p.category,
           ROUND(SUM(o.line_value), 2)                    AS net_sales,
           SUM(o.quantity)                                AS net_units,
           RANK() OVER (ORDER BY SUM(o.line_value) DESC)  AS sales_rank
    FROM order_lines o
    JOIN products p ON p.stock_code = o.stock_code
    GROUP BY p.description, p.category
) ranked
WHERE sales_rank <= 10
ORDER BY sales_rank;

-- S5: How much do we sell in each region?
SELECT c.region,
       ROUND(SUM(o.line_value), 2)                                         AS net_sales,
       COUNT(DISTINCT CASE WHEN o.line_type = 'Sale' THEN o.invoice_no END) AS orders,
       COUNT(DISTINCT CASE WHEN o.customer_id <> 'Unknown' THEN o.customer_id END) AS customers
FROM order_lines o
JOIN countries c ON c.country = o.country
GROUP BY c.region
ORDER BY net_sales DESC;
