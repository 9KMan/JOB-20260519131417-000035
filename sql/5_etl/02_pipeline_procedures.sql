-- ============================================================================
-- ETL PIPELINE AUTOMATION - Stored Procedures
-- Centralized logging, error handling, and pipeline orchestration
-- ============================================================================

-- ============================================================================
-- usp_etl_log_step_start
-- Logs the start of a pipeline step
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_log_step_start', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_log_step_start;
GO

CREATE PROC etl.usp_etl_log_step_start
    @PipelineName NVARCHAR(100),
    @StepName NVARCHAR(100) = NULL,
    @StepOrder INT = NULL,
    @BatchID UNIQUEIDENTIFIER = NULL,
    @SourceSystem NVARCHAR(50) = NULL,
    @TargetSchema NVARCHAR(50) = NULL,
    @TargetTable NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO etl.pipeline_log (
        JobID, PipelineName, StepName, StepOrder, Status, StartTime,
        BatchID, SourceSystem, TargetSchema, TargetTable
    )
    VALUES (
        NEWID(), @PipelineName, @StepName, @StepOrder, 'running', SYSDATETIME(),
        @BatchID, @SourceSystem, @TargetSchema, @TargetTable
    );

    SELECT SCOPE_IDENTITY() AS LogID;
END
GO

-- ============================================================================
-- usp_etl_log_step_end
-- Logs the completion of a pipeline step
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_log_step_end', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_log_step_end;
GO

CREATE PROC etl.usp_etl_log_step_end
    @LogID BIGINT,
    @Status NVARCHAR(20),
    @RowsProcessed INT = 0,
    @RowsAffected INT = 0,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @WarningMessage NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE etl.pipeline_log
    SET
        EndTime = SYSDATETIME(),
        DurationSeconds = DATEDIFF(SECOND, StartTime, SYSDATETIME()),
        Status = @Status,
        RowsProcessed = @RowsProcessed,
        RowsAffected = @RowsAffected,
        ErrorMessage = @ErrorMessage,
        ErrorSeverity = CASE WHEN @ErrorMessage IS NOT NULL THEN ERROR_SEVERITY() ELSE NULL END,
        ErrorNumber = CASE WHEN @ErrorMessage IS NOT NULL THEN ERROR_NUMBER() ELSE NULL END,
        WarningMessage = @WarningMessage
    WHERE LogID = @LogID;
END
GO

-- ============================================================================
-- usp_etl_log_to_dead_letter
-- Sends failed records to dead letter queue
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_log_to_dead_letter', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_log_to_dead_letter;
GO

CREATE PROC etl.usp_etl_log_to_dead_letter
    @JobID UNIQUEIDENTIFIER,
    @SourceSystem NVARCHAR(50),
    @SourceTable NVARCHAR(100),
    @SourceRecordID NVARCHAR(100) = NULL,
    @SourceData NVARCHAR(MAX) = NULL,
    @ErrorMessage NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO etl.dead_letter (
        JobID, SourceSystem, SourceTable, SourceRecordID, SourceData, ErrorMessage
    )
    VALUES (
        @JobID, @SourceSystem, @SourceTable, @SourceRecordID, @SourceData, @ErrorMessage
    );
END
GO

-- ============================================================================
-- usp_etl_update_pipeline_stats
-- Updates aggregated statistics after pipeline run
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_update_pipeline_stats', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_update_pipeline_stats;
GO

CREATE PROC etl.usp_etl_update_pipeline_stats
    @JobID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PipelineName NVARCHAR(100);
    DECLARE @StartTime DATETIME2;
    DECLARE @EndTime DATETIME2;
    DECLARE @TotalRows INT;
    DECLARE @TotalSteps INT;
    DECLARE @SuccessSteps INT;
    DECLARE @FailedSteps INT;
    DECLARE @WarningSteps INT;
    DECLARE @Status NVARCHAR(20);

    -- Get pipeline name and times from first log entry
    SELECT
        @PipelineName = PipelineName,
        @StartTime = StartTime
    FROM etl.pipeline_log
    WHERE JobID = @JobID;

    -- Aggregate step results
    SELECT
        @TotalSteps = COUNT(*),
        @SuccessSteps = SUM(CASE WHEN Status = 'success' THEN 1 ELSE 0 END),
        @FailedSteps = SUM(CASE WHEN Status = 'failed' THEN 1 ELSE 0 END),
        @WarningSteps = SUM(CASE WHEN Status = 'warning' THEN 1 ELSE 0 END),
        @TotalRows = SUM(ISNULL(RowsProcessed, 0)),
        @EndTime = MAX(EndTime)
    FROM etl.pipeline_log
    WHERE JobID = @JobID;

    -- Determine overall status
    IF @FailedSteps > 0
        SET @Status = 'failed';
    ELSE IF @WarningSteps > 0
        SET @Status = 'warning';
    ELSE
        SET @Status = 'success';

    -- Insert/update stats
    MERGE INTO etl.pipeline_stats AS target
    USING (SELECT @JobID AS JobID) AS source
    ON target.JobID = source.JobID
    WHEN NOT MATCHED THEN
        INSERT (JobID, PipelineName, StartTime, EndTime, DurationSeconds, TotalRowsProcessed,
                TotalSteps, SuccessfulSteps, FailedSteps, WarningSteps, Status)
        VALUES (@JobID, @PipelineName, @StartTime, @EndTime,
                DATEDIFF(SECOND, @StartTime, @EndTime),
                @TotalRows, @TotalSteps, @SuccessSteps, @FailedSteps, @WarningSteps, @Status)
    WHEN MATCHED THEN
        UPDATE SET
            EndTime = @EndTime,
            DurationSeconds = DATEDIFF(SECOND, @StartTime, @EndTime),
            TotalRowsProcessed = @TotalRows,
            TotalSteps = @TotalSteps,
            SuccessfulSteps = @SuccessSteps,
            FailedSteps = @FailedSteps,
            WarningSteps = @WarningSteps,
            Status = @Status;

    -- Update pipeline config with last run time
    UPDATE etl.pipeline_config
    SET LastRunTime = @StartTime
    WHERE PipelineName = @PipelineName;
END
GO

-- ============================================================================
-- usp_etl_run_bronze_load
-- Orchestrates bronze layer load with logging
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_run_bronze_load', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_run_bronze_load;
GO

CREATE PROC etl.usp_etl_run_bronze_load
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JobID UNIQUEIDENTIFIER = NEWID();
    DECLARE @LogID BIGINT;
    DECLARE @Status NVARCHAR(20) = 'success';
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);

    BEGIN TRY
        PRINT 'Starting Bronze Layer Load - Job: ' + CAST(@JobID AS NVARCHAR(50));

        -- Step 1: Load Sage Sales Orders
        EXEC @LogID = etl.usp_etl_log_step_start
            @PipelineName = 'bronze_layer_load',
            @StepName = 'load_sage_sales_orders',
            @StepOrder = 1,
            @BatchID = @JobID,
            @SourceSystem = 'sage_erp';

        BEGIN TRY
            EXEC bronze.usp_bronze_load_sage_sales_orders;
            SET @RowsProcessed = @@ROWCOUNT;
            EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
            SET @Status = 'failed';
        END CATCH

        -- Step 2: Load Sage Invoices
        IF @Status = 'success' OR @Status = 'warning'
        BEGIN
            EXEC @LogID = etl.usp_etl_log_step_start
                @PipelineName = 'bronze_layer_load',
                @StepName = 'load_sage_invoices',
                @StepOrder = 2,
                @BatchID = @JobID,
                @SourceSystem = 'sage_erp';

            BEGIN TRY
                EXEC bronze.usp_bronze_load_sage_invoices;
                SET @RowsProcessed = @@ROWCOUNT;
                EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();
                EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
                SET @Status = 'failed';
            END CATCH
        END

        -- Step 3: Load SAP Sales Orders
        IF @Status = 'success' OR @Status = 'warning'
        BEGIN
            EXEC @LogID = etl.usp_etl_log_step_start
                @PipelineName = 'bronze_layer_load',
                @StepName = 'load_sap_sales_orders',
                @StepOrder = 3,
                @BatchID = @JobID,
                @SourceSystem = 'sap_erp';

            BEGIN TRY
                EXEC bronze.usp_bronze_load_sap_sales_orders;
                SET @RowsProcessed = @@ROWCOUNT;
                EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();
                EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
                SET @Status = 'failed';
            END CATCH
        END

        -- Step 4: Load Custom Inventory
        IF @Status = 'success' OR @Status = 'warning'
        BEGIN
            EXEC @LogID = etl.usp_etl_log_step_start
                @PipelineName = 'bronze_layer_load',
                @StepName = 'load_custom_inventory',
                @StepOrder = 4,
                @BatchID = @JobID,
                @SourceSystem = 'custom_erp';

            BEGIN TRY
                EXEC bronze.usp_bronze_load_custom_inventory;
                SET @RowsProcessed = @@ROWCOUNT;
                EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();
                EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
                SET @Status = 'failed';
            END CATCH
        END

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Bronze Layer Load Failed: ' + @ErrorMessage;
        SET @Status = 'failed';
    END CATCH

    -- Update stats
    EXEC etl.usp_etl_update_pipeline_stats @JobID;

    PRINT 'Bronze Layer Load Complete - Status: ' + @Status;
    RETURN CASE WHEN @Status = 'failed' THEN 1 ELSE 0 END;
END
GO

-- ============================================================================
-- usp_etl_run_silver_mapping
-- Orchestrates silver layer mapping with logging
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_run_silver_mapping', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_run_silver_mapping;
GO

CREATE PROC etl.usp_etl_run_silver_mapping
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JobID UNIQUEIDENTIFIER = NEWID();
    DECLARE @LogID BIGINT;
    DECLARE @Status NVARCHAR(20) = 'success';
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);

    BEGIN TRY
        PRINT 'Starting Silver Layer Mapping - Job: ' + CAST(@JobID AS NVARCHAR(50));

        -- Map Sales Orders
        EXEC @LogID = etl.usp_etl_log_step_start
            @PipelineName = 'silver_layer_map',
            @StepName = 'map_sales_orders',
            @StepOrder = 1,
            @BatchID = @JobID;

        BEGIN TRY
            EXEC silver.usp_silver_map_sales_orders;
            SET @RowsProcessed = @@ROWCOUNT;
            EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
            SET @Status = 'failed';
        END CATCH

        -- Map Invoices
        IF @Status = 'success' OR @Status = 'warning'
        BEGIN
            EXEC @LogID = etl.usp_etl_log_step_start
                @PipelineName = 'silver_layer_map',
                @StepName = 'map_invoices',
                @StepOrder = 2,
                @BatchID = @JobID;

            BEGIN TRY
                EXEC silver.usp_silver_map_invoices;
                SET @RowsProcessed = @@ROWCOUNT;
                EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();
                EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
                SET @Status = 'failed';
            END CATCH
        END

        -- Map Shipments
        IF @Status = 'success' OR @Status = 'warning'
        BEGIN
            EXEC @LogID = etl.usp_etl_log_step_start
                @PipelineName = 'silver_layer_map',
                @StepName = 'map_shipments',
                @StepOrder = 3,
                @BatchID = @JobID;

            BEGIN TRY
                EXEC silver.usp_silver_map_shipments;
                SET @RowsProcessed = @@ROWCOUNT;
                EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();
                EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
                SET @Status = 'failed';
            END CATCH
        END

        -- Map Inventory
        IF @Status = 'success' OR @Status = 'warning'
        BEGIN
            EXEC @LogID = etl.usp_etl_log_step_start
                @PipelineName = 'silver_layer_map',
                @StepName = 'map_inventory',
                @StepOrder = 4,
                @BatchID = @JobID;

            BEGIN TRY
                EXEC silver.usp_silver_map_inventory;
                SET @RowsProcessed = @@ROWCOUNT;
                EXEC etl.usp_etl_log_step_end @LogID, 'success', @RowsProcessed, @RowsProcessed;
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();
                EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
                SET @Status = 'failed';
            END CATCH
        END

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Silver Layer Mapping Failed: ' + @ErrorMessage;
        SET @Status = 'failed';
    END CATCH

    EXEC etl.usp_etl_update_pipeline_stats @JobID;

    PRINT 'Silver Layer Mapping Complete - Status: ' + @Status;
    RETURN CASE WHEN @Status = 'failed' THEN 1 ELSE 0 END;
END
GO

-- ============================================================================
-- usp_etl_run_gold_load
-- Orchestrates gold layer load with logging
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_run_gold_load', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_run_gold_load;
GO

CREATE PROC etl.usp_etl_run_gold_load
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JobID UNIQUEIDENTIFIER = NEWID();
    DECLARE @LogID BIGINT;
    DECLARE @Status NVARCHAR(20) = 'success';
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);

    BEGIN TRY
        PRINT 'Starting Gold Layer Load - Job: ' + CAST(@JobID AS NVARCHAR(50));

        -- Load Dimensions (SCD Type 2)
        EXEC @LogID = etl.usp_etl_log_step_start
            @PipelineName = 'gold_layer_load',
            @StepName = 'load_dimensions',
            @StepOrder = 1,
            @BatchID = @JobID;

        BEGIN TRY
            EXEC gold.usp_gold_scd2_product;
            EXEC gold.usp_gold_scd2_customer;
            EXEC gold.usp_gold_scd2_vendor;
            EXEC gold.usp_gold_scd2_location;
            EXEC etl.usp_etl_log_step_end @LogID, 'success', 0, 0;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
            SET @Status = 'failed';
        END CATCH

        -- Load Facts
        IF @Status = 'success' OR @Status = 'warning'
        BEGIN
            EXEC @LogID = etl.usp_etl_log_step_start
                @PipelineName = 'gold_layer_load',
                @StepName = 'load_facts',
                @StepOrder = 2,
                @BatchID = @JobID;

            BEGIN TRY
                EXEC gold.usp_gold_load_fact_sales_order;
                EXEC gold.usp_gold_load_fact_inventory;
                EXEC etl.usp_etl_log_step_end @LogID, 'success', 0, 0;
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();
                EXEC etl.usp_etl_log_step_end @LogID, 'failed', 0, 0, @ErrorMessage;
                SET @Status = 'failed';
            END CATCH
        END

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Gold Layer Load Failed: ' + @ErrorMessage;
        SET @Status = 'failed';
    END CATCH

    EXEC etl.usp_etl_update_pipeline_stats @JobID;

    PRINT 'Gold Layer Load Complete - Status: ' + @Status;
    RETURN CASE WHEN @Status = 'failed' THEN 1 ELSE 0 END;
END
GO

-- ============================================================================
-- usp_etl_run_full_pipeline
-- Master procedure to run complete ETL pipeline
-- Bronze -> Silver -> Gold
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_run_full_pipeline', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_run_full_pipeline;
GO

CREATE PROC etl.usp_etl_run_full_pipeline
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OverallStatus NVARCHAR(20) = 'success';
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @ReturnCode INT = 0;

    PRINT '==================================================';
    PRINT 'Starting Full ETL Pipeline - ' + CONVERT(NVARCHAR(30), SYSDATETIME(), 120);
    PRINT '==================================================';

    -- Step 1: Bronze Layer
    PRINT '';
    PRINT '--- BRONZE LAYER ---';
    EXEC @ReturnCode = etl.usp_etl_run_bronze_load;
    IF @ReturnCode <> 0
    BEGIN
        SET @OverallStatus = 'failed';
        PRINT 'WARNING: Bronze layer completed with errors';
    END

    -- Step 2: Silver Layer
    PRINT '';
    PRINT '--- SILVER LAYER ---';
    EXEC @ReturnCode = etl.usp_etl_run_silver_mapping;
    IF @ReturnCode <> 0
    BEGIN
        SET @OverallStatus = 'failed';
        PRINT 'WARNING: Silver layer completed with errors';
    END

    -- Step 3: Gold Layer
    PRINT '';
    PRINT '--- GOLD LAYER ---';
    EXEC @ReturnCode = etl.usp_etl_run_gold_load;
    IF @ReturnCode <> 0
    BEGIN
        SET @OverallStatus = 'failed';
        PRINT 'WARNING: Gold layer completed with errors';
    END

    PRINT '';
    PRINT '==================================================';
    PRINT 'Full ETL Pipeline Complete - Status: ' + @OverallStatus;
    PRINT '==================================================';

    RETURN CASE WHEN @OverallStatus = 'failed' THEN 1 ELSE 0 END;
END
GO

-- ============================================================================
-- usp_etl_get_pipeline_status
-- Get current pipeline execution status
-- ============================================================================
IF OBJECT_ID('etl.usp_etl_get_pipeline_status', 'P') IS NOT NULL
    DROP PROC etl.usp_etl_get_pipeline_status;
GO

CREATE PROC etl.usp_etl_get_pipeline_status
    @DaysToShow INT = 7
AS
BEGIN
    SET NOCOUNT ON;

    -- Current running pipelines
    SELECT
        'Running Pipelines' AS Category,
        pl.PipelineName,
        pl.StepName,
        pl.Status,
        pl.StartTime,
        DATEDIFF(SECOND, pl.StartTime, SYSDATETIME()) AS RunningSeconds,
        pl.HostName
    FROM etl.pipeline_log pl
    WHERE pl.Status = 'running'
    AND pl.StartTime >= DATEADD(DAY, -@DaysToShow, SYSDATETIME())
    ORDER BY pl.StartTime DESC;

    -- Recent pipeline stats
    SELECT
        'Recent Pipeline Runs' AS Category,
        ps.PipelineName,
        ps.RunDate,
        ps.StartTime,
        ps.EndTime,
        ps.DurationSeconds,
        ps.TotalRowsProcessed,
        ps.TotalSteps,
        ps.SuccessfulSteps,
        ps.FailedSteps,
        ps.Status
    FROM etl.pipeline_stats ps
    WHERE ps.RunDate >= DATEADD(DAY, -@DaysToShow, CAST(SYSDATETIME() AS DATE))
    ORDER BY ps.StartTime DESC;

    -- Failed steps requiring attention
    SELECT
        'Failed Steps' AS Category,
        pl.PipelineName,
        pl.StepName,
        pl.StartTime,
        pl.ErrorMessage,
        pl.HostName
    FROM etl.pipeline_log pl
    WHERE pl.Status = 'failed'
    AND pl.StartTime >= DATEADD(DAY, -@DaysToShow, SYSDATETIME())
    ORDER BY pl.StartTime DESC;

    -- Dead letter queue count
    SELECT
        'Dead Letter Queue' AS Category,
        COUNT(*) AS PendingRecords,
        MIN(InsertedAt) AS OldestRecord,
        MAX(InsertedAt) AS NewestRecord,
        SourceSystem,
        SourceTable
    FROM etl.dead_letter
    WHERE ProcessedAt IS NULL
    GROUP BY SourceSystem, SourceTable;
END
GO

PRINT 'ETL pipeline procedures created successfully.';
GO