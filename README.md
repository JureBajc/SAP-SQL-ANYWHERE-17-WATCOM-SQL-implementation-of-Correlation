# SAP SQL Anywhere 17 - Watcom SQL Implementation of Correlation Procedures

This repository provides a set of advanced SQL stored procedures for SAP SQL Anywhere 17 (Watcom SQL dialect) to compute correlation matrices and heatmaps for both numerical and categorical data. The procedures support multiple correlation methods and are designed for flexible exploratory data analysis directly within the database.

---

## Features

- **Correlation Matrix Calculation**  
  Compute correlation matrices for all pairs of numeric columns (Pearson/Spearman) or categorical columns (Cramer's V).

- **Asymmetric Correlation (Eta Squared)**
  Calculate eta squared statistics for all combinations of categorical and numeric variables (asymmetric measure).

- **Heatmap Output**  
  Generate results in long format with optional color coding for visualization.

- **Robust Input Handling**  
  Accepts arbitrary SQL queries as input for data selection.

- **Flexible Method Selection**  
  Supports multiple correlation methods: `PEARSON`, `SPEARMAN`, `CRAMER`, and `ETA`.

---

## Stored Procedures

### 1. `proc_korelacija`

Calculates a correlation matrix for the provided query.

**Parameters:**
- `in_query` (long varchar): SQL query returning the source data.
- `in_method` (long varchar): Correlation method (`PEARSON`, `SPEARMAN`, or `CRAMER`). Default is `PEARSON`.

**Result:**  
Creates/overwrites the table `goinfo.korelacija_rezultat` with the correlation matrix.

### 2. `proc_korelacija_asim`

Calculates an asymmetric eta squared matrix for categorical vs. numeric columns.

**Parameters:**
- `in_query` (long varchar): SQL query returning the source data.

**Result:**  
Creates/overwrites the table `goinfo.korelacija_rezultat` with the eta squared values.

### 3. `proc_korelacija_heatmap`

Router procedure that produces a heatmap-friendly long-format output and color encoding.

**Parameters:**
- `in_query` (long varchar): SQL query returning the source data.
- `in_add_colors` (varchar(1)): `'y'` for color-coding output, `'n'` for none. Default `'y'`.
- `in_method` (varchar(10)): Correlation method (`pearson`, `spearman`, `cramer`, or `eta`). Default is `pearson`.

**Result:**  
Populates the table `dis_temp` with heatmap data, ready for visualization.

---

## Usage Example

```sql
-- Example: Calculate Pearson correlation matrix for a table
call goinfo.proc_korelacija('select * from my_table', 'PEARSON');

-- Example: Calculate Cramer's V matrix for categorical variables
call goinfo.proc_korelacija('select * from my_table', 'CRAMER');

-- Example: Calculate eta squared for categorical vs numeric columns
call goinfo.proc_korelacija_asim('select * from my_table');

-- Example: Generate a heatmap for all correlations with color coding
call goinfo.proc_korelacija_heatmap('select * from my_table', 'y', 'pearson');
```

---

## Output Tables

- **`goinfo.korelacija_rezultat`**: Contains the correlation or eta squared matrix (pivoted format).
- **`dis_temp`**: Contains long-format heatmap data (for visualization).

---

## Supported Methods

| Method    | Description                                   | Procedure(s)         |
|-----------|-----------------------------------------------|----------------------|
| PEARSON   | Standard Pearson correlation (numeric)        | proc_korelacija      |
| SPEARMAN  | Rank-based Spearman correlation (numeric)     | proc_korelacija      |
| CRAMER    | Cramer's V for categorical variables          | proc_korelacija      |
| ETA       | Eta squared (categorical vs. numeric, asym.)  | proc_korelacija_asim |

---

## Requirements

- **SAP SQL Anywhere 17** or compatible version.
- Sufficient privileges to create/drop tables in the target schema.
- The schema `goinfo` must exist or be created prior to usage.

---

## Notes

- Procedures automatically detect column types via `sa_describe_query`.
- All intermediate tables are managed as local temporary tables.
- Output tables are overwritten on each procedure call.
- Error handling is basic; ensure queries are well-formed for best results.

---

## License

MIT License

---

## Author

[JureBajc](https://github.com/JureBajc)
