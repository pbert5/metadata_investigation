{
  description = "Metadata schema optimization and DataHarmonizer compatibility tooling";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          appRoot = ./datacatlogue_webui_test;
          datacatalogueWebuiImage = pkgs.dockerTools.buildLayeredImage {
            name = "datacatalogue-webui";
            tag = "latest";
            contents = [
              pkgs.python3
              pkgs.coreutils
            ];
            config = {
              Cmd = [ "${pkgs.python3}/bin/python" "/app/run.py" ];
              WorkingDir = "/app";
              Env = [
                "DATACATALOGUE_WEBUI_HOST=0.0.0.0"
                "DATACATALOGUE_WEBUI_PORT=18086"
              ];
              ExposedPorts = { "18086/tcp" = { }; };
            };
            extraCommands = ''
              mkdir -p app
              cp -r ${appRoot}/src app/src
              cp -r ${appRoot}/static app/static
              cp -r ${appRoot}/internal_config app/internal_config
              cp ${appRoot}/run.py app/run.py
            '';
          };
        in
        {
          datacatalogue-webui-docker = datacatalogueWebuiImage;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          scriptPython = pkgs.python3.withPackages (
            ps: with ps; [
              pyyaml
            ]
          );
          schemaToYaml = pkgs.writeShellApplication {
            name = "schema-to-yaml";
            runtimeInputs = [ scriptPython ];
            text = ''
              exec python investigation/scripts/legacy_schema_to_linkml_yaml.py --mode optimized "$@"
            '';
          };
          schemaToDhYaml = pkgs.writeShellApplication {
            name = "schema-to-dh-yaml";
            runtimeInputs = [ scriptPython ];
            text = ''
              exec python investigation/scripts/legacy_schema_to_linkml_yaml.py --mode dataharmonizer "$@"
            '';
          };
          prepareDataHarmonizer = pkgs.writeShellApplication {
            name = "prepare-dataharmonizer";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              pkgs.uv
              scriptPython
            ];
            text = ''
              dh_dir="vendor/DataHarmonizer"
              legacy_schema="kat_schema_prototyping/20260213_bio_automation_metadata_schema_v1.0.5.json"

              if [ ! -d "$dh_dir/.git" ]; then
                mkdir -p vendor
                git clone https://github.com/cidgoh/DataHarmonizer.git "$dh_dir"
              fi

              python investigation/scripts/legacy_schema_to_linkml_yaml.py "$legacy_schema" \
                --mode optimized \
                --schema-name bio_automation_container \
                --schema-id https://example.org/metadata/bio_automation_container \
                -o generated/bio_automation.optimized.linkml.yaml
              python investigation/scripts/legacy_schema_to_linkml_yaml.py "$legacy_schema" \
                --mode dataharmonizer \
                --schema-name bio_automation_dh \
                --schema-id https://example.org/metadata/bio_automation_dh \
                -o generated/bio_automation.dataharmonizer.linkml.yaml

              mkdir -p "$dh_dir/web/templates/bio_automation_container" "$dh_dir/web/templates/bio_automation_dh"
              cp generated/bio_automation.optimized.linkml.yaml "$dh_dir/web/templates/bio_automation_container/schema.yaml"
              cp generated/bio_automation.dataharmonizer.linkml.yaml "$dh_dir/web/templates/bio_automation_dh/schema.yaml"

              (
                cd "$dh_dir/web/templates/bio_automation_dh"
                uv run --project "$PWD/../../../../../investigation" --with linkml-runtime --with dpath --with pyyaml \
                  python ../../../script/linkml.py -i schema.yaml -m
              )
              (
                cd "$dh_dir/web/templates/bio_automation_container"
                uv run --project "$PWD/../../../../../investigation" --with linkml-runtime --with dpath --with pyyaml \
                  python ../../../script/linkml.py -i schema.yaml -m
              )
              python - <<'PY'
              import json
              from pathlib import Path

              menu_path = Path("vendor/DataHarmonizer/web/templates/menu.json")
              menu = json.loads(menu_path.read_text())
              keep = ["bio_automation_container", "bio_automation_dh"]
              filtered = {name: menu[name] for name in keep if name in menu}
              missing = [name for name in keep if name not in filtered]
              if missing:
                  raise SystemExit(f"Missing DataHarmonizer menu entries: {', '.join(missing)}")
              menu_path.write_text(json.dumps(filtered, indent=2, separators=(",", ": ")) + "\n")
              PY
            '';
          };
          dataHarmonizerWeb = pkgs.writeShellApplication {
            name = "dataharmonizer-web";
            runtimeInputs = [
              pkgs.nodejs
              pkgs.yarn
            ];
            text = ''
              port="''${DATAHARMONIZER_PORT:-18084}"
              if [ ! -f vendor/DataHarmonizer/web/templates/bio_automation_container/schema.json ] \
                || [ ! -f vendor/DataHarmonizer/web/templates/bio_automation_dh/schema.json ]; then
                echo "DataHarmonizer templates are missing; run: nix run .#prepare-dataharmonizer" >&2
                exit 1
              fi
              node <<'JS'
              const fs = require('fs');
              const menuPath = 'vendor/DataHarmonizer/web/templates/menu.json';
              const keep = ['bio_automation_container', 'bio_automation_dh'];
              const menu = JSON.parse(fs.readFileSync(menuPath, 'utf8'));
              const filtered = {};
              const missing = [];
              for (const name of keep) {
                if (menu[name]) filtered[name] = menu[name];
                else missing.push(name);
              }
              if (missing.length) {
                console.error('Missing DataHarmonizer menu entries: ' + missing.join(', '));
                process.exit(1);
              }
              fs.writeFileSync(menuPath, JSON.stringify(filtered, null, 2) + '\n');
              JS
              cd vendor/DataHarmonizer
              if [ ! -d node_modules ]; then
                yarn install --frozen-lockfile
              fi
              exec yarn dev --host 127.0.0.1 --port "$port"
            '';
          };
          datacatalogueWebuiTest = pkgs.writeShellApplication {
            name = "datacatalogue-webui-test";
            runtimeInputs = [ pkgs.python3 ];
            text = ''
              exec python datacatlogue_webui_test/run.py "$@"
            '';
          };
        in
        {
          schema-to-yaml = {
            type = "app";
            program = "${schemaToYaml}/bin/schema-to-yaml";
            meta.description = "Convert legacy LinkML JSON into optimized single-file LinkML YAML.";
          };
          schema-to-dh-yaml = {
            type = "app";
            program = "${schemaToDhYaml}/bin/schema-to-dh-yaml";
            meta.description = "Convert legacy LinkML JSON into DataHarmonizer-compatible LinkML YAML.";
          };
          prepare-dataharmonizer = {
            type = "app";
            program = "${prepareDataHarmonizer}/bin/prepare-dataharmonizer";
            meta.description = "Clone/sync DataHarmonizer templates and regenerate schema.json/menu entries.";
          };
          dataharmonizer-web = {
            type = "app";
            program = "${dataHarmonizerWeb}/bin/dataharmonizer-web";
            meta.description = "Run the DataHarmonizer webpack development server.";
          };
          datacatalogue-webui-test = {
            type = "app";
            program = "${datacatalogueWebuiTest}/bin/datacatalogue-webui-test";
            meta.description = "Run the Data Catalogue Web UI prototype server.";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              let
                name = baseNameOf path;
              in
              ! (
                name == ".venv"
                || name == ".pytest_cache"
                || name == "__pycache__"
                || name == ".serena"
              );
          };
          python = pkgs.python3.withPackages (
            ps: with ps; [
              pyyaml
            ]
          );
        in
        {
          schema-conversion = pkgs.runCommand "metadata-schema-conversion" {
            nativeBuildInputs = [ python ];
            inherit src;
          } ''
            cp -r "$src" source
            chmod -R u+w source
            cd source
            python investigation/scripts/legacy_schema_to_linkml_yaml.py \
              kat_schema_prototyping/20260213_bio_automation_metadata_schema_v1.0.5.json \
              --mode optimized \
              -o optimized.yaml
            python investigation/scripts/legacy_schema_to_linkml_yaml.py \
              kat_schema_prototyping/20260213_bio_automation_metadata_schema_v1.0.5.json \
              --mode dataharmonizer \
              -o dataharmonizer.yaml
            python - <<'PY'
            from pathlib import Path
            import yaml

            optimized = yaml.safe_load(Path("optimized.yaml").read_text())
            compat = yaml.safe_load(Path("dataharmonizer.yaml").read_text())

            assert "classes" in optimized
            assert "slots" in optimized
            assert "Container" in optimized["classes"]
            assert "dh_interface" not in optimized["classes"]
            assert "dh_interface" in compat["classes"]
            assert any(
                cls.get("is_a") == "dh_interface"
                for cls in compat["classes"].values()
                if isinstance(cls, dict)
            )
            PY
            touch "$out"
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          scriptPython = pkgs.python3.withPackages (
            ps: with ps; [
              pyyaml
            ]
          );
          linkmlValidate = pkgs.writeShellApplication {
            name = "linkml-validate";
            runtimeInputs = [ pkgs.uv ];
            text = ''
              exec uvx --from linkml linkml-validate "$@"
            '';
          };
          schemaToJsonSchema = pkgs.writeShellApplication {
            name = "schema-to-json-schema";
            runtimeInputs = [ pkgs.uv ];
            text = ''
              exec uvx --from linkml gen-json-schema "$@"
            '';
          };
          linkmlLint = pkgs.writeShellApplication {
            name = "linkml-lint";
            runtimeInputs = [ pkgs.uv ];
            text = ''
              exec uvx --from linkml linkml-lint "$@"
            '';
          };
          schemaToYaml = pkgs.writeShellApplication {
            name = "schema-to-yaml";
            runtimeInputs = [ scriptPython ];
            text = ''
              exec python investigation/scripts/legacy_schema_to_linkml_yaml.py --mode optimized "$@"
            '';
          };
          schemaToDhYaml = pkgs.writeShellApplication {
            name = "schema-to-dh-yaml";
            runtimeInputs = [ scriptPython ];
            text = ''
              exec python investigation/scripts/legacy_schema_to_linkml_yaml.py --mode dataharmonizer "$@"
            '';
          };
          devPython = pkgs.python3.withPackages (
            ps: with ps; [
              pip
              pyyaml
              pytest
            ]
          );
        in
        {
          default = pkgs.mkShell {
            name = "metadata-schema-tools";
            packages = [
              devPython
              pkgs.git
              pkgs.jq
              pkgs.nix
              pkgs.nodejs
              pkgs.yarn
              pkgs.uv
              pkgs.yq-go
              linkmlLint
              linkmlValidate
              schemaToDhYaml
              schemaToJsonSchema
              schemaToYaml
            ];
            shellHook = ''
              echo "Metadata schema tools: schema-to-yaml, schema-to-dh-yaml, schema-to-json-schema, linkml-validate, linkml-lint" >&2
            '';
          };
        }
      );
    };
}
