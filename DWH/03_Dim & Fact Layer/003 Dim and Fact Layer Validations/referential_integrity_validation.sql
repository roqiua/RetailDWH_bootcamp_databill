USE [RetailDWH];


GO
/*
===============================================================================
REFERENTIAL INTEGRITY VALIDATION
===============================================================================
Purpose:
    Validate that all foreign keys in FactSales exist in their
    corresponding dimension tables before loading the fact table.

When to run:
    After loading dimensions and before loading FactSales.
===============================================================================
*/
-- 1. Validate Customer references
SELECT 'Customer' AS DimensionName,
       COUNT(*) AS InvalidRows
FROM   stg.OrderLines AS ol
       INNER JOIN
       stg.Orders AS o
       ON o.OrderID = ol.OrderID
       LEFT OUTER JOIN
       dim.DimCustomer AS c
       ON c.CustomerID = o.CustomerID
WHERE  c.CustomerKey IS NULL;

-- 2. Validate Store references
SELECT 'Store' AS DimensionName,
       COUNT(*) AS InvalidRows
FROM   stg.Orders AS o
       LEFT OUTER JOIN
       dim.DimStore AS s
       ON s.StoreID = o.StoreID
WHERE  s.StoreKey IS NULL;

-- 3. Validate Product references
SELECT 'Product' AS DimensionName,
       COUNT(*) AS InvalidRows
FROM   stg.OrderLines AS ol
       LEFT OUTER JOIN
       dim.DimProduct AS p
       ON p.ProductID = ol.ProductID
WHERE  p.ProductKey IS NULL;

-- 4. Validate Date references
SELECT 'Date' AS DimensionName,
       COUNT(*) AS InvalidRows
FROM   stg.Orders AS o
       LEFT OUTER JOIN
       dim.DimDate AS d
       ON d.FullDate = CAST (o.OrderDate AS DATE)
WHERE  d.DateKey IS NULL;