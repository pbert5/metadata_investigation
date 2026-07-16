#!/usr/bin/env python3
"""Convert legacy LinkML JSON exports into cleaner single-file LinkML YAML."""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Any

import yaml


METADATA_KEYS = {"alias", "domain_of", "from_schema", "owner"}
SLOT_USAGE_KEYS = {
    "equals_string",
    "ifabsent",
    "maximum_value",
    "minimum_value",
    "multivalued",
    "pattern",
    "recommended",
    "required",
}


def ordered_dump(data: dict[str, Any]) -> str:
    class Dumper(yaml.SafeDumper):
        pass

    def represent_ordered_dict(dumper: yaml.Dumper, value: OrderedDict) -> yaml.Node:
        return dumper.represent_mapping("tag:yaml.org,2002:map", value.items())

    Dumper.add_representer(OrderedDict, represent_ordered_dict)
    return yaml.dump(data, Dumper=Dumper, sort_keys=False, allow_unicode=False)


def clean_linkml_value(value: Any) -> Any:
    if isinstance(value, dict):
        cleaned = OrderedDict()
        for key, nested in value.items():
            if key in METADATA_KEYS:
                continue
            cleaned_value = clean_linkml_value(nested)
            if cleaned_value is not None:
                cleaned[key] = cleaned_value
        return cleaned
    if isinstance(value, list):
        return [clean_linkml_value(item) for item in value]
    return value


def slot_payload(attribute: dict[str, Any]) -> OrderedDict:
    payload = clean_linkml_value(attribute)
    payload.pop("name", None)
    for key in SLOT_USAGE_KEYS:
        payload.pop(key, None)
    return payload


def slot_usage_payload(attribute: dict[str, Any]) -> OrderedDict:
    usage = OrderedDict()
    for key in SLOT_USAGE_KEYS:
        if key in attribute and attribute[key] is not None:
            usage[key] = clean_linkml_value(attribute[key])
    return usage


def comparable(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def merge_slot(
    slots: OrderedDict[str, Any],
    slot_name: str,
    attribute: dict[str, Any],
    conflicts: list[str],
) -> None:
    incoming = slot_payload(attribute)
    if slot_name not in slots:
        slots[slot_name] = incoming
        return
    if comparable(slots[slot_name]) != comparable(incoming):
        conflicts.append(slot_name)


def container_slot_name(class_name: str) -> str:
    name = re.sub(r"[^0-9A-Za-z]+", "_", class_name).strip("_").lower()
    if not name:
        name = "template"
    if name[0].isdigit():
        name = f"template_{name}"
    return f"{name}_records"


def class_sort_key(item: tuple[str, Any]) -> tuple[int, str]:
    name, value = item
    if name == "dh_interface":
        return (0, name)
    if isinstance(value, dict) and value.get("is_a") == "dh_interface":
        return (1, name)
    return (2, name)


def build_schema(
    source: dict[str, Any],
    mode: str,
    schema_name: str | None = None,
    schema_id: str | None = None,
    schema_version: str | None = None,
) -> OrderedDict:
    schema = OrderedDict()
    for key in [
        "id",
        "name",
        "description",
        "title",
        "version",
        "license",
        "default_prefix",
        "default_range",
        "prefixes",
        "imports",
    ]:
        if key in source and source[key] is not None:
            schema[key] = source[key]

    schema.setdefault("version", "0.1.0")
    schema.setdefault("in_language", ["en"])
    if schema_name:
        schema["name"] = schema_name
    if schema_id:
        schema["id"] = schema_id
    if schema_version:
        schema["version"] = schema_version

    for key in ["types", "enums"]:
        value = source.get(key)
        if value:
            schema[key] = value

    slots: OrderedDict[str, Any] = OrderedDict()
    classes: OrderedDict[str, Any] = OrderedDict()
    conflicts: list[str] = []
    template_classes: list[str] = []

    for class_name, class_def in sorted(source.get("classes", {}).items(), key=class_sort_key):
        if not isinstance(class_def, dict):
            continue
        if class_name == "dh_interface":
            if mode == "dataharmonizer":
                classes[class_name] = copy.deepcopy(class_def)
            continue

        class_copy = OrderedDict(
            (key, copy.deepcopy(value))
            for key, value in class_def.items()
            if key not in {"attributes", "slot_usage"}
        )
        attributes = class_def.get("attributes") or {}
        class_slots = []
        slot_usage = OrderedDict()
        for slot_name, attribute in attributes.items():
            if not isinstance(attribute, dict):
                continue
            merge_slot(slots, slot_name, attribute, conflicts)
            class_slots.append(slot_name)
            usage = slot_usage_payload(attribute)
            if usage:
                slot_usage[slot_name] = usage

        if class_slots:
            existing_slots = class_copy.get("slots") or []
            class_copy["slots"] = list(dict.fromkeys([*existing_slots, *class_slots]))
        if slot_usage:
            class_copy["slot_usage"] = slot_usage
        if mode == "optimized":
            class_copy.pop("is_a", None)
        elif class_def.get("is_a") == "dh_interface":
            class_copy["is_a"] = "dh_interface"

        classes[class_name] = class_copy
        if class_slots:
            template_classes.append(class_name)

    if conflicts:
        unique = ", ".join(sorted(set(conflicts)))
        raise ValueError(f"Conflicting repeated slot definitions need manual review: {unique}")

    if mode == "optimized":
        container_attributes = OrderedDict()
        for class_name in template_classes:
            container_attributes[container_slot_name(class_name)] = OrderedDict(
                [
                    ("range", class_name),
                    ("multivalued", True),
                    ("inlined_as_list", True),
                    ("description", f"Records using the {class_name} metadata template."),
                ]
            )
        classes["Container"] = OrderedDict(
            [
                ("description", "Container root for metadata template records."),
                ("tree_root", True),
                ("attributes", container_attributes),
            ]
        )

    if slots:
        schema["slots"] = slots
    schema["classes"] = classes
    return schema


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="Legacy LinkML JSON schema.")
    parser.add_argument("-o", "--output", type=Path, help="Output YAML path. Defaults to stdout.")
    parser.add_argument(
        "--mode",
        choices=["optimized", "dataharmonizer"],
        default="optimized",
        help="Output profile to generate.",
    )
    parser.add_argument("--schema-name", help="Override the LinkML schema name.")
    parser.add_argument("--schema-id", help="Override the LinkML schema id.")
    parser.add_argument("--schema-version", help="Override the LinkML schema version.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    source = json.loads(args.input.read_text())
    schema = build_schema(
        source,
        args.mode,
        schema_name=args.schema_name,
        schema_id=args.schema_id,
        schema_version=args.schema_version,
    )
    output = ordered_dump(schema)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output)
    else:
        sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
