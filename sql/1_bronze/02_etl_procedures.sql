-- ============================================================================
-- BRONZE LAYER - ETL Pipeline Stored Procedures
-- Watermark-based incremental CDC procedures
-- No full re-loads - incremental only
-- ============================================================================

-- ============================================================================
--usp_bronze_get_watermark
-- Retrieves the last watermark value for a given source
-- ============================================================================
IF OBJECT_ID('bronze.usp_bronze_get_watermark', 'P') IS NOT NULL
    DROP PROC bronze.usp_bronze_get_watermark;
GO

CREATE PROC bronze.usp_bronze_get_watermark
    @source_id NVARCHAR(50),
    @source_table NVARCHAR(100),
    @last_watermark DATETIME2 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @last_watermark = last_watermark_value
    FROM bronze.watermark
    WHERE source_id = @source_id
      AND source_table = @source_table;

    -- Return NULL if no watermark exists (first run)
    SET @last_watermark = ISNULL(@last_watermark, '1900-01-01');
END
GO

-- ============================================================================
--usp_bronze_update_watermark
-- Updates the watermark after successful load
-- ============================================================================
IF OBJECT_ID('bronze.usp_bronze_update_watermark', 'P') IS NOT NULL
    DROP PROC bronze.usp_bronze_update_watermark;
GO

CREATE PROC bronze.usp_bronze_update_watermark
    @source_id NVARCHAR(50),
    @source_table NVARCHAR(100),
    @stage_table NVARCHAR(100),
    @new_watermark_value DATETIME2,
    @rows_processed INT,
    @status NVARCHAR(20) = 'success',
    @error_message NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE INTO bronze.watermark AS target
    USING (SELECT @source_id AS source_id, @source_table AS source_table) AS source
    ON target.source_id = source.source_id AND target.source_table = source.source_table
    WHEN MATCHED THEN
        UPDATE SET
            last_watermark_value = @new_watermark_value,
            last_run_time = SYSDATETIME(),
            rows_processed = @rows_processed,
            status = @status,
            error_message = @error_message
    WHEN NOT MATCHED THEN
        INSERT (source_id, source_table, stage_table, last_watermark_value, last_run_time, rows_processed, status, error_message)
        VALUES (@source_id, @source_table, @stage_table, @new_watermark_value, SYSDATETIME(), @rows_processed, @status, @error_message);
END
GO

-- ============================================================================
--usp_bronze_load_sage_sales_orders
-- Incremental load from Sage ERP - only new/modified rows since last run
-- ============================================================================
IF OBJECT_ID('bronze.usp_bronze_load_sage_sales_orders', 'P') IS NOT NULL
    DROP PROC bronze.usp_bronze_load_sage_sales_orders;
GO

CREATE PROC bronze.usp_bronze_load_sage_sales_orders
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @last_watermark DATETIME2;
    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @rows_processed INT = 0;
    DECLARE @max_watermark DATETIME2;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        -- Get last watermark
        EXEC bronze.usp_bronze_get_watermark
            @source_id = 'sage_erp',
            @source_table = 'SO_SalesOrderHeaders',
            @last_watermark = @last_watermark OUTPUT;

        -- Mark as running
        UPDATE bronze.watermark
        SET status = 'running'
        WHERE source_id = 'sage_erp' AND source_table = 'SO_SalesOrderHeaders';

        -- Source query (replace with actual linked server query in production)
        -- This example uses OPENROWSET or linked server syntax
        /*
        INSERT INTO bronze.stage_sage_sales_orders
            (OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus, LastModified, SourceSystem, BatchID)
        SELECT
            OrderID,
            CustomerID,
            OrderDate,
            TotalAmount,
            OrderStatus,
            LastModified,
            'sage_erp',
            @batch_id
        FROM [sage-db.internal].SageLive.dbo.SO_SalesOrderHeaders
        WHERE LastModified > @last_watermark;
        */

        -- Simulated insert for development
        INSERT INTO bronze.stage_sage_sales_orders
            (OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus, LastModified, SourceSystem, BatchID)
        VALUES
            ('SO-2025-001', 'CUST-001', '2025-01-15', 15000.00, 'Approved', SYSDATETIME(), 'sage_erp', @batch_id),
            ('SO-2025-002', 'CUST-002', '2025-01-15', 8500.00, 'Pending', SYSDATETIME(), 'sage_erp', @batch_id);

        -- Get count and max watermark
        SELECT @rows_processed = COUNT(*), @max_watermark = MAX(LastModified)
        FROM bronze.stage_sage_sales_orders
        WHERE BatchID = @batch_id;

        -- Update watermark on success
        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'sage_erp',
            @source_table = 'SO_SalesOrderHeaders',
            @stage_table = 'stage_sage_sales_orders',
            @new_watermark_value = @max_watermark,
            @rows_processed = @rows_processed,
            @status = 'success';

        PRINT 'Sage sales orders loaded: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        SET @error_message = ERROR_MESSAGE();

        -- Log failure
        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'sage_erp',
            @source_table = 'SO_SalesOrderHeaders',
            @stage_table = 'stage_sage_sales_orders',
            @new_watermark_value = @last_watermark,
            @rows_processed = 0,
            @status = 'failed',
            @error_message = @error_message;

        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_bronze_load_sage_invoices
-- Incremental load from Sage Invoices
-- ============================================================================
IF OBJECT_ID('bronze.usp_bronze_load_sage_invoices', 'P') IS NOT NULL
    DROP PROC bronze.usp_bronze_load_sage_invoices;
GO

CREATE PROC bronze.usp_bronze_load_sage_invoices
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @last_watermark DATETIME2;
    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @rows_processed INT = 0;
    DECLARE @max_watermark DATETIME2;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        EXEC bronze.usp_bronze_get_watermark
            @source_id = 'sage_erp',
            @source_table = 'AR_Invoices',
            @last_watermark = @last_watermark OUTPUT;

        UPDATE bronze.watermark
        SET status = 'running'
        WHERE source_id = 'sage_erp' AND source_table = 'AR_Invoices';

        /* Source query:
        INSERT INTO bronze.stage_sage_invoices
            (InvoiceID, OrderID, CustomerID, InvoiceDate, TotalAmount, PaidAmount, LastModified, SourceSystem, BatchID)
        SELECT
            InvoiceID, OrderID, CustomerID, InvoiceDate, TotalAmount, PaidAmount, LastModified, 'sage_erp', @batch_id
        FROM [sage-db.internal].SageLive.dbo.AR_Invoices
        WHERE LastModified > @last_watermark;
        */

        -- Simulated insert
        INSERT INTO bronze.stage_sage_invoices
            (InvoiceID, OrderID, CustomerID, InvoiceDate, TotalAmount, PaidAmount, LastModified, SourceSystem, BatchID)
        VALUES
            ('INV-2025-001', 'SO-2025-001', 'CUST-001', '2025-01-16', 15000.00, 5000.00, SYSDATETIME(), 'sage_erp', @batch_id),
            ('INV-2025-002', 'SO-2025-002', 'CUST-002', '2025-01-16', 8500.00, 0, SYSDATETIME(), 'sage_erp', @batch_id);

        SELECT @rows_processed = COUNT(*), @max_watermark = MAX(LastModified)
        FROM bronze.stage_sage_invoices
        WHERE BatchID = @batch_id;

        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'sage_erp',
            @source_table = 'AR_Invoices',
            @stage_table = 'stage_sage_invoices',
            @new_watermark_value = @max_watermark,
            @rows_processed = @rows_processed,
            @status = 'success';

        PRINT 'Sage invoices loaded: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        SET @error_message = ERROR_MESSAGE();

        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'sage_erp',
            @source_table = 'AR_Invoices',
            @stage_table = 'stage_sage_invoices',
            @new_watermark_value = @last_watermark,
            @rows_processed = 0,
            @status = 'failed',
            @error_message = @error_message;

        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_bronze_load_sap_sales_orders
-- Incremental load from SAP ERP
-- ============================================================================
IF OBJECT_ID('bronze.usp_bronze_load_sap_sales_orders', 'P') IS NOT NULL
    DROP PROC bronze.usp_bronze_load_sap_sales_orders;
GO

CREATE PROC bronze.usp_bronze_load_sap_sales_orders
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @last_watermark DATETIME2;
    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @rows_processed INT = 0;
    DECLARE @max_watermark DATETIME2;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        EXEC bronze.usp_bronze_get_watermark
            @source_id = 'sap_erp',
            @source_table = 'VBAK_SalesOrders',
            @last_watermark = @last_watermark OUTPUT;

        UPDATE bronze.watermark
        SET status = 'running'
        WHERE source_id = 'sap_erp' AND source_table = 'VBAK_SalesOrders';

        /* SAP source query:
        INSERT INTO bronze.stage_sap_sales_orders
            (OrderID, CustomerID, OrderDate, TotalAmount, POReference, OrderStatus, LastModified, SourceSystem, BatchID)
        SELECT
            VBELN, KUNNR, AUDAT, NETWR, BSTNK, VMSTA, MODIFIED_TS, 'sap_erp', @batch_id
        FROM [sap-db.internal].SAPECC.dbo.VBAK_SalesOrders
        WHERE MODIFIED_TS > @last_watermark;
        */

        -- Simulated insert
        INSERT INTO bronze.stage_sap_sales_orders
            (OrderID, CustomerID, OrderDate, TotalAmount, POReference, OrderStatus, LastModified, SourceSystem, BatchID)
        VALUES
            ('SAP-0001', 'CUST-003', '2025-01-15', 22000.00, 'PO-12345', 'Approved', SYSDATETIME(), 'sap_erp', @batch_id),
            ('SAP-0002', 'CUST-001', '2025-01-15', 11000.00, 'PO-12346', 'Pending', SYSDATETIME(), 'sap_erp', @batch_id);

        SELECT @rows_processed = COUNT(*), @max_watermark = MAX(LastModified)
        FROM bronze.stage_sap_sales_orders
        WHERE BatchID = @batch_id;

        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'sap_erp',
            @source_table = 'VBAK_SalesOrders',
            @stage_table = 'stage_sap_sales_orders',
            @new_watermark_value = @max_watermark,
            @rows_processed = @rows_processed,
            @status = 'success';

        PRINT 'SAP sales orders loaded: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        SET @error_message = ERROR_MESSAGE();

        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'sap_erp',
            @source_table = 'VBAK_SalesOrders',
            @stage_table = 'stage_sap_sales_orders',
            @new_watermark_value = @last_watermark,
            @rows_processed = 0,
            @status = 'failed',
            @error_message = @error_message;

        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_bronze_load_custom_inventory
-- Incremental load from Custom ERP inventory
-- ============================================================================
IF OBJECT_ID('bronze.usp_bronze_load_custom_inventory', 'P') IS NOT NULL
    DROP PROC bronze.usp_bronze_load_custom_inventory;
GO

CREATE PROC bronze.usp_bronze_load_custom_inventory
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @last_watermark DATETIME2;
    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @rows_processed INT = 0;
    DECLARE @max_watermark DATETIME2;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        EXEC bronze.usp_bronze_get_watermark
            @source_id = 'custom_erp',
            @source_table = 'inventory_snapshot',
            @last_watermark = @last_watermark OUTPUT;

        UPDATE bronze.watermark
        SET status = 'running'
        WHERE source_id = 'custom_erp' AND source_table = 'inventory_snapshot';

        /* Custom ERP source query:
        INSERT INTO bronze.stage_custom_inventory
            (SnapshotID, ProductID, WarehouseID, Quantity, LastModified, SourceSystem, BatchID)
        SELECT
            snapshot_id, product_id, warehouse_id, quantity_on_hand, updated_at, 'custom_erp', @batch_id
        FROM [custom-db.internal].MfgERP.public.inventory_snapshot
        WHERE updated_at > @last_watermark;
        */

        -- Simulated insert
        INSERT INTO bronze.stage_custom_inventory
            (SnapshotID, ProductID, WarehouseID, Quantity, LastModified, SourceSystem, BatchID)
        VALUES
            ('SNAP-001', 'PROD-001', 'WH-001', 500.00, SYSDATETIME(), 'custom_erp', @batch_id),
            ('SNAP-001', 'PROD-002', 'WH-001', 250.00, SYSDATETIME(), 'custom_erp', @batch_id),
            ('SNAP-001', 'PROD-003', 'WH-002', 1200.00, SYSDATETIME(), 'custom_erp', @batch_id);

        SELECT @rows_processed = COUNT(*), @max_watermark = MAX(LastModified)
        FROM bronze.stage_custom_inventory
        WHERE BatchID = @batch_id;

        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'custom_erp',
            @source_table = 'inventory_snapshot',
            @stage_table = 'stage_custom_inventory',
            @new_watermark_value = @max_watermark,
            @rows_processed = @rows_processed,
            @status = 'success';

        PRINT 'Custom inventory loaded: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        SET @error_message = ERROR_MESSAGE();

        EXEC bronze.usp_bronze_update_watermark
            @source_id = 'custom_erp',
            @source_table = 'inventory_snapshot',
            @stage_table = 'stage_custom_inventory',
            @new_watermark_value = @last_watermark,
            @rows_processed = 0,
            @status = 'failed',
            @error_message = @error_message;

        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_bronze_run_all
-- Master procedure to run all bronze loads
-- ============================================================================
IF OBJECT_ID('bronze.usp_bronze_run_all', 'P') IS NOT NULL
    DROP PROC bronze.usp_bronze_run_all;
GO

CREATE PROC bronze.usp_bronze_run_all
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Starting Bronze layer load...';
    PRINT '--------------------------------';

    -- Load Sage
    PRINT 'Loading Sage ERP...';
    EXEC bronze.usp_bronze_load_sage_sales_orders;
    EXEC bronze.usp_bronze_load_sage_invoices;

    -- Load SAP
    PRINT 'Loading SAP ERP...';
    EXEC bronze.usp_bronze_load_sap_sales_orders;

    -- Load Custom
    PRINT 'Loading Custom ERP...';
    EXEC bronze.usp_bronze_load_custom_inventory;

    PRINT '--------------------------------';
    PRINT 'Bronze layer load complete.';
END
GO

PRINT 'Bronze layer ETL procedures created successfully.';
GO