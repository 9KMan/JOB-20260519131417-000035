# Manufacturing ERP Data Integration Platform

**JOB-20260519131417-000035** | SQL Server / Azure SQL / Kimball Dimensional Model

---

## Architecture

```
Multi-ERP Sources (Sage, SAP, Custom)
         │
         ▼
┌─────────────────────────┐
│   Bronze — Staging      │  Raw ERP tables, watermark-based CDC
│   (stage_*)             │  No full re-loads, json_config-driven
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   Silver — Canonical   │  Unified schemas, deduplication, SCD Type 2
│   (silver_*)            │  Data quality validation
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   Gold — Kimball Star   │  Analytics-ready dimensional model
│   (Dim* / Fact*)        │  Surrogate keys, conformed dimensions
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   Consumption Layer     │  SQL views for web platform
│   (vw_*)                │  JSON config exports
└─────────────────────────────────────────┘
```

---

## Directory Structure

```
sql/
├── 1_bronze/          # Staging tables + CDC procedures
│   ├── 01_staging_tables.sql
│   └── 02_etl_procedures.sql
├── 2_silver/           # Canonical schemas + mapping
│   ├── 01_canonical_tables.sql
│   └── 02_etl_procedures.sql
├── 3_gold/             # Kimball star schema
│   ├── dims/           # Dimension tables (SCD Type 2)
│   │   └── 01_dimension_tables.sql
│   ├── facts/          # Fact tables
│   │   └── 02_fact_tables.sql
│   └── 03_etl_procedures.sql
├── 4_views/            # Web platform views + JSON export
│   ├── 01_web_views.sql
│   └── 02_json_export.sql
└── 5_etl/              # Pipeline automation + production support
    ├── 01_pipeline_tables.sql
    ├── 02_pipeline_procedures.sql
    └── 03_production_support.sql

json/
├── erp_sources.json    # Source ERP connection/schema mapping
└── workflow_config.json # Web platform workflow definitions
```

---

## Data Model

### Dimension Tables (Gold)

| Table | Description | SCD Type |
|-------|-------------|----------|
| DimProduct | Product master, category, unit of measure | Type 2 |
| DimCustomer | Customer master, region, segment | Type 2 |
| DimVendor | Vendor master, payment terms | Type 2 |
| DimDate | Calendar (Year, Quarter, Month, Week) | Static |
| DimCurrency | Currency codes, exchange rates | Type 1 |
| DimLocation | Warehouse/location master | Type 2 |

### Fact Tables (Gold)

| Table | Grain | Dimensions |
|-------|-------|------------|
| FactSalesOrder | One row per sales order line | DimDate, DimCustomer, DimProduct, DimLocation |
| FactInventory | One row per inventory snapshot | DimDate, DimProduct, DimLocation |
| FactProcurement | One row per PO line | DimDate, DimVendor, DimProduct |
| FactShipment | One row per shipment line | DimDate, DimCustomer, DimProduct, DimLocation |

### Staging Tables (Bronze)

| Table | Source | CDC Strategy |
|-------|--------|--------------|
| stage_sage_sales_orders | Sage ERP | Watermark: LastModified |
| stage_sage_invoices | Sage ERP | Watermark: LastModified |
| stage_sap_sales_orders | SAP ERP | Watermark: MODIFIED_TS |

---

## Key Technical Decisions

1. **Watermark-based CDC** — Works across all ERP sources, no SQL Server version dependency
2. **SCD Type 2 on slow-changing dimensions** — Product pricing, customer address, vendor terms track history
3. **Surrogate keys** — Decouples natural keys from analytics, enables conformed dimensions
4. **JSON config for source mapping** — New ERP source = edit JSON, not SQL
5. **Stored procedure pattern** — TRY/CATCH, explicit transactions, dead-letter logging
6. **Separate schemas** — stage / silver / gold isolation for safety and auditability

---

## ETL Pipeline

```
erp_sources.json → Staging (Bronze) → Canonical (Silver) → Star Schema (Gold) → Web Views
                  Watermark CDC     Dedup + Validation   Surrogate Keys      Dynamic UI
```

Pipeline execution is logged to `etl.pipeline_log` with job_id, start/end time, rows processed, and error messages.

---

## Production Support

- Query execution plans for slow stored procedures
- Dead-letter table: `etl.dead_letter` — rows that failed processing with error context
- Pipeline stats table: `etl.pipeline_stats` — per-job performance metrics
- All procedures have TRY/CATCH with rollback on failure

---

## Getting Started

1. Review `json/erp_sources.json` — configure your ERP source connection
2. Run `sql/1_bronze/01_staging_tables.sql` — create staging schema
3. Run `sql/2_silver/01_canonical_tables.sql` — create silver schema
4. Run `sql/3_gold/dims/01_dimension_tables.sql` — create dimension tables
5. Run `sql/3_gold/facts/02_fact_tables.sql` — create fact tables
6. Configure SQL Agent jobs or Azure Data Factory for pipeline scheduling

---

**Stack:** SQL Server / T-SQL · Azure SQL · Kimball Dimensional Modeling · Watermark CDC