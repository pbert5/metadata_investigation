# Metadata Schema Tools

This repo is a small working area for optimizing legacy LinkML/DataHarmonizer metadata schemas.

The current source example is:

```text
examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json
```

That legacy schema was shaped around DataHarmonizer's older `dh_interface` pattern. The tooling here generates two single-file LinkML YAML profiles from it:

- `generated/microbial_templates.optimized.linkml.yaml`: canonical candidate with reusable top-level `slots` and a `Container` root.
- `generated/microbial_templates.dataharmonizer.linkml.yaml`: compatibility adapter that keeps `dh_interface` and `is_a: dh_interface`.

Both profiles can also be emitted as JSON Schema:

- `generated/microbial_templates.optimized.schema.json`
- `generated/microbial_templates.dataharmonizer.schema.json`

## Quick Start

Enter the dev shell:

```bash
nix develop
```

## Entry Points

Flake apps:

```bash
nix run .#schema-to-yaml -- <legacy-schema.json> -o <optimized.linkml.yaml>
nix run .#schema-to-dh-yaml -- <legacy-schema.json> -o <dataharmonizer.linkml.yaml>
nix run .#prepare-dataharmonizer
nix run .#dataharmonizer-web
```

Dev-shell commands:

```bash
schema-to-yaml
schema-to-dh-yaml
schema-to-json-schema
linkml-validate
linkml-lint
```

Python package script:

```bash
legacy-schema-to-linkml-yaml --help
```

Core script entry point:

```bash
python scripts/legacy_schema_to_linkml_yaml.py --help
```

DataHarmonizer web entry points:

```text
http://127.0.0.1:18084/?template=km_microbial_container/DNA-seq
http://127.0.0.1:18084/?template=km_microbial_dh/DNA-seq
```

Regenerate the optimized schema:

```bash
schema-to-yaml examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json \
  --schema-name KM_microbial_container \
  --schema-id https://example.org/metadata/KM_microbial_container \
  -o generated/microbial_templates.optimized.linkml.yaml
```

Regenerate the DataHarmonizer compatibility schema:

```bash
schema-to-dh-yaml examples/outdated/20260225_KM_microbial_templates_schema_v2.2.0.json \
  --schema-name KM_microbial_dh \
  --schema-id https://example.org/metadata/KM_microbial_dh \
  -o generated/microbial_templates.dataharmonizer.linkml.yaml
```

Generate JSON Schema:

```bash
schema-to-json-schema generated/microbial_templates.optimized.linkml.yaml \
  > generated/microbial_templates.optimized.schema.json

schema-to-json-schema generated/microbial_templates.dataharmonizer.linkml.yaml \
  > generated/microbial_templates.dataharmonizer.schema.json
```

## DataHarmonizer Web UI

Prepare a local DataHarmonizer checkout and sync both generated profiles into its template folder:

```bash
nix run .#prepare-dataharmonizer
```

This writes DataHarmonizer's local `web/templates/menu.json` with only the two repo-owned template groups:

- `KM_microbial_container`
- `KM_microbial_dh`

Start the web UI:

```bash
nix run .#dataharmonizer-web
```

The web launcher also enforces the same filtered menu before starting, so upstream DataHarmonizer templates do not appear in the local UI.

The default local URL is:

```text
http://127.0.0.1:18084/
```

Direct template links:

```text
http://127.0.0.1:18084/?template=km_microbial_container/DNA-seq
http://127.0.0.1:18084/?template=km_microbial_dh/DNA-seq
```

Port `18084` was chosen to avoid the home flake inventory ports and eVOLVER's local defaults (`18082`, `18083`, and hardware Socket.IO on `8081`).

## Validation

Run the project checks:

```bash
nix flake check
```

Useful docs:

- `docs/schema-optimization.md`
- `docs/dataharmonizer-compatibility.md`
