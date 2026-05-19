-- ============================================================================
-- PRODUCTION SUPPORT RUNBOOK
-- Troubleshooting procedures for data issues
-- ============================================================================

-- ============================================================================
-- usp_troubleshoot_data_lineage
-- Trace data from staging to gold to identify issues
-- ============================================================================
IF OBJECT_ID('etl.usp_troubleshoot_data_lineage', 'P') IS NOT NULL
    DROP PROC etl.usp_troubleshoot_data_lineage;
GO

CREATE PROC etl.usp_troubleshoot_data_lineage
    @SourceOrderID NVARCHAR(50) = NULL,
    @SourceSystem NVARCHAR(50) = NULL,
    @OrderDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== DATA LINEAGE REPORT ===';
    PRINT 'Order ID: ' + ISNULL(@SourceOrderID, 'N/A');
    PRINT 'Source System: ' + ISNULL(@SourceSystem, 'N/A');
    PRINT 'Order Date: ' + ISNULL(CONVERT(NVARCHAR(10), @OrderDate), 'N/A');
    PRINT '';

    -- Bronze Layer
    PRINT '--- BRONZE LAYER ---';
    SELECT
        'stage_sage_sales_orders' AS TableName,
        OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus, LastModified
    FROM bronze.stage_sage_sales_orders
    WHERE (@SourceOrderID IS NULL OR OrderID = @SourceOrderID)
    AND (@SourceSystem IS NULL OR SourceSystem = @SourceSystem)
    UNION ALL
    SELECT
        'stage_sap_sales_orders' AS TableName,
        OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus, LastModified
    FROM bronze.stage_sap_sales_orders
    WHERE (@SourceOrderID IS NULL OR OrderID = @SourceOrderID)
    AND (@SourceSystem IS NULL OR SourceSystem = @SourceSystem)
    UNION ALL
    SELECT
        'stage_custom_sales_orders' AS TableName,
        OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus, LastModified
    FROM bronze.stage_custom_sales_orders
    WHERE (@SourceOrderID IS NULL OR OrderID = @SourceOrderID)
    AND (@SourceSystem IS NULL OR SourceSystem = @SourceSystem);

    -- Silver Layer
    PRINT '';
    PRINT '--- SILVER LAYER ---';
    SELECT
        'silver.sales_order' AS TableName,
        SalesOrderKey, SourceSystem, SourceOrderID, OrderDate,
        CustomerID, TotalAmount, OrderStatus, ValidationStatus
    FROM silver.sales_order
    WHERE (@SourceOrderID IS NULL OR SourceOrderID = @SourceOrderID)
    AND (@SourceSystem IS NULL OR SourceSystem = @SourceSystem)
    AND (@OrderDate IS NULL OR OrderDate = @OrderDate);

    -- Gold Layer
    PRINT '';
    PRINT '--- GOLD LAYER (FactSalesOrder) ---';
    SELECT
        'gold.FactSalesOrder' AS TableName,
        fso.FactSalesOrderKey,
        fso.OrderID,
        fso.SourceSystem,
        fso.TotalAmount,
        fso.Quantity,
        dd.FullDate AS OrderDate,
        dc.CustomerName,
        dp.ProductName
    FROM gold.FactSalesOrder fso
    INNER JOIN gold.DimDate dd ON dd.DateKey = fso.OrderDateKey
    LEFT JOIN gold.DimCustomer dc ON dc.CustomerKey = fso.CustomerKey
    LEFT JOIN gold.DimProduct dp ON dp.ProductKey = fso.ProductKey
    WHERE (@SourceOrderID IS NULL OR fso.OrderID = @SourceOrderID)
    AND (@SourceSystem IS NULL OR fso.SourceSystem = @SourceSystem);

    -- Watermark status
    PRINT '';
    PRINT '--- WATERMARK STATUS ---';
    SELECT
        source_id,
        source_table,
        last_watermark_value,
        last_run_time,
        rows_processed,
        status
    FROM bronze.watermark
    WHERE source_table LIKE '%sales_order%';
END
GO

-- ============================================================================
-- usp_troubleshoot_missing_dimensions
-- Identify fact records with missing dimension keys
-- ============================================================================
IF OBJECT_ID('etl.usp_troubleshoot_missing_dimensions', 'P') IS NOT NULL
    DROP PROC etl.usp_troubleshoot_missing_dimensions;
GO

CREATE PROC etl.usp_troubleshoot_missing_dimensions
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== MISSING DIMENSION KEYS REPORT ===';
    PRINT '';

    -- FactSalesOrder missing keys
    PRINT '--- FactSalesOrder: Missing Customer Keys ---';
    SELECT
        fso.OrderID,
        fso.SourceSystem,
        fso.CustomerKey,
        CASE WHEN fso.CustomerKey < 0 THEN 'MISSING' ELSE 'OK' END AS Status
    FROM gold.FactSalesOrder fso
    WHERE fso.CustomerKey < 0;

    PRINT '';
    PRINT '--- FactSalesOrder: Missing Product Keys ---';
    SELECT
        fso.OrderID,
        fso.SourceSystem,
        fso.ProductKey,
        CASE WHEN fso.ProductKey < 0 THEN 'MISSING' ELSE 'OK' END AS Status
    FROM gold.FactSalesOrder fso
    WHERE fso.ProductKey < 0;

    PRINT '';
    PRINT '--- FactInventory: Missing Product Keys ---';
    SELECT
        fi.SnapshotID,
        fi.ProductKey,
        CASE WHEN fi.ProductKey < 0 THEN 'MISSING' ELSE 'OK' END AS Status
    FROM gold.FactInventory fi
    WHERE fi.ProductKey < 0;

    PRINT '';
    PRINT '--- FactInventory: Missing Location Keys ---';
    SELECT
        fi.SnapshotID,
        fi.LocationKey,
        CASE WHEN fi.LocationKey < 0 THEN 'MISSING' ELSE 'OK' END AS Status
    FROM gold.FactInventory fi
    WHERE fi.LocationKey < 0;

    -- Dimension coverage report
    PRINT '';
    PRINT '--- DIMENSION COVERAGE ---';
    SELECT
        'DimCustomer' AS Dimension,
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentRecords,
        SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END) AS HistoricalRecords
    FROM gold.DimCustomer
    UNION ALL
    SELECT
        'DimProduct' AS Dimension,
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentRecords,
        SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END) AS HistoricalRecords
    FROM gold.DimProduct
    UNION ALL
    SELECT
        'DimVendor' AS Dimension,
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentRecords,
        SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END) AS HistoricalRecords
    FROM gold.DimVendor
    UNION ALL
    SELECT
        'DimLocation' AS Dimension,
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentRecords,
        SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END) AS HistoricalRecords
    FROM gold.DimLocation;
END
GO

-- ============================================================================
-- usp_troubleshoot_validation_failures
-- Report on data quality validation failures
-- ============================================================================
IF OBJECT_ID('etl.usp_troubleshoot_validation_failures', 'P') IS NOT NULL
    DROP PROC etl.usp_troubleshoot_validation_failures;
GO

CREATE PROC etl.usp_troubleshoot_validation_failures
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== DATA QUALITY VALIDATION REPORT ===';
    PRINT '';

    -- Sales orders validation failures
    PRINT '--- Sales Orders: Validation Failures ---';
    SELECT
        SourceSystem,
        SourceOrderID,
        CustomerID,
        TotalAmount,
        OrderStatus,
        ValidationStatus,
        ValidationErrors
    FROM silver.sales_order
    WHERE ValidationStatus = 'failed'
    OR ValidationErrors IS NOT NULL;

    -- Invoices validation failures
    PRINT '';
    PRINT '--- Invoices: Validation Failures ---';
    SELECT
        SourceSystem,
        SourceInvoiceID,
        CustomerID,
        TotalAmount,
        PaidAmount,
        ValidationStatus,
        ValidationErrors
    FROM silver.invoice
    WHERE ValidationStatus = 'failed'
    OR ValidationErrors IS NOT NULL;

    -- Invalid amounts
    PRINT '';
    PRINT '--- Records with Invalid Amounts (Negative) ---';
    SELECT 'silver.sales_order' AS TableName, SourceOrderID, TotalAmount
    FROM silver.sales_order WHERE TotalAmount < 0
    UNION ALL
    SELECT 'silver.invoice' AS TableName, SourceInvoiceID, TotalAmount
    FROM silver.invoice WHERE TotalAmount < 0
    UNION ALL
    SELECT 'silver.invoice' AS TableName, SourceInvoiceID, PaidAmount
    FROM silver.invoice WHERE PaidAmount < 0;

    -- Future dates
    PRINT '';
    PRINT '--- Records with Future Dates ---';
    SELECT 'silver.sales_order' AS TableName, SourceOrderID, OrderDate
    FROM silver.sales_order WHERE OrderDate > CAST(SYSDATETIME() AS DATE)
    UNION ALL
    SELECT 'silver.invoice' AS TableName, SourceInvoiceID, InvoiceDate
    FROM silver.invoice WHERE InvoiceDate > CAST(SYSDATETIME() AS DATE)
    UNION ALL
    SELECT 'silver.shipment' AS TableName, SourceShipmentID, ShipDate
    FROM silver.shipment WHERE ShipDate > CAST(SYSDATETIME() AS DATE);
END
GO

-- ============================================================================
-- usp_troubleshoot_performance
-- Identify slow queries and missing indexes
-- ============================================================================
IF OBJECT_ID('etl.usp_troubleshoot_performance', 'P') IS NOT NULL
    DROP PROC etl.usp_troubleshoot_performance;
GO

CREATE PROC etl.usp_troubleshoot_performance
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== PERFORMANCE TROUBLESHOOTING REPORT ===';
    PRINT '';

    -- Table sizes
    PRINT '--- Table Sizes (Row Counts) ---';
    SELECT
        'bronze.stage_sage_sales_orders' AS TableName,
        COUNT(*) AS RowCount
    FROM bronze.stage_sage_sales_orders
    UNION ALL SELECT 'bronze.stage_sage_invoices', COUNT(*) FROM bronze.stage_sage_invoices
    UNION ALL SELECT 'bronze.stage_sap_sales_orders', COUNT(*) FROM bronze.stage_sap_sales_orders
    UNION ALL SELECT 'silver.sales_order', COUNT(*) FROM silver.sales_order
    UNION ALL SELECT 'silver.invoice', COUNT(*) FROM silver.invoice
    UNION ALL SELECT 'silver.shipment', COUNT(*) FROM silver.shipment
    UNION ALL SELECT 'gold.DimCustomer', COUNT(*) FROM gold.DimCustomer
    UNION ALL SELECT 'gold.DimProduct', COUNT(*) FROM gold.DimProduct
    UNION ALL SELECT 'gold.FactSalesOrder', COUNT(*) FROM gold.FactSalesOrder
    UNION ALL SELECT 'gold.FactInventory', COUNT(*) FROM gold.FactInventory;

    -- Unprocessed staging records (potential pipeline issues)
    PRINT '';
    PRINT '--- Unprocessed Staging Records (>1 hour old) ---';
    SELECT
        'stage_sage_sales_orders' AS TableName,
        COUNT(*) AS UnprocessedCount
    FROM bronze.stage_sage_sales_orders
    WHERE ProcessedAt IS NULL
    AND InsertedAt < DATEADD(HOUR, -1, SYSDATETIME())
    UNION ALL
    SELECT
        'stage_sap_sales_orders' AS TableName,
        COUNT(*) AS UnprocessedCount
    FROM bronze.stage_sap_sales_orders
    WHERE ProcessedAt IS NULL
    AND InsertedAt < DATEADD(HOUR, -1, SYSDATETIME());

    -- Watermark staleness
    PRINT '';
    PRINT '--- Stale Watermarks (>4 hours since last run) ---';
    SELECT
        source_id,
        source_table,
        last_run_time,
        DATEDIFF(HOUR, last_run_time, SYSDATETIME()) AS HoursSinceRun,
        status
    FROM bronze.watermark
    WHERE last_run_time < DATEADD(HOUR, -4, SYSDATETIME())
    OR status = 'failed';

    -- Recent pipeline failures
    PRINT '';
    PRINT '--- Recent Pipeline Failures (Last 24 hours) ---';
    SELECT TOP 10
        PipelineName,
        StepName,
        StartTime,
        ErrorMessage
    FROM etl.pipeline_log
    WHERE Status = 'failed'
    AND StartTime > DATEADD(HOUR, -24, SYSDATETIME())
    ORDER BY StartTime DESC;
END
GO

PRINT 'Production support runbook procedures created successfully.';
GO