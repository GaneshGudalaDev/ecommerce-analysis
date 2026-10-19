# Data dictionary

Clean tables written by `notebooks/01_data_cleaning.ipynb` to `data/processed/`. They are loaded into MySQL by
`sql/01_create_schema.sql` and into Power BI from the same CSV files.

Source: UCI *Online Retail II* (real invoice lines, UK online gift retailer, 01-Dec-2009 to 09-Dec-2011, CC BY 4.0).

## order_lines (fact table, one row per invoice line)

| Column | Type | Description |
|---|---|---|
| invoice_no | text | Invoice number. Return lines have a `C` in front (credit note) |
| invoice_date | date | Date of the invoice |
| line_type | text | `Sale` or `Return` |
| stock_code | text | Product code, upper case (links to `products`) |
| quantity | integer | Units. **Negative on returns** |
| unit_price | decimal | Price per unit in GBP (always > 0) |
| line_value | decimal | quantity × unit_price. **Negative on returns** |
| customer_id | text | Customer number, or `Unknown` when the retailer didn't record one (about 23% of raw lines) |
| country | text | Customer's country as written in the source (links to `countries`) |

## products

| Column | Type | Description |
|---|---|---|
| stock_code | text | Product code (primary key) |
| description | text | Most common description used for that code |
| category | text | **My own grouping**, from keywords in the description (`data/reference/category_keywords.csv`). The source has no category |

## customers (known customers only)

| Column | Type | Description |
|---|---|---|
| customer_id | text | Primary key |
| country | text | The country the customer orders from most often |
| first_purchase_date | date | Date of their first sale line in the data. Empty for the few customers who only appear with a return |

## countries

| Column | Type | Description |
|---|---|---|
| country | text | Country as written in the source (primary key) |
| country_clean | text | Readable name (`EIRE` → Ireland, `RSA` → South Africa) |
| region | text | United Kingdom / EU / Europe (non-EU) / Rest of World / Unspecified (EU as of 2009–2011) |
| shipping_zone | text | Domestic (UK and Channel Islands) or International |

## delivery_charges

Postage and carriage lines (stock codes `POST`, `DOT`, `C2`), taken out of the product lines and kept here.

| Column | Type | Description |
|---|---|---|
| invoice_no | text | Invoice the charge was on |
| invoice_date | date | |
| line_type | text | `Sale` (charged) or `Return` (refunded) |
| charge_type | text | Postage / Dotcom postage / Carriage |
| line_value | decimal | Amount in GBP (negative when refunded) |
| customer_id | text | As in `order_lines` |
| country | text | As in `order_lines` |

## cleaning_log

One row per cleaning rule: rows before, rows after, rows removed and a note. This is the audit trail from raw to clean.

## What the data does **not** contain
- payment method (so no cash-on-delivery analysis)
- discounts (the source has 177 manual discount lines worth £13k; too few to analyse, removed with the other fee lines)
- dispatch or delivery dates (so no delivery-time analysis)
- return reasons, and a link from a credit note to the original invoice
