-- ============================================================================
-- JSON Config Export for Web Platform
-- Generates workflow config from database metadata
-- Used by web platform for dynamic screen rendering
-- ============================================================================

-- ============================================================================
-- usp_export_workflow_config
-- Exports workflow configuration as JSON
-- ============================================================================
IF OBJECT_ID('web.usp_export_workflow_config', 'P') IS NOT NULL
    DROP PROC web.usp_export_workflow_config;
GO

CREATE PROC web.usp_export_workflow_config
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @json NVARCHAR(MAX);

    -- Build workflow config JSON manually
    -- In production, this would be generated from actual metadata tables
    SET @json = '{
  "application": "Manufacturing ERP Dashboard",
  "version": "1.0.0",
  "last_updated": "' + CONVERT(NVARCHAR(10), SYSDATETIME(), 120) + '",
  "menus": [
    {
      "menu_id": "sales",
      "menu_name": "Sales",
      "icon": "fa-chart-line",
      "order": 1,
      "screens": [
        {
          "screen_id": "sales_orders",
          "screen_name": "Sales Orders",
          "view_name": "web.vw_sales_orders_list",
          "detail_view": "web.vw_sales_order_detail",
          "workflow": "order_to_cash",
          "permissions": ["sales_read", "sales_write"],
          "columns": [
            {"field": "OrderID", "label": "Order #", "type": "string", "sortable": true},
            {"field": "CustomerName", "label": "Customer", "type": "string", "sortable": true},
            {"field": "OrderDate", "label": "Order Date", "type": "date", "sortable": true},
            {"field": "TotalAmount", "label": "Total", "type": "currency", "sortable": true},
            {"field": "OrderStatus", "label": "Status", "type": "string", "sortable": true},
            {"field": "POReference", "label": "PO Reference", "type": "string", "sortable": false}
          ]
        },
        {
          "screen_id": "invoices",
          "screen_name": "Invoices",
          "view_name": "web.vw_invoices_list",
          "detail_view": "web.vw_invoice_detail",
          "workflow": "order_to_cash",
          "permissions": ["finance_read"],
          "columns": [
            {"field": "InvoiceID", "label": "Invoice #", "type": "string"},
            {"field": "OrderID", "label": "Order #", "type": "string"},
            {"field": "CustomerName", "label": "Customer", "type": "string"},
            {"field": "InvoiceDate", "label": "Invoice Date", "type": "date"},
            {"field": "TotalAmount", "label": "Amount", "type": "currency"},
            {"field": "PaidAmount", "label": "Paid", "type": "currency"},
            {"field": "BalanceDue", "label": "Balance", "type": "currency"},
            {"field": "PaymentStatus", "label": "Status", "type": "badge"}
          ]
        },
        {
          "screen_id": "shipments",
          "screen_name": "Shipments",
          "view_name": "web.vw_shipments_list",
          "detail_view": "web.vw_shipment_detail",
          "workflow": "order_to_cash",
          "permissions": ["shipping_read"],
          "columns": [
            {"field": "ShipmentID", "label": "Shipment #", "type": "string"},
            {"field": "OrderID", "label": "Order #", "type": "string"},
            {"field": "CustomerName", "label": "Customer", "type": "string"},
            {"field": "ShipDate", "label": "Ship Date", "type": "date"},
            {"field": "Carrier", "label": "Carrier", "type": "string"},
            {"field": "TrackingNumber", "label": "Tracking", "type": "string"}
          ]
        }
      ]
    },
    {
      "menu_id": "inventory",
      "menu_name": "Inventory",
      "icon": "fa-warehouse",
      "order": 2,
      "screens": [
        {
          "screen_id": "stock_levels",
          "screen_name": "Stock Levels",
          "view_name": "web.vw_inventory_current",
          "detail_view": "web.vw_inventory_detail",
          "workflow": "inventory_management",
          "permissions": ["inventory_read"],
          "columns": [
            {"field": "ProductName", "label": "Product", "type": "string"},
            {"field": "WarehouseName", "label": "Warehouse", "type": "string"},
            {"field": "QuantityOnHand", "label": "On Hand", "type": "number"},
            {"field": "QuantityAvailable", "label": "Available", "type": "number"},
            {"field": "LastSnapshotDate", "label": "Last Update", "type": "datetime"}
          ]
        }
      ]
    },
    {
      "menu_id": "procurement",
      "menu_name": "Procurement",
      "icon": "fa-shopping-cart",
      "order": 3,
      "screens": [
        {
          "screen_id": "purchase_orders",
          "screen_name": "Purchase Orders",
          "view_name": "web.vw_purchase_orders_list",
          "detail_view": "web.vw_purchase_order_detail",
          "workflow": "procurement",
          "permissions": ["procurement_read", "procurement_write"],
          "columns": [
            {"field": "PONumber", "label": "PO #", "type": "string"},
            {"field": "VendorName", "label": "Vendor", "type": "string"},
            {"field": "PODate", "label": "PO Date", "type": "date"},
            {"field": "TotalAmount", "label": "Amount", "type": "currency"},
            {"field": "POStatus", "label": "Status", "type": "string"}
          ]
        }
      ]
    },
    {
      "menu_id": "analytics",
      "menu_name": "Analytics",
      "icon": "fa-chart-bar",
      "order": 4,
      "screens": [
        {
          "screen_id": "sales_summary",
          "screen_name": "Sales Summary",
          "view_name": "web.vw_analytics_sales_summary",
          "detail_view": null,
          "workflow": null,
          "permissions": ["analytics_read"],
          "columns": []
        },
        {
          "screen_id": "order_to_cash",
          "screen_name": "Order-to-Cash KPI",
          "view_name": "web.vw_analytics_otc",
          "detail_view": null,
          "workflow": null,
          "permissions": ["analytics_read"],
          "columns": []
        }
      ]
    }
  ],
  "workflows": {
    "order_to_cash": {
      "name": "Order-to-Cash",
      "description": "Sales order lifecycle from creation to payment",
      "states": [
        {"state": "draft", "label": "Draft", "allowed_transitions": ["submitted"]},
        {"state": "submitted", "label": "Submitted", "allowed_transitions": ["approved", "cancelled"]},
        {"state": "approved", "label": "Approved", "allowed_transitions": ["invoiced", "cancelled"]},
        {"state": "invoiced", "label": "Invoiced", "allowed_transitions": ["shipped", "partial_shipped"]},
        {"state": "partial_shipped", "label": "Partially Shipped", "allowed_transitions": ["shipped"]},
        {"state": "shipped", "label": "Shipped", "allowed_transitions": ["delivered", "invoiced"]},
        {"state": "delivered", "label": "Delivered", "allowed_transitions": ["paid"]},
        {"state": "paid", "label": "Paid", "allowed_transitions": []},
        {"state": "cancelled", "label": "Cancelled", "allowed_transitions": []}
      ]
    },
    "inventory_management": {
      "name": "Inventory Management",
      "description": "Track inventory movements and adjustments",
      "states": [
        {"state": "available", "label": "Available", "allowed_transitions": ["reserved", "adjusted"]},
        {"state": "reserved", "label": "Reserved", "allowed_transitions": ["available", "shipped"]},
        {"state": "adjusted", "label": "Adjusted", "allowed_transitions": ["available"]},
        {"state": "shipped", "label": "Shipped", "allowed_transitions": []}
      ]
    },
    "procurement": {
      "name": "Procurement",
      "description": "Purchase order lifecycle",
      "states": [
        {"state": "draft", "label": "Draft", "allowed_transitions": ["submitted"]},
        {"state": "submitted", "label": "Submitted", "allowed_transitions": ["approved", "cancelled"]},
        {"state": "approved", "label": "Approved", "allowed_transitions": ["received", "cancelled"]},
        {"state": "received", "label": "Received", "allowed_transitions": ["closed"]},
        {"state": "closed", "label": "Closed", "allowed_transitions": []},
        {"state": "cancelled", "label": "Cancelled", "allowed_transitions": []}
      ]
    }
  },
  "roles": {
    "admin": {"permissions": ["*"]},
    "sales_manager": {"permissions": ["sales_read", "sales_write", "analytics_read"]},
    "finance": {"permissions": ["finance_read", "analytics_read"]},
    "warehouse": {"permissions": ["inventory_read", "shipping_read"]},
    "procurement": {"permissions": ["procurement_read", "procurement_write"]},
    "viewer": {"permissions": ["sales_read", "inventory_read"]}
  }
}';

    SELECT @json AS workflow_config_json;
END
GO

-- ============================================================================
-- usp_export_erp_sources_config
-- Exports ERP sources configuration as JSON
-- ============================================================================
IF OBJECT_ID('web.usp_export_erp_sources_config', 'P') IS NOT NULL
    DROP PROC web.usp_export_erp_sources_config;
GO

CREATE PROC web.usp_export_erp_sources_config
AS
BEGIN
    SET NOCOUNT ON;

    -- Export from the watermark table metadata
    SELECT
        source_id,
        source_table,
        stage_table,
        last_watermark_value,
        last_run_time,
        rows_processed,
        status
    FROM bronze.watermark
    FOR JSON AUTO;
END
GO

PRINT 'JSON config export procedures created successfully.';
GO