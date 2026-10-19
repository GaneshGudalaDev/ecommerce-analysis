/* =====================================================================
   06 · Delivery charges  (PART 1 – logistics angle)
   The data has no delivery dates. The only delivery information is the
   postage / carriage lines the retailer charged on invoices.
   ===================================================================== */
USE online_retail;

-- D1: How much postage did we charge, and on what share of orders, for domestic vs international customers?
WITH invoices AS (
    SELECT o.invoice_no, c.shipping_zone, SUM(o.line_value) AS goods_value
    FROM order_lines o
    JOIN countries c ON c.country = o.country
    WHERE o.line_type = 'Sale'
    GROUP BY o.invoice_no, c.shipping_zone
),
postage AS (
    SELECT invoice_no, SUM(line_value) AS postage_value
    FROM delivery_charges
    WHERE line_type = 'Sale'
    GROUP BY invoice_no
)
SELECT i.shipping_zone,
       COUNT(*)                                                               AS orders,
       SUM(CASE WHEN p.invoice_no IS NOT NULL THEN 1 ELSE 0 END)              AS orders_with_postage,
       ROUND(SUM(CASE WHEN p.invoice_no IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_with_postage,
       ROUND(SUM(COALESCE(p.postage_value, 0)), 2)                            AS postage_charged,
       ROUND(SUM(COALESCE(p.postage_value, 0)) / SUM(i.goods_value) * 100, 2) AS postage_pct_of_goods
FROM invoices i
LEFT JOIN postage p ON p.invoice_no = i.invoice_no
GROUP BY i.shipping_zone
ORDER BY orders DESC;

-- D2: Which countries pay the most postage per order?
WITH postage_orders AS (
    SELECT d.invoice_no, c.country_clean AS country, SUM(d.line_value) AS postage_value
    FROM delivery_charges d
    JOIN countries c ON c.country = d.country
    WHERE d.line_type = 'Sale'
    GROUP BY d.invoice_no, c.country_clean
)
SELECT country,
       COUNT(*)                         AS orders_with_postage,
       ROUND(AVG(postage_value), 2)     AS avg_postage_per_order,
       ROUND(SUM(postage_value), 2)     AS total_postage,
       RANK() OVER (ORDER BY AVG(postage_value) DESC) AS postage_rank
FROM postage_orders
GROUP BY country
HAVING COUNT(*) >= 20
ORDER BY postage_rank;

-- D3: How much postage did we refund (postage lines on credit notes)?
SELECT charge_type,
       ROUND(SUM(CASE WHEN line_type = 'Sale'   THEN line_value ELSE 0 END), 2)  AS postage_charged,
       ROUND(-SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END), 2) AS postage_refunded
FROM delivery_charges
GROUP BY charge_type
ORDER BY postage_charged DESC;
