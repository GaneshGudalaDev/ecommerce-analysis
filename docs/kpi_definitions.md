# KPI definitions

Each KPI means the same thing in SQL (`sql/`), Python (`notebooks/02_returns_analysis.ipynb`) and Power BI (the `_Measures` table).

## Part 1: Returns

| KPI | Definition | DAX measure | Value (Dec-2009 to Dec-2011) |
|---|---|---|---|
| Gross Sales | Sum of `line_value` on **Sale** lines | `Gross Sales` | £19.40m |
| Returned Value (cost of returns) | Sum of `line_value` on **Return** lines, made positive | `Returned Value` | £470.8k |
| Return Rate % | Returned Value ÷ Gross Sales | `Return Rate %` | 2.4% |
| Units Returned | Sum of `quantity` on Return lines, made positive | `Units Returned` | |
| Credit Notes | Number of distinct return invoices (`C…`) | `Credit Notes` | 7,403 |
| Customers Who Returned | Known customers with at least one return line | `Customers Who Returned` | 2,442 |
| % Customers Who Returned | Customers Who Returned ÷ Customers | `% Customers Who Returned` | 41.6% |

**Why value and not count?** A return of 1 cheap item and a return of 500 cake stands are both "one line". Value shows what returns cost.

**Limits:** "Returns" includes cancellations, because the data books both as credit notes. The cost is only the value credited;
handling, restocking and return-postage costs aren't in the data.

## Part 1: Delivery

| KPI | Definition | DAX measure | Value |
|---|---|---|---|
| Postage Charged | Sum of postage/carriage lines on sales invoices | `Postage Charged` | £449k |
| Postage % of Goods | Postage Charged ÷ Gross Sales. Use it by region or month only, because postage isn't linked to products | `Postage % of Goods` | 2.3% |

## Part 2: Sales and customers

| KPI | Definition | DAX measure | Value |
|---|---|---|---|
| Net Sales | Sum of all `line_value` (sales minus returns) | `Net Sales` | £18.93m |
| Orders | Distinct sales invoices | `Orders` | 39,514 |
| Average Order Value | Gross Sales ÷ Orders | `Average Order Value` | £491 |
| Customers | Distinct known customers (`customer_id` ≠ `Unknown`) | `Customers` | 5,875 |
| Repeat Customer % | Known customers with 2+ orders ÷ known customers with an order | `Repeat Customer %` | 72.3% |

That is 14 measures in total. They are all simple `SUM`, `DISTINCTCOUNT`, `CALCULATE` with one filter, and `DIVIDE`.
`Repeat Customer %` is the only one with a `VAR` and a `FILTER`.
