# 🔧 Data Engineering Zoomcamp — Module 4: Analytics Engineering with dbt

> My hands-on work for **Module 4** of the [DataTalksClub Data Engineering Zoomcamp](https://github.com/DataTalksClub/data-engineering-zoomcamp) — building a production-style **analytics engineering** project using **dbt (data build tool)** on top of BigQuery, transforming raw NYC Taxi data into clean, modelled, analysis-ready tables.

---

## 📖 Module Overview

Module 4 introduces **analytics engineering** — the discipline of applying software engineering best practices (modularity, version control, testing, documentation) to data transformation. The module uses **dbt Core** to build a layered data model on BigQuery that turns raw Yellow and Green Taxi trip records into a clean fact table and dimension tables ready for BI tools.

---

## 🏗️ Project Architecture

The project follows the standard **dbt layered modelling** pattern:

```
Raw BigQuery Tables (BigQuery / GCS)
        │
        ▼
┌─────────────────┐
│   Staging Layer │  ← stg_yellow_tripdata, stg_green_tripdata
│  (views/tables) │    Type casting, column renaming, null filtering
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Intermediate Layer  │  ← int_trips_union
│    (views/tables)   │    Union green + yellow, deduplicate
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│           Marts Layer               │
│  fct_trip   dim_vendors   dim_zone  │  ← Surrogate keys, dedup, lookups
└─────────────────────────────────────┘
```

---

## 🗂️ Models

### Staging Layer (`models/staging/`)

Connects to raw BigQuery tables in the `nytaxi` dataset of the `kestra-sandbox-497507` project via `sources.yml`.

#### `stg_green_tripdata`
Cleans and standardises raw Green Taxi data:
- Renames `lpep_pickup_datetime` / `lpep_dropoff_datetime` → `pickup_datetime` / `dropoff_datetime`
- Renames `PULocationID` / `DOLocationID` → `pickup_locationid` / `dropoff_locationid`
- Casts all columns to correct types (`INTEGER`, `NUMERIC`, `TIMESTAMP`)
- Filters out rows where `vendorid IS NULL`
- Retains Green-specific columns: `trip_type`, `ehail_fee`

#### `stg_yellow_tripdata`
Cleans and standardises raw Yellow Taxi data — same structure as Green staging with two adjustments:
- Renames `tpep_pickup_datetime` / `tpep_dropoff_datetime` → shared column names
- Hardcodes `trip_type = 1` (Yellow taxis are always street-hail)
- Hardcodes `ehail_fee = 0` (not applicable to Yellow taxis)
- Filters out rows where `vendorid IS NULL`

Both staging models produce a **unified schema** so they can be combined downstream.

---

### Intermediate Layer (`models/intermediate/`)

#### `int_trips_union`
Combines Green and Yellow staging models into a single dataset:

```sql
select * from green_tripdata
union all
select * from yellow_tripdata
```

- Uses `UNION ALL` to preserve all records, then applies `SELECT DISTINCT *` to remove exact duplicates
- References upstream models via `{{ ref() }}` — ensuring dbt tracks the dependency graph

---

### Marts Layer (`models/marts/`)

#### `fct_trip`
The central **fact table** for all taxi trips:

- Reads from `int_trips_union`
- Generates a **surrogate primary key** (`trip_id`) using `dbt_utils.generate_surrogate_key` on:
  `vendorid`, `pickup_locationid`, `dropoff_locationid`, `pickup_datetime`, `dropoff_datetime`, `trip_distance`, `fare_amount`
- **Deduplicates** using `QUALIFY ROW_NUMBER() OVER (PARTITION BY trip_id ORDER BY pickup_datetime) = 1`
- Ensures every row is uniquely identifiable even without a natural primary key

#### `dim_vendors`
A **vendor dimension table** mapping vendor IDs to human-readable names via the custom macro:

| VendorID | Vendor Name |
|----------|-------------|
| 1 | Creative Mobile Technologies |
| 2 | VeriFone Inc. |
| 4 | Unknown/Other |

#### `dim_zone`
A **zone dimension table** built from the `taxi_zone_lookup` seed/reference:
- Renames columns to snake_case (`LocationID` → `location_id`, `Borough` → `borough`, `Zone` → `zone`)
- Provides borough, zone name, and service zone for every location ID

---

## 🧩 Macros (`macros/`)

#### `get_vendor_data(vendor_id)`
A reusable Jinja macro that generates a `CASE` statement to translate a numeric `VendorID` into a vendor name string. Used in `dim_vendors.sql`.

```sql
{% macro get_vendor_data(vendor_id) %}
case
    when {{vendor_id}} = 1 then 'Creative Mobile Technologies'
    when {{vendor_id}} = 2 then 'VeriFone Inc.'
    when {{vendor_id}} = 4 then 'Unknown/Other'
end
{% endmacro %}
```

---

## 📦 Packages (`packages.yml`)

| Package | Version | Usage |
|---------|---------|-------|
| `dbt-labs/dbt_utils` | `1.3.0` | `generate_surrogate_key` in `fct_trip` |

Install with:
```bash
dbt deps
```

---

## 🗃️ Project Configuration (`dbt_project.yml`)

- **Project name**: `my_new_project`
- **Profile**: `chirag` (configured in `~/.dbt/profiles.yml` pointing to BigQuery)
- **Default materialisation**: `view` for all models
- **Example models override**: materialised as `table`

---

## 🗂️ Repository Structure

```
.
├── dbt_project.yml                         # Project config, materialisation settings
├── packages.yml                            # dbt_utils dependency
├── package-lock.yml                        # Locked package versions
├── macros/
│   └── get_vendor_name.sql                 # Macro: VendorID → vendor name CASE statement
├── models/
│   ├── staging/
│   │   ├── sources.yml                     # Source definitions (BigQuery raw tables)
│   │   ├── stg_green_tripdata.sql          # Green taxi: cast, rename, filter nulls
│   │   └── stg_yellow_tripdata.sql         # Yellow taxi: cast, rename, filter nulls
│   ├── intermediate/
│   │   └── int_trips_union.sql             # UNION ALL green + yellow, distinct
│   ├── marts/
│   │   ├── fct_trip.sql                    # Fact table with surrogate key + dedup
│   │   ├── dim_vendors.sql                 # Vendor dimension with macro
│   │   └── dim_zone.sql                    # Zone/borough dimension from lookup
│   └── example/
│       ├── my_first_dbt_model.sql          # dbt starter example (table materialisation)
│       ├── my_second_dbt_model.sql         # dbt starter example (ref usage)
│       └── schema.yml                      # Tests: unique + not_null on id column
├── analyses/
├── seeds/
├── snapshots/
└── tests/
```

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| dbt Core | Data transformation & modelling |
| BigQuery | Cloud data warehouse (target) |
| `dbt_utils` | Surrogate key generation |
| Jinja / SQL | Model logic and macros |
| GCS | Upstream raw data source |

---

## 🚀 Getting Started

### Prerequisites

- dbt Core installed with the BigQuery adapter: `pip install dbt-bigquery`
- A GCP service account with BigQuery access
- A `~/.dbt/profiles.yml` configured with a `chirag` profile pointing to your BigQuery project

### Run the project

```bash
# Install dependencies
dbt deps

# Test connection
dbt debug

# Run all models
dbt run

# Run tests
dbt test

# Generate and serve documentation
dbt docs generate
dbt docs serve
```

### Run specific layers

```bash
# Staging only
dbt run --select staging

# Everything downstream of staging
dbt run --select staging+

# A single model and its dependencies
dbt run --select fct_trip+
```

---

## 📚 Resources

- [DataTalksClub DE Zoomcamp — Module 4](https://github.com/DataTalksClub/data-engineering-zoomcamp/tree/main/04-analytics-engineering)
- [dbt Documentation](https://docs.getdbt.com/)
- [dbt_utils Package](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/)
- [Course YouTube Playlist](https://www.youtube.com/playlist?list=PL3MmuxUbc_hJed7dXYoJw8DoCuVHhGEQb)

---

## 🙌 Acknowledgements

Thanks to [Alexey Grigorev](https://linkedin.com/in/agrigorev) and the DataTalksClub team for this excellent free course.
