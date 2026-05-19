-- ============================================================================
-- CDC ETL Procedures for Bronze Layer
-- ============================================================================
-- Watermark-based incremental load procedures with TRY/CATCH error handling,
-- transaction management, and pipeline logging.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- ETL Watermarks Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS etl.etl_watermarks (
    watermark_id INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NOT NULL,
    source_table NVARCHAR(100) NOT NULL,
    watermark_column NVARCHAR(100) NOT NULL,
    last_watermark_value DATETIME2 NULL,
    updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT UQ_etl_watermarks_source_table UNIQUE (source_system, source_table)
);
GO

-- ============================================================================
-- Procedure: usp_bronze_load_sage_sales_orders
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_bronze_load_sage_sales_orders
    @BatchSize INT = 10000,
    @LoadId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @LastWatermark DATETIME2;
    
    -- Initialize LoadId if not provided
    IF @LoadId IS NULL
        SET @LoadId = NEWID();
    
    BEGIN TRY
        -- Get last watermark
        SELECT @LastWatermark = last_watermark_value
        FROM etl.etl_watermarks
        WHERE source_system = 'sage' AND source_table = 'sales_orders';
        
        -- Start pipeline log
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- CDC Incremental Load from Sage Source
        -- In production, this would be: INSERT INTO stage.stage_sage_sales_orders (...)
        -- SELECT ... FROM [$(SageServer)].[$(SageDatabase)].dbo.sales_orders s
        -- WHERE s.LastModified > @LastWatermark OR @LastWatermark IS NULL
        
        -- For demo, simulate incremental load
        INSERT INTO stage.stage_sage_sales_orders (
            source_system, load_id, last_modified, is_deleted, natural_key,
            OrderID, CustomerID, OrderDate, TotalAmount, Status
        )
        SELECT TOP (@BatchSize)
            'sage',
            @LoadId,
            GETDATE(),
            0,
            CAST(OrderID AS NVARCHAR(255)),
            OrderID,
            CustomerID,
            OrderDate,
            TotalAmount,
            Status
        FROM (
            SELECT 1 AS OrderID, 'CUST001' AS CustomerID, GETDATE() AS OrderDate, 1000.00 AS TotalAmount, 'Active' AS Status
        ) AS SimulatedSource
        WHERE NOT EXISTS (
            SELECT 1 FROM stage.stage_sage_sales_orders sso
            WHERE sso.OrderID = OrderID AND sso.load_id = @LoadId
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
        -- Update watermark
        MERGE INTO etl.etl_watermarks AS target
        USING (SELECT 'sage' AS source_system, 'sales_orders' AS source_table, SYSDATETIME() AS last_watermark_value) AS source
        ON target.source_system = source.source_system AND target.source_table = source.source_table
        WHEN MATCHED THEN
            UPDATE SET last_watermark_value = source.last_watermark_value, updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (source_system, source_table, watermark_column, last_watermark_value)
            VALUES (source.source_system, source.source_table, 'LastModified', source.last_watermark_value);
        
        COMMIT TRANSACTION;
        
        -- Update pipeline log success
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE() + ' (Line: ' + CAST(ERROR_LINE() AS NVARCHAR(10)) + ')';
        
        -- Log error
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Failed', error_message = @ErrorMessage
        WHERE job_id = @JobId;
        
        -- Insert to dead letter
        INSERT INTO etl.dead_letter (source_system, source_table, payload, error_message, retry_count)
        VALUES ('sage', 'sales_orders', NULL, @ErrorMessage, 0);
        
        -- Rethrow for calling procedure
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- Procedure: usp_bronze_load_sage_invoices
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_bronze_load_sage_invoices
    @BatchSize INT = 10000,
    @LoadId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @LastWatermark DATETIME2;
    
    IF @LoadId IS NULL
        SET @LoadId = NEWID();
    
    BEGIN TRY
        SELECT @LastWatermark = last_watermark_value
        FROM etl.etl_watermarks
        WHERE source_system = 'sage' AND source_table = 'invoices';
        
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- CDC Incremental Load
        INSERT INTO stage.stage_sage_invoices (
            source_system, load_id, last_modified, is_deleted, natural_key,
            InvoiceID, OrderID, InvoiceDate, InvoiceAmount, TaxAmount
        )
        SELECT TOP (@BatchSize)
            'sage',
            @LoadId,
            GETDATE(),
            0,
            CAST(InvoiceID AS NVARCHAR(255)),
            InvoiceID,
            OrderID,
            InvoiceDate,
            InvoiceAmount,
            TaxAmount
        FROM (
            SELECT 1 AS InvoiceID, 'ORD001' AS OrderID, GETDATE() AS InvoiceDate, 1000.00 AS InvoiceAmount, 100.00 AS TaxAmount
        ) AS SimulatedSource
        WHERE NOT EXISTS (
            SELECT 1 FROM stage.stage_sage_invoices si
            WHERE si.InvoiceID = InvoiceID AND si.load_id = @LoadId
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
        MERGE INTO etl.etl_watermarks AS target
        USING (SELECT 'sage' AS source_system, 'invoices' AS source_table, SYSDATETIME() AS last_watermark_value) AS source
        ON target.source_system = source.source_system AND target.source_table = source.source_table
        WHEN MATCHED THEN
            UPDATE SET last_watermark_value = source.last_watermark_value, updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (source_system, source_table, watermark_column, last_watermark_value)
            VALUES (source.source_system, source.source_table, 'LastModified', source.last_watermark_value);
        
        COMMIT TRANSACTION;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE() + ' (Line: ' + CAST(ERROR_LINE() AS NVARCHAR(10)) + ')';
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Failed', error_message = @ErrorMessage
        WHERE job_id = @JobId;
        
        INSERT INTO etl.dead_letter (source_system, source_table, payload, error_message, retry_count)
        VALUES ('sage', 'invoices', NULL, @ErrorMessage, 0);
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- Procedure: usp_bronze_load_sap_sales_orders
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_bronze_load_sap_sales_orders
    @BatchSize INT = 10000,
    @LoadId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @LastWatermark DATETIME2;
    
    IF @LoadId IS NULL
        SET @LoadId = NEWID();
    
    BEGIN TRY
        SELECT @LastWatermark = last_watermark_value
        FROM etl.etl_watermarks
        WHERE source_system = 'sap' AND source_table = 'sales_orders';
        
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- SAP uses MODIFIED_TS watermark column
        INSERT INTO stage.stage_sap_sales_orders (
            source_system, load_id, last_modified, is_deleted, natural_key,
            VBELN, KUNNR, AUDAT, NETWR, WKURS, WAERS, BSTNK, STATU
        )
        SELECT TOP (@BatchSize)
            'sap',
            @LoadId,
            GETDATE(),
            0,
            CAST(VBELN AS NVARCHAR(255)),
            VBELN,
            KUNNR,
            AUDAT,
            NETWR,
            WKURS,
            WAERS,
            BSTNK,
            STATU
        FROM (
            SELECT 'VB001' AS VBELN, 'KUN001' AS KUNNR, GETDATE() AS AUDAT, 5000.00 AS NETWR, '1.0' AS WKURS, 'USD' AS WAERS, 'PO001' AS BSTNK, 'A' AS STATU
        ) AS SimulatedSource
        WHERE NOT EXISTS (
            SELECT 1 FROM stage.stage_sap_sales_orders sso
            WHERE sso.VBELN = VBELN AND sso.load_id = @LoadId
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
        MERGE INTO etl.etl_watermarks AS target
        USING (SELECT 'sap' AS source_system, 'sales_orders' AS source_table, SYSDATETIME() AS last_watermark_value) AS source
        ON target.source_system = source.source_system AND target.source_table = source.source_table
        WHEN MATCHED THEN
            UPDATE SET last_watermark_value = source.last_watermark_value, updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (source_system, source_table, watermark_column, last_watermark_value)
            VALUES (source.source_system, source.source_table, 'MODIFIED_TS', source.last_watermark_value);
        
        COMMIT TRANSACTION;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE() + ' (Line: ' + CAST(ERROR_LINE() AS NVARCHAR(10)) + ')';
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Failed', error_message = @ErrorMessage
        WHERE job_id = @JobId;
        
        INSERT INTO etl.dead_letter (source_system, source_table, payload, error_message, retry_count)
        VALUES ('sap', 'sales_orders', NULL, @ErrorMessage, 0);
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- Procedure: usp_bronze_load_sap_invoices
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_bronze_load_sap_invoices
    @BatchSize INT = 10000,
    @LoadId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @LastWatermark DATETIME2;
    
    IF @LoadId IS NULL
        SET @LoadId = NEWID();
    
    BEGIN TRY
        SELECT @LastWatermark = last_watermark_value
        FROM etl.etl_watermarks
        WHERE source_system = 'sap' AND source_table = 'invoices';
        
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        INSERT INTO stage.stage_sap_invoices (
            source_system, load_id, last_modified, is_deleted, natural_key,
            INVNUM, VBELN, FKDAT, NETWR, MWSBK, KUNRG, WAERS
        )
        SELECT TOP (@BatchSize)
            'sap',
            @LoadId,
            GETDATE(),
            0,
            CAST(INVNUM AS NVARCHAR(255)),
            INVNUM,
            VBELN,
            FKDAT,
            NETWR,
            MWSBK,
            KUNRG,
            WAERS
        FROM (
            SELECT 'INV001' AS INVNUM, 'VB001' AS VBELN, GETDATE() AS FKDAT, 5000.00 AS NETWR, 500.00 AS MWSBK, 'KUN001' AS KUNRG, 'USD' AS WAERS
        ) AS SimulatedSource
        WHERE NOT EXISTS (
            SELECT 1 FROM stage.stage_sap_invoices si
            WHERE si.INVNUM = INVNUM AND si.load_id = @LoadId
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
        MERGE INTO etl.etl_watermarks AS target
        USING (SELECT 'sap' AS source_system, 'invoices' AS source_table, SYSDATETIME() AS last_watermark_value) AS source
        ON target.source_system = source.source_system AND target.source_table = source.source_table
        WHEN MATCHED THEN
            UPDATE SET last_watermark_value = source.last_watermark_value, updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (source_system, source_table, watermark_column, last_watermark_value)
            VALUES (source.source_system, source.source_table, 'MODIFIED_TS', source.last_watermark_value);
        
        COMMIT TRANSACTION;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE() + ' (Line: ' + CAST(ERROR_LINE() AS NVARCHAR(10)) + ')';
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Failed', error_message = @ErrorMessage
        WHERE job_id = @JobId;
        
        INSERT INTO etl.dead_letter (source_system, source_table, payload, error_message, retry_count)
        VALUES ('sap', 'invoices', NULL, @ErrorMessage, 0);
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- Procedure: usp_bronze_load_custom_inventory
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_bronze_load_custom_inventory
    @BatchSize INT = 10000,
    @LoadId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @LastWatermark DATETIME2;
    
    IF @LoadId IS NULL
        SET @LoadId = NEWID();
    
    BEGIN TRY
        SELECT @LastWatermark = last_watermark_value
        FROM etl.etl_watermarks
        WHERE source_system = 'custom' AND source_table = 'inventory';
        
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- Custom ERP uses updated_at watermark
        INSERT INTO stage.stage_custom_inventory (
            source_system, load_id, last_modified, is_deleted, natural_key,
            inventory_id, product_sku, warehouse_code, quantity_on_hand,
            quantity_reserved, quantity_available, unit_cost, last_updated
        )
        SELECT TOP (@BatchSize)
            'custom',
            @LoadId,
            GETDATE(),
            0,
            CAST(product_sku + '_' + warehouse_code AS NVARCHAR(255)),
            inventory_id,
            product_sku,
            warehouse_code,
            quantity_on_hand,
            quantity_reserved,
            quantity_available,
            unit_cost,
            last_updated
        FROM (
            SELECT 'INV001' AS inventory_id, 'SKU001' AS product_sku, 'WH001' AS warehouse_code,
                   100.00 AS quantity_on_hand, 10.00 AS quantity_reserved, 90.00 AS quantity_available,
                   25.00 AS unit_cost, GETDATE() AS last_updated
        ) AS SimulatedSource
        WHERE NOT EXISTS (
            SELECT 1 FROM stage.stage_custom_inventory ci
            WHERE ci.inventory_id = inventory_id AND ci.load_id = @LoadId
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
        MERGE INTO etl.etl_watermarks AS target
        USING (SELECT 'custom' AS source_system, 'inventory' AS source_table, SYSDATETIME() AS last_watermark_value) AS source
        ON target.source_system = source.source_system AND target.source_table = source.source_table
        WHEN MATCHED THEN
            UPDATE SET last_watermark_value = source.last_watermark_value, updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (source_system, source_table, watermark_column, last_watermark_value)
            VALUES (source.source_system, source.source_table, 'updated_at', source.last_watermark_value);
        
        COMMIT TRANSACTION;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE() + ' (Line: ' + CAST(ERROR_LINE() AS NVARCHAR(10)) + ')';
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Failed', error_message = @ErrorMessage
        WHERE job_id = @JobId;
        
        INSERT INTO etl.dead_letter (source_system, source_table, payload, error_message, retry_count)
        VALUES ('custom', 'inventory', NULL, @ErrorMessage, 0);
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

PRINT 'Bronze ETL procedures created successfully.';
GO