-- ============================================================================
-- Pipeline Automation Procedures
-- ============================================================================
-- Procedures to orchestrate ETL pipeline execution.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- usp_etl_run_bronze_load
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_etl_run_bronze_load
    @LoadId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @LoadCount INT;
    
    IF @LoadId IS NULL
        SET @LoadId = NEWID();
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        -- Execute all bronze load procedures
        EXEC @LoadCount = etl.usp_bronze_load_sage_sales_orders @LoadId = @LoadId OUTPUT;
        SET @RowsProcessed = @RowsProcessed + @LoadCount;
        
        EXEC @LoadCount = etl.usp_bronze_load_sage_invoices @LoadId = @LoadId OUTPUT;
        SET @RowsProcessed = @RowsProcessed + @LoadCount;
        
        EXEC @LoadCount = etl.usp_bronze_load_sap_sales_orders @LoadId = @LoadId OUTPUT;
        SET @RowsProcessed = @RowsProcessed + @LoadCount;
        
        EXEC @LoadCount = etl.usp_bronze_load_sap_invoices @LoadId = @LoadId OUTPUT;
        SET @RowsProcessed = @RowsProcessed + @LoadCount;
        
        EXEC @LoadCount = etl.usp_bronze_load_custom_inventory @LoadId = @LoadId OUTPUT;
        SET @RowsProcessed = @RowsProcessed + @LoadCount;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
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
-- usp_etl_run_silver_transform
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_etl_run_silver_transform
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @ProcCount INT;
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        EXEC @ProcCount = silver.usp_silver_standardize_sales_orders;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = silver.usp_silver_standardize_invoices;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = silver.usp_silver_standardize_customers;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = silver.usp_silver_standardize_products;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
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
-- usp_etl_run_gold_load
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_etl_run_gold_load
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @ProcCount INT;
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        -- Dimensions first
        EXEC @ProcCount = gold.usp_gold_dim_date;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_dim_currency;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_dim_product;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_dim_customer;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_dim_vendor;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_dim_location;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        -- Facts
        EXEC @ProcCount = gold.usp_gold_fact_sales_order;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_fact_inventory;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_fact_procurement;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        EXEC @ProcCount = gold.usp_gold_fact_shipment;
        SET @RowsProcessed = @RowsProcessed + @ProcCount;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
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
-- usp_etl_full_pipeline
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_etl_full_pipeline
    @LoadId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @BronzeRows INT;
    DECLARE @SilverRows INT;
    DECLARE @GoldRows INT;
    
    IF @LoadId IS NULL
        SET @LoadId = NEWID();
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        -- Bronze Layer
        EXEC @BronzeRows = etl.usp_etl_run_bronze_load @LoadId = @LoadId OUTPUT;
        SET @RowsProcessed = @RowsProcessed + @BronzeRows;
        
        -- Silver Layer
        EXEC @SilverRows = etl.usp_etl_run_silver_transform;
        SET @RowsProcessed = @RowsProcessed + @SilverRows;
        
        -- Gold Layer
        EXEC @GoldRows = etl.usp_etl_run_gold_load;
        SET @RowsProcessed = @RowsProcessed + @GoldRows;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE() + ' (Line: ' + CAST(ERROR_LINE() AS NVARCHAR(10)) + ')';
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Failed', error_message = @ErrorMessage
        WHERE job_id = @JobId;
        
        -- Insert full pipeline failure to dead letter
        INSERT INTO etl.dead_letter (source_system, source_table, payload, error_message, retry_count)
        VALUES ('pipeline', 'full_pipeline', NULL, @ErrorMessage, 0);
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

-- ============================================================================
-- usp_etl_cleanup_old_watermarks
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_etl_cleanup_old_watermarks
    @RetentionDays INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RowsDeleted INT = 0;
    
    DELETE FROM etl.etl_watermarks
    WHERE updated_at < DATEADD(DAY, -@RetentionDays, SYSDATETIME());
    
    SET @RowsDeleted = @@ROWCOUNT;
    
    RETURN @RowsDeleted;
END
GO

-- ============================================================================
-- usp_etl_retry_dead_letter
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_etl_retry_dead_letter
    @MaxRetries INT = 3
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        -- Retry failed records that haven't exceeded max retries
        UPDATE etl.dead_letter
        SET retry_count = retry_count + 1,
            last_retry_at = SYSDATETIME()
        WHERE resolved_at IS NULL
        AND retry_count < @MaxRetries
        AND error_message IS NOT NULL;
        
        SET @RowsProcessed = @@ROWCOUNT;
        
        -- Mark as resolved if max retries reached
        UPDATE etl.dead_letter
        SET resolved_at = SYSDATETIME()
        WHERE retry_count >= @MaxRetries
        AND resolved_at IS NULL;
        
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Success', rows_processed = @RowsProcessed
        WHERE job_id = @JobId;
        
    END TRY
    BEGIN CATCH
        UPDATE etl.pipeline_log
        SET end_time = SYSDATETIME(), status = 'Failed', error_message = ERROR_MESSAGE()
        WHERE job_id = @JobId;
        
        THROW;
        
    END CATCH
    
    RETURN @RowsProcessed;
END
GO

PRINT 'Pipeline automation procedures created successfully.';
GO