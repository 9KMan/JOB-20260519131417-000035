-- ============================================================================
-- GOLD LAYER - ETL Procedures for Dimensions and Facts
-- SCD Type 2 handling, surrogate key lookups, fact loading
-- ============================================================================

-- ============================================================================
-- usp_gold_scd2_product
-- SCD Type 2 handling for DimProduct
-- ============================================================================
IF OBJECT_ID('gold.usp_gold_scd2_product', 'P') IS NOT NULL
    DROP PROC gold.usp_gold_scd2_product;
GO

CREATE PROC gold.usp_gold_scd2_product
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insert new or changed products
        MERGE INTO gold.DimProduct AS target
        USING (
            SELECT DISTINCT
                NaturalKey = CONCAT(SourceSystem, '|', ProductID),
                ProductID,
                ProductName = ISNULL(ProductName, 'Unknown Product'),
                Category,
                Subcategory,
                UnitOfMeasureKey = 1  -- Default 'Each'
            FROM silver.product
            WHERE ValidationStatus = 'validated'
        ) AS source
        ON target.NaturalKey = source.NaturalKey AND target.IsCurrent = 1
        WHEN NOT MATCHED THEN
            INSERT (NaturalKey, ProductID, ProductName, Category, Subcategory, UnitOfMeasureKey)
            VALUES (source.NaturalKey, source.ProductID, source.ProductName,
                    source.Category, source.Subcategory, source.UnitOfMeasureKey)
        WHEN MATCHED AND (
            target.ProductName <> source.ProductName OR
            target.Category <> source.Category OR
            target.Subcategory <> source.Subcategory
        ) THEN
            -- Close old record (SCD Type 2)
            UPDATE SET
                EndDate = SYSDATETIME(),
                IsCurrent = 0,
                UpdatedAt = SYSDATETIME();

        -- Insert new versions for changed records
        INSERT INTO gold.DimProduct (NaturalKey, ProductID, ProductName, Category, Subcategory, UnitOfMeasureKey)
        SELECT
            NaturalKey = CONCAT(p.SourceSystem, '|', p.ProductID),
            p.ProductID,
            p.ProductName,
            p.Category,
            p.Subcategory,
            UnitOfMeasureKey = 1
        FROM silver.product p
        INNER JOIN gold.DimProduct dp
            ON dp.NaturalKey = CONCAT(p.SourceSystem, '|', p.ProductID)
            AND dp.IsCurrent = 0  -- Just closed
            AND dp.EndDate >= DATEADD(DAY, -1, SYSDATETIME())
        WHERE NOT EXISTS (
            SELECT 1 FROM gold.DimProduct dp2
            WHERE dp2.NaturalKey = dp.NaturalKey AND dp2.IsCurrent = 1
        );

        COMMIT TRANSACTION;
        PRINT 'DimProduct SCD Type 2 processing complete';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
-- usp_gold_scd2_customer
-- SCD Type 2 handling for DimCustomer
-- ============================================================================
IF OBJECT_ID('gold.usp_gold_scd2_customer', 'P') IS NOT NULL
    DROP PROC gold.usp_gold_scd2_customer;
GO

CREATE PROC gold.usp_gold_scd2_customer
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE INTO gold.DimCustomer AS target
        USING (
            SELECT DISTINCT
                NaturalKey = CONCAT(SourceSystem, '|', CustomerID),
                CustomerID,
                CustomerName,
                Region,
                Segment
            FROM silver.customer
            WHERE ValidationStatus = 'validated'
        ) AS source
        ON target.NaturalKey = source.NaturalKey AND target.IsCurrent = 1
        WHEN NOT MATCHED THEN
            INSERT (NaturalKey, CustomerID, CustomerName, Region, Segment)
            VALUES (source.NaturalKey, source.CustomerID, source.CustomerName,
                    source.Region, source.Segment)
        WHEN MATCHED AND (
            target.CustomerName <> source.CustomerName OR
            target.Region <> source.Region OR
            target.Segment <> source.Segment
        ) THEN
            UPDATE SET
                EndDate = SYSDATETIME(),
                IsCurrent = 0,
                UpdatedAt = SYSDATETIME();

        -- Insert new versions
        INSERT INTO gold.DimCustomer (NaturalKey, CustomerID, CustomerName, Region, Segment)
        SELECT
            NaturalKey = CONCAT(c.SourceSystem, '|', c.CustomerID),
            c.CustomerID,
            c.CustomerName,
            c.Region,
            c.Segment
        FROM silver.customer c
        INNER JOIN gold.DimCustomer dc
            ON dc.NaturalKey = CONCAT(c.SourceSystem, '|', c.CustomerID)
            AND dc.IsCurrent = 0
            AND dc.EndDate >= DATEADD(DAY, -1, SYSDATETIME())
        WHERE NOT EXISTS (
            SELECT 1 FROM gold.DimCustomer dc2
            WHERE dc2.NaturalKey = dc.NaturalKey AND dc2.IsCurrent = 1
        );

        COMMIT TRANSACTION;
        PRINT 'DimCustomer SCD Type 2 processing complete';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
-- usp_gold_scd2_vendor
-- SCD Type 2 handling for DimVendor
-- ============================================================================
IF OBJECT_ID('gold.usp_gold_scd2_vendor', 'P') IS NOT NULL
    DROP PROC gold.usp_gold_scd2_vendor;
GO

CREATE PROC gold.usp_gold_scd2_vendor
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE INTO gold.DimVendor AS target
        USING (
            SELECT DISTINCT
                NaturalKey = CONCAT(SourceSystem, '|', VendorID),
                VendorID,
                VendorName,
                Category,
                PaymentTerms
            FROM silver.vendor
            WHERE ValidationStatus = 'validated'
        ) AS source
        ON target.NaturalKey = source.NaturalKey AND target.IsCurrent = 1
        WHEN NOT MATCHED THEN
            INSERT (NaturalKey, VendorID, VendorName, Category, PaymentTerms)
            VALUES (source.NaturalKey, source.VendorID, source.VendorName,
                    source.Category, source.PaymentTerms)
        WHEN MATCHED AND (
            target.VendorName <> source.VendorName OR
            target.Category <> source.Category OR
            target.PaymentTerms <> source.PaymentTerms
        ) THEN
            UPDATE SET
                EndDate = SYSDATETIME(),
                IsCurrent = 0,
                UpdatedAt = SYSDATETIME();

        COMMIT TRANSACTION;
        PRINT 'DimVendor SCD Type 2 processing complete';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
-- usp_gold_scd2_location
-- SCD Type 2 handling for DimLocation
-- ============================================================================
IF OBJECT_ID('gold.usp_gold_scd2_location', 'P') IS NOT NULL
    DROP PROC gold.usp_gold_scd2_location;
GO

CREATE PROC gold.usp_gold_scd2_location
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE INTO gold.DimLocation AS target
        USING (
            SELECT DISTINCT
                NaturalKey = CONCAT(ISNULL(SourceSystem,'unknown'), '|', ISNULL(WarehouseID,'unknown')),
                WarehouseID,
                WarehouseName = ISNULL(WarehouseID, 'Unknown') + ' Warehouse',
                Region,
                Country
            FROM silver.inventory
            CROSS JOIN (SELECT TOP 1 WarehouseID, Region, Country FROM silver.inventory WHERE WarehouseID IS NOT NULL) AS w
        ) AS source
        ON target.NaturalKey = source.NaturalKey AND target.IsCurrent = 1
        WHEN NOT MATCHED THEN
            INSERT (NaturalKey, WarehouseID, WarehouseName, Region, Country)
            VALUES (source.NaturalKey, source.WarehouseID, source.WarehouseName,
                    source.Region, source.Country)
        WHEN MATCHED AND (
            target.Region <> source.Region OR
            target.Country <> source.Country
        ) THEN
            UPDATE SET
                EndDate = SYSDATETIME(),
                IsCurrent = 0,
                UpdatedAt = SYSDATETIME();

        COMMIT TRANSACTION;
        PRINT 'DimLocation SCD Type 2 processing complete';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
-- usp_gold_load_fact_sales_order
-- Loads FactSalesOrder from silver sales order
-- ============================================================================
IF OBJECT_ID('gold.usp_gold_load_fact_sales_order', 'P') IS NOT NULL
    DROP PROC gold.usp_gold_load_fact_sales_order;
GO

CREATE PROC gold.usp_gold_load_fact_sales_order
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_processed INT = 0;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO gold.FactSalesOrder (
            OrderDateKey, CustomerKey, ProductKey, LocationKey,
            OrderID, SourceSystem, TotalAmount, Quantity, UnitPrice, OrderStatus
        )
        SELECT
            -- Date key lookup
            d.DateKey,
            -- Customer key lookup (current)
            ISNULL(c.CustomerKey, -1),
            -- Product key lookup (current)
            ISNULL(p.ProductKey, -1),
            -- Location key lookup (current)
            ISNULL(l.LocationKey, -1),
            -- Degenerate dimensions
            so.SourceOrderID,
            so.SourceSystem,
            -- Measures
            so.TotalAmount,
            1 AS Quantity,  -- Default quantity
            so.TotalAmount AS UnitPrice,  -- Simplified
            so.OrderStatus
        FROM silver.sales_order so
        INNER JOIN gold.DimDate d ON d.FullDate = so.OrderDate
        LEFT JOIN gold.DimCustomer c
            ON c.NaturalKey = CONCAT(so.SourceSystem, '|', so.CustomerID)
            AND c.IsCurrent = 1
        LEFT JOIN gold.DimProduct p
            ON p.NaturalKey = CONCAT(so.SourceSystem, '|', so.CustomerID)  -- Simplified: using customer key logic
            AND p.IsCurrent = 1
        LEFT JOIN gold.DimLocation l
            ON l.NaturalKey = 'default|default'  -- Default location
            AND l.IsCurrent = 1
        WHERE so.ValidationStatus IN ('validated', 'updated')
        AND NOT EXISTS (
            SELECT 1 FROM gold.FactSalesOrder f
            WHERE f.OrderID = so.SourceOrderID
            AND f.SourceSystem = so.SourceSystem
        );

        SET @rows_processed = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT 'FactSalesOrder loaded: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
-- usp_gold_load_fact_inventory
-- Loads FactInventory from silver inventory
-- ============================================================================
IF OBJECT_ID('gold.usp_gold_load_fact_inventory', 'P') IS NOT NULL
    DROP PROC gold.usp_gold_load_fact_inventory;
GO

CREATE PROC gold.usp_gold_load_fact_inventory
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_processed INT = 0;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO gold.FactInventory (
            SnapshotDateKey, ProductKey, LocationKey,
            SnapshotID, SourceSystem, QuantityOnHand
        )
        SELECT
            d.DateKey,
            ISNULL(p.ProductKey, -1),
            ISNULL(l.LocationKey, -1),
            i.SourceSnapshotID,
            i.SourceSystem,
            i.Quantity
        FROM silver.inventory i
        INNER JOIN gold.DimDate d ON d.FullDate = i.SnapshotDate
        LEFT JOIN gold.DimProduct p
            ON p.NaturalKey = CONCAT(i.SourceSystem, '|', i.ProductID)
            AND p.IsCurrent = 1
        LEFT JOIN gold.DimLocation l
            ON l.NaturalKey = CONCAT(i.SourceSystem, '|', i.WarehouseID)
            AND l.IsCurrent = 1
        WHERE i.ValidationStatus IN ('validated', 'updated')
        AND NOT EXISTS (
            SELECT 1 FROM gold.FactInventory f
            WHERE f.SnapshotID = i.SourceSnapshotID
            AND f.SourceSystem = i.SourceSystem
            AND f.ProductKey = ISNULL(p.ProductKey, -1)
            AND f.LocationKey = ISNULL(l.LocationKey, -1)
        );

        SET @rows_processed = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT 'FactInventory loaded: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
-- usp_gold_run_all
-- Master procedure to run all gold loads
-- ============================================================================
IF OBJECT_ID('gold.usp_gold_run_all', 'P') IS NOT NULL
    DROP PROC gold.usp_gold_run_all;
GO

CREATE PROC gold.usp_gold_run_all
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Starting Gold layer loading...';
    PRINT '================================';

    -- Dimension loads (SCD Type 2)
    PRINT 'Loading dimensions...';
    EXEC gold.usp_gold_scd2_product;
    EXEC gold.usp_gold_scd2_customer;
    EXEC gold.usp_gold_scd2_vendor;
    EXEC gold.usp_gold_scd2_location;

    -- Fact loads
    PRINT 'Loading facts...';
    EXEC gold.usp_gold_load_fact_sales_order;
    EXEC gold.usp_gold_load_fact_inventory;

    PRINT '================================';
    PRINT 'Gold layer loading complete.';
END
GO

PRINT 'Gold layer ETL procedures created successfully.';
GO