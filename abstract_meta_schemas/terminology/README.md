# Terminology Tables

These files are the proposed admin-facing vocabulary layer.

They are TSV rather than embedded LinkML enums so non-developer admins can maintain terms without touching schema structure. If ODS files are preferred for editing, keep the same columns and export to TSV before generation.

Required columns:

```text
term_set	id	label	status	definition	aliases	source
```

Status values:

- `active`: valid for new data.
- `deprecated`: retained for old data but hidden from new-entry dropdowns.
- `candidate`: proposed term pending review.

The generator should convert each `term_set` into the enum or permissible-value structure required by a profile.
