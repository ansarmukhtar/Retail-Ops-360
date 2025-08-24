USE RetailOps360;
SELECT COUNT(*) AS Products FROM stg.ProductsRaw;
SELECT COUNT(*) AS Stores   FROM stg.StoresRaw;
SELECT COUNT(*) AS Customers FROM stg.CustomersRaw;
SELECT TOP 5 * FROM stg.DatesRaw;
-- Product
IF OBJECT_ID('dw.DimProduct') IS NOT NULL DROP TABLE dw.DimProduct;
CREATE TABLE dw.DimProduct(
  SK_Product int IDENTITY(1,1) PRIMARY KEY,
  ProductKey int UNIQUE,
  Product nvarchar(200),
  Subcategory nvarchar(200),
  Category nvarchar(200)
);
EXEC sp_help 'stg.ProductsRaw';
-- or
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='stg' AND TABLE_NAME='ProductsRaw'
ORDER BY ORDINAL_POSITION;

IF OBJECT_ID('dw.DimProduct') IS NOT NULL DROP TABLE dw.DimProduct;
CREATE TABLE dw.DimProduct(
  SK_Product   int IDENTITY(1,1) PRIMARY KEY,
  ProductKey   int UNIQUE,             -- source/business key
  ProductName  nvarchar(200),
  Brand        nvarchar(200),
  Manufacturer nvarchar(200),
  Color        nvarchar(100),
  WeightUnit   nvarchar(100),
  Weight       decimal(18,10)
);

INSERT INTO dw.DimProduct(ProductKey, ProductName, Brand, Manufacturer, Color, WeightUnit, Weight)
SELECT DISTINCT
  [ProductKey],
  [ProductName],
  [Brand],
  [Manufacturer],
  [Color],
  [WeightUnit],
  [Weight]
FROM stg.ProductsRaw
WHERE [ProductKey] IS NOT NULL;

CREATE UNIQUE INDEX UX_DimProduct_ProductKey ON dw.DimProduct(ProductKey);

SELECT TOP 5 * FROM dw.DimProduct;
SELECT COUNT(*) FROM dw.DimProduct;

EXEC sp_help 'stg.storesRaw';
EXEC sp_help 'stg.CustomersRaw';
EXEC sp_help 'stg.datesRaw';

USE RetailOps360;

IF OBJECT_ID('dw.DimStore') IS NOT NULL DROP TABLE dw.DimStore;
CREATE TABLE dw.DimStore(
  SK_Store     int IDENTITY(1,1) PRIMARY KEY,
  StoreKey     int       UNIQUE,
  StoreCode    smallint  NULL,
  GeoAreaKey   smallint  NULL,
  StoreName    nvarchar(200) NULL,   -- from Description
  CountryCode  nvarchar(100) NULL,
  CountryName  nvarchar(100) NULL,
  [State]      nvarchar(100) NULL,
  OpenDate     date NULL,
  CloseDate    date NULL,
  SquareMeters smallint NULL,
  [Status]     nvarchar(100) NULL
);

INSERT INTO dw.DimStore
  (StoreKey, StoreCode, GeoAreaKey, StoreName, CountryCode, CountryName, [State],
   OpenDate, CloseDate, SquareMeters, [Status])
SELECT DISTINCT
  s.[StoreKey],
  s.[StoreCode],
  s.[GeoAreaKey],
  s.[Description]      AS StoreName,
  s.[CountryCode],
  s.[CountryName],
  s.[State],
  s.[OpenDate],
  s.[CloseDate],
  s.[SquareMeters],
  s.[Status]
FROM stg.storesRaw s
WHERE s.[StoreKey] IS NOT NULL;

CREATE UNIQUE INDEX UX_DimStore_StoreKey ON dw.DimStore(StoreKey);

SELECT TOP 5 * FROM dw.DimStore;
SELECT COUNT(*) FROM dw.DimStore;

EXEC sp_help 'stg.CustomersRaw';
EXEC sp_help 'stg.datesRaw';

USE RetailOps360;

IF OBJECT_ID('dw.DimCustomer') IS NOT NULL DROP TABLE dw.DimCustomer;
CREATE TABLE dw.DimCustomer(
  SK_Customer  int IDENTITY(1,1) PRIMARY KEY,
  CustomerKey  int UNIQUE,             -- business key from source
  FullName     nvarchar(300) NULL,     -- Title + Given + Surname
  Gender       nvarchar(100) NULL,
  City         nvarchar(200) NULL,
  [State]      nvarchar(100) NULL,
  Country      nvarchar(100) NULL,
  Birthday     date NULL,
  Age          int  NULL,
  AgeSegment   nvarchar(20) NULL,      -- derived bucket
  Occupation   nvarchar(200) NULL,
  Company      nvarchar(200) NULL
);

INSERT INTO dw.DimCustomer
  (CustomerKey, FullName, Gender, City, [State], Country, Birthday, Age, AgeSegment, Occupation, Company)
SELECT DISTINCT
  c.[CustomerKey],
  RTRIM(LTRIM(CONCAT(NULLIF(c.[Title],''),' ',
                     NULLIF(c.[GivenName],''),' ',
                     NULLIF(c.[Surname],''))))           AS FullName,
  c.[Gender],
  c.[City],
  c.[State],
  c.[Country],
  c.[Birthday],
  c.[Age],
  CASE 
    WHEN c.[Age] IS NULL THEN NULL
    WHEN c.[Age] < 25 THEN 'Under25'
    WHEN c.[Age] BETWEEN 25 AND 34 THEN '25-34'
    WHEN c.[Age] BETWEEN 35 AND 44 THEN '35-44'
    WHEN c.[Age] BETWEEN 45 AND 54 THEN '45-54'
    WHEN c.[Age] BETWEEN 55 AND 64 THEN '55-64'
    ELSE '65+'
  END AS AgeSegment,
  c.[Occupation],
  c.[Company]
FROM stg.CustomersRaw c
WHERE c.[CustomerKey] IS NOT NULL;

CREATE UNIQUE INDEX UX_DimCustomer_CustomerKey ON dw.DimCustomer(CustomerKey);

SELECT TOP 5 * FROM dw.DimCustomer;
SELECT COUNT(*) FROM dw.DimCustomer;

EXEC sp_help 'stg.datesRaw';
SELECT TOP 5 * FROM stg.datesRaw;

USE RetailOps360;

IF OBJECT_ID('dw.DimDate') IS NOT NULL DROP TABLE dw.DimDate;
CREATE TABLE dw.DimDate(
  DateKey     int        PRIMARY KEY,     -- e.g., 20240131
  [Date]      date       UNIQUE,
  [Year]      smallint   NOT NULL,
  [Quarter]   tinyint    NOT NULL,        -- 1..4
  MonthNo     tinyint    NOT NULL,        -- 1..12
  MonthName   nvarchar(20) NOT NULL,
  DayOfWeekNo tinyint    NULL,
  WorkingDay  bit        NULL
);

INSERT INTO dw.DimDate(DateKey, [Date], [Year], [Quarter], MonthNo, MonthName, DayOfWeekNo, WorkingDay)
SELECT DISTINCT
  CONVERT(int, FORMAT(d.[Date], 'yyyyMMdd'))                         AS DateKey,
  d.[Date],
  d.[Year],
  CAST(CEILING(CAST(d.[MonthNumber] AS float)/3.0) AS tinyint)       AS [Quarter],
  CAST(d.[MonthNumber] AS tinyint)                                   AS MonthNo,
  d.[Month]                                                          AS MonthName,
  CAST(d.[DayofWeekNumber] AS tinyint)                               AS DayOfWeekNo,
  d.[WorkingDay]                                                     AS WorkingDay
FROM stg.datesRaw d
WHERE d.[Date] IS NOT NULL;

CREATE UNIQUE INDEX UX_DimDate_Date ON dw.DimDate([Date]);

-- sanity
SELECT COUNT(*) AS Dates, MIN([Date]) AS MinDate, MAX([Date]) AS MaxDate FROM dw.DimDate;

EXEC sp_help 'stg.salesRaw';

IF OBJECT_ID('dw.FactSales') IS NOT NULL DROP TABLE dw.FactSales;
CREATE TABLE dw.FactSales(
    SK_Sales      int IDENTITY(1,1) PRIMARY KEY,  -- surrogate key
    OrderKey      int,
    LineNumber    int,
    SK_Date       int,    -- links to DimDate
    SK_Delivery   int,    -- links to DimDate (delivery date)
    SK_Customer   int,    -- links to DimCustomer
    SK_Store      int,    -- links to DimStore
    SK_Product    int,    -- links to DimProduct
    Quantity      int,
    UnitPrice     float,
    NetPrice      float,
    UnitCost      float,
    CurrencyCode  nvarchar(100),
    ExchangeRate  float
);

USE RetailOps360;

-- 1) Quick mapping quality check
SELECT 
    COUNT(*)                                       AS TotalRows,
    SUM(CASE WHEN dp.SK_Product  IS NULL THEN 1 ELSE 0 END) AS Missing_Product,
    SUM(CASE WHEN ds.SK_Store    IS NULL THEN 1 ELSE 0 END) AS Missing_Store,
    SUM(CASE WHEN dc.SK_Customer IS NULL THEN 1 ELSE 0 END) AS Missing_Customer,
    SUM(CASE WHEN dd.DateKey     IS NULL THEN 1 ELSE 0 END) AS Missing_OrderDate,
    SUM(CASE WHEN dlv.DateKey    IS NULL THEN 1 ELSE 0 END) AS Missing_DeliveryDate
FROM stg.salesRaw s
LEFT JOIN dw.DimProduct  dp ON dp.ProductKey  = s.ProductKey
LEFT JOIN dw.DimStore    ds ON ds.StoreKey    = s.StoreKey
LEFT JOIN dw.DimCustomer dc ON dc.CustomerKey = s.CustomerKey
LEFT JOIN dw.DimDate     dd ON dd.[Date]      = s.OrderDate
LEFT JOIN dw.DimDate     dlv ON dlv.[Date]    = s.DeliveryDate;

-- 2) Show a few problem rows (if any)
SELECT TOP 20 s.*
FROM stg.salesRaw s
LEFT JOIN dw.DimProduct  dp ON dp.ProductKey  = s.ProductKey
LEFT JOIN dw.DimStore    ds ON ds.StoreKey    = s.StoreKey
LEFT JOIN dw.DimCustomer dc ON dc.CustomerKey = s.CustomerKey
LEFT JOIN dw.DimDate     dd ON dd.[Date]      = s.OrderDate
LEFT JOIN dw.DimDate     dlv ON dlv.[Date]    = s.DeliveryDate
WHERE dp.SK_Product IS NULL
   OR ds.SK_Store   IS NULL
   OR dc.SK_Customer IS NULL
   OR dd.DateKey    IS NULL
   OR dlv.DateKey   IS NULL;

-- A) How many distinct CustomerKeys are missing from the dimension?
SELECT 
  COUNT(DISTINCT s.CustomerKey) AS DistinctMissingCustomerKeys,
  MIN(s.CustomerKey) AS MinMissingKey,
  MAX(s.CustomerKey) AS MaxMissingKey
FROM stg.salesRaw s
LEFT JOIN dw.DimCustomer dc ON dc.CustomerKey = s.CustomerKey
WHERE dc.SK_Customer IS NULL;

-- B) Show the top 20 missing CustomerKeys with how many sales rows they affect
SELECT TOP 20 
  s.CustomerKey, 
  COUNT(*) AS RowsAffected
FROM stg.salesRaw s
LEFT JOIN dw.DimCustomer dc ON dc.CustomerKey = s.CustomerKey
WHERE dc.SK_Customer IS NULL
GROUP BY s.CustomerKey
ORDER BY RowsAffected DESC;

USE RetailOps360;

-- Add placeholder rows for any CustomerKey that exists in sales but not in the dimension
INSERT INTO dw.DimCustomer
  (CustomerKey, FullName, Gender, City, [State], Country, Birthday, Age, AgeSegment, Occupation, Company)
SELECT DISTINCT
  s.CustomerKey,
  CONCAT('Unknown Customer ', s.CustomerKey) AS FullName,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
FROM stg.salesRaw s
LEFT JOIN dw.DimCustomer dc ON dc.CustomerKey = s.CustomerKey
WHERE dc.CustomerKey IS NULL;

SELECT 
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN dp.SK_Product  IS NULL THEN 1 ELSE 0 END) AS Missing_Product,
    SUM(CASE WHEN ds.SK_Store    IS NULL THEN 1 ELSE 0 END) AS Missing_Store,
    SUM(CASE WHEN dc.SK_Customer IS NULL THEN 1 ELSE 0 END) AS Missing_Customer,
    SUM(CASE WHEN dd.DateKey     IS NULL THEN 1 ELSE 0 END) AS Missing_OrderDate,
    SUM(CASE WHEN dlv.DateKey    IS NULL THEN 1 ELSE 0 END) AS Missing_DeliveryDate
FROM stg.salesRaw s
LEFT JOIN dw.DimProduct  dp ON dp.ProductKey  = s.ProductKey
LEFT JOIN dw.DimStore    ds ON ds.StoreKey    = s.StoreKey
LEFT JOIN dw.DimCustomer dc ON dc.CustomerKey = s.CustomerKey
LEFT JOIN dw.DimDate     dd ON dd.[Date]      = s.OrderDate
LEFT JOIN dw.DimDate     dlv ON dlv.[Date]    = s.DeliveryDate;

USE RetailOps360;

-- Insert sales with mapped surrogate keys
INSERT INTO dw.FactSales
  (OrderKey, LineNumber, SK_Date, SK_Delivery, SK_Customer, SK_Store, SK_Product,
   Quantity, UnitPrice, NetPrice, UnitCost, CurrencyCode, ExchangeRate)
SELECT
  s.OrderKey,
  s.LineNumber,
  CONVERT(int, FORMAT(s.OrderDate,'yyyyMMdd'))  AS SK_Date,
  CONVERT(int, FORMAT(s.DeliveryDate,'yyyyMMdd')) AS SK_Delivery,
  dc.SK_Customer,
  ds.SK_Store,
  dp.SK_Product,
  s.Quantity,
  s.UnitPrice,
  s.NetPrice,
  s.UnitCost,
  s.CurrencyCode,
  s.ExchangeRate
FROM stg.salesRaw s
JOIN dw.DimProduct  dp ON dp.ProductKey  = s.ProductKey
JOIN dw.DimStore    ds ON ds.StoreKey    = s.StoreKey
JOIN dw.DimCustomer dc ON dc.CustomerKey = s.CustomerKey
JOIN dw.DimDate     dd ON dd.[Date]      = s.OrderDate
JOIN dw.DimDate     dl ON dl.[Date]      = s.DeliveryDate;

SELECT COUNT(*) AS FactRows FROM dw.FactSales;
SELECT TOP 5 * FROM dw.FactSales;

USE RetailOps360;

-- A) What range do we actually have?
SELECT MIN(OrderDate) AS MinOrderDate,
       MAX(OrderDate) AS MaxOrderDate
FROM stg.salesRaw;

-- B) How many rows per year?
SELECT YEAR(OrderDate) AS [Year],
       COUNT(*)        AS Rows
FROM stg.salesRaw
GROUP BY YEAR(OrderDate)
ORDER BY [Year];

USE RetailOps360
SELECT TOP 10 * 
FROM stg.BudgetRaw;

USE RetailOps360
SELECT TABLE_SCHEMA, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%Inventory%';
