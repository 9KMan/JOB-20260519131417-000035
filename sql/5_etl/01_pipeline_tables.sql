-- ============================================================================
-- ETL PIPELINE AUTOMATION
-- Centralized pipeline execution logging and error handling
-- ============================================================================

-- Schema for ETL metadata
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
BEGIN
    EXEC('CREATE SCHEMA etl');
END
GO

-- ============================================================================
-- etl_pipeline_log
-- Centralized logging for all ETL pipeline executions
-- ============================================================================
IF OBJECT_ID('etl.pipeline_log', 'U') IS NULL
BEGIN
    CREATE TABLE etl.pipeline_log (
        LogID BIGINT IDENTITY(1,1) NOT NULL,
        JobID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        PipelineName NVARCHAR(100) NOT NULL,
        StepName NVARCHAR(100) NULL,
        StepOrder INT NULL,
        Status NVARCHAR(20) NOT NULL,  -- 'running', 'success', 'failed', 'warning'
        StartTime DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EndTime DATETIME2 NULL,
        DurationSeconds INT NULL,
        RowsProcessed INT NULL DEFAULT 0,
        RowsAffected INT NULL DEFAULT 0,
        ErrorMessage NVARCHAR(MAX) NULL,
        ErrorSeverity INT NULL,
        ErrorNumber INT NULL,
        WarningMessage NVARCHAR(MAX) NULL,
        -- Context
        BatchID UNIQUEIDENTIFIER NULL,
        SourceSystem NVARCHAR(50) NULL,
        TargetSchema NVARCHAR(50) NULL,
        TargetTable NVARCHAR(100) NULL,
        -- Additional metadata
        HostName NVARCHAR(100) DEFAULT HOST_NAME(),
        LoginName NVARCHAR(100) DEFAULT SUSER_NAME(),
        CONSTRAINT PK_etl_pipeline_log PRIMARY KEY CLUSTERED (LogID)
    );

    -- Indexes for common queries
    CREATE INDEX IX_etl_pipeline_log_job ON etl.pipeline_log (JobID, StepName);
    CREATE INDEX IX_etl_pipeline_log_pipeline ON etl.pipeline_log (PipelineName, StartTime DESC);
    CREATE INDEX IX_etl_pipeline_log_status ON etl.pipeline_log (Status, StartTime DESC);
    CREATE INDEX IX_etl_pipeline_log_date ON etl.pipeline_log (StartTime DESC);
END
GO

-- ============================================================================
-- etl_pipeline_stats
-- Aggregated statistics per pipeline run
-- ============================================================================
IF OBJECT_ID('etl.pipeline_stats', 'U') IS NULL
BEGIN
    CREATE TABLE etl.pipeline_stats (
        StatsID BIGINT IDENTITY(1,1) NOT NULL,
        JobID UNIQUEIDENTIFIER NOT NULL,
        PipelineName NVARCHAR(100) NOT NULL,
        RunDate DATE NOT NULL DEFAULT CAST(SYSDATETIME() AS DATE),
        StartTime DATETIME2 NOT NULL,
        EndTime DATETIME2 NULL,
        DurationSeconds INT NULL,
        TotalRowsProcessed INT DEFAULT 0,
        TotalSteps INT DEFAULT 0,
        SuccessfulSteps INT DEFAULT 0,
        FailedSteps INT DEFAULT 0,
        WarningSteps INT DEFAULT 0,
        Status NVARCHAR(20) NOT NULL,
        CONSTRAINT PK_etl_pipeline_stats PRIMARY KEY CLUSTERED (StatsID),
        CONSTRAINT UQ_etl_pipeline_stats_job UNIQUE (JobID)
    );
END
GO

-- ============================================================================
-- etl_dead_letter
-- Dead letter queue for failed records
-- ============================================================================
IF OBJECT_ID('etl.dead_letter', 'U') IS NULL
BEGIN
    CREATE TABLE etl.dead_letter (
        DLQID BIGINT IDENTITY(1,1) NOT NULL,
        JobID UNIQUEIDENTIFIER NOT NULL,
        SourceSystem NVARCHAR(50) NOT NULL,
        SourceTable NVARCHAR(100) NOT NULL,
        SourceRecordID NVARCHAR(100) NULL,
        SourceData NVARCHAR(MAX) NULL,
        ErrorMessage NVARCHAR(MAX) NOT NULL,
        ErrorSeverity INT NULL,
        ErrorNumber INT NULL,
        InsertedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        ProcessedAt DATETIME2 NULL,
        CONSTRAINT PK_etl_dead_letter PRIMARY KEY CLUSTERED (DLQID)
    );

    CREATE INDEX IX_etl_dead_letter_pending ON etl.dead_letter (ProcessedAt) WHERE ProcessedAt IS NULL;
    CREATE INDEX IX_etl_dead_letter_source ON etl.dead_letter (SourceSystem, SourceTable);
END
GO

-- ============================================================================
-- etl_pipeline_config
-- Pipeline schedule and configuration
-- ============================================================================
IF OBJECT_ID('etl.pipeline_config', 'U') IS NULL
BEGIN
    CREATE TABLE etl.pipeline_config (
        ConfigID INT IDENTITY(1,1) NOT NULL,
        PipelineName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(500) NULL,
        ScheduleType NVARCHAR(20) NOT NULL,  -- 'hourly', 'daily', 'weekly', 'manual'
        SchedulePattern NVARCHAR(100) NULL,   -- Cron for Azure, frequency for SQL Agent
        Enabled BIT NOT NULL DEFAULT 1,
        Priority INT NOT NULL DEFAULT 100,    -- Lower = higher priority
        MaxRetries INT NOT NULL DEFAULT 3,
        RetryDelaySeconds INT NOT NULL DEFAULT 60,
        AlertOnFailure BIT NOT NULL DEFAULT 1,
        NotificationEmail NVARCHAR(100) NULL,
        LastRunTime DATETIME2 NULL,
        NextRunTime DATETIME2 NULL,
        AvgDurationSeconds INT NULL,
        SuccessRate DECIMAL(5,2) NULL,
        CONSTRAINT PK_etl_pipeline_config PRIMARY KEY CLUSTERED (ConfigID),
        CONSTRAINT UQ_etl_pipeline_config_name UNIQUE (PipelineName)
    );

    -- Insert default pipeline configurations
    INSERT INTO etl.pipeline_config (PipelineName, Description, ScheduleType, SchedulePattern, Priority, MaxRetries)
    VALUES
    ('bronze_layer_load', 'Load staging tables from ERP sources', 'hourly', '0 * * * *', 10, 3),
    ('silver_layer_map', 'Map staging to canonical schemas', 'hourly', '15 * * * *', 20, 3),
    ('gold_layer_load', 'Load dimensional model', 'daily', '0 2 * * *', 30, 3),
    ('web_views_refresh', 'Refresh web platform views', 'daily', '0 3 * * *', 40, 2),
    ('json_config_export', 'Export JSON configs', 'daily', '0 4 * * *', 50, 2);
END
GO

PRINT 'ETL pipeline tables created successfully.';
GO