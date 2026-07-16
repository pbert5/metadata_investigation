In LinkML/DataHarmonizer, a **Container** is basically the **top-level box that says what kinds of records are inside a dataset**.

It is not a Docker container.

Think of this schema:

```yaml
classes:
  Plate:
    attributes:
      plate_id:
        range: string

  Sample:
    attributes:
      sample_id:
        range: string

  Container:
    tree_root: true
    attributes:
      plates:
        range: Plate
        multivalued: true
        inlined_as_list: true

      samples:
        range: Sample
        multivalued: true
        inlined_as_list: true
```

The resulting data looks like:

```yaml
plates:
  - plate_id: plate_001
  - plate_id: plate_002

samples:
  - sample_id: sample_001
  - sample_id: sample_002
```

So the Container is saying:

```text
This file contains:
  a list of Plates
  a list of Samples
```

## What each part means

```yaml
Container:
  tree_root: true
```

`tree_root: true` means:

> Start reading the dataset here.

Then:

```yaml
plates:
  range: Plate
```

means:

> The values under `plates` are Plate objects.

And:

```yaml
multivalued: true
```

means:

> There can be multiple plates.

Finally:

```yaml
inlined_as_list: true
```

means:

> Store the complete Plate objects directly inside the list.

## Why DataHarmonizer cares

DataHarmonizer can use the Container to decide which classes should appear as usable spreadsheet templates.

For example:

```yaml
classes:
  ClassA:
    is_a: dh_interface

  ClassB:
    is_a: ClassA

  Container:
    tree_root: true
    attributes:
      class_b_records:
        range: ClassB
        multivalued: true
        inlined_as_list: true
```

Even though `ClassB` does not directly say:

```yaml
is_a: dh_interface
```

the Container tells DataHarmonizer:

> ClassB is one of the record types this dataset contains, so expose it as a table/template.

The DataHarmonizer menu generator checks whether a class is directly under `dh_interface`, then also checks whether that class appears as the range of a Container attribute.

## ELI5 picture

```text
Container
├── Plates
│   ├── Plate 1
│   └── Plate 2
│
└── Samples
    ├── Sample 1
    └── Sample 2
```

The Container usually has little or no scientific data of its own. It mainly organizes the other classes and defines the shape of the complete file.
