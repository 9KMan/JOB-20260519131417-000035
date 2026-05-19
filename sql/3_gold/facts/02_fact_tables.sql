-- ============================================================================
-- GOLD LAYER - Fact Tables
-- Transactional fact tables with foreign keys to dimensions
-- ============================================================================

-- ============================================================================
-- FactSalesOrder - Order-to-cash fact table
-- One row per sales order line item
-- ============================================================================
IF OBJECT_ID('gold.FactSalesOrder', 'U') IS NULL
BEGIN
    CREATE TABLE gold.FactSalesOrder (
        FactSalesOrderKey BIGINT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_fact_sales_order),
        -- Dimension foreign keys
        OrderDateKey INT NOT NULL,
        CustomerKey INT NOT NULL,
        ProductKey INT NOT NULL,
        LocationKey INT NOT NULL,
        -- Degenerate dimensions
        OrderID NVARCHAR(50) NOT NULL,
        SourceSystem NVARCHAR(50) NOT NULL,
        -- Measures
        TotalAmount DECIMAL(18,2) NULL,
        Quantity DECIMAL(18,2) NULL,
        UnitPrice DECIMAL(18,2) NULL,
        DiscountAmount DECIMAL(18,2) DEFAULT 0,
        -- Order status (degenerate)
        OrderStatus NVARCHAR(50) NULL,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_FactSalesOrder PRIMARY KEY CLUSTERED (FactSalesOrderKey),
        CONSTRAINT FK_FactSalesOrder_DimDate
            FOREIGN KEY (OrderDateKey) REFERENCES gold.DimDate (DateKey),
        CONSTRAINT FK_FactSalesOrder_DimCustomer
            FOREIGN KEY (CustomerKey) REFERENCES gold.DimCustomer (CustomerKey),
        CONSTRAINT FK_FactSalesOrder_DimProduct
            FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
        CONSTRAINT FK_FactSalesOrder_DimLocation
            FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey)
    );

    -- Indexes for common query patterns
    CREATE INDEX IX_FactSalesOrder_Date ON gold.FactSalesOrder (OrderDateKey);
    CREATE INDEX IX_FactSalesOrder_Customer ON gold.FactSalesOrder (CustomerKey);
    CREATE INDEX IX_FactSalesOrder_Product ON gold.FactSalesOrder (ProductKey);
    CREATE INDEX IX_FactSalesOrder_Location ON gold.FactSalesOrder (LocationKey);
    -- Index for order lookups
    CREATE INDEX IX_FactSalesOrder_OrderID ON gold.FactSalesOrder (OrderID, SourceSystem);
END
GO

-- ============================================================================
-- FactInventory - Inventory snapshot fact table
-- One row per inventory snapshot per warehouse
-- ============================================================================
IF OBJECT_ID('gold.FactInventory', 'U') IS NULL
BEGIN
    CREATE TABLE gold.FactInventory (
        FactInventoryKey BIGINT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_fact_inventory),
        -- Dimension foreign keys
        SnapshotDateKey INT NOT NULL,
        ProductKey INT NOT NULL,
        LocationKey INT NOT NULL,
        -- Degenerate dimensions
        SnapshotID NVARCHAR(50) NOT NULL,
        SourceSystem NVARCHAR(50) NOT NULL,
        -- Measures
        QuantityOnHand DECIMAL(18,2) NOT NULL,
        QuantityReserved DECIMAL(18,2) DEFAULT 0,
        QuantityAvailable AS (ISNULL(QuantityOnHand,0) - ISNULL(QuantityReserved,0)) PERSISTED,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_FactInventory PRIMARY KEY CLUSTERED (FactInventoryKey),
        CONSTRAINT FK_FactInventory_DimDate
            FOREIGN KEY (SnapshotDateKey) REFERENCES gold.DimDate (DateKey),
        CONSTRAINT FK_FactInventory_DimProduct
            FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
        CONSTRAINT FK_FactInventory_DimLocation
            FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey)
    );

    CREATE INDEX IX_FactInventory_Date ON gold.FactInventory (SnapshotDateKey);
    CREATE INDEX IX_FactInventory_Product ON gold.FactInventory (ProductKey);
    CREATE INDEX IX_FactInventory_Location ON gold.FactInventory (LocationKey);
    CREATE INDEX IX_FactInventory_SnapshotID ON gold.FactInventory (SnapshotID, SourceSystem);
END
GO

-- ============================================================================
-- FactProcurement - Purchase order lifecycle fact table
-- One row per PO line item
-- ============================================================================
IF OBJECT_ID('gold.FactProcurement', 'U') IS NULL
BEGIN
    CREATE TABLE gold.FactProcurement (
        FactProcurementKey BIGINT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_fact_procurement),
        -- Dimension foreign keys
        PODateKey INT NOT NULL,
        VendorKey INT NOT NULL,
        ProductKey INT NOT NULL,
        LocationKey INT NOT NULL,
        -- Degenerate dimensions
        PONumber NVARCHAR(50) NOT NULL,
        SourceSystem NVARCHAR(50) NOT NULL,
        -- Measures
        TotalAmount DECIMAL(18,2) NULL,
        Quantity DECIMAL(18,2) NULL,
        UnitCost DECIMAL(18,2) NULL,
        -- PO Status (degenerate)
        POStatus NVARCHAR(50) NULL,
        ExpectedDeliveryDate DATE NULL,
        ActualDeliveryDate DATE NULL,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_FactProcurement PRIMARY KEY CLUSTERED (FactProcurementKey),
        CONSTRAINT FK_FactProcurement_DimDate
            FOREIGN KEY (PODateKey) REFERENCES gold.DimDate (DateKey),
        CONSTRAINT FK_FactProcurement_DimVendor
            FOREIGN KEY (VendorKey) REFERENCES gold.DimVendor (VendorKey),
        CONSTRAINT FK_FactProcurement_DimProduct
            FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
        CONSTRAINT FK_FactProcurement_DimLocation
            FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey)
    );

    CREATE INDEX IX_FactProcurement_Date ON gold.FactProcurement (PODateKey);
    CREATE INDEX IX_FactProcurement_Vendor ON gold.FactProcurement (VendorKey);
    CREATE INDEX IX_FactProcurement_Product ON gold.FactProcurement (ProductKey);
    CREATE INDEX IX_FactProcurement_PONumber ON gold.FactProcurement (PONumber, SourceSystem);
END
GO

-- ============================================================================
-- FactShipment - Fulfillment fact table
-- One row per shipment line
-- ============================================================================
IF OBJECT_ID('gold.FactShipment', 'U') IS NULL
BEGIN
    CREATE TABLE gold.FactShipment (
        FactShipmentKey BIGINT NOT NULL DEFAULT (NEXT VALUE FOR gold.seq_fact_shipment),
        -- Dimension foreign keys
        ShipDateKey INT NOT NULL,
        CustomerKey INT NOT NULL,
        ProductKey INT NOT NULL,
        LocationKey INT NOT NULL,
        -- Degenerate dimensions
        ShipmentID NVARCHAR(50) NOT NULL,
        OrderID NVARCHAR(50) NULL,
        SourceSystem NVARCHAR(50) NOT NULL,
        -- Measures
        QuantityShipped DECIMAL(18,2) NULL,
        ShipWeight DECIMAL(18,2) NULL,
        -- Shipping details (degenerate)
        Carrier NVARCHAR(100) NULL,
        TrackingNumber NVARCHAR(100) NULL,
        ShipmentStatus NVARCHAR(50) NULL,
        -- Row metadata
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_FactShipment PRIMARY KEY CLUSTERED (FactShipmentKey),
        CONSTRAINT FK_FactShipment_DimDate
            FOREIGN KEY (ShipDateKey) REFERENCES gold.DimDate (DateKey),
        CONSTRAINT FK_FactShipment_DimCustomer
            FOREIGN KEY (CustomerKey) REFERENCES gold.DimCustomer (CustomerKey),
        CONSTRAINT FK_FactShipment_DimProduct
            FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
        CONSTRAINT FK_FactShipment_DimLocation
            FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey)
    );

    CREATE INDEX IX_FactShipment_Date ON gold.FactShipment (ShipDateKey);
    CREATE INDEX IX_FactShipment_Customer ON gold.FactShipment (CustomerKey);
    CREATE INDEX IX_FactShipment_Product ON gold.FactShipment (ProductKey);
    CREATE INDEX IX_FactShipment_ShipmentID ON gold.FactShipment (ShipmentID, SourceSystem);
    CREATE INDEX IX_FactShipment_OrderID ON gold.FactShipment (OrderID) WHERE OrderID IS NOT NULL;
END
GO

PRINT 'Gold fact tables created successfully.';
GO