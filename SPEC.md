# Manufacturing ERP Data Integration Platform — SPEC.md
## JOB-20260519131417-000035

---

## 1. Project Overview

**Client:** Manufacturing ERP Integration — Upwork
**Goal:** Build a standardized Azure SQL data warehouse that consolidates ERP data from multiple manufacturing businesses, supporting analytics, dashboards, reporting, and internal web applications.
**Stack:** SQL Server / T-SQL, Azure SQL, Kimball dimensional modeling, ETL pipelines, JSON configuration
**Key Domains:** Sales orders, invoices, shipments, inventory, procurement, order-to-cash workflows

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    MULTI-ERP SOURCES                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐│
│  │ Sage ERP │  │ SAP ERP  │  │ Custom   │  │ Other Manufacturing│
│  │          │  │          │  │ ERP      │  │ ERP Systems       ││
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘│
└───────┼─────────────┼─────────────┼───────────────────┼──────────┘
        │             │             │                   │
        ▼             ▼             ▼                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BRONZE LAYER (Staging)                       │
│  ERP Staging Tables — raw schema match source systems           │
│  Watermark-based incremental CDC (no full re-loads)             │
│  json_config-driven source mapping                              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SILVER LAYER (Standardized)                    │
│  Canonical schemas — all ERPs map to unified table structures    │
│  Data quality validation, deduplication, denormalization        │
│  SCD Type 2 on dimension tables                                  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 GOLD LAYER (Star Schema / Kimball)               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ DimProduct  │  │ DimCustomer │  │ DimLocation │              │
│  │ DimDate     │  │ DimSalesRep │  │ DimVendor   │              │
│  │ DimCurrency │  │ DimUOM      │  │ DimWarehouse│              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │               │               │                       │
│  ┌──────┴───────────────┴───────────────┴───────┐               │
│  │            FACT TABLES                        │               │
│  │  • FactSalesOrder (order-to-cash)            │               │
│  │  • FactInventory (stock levels/movements)    │               │
│  │  • FactProcurement (PO lifecycle)            │               │
│  │  • FactShipment (fulfillment)                │               │
│  └───────────────────────────────────────────────┘               │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               CONSUMPTION LAYER                                  │
│  • SQL Views for web platform (dynamic screen generation)       │
│  • JSON config exports (menu/workflow definitions)               │
│  • Stored procedures for analytical queries                      │
│  • Azure SQL connection for reporting/BI tools                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Workstreams

### W1 — ERP Source Mapping & Staging (Bronze)
- **Goal:** Ingest raw data from each ERP source into staging tables
- **Pattern:** Watermark-based incremental CDC — track `LastModified` watermark per source table, re-query only changed rows since last run
- **No full re-loads** — incremental only
- **json_config:** `erp_sources.json` defines per-source connection, schema, watermark column, and column mapping
- **Tables:** `stage_{erp_source}_{table}` (e.g., `stage_sage_sales_orders`)

### W2 — Canonical Standardization (Silver)
- **Goal:** Map all ERP sources to unified canonical schemas
- **Deduplication:** Handle same entity appearing in multiple ERPs (e.g., same customer in Sage and SAP)
- **Data quality:** CHECK constraints, NULL detection, referential integrity
- **SCD Type 2:** Dimension tables track historical changes (DimProduct, DimCustomer, DimVendor)
- **Tables:** `silver_{entity}` (e.g., `silver_sales_order`, `silver_customer`)

### W3 — Kimball Star Schema (Gold)
- **Goal:** Build analytics-ready dimensional model
- **Dimension tables:** Surrogate keys, natural keys, SCD Type 2 attributes, degenerate dimensions
- **Fact tables:**事务型事实表 — granular row per line item, foreign keys to dimension tables
- **Conformed dimensions:** Shared across fact tables (DimDate is universal)
- **Surrogate key generation:** `IDENTITY(1,1)` or `NEXT VALUE FOR` sequence per dimension

### W4 — Web Platform Views & JSON Config
- **Goal:** Generate SQL views and JSON configs consumed by internal web platform
- **Dynamic screens:** Views named `vw_{screen}_{workflow}` — web platform reads schema and dynamically renders UI
- **JSON config:** `workflow_config.json` — defines menu structure, screen relationships, and workflow states
- **Security:** Row-level security filters embedded in views based on `json_config` user roles

### W5 — ETL Pipeline Automation
- **Pattern:** SQL Agent jobs or Azure Data Factory pipelines
- **Schedule:** Near-real-time for transactional tables (sales orders), daily for slow-changing dims
- **Error handling:** Try/catch in stored procedures, dead-letter queues, alerting on failure
- **Logging:** Pipeline execution log table — job_id, start_time, end_time, rows_processed, error_message

### W6 — Production Support & Troubleshooting
- **Issue types:** Data inconsistency (missing/mismatch), performance degradation, failed loads
- **Tools:** Profiler traces, execution plans, extended events for slow query diagnosis
- **Patterns:** Root cause via data lineage (staging → silver → gold), identifying source of bad data

---

## 4. Data Model — Key Tables

### Dimension Tables (Gold)

| Table | Key Fields | SCD Type |
|-------|-----------|----------|
| DimProduct | ProductKey (PK), NaturalKey, Name, Category, Subcategory, UnitOfMeasure | Type 2 |
| DimCustomer | CustomerKey (PK), CustomerID, Name, Region, Segment | Type 2 |
| DimVendor | VendorKey (PK), VendorID, Name, Category, PaymentTerms | Type 2 |
| DimDate | DateKey (PK), FullDate, Year, Quarter, Month, Week, DayOfWeek | Static |
| DimCurrency | CurrencyKey (PK), CurrencyCode, ExchangeRate, RateDate | Type 1 |
| DimLocation | LocationKey (PK), WarehouseID, Region, Country | Type 2 |

### Fact Tables (Gold)

| Table | Grain | Key Dimensions |
|-------|-------|---------------|
| FactSalesOrder | One row per sales order line | DimDate, DimCustomer, DimProduct, DimLocation |
| FactInventory | One row per inventory snapshot per warehouse | DimDate, DimProduct, DimLocation |
| FactProcurement | One row per PO line | DimDate, DimVendor, DimProduct |
| FactShipment | One row per shipment line | DimDate, DimCustomer, DimProduct, DimLocation |

### Staging Tables (Bronze)

| Table | Source | Watermark Column |
|-------|--------|-----------------|
| stage_sage_sales_orders | Sage ERP | LastModified |
| stage_sage_invoices | Sage ERP | LastModified |
| stage_sap_sales_orders | SAP ERP | MODIFIED_TS |
| stage_custom_inventory | Custom ERP | updated_at |

---

## 5. Technical Decisions

1. **Watermark-based CDC over change tracking** — Works across all ERP sources (Sage, SAP, custom), no SQL Server version requirement
2. **SCD Type 2 on slow-changing dimensions** — Product pricing, customer address changes tracked historically
3. **Surrogate keys for all dimensions** — Decouples natural keys from analytics queries, enables conformed dimensions
4. **JSON config for source mapping** — No hardcoded ERP schemas; adding a new source = editing JSON, not SQL
5. **Stored procedure pattern for ETL** — Error handling, transaction management, logging built into each proc
6. **Separate staging schema** — Raw data isolated from canonical schemas; easy to re-load if mapping changes
7. **Order-to-cash as primary fact** — Sales order → invoice → shipment lifecycle is the core business metric

---

## 6. Out of Scope

- BI tool selection/implementation (Power BI, Tableau)
- Real-time streaming (Kafka, Event Hub)
- Cloud migration planning (Azure infrastructure)
- ERP customization or implementation
- Data science / ML workloads

---

## 7. Success Metrics

- Sales order data available in Gold layer within 4 hours of source change
- Zero data gaps in order-to-cash fact table for established ERP sources
- JSON config exports validated against schema on every pipeline run
- All stored procedures have TRY/CATCH with logged error output
- Execution plans reviewed for all fact table join queries (index usage verified)

---

## 8. Deliverables

| Phase | Deliverable |
|-------|------------|
| P1 | Staging layer for primary ERP source (Sage or SAP) |
| P2 | Silver canonical schemas for sales orders, invoices, shipments |
| P3 | Gold Kimball star schema (4 dim + 4 fact tables) |
| P4 | Web platform views + JSON config export |
| P5 | ETL pipeline automation with logging |
| P6 | Production support runbook |