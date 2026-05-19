-- ============================================================================
-- SILVER LAYER - Canonical Schemas
-- All ERP sources map to unified table structures
-- Data quality validation, deduplication, referential integrity
-- ============================================================================

-- Schema creation
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA silver');
END
GO

-- ============================================================================
-- silver_sales_order - Unified sales order canonical schema
-- Consolidates orders from all ERP sources
-- ============================================================================
IF OBJECT_ID('silver.sales_order', 'U') IS NULL
BEGIN
    CREATE TABLE silver.sales_order (
        -- Surrogate key
        SalesOrderKey INT IDENTITY(1,1) NOT NULL,

        -- Natural key (composite: source system + source order ID)
        SourceSystem NVARCHAR(50) NOT NULL,
        SourceOrderID NVARCHAR(50) NOT NULL,
        NaturalKey AS (SourceSystem + '|' + SourceOrderID) PERSISTED,

        -- Business fields (canonical)
        OrderDate DATE NOT NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        CustomerName NVARCHAR(200) NULL,
        TotalAmount DECIMAL(18,2) NULL,
        OrderStatus NVARCHAR(50) NULL,
        POReference NVARCHAR(100) NULL,

        -- Data quality
        ValidationStatus NVARCHAR(20) DEFAULT 'pending',
        ValidationErrors NVARCHAR(MAX) NULL,

        -- Row metadata for SCD (future use)
        SourceRowHash NVARCHAR(64) NULL,
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),

        -- Constraints
        CONSTRAINT PK_silver_sales_order PRIMARY KEY NONCLUSTERED (SalesOrderKey),
        CONSTRAINT UQ_silver_sales_order_natural_key UNIQUE CLUSTERED (NaturalKey)
    );

    -- Indexes for common queries
    CREATE INDEX IX_silver_sales_order_date ON silver.sales_order (OrderDate);
    CREATE INDEX IX_silver_sales_order_customer ON silver.sales_order (CustomerID);
    CREATE INDEX IX_silver_sales_order_status ON silver.sales_order (OrderStatus);
END
GO

-- ============================================================================
-- silver_invoice - Unified invoice canonical schema
-- ============================================================================
IF OBJECT_ID('silver.invoice', 'U') IS NULL
BEGIN
    CREATE TABLE silver.invoice (
        InvoiceKey INT IDENTITY(1,1) NOT NULL,

        SourceSystem NVARCHAR(50) NOT NULL,
        SourceInvoiceID NVARCHAR(50) NOT NULL,
        NaturalKey AS (SourceSystem + '|' + SourceInvoiceID) PERSISTED,

        -- FK to sales order
        SourceOrderID NVARCHAR(50) NULL,

        InvoiceDate DATE NOT NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        CustomerName NVARCHAR(200) NULL,
        TotalAmount DECIMAL(18,2) NULL,
        PaidAmount DECIMAL(18,2) DEFAULT 0,
        BalanceDue AS (ISNULL(TotalAmount,0) - ISNULL(PaidAmount,0)) PERSISTED,

        ValidationStatus NVARCHAR(20) DEFAULT 'pending',
        ValidationErrors NVARCHAR(MAX) NULL,

        SourceRowHash NVARCHAR(64) NULL,
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),

        CONSTRAINT PK_silver_invoice PRIMARY KEY NONCLUSTERED (InvoiceKey),
        CONSTRAINT UQ_silver_invoice_natural_key UNIQUE CLUSTERED (NaturalKey)
    );

    CREATE INDEX IX_silver_invoice_date ON silver.invoice (InvoiceDate);
    CREATE INDEX IX_silver_invoice_customer ON silver.invoice (CustomerID);
END
GO

-- ============================================================================
-- silver_shipment - Unified shipment canonical schema
-- ============================================================================
IF OBJECT_ID('silver.shipment', 'U') IS NULL
BEGIN
    CREATE TABLE silver.shipment (
        ShipmentKey INT IDENTITY(1,1) NOT NULL,

        SourceSystem NVARCHAR(50) NOT NULL,
        SourceShipmentID NVARCHAR(50) NOT NULL,
        NaturalKey AS (SourceSystem + '|' + SourceShipmentID) PERSISTED,

        SourceOrderID NVARCHAR(50) NULL,
        ShipDate DATE NOT NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        CustomerName NVARCHAR(200) NULL,
        Carrier NVARCHAR(100) NULL,
        TrackingNumber NVARCHAR(100) NULL,

        ValidationStatus NVARCHAR(20) DEFAULT 'pending',
        ValidationErrors NVARCHAR(MAX) NULL,

        SourceRowHash NVARCHAR(64) NULL,
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),

        CONSTRAINT PK_silver_shipment PRIMARY KEY NONCLUSTERED (ShipmentKey),
        CONSTRAINT UQ_silver_shipment_natural_key UNIQUE CLUSTERED (NaturalKey)
    );

    CREATE INDEX IX_silver_shipment_date ON silver.shipment (ShipDate);
    CREATE INDEX IX_silver_shipment_order ON silver.shipment (SourceOrderID);
END
GO

-- ============================================================================
-- silver_customer - Unified customer canonical schema
-- Handles deduplication across ERPs
-- ============================================================================
IF OBJECT_ID('silver.customer', 'U') IS NULL
BEGIN
    CREATE TABLE silver.customer (
        CustomerKey INT IDENTITY(1,1) NOT NULL,

        SourceSystem NVARCHAR(50) NOT NULL,
        SourceCustomerID NVARCHAR(50) NOT NULL,
        NaturalKey AS (SourceSystem + '|' + SourceCustomerID) PERSISTED,

        CustomerID NVARCHAR(50) NOT NULL,  -- Canonical ID (after dedup)
        CustomerName NVARCHAR(200) NOT NULL,
        Region NVARCHAR(50) NULL,
        Segment NVARCHAR(50) NULL,

        -- Master ID for dedup matching (use name + address hash or MDM ID)
        MasterCustomerID NVARCHAR(50) NULL,

        ValidationStatus NVARCHAR(20) DEFAULT 'pending',
        ValidationErrors NVARCHAR(MAX) NULL,

        SourceRowHash NVARCHAR(64) NULL,
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),

        CONSTRAINT PK_silver_customer PRIMARY KEY NONCLUSTERED (CustomerKey),
        CONSTRAINT UQ_silver_customer_natural_key UNIQUE CLUSTERED (NaturalKey)
    );

    CREATE INDEX IX_silver_customer_master ON silver.customer (MasterCustomerID) WHERE MasterCustomerID IS NOT NULL;
    CREATE INDEX IX_silver_customer_name ON silver.customer (CustomerName);
END
GO

-- ============================================================================
-- silver_product - Unified product canonical schema
-- ============================================================================
IF OBJECT_ID('silver.product', 'U') IS NULL
BEGIN
    CREATE TABLE silver.product (
        ProductKey INT IDENTITY(1,1) NOT NULL,

        SourceSystem NVARCHAR(50) NOT NULL,
        SourceProductID NVARCHAR(50) NOT NULL,
        NaturalKey AS (SourceSystem + '|' + SourceProductID) PERSISTED,

        ProductID NVARCHAR(50) NOT NULL,
        ProductName NVARCHAR(200) NOT NULL,
        Category NVARCHAR(100) NULL,
        Subcategory NVARCHAR(100) NULL,
        UnitOfMeasure NVARCHAR(50) NULL,

        MasterProductID NVARCHAR(50) NULL,

        ValidationStatus NVARCHAR(20) DEFAULT 'pending',
        ValidationErrors NVARCHAR(MAX) NULL,

        SourceRowHash NVARCHAR(64) NULL,
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),

        CONSTRAINT PK_silver_product PRIMARY KEY NONCLUSTERED (ProductKey),
        CONSTRAINT UQ_silver_product_natural_key UNIQUE CLUSTERED (NaturalKey)
    );

    CREATE INDEX IX_silver_product_master ON silver.product (MasterProductID) WHERE MasterProductID IS NOT NULL;
    CREATE INDEX IX_silver_product_name ON silver.product (ProductName);
END
GO

-- ============================================================================
-- silver_vendor - Unified vendor canonical schema
-- ============================================================================
IF OBJECT_ID('silver.vendor', 'U') IS NULL
BEGIN
    CREATE TABLE silver.vendor (
        VendorKey INT IDENTITY(1,1) NOT NULL,

        SourceSystem NVARCHAR(50) NOT NULL,
        SourceVendorID NVARCHAR(50) NOT NULL,
        NaturalKey AS (SourceSystem + '|' + SourceVendorID) PERSISTED,

        VendorID NVARCHAR(50) NOT NULL,
        VendorName NVARCHAR(200) NOT NULL,
        Category NVARCHAR(100) NULL,
        PaymentTerms NVARCHAR(100) NULL,

        MasterVendorID NVARCHAR(50) NULL,

        ValidationStatus NVARCHAR(20) DEFAULT 'pending',
        ValidationErrors NVARCHAR(MAX) NULL,

        SourceRowHash NVARCHAR(64) NULL,
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),

        CONSTRAINT PK_silver_vendor PRIMARY KEY NONCLUSTERED (VendorKey),
        CONSTRAINT UQ_silver_vendor_natural_key UNIQUE CLUSTERED (NaturalKey)
    );
END
GO

-- ============================================================================
-- silver_inventory - Unified inventory canonical schema
-- ============================================================================
IF OBJECT_ID('silver.inventory', 'U') IS NULL
BEGIN
    CREATE TABLE silver.inventory (
        InventoryKey INT IDENTITY(1,1) NOT NULL,

        SourceSystem NVARCHAR(50) NOT NULL,
        SourceSnapshotID NVARCHAR(50) NOT NULL,
        NaturalKey AS (SourceSystem + '|' + SourceSnapshotID + '|' + ProductID + '|' + WarehouseID) PERSISTED,

        SnapshotDate DATE NOT NULL,
        ProductID NVARCHAR(50) NOT NULL,
        WarehouseID NVARCHAR(50) NOT NULL,
        Quantity DECIMAL(18,2) NOT NULL,

        ValidationStatus NVARCHAR(20) DEFAULT 'pending',
        ValidationErrors NVARCHAR(MAX) NULL,

        SourceRowHash NVARCHAR(64) NULL,
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),

        CONSTRAINT PK_silver_inventory PRIMARY KEY NONCLUSTERED (InventoryKey),
        CONSTRAINT UQ_silver_inventory_natural_key UNIQUE CLUSTERED (NaturalKey)
    );

    CREATE INDEX IX_silver_inventory_date ON silver.inventory (SnapshotDate);
    CREATE INDEX IX_silver_inventory_product ON silver.inventory (ProductID);
    CREATE INDEX IX_silver_inventory_warehouse ON silver.inventory (WarehouseID);
END
GO

-- ============================================================================
-- Data Quality Validation Check Constraints
-- ============================================================================
ALTER TABLE silver.sales_order ADD CONSTRAINT CK_sales_order_date
    CHECK (OrderDate <= DATEADD(DAY, 1, GETDATE()));  -- No future orders

ALTER TABLE silver.sales_order ADD CONSTRAINT CK_sales_order_amount
    CHECK (TotalAmount IS NULL OR TotalAmount >= 0);  -- No negative amounts

ALTER TABLE silver.invoice ADD CONSTRAINT CK_invoice_date
    CHECK (InvoiceDate <= DATEADD(DAY, 1, GETDATE()));

ALTER TABLE silver.invoice ADD CONSTRAINT CK_invoice_paid
    CHECK (PaidAmount >= 0 AND PaidAmount <= ISNULL(TotalAmount, 0));

ALTER TABLE silver.shipment ADD CONSTRAINT CK_shipment_date
    CHECK (ShipDate <= DATEADD(DAY, 1, GETDATE()));

ALTER TABLE silver.customer ADD CONSTRAINT CK_customer_name
    CHECK (LEN(CustomerName) > 0);

ALTER TABLE silver.product ADD CONSTRAINT CK_product_name
    CHECK (LEN(ProductName) > 0);

ALTER TABLE silver.inventory ADD CONSTRAINT CK_inventory_qty
    CHECK (Quantity >= 0);

PRINT 'Silver layer canonical tables created successfully.';
GO