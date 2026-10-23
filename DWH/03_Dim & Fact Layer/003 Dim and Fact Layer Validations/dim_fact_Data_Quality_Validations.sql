/*
===============================================================================
RETAIL DWH - DIMENSION & FACT DATA QUALITY VALIDATIONS
===============================================================================

Purpose:
    Validate data quality in dimension and fact tables.

Execution:
    1. Run after loading dimensions.
    2. Run before and after loading the fact table as appropriate.
    3. Review all returned rows before accepting the load.

===============================================================================
*/
/*=============================================================================
1. DIM CUSTOMER VALIDATIONS
=============================================================================*/
-- Check duplicate business keys
SELECT   CustomerID,
         COUNT(*) AS DuplicateCount
FROM     dim.DimCustomer
GROUP BY CustomerID
HAVING   COUNT(*) > 1;

-- Check missing mandatory attributes
SELECT *
FROM   dim.DimCustomer
WHERE  CustomerID IS NULL;

/*=============================================================================
2. DIM STORE VALIDATIONS
=============================================================================*/
-- Check duplicate business keys
SELECT   StoreID,
         COUNT(*) AS DuplicateCount
FROM     dim.DimStore
GROUP BY StoreID
HAVING   COUNT(*) > 1;

-- Check missing mandatory attributes
SELECT *
FROM   dim.DimStore
WHERE  StoreID IS NULL;

/*=============================================================================
3. DIM PRODUCT - SCD TYPE 2 VALIDATIONS
=============================================================================*/
-- Check missing mandatory attributes
SELECT *
FROM   dim.DimProduct
WHERE  ProductID != 0
       AND (ProductID IS NULL
            OR StartDate IS NULL
            OR EndDate IS NULL);

-- Check invalid date ranges
SELECT *
FROM   dim.DimProduct
WHERE  EndDate < StartDate;

-- Check overlapping product versions
SELECT p1.ProductID,
       p1.ProductKey AS ProductKey1,
       p2.ProductKey AS ProductKey2,
       p1.StartDate AS StartDate1,
       p1.EndDate AS EndDate1,
       p2.StartDate AS StartDate2,
       p2.EndDate AS EndDate2
FROM   dim.DimProduct AS p1
       INNER JOIN
       dim.DimProduct AS p2
       ON p1.ProductID = p2.ProductID
          AND p1.ProductKey < p2.ProductKey
          AND p1.StartDate < p2.EndDate
          AND p2.StartDate < p1.EndDate;

-- Check duplicate current versions
SELECT   ProductID,
         COUNT(*) AS CurrentVersions
FROM     dim.DimProduct
WHERE    EndDate = NULL
GROUP BY ProductID
HAVING   COUNT(*) > 1;

/*=============================================================================
4. DIM DATE VALIDATIONS
=============================================================================*/
-- Check duplicate dates
SELECT   FullDate,
         COUNT(*) AS DuplicateCount
FROM     dim.DimDate
GROUP BY FullDate
HAVING   COUNT(*) > 1;

-- Check missing mandatory date attributes
SELECT *
FROM   dim.DimDate
WHERE  FullDate IS NULL
       OR DateKey IS NULL;

/*=============================================================================
5. FACT SALES VALIDATIONS
=============================================================================*/
-- Check missing dimension keys
SELECT *
FROM   fact.FactSales
WHERE  CustomerKey IS NULL
       OR StoreKey IS NULL
       OR ProductKey IS NULL
       OR DateKey IS NULL;

-- Check invalid numeric measures
SELECT *
FROM   fact.FactSales
WHERE  Quantity <= 0
       OR GrossSales < 0
       OR DiscountAmount < 0
       OR Profit < 0;

-- Check profit calculation
-- Expected formula:
-- Profit = GrossSales - DiscountAmount - (Quantity * UnitCost)
SELECT *
FROM   fact.FactSales
WHERE  ABS(Profit - (GrossSales - DiscountAmount - (Quantity * UnitPrice))) > 0.01;

/*=============================================================================
6. Validation and Analytical Questions 
=============================================================================*/
--1. How many source orders have a Completed status? 
SELECT COUNT(DISTINCT OrderID) fact_orders_count
FROM   [fact].[FactSales];

SELECT COUNT(DISTINCT [OrderLines].[OrderID]) stg_order_count
FROM   [stg].[Orders]
       INNER JOIN
       [stg].[OrderLines]
       ON [Orders].[OrderID] = [OrderLines].[OrderID]
WHERE  OrderStatus = N'Completed'
       AND EXISTS (SELECT *
                   FROM   [stg].[ProductCatalog]
                   WHERE  [OrderLines].[ProductID] = [ProductCatalog].[ProductID]);

--2. How many valid order lines remain after the product lookup?
SELECT COUNT(*) AS fact_OrderLines
FROM   fact.FactSales;

SELECT COUNT(*) AS stg_valid_OrderLines
FROM   stg.Orders AS o
       INNER JOIN
       stg.OrderLines AS ol
       ON o.OrderID = ol.OrderID
WHERE  o.OrderStatus = N'Completed'
       AND EXISTS (SELECT 1
                   FROM   stg.ProductCatalog AS p
                   WHERE  p.ProductID = ol.ProductID);

--3. Does COUNT(DISTINCT SourceOrderLineID) equal the total row count in FactSales?
SELECT COUNT(DISTINCT SourceOrderLineID) AS DistinctSourceOrderLines,
       COUNT(*) AS TotalFactRows,
       CASE WHEN COUNT(DISTINCT SourceOrderLineID) = COUNT(*) THEN 'Yes' ELSE 'No' END AS CountsMatch
FROM   fact.FactSales;

--4. What is the monthly revenue by brand and store?
SELECT   MonthName,
         MonthNumber,
         Brand,
         StoreName,
         SUM(NetSales) AS monthly_revenue
FROM     fact.FactSales
         INNER JOIN
         dim.DimDate
         ON FactSales.DateKey = DimDate.DateKey
         INNER JOIN
         dim.DimProduct
         ON FactSales.ProductKey = DimProduct.ProductKey
         INNER JOIN
         dim.DimStore
         ON FactSales.StoreKey = DimStore.StoreKey
GROUP BY MonthName,
         MonthNumber,
         Brand,
         StoreName
ORDER BY MonthNumber,
         Brand,
         StoreName;