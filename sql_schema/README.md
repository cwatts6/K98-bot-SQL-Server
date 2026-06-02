# SQL Schema Snapshots

This folder contains one generated file per SQL object:

- `Schema.Name.Table.sql`
- `Schema.Name.View.sql`
- `Schema.Name.StoredProcedure.sql`
- `Schema.Name.UserDefinedFunction.sql`
- `Schema.Name.UserDefinedTableType.sql`

These files are reference material and drift evidence. Intentional SQL changes are deployed from
reviewed migration files in `migrations/`.

When a migration changes an object, update the matching snapshot in this folder as the expected
post-deployment shape where practical. After deployment, run the drift check to confirm Production
matches Git.

Production exports must use `deploy/Export-ProdSchemaSnapshot.ps1` and must not push directly to
`main`.
