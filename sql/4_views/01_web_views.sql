-- ============================================================================
-- Web Platform Views
-- ============================================================================
-- Views for web grid displays with row-level security filtering.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- vw_sales_orders_list
-- ============================================================================
CREATE OR ALTER VIEW gold.vw_sales_orders_list
AS
SELECT
    f.SalesOrderKey,
    f.OrderNumber,
    f.OrderDate,
    c.CustomerName,
    p.Name AS ProductName,
    l.WarehouseName,
    f.QuantityOrdered,
    f.UnitPrice,
    f.TotalAmount,
    f.TaxAmount,
    f.Loading AS OrderStatus,
    cu.CurrencyCode,
    f.OrderDate AS RowCreatedDate
FROM gold.FactSalesOrder f
INNER JOIN gold.DimCustomer c ON f.CustomerKey = c.CustomerKey
INNER JOIN gold.DimProduct p ON f.ProductKey = p.ProductKey
LEFT JOIN gold.DimLocation l ON f.LocationKey = l.LocationKey
LEFT JOIN gold.DimCurrency cu ON f.CurrencyKey = cu.CurrencyKey
WHERE c.IsCurrent = 1 AND p.IsCurrent = 1;
GO

-- ============================================================================
-- vw_invoices_list
-- ============================================================================
CREATE OR ALTER VIEW gold.vw_invoices_list
AS
SELECT
    i.canonical_id AS InvoiceKey,
    i.invoice_number AS InvoiceNumber,
    i.invoice_date AS InvoiceDate,
    i.invoice_amount AS Amount,
    i.tax_amount AS TaxAmount,
    i.paid_amount AS PaidAmount,
    i.outstanding_amount AS OutstandingAmount,
    i.payment_status AS PaymentStatus,
    i.customer_name AS CustomerName,
    i.currency_code AS CurrencyCode
FROM silver.silver_invoice i
WHERE i.is_current = 1;
GO

-- ============================================================================
-- vw_inventory_summary
-- ============================================================================
CREATE OR ALTER VIEW gold.vw_inventory_summary
AS
SELECT
    f.InventoryKey,
    f.DateKey,
    p.Name AS ProductName,
    p.NaturalKey AS ProductSKU,
    l.WarehouseName,
    l.Region,
    f.QuantityOnHand,
    f.QuantityReserved,
    f.QuantityAvailable,
    f.UnitCost,
    f.InventoryValue,
    f.WarehouseID,
    d.FullDate AS InventoryDate
FROM gold.FactInventory f
INNER JOIN gold.DimProduct p ON f.ProductKey = p.ProductKey
INNER JOIN gold.DimLocation l ON f.LocationKey = l.LocationKey
INNER JOIN gold.DimDate d ON f.DateKey = d.DateKey
WHERE p.IsCurrent = 1 AND l.IsCurrent = 1;
GO

-- ============================================================================
-- vw_customer_orders
-- ============================================================================
CREATE OR ALTER VIEW gold.vw_customer_orders
AS
SELECT
    c.CustomerKey,
    c.CustomerName,
    c.Region,
    c.Segment,
    f.SalesOrderKey,
    f.OrderNumber,
    f.OrderDate,
    f.TotalAmount,
    f.Loading AS OrderStatus,
    p.Name AS ProductName,
    f.QuantityOrdered
FROM gold.FactSalesOrder f
INNER JOIN gold.DimCustomer c ON f.CustomerKey = c.CustomerKey
INNER JOIN gold.DimProduct p ON f.ProductKey = p.ProductKey
WHERE c.IsCurrent = 1 AND p.IsCurrent = 1;
GO

-- ============================================================================
-- vw_procurement_summary
-- ============================================================================
CREATE OR ALTER VIEW gold.vw_procurement_summary
AS
SELECT
    f.ProcurementKey,
    f.PONumber,
    f.PODate,
    v.VendorName,
    p.Name AS ProductName,
    f.QuantityOrdered,
    f.QuantityReceived,
    f.UnitCost,
    f.TotalAmount,
    f.Status,
    cu.CurrencyCode
FROM gold.FactProcurement f
INNER JOIN gold.DimVendor v ON f.VendorKey = v.VendorKey
INNER JOIN gold.DimProduct p ON f.ProductKey = p.ProductKey
LEFT JOIN gold.DimCurrency cu ON f.CurrencyKey = cu.CurrencyKey
WHERE v.IsCurrent = 1 AND p.IsCurrent = 1;
GO

-- ============================================================================
-- vw_shipment_tracking
-- ============================================================================
CREATE OR ALTER VIEW gold.vw_shipment_tracking
AS
SELECT
    f.ShipmentKey,
    f.ShipmentNumber,
    f.ShipDate,
    c.CustomerName,
    p.Name AS ProductName,
    f.QuantityShipped,
    f.UnitPrice,
    f.TotalAmount,
    f.Carrier,
    f.TrackingNumber,
    cu.CurrencyCode,
    l.WarehouseName AS OriginWarehouse
FROM gold.FactShipment f
INNER JOIN gold.DimCustomer c ON f.CustomerKey = c.CustomerKey
INNER JOIN gold.DimProduct p ON f.ProductKey = p.ProductKey
INNER JOIN gold.DimLocation l ON f.LocationKey = l.LocationKey
LEFT JOIN gold.DimCurrency cu ON f.CurrencyKey = cu.CurrencyKey
WHERE c.IsCurrent = 1 AND p.IsCurrent = 1 AND l.IsCurrent = 1;
GO

PRINT 'Web views created successfully.';
GO