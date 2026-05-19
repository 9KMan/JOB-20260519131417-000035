-- ============================================================================
-- SILVER LAYER - ETL Procedures
-- Map staging to canonical schemas with deduplication
-- ============================================================================

-- ============================================================================
--usp_silver_map_sales_orders
-- Maps all staging sales orders to canonical schema
-- ============================================================================
IF OBJECT_ID('silver.usp_silver_map_sales_orders', 'P') IS NOT NULL
    DROP PROC silver.usp_silver_map_sales_orders;
GO

CREATE PROC silver.usp_silver_map_sales_orders
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_processed INT = 0;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Merge Sage sales orders
        MERGE INTO silver.sales_order AS target
        USING (
            SELECT
                'sage_erp' AS SourceSystem,
                OrderID AS SourceOrderID,
                CAST(OrderDate AS DATE) AS OrderDate,
                CustomerID,
                NULL AS CustomerName,
                TotalAmount,
                OrderStatus,
                NULL AS POReference,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(OrderID,''), ISNULL(CustomerID,''), ISNULL(CAST(TotalAmount AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_sage_sales_orders
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceOrderID = source.SourceOrderID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceOrderID, OrderDate, CustomerID, TotalAmount, OrderStatus, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceOrderID, source.OrderDate, source.CustomerID,
                    source.TotalAmount, source.OrderStatus, source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                TotalAmount = source.TotalAmount,
                OrderStatus = source.OrderStatus,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        -- Merge SAP sales orders
        MERGE INTO silver.sales_order AS target
        USING (
            SELECT
                'sap_erp' AS SourceSystem,
                OrderID AS SourceOrderID,
                CAST(OrderDate AS DATE) AS OrderDate,
                CustomerID,
                NULL AS CustomerName,
                TotalAmount,
                OrderStatus,
                POReference,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(OrderID,''), ISNULL(CustomerID,''), ISNULL(CAST(TotalAmount AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_sap_sales_orders
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceOrderID = source.SourceOrderID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceOrderID, OrderDate, CustomerID, TotalAmount, OrderStatus, POReference, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceOrderID, source.OrderDate, source.CustomerID,
                    source.TotalAmount, source.OrderStatus, source.POReference, source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                TotalAmount = source.TotalAmount,
                OrderStatus = source.OrderStatus,
                POReference = source.POReference,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        -- Merge Custom ERP sales orders
        MERGE INTO silver.sales_order AS target
        USING (
            SELECT
                'custom_erp' AS SourceSystem,
                OrderID AS SourceOrderID,
                CAST(OrderDate AS DATE) AS OrderDate,
                CustomerID,
                NULL AS CustomerName,
                TotalAmount,
                OrderStatus,
                NULL AS POReference,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(OrderID,''), ISNULL(CustomerID,''), ISNULL(CAST(TotalAmount AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_custom_sales_orders
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceOrderID = source.SourceOrderID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceOrderID, OrderDate, CustomerID, TotalAmount, OrderStatus, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceOrderID, source.OrderDate, source.CustomerID,
                    source.TotalAmount, source.OrderStatus, source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                TotalAmount = source.TotalAmount,
                OrderStatus = source.OrderStatus,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        -- Mark staging rows as processed
        UPDATE bronze.stage_sage_sales_orders
        SET ProcessedAt = SYSDATETIME()
        WHERE ProcessedAt IS NULL;

        UPDATE bronze.stage_sap_sales_orders
        SET ProcessedAt = SYSDATETIME()
        WHERE ProcessedAt IS NULL;

        UPDATE bronze.stage_custom_sales_orders
        SET ProcessedAt = SYSDATETIME()
        WHERE ProcessedAt IS NULL;

        -- Get count
        SELECT @rows_processed = COUNT(*)
        FROM silver.sales_order
        WHERE UpdatedAt >= DATEADD(MINUTE, -5, SYSDATETIME());

        COMMIT TRANSACTION;

        PRINT 'Silver sales orders mapped: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_silver_map_invoices
-- Maps all staging invoices to canonical schema
-- ============================================================================
IF OBJECT_ID('silver.usp_silver_map_invoices', 'P') IS NOT NULL
    DROP PROC silver.usp_silver_map_invoices;
GO

CREATE PROC silver.usp_silver_map_invoices
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_processed INT = 0;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Merge Sage invoices
        MERGE INTO silver.invoice AS target
        USING (
            SELECT
                'sage_erp' AS SourceSystem,
                InvoiceID AS SourceInvoiceID,
                OrderID AS SourceOrderID,
                CAST(InvoiceDate AS DATE) AS InvoiceDate,
                CustomerID,
                NULL AS CustomerName,
                TotalAmount,
                PaidAmount,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(InvoiceID,''), ISNULL(OrderID,''), ISNULL(CAST(TotalAmount AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_sage_invoices
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceInvoiceID = source.SourceInvoiceID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceInvoiceID, SourceOrderID, InvoiceDate, CustomerID,
                    TotalAmount, PaidAmount, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceInvoiceID, source.SourceOrderID,
                    source.InvoiceDate, source.CustomerID, source.TotalAmount,
                    source.PaidAmount, source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                PaidAmount = source.PaidAmount,
                TotalAmount = source.TotalAmount,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        -- Merge SAP invoices
        MERGE INTO silver.invoice AS target
        USING (
            SELECT
                'sap_erp' AS SourceSystem,
                InvoiceID AS SourceInvoiceID,
                OrderID AS SourceOrderID,
                CAST(InvoiceDate AS DATE) AS InvoiceDate,
                CustomerID,
                NULL AS CustomerName,
                TotalAmount,
                PaidAmount,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(InvoiceID,''), ISNULL(OrderID,''), ISNULL(CAST(TotalAmount AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_sap_invoices
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceInvoiceID = source.SourceInvoiceID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceInvoiceID, SourceOrderID, InvoiceDate, CustomerID,
                    TotalAmount, PaidAmount, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceInvoiceID, source.SourceOrderID,
                    source.InvoiceDate, source.CustomerID, source.TotalAmount,
                    source.PaidAmount, source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                PaidAmount = source.PaidAmount,
                TotalAmount = source.TotalAmount,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        -- Mark processed
        UPDATE bronze.stage_sage_invoices SET ProcessedAt = SYSDATETIME() WHERE ProcessedAt IS NULL;
        UPDATE bronze.stage_sap_invoices SET ProcessedAt = SYSDATETIME() WHERE ProcessedAt IS NULL;

        SELECT @rows_processed = COUNT(*)
        FROM silver.invoice
        WHERE UpdatedAt >= DATEADD(MINUTE, -5, SYSDATETIME());

        COMMIT TRANSACTION;

        PRINT 'Silver invoices mapped: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_silver_map_shipments
-- Maps all staging shipments to canonical schema
-- ============================================================================
IF OBJECT_ID('silver.usp_silver_map_shipments', 'P') IS NOT NULL
    DROP PROC silver.usp_silver_map_shipments;
GO

CREATE PROC silver.usp_silver_map_shipments
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_processed INT = 0;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Merge Sage shipments
        MERGE INTO silver.shipment AS target
        USING (
            SELECT
                'sage_erp' AS SourceSystem,
                ShipmentID AS SourceShipmentID,
                OrderID AS SourceOrderID,
                CAST(ShipDate AS DATE) AS ShipDate,
                CustomerID,
                NULL AS CustomerName,
                Carrier,
                TrackingNumber,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(ShipmentID,''), ISNULL(OrderID,''), ISNULL(CAST(ShipDate AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_sage_shipments
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceShipmentID = source.SourceShipmentID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceShipmentID, SourceOrderID, ShipDate, CustomerID,
                    Carrier, TrackingNumber, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceShipmentID, source.SourceOrderID,
                    source.ShipDate, source.CustomerID, source.Carrier,
                    source.TrackingNumber, source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                Carrier = source.Carrier,
                TrackingNumber = source.TrackingNumber,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        -- Merge SAP shipments
        MERGE INTO silver.shipment AS target
        USING (
            SELECT
                'sap_erp' AS SourceSystem,
                ShipmentID AS SourceShipmentID,
                OrderID AS SourceOrderID,
                CAST(ShipDate AS DATE) AS ShipDate,
                CustomerID,
                NULL AS CustomerName,
                Carrier,
                TrackingNumber,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(ShipmentID,''), ISNULL(OrderID,''), ISNULL(CAST(ShipDate AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_sap_shipments
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceShipmentID = source.SourceShipmentID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceShipmentID, SourceOrderID, ShipDate, CustomerID,
                    Carrier, TrackingNumber, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceShipmentID, source.SourceOrderID,
                    source.ShipDate, source.CustomerID, source.Carrier,
                    source.TrackingNumber, source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                Carrier = source.Carrier,
                TrackingNumber = source.TrackingNumber,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        -- Mark processed
        UPDATE bronze.stage_sage_shipments SET ProcessedAt = SYSDATETIME() WHERE ProcessedAt IS NULL;
        UPDATE bronze.stage_sap_shipments SET ProcessedAt = SYSDATETIME() WHERE ProcessedAt IS NULL;

        SELECT @rows_processed = COUNT(*)
        FROM silver.shipment
        WHERE UpdatedAt >= DATEADD(MINUTE, -5, SYSDATETIME());

        COMMIT TRANSACTION;

        PRINT 'Silver shipments mapped: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_silver_map_inventory
-- Maps staging inventory to canonical schema
-- ============================================================================
IF OBJECT_ID('silver.usp_silver_map_inventory', 'P') IS NOT NULL
    DROP PROC silver.usp_silver_map_inventory;
GO

CREATE PROC silver.usp_silver_map_inventory
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_processed INT = 0;
    DECLARE @error_message NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE INTO silver.inventory AS target
        USING (
            SELECT
                'custom_erp' AS SourceSystem,
                SnapshotID AS SourceSnapshotID,
                CAST(SYSDATETIME() AS DATE) AS SnapshotDate,
                ProductID,
                WarehouseID,
                Quantity,
                HASHBYTES('SHA2_256',
                    CONCAT(ISNULL(SnapshotID,''), ISNULL(ProductID,''), ISNULL(WarehouseID,''), ISNULL(CAST(Quantity AS NVARCHAR(50)),'')))
                    AS SourceRowHash
            FROM bronze.stage_custom_inventory
            WHERE ProcessedAt IS NULL
        ) AS source
        ON target.SourceSystem = source.SourceSystem
           AND target.SourceSnapshotID = source.SourceSnapshotID
           AND target.ProductID = source.ProductID
           AND target.WarehouseID = source.WarehouseID
        WHEN NOT MATCHED THEN
            INSERT (SourceSystem, SourceSnapshotID, SnapshotDate, ProductID, WarehouseID,
                    Quantity, SourceRowHash, ValidationStatus)
            VALUES (source.SourceSystem, source.SourceSnapshotID, source.SnapshotDate,
                    source.ProductID, source.WarehouseID, source.Quantity,
                    source.SourceRowHash, 'validated')
        WHEN MATCHED AND target.SourceRowHash <> source.SourceRowHash THEN
            UPDATE SET
                Quantity = source.Quantity,
                SourceRowHash = source.SourceRowHash,
                UpdatedAt = SYSDATETIME(),
                ValidationStatus = 'updated';

        UPDATE bronze.stage_custom_inventory SET ProcessedAt = SYSDATETIME() WHERE ProcessedAt IS NULL;

        SELECT @rows_processed = COUNT(*)
        FROM silver.inventory
        WHERE UpdatedAt >= DATEADD(MINUTE, -5, SYSDATETIME());

        COMMIT TRANSACTION;

        PRINT 'Silver inventory mapped: ' + CAST(@rows_processed AS NVARCHAR(10)) + ' rows';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
--usp_silver_run_all
-- Master procedure to run all silver mappings
-- ============================================================================
IF OBJECT_ID('silver.usp_silver_run_all', 'P') IS NOT NULL
    DROP PROC silver.usp_silver_run_all;
GO

CREATE PROC silver.usp_silver_run_all
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Starting Silver layer mapping...';
    PRINT '--------------------------------';

    EXEC silver.usp_silver_map_sales_orders;
    EXEC silver.usp_silver_map_invoices;
    EXEC silver.usp_silver_map_shipments;
    EXEC silver.usp_silver_map_inventory;

    PRINT '--------------------------------';
    PRINT 'Silver layer mapping complete.';
END
GO

PRINT 'Silver layer ETL procedures created successfully.';
GO