/* =====================================================================
   03 · Return rates  (PART 1 – the main story)

   Return rate = returned value / gross sales value
     gross sales value = SUM(line_value) of Sale lines
     returned value    = -SUM(line_value) of Return lines  (made positive)
   ===================================================================== */
USE online_retail;

-- RT1: What share of what we sell comes back as a return?
SELECT
    ROUND(SUM(CASE WHEN line_type = 'Sale'   THEN line_value ELSE 0 END), 2)  AS gross_sales,
    ROUND(-SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END), 2) AS returned_value,
    ROUND(SUM(line_value), 2)                                                 AS net_sales,
    ROUND(-SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END)
          / SUM(CASE WHEN line_type = 'Sale'  THEN line_value ELSE 0 END) * 100, 2) AS return_rate_pct,
    COUNT(DISTINCT CASE WHEN line_type = 'Sale'   THEN invoice_no END)       AS sales_invoices,
    COUNT(DISTINCT CASE WHEN line_type = 'Return' THEN invoice_no END)       AS credit_notes
FROM order_lines;

-- RT2: Which product categories have the highest return rate?
SELECT
    p.category,
    ROUND(SUM(CASE WHEN o.line_type = 'Sale'   THEN o.line_value ELSE 0 END), 2)  AS gross_sales,
    ROUND(-SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END), 2) AS returned_value,
    ROUND(-SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END)
          / SUM(CASE WHEN o.line_type = 'Sale'  THEN o.line_value ELSE 0 END) * 100, 2) AS return_rate_pct
FROM order_lines o
JOIN products p ON p.stock_code = o.stock_code
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- RT3: Do UK, EU and rest-of-world customers return at different rates?
SELECT
    c.region,
    ROUND(SUM(CASE WHEN o.line_type = 'Sale'   THEN o.line_value ELSE 0 END), 2)  AS gross_sales,
    ROUND(-SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END), 2) AS returned_value,
    ROUND(-SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END)
          / SUM(CASE WHEN o.line_type = 'Sale'  THEN o.line_value ELSE 0 END) * 100, 2) AS return_rate_pct
FROM order_lines o
JOIN countries c ON c.country = o.country
GROUP BY c.region
ORDER BY return_rate_pct DESC;

-- RT4: Which countries (with at least £20k of sales) have the highest return rates?
WITH country_returns AS (
    SELECT
        c.country_clean AS country,
        c.region,
        SUM(CASE WHEN o.line_type = 'Sale'   THEN o.line_value ELSE 0 END)  AS gross_sales,
        -SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END) AS returned_value
    FROM order_lines o
    JOIN countries c ON c.country = o.country
    GROUP BY c.country_clean, c.region
)
SELECT country,
       region,
       ROUND(gross_sales, 2)                              AS gross_sales,
       ROUND(returned_value, 2)                           AS returned_value,
       ROUND(returned_value / gross_sales * 100, 2)       AS return_rate_pct,
       RANK() OVER (ORDER BY returned_value / gross_sales DESC) AS return_rate_rank
FROM country_returns
WHERE gross_sales >= 20000
ORDER BY return_rate_rank;

-- RT5: Are orders shipped abroad returned more than domestic (UK) orders?
SELECT
    c.shipping_zone,
    COUNT(DISTINCT CASE WHEN o.line_type = 'Sale'   THEN o.invoice_no END)    AS sales_invoices,
    COUNT(DISTINCT CASE WHEN o.line_type = 'Return' THEN o.invoice_no END)    AS credit_notes,
    ROUND(-SUM(CASE WHEN o.line_type = 'Return' THEN o.line_value ELSE 0 END)
          / SUM(CASE WHEN o.line_type = 'Sale'  THEN o.line_value ELSE 0 END) * 100, 2) AS return_rate_pct
FROM order_lines o
JOIN countries c ON c.country = o.country
GROUP BY c.shipping_zone
ORDER BY return_rate_pct DESC;
