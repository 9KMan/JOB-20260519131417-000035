-- ============================================================================
-- Gold Layer Fact Tables
-- ============================================================================
-- Transactional fact tables with foreign keys to dimensions.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- FactSalesOrder
-- ============================================================================
CREATE TABLE gold.FactSalesOrder (
    SalesOrderKey BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    DateKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    LocationKey INT NULL,
    OrderNumber NVARCHAR(50) NOT NULL,
    OrderLineNumber INT NULL,
    OrderDate DATE NOT NULL,
    QuantityOrdered DECIMAL(18,4) NULL,
    UnitPrice DECIMAL(18,4) NULL,
    TotalAmount DECIMAL(18,4) NULL,
    DiscountAmount DECIMAL(18,4) NULL,
    TaxAmount DECIMAL(18,4) NULL,
    CurrencyKey INT NULL,
    Loading NVARCHAR(50) NULL,
    
    -- Foreign Keys
    CONSTRAINT FK_FactSalesOrder_DimDate FOREIGN KEY (DateKey) REFERENCES gold.DimDate (DateKey),
    CONSTRAINT FK_FactSalesOrder_DimCustomer FOREIGN KEY (CustomerKey) REFERENCES gold.DimCustomer (CustomerKey),
    CONSTRAINT FK_FactSalesOrder_DimProduct FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
    CONSTRAINT FK_FactSalesOrder_DimLocation FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey),
    CONSTRAINT FK_FactSalesOrder_DimCurrency FOREIGN KEY (CurrencyKey) REFERENCES gold.DimCurrency (CurrencyKey),
    
    -- Constraints
    CONSTRAINT CK_FactSalesOrder_qty CHECK (QuantityOrdered >= 0),
    CONSTRAINT CK_FactSalesOrder_price CHECK (UnitPrice >= 0),
    CONSTRAINT CK_FactSalesOrder_amount CHECK (TotalAmount >= 0)
);
GO

CREATE NONCLUSTERED INDEX IX_FactSalesOrder_OrderNumber ON gold.FactSalesOrder (OrderNumber ASC);
CREATE NONCLUSTERED INDEX IX_FactSalesOrder_OrderDate ON gold.FactSalesOrder (OrderDate ASC);
CREATE NONCLUSTERED INDEX IX_FactSalesOrder_CustomerKey ON gold.FactSalesOrder (CustomerKey ASC);
CREATE NONCLUSTERED INDEX IX_FactSalesOrder_ProductKey ON gold.FactSalesOrder (ProductKey ASC);
CREATE NONCLUSTERED INDEX IX_FactSalesOrder_DateKey ON gold.FactSalesOrder (DateKey ASC);
GO

-- ============================================================================
-- FactInventory
-- ============================================================================
CREATE TABLE gold.FactInventory (
    InventoryKey BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    DateKey INT NOT NULL,
    ProductKey INT NOT NULL,
    LocationKey INT NOT NULL,
    QuantityOnHand DECIMAL(18,4) NULL,
    QuantityReserved DECIMAL(18,4) NULL,
    QuantityAvailable DECIMAL(18,4) NULL,
    UnitCost DECIMAL(18,4) NULL,
    InventoryValue DECIMAL(18,4) NULL,
    WarehouseID NVARCHAR(50) NULL,
    
    CONSTRAINT FK_FactInventory_DimDate FOREIGN KEY (DateKey) REFERENCES gold.DimDate (DateKey),
    CONSTRAINT FK_FactInventory_DimProduct FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
    CONSTRAINT FK_FactInventory_DimLocation FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey),
    
    CONSTRAINT CK_FactInventory_qty_on_hand CHECK (QuantityOnHand >= 0),
    CONSTRAINT CK_FactInventory_qty_reserved CHECK (QuantityReserved >= 0),
    CONSTRAINT CK_FactInventory_qty_available CHECK (QuantityAvailable >= 0)
);
GO

CREATE NONCLUSTERED INDEX IX_FactInventory_DateKey ON gold.FactInventory (DateKey ASC);
CREATE NONCLUSTERED INDEX IX_FactInventory_ProductKey ON gold.FactInventory (ProductKey ASC);
CREATE NONCLUSTERED INDEX IX_FactInventory_LocationKey ON gold.FactInventory (LocationKey ASC);
CREATE NONCLUSTERED INDEX IX_FactInventory_WarehouseID ON gold.FactInventory (WarehouseID ASC);
GO

-- ============================================================================
-- FactProcurement
-- ============================================================================
CREATE TABLE gold.FactProcurement (
    ProcurementKey BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    DateKey INT NOT NULL,
    VendorKey INT NOT NULL,
    ProductKey INT NOT NULL,
    PONumber NVARCHAR(50) NOT NULL,
    POLineNumber INT NULL,
    PODate DATE NOT NULL,
    QuantityOrdered DECIMAL(18,4) NULL,
    QuantityReceived DECIMAL(18,4) NULL,
    UnitCost DECIMAL(18,4) NULL,
    TotalAmount DECIMAL(18,4) NULL,
    CurrencyKey INT NULL,
    Status NVARCHAR(50) NULL,
    
    CONSTRAINT FK_FactProcurement_DimDate FOREIGN KEY (DateKey) REFERENCES gold.DimDate (DateKey),
    CONSTRAINT FK_FactProcurement_DimVendor FOREIGN KEY (VendorKey) REFERENCES gold.DimVendor (VendorKey),
    CONSTRAINT FK_FactProcurement_DimProduct FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
    CONSTRAINT FK_FactProcurement_DimCurrency FOREIGN KEY (CurrencyKey) REFERENCES gold.DimCurrency (CurrencyKey),
    
    CONSTRAINT CK_FactProcurement_qty_ordered CHECK (QuantityOrdered >= 0),
    CONSTRAINT CK_FactProcurement_qty_received CHECK (QuantityReceived >= 0)
);
GO

CREATE NONCLUSTERED INDEX IX_FactProcurement_PONumber ON gold.FactProcurement (PONumber ASC);
CREATE NONCLUSTERED INDEX IX_FactProcurement_PODate ON gold.FactProcurement (PODate ASC);
CREATE NONCLUSTERED INDEX IX_FactProcurement_VendorKey ON gold.FactProcurement (VendorKey ASC);
CREATE NONCLUSTERED INDEX IX_FactProcurement_Status ON gold.FactProcurement (Status ASC);
GO

-- ============================================================================
-- FactShipment
-- ============================================================================
CREATE TABLE gold.FactShipment (
    ShipmentKey BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    DateKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    LocationKey INT NOT NULL,
    ShipmentNumber NVARCHAR(50) NOT NULL,
    ShipmentLineNumber INT NULL,
    ShipDate DATE NOT NULL,
    QuantityShipped DECIMAL(18,4) NULL,
    UnitPrice DECIMAL(18,4) NULL,
    TotalAmount DECIMAL(18,4) NULL,
    Carrier NVARCHAR(100) NULL,
    TrackingNumber NVARCHAR(100) NULL,
    CurrencyKey INT NULL,
    
    CONSTRAINT FK_FactShipment_DimDate FOREIGN KEY (DateKey) REFERENCES gold.DimDate (DateKey),
    CONSTRAINT FK_FactShipment_DimCustomer FOREIGN KEY (CustomerKey) REFERENCES gold.DimCustomer (CustomerKey),
    CONSTRAINT FK_FactShipment_DimProduct FOREIGN KEY (ProductKey) REFERENCES gold.DimProduct (ProductKey),
    CONSTRAINT FK_FactShipment_DimLocation FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey),
    CONSTRAINT FK_FactShipment_DimCurrency FOREIGN KEY (CurrencyKey) REFERENCES gold.DimCurrency (CurrencyKey),
    
    CONSTRAINT CK_FactShipment_qty CHECK (QuantityShipped >= 0)
);
GO

CREATE NONCLUSTERED INDEX IX_FactShipment_ShipmentNumber ON gold.FactShipment (ShipmentNumber ASC);
CREATE NONCLUSTERED INDEX IX_FactShipment_ShipDate ON gold.FactShipment (ShipDate ASC);
CREATE NONCLUSTERED INDEX IX_FactShipment_CustomerKey ON gold.FactShipment (CustomerKey ASC);
CREATE NONCLUSTERED INDEX IX_FactShipment_TrackingNumber ON gold.FactShipment (TrackingNumber ASC);
GO

PRINT 'Gold fact tables created successfully.';
GO