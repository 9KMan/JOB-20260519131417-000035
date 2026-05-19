-- ============================================================================
-- JSON Config Export Procedures
-- ============================================================================
-- Procedures to export configuration JSON for dynamic UI generation.
-- ============================================================================

USE DATABASE $(DATABASE_NAME);
GO

-- ============================================================================
-- usp_export_workflow_config
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_export_workflow_config
    @JsonOutput NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- This would read from workflow_config.json file or table
    -- For demo, returns static JSON
    SET @JsonOutput = N'{
  "workflows": [
    {
      "workflow_id": "order_to_cash",
      "workflow_name": "Order to Cash",
      "description": "Sales order through shipment lifecycle",
      "screens": [
        {
          "screen_id": "sales_orders",
          "screen_name": "Sales Orders",
          "table_view": "vw_sales_orders_list",
          "fields": [
            {"field": "OrderNumber", "label": "Order #", "type": "string", "required": true},
            {"field": "CustomerName", "label": "Customer", "type": "lookup", "source": "DimCustomer"},
            {"field": "OrderDate", "label": "Order Date", "type": "date", "required": true},
            {"field": "TotalAmount", "label": "Total", "type": "currency", "required": true}
          ]
        }
      ]
    }
  ]
}';
    
    RETURN 0;
END
GO

-- ============================================================================
-- usp_export_menu_config
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_export_menu_config
    @JsonOutput NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @JsonOutput = N'{
  "menu": [
    {
      "menu_id": "sales",
      "menu_name": "Sales",
      "icon": "shopping_cart",
      "items": [
        {"screen_id": "sales_orders", "label": "Sales Orders"},
        {"screen_id": "invoices", "label": "Invoices"},
        {"screen_id": "shipments", "label": "Shipments"}
      ]
    },
    {
      "menu_id": "procurement",
      "menu_name": "Procurement",
      "icon": "local_shipping",
      "items": [
        {"screen_id": "purchase_orders", "label": "Purchase Orders"}
      ]
    },
    {
      "menu_id": "inventory",
      "menu_name": "Inventory",
      "icon": "inventory",
      "items": [
        {"screen_id": "inventory_levels", "label": "Inventory Levels"}
      ]
    }
  ]
}';
    
    RETURN 0;
END
GO

-- ============================================================================
-- usp_export_screen_config
-- ============================================================================
CREATE OR ALTER PROCEDURE etl.usp_export_screen_config
    @ScreenId NVARCHAR(100),
    @JsonOutput NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @JsonOutput = N'{
  "screen_id": "' + ISNULL(@ScreenId, 'unknown') + '",
  "config": {
    "allow_add": true,
    "allow_edit": true,
    "allow_delete": true,
    "page_size": 50,
    "export_formats": ["excel", "pdf", "csv"]
  }
}';
    
    RETURN 0;
END
GO

PRINT 'JSON export procedures created successfully.';
GO