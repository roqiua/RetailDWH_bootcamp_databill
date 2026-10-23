USE RetailDWH;


GO
-- Create the staging schema if it does not exist.
IF SCHEMA_ID('stg') IS NULL
    EXECUTE ('CREATE SCHEMA stg');


GO
/*
===============================================================================
1. CUSTOMERS
===============================================================================
Stores raw customer data extracted from the source system.
*/
DROP TABLE IF EXISTS stg.Customers;


GO
CREATE TABLE stg.Customers
(
    StagingRowID INT IDENTITY (1, 1),
    CustomerID INT PRIMARY KEY,
    CustomerName NVARCHAR (100),
    City NVARCHAR (50),
    Region NVARCHAR (50),
    Email NVARCHAR (120),
    LastModifiedAt DATETIME2 (3)
);


GO
/*
===============================================================================
2. STORES
===============================================================================
Stores raw store and location data.
*/
DROP TABLE IF EXISTS stg.Stores;


GO
CREATE TABLE stg.Stores
(
    StagingRowID INT IDENTITY (1, 1),
    StoreID INT PRIMARY KEY,
    StoreName NVARCHAR (100),
    City NVARCHAR (50),
    Region NVARCHAR (50),
    LastModifiedAt DATETIME2 (3)
);


GO
/*
===============================================================================
3. ORDERS
===============================================================================
Stores raw order header data.
*/
DROP TABLE IF EXISTS stg.Orders;


GO
CREATE TABLE stg.Orders
(
    StagingRowID INT IDENTITY (1, 1),
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    StoreID INT,
    OrderDate DATETIME2 (0),
    OrderStatus VARCHAR (20),
    LastModifiedAt DATETIME2 (3)
);


GO
/*
===============================================================================
4. ORDER LINES
===============================================================================
Stores raw order line details, including quantity, price, and discount.
*/
DROP TABLE IF EXISTS stg.OrderLines;


GO
CREATE TABLE stg.OrderLines
(
    StagingRowID INT IDENTITY (1, 1),
    OrderLineID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL (12, 2),
    DiscountAmount DECIMAL (12, 2),
    LastModifiedAt DATETIME2 (3)
);


GO
/*
===============================================================================
5. PRODUCT CATALOG
===============================================================================
Stores raw product details, cost, status, and modification timestamp.
*/
DROP TABLE IF EXISTS stg.ProductCatalog;


GO
CREATE TABLE stg.ProductCatalog
(
    StagingRowID INT IDENTITY (1, 1),
    ProductID INT PRIMARY KEY,
    SKU NVARCHAR (30),
    ProductName NVARCHAR (100),
    Category NVARCHAR (60),
    Brand NVARCHAR (60),
    UnitCost DECIMAL (12, 2),
    IsActive CHAR (1),
    LastModifiedAt DATETIME2 (3)
);


GO