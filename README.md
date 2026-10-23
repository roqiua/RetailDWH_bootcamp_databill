# Retail Data Warehouse \| SQL Server & SSIS

A retail analytics data warehouse built with **Microsoft SQL Server**
and **SQL Server Integration Services (SSIS)**. The project demonstrates
an end-to-end ETL workflow, from staging operational data to loading
dimensional models for sales analysis.

## Project Overview

**RetailDWH** organizes retail data into a dimensional model so business
questions can be answered consistently---for example, monthly revenue by
brand and store, sales trends, and product performance.

The solution separates raw staging from analytical transformations and
uses surrogate keys, data-quality checks, and ETL execution logging to
make the load process easier to monitor and troubleshoot.

## Architecture

``` mermaid
flowchart TD
    A[Operational SQL Server Data] --> B[SSIS Staging Load]
    C[Product Catalog File] --> B
    B --> D[stg Schema]
    D --> E[Data Quality Validation]
    E --> F[Dimension Loads]
    F --> G[FactSales Load]
    G --> H[RetailDWH Analytics]
    I[ETL Batch and Operation Logs] -. monitors .-> B
    I -. monitors .-> F
    I -. monitors .-> G
```

**High-level flow:** Sources → Staging → Validation and transformation →
Dimensions → Fact table → Reporting and analysis.

## Data Warehouse Model

The warehouse uses a dimensional model with four dimensions and one fact
table.

  -----------------------------------------------------------------------
  Object                  Purpose                 Load / history strategy
  ----------------------- ----------------------- -----------------------
  `stg.Customers`         Staging customer        Full overwrite or
                          records                 incremental staging
                                                  load

  `stg.Stores`            Staging store records   Full overwrite or
                                                  incremental staging
                                                  load

  `stg.Orders`            Staging order headers   Full overwrite or
                          and statuses            incremental staging
                                                  load

  `stg.OrderLines`        Staging order-line      Loaded from the
                          details                 operational source

  `stg.ProductCatalog`    Staging product catalog Loaded from the
                          data                    supplied product
                                                  catalog

  `dim.DimCustomer`       Customer dimension      SCD Type 1

  `dim.DimStore`          Store dimension         SCD Type 1

  `dim.DimProduct`        Product dimension       SCD Type 2

  `dim.DimDate`           Calendar dimension      Date-based dimension

  `fact.FactSales`        Sales at order-line     Incremental fact
                          grain                   loading
  -----------------------------------------------------------------------

> Update the table descriptions if your final package configuration
> differs from the implementation.

### Fact table grain

**One row per source order line** represented in `fact.FactSales`.
`SourceOrderLineID` is used to trace a fact row back to its source order
line.

Typical dimension keys include the customer, store, product, and order
date keys. `OrderID` can remain in the fact as a degenerate dimension
for order-level analysis.

## ETL Design

### Staging load strategies

The staging layer supports two loading patterns:

-   **Overwrite load:** Clear the target staging table and reload the
    source data.
-   **Incremental load:** Retrieve records modified after the last
    successful watermark, using `LastModifiedAt` where available.

The watermark should advance only after the corresponding load succeeds.
This prevents a failed run from skipping source changes on the next
attempt.

### Dimension loading

-   **Customer --- SCD Type 1:** Update existing customer attributes in
    place.
-   **Store --- SCD Type 1:** Update existing store attributes in place.
-   **Product --- SCD Type 2:** Preserve tracked product history by
    closing the previous version and inserting a new version when
    tracked attributes change.
-   **Date --- DimDate:** Provides year, month, quarter, and day
    attributes for time-based analysis.

For SCD Type 2 products, the order date should match the product version
whose effective period contains that date:

`StartDate <= OrderDate AND OrderDate < EndDate`

This lets the fact load resolve the product cost applicable to the order
date.

### Fact transformation

The fact load joins order headers to order lines and resolves dimension
keys. Revenue and profit measures are derived from order-line values and
the applicable product version.

Example measures:

-   **Gross Sales** = `Quantity × UnitPrice`
-   **Discount Amount** = `GrossSales × Discount`
-   **Net Sales** = `GrossSales − DiscountAmount`
-   **Profit** = `NetSales − (Quantity × UnitCost)`

The formulas assume `Discount` is stored as a rate (for example, `0.10`
for 10%). Adapt the expression if the source stores discounts
differently.

Only orders with `OrderStatus = 'Completed'` should contribute to
completed-sales reporting. Product lookup failures should be routed for
investigation rather than assigned an arbitrary product key.

## Data Quality and Referential Integrity

Validation checks can be used before loading dimensions and facts to
detect issues such as:

-   Missing or invalid business keys.
-   Duplicate source identifiers.
-   Null or malformed values.
-   Order lines whose product ID is not present in the product catalog.
-   Missing dimension-key matches before fact insertion.
-   Invalid or overlapping product effective-date ranges.

Unknown dimension members can support unresolved customer or store
references where configured. Product lookup failures are handled
separately so invalid product lines can be investigated.

## ETL Monitoring and Error Handling

The project includes a design for tracking ETL execution at both batch
and table-operation level.

-   **Batch log:** Records the overall execution start, end, and status.
-   **Operation log:** Records the table, operation type, load type, row
    count, success/failure, and message.
-   **Failure handling:** A failed required operation should be
    reflected in the batch result; a failed load must not be reported as
    successful.
-   **Master package orchestration:** A parent package can execute child
    packages and centralize monitoring.

Make sure the README matches the logging and package behavior that is
present in your final SSIS implementation.

## Example Business Query

**Monthly revenue by brand and store**

``` sql
SELECT
    d.YearNumber,
    d.MonthNumber,
    p.Brand,
    s.StoreName,
    SUM(f.NetSales) AS MonthlyRevenue
FROM fact.FactSales AS f
INNER JOIN dim.DimDate AS d
    ON f.DateKey = d.DateKey
INNER JOIN dim.DimProduct AS p
    ON f.ProductKey = p.ProductKey
INNER JOIN dim.DimStore AS s
    ON f.StoreKey = s.StoreKey
GROUP BY
    d.YearNumber,
    d.MonthNumber,
    p.Brand,
    s.StoreName
ORDER BY
    d.YearNumber,
    d.MonthNumber,
    p.Brand,
    s.StoreName;
```

This query assumes the store name column is `StoreName` and the revenue
measure is `NetSales`; adjust the names if your schema differs.

## Technology Stack

-   **Database:** Microsoft SQL Server, T-SQL
-   **ETL:** SQL Server Integration Services (SSIS)
-   **Development:** Visual Studio, SQL Server Management Studio (SSMS)
-   **Modeling and analysis:** Dimensional modeling, star-schema
    concepts, SCD Type 1 and Type 2
-   **Workflow concepts:** Incremental loading, watermarks, data
    validation, logging, and error handling

## Repository Contents

The repository can be organized around these project assets:

-   SQL scripts for staging, dimensions, facts, validation, and ETL
    logging.
-   SSIS project and packages for staging and warehouse loads.
-   Source data files or instructions for obtaining the input dataset.
-   Documentation and sample analytical queries.

Only include files that are actually present in this repository; do not
commit credentials or connection strings containing secrets.

## How to Run

1.  Install a compatible SQL Server instance and the SSIS development
    extension for Visual Studio.
2.  Create or configure the `RetailDWH` database and required schemas.
3.  Configure source and destination connection managers in the SSIS
    project.
4.  Place the supplied product catalog file in the configured location
    and update the Flat File Connection Manager if needed.
5.  Execute the staging load.
6.  Run data-quality and referential-integrity validations.
7.  Execute the dimension loads, followed by the fact load.
8.  Review ETL logs and run the analytical queries to validate the
    results.

Exact deployment steps depend on the connection managers, parameters,
and package configuration in the repository.

## Key Learning Outcomes

-   Designing a dimensional model for retail analytics.
-   Building reusable SSIS ETL workflows.
-   Implementing overwrite and watermark-based incremental loads.
-   Managing changing product attributes with SCD Type 2.
-   Resolving surrogate keys and validating referential integrity.
-   Calculating sales and profit measures using historical product
    costs.
-   Logging ETL execution and handling failed operations.
-   Writing SQL queries for business reporting.

## Author

**Roqia Mohammad**

-   GitHub: [github.com/roqiua](https://github.com/roqiua)
-   LinkedIn:
    [linkedin.com/in/roqiua-mohammad](https://www.linkedin.com/in/roqiua-mohammad)

------------------------------------------------------------------------

*Portfolio project for practicing SQL Server data warehousing and
SSIS-based ETL.*
