USE [RetailDWH];


GO
/*
===============================================================================
RETAILDWH - CREATE DIMENSION AND FACT TABLES
===============================================================================

PURPOSE:
    Create and populate the dimension and fact tables for the RetailDWH
    data warehouse.

TABLES:
    Dimensions:
        dim.DimDate
        dim.DimCustomer
        dim.DimStore
        dim.DimProduct

    Fact:
        fact.FactSales

===============================================================================
WARNING - DATA LOSS
===============================================================================

THIS SCRIPT DROPS AND RECREATES EXISTING TABLES.

Running this script will:
    1. Drop fact.FactSales and permanently delete all its existing data.
    2. Drop dimension tables and permanently delete their existing data.
    3. Recreate all tables and their constraints.
    4. Repopulate DimDate for the configured date range.
    5. Reinsert Unknown members with surrogate key 0.

IMPORTANT:
    - Back up any important data before running this script.
    - Existing dimension and fact data will be lost.
    - IDENTITY values will be reset when their tables are recreated.
    - Dependent views, procedures, ETL packages, or reports may be affected.
    - Do not run this script as part of routine ETL execution.
    - This script is intended for initial setup or full recreation only.

===============================================================================
*/
-- Switch to the RetailDWH database.
USE RetailDWH;


GO
/*
===============================================================================
1. CREATE REQUIRED SCHEMAS
===============================================================================
Create the dimension and fact schemas if they do not already exist.
*/
IF SCHEMA_ID(N'dim') IS NULL
    EXECUTE (N'CREATE SCHEMA dim');


GO
IF SCHEMA_ID(N'fact') IS NULL
    EXECUTE (N'CREATE SCHEMA fact');


GO
/*
===============================================================================
2. DROP EXISTING TABLES
===============================================================================
WARNING:
    The following statements permanently delete existing table data.

Drop FactSales first because it references the dimension tables through
foreign key constraints.
*/
DROP TABLE IF EXISTS fact.FactSales;


GO
DROP TABLE IF EXISTS dim.DimProduct;


GO
DROP TABLE IF EXISTS dim.DimStore;


GO
DROP TABLE IF EXISTS dim.DimCustomer;


GO
DROP TABLE IF EXISTS dim.DimDate;


GO
/*
===============================================================================
3. DIMENSION: DATE
===============================================================================
Purpose:
    Stores calendar attributes used to analyze sales over time.

DateKey:
    Integer key in YYYYMMDD format (e.g., 20260115).

Date Range:
    2020-01-01 through 2030-12-31.
*/
CREATE TABLE dim.DimDate
(
    DateKey INT NOT NULL,
    FullDate DATE NOT NULL,
    DayNumber INT NOT NULL,
    MonthNumber INT NOT NULL,
    MonthName NVARCHAR (20) NOT NULL,
    QuarterNumber INT NOT NULL,
    YearNumber INT NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY (DateKey),
    CONSTRAINT UQ_DimDate_FullDate UNIQUE (FullDate)
);


GO
/*
===============================================================================
4. POPULATE DATE DIMENSION
===============================================================================
Generate one row for each calendar date in the configured date range.
*/
WITH DateCTE
AS   (-- Start with the first date in the required range.
      SELECT CAST ('20200101' AS DATE) AS FullDate
      UNION ALL
      -- Generate the next date until the end date is reached.
      SELECT DATEADD(DAY, 1, FullDate)
      FROM   DateCTE
      WHERE  FullDate < CAST ('20301231' AS DATE))
INSERT INTO dim.DimDate
(
    DateKey,
    FullDate,
    DayNumber,
    MonthNumber,
    MonthName,
    QuarterNumber,
    YearNumber
)
SELECT CONVERT (INT, CONVERT (CHAR (8), FullDate, 112)) AS DateKey,
       FullDate,
       DAY(FullDate) AS DayNumber,
       MONTH(FullDate) AS MonthNumber,
       DATENAME(MONTH, FullDate) AS MonthName,
       DATEPART(QUARTER, FullDate) AS QuarterNumber,
       YEAR(FullDate) AS YearNumber
FROM   DateCTE
OPTION
(
    MAXRECURSION 0
);


GO
/*
===============================================================================
5. DIMENSION: CUSTOMER
===============================================================================
CustomerKey:
    Warehouse-generated surrogate key.

CustomerID:
    Source-system business key. Unique because this dimension uses Type 1.

IsInferredMember:
    1 = Inferred placeholder member.
    0 = Regular or Unknown member.
*/
CREATE TABLE dim.DimCustomer
(
    CustomerKey INT IDENTITY (0, 1) NOT NULL,
    CustomerID INT NOT NULL,
    CustomerName NVARCHAR (100) NULL,
    City NVARCHAR (50) NULL,
    Region NVARCHAR (50) NULL,
    Email NVARCHAR (120) NULL,
    IsInferredMember BIT CONSTRAINT DF_DimCustomer_IsInferredMember DEFAULT (0) NOT NULL,
    CONSTRAINT PK_DimCustomer PRIMARY KEY (CustomerKey),
    CONSTRAINT UQ_DimCustomer_CustomerID UNIQUE (CustomerID)
);


GO
/*
===============================================================================
6. DIMENSION: STORE
===============================================================================
StoreKey:
    Warehouse-generated surrogate key.

StoreID:
    Source-system business key. Unique because this dimension uses Type 1.

IsInferredMember:
    Indicates whether the row is an inferred placeholder.
*/
CREATE TABLE dim.DimStore
(
    StoreKey INT IDENTITY (0, 1) NOT NULL,
    StoreID INT NOT NULL,
    StoreName NVARCHAR (100) NULL,
    City NVARCHAR (50) NULL,
    Region NVARCHAR (50) NULL,
    IsInferredMember BIT CONSTRAINT DF_DimStore_IsInferredMember DEFAULT (0) NOT NULL,
    CONSTRAINT PK_DimStore PRIMARY KEY (StoreKey),
    CONSTRAINT UQ_DimStore_StoreID UNIQUE (StoreID)
);


GO
/*
===============================================================================
7. DIMENSION: PRODUCT
===============================================================================
Purpose:
    Stores product attributes and historical versions using SCD Type 2.

ProductKey:
    Surrogate key identifying a specific product version.

ProductID:
    Source-system business key. Repeated values are allowed because a product
    can have multiple historical versions.

StartDate / EndDate:
    Define the validity period of each version.

    For a current version, EndDate is NULL.
    Match a sales event to a version using:
        StartDate <= event date
        AND (event date < EndDate OR EndDate IS NULL)

IsInferredMember:
    Indicates whether the row is an inferred placeholder.
*/
CREATE TABLE dim.DimProduct
(
    ProductKey INT IDENTITY (1, 1) NOT NULL,
    ProductID INT NOT NULL,
    SKU NVARCHAR (30) NULL,
    ProductName NVARCHAR (100) NULL,
    Category NVARCHAR (60) NULL,
    Brand NVARCHAR (60) NULL,
    UnitCost DECIMAL (12, 2) NULL,
    StartDate DATETIME NULL,
    EndDate DATETIME NULL,
    IsInferredMember BIT CONSTRAINT DF_DimProduct_IsInferredMember DEFAULT (0) NOT NULL,
    CONSTRAINT PK_DimProduct PRIMARY KEY (ProductKey),
    CONSTRAINT CK_DimProduct_DateRange CHECK (EndDate IS NULL
                                              OR (StartDate IS NOT NULL
                                                  AND EndDate >= StartDate))
);


GO
/*
===============================================================================
8. FACT TABLE: SALES
===============================================================================
Purpose:
    Stores sales transactions and references the appropriate dimension rows.

SalesKey:
    Warehouse-generated primary key.

SourceOrderLineID:
    Unique source order-line identifier used to prevent duplicate fact rows.

Measures:
    Quantity       = Number of units sold.
    UnitPrice      = Unit selling price.
    GrossSales     = Sales amount before discount.
    DiscountAmount = Discount amount.
    NetSales       = Sales amount after discount.
    Profit         = Net sales minus product cost.

LoadedAt:
    Timestamp when the fact row was loaded.
*/
CREATE TABLE fact.FactSales
(
    SalesKey BIGINT IDENTITY (1, 1) NOT NULL,
    SourceOrderLineID INT NOT NULL,
    OrderID INT NOT NULL,
    DateKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    StoreKey INT NOT NULL,
    ProductKey INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL (12, 2) NOT NULL,
    GrossSales DECIMAL (18, 2) NOT NULL,
    DiscountAmount DECIMAL (18, 2) NOT NULL,
    NetSales DECIMAL (18, 2) NOT NULL,
    Profit DECIMAL (18, 2) NOT NULL,
    LoadedAt DATETIME CONSTRAINT DF_FactSales_LoadedAt DEFAULT (SYSDATETIME()) NOT NULL,
    CONSTRAINT PK_FactSales PRIMARY KEY (SalesKey),
    CONSTRAINT UQ_FactSales_SourceOrderLineID UNIQUE (SourceOrderLineID),
    -- Link sales to the date dimension.
    CONSTRAINT FK_FactSales_DimDate FOREIGN KEY (DateKey) REFERENCES dim.DimDate (DateKey),
    -- Link sales to the customer dimension.
    CONSTRAINT FK_FactSales_DimCustomer FOREIGN KEY (CustomerKey) REFERENCES dim.DimCustomer (CustomerKey),
    -- Link sales to the store dimension.
    CONSTRAINT FK_FactSales_DimStore FOREIGN KEY (StoreKey) REFERENCES dim.DimStore (StoreKey),
    -- Link sales to the correct product version.
    CONSTRAINT FK_FactSales_DimProduct FOREIGN KEY (ProductKey) REFERENCES dim.DimProduct (ProductKey),
    -- Validate sales quantities and discounts.
    CONSTRAINT CK_FactSales_Quantity CHECK (Quantity >= 0),
    CONSTRAINT CK_FactSales_DiscountAmount CHECK (DiscountAmount >= 0)
);


GO
/*
===============================================================================
9. INSERT UNKNOWN MEMBER - CUSTOMER
===============================================================================
CustomerKey = 0 represents an unknown or unavailable customer.
*/
SET IDENTITY_INSERT dim.DimCustomer ON;

INSERT  INTO dim.DimCustomer
(
    CustomerKey,
    CustomerID,
    CustomerName,
    City,
    Region,
    Email,
    IsInferredMember
)
VALUES                      (0, 0, N'Unknown', N'Unknown', N'Unknown', N'Unknown', 0);

SET IDENTITY_INSERT dim.DimCustomer OFF;


GO
/*
===============================================================================
10. INSERT UNKNOWN MEMBER - STORE
===============================================================================
StoreKey = 0 represents an unknown or unavailable store.
*/
SET IDENTITY_INSERT dim.DimStore ON;

INSERT  INTO dim.DimStore
(
    StoreKey,
    StoreID,
    StoreName,
    City,
    Region,
    IsInferredMember
)
VALUES                   (0, 0, N'Unknown', N'Unknown', N'Unknown', 0);

SET IDENTITY_INSERT dim.DimStore OFF;


GO
/*
===============================================================================
11. INSERT UNKNOWN MEMBER - PRODUCT
===============================================================================
ProductKey = 0 represents an unknown or unavailable product.
*/
--SET IDENTITY_INSERT dim.DimProduct ON;
--INSERT  INTO dim.DimProduct
--(
--    ProductKey,
--    ProductID,
--    SKU,
--    ProductName,
--    Category,
--    Brand,
--    UnitCost,
--    StartDate,
--    EndDate,
--    IsInferredMember
--)
--VALUES                     (0, 0, N'Unknown', N'Unknown', N'Unknown', N'Unknown', NULL, NULL, NULL, 0);
--SET IDENTITY_INSERT dim.DimProduct OFF;
--GO
/*
===============================================================================
12. VALIDATE CREATED TABLES
===============================================================================
Check the number of date rows and verify the generated date range.
*/
SELECT COUNT(*) AS TotalDates,
       MIN(FullDate) AS FirstDate,
       MAX(FullDate) AS LastDate
FROM   dim.DimDate;


GO

/*
===============================================================================
END OF SCRIPT
===============================================================================
*/