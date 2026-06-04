# Esports360 Database

This folder contains PostgreSQL schema files for the Esports360 backend.

Current rule:

- Schema files are source-controlled.
- Apply them through Docker/PostgreSQL after review.
- iOS must use internal Esports360 IDs only.
- Provider IDs stay behind the backend in `provider_entity_map`.
- Raw external payloads stay in `provider_payloads`.

Files:

- `schema/001_core_data_platform.sql`: core provider-neutral esports data model.
- `schema/002_seed_core_catalog.sql`: initial providers, games, and regions.

Quick validation against a temporary database:

```bash
createdb esports360_schema_check
psql -d esports360_schema_check -v ON_ERROR_STOP=1 -f schema/001_core_data_platform.sql
psql -d esports360_schema_check -v ON_ERROR_STOP=1 -f schema/002_seed_core_catalog.sql
dropdb esports360_schema_check
```
