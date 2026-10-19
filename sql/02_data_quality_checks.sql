/* =====================================================================
   02 · Data quality checks. Run after every load.
   DQ1–DQ5 should all return 0 (or no rows). DQ6 is just a summary.
   ===================================================================== */
USE online_retail;

-- DQ1: Are any order lines exact duplicates?
SELECT invoice_no, stock_code, quantity, unit_price, customer_id, COUNT(*) AS copies
FROM order_lines
GROUP BY invoice_no, stock_code, quantity, unit_price, customer_id, invoice_date, line_type, country, line_value
HAVING COUNT(*) > 1;

-- DQ2: Does every order line point to a known product and country?
SELECT
    SUM(CASE WHEN p.stock_code IS NULL THEN 1 ELSE 0 END) AS lines_without_product,
    SUM(CASE WHEN c.country    IS NULL THEN 1 ELSE 0 END) AS lines_without_country
FROM order_lines o
LEFT JOIN products  p ON p.stock_code = o.stock_code
LEFT JOIN countries c ON c.country    = o.country;

-- DQ3: Do sales have positive quantities and returns negative ones?
SELECT
    SUM(CASE WHEN line_type = 'Sale'   AND quantity <= 0 THEN 1 ELSE 0 END) AS bad_sales,
    SUM(CASE WHEN line_type = 'Return' AND quantity >= 0 THEN 1 ELSE 0 END) AS bad_returns,
    SUM(CASE WHEN line_type NOT IN ('Sale', 'Return')   THEN 1 ELSE 0 END) AS unknown_line_types
FROM order_lines;

-- DQ4: Does line_value always equal quantity x unit_price?
SELECT COUNT(*) AS wrong_line_values
FROM order_lines
WHERE ABS(quantity * unit_price - line_value) > 0.01;

-- DQ5: Are there any zero or negative prices left?
SELECT COUNT(*) AS bad_prices
FROM order_lines
WHERE unit_price <= 0;

-- DQ6: What period, how many invoices and how many customers does the data cover?
SELECT MIN(invoice_date)                                                   AS first_date,
       MAX(invoice_date)                                                   AS last_date,
       COUNT(DISTINCT invoice_no)                                          AS invoices,
       COUNT(*)                                                            AS lines,
       COUNT(DISTINCT CASE WHEN customer_id <> 'Unknown' THEN customer_id END) AS known_customers
FROM order_lines;
