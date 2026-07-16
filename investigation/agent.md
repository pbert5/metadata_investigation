# Agent Working Agreement - metadata

## Required First Steps

1. Call `mcp__serena__initial_instructions` and follow the Serena manual.
2. Activate this project with `mcp__serena__activate_project` at `/home/ash/Documents/work/metadata`.
3. Read local guidance before changing files, including this file and `/home/ash/.codex/RTK.md`.

## Shell Usage

Always prefix shell commands with `rtk` so command output stays token-efficient:

- `rtk jq '.classes | keys' examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json`
- `rtk nix flake check`
- `rtk python scripts/legacy_schema_to_linkml_yaml.py --help`

## Project Layout

- `examples/outdated/` keeps imported or legacy schema artifacts for comparison.
- `generated/` contains reproducible schema outputs made from scripts.
- `scripts/` contains schema conversion, validation, and compatibility helpers.
- `docs/` contains migration notes, DataHarmonizer compatibility findings, and optimization guides.

## Schema Work Rules

- Treat legacy DataHarmonizer affordances, especially `dh_interface`, as compatibility adapters rather than the canonical model.
- Prefer reusable top-level LinkML `slots` over repeated class `attributes`.
- Prefer an explicit container/root class for serialized data entry packages and integration payloads.
- Keep generated schema documents single-file unless a user explicitly asks for modularized imports.
- Preserve enough metadata for DataHarmonizer testing: class names, titles, descriptions, slot groups, ranges, required flags, examples, and permissible values.

## Validation

Use the dev shell tools from `flake.nix` when available:

- `schema-to-yaml <legacy.json> -o generated/<name>.linkml.yaml`
- `schema-to-dh-yaml <legacy.json> -o generated/<name>.dataharmonizer.yaml`
- `schema-to-json-schema generated/<name>.linkml.yaml`
- `linkml-validate --schema generated/<name>.linkml.yaml <data.yaml>`

For DataHarmonizer compatibility, test both outputs:

- optimized container output: confirms whether DataHarmonizer can parse the container-root alternative.
- compatibility output: keeps `dh_interface` plus `is_a` so current DataHarmonizer template discovery should continue to work.

## Documentation

When schema structure changes, update:

- `docs/schema-optimization.md`
- `docs/dataharmonizer-compatibility.md`

