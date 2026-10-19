# Power BI report: Returns_Analysis.pbip

Saved as a **Power BI Project** (`.pbip`): the model (`.SemanticModel/`, TMDL text files) and the report pages
(`.Report/`, JSON) are plain text, so changes show up clearly in Git.

## Open it
1. Run `notebooks/01_data_cleaning.ipynb` first, so `data/processed/` has the CSV files.
2. Open `Returns_Analysis.pbip` in Power BI Desktop (2024 or later).
3. **Home › Transform data › Edit parameters** → set `DataFolder` to the full path of your `data\processed\` folder, ending with `\`.
4. **Home › Refresh.**

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
