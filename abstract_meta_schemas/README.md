# Abstract Metadata Schemas

This directory is a proposal workspace for separating three concerns that are currently coupled in the DataHarmonizer-oriented LinkML export:

1. Canonical experiment metadata structure.
2. Controlled terminology and lab-maintained pick lists.
3. Tool-specific flattened schemas for DataHarmonizer, data catalog import, and internal forms.

The current reference input is:

```text
../kat_schema_prototyping/20260714_bio_automation_metadata_schema_v1.0.9.json
```

## Intended Shape

```text
admin terminology tables
        |
        v
canonical nested LinkML model
        |
        +--> DataHarmonizer profile
        +--> data catalog profile
        +--> internal form profiles
        +--> compatibility export matching the current v1.0.9 style
```

The canonical model should be the source of truth for data meaning. DataHarmonizer compatibility should be generated as an adapter, not maintained as the primary schema.

## Contents

- `docs/architecture.md` explains the layer boundaries and migration path.
- `terminology/` contains admin-editable controlled vocabulary tables.
- `schemas/canonical.linkml.yaml` sketches the normalized/nested backend model.
- `profiles/dataharmonizer.profile.yaml` describes a flattened DataHarmonizer adapter.
- `profiles/data_catalog.profile.yaml` describes a flattened data catalog adapter.
- `mappings/flattening.yaml` maps canonical paths to exported column names.

## Working Rules

- Add or retire vocabulary values in `terminology/*.tsv`, not by editing LinkML enum blocks directly.
- Keep canonical classes nested where the backend needs reusable entities, such as recipes, strains, reagents, assays, plates, wells, and source materials.
- Keep flattened column names in profile or mapping files.
- Generate compatibility schemas from these layers until the team no longer needs DataHarmonizer-specific artifacts.
