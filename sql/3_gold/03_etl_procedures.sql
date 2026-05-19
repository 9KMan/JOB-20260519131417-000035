-- ============================================================================
-- Gold Layer ETL Procedures
-- ============================================================================
-- Procedures to load dimension and fact tables from silver layer with
-- surrogate key lookups and SCD Type 2 handling.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- usp_gold_dim_product (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_dim_product
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
        
        -- SCD Type 2 Merge: Close old version if attributes changed
        UPDATE gold.DimProduct
        SET ValidTo = DATEADD(DAY, -1, SYSDATETIME()),
            IsCurrent = 0,
            VersionNumber = VersionNumber + 1
        FROM gold.DimProduct d
        INNER JOIN silver.silver_product s ON d.NaturalKey = s.natural_key
        WHERE d.IsCurrent = 1
        AND (
            d.Name <> s.product_name
            OR d.StandardCost <> s.standard_cost
            OR d.Category <> s.category
        );
        
        -- Insert new versions for changed records
        INSERT INTO gold.DimProduct (
            NaturalKey, Name, Category, Subcategory, UnitOfMeasure,
            StandardCost, SupplierID, IsCurrent, ValidFrom, VersionNumber
        )
        SELECT TOP (@BatchSize)
            s.natural_key,
            s.product_name,
            s.category,
            s.subcategory,
            s.unit_of_measure,
            s.standard_cost,
            s.supplier_id,
            1,
            SYSDATETIME(),
            1
        FROM silver.silver_product s
        WHERE s.is_current = 1
        AND NOT EXISTS (
            SELECT 1 FROM gold.DimProduct d
            WHERE d.NaturalKey = s.natural_key AND d.IsCurrent = 1
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
-- usp_gold_dim_customer (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_dim_customer
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
        
        -- Close old version if address changed
        UPDATE gold.DimCustomer
        SET ValidTo = DATEADD(DAY, -1, SYSDATETIME()),
            IsCurrent = 0,
            VersionNumber = VersionNumber + 1
        FROM gold.DimCustomer d
        INNER JOIN silver.silver_customer s ON d.NaturalKey = s.natural_key
        WHERE d.IsCurrent = 1
        AND (
            d.CustomerAddress <> s.customer_address
            OR d.CustomerCity <> s.customer_city
            OR d.CustomerPostalCode <> s.customer_postal_code
            OR d.Region <> s.region
        );
        
        -- Insert new versions
        INSERT INTO gold.DimCustomer (
            NaturalKey, CustomerName, Region, Segment, CustomerAddress,
            CustomerCity, CustomerPostalCode, IsCurrent, ValidFrom, VersionNumber
        )
        SELECT TOP (@BatchSize)
            s.natural_key,
            s.customer_name,
            s.region,
            s.segment,
            s.customer_address,
            s.customer_city,
            s.customer_postal_code,
            1,
            SYSDATETIME(),
            1
        FROM silver.silver_customer s
        WHERE s.is_current = 1
        AND NOT EXISTS (
            SELECT 1 FROM gold.DimCustomer d
            WHERE d.NaturalKey = s.natural_key AND d.IsCurrent = 1
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
-- usp_gold_dim_vendor (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_dim_vendor
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
        
        UPDATE gold.DimVendor
        SET ValidTo = DATEADD(DAY, -1, SYSDATETIME()),
            IsCurrent = 0,
            VersionNumber = VersionNumber + 1
        FROM gold.DimVendor d
        INNER JOIN silver.silver_vendor s ON d.NaturalKey = s.natural_key
        WHERE d.IsCurrent = 1
        AND (
            d.VendorName <> s.vendor_name
            OR d.PaymentTerms <> s.payment_terms
        );
        
        INSERT INTO gold.DimVendor (
            NaturalKey, VendorName, Category, PaymentTerms,
            IsCurrent, ValidFrom, VersionNumber
        )
        SELECT TOP (@BatchSize)
            s.natural_key,
            s.vendor_name,
            s.category,
            s.payment_terms,
            1,
            SYSDATETIME(),
            1
        FROM silver.silver_vendor s
        WHERE s.is_current = 1
        AND NOT EXISTS (
            SELECT 1 FROM gold.DimVendor d
            WHERE d.NaturalKey = s.natural_key AND d.IsCurrent = 1
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
-- usp_gold_dim_location (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_dim_location
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
        
        INSERT INTO gold.DimLocation (
            NaturalKey, WarehouseID, WarehouseName, Region, Country,
            IsCurrent, ValidFrom, VersionNumber
        )
        SELECT TOP (@BatchSize)
            s.natural_key,
            s.warehouse_id,
            s.location_name,
            s.region,
            s.country,
            1,
            SYSDATETIME(),
            1
        FROM silver.silver_location s
        WHERE s.is_current = 1
        AND NOT EXISTS (
            SELECT 1 FROM gold.DimLocation d
            WHERE d.NaturalKey = s.natural_key AND d.IsCurrent = 1
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
-- usp_gold_dim_currency (Type 1)
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_dim_currency
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
        
        -- Type 1: Update/Insert (no history)
        MERGE INTO gold.DimCurrency AS target
        USING (
            SELECT 'USD' AS CurrencyCode, 'US Dollar' AS CurrencyName, 1.0 AS ExchangeRate, CAST(GETDATE() AS DATE) AS RateDate
        ) AS source
        ON target.CurrencyCode = source.CurrencyCode AND target.IsCurrent = 1
        WHEN MATCHED THEN
            UPDATE SET ExchangeRate = source.ExchangeRate, RateDate = source.RateDate
        WHEN NOT MATCHED THEN
            INSERT (CurrencyCode, CurrencyName, ExchangeRate, RateDate, IsCurrent)
            VALUES (source.CurrencyCode, source.CurrencyName, source.ExchangeRate, source.RateDate, 1);
        
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
-- usp_gold_dim_date (Generate Static Date Dimension)
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_dim_date
    @StartYear INT = 2020,
    @EndYear INT = 2030
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @ProcName NVARCHAR(255) = OBJECT_NAME(@@PROCID);
    DECLARE @JobId UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @CurrentDate DATE;
    DECLARE @DateKey INT;
    
    BEGIN TRY
        INSERT INTO etl.pipeline_log (job_name, job_id, start_time, status, rows_processed)
        VALUES (@ProcName, @JobId, SYSDATETIME(), 'Running', 0);
        
        BEGIN TRANSACTION;
        
        -- Clear existing data (static dimension, reload each time)
        TRUNCATE TABLE gold.DimDate;
        
        SET @CurrentDate = CAST(@StartYear AS VARCHAR(4)) + '-01-01';
        
        WHILE @CurrentDate <= CAST(@EndYear AS VARCHAR(4)) + '-12-31'
        BEGIN
            SET @DateKey = CAST(FORMAT(@CurrentDate, 'yyyyMMdd') AS INT);
            
            INSERT INTO gold.DimDate (
                DateKey, FullDate, DayOfWeek, DayName, Month, MonthName,
                Quarter, Year, WeekOfYear, FiscalYear, FiscalQuarter
            )
            VALUES (
                @DateKey,
                @CurrentDate,
                DATEPART(WEEKDAY, @CurrentDate),
                DATENAME(WEEKDAY, @CurrentDate),
                MONTH(@CurrentDate),
                DATENAME(MONTH, @CurrentDate),
                DATEPART(QUARTER, @CurrentDate),
                YEAR(@CurrentDate),
                DATEPART(WEEK, @CurrentDate),
                CASE WHEN MONTH(@CurrentDate) >= 7 THEN YEAR(@CurrentDate) + 1 ELSE YEAR(@CurrentDate) END,
                CASE 
                    WHEN MONTH(@CurrentDate) BETWEEN 7 AND 9 THEN 1
                    WHEN MONTH(@CurrentDate) BETWEEN 10 AND 12 THEN 2
                    WHEN MONTH(@CurrentDate) BETWEEN 1 AND 3 THEN 3
                    ELSE 4
                END
            );
            
            SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
            SET @RowsProcessed = @RowsProcessed + 1;
        END
        
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
-- usp_gold_fact_sales_order
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_fact_sales_order
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
        
        -- Surrogate key lookups
        INSERT INTO gold.FactSalesOrder (
            DateKey, CustomerKey, ProductKey, LocationKey,
            OrderNumber, OrderLineNumber, OrderDate,
            QuantityOrdered, UnitPrice, TotalAmount,
            DiscountAmount, TaxAmount, CurrencyKey, Loading
        )
        SELECT TOP (@BatchSize)
            CAST(FORMAT(CAST(s.order_date AS DATE), 'yyyyMMdd') AS INT),
            COALESCE(c.CustomerKey, -1),
            COALESCE(p.ProductKey, -1),
            COALESCE(l.LocationKey, -1),
            s.order_number,
            1 AS OrderLineNumber,
            s.order_date,
            1 AS QuantityOrdered,
            s.total_amount AS UnitPrice,
            s.total_amount,
            0 AS DiscountAmount,
            s.tax_amount,
            (SELECT TOP 1 CurrencyKey FROM gold.DimCurrency WHERE IsCurrent = 1) AS CurrencyKey,
            s.order_status AS Loading
        FROM silver.silver_sales_order s
        LEFT JOIN gold.DimCustomer c ON c.NaturalKey = s.customer_natural_key AND c.IsCurrent = 1
        LEFT JOIN gold.DimProduct p ON p.NaturalKey = s.customer_natural_key AND p.IsCurrent = 1
        LEFT JOIN gold.DimLocation l ON l.WarehouseID = s.warehouse_code AND l.IsCurrent = 1
        WHERE s.is_current = 1
        AND NOT EXISTS (
            SELECT 1 FROM gold.FactSalesOrder f
            WHERE f.OrderNumber = s.order_number
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
-- usp_gold_fact_inventory
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_fact_inventory
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
        
        -- Placeholder for silver_inventory source
        -- INSERT INTO gold.FactInventory (...) SELECT ... FROM silver.silver_inventory ...
        
        SET @RowsProcessed = 0;
        
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
-- usp_gold_fact_procurement
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_fact_procurement
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
        
        -- Placeholder for silver_po source
        SET @RowsProcessed = 0;
        
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
-- usp_gold_fact_shipment
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.usp_gold_fact_shipment
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
        
        -- Placeholder for silver_shipment source
        SET @RowsProcessed = 0;
        
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

PRINT 'Gold ETL procedures created successfully.';
GO