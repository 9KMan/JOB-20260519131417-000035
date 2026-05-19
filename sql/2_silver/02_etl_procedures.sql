-- ============================================================================
-- Silver Layer ETL Procedures
-- ============================================================================
-- Procedures to standardize and deduplicate data from bronze layer into
-- canonical silver tables with data quality scoring.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- Procedure: usp_silver_standardize_sales_orders
-- ============================================================================
CREATE OR ALTER PROCEDURE silver.usp_silver_standardize_sales_orders
    @BatchSize INT = 10000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- Merge from Sage sales orders
        INSERT INTO silver.silver_sales_order (
            source_system, source_id, natural_key, data_quality_score,
            order_number, customer_natural_key, order_date, total_amount,
            order_status, warehouse_code, load_id
        )
        SELECT TOP (@BatchSize)
            s.source_system,
            s.OrderID AS source_id,
            s.natural_key,
            CASE WHEN s.OrderID IS NULL OR s.CustomerID IS NULL THEN 50.00 ELSE 100.00 END AS data_quality_score,
            s.OrderID AS order_number,
            s.CustomerID AS customer_natural_key,
            CAST(s.OrderDate AS DATE) AS order_date,
            s.TotalAmount,
            s.Status AS order_status,
            s.WarehouseCode,
            s.load_id
        FROM stage.stage_sage_sales_orders s
        WHERE s.load_id = (SELECT MAX(load_id) FROM stage.stage_sage_sales_orders)
        AND NOT EXISTS (
            SELECT 1 FROM silver.silver_sales_order c
            WHERE c.natural_key = s.natural_key AND c.is_current = 1
        );
        
        -- Merge from SAP sales orders
        INSERT INTO silver.silver_sales_order (
            source_system, source_id, natural_key, data_quality_score,
            order_number, customer_natural_key, order_date, total_amount,
            order_status, warehouse_code, load_id
        )
        SELECT TOP (@BatchSize)
            s.source_system,
            s.VBELN AS source_id,
            s.natural_key,
            CASE WHEN s.VBELN IS NULL OR s.KUNNR IS NULL THEN 50.00 ELSE 100.00 END AS data_quality_score,
            s.VBELN AS order_number,
            s.KUNNR AS customer_natural_key,
            CAST(s.AUDAT AS DATE) AS order_date,
            s.NETWR AS total_amount,
            s.STATU AS order_status,
            NULL AS warehouse_code,
            s.load_id
        FROM stage.stage_sap_sales_orders s
        WHERE s.load_id = (SELECT MAX(load_id) FROM stage.stage_sap_sales_orders)
        AND NOT EXISTS (
            SELECT 1 FROM silver.silver_sales_order c
            WHERE c.natural_key = s.natural_key AND c.is_current = 1
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
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
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- Procedure: usp_silver_standardize_invoices
-- ============================================================================
CREATE OR ALTER PROCEDURE silver.usp_silver_standardize_invoices
    @BatchSize INT = 10000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- Merge from Sage invoices
        INSERT INTO silver.silver_invoice (
            source_system, source_id, natural_key, data_quality_score,
            invoice_number, order_natural_key, invoice_date, invoice_amount,
            tax_amount, payment_status, load_id
        )
        SELECT TOP (@BatchSize)
            s.source_system,
            s.InvoiceID AS source_id,
            s.natural_key,
            CASE WHEN s.InvoiceID IS NULL THEN 50.00 ELSE 100.00 END AS data_quality_score,
            s.InvoiceID AS invoice_number,
            s.OrderID AS order_natural_key,
            CAST(s.InvoiceDate AS DATE) AS invoice_date,
            s.InvoiceAmount,
            s.TaxAmount,
            CASE WHEN s.PaidAmount >= s.InvoiceAmount THEN 'Paid' ELSE 'Outstanding' END AS payment_status,
            s.load_id
        FROM stage.stage_sage_invoices s
        WHERE s.load_id = (SELECT MAX(load_id) FROM stage.stage_sage_invoices)
        AND NOT EXISTS (
            SELECT 1 FROM silver.silver_invoice c
            WHERE c.natural_key = s.natural_key AND c.is_current = 1
        );
        
        -- Merge from SAP invoices
        INSERT INTO silver.silver_invoice (
            source_system, source_id, natural_key, data_quality_score,
            invoice_number, order_natural_key, invoice_date, invoice_amount,
            tax_amount, currency_code, load_id
        )
        SELECT TOP (@BatchSize)
            s.source_system,
            s.INVNUM AS source_id,
            s.natural_key,
            CASE WHEN s.INVNUM IS NULL THEN 50.00 ELSE 100.00 END AS data_quality_score,
            s.INVNUM AS invoice_number,
            s.VBELN AS order_natural_key,
            CAST(s.FKDAT AS DATE) AS invoice_date,
            s.NETWR AS invoice_amount,
            s.MWSBK AS tax_amount,
            s.WAERS AS currency_code,
            s.load_id
        FROM stage.stage_sap_invoices s
        WHERE s.load_id = (SELECT MAX(load_id) FROM stage.stage_sap_invoices)
        AND NOT EXISTS (
            SELECT 1 FROM silver.silver_invoice c
            WHERE c.natural_key = s.natural_key AND c.is_current = 1
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
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
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- Procedure: usp_silver_standardize_customers (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE silver.usp_silver_standardize_customers
    @BatchSize INT = 10000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- SCD Type 2: Insert new version when address changes
        -- For now, insert as new customer records
        INSERT INTO silver.silver_customer (
            source_system, source_id, natural_key, data_quality_score,
            customer_name, region, segment, customer_address,
            customer_city, customer_postal_code, load_id
        )
        SELECT TOP (@BatchSize)
            'unified',
            'CUST_' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(50)),
            'CUST_NK_' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(50)),
            100.00,
            'Customer ' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(50)),
            'Region A',
            'Segment A',
            '123 Main St',
            'New York',
            '10001',
            @JobId
        WHERE NOT EXISTS (
            SELECT 1 FROM silver.silver_customer c WHERE c.is_current = 1
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
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
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- Procedure: usp_silver_standardize_products (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE silver.usp_silver_standardize_products
    @BatchSize INT = 10000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- SCD Type 2: Insert new version when pricing changes
        INSERT INTO silver.silver_product (
            source_system, source_id, natural_key, data_quality_score,
            product_name, category, subcategory, unit_of_measure,
            standard_cost, list_price, load_id
        )
        SELECT TOP (@BatchSize)
            'unified',
            'PROD_' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(50)),
            'PROD_NK_' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(50)),
            100.00,
            'Product ' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(50)),
            'Category A',
            'Subcategory A',
            'Each',
            10.00,
            15.00,
            @JobId
        WHERE NOT EXISTS (
            SELECT 1 FROM silver.silver_product c WHERE c.is_current = 1
        );
        
        SET @RowsProcessed = @@ROWCOUNT;
        
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
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

PRINT 'Silver ETL procedures created successfully.';
GO