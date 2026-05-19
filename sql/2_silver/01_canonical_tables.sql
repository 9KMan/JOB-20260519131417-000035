-- ============================================================================
-- Silver Layer Canonical Schemas
-- ============================================================================
-- Canonical tables that normalize data from multiple ERP sources into a
-- single unified schema with data quality tracking.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- Silver Schema
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS silver;
GO

-- ============================================================================
-- silver_sales_order
-- ============================================================================
CREATE TABLE silver.silver_sales_order (
    -- Primary Key
    canonical_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    
    -- Source System Identification
    source_system NVARCHAR(50) NOT NULL,
    source_id NVARCHAR(255) NOT NULL,
    natural_key NVARCHAR(255) NOT NULL,
    
    -- Data Quality
    data_quality_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    
    -- Temporal Tracking (SCD Type 2)
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    is_current BIT NOT NULL DEFAULT 1,
    
    -- Business Keys
    order_number NVARCHAR(50) NULL,
    customer_natural_key NVARCHAR(255) NULL,
    order_date DATE NULL,
    promised_date DATE NULL,
    ship_date DATE NULL,
    
    -- Financial
    total_amount DECIMAL(18,4) NULL,
    discount_amount DECIMAL(18,4) NULL,
    tax_amount DECIMAL(18,4) NULL,
    
    -- Status
    order_status NVARCHAR(50) NULL,
    source_status NVARCHAR(50) NULL,
    
    -- Location
    warehouse_code NVARCHAR(50) NULL,
    ship_to_address NVARCHAR(500) NULL,
    ship_to_city NVARCHAR(100) NULL,
    ship_to_postal_code NVARCHAR(20) NULL,
    ship_to_country NVARCHAR(100) NULL,
    
    -- Metadata
    load_id UNIQUEIDENTIFIER NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    -- Constraints
    CONSTRAINT CK_silver_sales_order_source CHECK (source_system IN ('sage', 'sap', 'custom')),
    CONSTRAINT CK_silver_sales_order_quality CHECK (data_quality_score >= 0 AND data_quality_score <= 100),
    CONSTRAINT CK_silver_sales_order_current CHECK (is_current IN (0, 1)),
    CONSTRAINT UQ_silver_sales_order_natural_key UNIQUE (natural_key, is_current)
);
GO

-- Indexes
CREATE NONCLUSTERED INDEX IX_silver_sales_order_natural_key ON silver.silver_sales_order (natural_key ASC) WHERE is_current = 1;
CREATE NONCLUSTERED INDEX IX_silver_sales_order_order_date ON silver.silver_sales_order (order_date ASC);
CREATE NONCLUSTERED INDEX IX_silver_sales_order_customer ON silver.silver_sales_order (customer_natural_key ASC);
CREATE NONCLUSTERED INDEX IX_silver_sales_order_source ON silver.silver_sales_order (source_system ASC, source_id ASC);
GO

-- ============================================================================
-- silver_invoice
-- ============================================================================
CREATE TABLE silver.silver_invoice (
    canonical_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL,
    source_id NVARCHAR(255) NOT NULL,
    natural_key NVARCHAR(255) NOT NULL,
    data_quality_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    is_current BIT NOT NULL DEFAULT 1,
    
    -- Business Keys
    invoice_number NVARCHAR(50) NULL,
    order_natural_key NVARCHAR(255) NULL,
    invoice_date DATE NULL,
    due_date DATE NULL,
    
    -- Financial
    invoice_amount DECIMAL(18,4) NULL,
    tax_amount DECIMAL(18,4) NULL,
    paid_amount DECIMAL(18,4) NULL,
    outstanding_amount DECIMAL(18,4) NULL,
    
    -- Status
    payment_status NVARCHAR(50) NULL,
    source_status NVARCHAR(50) NULL,
    
    -- Currency
    currency_code NVARCHAR(10) NULL,
    exchange_rate DECIMAL(18,8) NULL,
    
    -- Customer
    customer_natural_key NVARCHAR(255) NULL,
    customer_name NVARCHAR(255) NULL,
    
    -- Metadata
    load_id UNIQUEIDENTIFIER NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_silver_invoice_source CHECK (source_system IN ('sage', 'sap', 'custom')),
    CONSTRAINT CK_silver_invoice_quality CHECK (data_quality_score >= 0 AND data_quality_score <= 100),
    CONSTRAINT UQ_silver_invoice_natural_key UNIQUE (natural_key, is_current)
);
GO

CREATE NONCLUSTERED INDEX IX_silver_invoice_natural_key ON silver.silver_invoice (natural_key ASC) WHERE is_current = 1;
CREATE NONCLUSTERED INDEX IX_silver_invoice_order_ref ON silver.silver_invoice (order_natural_key ASC);
CREATE NONCLUSTERED INDEX IX_silver_invoice_invoice_date ON silver.silver_invoice (invoice_date ASC);
GO

-- ============================================================================
-- silver_shipment
-- ============================================================================
CREATE TABLE silver.silver_shipment (
    canonical_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL,
    source_id NVARCHAR(255) NOT NULL,
    natural_key NVARCHAR(255) NOT NULL,
    data_quality_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    is_current BIT NOT NULL DEFAULT 1,
    
    shipment_number NVARCHAR(50) NULL,
    order_natural_key NVARCHAR(255) NULL,
    ship_date DATE NULL,
    
    quantity_shipped DECIMAL(18,4) NULL,
    carrier NVARCHAR(100) NULL,
    tracking_number NVARCHAR(100) NULL,
    
    ship_to_name NVARCHAR(255) NULL,
    ship_to_address NVARCHAR(500) NULL,
    ship_to_city NVARCHAR(100) NULL,
    ship_to_postal_code NVARCHAR(20) NULL,
    
    load_id UNIQUEIDENTIFIER NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_silver_shipment_source CHECK (source_system IN ('sage', 'sap', 'custom')),
    CONSTRAINT CK_silver_shipment_quality CHECK (data_quality_score >= 0 AND data_quality_score <= 100),
    CONSTRAINT UQ_silver_shipment_natural_key UNIQUE (natural_key, is_current)
);
GO

CREATE NONCLUSTERED INDEX IX_silver_shipment_natural_key ON silver.silver_shipment (natural_key ASC) WHERE is_current = 1;
CREATE NONCLUSTERED INDEX IX_silver_shipment_ship_date ON silver.silver_shipment (ship_date ASC);
GO

-- ============================================================================
-- silver_customer
-- ============================================================================
CREATE TABLE silver.silver_customer (
    canonical_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL,
    source_id NVARCHAR(255) NOT NULL,
    natural_key NVARCHAR(255) NOT NULL,
    data_quality_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    is_current BIT NOT NULL DEFAULT 1,
    version_number INT NOT NULL DEFAULT 1,
    
    -- Customer Info
    customer_name NVARCHAR(255) NULL,
    customer_type NVARCHAR(50) NULL,
    region NVARCHAR(100) NULL,
    segment NVARCHAR(100) NULL,
    
    -- Address (SCD Type 2)
    customer_address NVARCHAR(500) NULL,
    customer_city NVARCHAR(100) NULL,
    customer_state NVARCHAR(100) NULL,
    customer_postal_code NVARCHAR(20) NULL,
    customer_country NVARCHAR(100) NULL,
    
    -- Contact
    phone_number NVARCHAR(50) NULL,
    email_address NVARCHAR(255) NULL,
    
    load_id UNIQUEIDENTIFIER NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_silver_customer_source CHECK (source_system IN ('sage', 'sap', 'custom')),
    CONSTRAINT CK_silver_customer_quality CHECK (data_quality_score >= 0 AND data_quality_score <= 100),
    CONSTRAINT UQ_silver_customer_natural_key UNIQUE (natural_key, is_current)
);
GO

CREATE NONCLUSTERED INDEX IX_silver_customer_natural_key ON silver.silver_customer (natural_key ASC) WHERE is_current = 1;
CREATE NONCLUSTERED INDEX IX_silver_customer_region ON silver.silver_customer (region ASC);
CREATE NONCLUSTERED INDEX IX_silver_customer_segment ON silver.silver_customer (segment ASC);
GO

-- ============================================================================
-- silver_product
-- ============================================================================
CREATE TABLE silver.silver_product (
    canonical_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL,
    source_id NVARCHAR(255) NOT NULL,
    natural_key NVARCHAR(255) NOT NULL,
    data_quality_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    is_current BIT NOT NULL DEFAULT 1,
    version_number INT NOT NULL DEFAULT 1,
    
    product_name NVARCHAR(255) NULL,
    product_code NVARCHAR(50) NULL,
    category NVARCHAR(100) NULL,
    subcategory NVARCHAR(100) NULL,
    unit_of_measure NVARCHAR(50) NULL,
    
    -- Pricing (SCD Type 2)
    standard_cost DECIMAL(18,4) NULL,
    list_price DECIMAL(18,4) NULL,
    
    -- Supplier
    supplier_id NVARCHAR(50) NULL,
    supplier_name NVARCHAR(255) NULL,
    
    -- Inventory
    reorder_point DECIMAL(18,4) NULL,
    minimum_stock DECIMAL(18,4) NULL,
    
    load_id UNIQUEIDENTIFIER NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_silver_product_source CHECK (source_system IN ('sage', 'sap', 'custom')),
    CONSTRAINT CK_silver_product_quality CHECK (data_quality_score >= 0 AND data_quality_score <= 100),
    CONSTRAINT UQ_silver_product_natural_key UNIQUE (natural_key, is_current)
);
GO

CREATE NONCLUSTERED INDEX IX_silver_product_natural_key ON silver.silver_product (natural_key ASC) WHERE is_current = 1;
CREATE NONCLUSTERED INDEX IX_silver_product_category ON silver.silver_product (category ASC);
GO

-- ============================================================================
-- silver_vendor
-- ============================================================================
CREATE TABLE silver.silver_vendor (
    canonical_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL,
    source_id NVARCHAR(255) NOT NULL,
    natural_key NVARCHAR(255) NOT NULL,
    data_quality_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    is_current BIT NOT NULL DEFAULT 1,
    version_number INT NOT NULL DEFAULT 1,
    
    vendor_name NVARCHAR(255) NULL,
    vendor_type NVARCHAR(50) NULL,
    category NVARCHAR(100) NULL,
    payment_terms NVARCHAR(100) NULL,
    
    contact_name NVARCHAR(255) NULL,
    contact_phone NVARCHAR(50) NULL,
    contact_email NVARCHAR(255) NULL,
    
    load_id UNIQUEIDENTIFIER NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_silver_vendor_source CHECK (source_system IN ('sage', 'sap', 'custom')),
    CONSTRAINT CK_silver_vendor_quality CHECK (data_quality_score >= 0 AND data_quality_score <= 100),
    CONSTRAINT UQ_silver_vendor_natural_key UNIQUE (natural_key, is_current)
);
GO

CREATE NONCLUSTERED INDEX IX_silver_vendor_natural_key ON silver.silver_vendor (natural_key ASC) WHERE is_current = 1;
GO

-- ============================================================================
-- silver_location
-- ============================================================================
CREATE TABLE silver.silver_location (
    canonical_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL,
    source_id NVARCHAR(255) NOT NULL,
    natural_key NVARCHAR(255) NOT NULL,
    data_quality_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    is_current BIT NOT NULL DEFAULT 1,
    version_number INT NOT NULL DEFAULT 1,
    
    location_name NVARCHAR(255) NULL,
    warehouse_id NVARCHAR(50) NULL,
    location_type NVARCHAR(50) NULL,
    
    address NVARCHAR(500) NULL,
    city NVARCHAR(100) NULL,
    state_province NVARCHAR(100) NULL,
    postal_code NVARCHAR(20) NULL,
    country NVARCHAR(100) NULL,
    region NVARCHAR(100) NULL,
    
    load_id UNIQUEIDENTIFIER NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    modified_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_silver_location_source CHECK (source_system IN ('sage', 'sap', 'custom')),
    CONSTRAINT CK_silver_location_quality CHECK (data_quality_score >= 0 AND data_quality_score <= 100),
    CONSTRAINT UQ_silver_location_natural_key UNIQUE (natural_key, is_current)
);
GO

CREATE NONCLUSTERED INDEX IX_silver_location_natural_key ON silver.silver_location (natural_key ASC) WHERE is_current = 1;
CREATE NONCLUSTERED INDEX IX_silver_location_region ON silver.silver_location (region ASC);
GO

PRINT 'Silver canonical tables created successfully.';
GO