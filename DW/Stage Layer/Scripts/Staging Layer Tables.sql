
USE RetailDWH;


GO
-- Create Staging Schema if it does not exist.
IF SCHEMA_ID('stg') IS NULL
    EXECUTE ('CREATE SCHEMA stg');


GO
-- Customers
DROP TABLE IF EXISTS stg.Customers;

CREATE TABLE stg.Customers
(
    StagingRowID INT IDENTITY (1, 1),
    CustomerID INT,
    CustomerName NVARCHAR (100),
    City NVARCHAR (50),
    Region NVARCHAR (50),
    Email NVARCHAR (120),
    LastModifiedAt DATETIME2 (3)
);


GO
-- Stores
DROP TABLE IF EXISTS stg.Stores;

CREATE TABLE stg.Stores
(
    StagingRowID INT IDENTITY (1, 1),
    StoreID INT,
    StoreName NVARCHAR (100),
    City NVARCHAR (50),
    Region NVARCHAR (50),
    LastModifiedAt DATETIME2 (3)
);


GO
-- Orders
DROP TABLE IF EXISTS stg.Orders;

CREATE TABLE stg.Orders
(
    StagingRowID INT IDENTITY (1, 1),
    OrderID INT,
    CustomerID INT,
    StoreID INT,
    OrderDate DATETIME2 (0),
    OrderStatus VARCHAR (20),
    LastModifiedAt DATETIME2 (3)
);


GO
-- OrderLines
DROP TABLE IF EXISTS stg.OrderLines;

CREATE TABLE stg.OrderLines
(
    StagingRowID INT IDENTITY (1, 1),
    OrderLineID INT,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL (12, 2),
    DiscountAmount DECIMAL (12, 2),
    LastModifiedAt DATETIME2 (3)
);


GO
-- ProductCatalog
DROP TABLE IF EXISTS stg.ProductCatalog;

CREATE TABLE stg.ProductCatalog
(
    StagingRowID INT IDENTITY (1, 1),
    ProductID INT,
    SKU NVARCHAR (30),
    ProductName NVARCHAR (100),
    Category NVARCHAR (60),
    Brand NVARCHAR (60),
    UnitCost DECIMAL (12, 2),
    IsActive CHAR (1),
    LastModifiedAt DATETIME2 (3)
);


GO
