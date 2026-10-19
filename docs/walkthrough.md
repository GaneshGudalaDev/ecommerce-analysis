# Walkthrough: how this project works

A guide to explaining every part of the project in an interview. Read it next to the files it mentions.
Work through it in order: the data, then the cleaning, then the SQL, then Power BI.

---

## 1. The data (30-second version)

> "I used the UCI Online Retail II dataset. It's real invoice data from a UK online retailer that sells gifts, mainly
> to small shops, from December 2009 to December 2011. That's about a million invoice lines. Returns are booked
> as credit notes, which are invoices starting with a C and with negative quantities, so I could measure
> returns directly."

Things to know:
- **One row = one product on one invoice.** An invoice (order) has many lines.
- **Credit note = return or cancellation.** The data doesn't say which, or why, and it doesn't link the credit note to the original order.
- **No category, payment method, discount or delivery date.** Be upfront about this. It shows you understand your data.

---

## 2. Cleaning (`notebooks/01_data_cleaning.ipynb`)

Every rule writes a row to `cleaning_log.csv` (rows before, rows after). If asked "how do you know your cleaning was right?",
point to the log plus the validation checks at the end of the notebook.

| Step | What and why | Code idea |
|---|---|---|
| Rename columns | `Customer ID` → `customer_id`, so they are easy to type in SQL | `df.rename(columns={...})` |
| Standardise codes | `15056bl` and `15056BL` are the same product. Power BI treats keys case-insensitively, so they would clash | `.str.strip().str.upper()` |
| Duplicates | 34,335 rows were exact copies (export ran twice), plus 4 double entries | `drop_duplicates()` |
| Sale or return | Invoice starts with `C` → Return; with `A` → bad-debt adjustment | `df.loc[df.invoice_no.str.startswith("C"), "line_type"] = "Return"` |
| Non-product lines | Real products have codes starting with 5 digits. `POST`/`DOT`/`C2` are postage (kept in a separate table); `M`, `BANK CHARGES`, `AMAZONFEE`… are fees (removed) | `str.match(r"^\d{5}")` |
| Zero prices | Price 0 lines with notes like *damaged*, *lost* are warehouse write-offs, not customer returns | `df[df.unit_price > 0]` |
| Bulk-order mistakes | Two orders of 80,995 and 74,215 units, each cancelled 20 minutes later. Left in, they'd be about a third of all returns | `df[df.quantity.abs() <= 50000]` |
| Missing customer | 23% of lines have no customer id. I kept them as `Unknown` (they're real sales) and only leave them out of customer-level numbers | `map(lambda x: "Unknown" if pd.isna(x) else ...)` |
| Categories | Made my own from keywords in the description (`MUG` → Kitchen & Dining). First matching keyword wins | loop over `category_keywords.csv` |
| Regions | Small lookup table: country → region and Domestic/International | `country_regions.csv` |

**Likely question: "Why not just delete rows with no customer id?"**
Because they are about a fifth of real sales, so deleting them would understate every sales and return number. I only
exclude them when the question is about customers.

**Likely question: "How did you decide on the categories?"**
I listed the most common words in product names, grouped them into 10 categories, and checked how much sales value was
left in *Other* (about 4%). It's my own grouping, and I say so in the README.

---

## 3. SQL (`sql/`)

Run order: `01` creates and loads the tables, `02` checks the data, and `03`–`09` answer the questions.
Every query has a comment above it saying which business question it answers. Read those comments out loud
as you explain each query.

### The one pattern used everywhere: conditional aggregation

```sql
SUM(CASE WHEN line_type = 'Sale'   THEN line_value ELSE 0 END)   -- gross sales
-SUM(CASE WHEN line_type = 'Return' THEN line_value ELSE 0 END)  -- returned value (made positive)
```
"Sales and returns are in the same table, so I use CASE WHEN inside SUM to add up only the rows I want.
Dividing the two gives the return rate. It's one pass over the table, with no self-join."

### File by file

| File | What it shows you can do | Key idea to explain |
|---|---|---|
| `01_create_schema.sql` | DDL, keys, `LOAD DATA` | primary and foreign keys; why `customer_id` is text |
| `02_data_quality_checks.sql` | Testing data | `LEFT JOIN … WHERE x IS NULL` finds orphan rows; `GROUP BY … HAVING COUNT(*) > 1` finds duplicates |
| `03_return_rates.sql` | JOIN + GROUP BY + CASE WHEN | return rate by category (JOIN products), by region (JOIN countries); RT4 uses a **CTE** and **RANK()** |
| `04_cost_of_returns.sql` | Window functions | RC2: **LAG()** compares each month with the previous one. RC4: **RANK() OVER (PARTITION BY category …)** gives a top 3 *within* each category |
| `05_returning_customers.sql` | Customer-level CTEs | build one row per customer first (CTE), then band them with CASE WHEN |
| `06_delivery_charges.sql` | LEFT JOIN of two CTEs | orders with and without a postage line; `COALESCE` turns missing postage into 0 |
| `07_sales_overview.sql` | Sales KPIs | S2: LAG(…, 12) = same month last year; S3: share of total with a `CROSS JOIN` to a one-row total CTE |
| `08_customers.sql` | Repeat customers | count orders per customer, then `CASE WHEN orders >= 2` |
| `09_reporting_view.sql` | Views | one wide view so Excel or BI tools don't need to repeat the joins |

**RANK vs ROW_NUMBER:** RANK gives ties the same number (1, 2, 2, 4). ROW_NUMBER always counts 1, 2, 3, 4.

**Why a CTE?** It breaks the query into named steps, so it reads top to bottom: "first per-product totals, then rank them".

**How did you test it?** `python scripts/run_sql_tests.py` runs all 34 queries on the clean data. It fails if any
data-quality check finds a problem, and it recalculates gross sales and returns in pandas to prove they match.

---

## 4. Power BI (`powerbi/Returns_Analysis.pbip`)

### Model: a star schema
- **Fact table:** `OrderLines`, one row per invoice line (the numbers).
- **Lookup (dimension) tables:** `Products`, `Customers`, `Countries`, `Date`, which hold the descriptions you slice by.
- `DeliveryCharges` is a second small fact table that shares `Date` and `Countries`.
- Relationships are one-to-many, filtering one way (lookup → fact).

"I used a star schema so every filter flows one way from a lookup table to the fact table. The DAX stays simple,
and a Region slicer filters both sales and postage."

### The 14 measures, in plain words

| Measure | DAX | Say it as |
|---|---|---|
| Gross Sales | `CALCULATE(SUM(OrderLines[line_value]), OrderLines[line_type] = "Sale")` | sum of line value, only sale lines |
| Returned Value | `-CALCULATE(SUM(...), line_type = "Return")` | sum of return lines, made positive |
| Return Rate % | `DIVIDE([Returned Value], [Gross Sales])` | DIVIDE avoids divide-by-zero errors |
| Net Sales | `SUM(OrderLines[line_value])` | returns are negative, so a plain sum is sales minus returns |
| Orders / Credit Notes | `CALCULATE(DISTINCTCOUNT(invoice_no), line_type = …)` | count distinct invoices of each type |
| Average Order Value | `DIVIDE([Gross Sales], [Orders])` | |
| Customers | `DISTINCTCOUNT(customer_id)` excluding "Unknown" | |
| Customers Who Returned | `CALCULATE([Customers], line_type = "Return")` | a measure reused inside CALCULATE |
| Repeat Customer % | `FILTER(VALUES(customer_id), [Orders] >= 2)` | for each customer, keep those with 2+ orders, then count them |
| Postage Charged / % of Goods | sum of postage lines; ÷ Gross Sales | |

**CALCULATE in one sentence:** "It calculates an expression after changing the filter, here adding `line_type = Sale`."

**Why measures and not calculated columns?** Measures recalculate for whatever is selected (a year, a region).
A calculated column is fixed per row.

### Pages
1. **Returns Overview:** the headline cards, plus where and when returns happen.
2. **Return Drivers:** which products, customers and countries. Click a table header to sort.
3. **Sales & Delivery:** net sales trend, categories, regions, and postage % of goods.
4. **Customers:** active customers, repeat %, biggest customers.

---

## 5. Questions to be ready for

- **"What would you do next with better data?"** Link credit notes to the original order (to measure time to return),
  record return reasons, and add dispatch and delivery dates to test whether late deliveries cause returns.
- **"What's the business recommendation?"** Look at the 297 customers who return 10% or more of what they buy, and the
  top 10 returned products (15% of all returned value). Check packaging on fragile Candles & Lighting items. Review the
  high-return EU accounts one by one.
- **"Is 2.4% high?"** For trade buyers it's low. Online fashion return rates are often quoted at 20–30%. That's why I break it down: the overall
  number hides pockets like a 13% country rate that comes from one customer.
- **"What was hardest?"** Deciding what counts as a return: separating customer credit notes from fees, postage, write-offs
  and order-entry mistakes.
