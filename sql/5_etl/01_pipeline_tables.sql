-- ============================================================================
-- Pipeline Support Tables
-- ============================================================================
-- Tables for ETL pipeline logging, error handling, and statistics.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- ETL Schema
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS etl;
GO

-- ============================================================================
-- etl.pipeline_log
-- ============================================================================
CREATE TABLE etl.pipeline_log (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    job_name NVARCHAR(255) NOT NULL,
    job_id UNIQUEIDENTIFIER NOT NULL,
    start_time DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    end_time DATETIME2 NULL,
    status NVARCHAR(50) NOT NULL,
    rows_processed INT NOT NULL DEFAULT 0,
    error_message NVARCHAR(MAX) NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT CK_pipeline_log_status CHECK (status IN ('Running', 'Success', 'Failed', 'Cancelled'))
);
GO

CREATE NONCLUSTERED INDEX IX_pipeline_log_job_name ON etl.pipeline_log (job_name ASC);
CREATE NONCLUSTERED INDEX IX_pipeline_log_start_time ON etl.pipeline_log (start_time DESC);
CREATE NONCLUSTERED INDEX IX_pipeline_log_status ON etl.pipeline_log (status ASC);
GO

-- ============================================================================
-- etl.dead_letter
-- ============================================================================
CREATE TABLE etl.dead_letter (
    dead_letter_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    source_system NVARCHAR(50) NULL,
    source_table NVARCHAR(100) NULL,
    source_id NVARCHAR(255) NULL,
    payload NVARCHAR(MAX) NULL,
    error_message NVARCHAR(MAX) NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    retry_count INT NOT NULL DEFAULT 0,
    last_retry_at DATETIME2 NULL,
    resolved_at DATETIME2 NULL,
    
    CONSTRAINT CK_dead_letter_retry CHECK (retry_count >= 0)
);
GO

CREATE NONCLUSTERED INDEX IX_dead_letter_source ON etl.dead_letter (source_system ASC, source_table ASC);
CREATE NONCLUSTERED INDEX IX_dead_letter_created ON etl.dead_letter (created_at DESC);
CREATE NONCLUSTERED INDEX IX_dead_letter_unresolved ON etl.dead_letter (resolved_at ASC) WHERE resolved_at IS NULL;
GO

-- ============================================================================
-- etl.pipeline_stats
-- ============================================================================
CREATE TABLE etl.pipeline_stats (
    stats_id BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    job_name NVARCHAR(255) NOT NULL,
    run_date DATE NOT NULL,
    avg_duration_ms DECIMAL(18,2) NULL,
    min_duration_ms DECIMAL(18,2) NULL,
    max_duration_ms DECIMAL(18,2) NULL,
    total_rows BIGINT NULL,
    p50_duration_ms DECIMAL(18,2) NULL,
    p95_duration_ms DECIMAL(18,2) NULL,
    p99_duration_ms DECIMAL(18,2) NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT UQ_pipeline_stats_job_date UNIQUE (job_name, run_date)
);
GO

CREATE NONCLUSTERED INDEX IX_pipeline_stats_job_name ON etl.pipeline_stats (job_name ASC);
CREATE NONCLUSTERED INDEX IX_pipeline_stats_run_date ON etl.pipeline_stats (run_date DESC);
GO

-- ============================================================================
-- etl.watermarks (created in bronze layer but referenced here)
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

CREATE NONCLUSTERED INDEX IX_etl_watermarks_source ON etl.etl_watermarks (source_system ASC);
GO

PRINT 'Pipeline support tables created successfully.';
GO