# Metadata Schema Abstraction Architecture

## Problem

The current schema treats the DataHarmonizer-compatible LinkML file as the main editing surface. That makes the schema carry too many responsibilities at once:

- It defines backend data structure.
- It stores controlled vocabulary values.
- It encodes spreadsheet column names and UI groupings.
- It carries DataHarmonizer template discovery details.
- It carries app-specific lookup behavior through annotations.

This works for data entry, but it makes vocabulary governance and schema evolution fragile. A small terminology change becomes a schema edit, and a tool-specific flattening decision becomes part of the domain model.

## Proposed Layers

### 1. Terminology Layer

Admin-maintained tables define controlled values independently from schema structure.

Initial table columns:

| Column | Meaning |
| --- | --- |
| `term_set` | The controlled list this term belongs to. |
| `id` | Stable local identifier. |
| `label` | User-facing text. |
| `status` | `active`, `deprecated`, or `candidate`. |
| `definition` | Short meaning or curation note. |
| `aliases` | Optional alternate labels separated by `|`. |
| `source` | Owning source or external reference. |

These can be maintained as TSV files in git, or edited as ODS spreadsheets and exported to TSV during generation.

### 2. Canonical Model Layer

The canonical model represents how metadata should exist in the backend:

- `Dataset` has one or more `Plate` records.
- `Plate` has `WellSample` records.
- `WellSample` references reusable entities like `Strain`, `Recipe`, `Assay`, and `Reagent`.
- `Recipe` contains repeated `CarbonSourceUsage`, `NitrogenSourceUsage`, and `ReagentUsage` records.
- Plate specializations use `is_a` for shared behavior instead of repeating flat slot lists.

This layer should use normal LinkML inheritance, nested objects, references, and multivalued slots.

### 3. Profile Layer

Profiles describe what a specific tool needs:

- DataHarmonizer wants spreadsheet-like templates and controlled dropdowns.
- The data catalog wants searchable, importable records.
- Internal forms may want focused payloads for unique entities or mapped repeated entities.

Profiles decide which canonical classes appear, which fields flatten, and which vocabulary term sets become dropdowns.

### 4. Mapping Layer

Mappings are explicit transformations between canonical paths and flat columns.

Example:

```yaml
source_path: plate.wells[].recipe.carbon_sources[0].term
target_column: carbon_source_1
```

This keeps awkward spreadsheet compromises out of the canonical model.

## Migration Path

1. Extract the current embedded enums into `terminology/*.tsv`.
2. Build a canonical LinkML model that reuses current slot names where possible but introduces nested entities and inheritance.
3. Generate a DataHarmonizer profile that matches the current spreadsheet columns.
4. Generate a v1.0.9-style compatibility LinkML file to prove existing tools still work.
5. Move admin vocabulary maintenance from schema editing to terminology-table editing.
6. Incrementally migrate data catalog and internal tools to canonical JSON/YAML payloads where possible.

## Compatibility Boundary

DataHarmonizer compatibility remains a hard requirement unless the team agrees to switch tools. The design therefore assumes DataHarmonizer output is generated, tested, and versioned, but not manually edited as the source of truth.
