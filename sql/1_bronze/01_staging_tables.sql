-- ============================================================================
-- BRONZE LAYER - Staging Schema
-- Raw ERP data with watermark-based incremental CDC
-- No full re-loads - incremental only
-- ============================================================================

-- Schema creation
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze');
END
GO

-- ============================================================================
-- Watermark tracking table - persists last sync timestamp per source table
-- ============================================================================
IF OBJECT_ID('bronze.watermark', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.watermark (
        source_id NVARCHAR(50) NOT NULL,
        source_table NVARCHAR(100) NOT NULL,
        stage_table NVARCHAR(100) NOT NULL,
        last_watermark_value DATETIME2 NULL,
        last_run_time DATETIME2 NULL,
        rows_processed INT NULL,
        status NVARCHAR(20) DEFAULT 'idle',
        error_message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_bronze_watermark PRIMARY KEY (source_id, source_table)
    );
END
GO

-- ============================================================================
-- Generic staging table structure for sales orders
-- ============================================================================
IF OBJECT_ID('bronze.stage_sage_sales_orders', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_sage_sales_orders (
        -- Natural key from source
        OrderID NVARCHAR(50) NOT NULL,
        -- Business fields
        CustomerID NVARCHAR(50) NOT NULL,
        OrderDate DATETIME2 NOT NULL,
        TotalAmount DECIMAL(18,2) NULL,
        OrderStatus NVARCHAR(50) NULL,
        -- CDC metadata
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'sage_erp',
        -- Staging metadata
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        -- Primary key constraint
        CONSTRAINT PK_bronze_stage_sage_sales_orders PRIMARY KEY (OrderID)
    );

    -- Non-clustered index for watermark queries
    CREATE INDEX IX_bronze_stage_sage_sales_orders_watermark
    ON bronze.stage_sage_sales_orders (LastModified)
    INCLUDE (OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus);
END
GO

-- ============================================================================
-- Sage Invoices staging
-- ============================================================================
IF OBJECT_ID('bronze.stage_sage_invoices', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_sage_invoices (
        InvoiceID NVARCHAR(50) NOT NULL,
        OrderID NVARCHAR(50) NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        InvoiceDate DATETIME2 NOT NULL,
        TotalAmount DECIMAL(18,2) NULL,
        PaidAmount DECIMAL(18,2) DEFAULT 0,
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'sage_erp',
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_bronze_stage_sage_invoices PRIMARY KEY (InvoiceID)
    );

    CREATE INDEX IX_bronze_stage_sage_invoices_watermark
    ON bronze.stage_sage_invoices (LastModified)
    INCLUDE (InvoiceID, OrderID, CustomerID, InvoiceDate, TotalAmount, PaidAmount);
END
GO

-- ============================================================================
-- Sage Shipments staging
-- ============================================================================
IF OBJECT_ID('bronze.stage_sage_shipments', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_sage_shipments (
        ShipmentID NVARCHAR(50) NOT NULL,
        OrderID NVARCHAR(50) NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        ShipDate DATETIME2 NOT NULL,
        Carrier NVARCHAR(100) NULL,
        TrackingNumber NVARCHAR(100) NULL,
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'sage_erp',
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_bronze_stage_sage_shipments PRIMARY KEY (ShipmentID)
    );

    CREATE INDEX IX_bronze_stage_sage_shipments_watermark
    ON bronze.stage_sage_shipments (LastModified)
    INCLUDE (ShipmentID, OrderID, CustomerID, ShipDate, Carrier);
END
GO

-- ============================================================================
-- SAP Sales Orders staging
-- ============================================================================
IF OBJECT_ID('bronze.stage_sap_sales_orders', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_sap_sales_orders (
        OrderID NVARCHAR(50) NOT NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        OrderDate DATETIME2 NOT NULL,
        TotalAmount DECIMAL(18,2) NULL,
        POReference NVARCHAR(50) NULL,
        OrderStatus NVARCHAR(50) NULL,
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'sap_erp',
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_bronze_stage_sap_sales_orders PRIMARY KEY (OrderID)
    );

    CREATE INDEX IX_bronze_stage_sap_sales_orders_watermark
    ON bronze.stage_sap_sales_orders (LastModified)
    INCLUDE (OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus);
END
GO

-- ============================================================================
-- SAP Invoices staging
-- ============================================================================
IF OBJECT_ID('bronze.stage_sap_invoices', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_sap_invoices (
        InvoiceID NVARCHAR(50) NOT NULL,
        OrderID NVARCHAR(50) NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        InvoiceDate DATETIME2 NOT NULL,
        TotalAmount DECIMAL(18,2) NULL,
        PaidAmount DECIMAL(18,2) DEFAULT 0,
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'sap_erp',
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_bronze_stage_sap_invoices PRIMARY KEY (InvoiceID)
    );

    CREATE INDEX IX_bronze_stage_sap_invoices_watermark
    ON bronze.stage_sap_invoices (LastModified)
    INCLUDE (InvoiceID, OrderID, CustomerID, InvoiceDate, TotalAmount, PaidAmount);
END
GO

-- ============================================================================
-- SAP Shipments staging
-- ============================================================================
IF OBJECT_ID('bronze.stage_sap_shipments', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_sap_shipments (
        ShipmentID NVARCHAR(50) NOT NULL,
        OrderID NVARCHAR(50) NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        ShipDate DATETIME2 NOT NULL,
        Carrier NVARCHAR(100) NULL,
        TrackingNumber NVARCHAR(100) NULL,
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'sap_erp',
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_bronze_stage_sap_shipments PRIMARY KEY (ShipmentID)
    );

    CREATE INDEX IX_bronze_stage_sap_shipments_watermark
    ON bronze.stage_sap_shipments (LastModified)
    INCLUDE (ShipmentID, OrderID, CustomerID, ShipDate, Carrier);
END
GO

-- ============================================================================
-- Custom ERP Sales Orders staging
-- ============================================================================
IF OBJECT_ID('bronze.stage_custom_sales_orders', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_custom_sales_orders (
        OrderID NVARCHAR(50) NOT NULL,
        CustomerID NVARCHAR(50) NOT NULL,
        OrderDate DATETIME2 NOT NULL,
        TotalAmount DECIMAL(18,2) NULL,
        OrderStatus NVARCHAR(50) NULL,
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'custom_erp',
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_bronze_stage_custom_sales_orders PRIMARY KEY (OrderID)
    );

    CREATE INDEX IX_bronze_stage_custom_sales_orders_watermark
    ON bronze.stage_custom_sales_orders (LastModified)
    INCLUDE (OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus);
END
GO

-- ============================================================================
-- Custom ERP Inventory staging
-- ============================================================================
IF OBJECT_ID('bronze.stage_custom_inventory', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.stage_custom_inventory (
        SnapshotID NVARCHAR(50) NOT NULL,
        ProductID NVARCHAR(50) NOT NULL,
        WarehouseID NVARCHAR(50) NOT NULL,
        Quantity DECIMAL(18,2) NOT NULL,
        LastModified DATETIME2 NOT NULL,
        SourceSystem NVARCHAR(50) DEFAULT 'custom_erp',
        BatchID UNIQUEIDENTIFIER DEFAULT NEWID(),
        InsertedAt DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_bronze_stage_custom_inventory PRIMARY KEY (SnapshotID, ProductID, WarehouseID)
    );

    CREATE INDEX IX_bronze_stage_custom_inventory_watermark
    ON bronze.stage_custom_inventory (LastModified)
    INCLUDE (SnapshotID, ProductID, WarehouseID, Quantity);
END
GO

PRINT 'Bronze layer staging tables created successfully.';
GO