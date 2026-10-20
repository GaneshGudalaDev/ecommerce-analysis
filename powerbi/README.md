# Power BI report: Returns_Analysis.pbip

Saved as a **Power BI Project** (`.pbip`): the model (`.SemanticModel/`, TMDL text files) and the report pages
(`.Report/`, JSON) are plain text, so changes show up clearly in Git.

## Open it
1. Run `notebooks/01_data_cleaning.ipynb` first, so `data/processed/` has the CSV files.
2. Open `Returns_Analysis.pbip` in Power BI Desktop (2024 or later).
3. The `DataFolder` parameter defaults to `C:\data\processed\`. Either copy the CSV files there, or go to
   **Home › Transform data › Edit parameters** and set it to the full path of your own `data\processed\` folder (ending with `\`).
4. **Home › Refresh.**

## Report settings worth knowing
- **Tables are sorted biggest first:** products, customers and countries by returned value; the Customers page by net sales.
  Click any column header to re-sort.
- **Customer tables hide `Unknown`** (orders with no customer id) with a visual-level filter, so only real customers are ranked.
- **Monthly charts leave out December 2011.** The data stops on 9 Dec 2011, so that month would look like a sudden drop.
  The `Date` table has an `Is Full Month` column (FALSE from 1 Dec 2011), and every monthly chart has a visual-level filter
  `Is Full Month = TRUE`. KPI cards and the other charts still include those 9 days.

## Model (star schema)

```
            Date ─────┐
        Products ─────┤
       Customers ─────┼──► OrderLines (fact: one row per invoice line)
       Countries ─────┤
                      └──► DeliveryCharges (postage lines) ◄── Date, Countries
```

All relationships are one-to-many, single direction, from the lookup table to the fact table.

## Measures (14, in the `_Measures` table)

| Folder | Measures |
|---|---|
| 1 Returns | Returned Value, Return Rate %, Units Returned, Credit Notes |
| 2 Sales | Gross Sales, Net Sales, Orders, Average Order Value |
| 3 Customers | Customers, Customers Who Returned, % Customers Who Returned, Repeat Customer % |
| 4 Delivery | Postage Charged, Postage % of Goods |

Definitions are in [../docs/kpi_definitions.md](../docs/kpi_definitions.md).

## Pages

| Page | What it shows |
|---|---|
| Returns Overview | KPI cards; return rate by category, region, UK vs international; returned value and return rate by month |
| Return Drivers | Tables of products, customers and countries ranked by returned value; returned value by category |
| Sales & Delivery | Net sales by month, category and region; postage as % of goods value |
| Customers | Active customers by month, repeat %, customers by region, customer table |

Every page has Year, Region and Category slicers.
