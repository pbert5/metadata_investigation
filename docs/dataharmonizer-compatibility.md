# DataHarmonizer Compatibility Guide

## Current Upstream Behavior

The DataHarmonizer README describes templates as a hand-assembled single `schema.yaml` that merges a valid LinkML schema with an extra `dh_interface` class. Its example marks the display template class with `is_a: dh_interface`; the README says this signals DataHarmonizer to show that class as a template menu option.

Source checked: https://github.com/cidgoh/DataHarmonizer, README "Making templates" section, accessed 2026-07-16.

## Profiles In This Repo

## Local Web UI

Run the DataHarmonizer dev server on `127.0.0.1:18084`.

This port was chosen after checking:

- `/home/ash/flake/inventory/ports.nix`: `8080`, `8081`, `8082`, `8090`, `8333`, `8776`, `8888`, `9094`, `9095`, `9096`, `9333`, `9983`, `17650`, `45870`, and related inventory ports are already assigned.
- `/home/ash/Documents/work/evolver_code`: eVOLVER defaults use `18082` for the control plane, `18083` for the supervisor, and `8081` for the hardware Socket.IO endpoint.
- active listeners: `18084` is now the DataHarmonizer webpack server, with no overlap with the above.

Direct URLs:

```text
http://127.0.0.1:18084/?template=km_microbial_container/DNA-seq
http://127.0.0.1:18084/?template=km_microbial_dh/DNA-seq
```

The local DataHarmonizer checkout is intentionally filtered to only these repo-owned schema groups:

- `KM_microbial_container`
- `KM_microbial_dh`

Both `prepare-dataharmonizer` and `dataharmonizer-web` enforce that filtered `web/templates/menu.json`.

### Optimized LinkML Profile

Generated with:

```bash
schema-to-yaml examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json \
  -o generated/microbial_templates.optimized.linkml.yaml
```

Properties:

- no `dh_interface` class.
- assay templates use top-level reusable slots.
- `Container` is `tree_root`.
- each assay record list is represented as a multivalued, inlined container attribute.

Use this as the candidate canonical schema if DataHarmonizer can parse the container-root alternative.

### DataHarmonizer Compatibility Profile

Generated with:

```bash
schema-to-dh-yaml examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json \
  -o generated/microbial_templates.dataharmonizer.linkml.yaml
```

Properties:

- keeps `dh_interface`.
- keeps `is_a: dh_interface` on assay template classes.
- still hoists repeated fields into top-level slots.
- remains a single schema document.

Use this as the bridge if current DataHarmonizer requires inheritance-based template discovery.

## Compatibility Test Matrix

| Test | Expected result | Status |
| --- | --- | --- |
| LinkML parses optimized profile | Schema loads and can generate JSON Schema | Verified locally |
| LinkML parses DataHarmonizer profile | Schema loads and can generate JSON Schema | Verified locally |
| DataHarmonizer parses compatibility profile | Assay classes appear as template choices | Pending |
| DataHarmonizer parses optimized profile | Container or assay classes appear without `dh_interface` | Pending |
| DataHarmonizer validates sample rows from optimized profile | Validation uses the expected class slots | Pending |

Local verification commands:

```bash
nix flake check
nix develop --quiet -c schema-to-json-schema generated/microbial_templates.optimized.linkml.yaml \
  > generated/microbial_templates.optimized.schema.json
nix develop --quiet -c schema-to-json-schema generated/microbial_templates.dataharmonizer.linkml.yaml \
  > generated/microbial_templates.dataharmonizer.schema.json
python -m json.tool generated/microbial_templates.optimized.schema.json >/dev/null
python -m json.tool generated/microbial_templates.dataharmonizer.schema.json >/dev/null
```

## Decision Rule

- If DataHarmonizer accepts the optimized container profile, use it as the primary artifact and document any template menu configuration needed outside the schema.
- If DataHarmonizer only accepts `dh_interface`, keep the optimized profile canonical and generate the compatibility profile as an adapter until the integration can be dropped or replaced.
