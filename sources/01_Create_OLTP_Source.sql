/* STEP 1A | SQL SERVER SOURCE SCHEMA - RUN FIRST | RESETS ONLY RetailOLTP */
USE master;
GO
IF DB_ID(N'RetailOLTP') IS NULL CREATE DATABASE RetailOLTP;
GO
USE RetailOLTP;
GO
DROP TABLE IF EXISTS dbo.OrderLines;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.Stores;
GO
CREATE TABLE dbo.Customers (
 CustomerID INT NOT NULL PRIMARY KEY, CustomerName NVARCHAR(100) NOT NULL,
 City NVARCHAR(50) NOT NULL, Region NVARCHAR(50) NOT NULL,
 Email NVARCHAR(120) NULL, LastModifiedAt DATETIME2(3) NOT NULL
);
CREATE TABLE dbo.Stores (
 StoreID INT NOT NULL PRIMARY KEY, StoreName NVARCHAR(100) NOT NULL,
 City NVARCHAR(50) NOT NULL, Region NVARCHAR(50) NOT NULL,
 LastModifiedAt DATETIME2(3) NOT NULL
);
CREATE TABLE dbo.Orders (
 OrderID INT NOT NULL PRIMARY KEY, CustomerID INT NOT NULL,
 StoreID INT NOT NULL, OrderDate DATETIME2(0) NOT NULL,
 OrderStatus VARCHAR(20) NOT NULL,
 LastModifiedAt DATETIME2(3) NOT NULL,
 CONSTRAINT FK_Orders_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID),
 CONSTRAINT FK_Orders_Store FOREIGN KEY (StoreID) REFERENCES dbo.Stores(StoreID),
 CONSTRAINT CK_Orders_Status CHECK (OrderStatus IN ('Completed','Cancelled','Pending'))
);
CREATE TABLE dbo.OrderLines (
 OrderLineID INT NOT NULL PRIMARY KEY, OrderID INT NOT NULL,
 ProductID INT NOT NULL, Quantity INT NOT NULL,
 UnitPrice DECIMAL(12,2) NOT NULL, DiscountAmount DECIMAL(12,2) NOT NULL,
 LastModifiedAt DATETIME2(3) NOT NULL,
 CONSTRAINT FK_OrderLines_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),
 CONSTRAINT CK_OrderLines_Qty CHECK (Quantity > 0)
);
-- Product details are deliberately NOT in this database: they come from the Excel catalog.
GO
