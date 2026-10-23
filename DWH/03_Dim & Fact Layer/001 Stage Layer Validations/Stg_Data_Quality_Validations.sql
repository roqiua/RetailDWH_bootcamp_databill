USE [RetailDWH];


GO
/*
===============================================================================
RETAIL DWH - DATA QUALITY VALIDATIONS
===============================================================================

WHEN TO RUN:
1. Run staging validations AFTER loading data into the staging layer.
2. Run them BEFORE transforming data into the Silver layer or loading dimensions.
3. Run referential integrity checks BEFORE loading the Fact table.
4. Run product-version checks AFTER updating DimProduct and BEFORE loading FactSales.
5. For incremental loads, validate against the complete staging dataset or the
   appropriate master/dimension tables, not only the current incremental batch.

IMPORTANT:
- Review returned rows; these queries identify potential issues and do not
  automatically correct the data.
- Some checks identify records for review rather than confirmed errors.
- NOT EXISTS is used instead of NOT IN to avoid NULL-related filtering issues.
- DimProduct uses SCD Type 2, so ProductID can appear in multiple versions.
- Product validity is checked using StartDate <= OrderDate < EndDate.
- EndDate IS NULL indicates the current product version.
- DiscountAmount is treated as a monetary amount, not a discount percentage.
===============================================================================
*/
/* ============================================================================
   1. CUSTOMERS VALIDATIONS
   Run AFTER loading stg.Customers and BEFORE loading DimCustomer.
   ============================================================================ */
-- 1.1 Check for duplicate CustomerID values.
-- Duplicate business keys can cause dimension-loading issues.
SELECT   CustomerID,
         COUNT(*) AS DuplicateCount
FROM     stg.Customers
GROUP BY CustomerID
HAVING   COUNT(*) > 1;

-- 1.2 Check for leading or trailing spaces in customer attributes.
-- DATALENGTH detects length differences after trimming, including trailing spaces.
-- NULL values are checked separately in section 1.3.
SELECT CustomerID,
       CustomerName,
       City,
       Region,
       Email
FROM   stg.Customers
WHERE  (CustomerName IS NOT NULL
        AND DATALENGTH(CustomerName) <> DATALENGTH
                                        (
                                            TRIM
                                            (CustomerName)
                                        ))
       OR (City IS NOT NULL
           AND DATALENGTH(City) <> DATALENGTH
                                   (
                                       TRIM
                                       (City)
                                   ))
       OR (Region IS NOT NULL
           AND DATALENGTH(Region) <> DATALENGTH
                                     (
                                         TRIM
                                         (Region)
                                     ))
       OR (Email IS NOT NULL
           AND DATALENGTH(Email) <> DATALENGTH
                                    (
                                        TRIM
                                        (Email)
                                    ));

-- 1.3 Check for NULL or empty values in required customer attributes.
-- Confirm that these fields are mandatory according to the business rules.
SELECT CustomerID,
       CustomerName,
       City,
       Region,
       Email
FROM   stg.Customers
WHERE  NULLIF (TRIM(CustomerName), N'') IS NULL
       OR NULLIF (TRIM(City), N'') IS NULL
       OR NULLIF (TRIM(Region), N'') IS NULL
       OR NULLIF (TRIM(Email), N'') IS NULL;

-- 1.4 Review distinct city values for inconsistent naming.
-- Examples: Mansoura, mansoura, and Mansoura with extra spaces.
SELECT   DISTINCT City
FROM     stg.Customers
ORDER BY City;

-- 1.5 Review distinct region values for inconsistent naming.
SELECT   DISTINCT Region
FROM     stg.Customers
ORDER BY Region;

-- 1.6 Check for duplicate non-empty Email values.
-- These may be valid if multiple customers can share an email address.
-- Review the results before enforcing an email uniqueness rule.
SELECT   TRIM(Email) AS NormalizedEmail,
         COUNT(*) AS DuplicateCount
FROM     stg.Customers
WHERE    NULLIF (TRIM(Email), N'') IS NOT NULL
GROUP BY TRIM(Email)
HAVING   COUNT(*) > 1;

/* ============================================================================
   2. STORES VALIDATIONS
   Run AFTER loading stg.Stores and BEFORE loading DimStore.
   ============================================================================ */
-- 2.1 Check for duplicate StoreID values.
SELECT   StoreID,
         COUNT(*) AS DuplicateCount
FROM     stg.Stores
GROUP BY StoreID
HAVING   COUNT(*) > 1;

-- 2.2 Check for leading or trailing spaces in store attributes.
SELECT StoreID,
       StoreName,
       City,
       Region
FROM   stg.Stores
WHERE  (StoreName IS NOT NULL
        AND DATALENGTH(StoreName) <> DATALENGTH
                                     (
                                         TRIM
                                         (StoreName)
                                     ))
       OR (City IS NOT NULL
           AND DATALENGTH(City) <> DATALENGTH
                                   (
                                       TRIM
                                       (City)
                                   ))
       OR (Region IS NOT NULL
           AND DATALENGTH(Region) <> DATALENGTH
                                     (
                                         TRIM
                                         (Region)
                                     ));

-- 2.3 Check for NULL or empty values in required store attributes.
SELECT StoreID,
       StoreName,
       City,
       Region
FROM   stg.Stores
WHERE  NULLIF (TRIM(StoreName), N'') IS NULL
       OR NULLIF (TRIM(City), N'') IS NULL
       OR NULLIF (TRIM(Region), N'') IS NULL;

/* ============================================================================
   3. PRODUCT CATALOG VALIDATIONS
   Run AFTER loading stg.ProductCatalog and BEFORE processing DimProduct SCD2.
   ============================================================================ */
-- 3.1 Check for NULL or empty values in required product attributes.
-- SKU is not included here because its mandatory status depends on business rules.
SELECT ProductID,
       ProductName,
       SKU,
       Category,
       Brand
FROM   stg.ProductCatalog
WHERE  NULLIF (TRIM(ProductName), N'') IS NULL
       OR NULLIF (TRIM(Category), N'') IS NULL
       OR NULLIF (TRIM(Brand), N'') IS NULL;

-- 3.2 Check for leading or trailing spaces in product attributes.
SELECT ProductID,
       ProductName,
       SKU,
       Category,
       Brand
FROM   stg.ProductCatalog
WHERE  (ProductName IS NOT NULL
        AND DATALENGTH(ProductName) <> DATALENGTH
                                       (
                                           TRIM
                                           (ProductName)
                                       ))
       OR (SKU IS NOT NULL
           AND DATALENGTH(SKU) <> DATALENGTH
                                  (
                                      TRIM
                                      (SKU)
                                  ))
       OR (Category IS NOT NULL
           AND DATALENGTH(Category) <> DATALENGTH
                                       (
                                           TRIM
                                           (Category)
                                       ))
       OR (Brand IS NOT NULL
           AND DATALENGTH(Brand) <> DATALENGTH
                                    (
                                        TRIM
                                        (Brand)
                                    ));

-- 3.3 Check for NULL, zero, or negative product costs.
-- A NULL cost prevents reliable profit calculation.
-- A zero or negative cost may be valid in special cases; review before rejecting.
SELECT ProductID,
       ProductName,
       UnitCost
FROM   stg.ProductCatalog
WHERE  UnitCost IS NULL
       OR UnitCost <= 0;

-- 3.4 Review distinct IsActive values.
-- Expected values are usually 0 and 1; NULL should be reviewed if permitted.
SELECT   DISTINCT IsActive
FROM     stg.ProductCatalog
ORDER BY IsActive;

/* ============================================================================
   4. ORDERS VALIDATIONS
   Run AFTER loading stg.Orders and BEFORE loading the Fact table.
   ============================================================================ */
-- 4.1 Check for duplicate OrderID values.
SELECT   OrderID,
         COUNT(*) AS DuplicateCount
FROM     stg.Orders
GROUP BY OrderID
HAVING   COUNT(*) > 1;

-- 4.2 Check for NULL or out-of-range OrderDate values.
-- Accepted date range: 1900-01-01 through 2050-01-01, inclusive.
-- The upper boundary excludes dates from 2050-01-02 onward.
SELECT *
FROM   stg.Orders
WHERE  OrderDate IS NULL
       OR OrderDate < CAST ('19000101' AS DATETIME)
       OR OrderDate >= CAST ('20500102' AS DATETIME);

-- 4.3 Check for missing required OrderID, CustomerID, or StoreID values.
SELECT *
FROM   stg.Orders
WHERE  OrderID IS NULL
       OR CustomerID IS NULL
       OR StoreID IS NULL;

-- 4.4 Find orders whose CustomerID does not exist in stg.Customers.
-- Use this check when stg.Customers contains the complete customer dataset.
-- If staging contains only an incremental batch, validate against DimCustomer
-- or another complete customer master instead.
SELECT o.*
FROM   stg.Orders AS o
WHERE  o.CustomerID IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM   stg.Customers AS c
                       WHERE  c.CustomerID = o.CustomerID);

-- 4.5 Find orders whose StoreID does not exist in stg.Stores.
-- Use this check when stg.Stores contains the complete store dataset.
-- For incremental staging, validate against DimStore or a complete store master.
SELECT o.*
FROM   stg.Orders AS o
WHERE  o.StoreID IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM   stg.Stores AS s
                       WHERE  s.StoreID = o.StoreID);

-- 4.6 Review distinct OrderStatus values.
-- Compare these values with the statuses allowed by the source system.
SELECT   DISTINCT OrderStatus
FROM     stg.Orders
ORDER BY OrderStatus;

/* ============================================================================
   5. ORDER LINES VALIDATIONS
   Run AFTER loading stg.OrderLines and BEFORE loading the Fact table.
   ============================================================================ */
-- 5.1 Check for duplicate OrderLineID values.
SELECT   OrderLineID,
         COUNT(*) AS DuplicateCount
FROM     stg.OrderLines
GROUP BY OrderLineID
HAVING   COUNT(*) > 1;

-- 5.2 Find order lines whose ProductID does not exist in any DimProduct version.
-- DimProduct uses SCD Type 2, so ProductID can repeat across historical versions.
-- These records may require an inferred member or the Unknown member.
-- Run AFTER DimProduct has been loaded or updated.
SELECT ol.*
FROM   stg.OrderLines AS ol
WHERE  ol.ProductID IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM   dim.DimProduct AS p
                       WHERE  p.ProductID = ol.ProductID);

-- 5.3 Find order lines whose ProductID has no valid dimension version
-- for the corresponding OrderDate.
-- Expected validity: StartDate <= OrderDate < EndDate.
-- EndDate IS NULL indicates the current version.
-- A result may indicate missing product history or incorrect validity dates.
SELECT ol.*,
       o.OrderDate
FROM   stg.OrderLines AS ol
       INNER JOIN
       stg.Orders AS o
       ON o.OrderID = ol.OrderID
WHERE  ol.ProductID IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM   dim.DimProduct AS p
                       WHERE  p.ProductID = ol.ProductID
                              AND p.StartDate IS NOT NULL
                              AND o.OrderDate >= p.StartDate
                              AND (o.OrderDate < p.EndDate
                                   OR p.EndDate IS NULL));

-- 5.4 Check for NULL or invalid OrderID values in order lines.
SELECT *
FROM   stg.OrderLines
WHERE  OrderID IS NULL
       OR OrderID = 0;

-- 5.5 Find order lines referencing an OrderID that does not exist in stg.Orders.
-- Use a complete orders dataset, or compare against the appropriate master
-- when staging contains only an incremental batch.
SELECT ol.*
FROM   stg.OrderLines AS ol
WHERE  ol.OrderID IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM   stg.Orders AS o
                       WHERE  o.OrderID = ol.OrderID);

-- 5.6 Check for NULL, zero, or negative Quantity and UnitPrice values.
-- Confirm whether negative quantities or prices represent valid returns.
-- Zero values may also be valid for promotional or no-charge transactions.
SELECT *
FROM   stg.OrderLines
WHERE  Quantity IS NULL
       OR Quantity <= 0
       OR UnitPrice IS NULL
       OR UnitPrice <= 0;

-- 5.7 Check for missing DiscountAmount values.
-- Decide whether NULL means unknown or should be replaced with zero.
SELECT *
FROM   stg.OrderLines
WHERE  DiscountAmount IS NULL;

-- 5.8 Check for negative discount amounts.
-- Negative values may be invalid unless the source uses them for adjustments.
SELECT *
FROM   stg.OrderLines
WHERE  DiscountAmount < 0;

-- 5.9 Identify discounts greater than the gross line sales amount.
-- These rows may indicate invalid discounts or special business adjustments.
-- Review them before deciding whether to reject the records.
SELECT OrderLineID,
       OrderID,
       ProductID,
       Quantity,
       UnitPrice,
       DiscountAmount,
       Quantity * UnitPrice AS GrossSales
FROM   stg.OrderLines
WHERE  Quantity IS NOT NULL
       AND UnitPrice IS NOT NULL
       AND DiscountAmount IS NOT NULL
       AND DiscountAmount > Quantity * UnitPrice;

-- 5.10 Check for NULL ProductID values separately.
-- These records cannot be matched to a specific product business key.
-- Decide whether to use the Unknown member or an inferred member.
SELECT *
FROM   stg.OrderLines
WHERE  ProductID IS NULL;

/* ============================================================================
   6. SALES AND PROFIT REVIEW
   Run AFTER DimProduct has been loaded or updated.
   Purpose:
       Review order lines with negative calculated profit.
   ============================================================================ */
-- Calculate sales and profit using the product version valid on OrderDate.
-- DiscountAmount is treated as a monetary amount.
-- GrossSales = Quantity * UnitPrice.
-- NetSales   = GrossSales - DiscountAmount.
-- Profit     = NetSales - (Quantity * UnitCost).
--
-- This query returns only negative-profit lines.
-- Negative profit is a review condition, not necessarily a data quality error.
-- Lines without a matching product version are excluded and should be reviewed
-- using validation 5.3 above.
SELECT ol.OrderLineID,
       ol.OrderID,
       ol.ProductID,
       o.OrderDate,
       ol.Quantity,
       ol.UnitPrice,
       ol.DiscountAmount,
       p.ProductKey,
       p.UnitCost,
       ol.Quantity * ol.UnitPrice AS GrossSales,
       (ol.Quantity * ol.UnitPrice) - ISNULL(ol.DiscountAmount, 0) AS NetSales,
       ((ol.Quantity * ol.UnitPrice) - ISNULL(ol.DiscountAmount, 0)) - (ol.Quantity * p.UnitCost) AS Profit
FROM   stg.OrderLines AS ol
       INNER JOIN
       stg.Orders AS o
       ON o.OrderID = ol.OrderID
       INNER JOIN
       dim.DimProduct AS p
       ON p.ProductID = ol.ProductID
          AND p.StartDate IS NOT NULL
          AND o.OrderDate >= p.StartDate
          AND (o.OrderDate < p.EndDate
               OR p.EndDate IS NULL)
WHERE  ol.Quantity IS NOT NULL
       AND ol.UnitPrice IS NOT NULL
       AND p.UnitCost IS NOT NULL
       AND ((ol.Quantity * ol.UnitPrice) - ISNULL(ol.DiscountAmount, 0) - (ol.Quantity * p.UnitCost)) < 0;


/* ============================================================================
   END OF DATA QUALITY VALIDATIONS
===============================================================================
*/
