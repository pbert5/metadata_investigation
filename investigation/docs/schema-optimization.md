# Schema Optimization Notes

## Goal

The legacy example in `examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json` appears to have been shaped around DataHarmonizer template discovery. Every assay template inherits from `dh_interface`, and most fields are embedded under each class as `attributes`.

That works as a DataHarmonizer-oriented artifact, but it makes the schema harder to reuse:

- repeated attributes obscure which fields are shared across templates.
- `dh_interface` mixes UI/template discovery concerns into the domain model.
- class-level attributes make it harder to maintain one canonical slot definition.
- downstream JSON/YAML conversions cannot easily distinguish core model structure from DataHarmonizer packaging.

## Current Optimization Path

1. Keep the legacy JSON file unchanged as an import/reference artifact.
2. Hoist class `attributes` into reusable top-level LinkML `slots`.
3. Replace per-class `attributes` with ordered class `slots`.
4. Emit a `Container` root class for integration payloads.
5. Keep a separate DataHarmonizer compatibility output that preserves `dh_interface` and `is_a` while still using top-level slots.

The conversion script supports both profiles:

```bash
schema-to-yaml examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json \
  -o generated/microbial_templates.optimized.linkml.yaml

schema-to-dh-yaml examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json \
  -o generated/microbial_templates.dataharmonizer.linkml.yaml
```

## Review Points

- If two assay templates define the same slot name with conflicting metadata, the converter fails and asks for manual review.
- The optimized profile removes `dh_interface`; the compatibility profile keeps it.
- The optimized profile uses one single-file YAML document with `Container` as `tree_root`.
- The compatibility profile is the safer candidate for current DataHarmonizer template packaging because DataHarmonizer documentation still describes `dh_interface` as the signal for template menu inclusion.

## Next Checks

1. Generate both YAML profiles.
2. Run LinkML lint/JSON Schema generation on both.
3. Copy the DataHarmonizer profile into a local `web/templates/<schema-name>/schema.yaml`.
4. Run DataHarmonizer's `script/linkml.py -i schema.yaml`.
5. Repeat the same test with the optimized container profile and record whether DataHarmonizer sees the root container, individual assay classes, both, or neither.
