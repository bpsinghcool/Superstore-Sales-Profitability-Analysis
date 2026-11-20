# Data Source — Sample Superstore Dataset

## Overview
This project uses the **Sample Superstore** dataset — a widely-used retail dataset
containing transactional sales, profit, discount and customer records for a
fictional "Superstore Giant." It is the standard dataset for retail profitability
analysis and is used here strictly for educational and portfolio purposes.

---

## Dataset Summary

| Attribute | Value |
|-----------|-------|
| **Dataset name** | Sample Superstore (Superstore Sales) |
| **Scale** | 9,994 rows × 21 columns |
| **Grain** | One row = one product line item within an order |
| **Date coverage** | 2014-01-03 → 2017-12-30 (4 full years) |
| **File used** | `superstore.csv` |
| **SQL table name** | `superstore` (SQL Server Express, `SuperstoreDB`) |
| **Download date** | `[25.10.2026]` |

---

## Source Links

- **Kaggle (primary download):**
  https://www.kaggle.com/datasets/vivek468/superstore-dataset-final
- **Original post (Salesforce Trailhead community):**
  https://trailhead.salesforce.com/trailblazer-community/feed/0D5KX00000kQPXv0AO

---

## Column Metadata

| Column | Description |
|--------|-------------|
| `Row_ID` | Unique ID for each row |
| `Order_ID` | Unique order identifier |
| `Order_Date` | Order date of the product |
| `Ship_Date` | Ship date of the product |
| `Ship_Mode` | Shipping mode specified by the customer |
| `Customer_ID` | Unique customer identifier |
| `Customer_Name` | Customer name |
| `Segment` | Customer segment (Consumer / Corporate / Home Office) |
| `Country` | Country of residence |
| `City` | City of residence |
| `State` | State of residence |
| `Postal_Code` | Customer postal code |
| `Region` | Region (West / East / Central / South) |
| `Product_ID` | Unique product identifier |
| `Category` | Product category (Furniture / Office Supplies / Technology) |
| `Sub_Category` | Product sub-category (17 values, e.g., Tables, Bookcases) |
| `Product_Name` | Product name |
| `Sales` | Revenue for the line item |
| `Quantity` | Units ordered |
| `Discount` | Discount applied (0–1 scale, e.g., 0.20 = 20%) |
| `Profit` | Profit or loss for the line item (can be negative) |

---

## Data Quality Notes

- **Nulls in key columns** (`Sales`, `Profit`, `Discount`, `Order_Date`): **0**
- **Exact duplicate `Order_ID + Product_ID` rows**: **0**
  — Apparent repeats are legitimate multi-line orders
    (same product ordered twice at different quantity / discount).
- **Encoding**: Original CSV throws a UTF-8 encoding warning on SQL Server
    Import Flat File wizard. Resolved by re-saving the file as **CSV UTF-8**
    in Excel before import.
- **Column naming**: Spaces and hyphens removed at import
    (e.g., `Order Date` → `Order_Date`, `Sub-Category` → `Sub_Category`)
    to avoid bracket-quoting throughout SQL queries.

Full validation queries are in `sql/00_data_checks_and_fixes.sql`.

---

## Known Limitations

- The dataset is **synthetic** (created by Tableau for training purposes) — it
  does not reflect real market behaviour, but it does follow realistic retail
  patterns (negative profit at high discounts, seasonal Q4 peaks).
- Data covers **2014–2017 only** — current market conditions may differ.
- No cost-of-goods column is present; `Profit` is provided pre-computed, so
  margin analysis is direct rather than derived.

---

## License & Usage

- **License:** Kaggle public dataset — see the dataset page for exact terms.
- **Usage:** Educational and portfolio purposes only. No commercial redistribution.
- **PII:** This dataset contains **no real customer personally identifiable
  information** — all names, IDs and addresses are fictional.

---

## Attribution

- **Original dataset creator:** Tableau (Sample Superstore)
- **Kaggle mirror:** [vivek468/superstore-dataset-final](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
- **Original community post:** Salesforce Trailhead (link above)
- **This project (analysis, SQL queries, Power BI dashboard):** Birpal Singh

> *"I do not own this data. All credits to the original authors/creators.
>  Used for educational purposes only."*

---

## Citation

If referencing this project or the underlying data:
Sample Superstore Dataset (Tableau).
Retrieved from https://www.kaggle.com/datasets/vivek468/superstore-dataset-final
via the Trailhead community post. Accessed [25-10-2026].

---

## Related Files in This Repo

- `data/superstore.csv` — the exact file used for analysis
- `sql/00_data_checks_and_fixes.sql` — validation queries referenced above
- `README.md` — full project narrative, findings and dashboard