/* =====================================================================
   Returns, discount & delivery analysis  ·  UK online gift retailer (UCI Online Retail II)
   01 · Create tables and load the cleaned CSVs  (MySQL 8.0)

   order_lines       one row per invoice line. line_type = 'Sale' or 'Return'.
                     Returns have a negative quantity and a negative line_value.
   products          stock_code -> description, category (category is my keyword grouping)
   customers         customer_id -> main country, first purchase date
   countries         country -> region, shipping zone (Domestic / International)
   delivery_charges  postage and carriage lines charged on invoices

   Run from the repo root:  mysql --local-infile=1 -u <user> -p < sql/01_create_schema.sql
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS online_retail;
USE online_retail;

DROP TABLE IF EXISTS order_lines;
DROP TABLE IF EXISTS delivery_charges;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS countries;

CREATE TABLE countries (
    country        VARCHAR(40) PRIMARY KEY,
    country_clean  VARCHAR(40) NOT NULL,
    region         VARCHAR(20) NOT NULL,
    shipping_zone  VARCHAR(15) NOT NULL
);

CREATE TABLE products (
    stock_code   VARCHAR(12) PRIMARY KEY,
    description  VARCHAR(80) NOT NULL,
    category     VARCHAR(30) NOT NULL
);

CREATE TABLE customers (
    customer_id          VARCHAR(10) PRIMARY KEY,
    country              VARCHAR(40) NOT NULL,
    first_purchase_date  DATE
);

CREATE TABLE order_lines (
    invoice_no    VARCHAR(10)   NOT NULL,
    invoice_date  DATE          NOT NULL,
    line_type     VARCHAR(10)   NOT NULL,
    stock_code    VARCHAR(12)   NOT NULL,
    quantity      INT           NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    line_value    DECIMAL(12,2) NOT NULL,
    customer_id   VARCHAR(10)   NOT NULL,   -- 'Unknown' when the retailer didn't record one
    country       VARCHAR(40)   NOT NULL,
    INDEX ix_lines_date (invoice_date),
    INDEX ix_lines_product (stock_code),
    INDEX ix_lines_customer (customer_id),
    CONSTRAINT fk_lines_product FOREIGN KEY (stock_code) REFERENCES products (stock_code),
    CONSTRAINT fk_lines_country FOREIGN KEY (country)    REFERENCES countries (country)
);

CREATE TABLE delivery_charges (
    invoice_no    VARCHAR(10)   NOT NULL,
    invoice_date  DATE          NOT NULL,
    line_type     VARCHAR(10)   NOT NULL,
    charge_type   VARCHAR(20)   NOT NULL,
    line_value    DECIMAL(12,2) NOT NULL,
    customer_id   VARCHAR(10)   NOT NULL,
    country       VARCHAR(40)   NOT NULL
);

-- SET GLOBAL local_infile = 1;   -- once, as admin, if LOCAL INFILE is disabled
LOAD DATA LOCAL INFILE 'data/processed/countries.csv' INTO TABLE countries
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/processed/products.csv' INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/processed/customers.csv' INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(customer_id, country, @first_purchase_date)
SET first_purchase_date = NULLIF(TRIM(@first_purchase_date), '');

LOAD DATA LOCAL INFILE 'data/processed/order_lines.csv' INTO TABLE order_lines
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/processed/delivery_charges.csv' INTO TABLE delivery_charges
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- How many rows landed in each table?
SELECT 'order_lines' AS table_name, COUNT(*) AS row_count FROM order_lines
UNION ALL SELECT 'products',         COUNT(*) FROM products
UNION ALL SELECT 'customers',        COUNT(*) FROM customers
UNION ALL SELECT 'countries',        COUNT(*) FROM countries
UNION ALL SELECT 'delivery_charges', COUNT(*) FROM delivery_charges;
