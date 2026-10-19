/* =====================================================================
   04 · Cost of returns  (PART 1 – the main story)
   "Cost" here = the sales value refunded or credited back to customers.
   The data has no handling/restocking costs, so the real cost is higher.
   ===================================================================== */
USE online_retail;

-- RC1: How much sales value did returns cost us each year?
SELECT
    YEAR(invoice_date)                                                       AS year,
    ROUND(SUM(CASE WHEN line_type = 'Sale'   THEN line_value ELSE 0 END), 2)  AS gross_sales,
    ROUND(-SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END), 2) AS returned_value,
    ROUND(-SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END)
          / SUM(CASE WHEN line_type = 'Sale'  THEN line_value ELSE 0 END) * 100, 2) AS return_rate_pct
FROM order_lines
GROUP BY YEAR(invoice_date)
ORDER BY year;

-- RC2: Is the monthly return rate going up or down? (change vs previous month with LAG)
WITH monthly AS (
    SELECT
        DATE_FORMAT(invoice_date, '%Y-%m')                                   AS month,
        SUM(CASE WHEN line_type = 'Sale'   THEN line_value ELSE 0 END)        AS gross_sales,
        -SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END)       AS returned_value
    FROM order_lines
    GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
)
SELECT month,
       ROUND(gross_sales, 2)                                   AS gross_sales,
       ROUND(returned_value, 2)                                AS returned_value,
       ROUND(returned_value / gross_sales * 100, 2)            AS return_rate_pct,
       ROUND(returned_value / gross_sales * 100
             - LAG(returned_value / gross_sales * 100) OVER (ORDER BY month), 2) AS change_vs_last_month_pts
FROM monthly
ORDER BY month;

-- RC3: Which 10 products cost us the most in returns?
WITH product_returns AS (
    SELECT
        p.stock_code,
        p.description,
        p.category,
        SUM(CASE WHEN o.line_type = 'Sale'   THEN o.line_value ELSE 0 END)  AS gross_sales,
        -SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END) AS returned_value
    FROM order_lines o
    JOIN products p ON p.stock_code = o.stock_code
    GROUP BY p.stock_code, p.description, p.category
)
SELECT *
FROM (
    SELECT stock_code,
           description,
           category,
           ROUND(returned_value, 2)                                   AS returned_value,
           ROUND(returned_value / NULLIF(gross_sales, 0) * 100, 2)    AS return_rate_pct,
           RANK() OVER (ORDER BY returned_value DESC)                 AS cost_rank
    FROM product_returns
) ranked
WHERE cost_rank <= 10
ORDER BY cost_rank;

-- RC4: In each category, which 3 products (with at least £2k of sales) have the highest return rate?
WITH product_returns AS (
    SELECT
        p.description,
        p.category,
        SUM(CASE WHEN o.line_type = 'Sale'   THEN o.line_value ELSE 0 END)  AS gross_sales,
        -SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END) AS returned_value
    FROM order_lines o
    JOIN products p ON p.stock_code = o.stock_code
    GROUP BY p.description, p.category
),
ranked AS (
    SELECT description,
           category,
           ROUND(gross_sales, 2)                          AS gross_sales,
           ROUND(returned_value / gross_sales * 100, 2)   AS return_rate_pct,
           RANK() OVER (PARTITION BY category ORDER BY returned_value / gross_sales DESC) AS rank_in_category
    FROM product_returns
    WHERE gross_sales >= 2000
)
SELECT *
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- RC5: How concentrated are returns: what share of returned value comes from the top 10 products?
WITH product_returns AS (
    SELECT stock_code, -SUM(line_value) AS returned_value
    FROM order_lines
    WHERE line_type = 'Return'
    GROUP BY stock_code
),
ranked AS (
    SELECT stock_code, returned_value, RANK() OVER (ORDER BY returned_value DESC) AS cost_rank
    FROM product_returns
)
SELECT
    COUNT(*)                                                                         AS products_returned,
    ROUND(SUM(CASE WHEN cost_rank <= 10  THEN returned_value ELSE 0 END) / SUM(returned_value) * 100, 1) AS top_10_share_pct,
    ROUND(SUM(CASE WHEN cost_rank <= 100 THEN returned_value ELSE 0 END) / SUM(returned_value) * 100, 1) AS top_100_share_pct
FROM ranked;
