/* =====================================================================
   09 · Reporting view. One wide, easy table for BI tools or Excel.
   ===================================================================== */
USE online_retail;

-- V1: Every order line with its product category, region and shipping zone in one place
CREATE OR REPLACE VIEW vw_order_lines AS
SELECT o.invoice_no,
       o.invoice_date,
       YEAR(o.invoice_date)                   AS year,
       DATE_FORMAT(o.invoice_date, '%Y-%m')   AS month,
       o.line_type,
       o.stock_code,
       p.description,
       p.category,
       o.quantity,
       o.unit_price,
       o.line_value,
       CASE WHEN o.line_type = 'Sale'   THEN o.line_value  ELSE 0 END AS sales_value,
       CASE WHEN o.line_type = 'Return' THEN -o.line_value ELSE 0 END AS returned_value,
       o.customer_id,
       c.country_clean                        AS country,
       c.region,
       c.shipping_zone
FROM order_lines o
JOIN products  p ON p.stock_code = o.stock_code
JOIN countries c ON c.country    = o.country;

-- V2: What does the view return by category? (quick check that the view works)
SELECT category,
       ROUND(SUM(sales_value), 2)    AS gross_sales,
       ROUND(SUM(returned_value), 2) AS returned_value
FROM vw_order_lines
GROUP BY category
ORDER BY gross_sales DESC;
