-- ============================================================================
-- WEB PLATFORM VIEWS
-- Dynamic views consumed by internal web platform for screen rendering
-- Views named vw_{screen}_{workflow} for web platform discovery
-- ============================================================================

-- Schema for views
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'web')
BEGIN
    EXEC('CREATE SCHEMA web');
END
GO

-- ============================================================================
-- vw_sales_orders_list
-- Sales orders list view for web platform
-- ============================================================================
IF OBJECT_ID('web.vw_sales_orders_list', 'V') IS NOT NULL
    DROP VIEW web.vw_sales_orders_list;
GO

CREATE VIEW web.vw_sales_orders_list
AS
SELECT
    so.SourceOrderID AS OrderID,
    so.OrderDate,
    so.CustomerID,
    COALESCE(dc.CustomerName, so.CustomerID) AS CustomerName,
    so.TotalAmount,
    so.OrderStatus,
    so.POReference,
    so.SourceSystem,
    -- Enriched data from dimensions
    dc.Region AS CustomerRegion,
    dc.Segment AS CustomerSegment,
    CASE so.OrderStatus
        WHEN 'Draft' THEN 'badge-secondary'
        WHEN 'Pending' THEN 'badge-warning'
        WHEN 'Approved' THEN 'badge-success'
        WHEN 'Invoiced' THEN 'badge-info'
        WHEN 'Shipped' THEN 'badge-primary'
        WHEN 'Delivered' THEN 'badge-success'
        WHEN 'Cancelled' THEN 'badge-danger'
        ELSE 'badge-secondary'
    END AS StatusBadgeClass
FROM silver.sales_order so
LEFT JOIN gold.DimCustomer dc
    ON dc.NaturalKey = CONCAT(so.SourceSystem, '|', so.CustomerID)
    AND dc.IsCurrent = 1;
GO

-- ============================================================================
-- vw_sales_order_detail
-- Sales order detail view
-- ============================================================================
IF OBJECT_ID('web.vw_sales_order_detail', 'V') IS NOT NULL
    DROP VIEW web.vw_sales_order_detail;
GO

CREATE VIEW web.vw_sales_order_detail
AS
SELECT
    so.SalesOrderKey,
    so.SourceOrderID AS OrderID,
    so.OrderDate,
    so.CustomerID,
    COALESCE(dc.CustomerName, so.CustomerID) AS CustomerName,
    dc.Region AS CustomerRegion,
    dc.Segment AS CustomerSegment,
    so.TotalAmount,
    so.OrderStatus,
    so.POReference,
    so.SourceSystem,
    -- Order lifecycle info
    inv.InvoiceKey,
    shp.ShipmentKey,
    COALESCE(inv.TotalAmount, 0) AS InvoicedAmount,
    COALESCE(shp.ShipmentID, 'Not Shipped') AS LastShipmentID,
    -- Dates
    so.InsertedAt AS CreatedAt,
    so.UpdatedAt AS LastModifiedAt
FROM silver.sales_order so
LEFT JOIN gold.DimCustomer dc
    ON dc.NaturalKey = CONCAT(so.SourceSystem, '|', so.CustomerID)
    AND dc.IsCurrent = 1
LEFT JOIN silver.invoice inv
    ON inv.SourceOrderID = so.SourceOrderID
    AND inv.SourceSystem = so.SourceSystem
LEFT JOIN silver.shipment shp
    ON shp.SourceOrderID = so.SourceOrderID
    AND shp.SourceSystem = so.SourceSystem;
GO

-- ============================================================================
-- vw_invoices_list
-- Invoices list view
-- ============================================================================
IF OBJECT_ID('web.vw_invoices_list', 'V') IS NOT NULL
    DROP VIEW web.vw_invoices_list;
GO

CREATE VIEW web.vw_invoices_list
AS
SELECT
    inv.SourceInvoiceID AS InvoiceID,
    inv.SourceOrderID AS OrderID,
    inv.InvoiceDate,
    inv.CustomerID,
    COALESCE(dc.CustomerName, inv.CustomerID) AS CustomerName,
    inv.TotalAmount,
    inv.PaidAmount,
    inv.BalanceDue,
    CASE
        WHEN inv.BalanceDue = 0 THEN 'badge-success'
        WHEN inv.BalanceDue < inv.TotalAmount * 0.5 THEN 'badge-warning'
        ELSE 'badge-danger'
    END AS PaymentStatusBadge,
    CASE
        WHEN inv.BalanceDue = 0 THEN 'Paid'
        WHEN inv.PaidAmount > 0 THEN 'Partial'
        ELSE 'Unpaid'
    END AS PaymentStatus
FROM silver.invoice inv
LEFT JOIN gold.DimCustomer dc
    ON dc.NaturalKey = CONCAT(inv.SourceSystem, '|', inv.CustomerID)
    AND dc.IsCurrent = 1;
GO

-- ============================================================================
-- vw_invoice_detail
-- Invoice detail view
-- ============================================================================
IF OBJECT_ID('web.vw_invoice_detail', 'V') IS NOT NULL
    DROP VIEW web.vw_invoice_detail;
GO

CREATE VIEW web.vw_invoice_detail
AS
SELECT
    inv.InvoiceKey,
    inv.SourceInvoiceID AS InvoiceID,
    inv.SourceOrderID AS OrderID,
    inv.InvoiceDate,
    inv.CustomerID,
    COALESCE(dc.CustomerName, inv.CustomerID) AS CustomerName,
    dc.Region AS CustomerRegion,
    inv.TotalAmount,
    inv.PaidAmount,
    inv.BalanceDue,
    inv.SourceSystem,
    CASE
        WHEN inv.BalanceDue = 0 THEN 'Paid'
        WHEN inv.PaidAmount > 0 THEN 'Partial'
        ELSE 'Unpaid'
    END AS PaymentStatus,
    inv.InsertedAt AS CreatedAt
FROM silver.invoice inv
LEFT JOIN gold.DimCustomer dc
    ON dc.NaturalKey = CONCAT(inv.SourceSystem, '|', inv.CustomerID)
    AND dc.IsCurrent = 1;
GO

-- ============================================================================
-- vw_shipments_list
-- Shipments list view
-- ============================================================================
IF OBJECT_ID('web.vw_shipments_list', 'V') IS NOT NULL
    DROP VIEW web.vw_shipments_list;
GO

CREATE VIEW web.vw_shipments_list
AS
SELECT
    shp.SourceShipmentID AS ShipmentID,
    shp.SourceOrderID AS OrderID,
    shp.ShipDate,
    shp.CustomerID,
    COALESCE(dc.CustomerName, shp.CustomerID) AS CustomerName,
    shp.Carrier,
    shp.TrackingNumber,
    shp.SourceSystem,
    CASE
        WHEN shp.TrackingNumber IS NOT NULL AND LEN(shp.TrackingNumber) > 5 THEN 'badge-success'
        ELSE 'badge-warning'
    END AS TrackingStatusBadge
FROM silver.shipment shp
LEFT JOIN gold.DimCustomer dc
    ON dc.NaturalKey = CONCAT(shp.SourceSystem, '|', shp.CustomerID)
    AND dc.IsCurrent = 1;
GO

-- ============================================================================
-- vw_shipment_detail
-- Shipment detail view
-- ============================================================================
IF OBJECT_ID('web.vw_shipment_detail', 'V') IS NOT NULL
    DROP VIEW web.vw_shipment_detail;
GO

CREATE VIEW web.vw_shipment_detail
AS
SELECT
    shp.ShipmentKey,
    shp.SourceShipmentID AS ShipmentID,
    shp.SourceOrderID AS OrderID,
    shp.ShipDate,
    shp.CustomerID,
    COALESCE(dc.CustomerName, shp.CustomerID) AS CustomerName,
    dc.Region AS CustomerRegion,
    shp.Carrier,
    shp.TrackingNumber,
    shp.SourceSystem,
    shp.InsertedAt AS CreatedAt
FROM silver.shipment shp
LEFT JOIN gold.DimCustomer dc
    ON dc.NaturalKey = CONCAT(shp.SourceSystem, '|', shp.CustomerID)
    AND dc.IsCurrent = 1;
GO

-- ============================================================================
-- vw_inventory_current
-- Current inventory levels view
-- ============================================================================
IF OBJECT_ID('web.vw_inventory_current', 'V') IS NOT NULL
    DROP VIEW web.vw_inventory_current;
GO

CREATE VIEW web.vw_inventory_current
AS
SELECT
    fi.SnapshotID,
    dp.ProductID,
    dp.ProductName,
    dl.WarehouseID,
    dl.WarehouseName,
    dl.Region AS WarehouseRegion,
    fi.QuantityOnHand,
    fi.QuantityReserved,
    fi.QuantityAvailable,
    fi.SourceSystem,
    dd.FullDate AS LastSnapshotDate,
    CASE
        WHEN fi.QuantityAvailable <= 0 THEN 'badge-danger'
        WHEN fi.QuantityAvailable < 10 THEN 'badge-warning'
        ELSE 'badge-success'
    END AS StockLevelBadge
FROM gold.FactInventory fi
INNER JOIN gold.DimProduct dp ON dp.ProductKey = fi.ProductKey
INNER JOIN gold.DimLocation dl ON dl.LocationKey = fi.LocationKey
INNER JOIN gold.DimDate dd ON dd.DateKey = fi.SnapshotDateKey
WHERE fi.SnapshotDateKey = (SELECT MAX(SnapshotDateKey) FROM gold.FactInventory);
GO

-- ============================================================================
-- vw_inventory_detail
-- Inventory detail view
-- ============================================================================
IF OBJECT_ID('web.vw_inventory_detail', 'V') IS NOT NULL
    DROP VIEW web.vw_inventory_detail;
GO

CREATE VIEW web.vw_inventory_detail
AS
SELECT
    fi.FactInventoryKey,
    fi.SnapshotID,
    dp.ProductKey,
    dp.ProductID,
    dp.ProductName,
    dp.Category,
    dp.Subcategory,
    dl.LocationKey,
    dl.WarehouseID,
    dl.WarehouseName,
    dl.Region,
    dl.Country,
    fi.QuantityOnHand,
    fi.QuantityReserved,
    fi.QuantityAvailable,
    fi.SourceSystem,
    dd.FullDate AS SnapshotDate
FROM gold.FactInventory fi
INNER JOIN gold.DimProduct dp ON dp.ProductKey = fi.ProductKey
INNER JOIN gold.DimLocation dl ON dl.LocationKey = fi.LocationKey
INNER JOIN gold.DimDate dd ON dd.DateKey = fi.SnapshotDateKey;
GO

-- ============================================================================
-- vw_purchase_orders_list
-- Purchase orders view (for procurement)
-- ============================================================================
IF OBJECT_ID('web.vw_purchase_orders_list', 'V') IS NOT NULL
    DROP VIEW web.vw_purchase_orders_list;
GO

CREATE VIEW web.vw_purchase_orders_list
AS
SELECT
    fp.PONumber,
    fp.PODateKey,
    dd.FullDate AS PODate,
    dv.VendorID,
    dv.VendorName,
    dv.Category AS VendorCategory,
    dp.ProductID,
    dp.ProductName,
    fp.TotalAmount,
    fp.Quantity,
    fp.UnitCost,
    fp.POStatus,
    fp.ExpectedDeliveryDate,
    fp.ActualDeliveryDate,
    fp.SourceSystem,
    CASE fp.POStatus
        WHEN 'Draft' THEN 'badge-secondary'
        WHEN 'Submitted' THEN 'badge-info'
        WHEN 'Approved' THEN 'badge-success'
        WHEN 'Received' THEN 'badge-primary'
        WHEN 'Cancelled' THEN 'badge-danger'
        ELSE 'badge-secondary'
    END AS StatusBadge
FROM gold.FactProcurement fp
INNER JOIN gold.DimVendor dv ON dv.VendorKey = fp.VendorKey
INNER JOIN gold.DimProduct dp ON dp.ProductKey = fp.ProductKey
INNER JOIN gold.DimDate dd ON dd.DateKey = fp.PODateKey;
GO

-- ============================================================================
-- vw_purchase_order_detail
-- Purchase order detail view
-- ============================================================================
IF OBJECT_ID('web.vw_purchase_order_detail', 'V') IS NOT NULL
    DROP VIEW web.vw_purchase_order_detail;
GO

CREATE VIEW web.vw_purchase_order_detail
AS
SELECT
    fp.FactProcurementKey,
    fp.PONumber,
    dd.FullDate AS PODate,
    dv.VendorKey,
    dv.VendorID,
    dv.VendorName,
    dv.Category AS VendorCategory,
    dv.PaymentTerms,
    dp.ProductKey,
    dp.ProductID,
    dp.ProductName,
    dp.Category AS ProductCategory,
    fp.TotalAmount,
    fp.Quantity,
    fp.UnitCost,
    fp.POStatus,
    fp.ExpectedDeliveryDate,
    fp.ActualDeliveryDate,
    fp.SourceSystem,
    dl.LocationID,
    dl.WarehouseName
FROM gold.FactProcurement fp
INNER JOIN gold.DimVendor dv ON dv.VendorKey = fp.VendorKey
INNER JOIN gold.DimProduct dp ON dp.ProductKey = fp.ProductKey
INNER JOIN gold.DimDate dd ON dd.DateKey = fp.PODateKey
INNER JOIN gold.DimLocation dl ON dl.LocationKey = fp.LocationKey;
GO

-- ============================================================================
-- vw_analytics_sales_summary
-- Sales summary for analytics
-- ============================================================================
IF OBJECT_ID('web.vw_analytics_sales_summary', 'V') IS NOT NULL
    DROP VIEW web.vw_analytics_sales_summary;
GO

CREATE VIEW web.vw_analytics_sales_summary
AS
SELECT
    dd.YearNumber,
    dd.MonthNumberOfYear,
    dd.MonthName,
    dd.QuarterNumber,
    dc.Region,
    dc.Segment,
    dp.Category AS ProductCategory,
    SUM(fso.TotalAmount) AS TotalSales,
    COUNT(DISTINCT fso.OrderID) AS OrderCount,
    SUM(fso.Quantity) AS TotalQuantity
FROM gold.FactSalesOrder fso
INNER JOIN gold.DimDate dd ON dd.DateKey = fso.OrderDateKey
INNER JOIN gold.DimCustomer dc ON dc.CustomerKey = fso.CustomerKey
INNER JOIN gold.DimProduct dp ON dp.ProductKey = fso.ProductKey
GROUP BY
    dd.YearNumber, dd.MonthNumberOfYear, dd.MonthName, dd.QuarterNumber,
    dc.Region, dc.Segment, dp.Category;
GO

-- ============================================================================
-- vw_analytics_otc
-- Order-to-Cash KPI view
-- ============================================================================
IF OBJECT_ID('web.vw_analytics_otc', 'V') IS NOT NULL
    DROP VIEW web.vw_analytics_otc;
GO

CREATE VIEW web.vw_analytics_otc
AS
SELECT
    dd.FullDate AS InvoiceDate,
    COUNT(DISTINCT inv.SourceInvoiceID) AS TotalInvoices,
    SUM(inv.TotalAmount) AS TotalInvoiceAmount,
    SUM(inv.PaidAmount) AS TotalPaidAmount,
    SUM(inv.BalanceDue) AS TotalOutstanding,
    CASE
        WHEN SUM(inv.TotalAmount) > 0
        THEN CAST(SUM(inv.PaidAmount) / SUM(inv.TotalAmount) * 100 AS DECIMAL(5,2))
        ELSE 0
    END AS CollectionRate,
    COUNT(DISTINCT CASE WHEN inv.BalanceDue = 0 THEN inv.SourceInvoiceID END) AS PaidInvoiceCount,
    COUNT(DISTINCT CASE WHEN inv.BalanceDue > 0 THEN inv.SourceInvoiceID END) AS OutstandingInvoiceCount
FROM silver.invoice inv
INNER JOIN gold.DimDate dd ON dd.FullDate = inv.InvoiceDate
GROUP BY dd.FullDate;
GO

PRINT 'Web platform views created successfully.';
GO