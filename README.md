# CSI25-Week7SQL

## SCD Type 0 – Fixed / Do Nothing
**Functionality:**
- Inserts new records but **ignores changes** to existing data.

**Current Table & Procedure:**
- **Table:** `Customer`
- **Procedure:** `insert_customer_if_new`

---

## SCD Type 1 – Overwrite
**Functionality:**
- **Overwrites old values** with the new values (no history is kept).

**Current Table & Procedure:**
- **Table:** `Customer`
- **Procedure:** `update_customer_overwrite`

---

## SCD Type 2 – Add New Row
**Functionality:**
- **Keeps historical data** by expiring old records and inserting new rows with `StartDate`, `EndDate`, and `IsCurrent` flags.

**Current Table & Procedure:**
- **Table:** `CustomerSCD2`
- **Procedure:** `manage_customer_history`

---

## SCD Type 3 – Add New Column
**Functionality:**
- Maintains **limited history** by storing the previous value in a separate column (e.g., `PreviousCity`).

**Current Table & Procedure:**
- **Table:** `CustomerSCD3`
- **Procedure:** `update_customer_city_history`

---

## SCD Type 4 – History Table
**Functionality:**
- **Separates current data and historical data** into two tables (Current & History).

**Current Tables & Procedure:**
- **Tables:** `CustomerSCD4Current`, `CustomerSCD4History`
- **Procedure:** `update_customer_with_history` 

---

## SCD Type 6 – Hybrid (1 + 2 + 3)
**Functionality:**
- **Combines SCD1, SCD2, and SCD3** by overwriting certain attributes, adding new rows for historical changes, and tracking previous values.

**Current Table & Procedure:**
- **Table:** `CustomerSCD6`
- **Procedure:** `manage_customer_scd6`
