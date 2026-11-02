# dbt Cost Optimization Package

A dbt package that analyzes your data platform's compute, storage, and query patterns to identify optimization opportunities and produce actionable recommendations.

## Supported platforms

| Platform | Status | Documentation |
|----------|--------|---------------|
| **Snowflake** | GA | [docs/snowflake/](docs/snowflake/index.md) |
| **Databricks** | Beta [WIP] | [docs/databricks/](docs/databricks/) |
| **BigQuery** | Beta [WIP] | [docs/bigquery/](docs/bigquery/clustering_key_candidates.md) |
| **Redshift** | Beta [WIP] | [docs/redshift/](docs/redshift/) |

## What you'll get

### Quick-use commands

On-demand optimization checks you can run with `dbt run-operation`, with no models to build first. Currently available for Snowflake:

| Command | What it finds |
|---------|---------------|
| `find_table_clustering_candidates` | Tables that would benefit from clustering |
| `suggest_clustering_keys` | The best clustering key columns for a specific model |
| `find_table_materialization_candidates` | Views queried often enough to materialize as tables |
| `find_incremental_materialization_candidates` | Large, slow-building tables suited to incremental models |
| `find_warehouse_sizing_recommendations` | Warehouse sizing changes (scale up or down, multi-cluster, Gen2) |
| `find_spillage_candidates` | Models whose builds spill to local or remote storage |
| `find_expensive_dbt_queries` | The most expensive recurring dbt queries by projected annual cost |

For example: `dbt run-operation find_table_clustering_candidates --args '{lookback_days: 14}'`. See [docs/snowflake/macros.md](docs/snowflake/macros.md) for every command's arguments.

### Snowflake

The package produces **gold-layer views**: dashboard-ready outputs that surface ranked, prioritized recommendations.

| View | Audience | What it shows |
|------|----------|--------------|
| `vw_snowflake__top_recommendations` | Executives / leads | Top-priority recommendations across all domains, deduped per entity |
| `vw_snowflake__dbt_model_optimizations` | dbt engineers | Actionable model changes: clustering keys, materialization, incremental configs |
| `vw_snowflake__warehouse_optimizations` | Snowflake admins | Warehouse config changes: auto-suspend, scaling, sizing — with linked model context |
| `vw_snowflake__optimization_backlog` | Sprint planning / agents | Full inventory of all signals (all priority tiers) for ticket creation |
| `vw_snowflake__top_expensive_queries` | Cost owners | Top 10 expensive queries enriched with root-cause co-signals |
| `vw_snowflake__top_spillage_models` | Performance engineers | Models causing the most memory spillage, with dbt platform run traceability |
| `vw_snowflake__top_queried_models` | Platform engineers | Most-queried models (downstream consumption pressure) |
| `vw_snowflake__cross_domain_insights` | Architecture leads | Multi-signal correlation (why issues co-occur on the same model) |
| `vw_snowflake__cost_savings_summary` | Dashboards | KPI tiles: total opportunity per domain |
| `vw_snowflake__user_level_cost_attribution` | Cost owners | User-level cost attribution for chargeback |
| `vw_snowflake__ai_optimizations` | AI/ML teams | Cortex model cost, token efficiency, agent spend |

Each recommendation includes a `priority_tier`, a per-entity relative ordering:
- **P1** = do this first (highest in the optimization hierarchy for this model/warehouse)
- **P2** = do this second (after P1 is applied)
- **P3+** = deferred (waiting for higher-priority fixes to resolve the symptom)

Priority cascades naturally: when you apply a P1 fix (e.g., add a clustering key) and rebuild, the signal disappears and P2 promotes to P1 automatically.

### Databricks, BigQuery, and Redshift (Beta)

These platforms produce recommendations at the fact-model layer. Dashboard views and charts like Snowflake's are coming soon.

| Platform | Recommendations |
|----------|-----------------|
| **Databricks** | Liquid clustering, OPTIMIZE, table and incremental materialization, snapshot optimization, and model run trends, plus a per-model rollup (`vw_databricks__recommendations_by_model`) |
| **BigQuery** | Table clustering candidates and clustering key recommendations |
| **Redshift** | Sort key and distribution key recommendations, table and incremental materialization, incremental config, and VACUUM and ANALYZE candidates |

See each platform's docs for model details and configuration.

---

## Installation

Works on dbt v2 (the dbt Fusion engine) and dbt v1 (dbt-core 1.10 and later).

Add to your `packages.yml`:

```yaml
packages:
  - package: dbt-labs/dbt_cost_optimization
    version: [">=1.0.0", "<2.0.0"]
```

Then run:

```bash
dbt deps
```

## Getting started

After installation, see your platform's documentation for required permissions, configuration, and quick start commands:

- **Snowflake:** [docs/snowflake/index.md](docs/snowflake/index.md)
- **Databricks:** [docs/databricks/](docs/databricks/)
- **BigQuery:** [docs/bigquery/](docs/bigquery/clustering_key_candidates.md)
- **Redshift:** [docs/redshift/](docs/redshift/)

## Configuration

The package is **opt-in**: its models only build where you turn it on.

### Turn the package on with environment variables

The settings that switch the package's models on and off are environment variables. They work the same on dbt v1 and dbt v2, so nothing changes when a project moves from one to the other. Set them only in the environments or jobs that should build the package (your shell, CI, or a dbt platform environment or job):

| Environment variable | Default | Set it when |
|---|---|---|
| `DBT_COST_OPTIMIZATION_ENABLED` | `false` | Always, to build the package: `true` |
| `DBT_COST_OPTIMIZATION_SNOWFLAKE_ENTERPRISE_EDITION` | `true` | You're on Snowflake Standard edition: `false` |
| `DBT_COST_OPTIMIZATION_AI_REST_API_ENABLED` | `true` | You want to leave Cortex REST API usage (billed in dollars, not credits) out of the AI analysis: `false` |
| `DBT_COST_OPTIMIZATION_USE_QUERY_TEXT_ATTRIBUTION` | `true` | BigQuery only, to turn off query-text column attribution: `false` |

```bash
export DBT_COST_OPTIMIZATION_ENABLED=true
dbt build --select package:dbt_cost_optimization
```

On dbt v1, after you change one of these environment variables, run the next command once with `--no-partial-parse`, so dbt re-reads the package's configuration.

> **Why environment variables?** On dbt v1, dbt-core renders an installed package's `dbt_project.yml` without your project's vars, so a var can't switch the package's models on there. On dbt v2, the vars (`dbt_cost_optimization_enabled`, `snowflake_enterprise_edition`, `ai_rest_api_enabled`, `use_query_text_attribution`) also work, set in `vars.yml` or with `--vars`, but not in your `dbt_project.yml` `vars:` section. Use one or the other for each setting, not both.

### Every other var

Set the package's other vars (lookback windows, thresholds, `credit_rate_usd`, scope settings) in your project's `dbt_project.yml` `vars:` section, in a `vars.yml` file in your project root (dbt v2, and dbt-core 1.12 and later), or with `--vars`:

```yaml
# dbt_project.yml
vars:
  credit_rate_usd: 3
  dbt_excluded_schemas: ['DBT_CLOUD_PR_%']
```

> **`vars.yml` needs dbt v2 or dbt-core 1.12 and later.** On dbt-core 1.10 and 1.11, `vars.yml` isn't read: set vars in your `dbt_project.yml` `vars:` section or with `--vars`.

On dbt v1, var values must be literals: dbt v1 doesn't render Jinja (such as `"{{ target.database }}"`) in `vars:` values. Every var has a default. For the full list, see your platform's documentation or the `vars:` section of [dbt_project.yml](dbt_project.yml), which groups them into shared and per-platform sections.

## How it works

### Package models are disabled by default

After installation:

- **Snowflake optimization commands are immediately available** via `dbt run-operation` (no configuration needed)
- **Package models do not run** during your project's normal `dbt run` / `dbt build`

To build package models, explicitly opt in.

**Recommended: dedicated scheduled jobs** (no changes to existing jobs required). Set `DBT_COST_OPTIMIZATION_ENABLED=true` on those jobs only, for example as a job-level environment variable in the dbt platform:
```bash
# All package models
dbt build --select package:dbt_cost_optimization

# Or select by optimization domain
dbt build --select +tag:clustering
```

**Alternative: enable it for a whole environment** (models build on every run)

If you set `DBT_COST_OPTIMIZATION_ENABLED=true` for an environment, every run there builds the package, so exclude package models from the runs where you don't want them (for example `--exclude package:dbt_cost_optimization`).

Either way, this avoids unexpectedly querying large platform system tables (such as Snowflake's `ACCOUNT_USAGE` views) on every regular dbt build. Only the models for your data platform are enabled.

### Suggested cadences for scheduled jobs

| Domain | Selector | Platforms | Suggested cadence |
|--------|----------|-----------|-------------------|
| Warehouse (sizing, spillage, expensive queries) | `+tag:warehouse` | Snowflake | Weekly |
| AI / Cortex spend | `+tag:ai_spend` | Snowflake | Weekly |
| Materialization (view→table, table→incremental) | `+tag:materialization` | Snowflake, Databricks, Redshift | Monthly |
| Clustering candidates | `+tag:clustering` | All | Monthly |
| Dashboard views | `tag:gold` | Snowflake, Databricks | After each domain job. Without the `+`, it refreshes only the dashboards from what the domain jobs last built; `+tag:gold` builds the whole package |

Every package mart also has the `dbt_cost_optimization` tag. Some Snowflake models measure your account with post-hooks (operator stats, the view probe, SHOW WAREHOUSES); see the [Snowflake setup guide](docs/snowflake/index.md) for how cadence affects them.

### Scope (Snowflake)

| What | Scope | Notes |
|------|-------|-------|
| Model-level recommendations (clustering, materialization, incremental) | **This project only** | Requires dbt graph context (model configs, lineage) |
| Warehouse-level recommendations (config changes, spillage, idle credits) | **Warehouses used by this project** | Surfaces for any warehouse that runs project models |
| Spillage / performance | **Project + installed packages** | Package models (e.g., dbt_artifacts) that run on your warehouse are included |
| Expensive queries | **Project models** | Queries attributed to dbt node_ids in the monitored project |

Graph-dependent recommendations require the dbt project graph. Warehouse and expensive query signals use Snowflake query_history, which provides account-wide visibility scoped to warehouses the project uses.

To leave dev deployments out of the Snowflake recommendations, set `dbt_excluded_schemas` (schema patterns, e.g. `['DBT_%']`) or `dbt_excluded_targets` (e.g. `['dev']`) in your `dbt_project.yml` `vars:` section. By default nothing is excluded.

On Databricks, BigQuery, and Redshift, recommendations are scoped to your project's dbt models by default. See each platform's docs for the scope settings.

## Visualize your results

For Snowflake, once you've built the gold-layer models, see
[integrations/dbt_charts/README.md](integrations/dbt_charts/README.md) to
launch a [dbt-charts](https://github.com/dbt-labs/dbt-charts) dashboard
over them.

## Repository structure

```
models/
  shared/              Platform-agnostic models (dbt graph introspection)
  snowflake/
    staging/           Source staging models
    intermediate/      Transforms, aggregations, and cross-environment discovery
    marts/
      clustering/      Table clustering candidate recommendations
      materialization/ View-to-table and incremental strategy recommendations
      warehouse/       Sizing, spillage, and expensive query recommendations
      ai/              AI/Cortex spend and token efficiency recommendations
      gold/            Dashboard-ready views (cross-domain, deduplicated by model)
  databricks/          staging/, intermediate/, marts/
  bigquery/            staging/, intermediate/, marts/
  redshift/            staging/, intermediate/, marts/

macros/
  _macros.yml          Every macro's arguments and which platforms implement it
  optimizations/       Commands you run with dbt run-operation (and their helpers)
  utils/               Internal utilities used by models and hooks
  platforms/           Each platform's implementation of the macros above

docs/
  snowflake/           Setup guide, permissions, configuration, and reference docs
  databricks/          Model docs
  bigquery/            Model docs
  redshift/            Model docs and platform notes

tests/snowflake/       Macro tests (unit tests sit next to their models)
integration_tests/
  snowflake/           A dbt project that runs the package on fixture ACCOUNT_USAGE data
```

[TESTING.md](TESTING.md) explains each kind of test and how to run it. The docs in `docs/` also build into a site with MkDocs Material (`mkdocs.yml`): run `pip install -r docs/requirements.txt` and then `mkdocs serve`.

Macros use `adapter.dispatch`, so each command keeps the same name across platforms and runs the right implementation for your data platform.

## Contributing

We welcome bug reports and feature requests. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to open an issue. We aren't accepting outside pull requests yet.

## Support

This package is provided as-is, without SLAs, and is maintained on a best-effort basis. To report a bug or request a feature, open a GitHub issue. We read every issue, but we can't guarantee response times.

## Security

Please don't report security vulnerabilities in a public issue. Use the **Security** tab of this repository to report them privately.

## License

This package is licensed under the Apache License 2.0. See [LICENSE](LICENSE).
