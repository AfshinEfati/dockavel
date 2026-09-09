# Changelog

All notable user-facing changes to Dockavel will be documented here.

Dockavel follows Semantic Versioning once a stable release line is published. Until the first release, the repository version remains a development version.

## [Unreleased]

### Added

- Smart project detection for Laravel/Node type, PHP requirement, package manager, database, Redis and Node hints.
- `project:detect` and `project:check` commands.
- Project-aware database status/create/export/import helpers.
- Additional read-only Doctor checks for registered projects and proxy configuration hints.
- Global version metadata and `dockavel version` / `dv`.

### Safety

- Smart detection only suggests values; it does not silently change project metadata.
- Database export refuses to overwrite an existing file.
- Database import requires explicit confirmation and never drops or recreates the database automatically.
- No installer, Compose topology, runtime image, source preset or registry strategy changes are included in this work.
