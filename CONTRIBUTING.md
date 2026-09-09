# Contributing to Dockavel

Dockavel intentionally keeps its core small and focused. A user-facing feature belongs in the core when it materially improves project setup, multi-project management, or local-environment debugging.

## Product architecture

Do not change the runtime/source architecture casually. Changes to image strategy, download-source behavior, Compose topology, runtime strategy, or registry publishing should be proposed explicitly and reviewed before implementation.

Regional presets must stay explicit. A selected regional source must not silently fall back to another registry or package source.

## Documentation sync policy

The runtime repository and the public website/documentation are maintained as one product surface.

For every new or materially changed user-facing feature, service, runtime, source preset, CLI command, configuration option, port, workflow, or behavior:

1. update `README.md` and `README.fa.md` when the runtime overview changes,
2. update the matching documentation page in `AfshinEfati/dockavel-site`,
3. update the landing page when the capability belongs in the product overview,
4. keep English and Persian docs aligned,
5. update the site sitemap when a new documentation route is introduced.

Internal refactors and bug fixes that do not change user-facing behavior do not require landing-page changes.

## Data safety

Avoid destructive Docker cleanup in examples and fixes unless data deletion is explicitly intended.

Prefer:

```bash
docker compose down --remove-orphans
```

Do not use `docker compose down -v`, image pruning, builder pruning, or volume deletion as routine troubleshooting steps.

`project:remove` must continue to remove Dockavel registration only and must not delete project source code.

## Validation

Before merging a runtime change, validate the affected combination of:

- Docker Compose configuration
- enabled profiles
- PHP/Node runtime behavior
- installer behavior
- CLI syntax and smoke tests
- Nginx configuration when routing changes
- documentation/site synchronization for user-facing changes
