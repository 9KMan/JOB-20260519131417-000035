-- ============================================================================
-- Gold Layer Dimension Tables (Kimball Methodology)
-- ============================================================================
-- Type 2 slowly changing dimensions with surrogate keys and version tracking.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- Gold Schema
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS gold;
GO

-- ============================================================================
-- DimProduct - SCD Type 2
-- ============================================================================
CREATE TABLE gold.DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    NaturalKey NVARCHAR(255) NOT NULL,
    Name NVARCHAR(255) NOT NULL,
    Category NVARCHAR(100) NULL,
    Subcategory NVARCHAR(100) NULL,
    UnitOfMeasure NVARCHAR(50) NULL,
    StandardCost DECIMAL(18,4) NULL,
    SupplierID NVARCHAR(50) NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    ValidFrom DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ValidTo DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    VersionNumber INT NOT NULL DEFAULT 1,
    
    CONSTRAINT CK_DimProduct_current CHECK (IsCurrent IN (0, 1)),
    CONSTRAINT UQ_DimProduct_natural_key UNIQUE (NaturalKey, IsCurrent)
);
GO

CREATE NONCLUSTERED INDEX IX_DimProduct_NaturalKey ON gold.DimProduct (NaturalKey ASC) WHERE IsCurrent = 1;
CREATE NONCLUSTERED INDEX IX_DimProduct_Category ON gold.DimProduct (Category ASC) WHERE IsCurrent = 1;
GO

-- ============================================================================
-- DimCustomer - SCD Type 2
-- ============================================================================
CREATE TABLE gold.DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    NaturalKey NVARCHAR(255) NOT NULL,
    CustomerName NVARCHAR(255) NOT NULL,
    Region NVARCHAR(100) NULL,
    Segment NVARCHAR(100) NULL,
    CustomerAddress NVARCHAR(500) NULL,
    CustomerCity NVARCHAR(100) NULL,
    CustomerPostalCode NVARCHAR(20) NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    ValidFrom DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ValidTo DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    VersionNumber INT NOT NULL DEFAULT 1,
    
    CONSTRAINT CK_DimCustomer_current CHECK (IsCurrent IN (0, 1)),
    CONSTRAINT UQ_DimCustomer_natural_key UNIQUE (NaturalKey, IsCurrent)
);
GO

CREATE NONCLUSTERED INDEX IX_DimCustomer_NaturalKey ON gold.DimCustomer (NaturalKey ASC) WHERE IsCurrent = 1;
CREATE NONCLUSTERED INDEX IX_DimCustomer_Region ON gold.DimCustomer (Region ASC) WHERE IsCurrent = 1;
GO

-- ============================================================================
-- DimVendor - SCD Type 2
-- ============================================================================
CREATE TABLE gold.DimVendor (
    VendorKey INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    NaturalKey NVARCHAR(255) NOT NULL,
    VendorName NVARCHAR(255) NOT NULL,
    Category NVARCHAR(100) NULL,
    PaymentTerms NVARCHAR(100) NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    ValidFrom DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ValidTo DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    VersionNumber INT NOT NULL DEFAULT 1,
    
    CONSTRAINT CK_DimVendor_current CHECK (IsCurrent IN (0, 1)),
    CONSTRAINT UQ_DimVendor_natural_key UNIQUE (NaturalKey, IsCurrent)
);
GO

CREATE NONCLUSTERED INDEX IX_DimVendor_NaturalKey ON gold.DimVendor (NaturalKey ASC) WHERE IsCurrent = 1;
GO

-- ============================================================================
-- DimDate - Type 1 (Static Dimension)
-- ============================================================================
CREATE TABLE gold.DimDate (
    DateKey INT NOT NULL PRIMARY KEY CLUSTERED,  -- Format: 20260101 for Jan 1 2026
    FullDate DATE NOT NULL,
    DayOfWeek TINYINT NOT NULL,
    DayName NVARCHAR(10) NOT NULL,
    Month TINYINT NOT NULL,
    MonthName NVARCHAR(10) NOT NULL,
    Quarter TINYINT NOT NULL,
    Year SMALLINT NOT NULL,
    WeekOfYear TINYINT NOT NULL,
    FiscalYear SMALLINT NOT NULL,
    FiscalQuarter TINYINT NOT NULL,
    
    CONSTRAINT CK_DimDate_dayofweek CHECK (DayOfWeek BETWEEN 1 AND 7),
    CONSTRAINT CK_DimDate_month CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT CK_DimDate_quarter CHECK (Quarter BETWEEN 1 AND 4)
);
GO

CREATE NONCLUSTERED INDEX IX_DimDate_FullDate ON gold.DimDate (FullDate ASC);
CREATE NONCLUSTERED INDEX IX_DimDate_Year ON gold.DimDate (Year ASC);
GO

-- ============================================================================
-- DimCurrency - Type 1
-- ============================================================================
CREATE TABLE gold.DimCurrency (
    CurrencyKey INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    CurrencyCode NVARCHAR(10) NOT NULL,
    CurrencyName NVARCHAR(100) NOT NULL,
    ExchangeRate DECIMAL(18,8) NULL,
    RateDate DATE NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    
    CONSTRAINT CK_DimCurrency_current CHECK (IsCurrent IN (0, 1)),
    CONSTRAINT UQ_DimCurrency_code UNIQUE (CurrencyCode, IsCurrent)
);
GO

CREATE NONCLUSTERED INDEX IX_DimCurrency_Code ON gold.DimCurrency (CurrencyCode ASC) WHERE IsCurrent = 1;
GO

-- ============================================================================
-- DimLocation - SCD Type 2
-- ============================================================================
CREATE TABLE gold.DimLocation (
    LocationKey INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    NaturalKey NVARCHAR(255) NOT NULL,
    WarehouseID NVARCHAR(50) NULL,
    WarehouseName NVARCHAR(255) NULL,
    Region NVARCHAR(100) NULL,
    Country NVARCHAR(100) NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    ValidFrom DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ValidTo DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    VersionNumber INT NOT NULL DEFAULT 1,
    
    CONSTRAINT CK_DimLocation_current CHECK (IsCurrent IN (0, 1)),
    CONSTRAINT UQ_DimLocation_natural_key UNIQUE (NaturalKey, IsCurrent)
);
GO

CREATE NONCLUSTERED INDEX IX_DimLocation_NaturalKey ON gold.DimLocation (NaturalKey ASC) WHERE IsCurrent = 1;
CREATE NONCLUSTERED INDEX IX_DimLocation_Region ON gold.DimLocation (Region ASC) WHERE IsCurrent = 1;
GO

PRINT 'Gold dimension tables created successfully.';
GO