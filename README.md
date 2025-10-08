# proc_korelacija.sql — Correlation Matrix Procedure for SAP SQL Anywhere 17

This repository provides a powerful SQL stored procedure for calculating correlation matrices across all numeric and categorical columns in your dataset using SAP SQL Anywhere 17 (Watcom SQL).

## 📄 What is `proc_korelacija.sql`?

`proc_korelacija.sql` defines the stored procedure `goinfo.proc_korelacija`, which enables automated computation of correlation coefficients between variables in any query result set. The procedure supports:

- **PEARSON**: Standard Pearson correlation for numeric columns
- **SPEARMAN**: Rank-based Spearman correlation for numeric columns
- **CRAMER**: Cramér's V calculation for categorical columns

The procedure automatically pivots results into a correlation matrix for easy analysis.

## ⚙️ How Does It Work?

You call `goinfo.proc_korelacija` with:
- `in_query`: Your SQL query returning the data to analyze
- `in_method`: The correlation method (`PEARSON`, `SPEARMAN`, or `CRAMER`)

Based on your input, the procedure:
1. Identifies relevant columns (numeric or categorical)
2. Calculates pairwise correlations using the selected method
3. Generates a pivoted correlation matrix as the output table `goinfo.korelacija_rezultat`

## 🚀 Usage Example

```sql
-- Example usage for numeric columns with Spearman correlation:
call goinfo.proc_korelacija(
    'SELECT col1, col2, col3 FROM your_table',
    'SPEARMAN'
);

-- Example usage for categorical columns with Cramér's V:
call goinfo.proc_korelacija(
    'SELECT cat1, cat2 FROM your_table',
    'CRAMER'
);

-- View the resulting matrix:
SELECT * FROM goinfo.korelacija_rezultat;
```

## 📝 Parameters

- `in_query` (long varchar): SQL query string that returns the dataset to analyze.
- `in_method` (long varchar): Correlation type. Options:
  - `'PEARSON'` (default)
  - `'SPEARMAN'`
  - `'CRAMER'`

## 📊 Output

The output table `goinfo.korelacija_rezultat` contains the correlation matrix, with each variable as both a row and column, and the corresponding correlation coefficient as the cell value.

## ❗ Error Handling

If an invalid method is specified, the procedure raises:
```
Neveljavna metoda. Uporabite PEARSON, SPEARMAN ali CRAMER.
```
("Invalid method. Use PEARSON, SPEARMAN, or CRAMER.")

## 🗂️ File Location

- [`proc_korelacija.sql`](proc_korelacija.sql): Main procedure implementation

## 📅 Version History

- **2025-10-02**: Procedure created
- **2025-10-06**: Spearman method implemented
- **2025-10-08**: Mathematical fix for Spearman, added Cramér's V

---

**For further details, see the full implementation in [`proc_korelacija.sql`](proc_korelacija.sql).**
