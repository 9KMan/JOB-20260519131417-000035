-- ============================================================================
-- GOLD LAYER - Kimball Dimensional Model
-- Star Schema with Surrogate Keys and SCD Type 2
-- ============================================================================

-- Schema creation
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END
GO

-- ============================================================================
-- Sequences for surrogate key generation
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_dim_date')
    CREATE SEQUENCE gold.seq_dim_date AS INT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_dim_product')
    CREATE SEQUENCE gold.seq_dim_product AS INT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_dim_customer')
    CREATE SEQUENCE gold.seq_dim_customer AS INT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_dim_vendor')
    CREATE SEQUENCE gold.seq_dim_vendor AS INT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_dim_currency')
    CREATE SEQUENCE gold.seq_dim_currency AS INT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_dim_location')
    CREATE SEQUENCE gold.seq_dim_location AS INT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_dim_uom')
    CREATE SEQUENCE gold.seq_dim_uom AS INT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_fact_sales_order')
    CREATE SEQUENCE gold.seq_fact_sales_order AS BIGINT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_fact_inventory')
    CREATE SEQUENCE gold.seq_fact_inventory AS BIGINT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_fact_procurement')
    CREATE SEQUENCE gold.seq_fact_procurement AS BIGINT START WITH 1 INCREMENT BY 1;

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_fact_shipment')
    CREATE SEQUENCE gold.seq_fact_shipment AS BIGINT START WITH 1 INCREMENT BY 1;
GO

-- ============================================================================
-- DimDate - Static dimension (dates don't change)
-- Pre-populated for analytical queries
-- ============================================================================
IF OBJECT_ID('gold.DimDate', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimDate (
        DateKey INT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_dim_date),
        FullDate DATE NOT NULL,
        DayOfWeek NVARCHAR(10) NULL,
        DayNumberOfWeek INT NULL,
        DayNumberOfMonth INT NULL,
        DayNumberOfYear INT NULL,
        WeekNumberOfYear INT NULL,
        MonthName NVARCHAR(20) NULL,
        MonthNumberOfYear INT NULL,
        QuarterNumber INT NULL,
        YearNumber INT NULL,
        IsWeekend BIT NULL,
        IsHoliday BIT NULL,
        FiscalYear INT NULL,
        FiscalQuarter INT NULL,
        CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (DateKey),
        CONSTRAINT UQ_DimDate_FullDate UNIQUE NONCLUSTERED (FullDate)
    );

    -- Populate with sample dates (in production, use a proper date dimension table)
    ;WITH DateRange AS (
        SELECT DATEADD(DAY, -365, CAST(SYSDATETIME() AS DATE)) AS dt
        UNION ALL
        SELECT DATEADD(DAY, 1, dt) FROM DateRange WHERE dt < CAST(SYSDATETIME() AS DATE)
    )
    INSERT INTO gold.DimDate (DateKey, FullDate, DayOfWeek, DayNumberOfWeek, DayNumberOfMonth,
                              DayNumberOfYear, WeekNumberOfYear, MonthName, MonthNumberOfYear,
                              QuarterNumber, YearNumber, IsWeekend, IsHoliday)
    SELECT
        DateKey = CAST(FORMAT(dt, 'yyyyMMdd') AS INT),
        FullDate = dt,
        DayOfWeek = DATENAME(WEEKDAY, dt),
        DayNumberOfWeek = DATEPART(WEEKDAY, dt),
        DayNumberOfMonth = DATEPART(DAY, dt),
        DayNumberOfYear = DATEPART(DAYOFYEAR, dt),
        WeekNumberOfYear = DATEPART(WEEK, dt),
        MonthName = DATENAME(MONTH, dt),
        MonthNumberOfYear = DATEPART(MONTH, dt),
        QuarterNumber = DATEPART(QUARTER, dt),
        YearNumber = DATEPART(YEAR, dt),
        IsWeekend = CASE WHEN DATEPART(WEEKDAY, dt) IN (1, 7) THEN 1 ELSE 0 END,
        IsHoliday = 0
    FROM DateRange
    OPTION (MAXRECURSION 400);

    -- Add indexes
    CREATE INDEX IX_DimDate_Year ON gold.DimDate (YearNumber);
    CREATE INDEX IX_DimDate_Month ON gold.DimDate (YearNumber, MonthNumberOfYear);
    CREATE INDEX IX_DimDate_Quarter ON gold.DimDate (YearNumber, QuarterNumber);
END
GO

-- ============================================================================
-- DimProduct - SCD Type 2 dimension
-- Tracks product changes historically
-- ============================================================================
IF OBJECT_ID('gold.DimProduct', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimProduct (
        ProductKey INT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_dim_product),
        NaturalKey NVARCHAR(100) NOT NULL,
        ProductID NVARCHAR(50) NOT NULL,
        ProductName NVARCHAR(200) NOT NULL,
        Category NVARCHAR(100) NULL,
        Subcategory NVARCHAR(100) NULL,
        UnitOfMeasureKey INT NULL,
        -- SCD Type 2
        StartDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EndDate DATETIME2 NULL,
        IsCurrent BIT NOT NULL DEFAULT 1,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_DimProduct PRIMARY KEY CLUSTERED (ProductKey),
        CONSTRAINT UQ_DimProduct_NaturalKey_Current
            UNIQUE NONCLUSTERED (NaturalKey, IsCurrent)
            WHERE IsCurrent = 1
    );

    CREATE INDEX IX_DimProduct_NaturalKey ON gold.DimProduct (NaturalKey);
    CREATE INDEX IX_DimProduct_ProductID ON gold.DimProduct (ProductID);
    CREATE INDEX IX_DimProduct_Current ON gold.DimProduct (IsCurrent) WHERE IsCurrent = 1;
END
GO

-- ============================================================================
-- DimCustomer - SCD Type 2 dimension
-- Tracks customer changes historically
-- ============================================================================
IF OBJECT_ID('gold.DimCustomer', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimCustomer (
        CustomerKey INT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_dim_customer),
        NaturalKey NVARCHAR(100) NOT NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        CustomerName NVARCHAR(200) NOT NULL,
        Region NVARCHAR(50) NULL,
        Segment NVARCHAR(50) NULL,
        -- SCD Type 2
        StartDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EndDate DATETIME2 NULL,
        IsCurrent BIT NOT NULL DEFAULT 1,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_DimCustomer PRIMARY KEY CLUSTERED (CustomerKey),
        CONSTRAINT UQ_DimCustomer_NaturalKey_Current
            UNIQUE NONCLUSTERED (NaturalKey, IsCurrent)
            WHERE IsCurrent = 1
    );

    CREATE INDEX IX_DimCustomer_NaturalKey ON gold.DimCustomer (NaturalKey);
    CREATE INDEX IX_DimCustomer_CustomerID ON gold.DimCustomer (CustomerID);
    CREATE INDEX IX_DimCustomer_Current ON gold.DimCustomer (IsCurrent) WHERE IsCurrent = 1;
    CREATE INDEX IX_DimCustomer_Region ON gold.DimCustomer (Region) WHERE Region IS NOT NULL;
END
GO

-- ============================================================================
-- DimVendor - SCD Type 2 dimension
-- ============================================================================
IF OBJECT_ID('gold.DimVendor', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimVendor (
        VendorKey INT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_dim_vendor),
        NaturalKey NVARCHAR(100) NOT NULL,
        VendorID NVARCHAR(50) NOT NULL,
        VendorName NVARCHAR(200) NOT NULL,
        Category NVARCHAR(100) NULL,
        PaymentTerms NVARCHAR(100) NULL,
        -- SCD Type 2
        StartDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EndDate DATETIME2 NULL,
        IsCurrent BIT NOT NULL DEFAULT 1,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_DimVendor PRIMARY KEY CLUSTERED (VendorKey),
        CONSTRAINT UQ_DimVendor_NaturalKey_Current
            UNIQUE NONCLUSTERED (NaturalKey, IsCurrent)
            WHERE IsCurrent = 1
    );

    CREATE INDEX IX_DimVendor_NaturalKey ON gold.DimVendor (NaturalKey);
    CREATE INDEX IX_DimVendor_Current ON gold.DimVendor (IsCurrent) WHERE IsCurrent = 1;
END
GO

-- ============================================================================
-- DimCurrency - Type 1 dimension (latest rate only)
-- ============================================================================
IF OBJECT_ID('gold.DimCurrency', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimCurrency (
        CurrencyKey INT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_dim_currency),
        CurrencyCode NVARCHAR(3) NOT NULL,
        CurrencyName NVARCHAR(50) NOT NULL,
        ExchangeRate DECIMAL(18,6) NULL,
        RateDate DATE NOT NULL,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_DimCurrency PRIMARY KEY CLUSTERED (CurrencyKey),
        CONSTRAINT UQ_DimCurrency_Code_Date UNIQUE NONCLUSTERED (CurrencyCode, RateDate)
    );

    CREATE INDEX IX_DimCurrency_Code ON gold.DimCurrency (CurrencyCode);
END
GO

-- ============================================================================
-- DimLocation - SCD Type 2 dimension
-- ============================================================================
IF OBJECT_ID('gold.DimLocation', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimLocation (
        LocationKey INT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_dim_location),
        NaturalKey NVARCHAR(100) NOT NULL,
        WarehouseID NVARCHAR(50) NOT NULL,
        WarehouseName NVARCHAR(200) NOT NULL,
        Region NVARCHAR(50) NULL,
        Country NVARCHAR(50) NULL,
        City NVARCHAR(100) NULL,
        -- SCD Type 2
        StartDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EndDate DATETIME2 NULL,
        IsCurrent BIT NOT NULL DEFAULT 1,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_DimLocation PRIMARY KEY CLUSTERED (LocationKey),
        CONSTRAINT UQ_DimLocation_NaturalKey_Current
            UNIQUE NONCLUSTERED (NaturalKey, IsCurrent)
            WHERE IsCurrent = 1
    );

    CREATE INDEX IX_DimLocation_NaturalKey ON gold.DimLocation (NaturalKey);
    CREATE INDEX IX_DimLocation_WarehouseID ON gold.DimLocation (WarehouseID);
    CREATE INDEX IX_DimLocation_Current ON gold.DimLocation (IsCurrent) WHERE IsCurrent = 1;
END
GO

-- ============================================================================
-- DimUOM - Type 1 dimension (unit of measure lookup)
-- ============================================================================
IF OBJECT_ID('gold.DimUOM', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimUOM (
        UOMKey INT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_dim_uom),
        UOMCode NVARCHAR(20) NOT NULL,
        UOMName NVARCHAR(50) NOT NULL,
        UOMType NVARCHAR(20) NULL,  -- 'Weight', 'Volume', 'Each', etc.
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_DimUOM PRIMARY KEY CLUSTERED (UOMKey),
        CONSTRAINT UQ_DimUOM_Code UNIQUE NONCLUSTERED (UOMCode)
    );

    -- Standard UOMs
    INSERT INTO gold.DimUOM (UOMCode, UOMName, UOMType) VALUES
    ('EA', 'Each', 'Each'),
    ('CS', 'Case', 'Each'),
    ('PK', 'Pack', 'Each'),
    ('BX', 'Box', 'Each'),
    ('LB', 'Pound', 'Weight'),
    ('KG', 'Kilogram', 'Weight'),
    ('OZ', 'Ounce', 'Weight'),
    ('GAL', 'Gallon', 'Volume'),
    ('L', 'Liter', 'Volume'),
    ('ML', 'Milliliter', 'Volume');
END
GO

-- ============================================================================
-- DimSalesRep - SCD Type 2 dimension
-- ============================================================================
IF OBJECT_ID('gold.DimSalesRep', 'U') IS NULL
BEGIN
    CREATE TABLE gold.DimSalesRep (
        SalesRepKey INT NOT NULL,
        NaturalKey NVARCHAR(100) NOT NULL,
        SalesRepID NVARCHAR(50) NOT NULL,
        SalesRepName NVARCHAR(200) NOT NULL,
        Region NVARCHAR(50) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        StartDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EndDate DATETIME2 NULL,
        IsCurrent BIT NOT NULL DEFAULT 1,
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_DimSalesRep PRIMARY KEY CLUSTERED (SalesRepKey),
        CONSTRAINT UQ_DimSalesRep_NaturalKey_Current
            UNIQUE NONCLUSTERED (NaturalKey, IsCurrent)
            WHERE IsCurrent = 1
    );
END
GO

PRINT 'Gold dimension tables created successfully.';
GO