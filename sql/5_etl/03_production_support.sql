-- ============================================================================
-- Production Support Diagnostic Procedures
-- ============================================================================
-- Procedures for monitoring and diagnosing pipeline health.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- usp_diag_slow_queries
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_diag_slow_queries
    @ThresholdMs INT = 5000,
    @DaysToAnalyze INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT
        job_name,
        COUNT(*) AS execution_count,
        AVG(DATEDIFF(MILLISECOND, start_time, end_time)) AS avg_duration_ms,
        MAX(DATEDIFF(MILLISECOND, start_time, end_time)) AS max_duration_ms,
        MIN(DATEDIFF(MILLISECOND, start_time, end_time)) AS min_duration_ms,
        MAX(end_time) AS last_run
    FROM etl.pipeline_log
    WHERE start_time >= DATEADD(DAY, -@DaysToAnalyze, SYSDATETIME())
    AND status = 'Success'
    GROUP BY job_name
    HAVING AVG(DATEDIFF(MILLISECOND, start_time, end_time)) > @ThresholdMs
    ORDER BY avg_duration_ms DESC;
    
    RETURN 0;
END
GO

-- ============================================================================
-- usp_diag_data_gaps
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_diag_data_gaps
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check for missing dates in DimDate
    SELECT 'DimDate' AS table_name, 'Missing dates' AS gap_type, COUNT(*) AS gap_count
    FROM (
        SELECT DATEADD(DAY, 1, FullDate) AS missing_date
        FROM gold.DimDate d1
        WHERE NOT EXISTS (
            SELECT 1 FROM gold.DimDate d2
            WHERE d2.FullDate = DATEADD(DAY, 1, d1.FullDate)
        )
        AND d1.FullDate < (SELECT MAX(FullDate) FROM gold.DimDate)
    ) AS gaps;
    
    -- Check for orphaned fact records (missing date keys)
    SELECT 'FactSalesOrder' AS table_name, 'Missing DateKey' AS gap_type, COUNT(*) AS gap_count
    FROM gold.FactSalesOrder f
    WHERE NOT EXISTS (SELECT 1 FROM gold.DimDate d WHERE d.DateKey = f.DateKey);
    
    SELECT 'FactInventory' AS table_name, 'Missing DateKey' AS gap_type, COUNT(*) AS gap_count
    FROM gold.FactInventory f
    WHERE NOT EXISTS (SELECT 1 FROM gold.DimDate d WHERE d.DateKey = f.DateKey);
    
    SELECT 'FactProcurement' AS table_name, 'Missing DateKey' AS gap_type, COUNT(*) AS gap_count
    FROM gold.FactProcurement f
    WHERE NOT EXISTS (SELECT 1 FROM gold.DimDate d WHERE d.DateKey = f.DateKey);
    
    SELECT 'FactShipment' AS table_name, 'Missing DateKey' AS gap_type, COUNT(*) AS gap_count
    FROM gold.FactShipment f
    WHERE NOT EXISTS (SELECT 1 FROM gold.DimDate d WHERE d.DateKey = f.DateKey);
    
    RETURN 0;
END
GO

-- ============================================================================
-- usp_diag_watermark_staleness
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_diag_watermark_staleness
    @StaleThresholdHours INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT
        source_system,
        source_table,
        watermark_column,
        last_watermark_value,
        updated_at,
        DATEDIFF(HOUR, updated_at, SYSDATETIME()) AS hours_since_update,
        CASE
            WHEN DATEDIFF(HOUR, updated_at, SYSDATETIME()) > @StaleThresholdHours THEN 'STALE'
            ELSE 'OK'
        END AS status
    FROM etl.etl_watermarks
    ORDER BY updated_at ASC;
    
    RETURN 0;
END
GO

-- ============================================================================
-- usp_diag_referential_integrity
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_diag_referential_integrity
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check orphaned CustomerKey in FactSalesOrder
    SELECT 'FactSalesOrder' AS table_name, 'CustomerKey' AS foreign_key, 'orphaned' AS issue_type, COUNT(*) AS record_count
    FROM gold.FactSalesOrder f
    WHERE f.CustomerKey < 0
    OR NOT EXISTS (SELECT 1 FROM gold.DimCustomer d WHERE d.CustomerKey = f.CustomerKey);
    
    -- Check orphaned ProductKey
    SELECT 'FactSalesOrder' AS table_name, 'ProductKey' AS foreign_key, 'orphaned' AS issue_type, COUNT(*) AS record_count
    FROM gold.FactSalesOrder f
    WHERE f.ProductKey < 0
    OR NOT EXISTS (SELECT 1 FROM gold.DimProduct d WHERE d.ProductKey = f.ProductKey);
    
    -- Check orphaned LocationKey
    SELECT 'FactSalesOrder' AS table_name, 'LocationKey' AS foreign_key, 'orphaned' AS issue_type, COUNT(*) AS record_count
    FROM gold.FactSalesOrder f
    WHERE f.LocationKey < 0
    OR NOT EXISTS (SELECT 1 FROM gold.DimLocation d WHERE d.LocationKey = f.LocationKey AND d.LocationKey IS NOT NULL);
    
    -- Check orphaned DateKey in all fact tables
    SELECT 'FactInventory' AS table_name, 'DateKey' AS foreign_key, 'orphaned' AS issue_type, COUNT(*) AS record_count
    FROM gold.FactInventory f
    WHERE NOT EXISTS (SELECT 1 FROM gold.DimDate d WHERE d.DateKey = f.DateKey);
    
    SELECT 'FactProcurement' AS table_name, 'DateKey' AS foreign_key, 'orphaned' AS issue_type, COUNT(*) AS record_count
    FROM gold.FactProcurement f
    WHERE NOT EXISTS (SELECT 1 FROM gold.DimDate d WHERE d.DateKey = f.DateKey);
    
    SELECT 'FactShipment' AS table_name, 'DateKey' AS foreign_key, 'orphaned' AS issue_type, COUNT(*) AS record_count
    FROM gold.FactShipment f
    WHERE NOT EXISTS (SELECT 1 FROM gold.DimDate d WHERE d.DateKey = f.DateKey);
    
    RETURN 0;
END
GO

PRINT 'Production support procedures created successfully.';
GO