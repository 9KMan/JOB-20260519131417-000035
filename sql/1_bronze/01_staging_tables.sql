-- ============================================================================
-- Bronze Layer Staging Tables with Watermark-based CDC
-- ============================================================================
-- These tables capture raw data from source ERP systems with CDC metadata
-- for incremental loading based on watermark columns.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- Stage Sage Sales Orders
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS stage;
GO

CREATE TABLE stage.stage_sage_sales_orders (
    -- Primary Key
    stage_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    
    -- Source System Identification
    source_system NVARCHAR(50) NOT NULL DEFAULT 'sage',
    load_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    
    -- CDC Watermark Columns
    last_modified DATETIME2 NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    
    -- Natural Key for Deduplication
    natural_key NVARCHAR(255) NULL,
    
    -- Raw JSON Payload for Audit/Replay
    raw_payload NVARCHAR(MAX) NULL,
    
    -- Source Columns (mapped from Sage sales_orders)
    OrderID NVARCHAR(50) NULL,
    CustomerID NVARCHAR(50) NULL,
    OrderDate DATETIME2 NULL,
    TotalAmount DECIMAL(18,4) NULL,
    Status NVARCHAR(50) NULL,
    ShipDate DATETIME2 NULL,
    WarehouseCode NVARCHAR(50) NULL,
    
    -- Metadata
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    -- Constraints
    CONSTRAINT CK_sage_sales_orders_source CHECK (source_system = 'sage'),
    CONSTRAINT CK_sage_sales_orders_deleted CHECK (is_deleted IN (0, 1))
);
GO

-- Indexes for watermark-based incremental loads
CREATE NONCLUSTERED INDEX IX_stage_sage_sales_orders_watermark 
    ON stage.stage_sage_sales_orders (last_modified ASC, stage_id ASC)
    WHERE last_modified IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_stage_sage_sales_orders_natural_key 
    ON stage.stage_sage_sales_orders (natural_key ASC)
    WHERE natural_key IS NOT NULL;
GO

-- ============================================================================
-- Stage Sage Invoices
-- ============================================================================
CREATE TABLE stage.stage_sage_invoices (
    stage_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL DEFAULT 'sage',
    load_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    last_modified DATETIME2 NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    natural_key NVARCHAR(255) NULL,
    raw_payload NVARCHAR(MAX) NULL,
    
    -- Source Columns (mapped from Sage invoices)
    InvoiceID NVARCHAR(50) NULL,
    OrderID NVARCHAR(50) NULL,
    InvoiceDate DATETIME2 NULL,
    InvoiceAmount DECIMAL(18,4) NULL,
    TaxAmount DECIMAL(18,4) NULL,
    PaidAmount DECIMAL(18,4) NULL,
    PaymentDate DATETIME2 NULL,
    
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_sage_invoices_source CHECK (source_system = 'sage'),
    CONSTRAINT CK_sage_invoices_deleted CHECK (is_deleted IN (0, 1))
);
GO

CREATE NONCLUSTERED INDEX IX_stage_sage_invoices_watermark 
    ON stage.stage_sage_invoices (last_modified ASC, stage_id ASC)
    WHERE last_modified IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_stage_sage_invoices_natural_key 
    ON stage.stage_sage_invoices (natural_key ASC)
    WHERE natural_key IS NOT NULL;
GO

-- ============================================================================
-- Stage SAP Sales Orders
-- ============================================================================
CREATE TABLE stage.stage_sap_sales_orders (
    stage_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL DEFAULT 'sap',
    load_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    last_modified DATETIME2 NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    natural_key NVARCHAR(255) NULL,
    raw_payload NVARCHAR(MAX) NULL,
    
    -- Source Columns (mapped from SAP VBAK)
    VBELN NVARCHAR(50) NULL,           -- Sales Document Number
    KUNNR NVARCHAR(50) NULL,           -- Customer Number
    AUDAT DATETIME2 NULL,              -- Document Date
    NETWR DECIMAL(18,4) NULL,          -- Net Value
    WKURS VARCHAR(10) NULL,            -- Exchange Rate
    WAERS NVARCHAR(5) NULL,             -- Currency Key
    BSTNK NVARCHAR(50) NULL,           -- Customer Purchase Order
    STATU NVARCHAR(50) NULL,           -- Status
    
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_sap_sales_orders_source CHECK (source_system = 'sap'),
    CONSTRAINT CK_sap_sales_orders_deleted CHECK (is_deleted IN (0, 1))
);
GO

CREATE NONCLUSTERED INDEX IX_stage_sap_sales_orders_watermark 
    ON stage.stage_sap_sales_orders (last_modified ASC, stage_id ASC)
    WHERE last_modified IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_stage_sap_sales_orders_vbeln 
    ON stage.stage_sap_sales_orders (VBELN ASC)
    WHERE VBELN IS NOT NULL;
GO

-- ============================================================================
-- Stage SAP Invoices
-- ============================================================================
CREATE TABLE stage.stage_sap_invoices (
    stage_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL DEFAULT 'sap',
    load_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    last_modified DATETIME2 NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    natural_key NVARCHAR(255) NULL,
    raw_payload NVARCHAR(MAX) NULL,
    
    -- Source Columns (mapped from SAP VBRK)
    INVNUM NVARCHAR(50) NULL,          -- Invoice Number
    VBELN NVARCHAR(50) NULL,           -- Reference SD Document
    FKDAT DATETIME2 NULL,              -- Invoice Date
    NETWR DECIMAL(18,4) NULL,          -- Net Value
    MWSBK DECIMAL(18,4) NULL,          -- Tax Amount
    KUNRG NVARCHAR(50) NULL,           -- Sold-to Party
    WAERS NVARCHAR(5) NULL,            -- Currency
    
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_sap_invoices_source CHECK (source_system = 'sap'),
    CONSTRAINT CK_sap_invoices_deleted CHECK (is_deleted IN (0, 1))
);
GO

CREATE NONCLUSTERED INDEX IX_stage_sap_invoices_watermark 
    ON stage.stage_sap_invoices (last_modified ASC, stage_id ASC)
    WHERE last_modified IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_stage_sap_invoices_invnum 
    ON stage.stage_sap_invoices (INVNUM ASC)
    WHERE INVNUM IS NOT NULL;
GO

-- ============================================================================
-- Stage Custom Inventory
-- ============================================================================
CREATE TABLE stage.stage_custom_inventory (
    stage_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL DEFAULT 'custom',
    load_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    last_modified DATETIME2 NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    natural_key NVARCHAR(255) NULL,
    raw_payload NVARCHAR(MAX) NULL,
    
    -- Source Columns
    inventory_id NVARCHAR(50) NULL,
    product_sku NVARCHAR(50) NULL,
    warehouse_code NVARCHAR(50) NULL,
    quantity_on_hand DECIMAL(18,4) NULL,
    quantity_reserved DECIMAL(18,4) NULL,
    quantity_available DECIMAL(18,4) NULL,
    unit_cost DECIMAL(18,4) NULL,
    last_updated DATETIME2 NULL,
    
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_custom_inventory_source CHECK (source_system = 'custom'),
    CONSTRAINT CK_custom_inventory_deleted CHECK (is_deleted IN (0, 1)),
    CONSTRAINT CK_custom_inventory_qty CHECK (quantity_on_hand >= 0 AND quantity_reserved >= 0 AND quantity_available >= 0)
);
GO

CREATE NONCLUSTERED INDEX IX_stage_custom_inventory_watermark 
    ON stage.stage_custom_inventory (last_modified ASC, stage_id ASC)
    WHERE last_modified IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_stage_custom_inventory_sku 
    ON stage.stage_custom_inventory (product_sku ASC, warehouse_code ASC)
    WHERE product_sku IS NOT NULL;
GO

PRINT 'Bronze staging tables created successfully.';
GO