# Firecasting Project Plan

Status: Canonical cross-repo planning document for the current Firecasting workspace.

Last updated: 2026-03-09

## Future Prompting Guide

Use this file as the default source of truth for cross-repo architecture, direction, and roadmap work in this workspace.

When starting a future Copilot or human task:

- Read this document first for system shape, priorities, and known evidence gaps.
- Use the evidence appendix to jump to the supporting repo files before changing architecture-sensitive code.
- Treat statements marked `Confirmed` as repo-backed facts.
- Treat statements marked `Inference` as working direction, not settled architecture.
- Treat statements marked `Unknown` or `Open question` as unresolved; do not silently convert them into implementation assumptions.

Update this document when any of the following changes happen:

- A cross-repo architectural boundary changes.
- A new API contract or version becomes the supported default.
- A major roadmap phase is completed or reprioritized.
- A previously unknown area becomes confirmed by code, docs, or infrastructure.
- A new architectural decision or tradeoff needs to be recorded.

Keep the section structure stable. Prefer updating existing sections over adding one-off notes elsewhere.

## Scope And Evidence Rules

This plan covers the three repos that make up the current workspace system:

- `firecasting/`: Docker Compose, Traefik, local/prod deployment, and cross-repo entry points.
- `firecasting-backend/`: Spring Boot simulation API and persistence modules.
- `firecasting-frontend/`: React/Vite UI and client-side planning tools.

Evidence discipline for this document:

- Major architectural statements must either cite repo evidence or be labeled `Inference`, `Assumption`, `Unknown`, or `Open question`.
- Placeholder screens, reserved versions, and incomplete docs are treated as signals, not commitments.
- Absence of evidence is not architecture. Missing auth, tenancy, scaling, or service boundaries stay in the unknowns section unless the repo proves them.

## Current State

### Current-State Summary

Confirmed:

- The workspace is a three-repo system: deployment/orchestration in `firecasting/`, a Spring Boot backend in `firecasting-backend/`, and a React/Vite frontend in `firecasting-frontend/`. Evidence: `.github/copilot-instructions.md`.
- The recommended local developer path is Docker Compose through the deployment repo, fronted by Traefik and backed by Postgres. Evidence: `firecasting/README.md`, `firecasting/deploy/dev/compose.yml`.
- The backend is a Maven multi-module project where `application/` is the runnable Spring Boot module and the rest provide domain, simulation, persistence, and shared logic. Evidence: `firecasting-backend/firecasting/pom.xml`, `firecasting-backend/.github/copilot-instructions.md`.
- The frontend is a React 19 + TypeScript + Vite SPA that talks to the backend through fetch endpoints plus SSE for simulation progress. Evidence: `firecasting-frontend/vite-react-frontend/package.json`, `firecasting-frontend/.github/copilot-instructions.md`, `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`.

### Major Subsystems And Responsibilities

Confirmed:

- Edge and deployment: Traefik owns hostname routing, TLS termination, CORS middleware, compression, SSE-specific header behavior, and optional monitoring exposure. Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`, `firecasting/.github/copilot-instructions.md`.
- Backend API and orchestration: the backend accepts simulation requests, deduplicates stable inputs, queues execution, streams progress over SSE, and persists append-only results to Postgres. Evidence: `firecasting-backend/.github/copilot-instructions.md`, `firecasting-backend/firecasting/persistence/`, `firecasting-backend/firecasting/application/`.
- Simulation semantics: backend docs explicitly treat API contracts, data dictionary, and invariants as maintained sources of truth for transport semantics and timing behavior. Evidence: `firecasting-backend/docs/index.md`, `firecasting-backend/docs/contracts/api-versioning.md`, `firecasting-backend/docs/invariants/timing-model.md`.
- Frontend authoring and analysis: the frontend owns user-facing simulation setup, assumptions/defaults UX, results exploration, run diff, replay/import flows, and a broader set of currently mixed live and placeholder planning surfaces. Evidence: `firecasting-frontend/vite-react-frontend/src/AppRoutes.tsx`, `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`, `firecasting-frontend/vite-react-frontend/docs/assumptions-inventory.md`.

### Interaction Pattern

Confirmed:

```text
Browser
  -> Traefik
    -> Frontend static app
    -> Backend HTTP API
      -> Postgres
      -> SSE stream back to browser for simulation progress
```

- The frontend is served as a static app and receives runtime API configuration from a generated `env.js` file at container startup. Evidence: `firecasting-frontend/vite-react-frontend/docker-entrypoint.sh`, `firecasting-frontend/vite-react-frontend/src/config/runtimeEnv.ts`.
- The backend exposes request/response endpoints for run creation, run lookup, diffing, replay/import, results retrieval, and CSV export, plus SSE for progress updates. Evidence: `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`, `firecasting-backend/.github/copilot-instructions.md`.

### Visible Technical Constraints

Confirmed:

- SSE is a critical deployment constraint: the prod stack routes `/api/simulation/progress` through a dedicated higher-priority Traefik router without compression and with buffering disabled. Evidence: `firecasting/deploy/prod/compose.yml`, `firecasting/.github/copilot-instructions.md`.
- The frontend runtime API base URL must be injected per container and is expected to include the simulation API prefix; the current code trims trailing slashes and falls back to `/api/simulation/v3` if nothing is configured. Evidence: `firecasting-frontend/vite-react-frontend/docker-entrypoint.sh`, `firecasting-frontend/vite-react-frontend/src/config/runtimeEnv.ts`, `firecasting-frontend/.github/copilot-instructions.md`.
- Postgres is intentionally internal-only in both dev and prod compose and is not published as a host port. Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`, `firecasting/.github/copilot-instructions.md`.
- Backend transport changes are expected to follow explicit versioning rules, and snapshot tests exist to guard contract drift. Evidence: `firecasting-backend/docs/contracts/api-versioning.md`, `firecasting-backend/docs/adr/0001-openapi-snapshot-testing.md`.
- Default persisted results are compact aggregated summaries rather than per-path traces; detailed trace storage is explicitly deferred or expected to live in a separate artifact path if ever added. Evidence: `firecasting-backend/docs/adr/0002-results-storage-volume.md`.
- The backend already uses bounded TTL-based in-memory caches rather than unbounded process memory for recent run data: yearly summaries (`maxEntries=10`, `ttlMs=300000`), metric summaries (`50`, `900000`), CSV/full results (`2`, `300000`), and timings/meta (`200`, `900000`). Evidence: `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationSummariesCache.java`, `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationMetricSummariesCache.java`, `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationResultsCache.java`, `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationTimingsCache.java`.

### Current Product Surface

Confirmed:

- The core implemented product surface is the simulation workflow: form-driven setup, execution defaults, progress streaming, result retrieval, export, diff, and replay-related pages and API calls. Evidence: `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`, `firecasting-frontend/vite-react-frontend/src/AppRoutes.tsx`.
- The frontend also contains many placeholder or skeleton routes for adjacent planning tools such as time accounting, life events, buffer planning, goal planning, housing, and strategy editors. These currently function as visualized extension points that make missing capabilities and future extension seams visible; they are not evidence that the underlying engines or persisted models already exist. Evidence: `firecasting-frontend/vite-react-frontend/src/AppRoutes.tsx`, maintainer input 2026-03-09.

### Backend Execution And Engine Posture

Confirmed:

- The current deployment shape is single-instance at the API tier in both dev and prod compose. Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`.

Maintainer direction:

- Single-instance backend execution is the deliberate near-term model because the system runs on a single free-tier VM and horizontal scaling is not relevant in the near future.
- The `scheduleBased` simulation engine is the primary engine for current product use, and future engine-selection changes should be treated as explicit architectural work rather than implicit drift.

## Boundaries And Ownership

Confirmed:

- Traefik/deployment repo owns edge behavior: routing, TLS, CORS middleware, compression policy, and runtime environment composition. Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`.
- Backend owns simulation semantics, contract versioning, invariants, queueing, deduplication, reproducibility mechanics, and persisted run history. Evidence: `firecasting-backend/docs/index.md`, `firecasting-backend/.github/copilot-instructions.md`, `firecasting-backend/firecasting/pom.xml`.
- Frontend owns presentation, user workflow composition, local assumptions/defaults UX, client-side scenario sharing, and consumption of backend-owned contracts. Evidence: `firecasting-frontend/.github/copilot-instructions.md`, `firecasting-frontend/vite-react-frontend/docs/assumptions-inventory.md`.
- Postgres is the primary persisted store visible in the repo today. No other cross-repo persistence service is confirmed. Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`.

Inference:

- The intended maintainability boundary is to keep simulation meaning in the backend and let the frontend remain a consumer of backend-defined schemas and result contracts rather than becoming a second source of simulation semantics.

## Target Direction

### Confirmed Direction

Confirmed:

- Keep the simulation platform contract-driven. The backend already treats versioned APIs, OpenAPI snapshots, and invariant docs as guardrails, so future work should preserve that discipline rather than bypass it with ad hoc UI/backend drift. Evidence: `firecasting-backend/docs/index.md`, `firecasting-backend/docs/contracts/api-versioning.md`, `firecasting-backend/docs/adr/0001-openapi-snapshot-testing.md`.
- Keep advanced-mode UI schema backend-driven. The frontend instructions and code assume form schemas are fetched from the backend rather than stored under frontend `public/`. Evidence: `firecasting-frontend/.github/copilot-instructions.md`, `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`.
- Keep reproducibility and deduplication as core platform behavior. The current backend flow and frontend API client both expose run search, replay, diff, and stable seeded execution concepts. Evidence: `firecasting-backend/.github/copilot-instructions.md`, `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`.
- Keep dev/prod deployment parity centered on the same composed topology with environment-driven differences, not separate app architectures. Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`.

### Inferred Direction

Inference:

- The next durable architecture step is to consolidate the current simulation platform and its analysis tooling before expanding the many placeholder planning pages into independently modeled products.
- Shared primitives are more likely to succeed than page-by-page feature islands. The existing frontend already has assumptions governance, saved scenarios, run diffing, replay status, and result retrieval; those are stronger foundations than the placeholder pages themselves.
- If broader lifestyle planning tools become first-class, they should probably reuse scenario, timeline, policy, and comparison primitives rather than inventing separate storage or orchestration stacks.

Maintainer direction:

- Some placeholder surfaces may become independent tools and others may be integrated into the main flow, but that product split is still undecided.

### Expected System Shape

Inference:

- Edge remains Traefik-centered.
- Backend remains the owner of simulation and persisted run data.
- Frontend grows as an orchestration and analysis layer over the current backend surface, with new backend capabilities added when current contracts stop being sufficient.
- Any future scale-oriented changes should be introduced explicitly through new decisions rather than implied by the current single-instance queue and in-memory cache model.

## Roadmap

Roadmap items are ordered by dependency, risk reduction, and architectural importance.

### Phase 1: Establish The Canonical Planning Loop

Outcome:

- One cross-repo project plan exists and is the default reference for future architecture and roadmap tasks.
- Deployment repo README and Copilot instructions point to it.

Why this comes first:

- It removes repeated rediscovery across three repos and gives later implementation work a place to record architectural changes.

Evidence:

- The workspace already has subsystem-specific docs and instructions, but no single cross-repo architecture/roadmap document. Evidence: `firecasting/README.md`, `firecasting-backend/docs/index.md`, `firecasting-frontend/vite-react-frontend/docs/assumptions-inventory.md`.

### Phase 2: Harden The Existing Simulation Platform Contracts

Outcome:

- The repo explicitly documents the non-negotiable edge/runtime/API constraints that already exist.
- The operational stance becomes explicit: no production Postgres backup automation for now, restore goes back to a reference point, and failure recovery should also restore to a reference point while preserving the queue.
- The existing cache behavior and single-instance posture are documented as deliberate near-term constraints instead of open ambiguity.

Why this unblocks later work:

- Feature work on simulation UX, diff, replay, or broader planning tools depends on preserving SSE behavior, API stability, and runtime configuration assumptions.

Evidence:

- SSE handling, contract versioning, and compact result persistence already have clear repo evidence. Evidence: `firecasting/deploy/prod/compose.yml`, `firecasting-backend/docs/contracts/api-versioning.md`, `firecasting-backend/docs/adr/0002-results-storage-volume.md`.

### Phase 3: Add Operator-Friendly Restore And Warm-Start Guidance

Outcome:

- The system has a documented operator path for restoring Postgres to a reference point and, if desired, repopulating frequently used deterministic runs by rerunning a curated set of popular simulations so they become available in the DB again.

Why this comes before broader product expansion:

- The maintainer explicitly does not want general Postgres backup automation right now, but does want a clearer restore/reference-point story and a possible way to repopulate useful persisted runs after restore.

Evidence and constraints:

- Deterministic persisted runs are already part of the backend contract, while random-seed runs are intentionally non-persisted and can only be served from short-lived caches. Evidence: `firecasting-backend/.github/copilot-instructions.md`, `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/FirecastingController.java`, maintainer input 2026-03-09.

### Phase 4: Complete The Already-Exposed Analysis Surface

Outcome:

- The frontend fully capitalizes on backend capabilities that already exist in code and API contracts, especially results-v3 detail, run diff, replay/import, and schema-driven advanced flows.

Why this comes before new product expansion:

- These capabilities already have concrete backend and frontend implementation evidence, which makes them lower-risk and more architecture-grounded than brand-new planning surfaces.

Evidence:

- Current client endpoints include `results-v3`, run diff, run replay/import, and historical run APIs. Evidence: `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`.

### Phase 5: Promote Placeholder Planning Surfaces Through Shared Primitives

Outcome:

- Any placeholder route promoted to real functionality is backed by reusable domain primitives such as scenario models, timeline/event models, policy rules, assumption profiles, and comparison outputs.

Why this ordering matters:

- The route map shows many planned areas, but the repo does not yet prove separate engines, data stores, or contracts for each one. Shared primitives reduce the risk of fragmented one-off implementations.

Evidence:

- Placeholder routes are visible, while assumptions governance and scenario-related utilities already exist. Evidence: `firecasting-frontend/vite-react-frontend/src/AppRoutes.tsx`, `firecasting-frontend/vite-react-frontend/docs/assumptions-inventory.md`.

### Phase 6: Revisit Scale And Storage Deliberately

Outcome:

- Any move toward multi-instance execution, distributed cache coherence, or optional detailed trace artifacts happens through explicit architectural decisions and repo-backed implementation work.

Why this is later:

- The current repo evidence plus maintainer direction support a single-instance queue plus in-memory coordination model and compact relational result persistence. There is not enough evidence, and no near-term product need, to treat scale-out as the current direction.

Evidence:

- Current compose files define one API service, one Postgres service, and no separate cache or worker service. Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`.

## Decision Log

### D-001: This File Is The Canonical Cross-Repo Plan

- Status: Accepted
- Date: 2026-03-09
- Decision: Keep one canonical planning document in `firecasting/docs/project-plan.md` and point adjacent discovery docs to it instead of duplicating cross-repo architecture summaries.
- Rationale: The workspace spans three repos and already has subsystem-specific docs. A single cross-repo plan reduces rediscovery and makes future prompting more consistent.
- Consequences: Cross-repo architecture and roadmap changes should update this file first.

### D-002: Edge Concerns Stay At Traefik

- Status: Accepted
- Evidence: `firecasting/deploy/dev/compose.yml`, `firecasting/deploy/prod/compose.yml`
- Decision: Routing, TLS, CORS middleware, compression, and SSE edge handling remain deployment-layer concerns.
- Rationale: Both dev and prod compose files already centralize these concerns in Traefik.
- Consequences: Backend or frontend changes that depend on edge behavior must be validated against Traefik config, especially SSE.

### D-003: Simulation Progress Uses SSE And Must Stay Uncompressed

- Status: Accepted
- Evidence: `firecasting/deploy/prod/compose.yml`, `firecasting-backend/.github/copilot-instructions.md`, `firecasting-frontend/.github/copilot-instructions.md`
- Decision: The progress channel is SSE, and the deployment path must preserve uncompressed, unbuffered delivery.
- Rationale: The prod stack has dedicated routing and headers specifically for this path.
- Consequences: Changes to routing or middleware require explicit SSE regression checks.

### D-004: Advanced Forms Are Backend-Defined

- Status: Accepted
- Evidence: `firecasting-frontend/.github/copilot-instructions.md`, `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`
- Decision: Advanced-mode form schemas are fetched from the backend, not owned as static frontend assets.
- Rationale: This keeps form shape aligned with backend DTO/schema evolution.
- Consequences: Schema changes are contract work, not just frontend copy changes.

### D-005: Compact Aggregated Results Are The Default Persistence Model

- Status: Accepted
- Evidence: `firecasting-backend/docs/adr/0002-results-storage-volume.md`
- Decision: Persist aggregated yearly and metric summaries by default, not per-path per-step traces.
- Rationale: Storage and I/O costs for detailed traces are explicitly documented as non-viable by default.
- Consequences: Any detailed trace feature should be explicit, bounded, and likely separate from primary relational storage.

### D-006: API Contract Changes Require Versioning Discipline

- Status: Accepted
- Evidence: `firecasting-backend/docs/contracts/api-versioning.md`, `firecasting-backend/docs/adr/0001-openapi-snapshot-testing.md`
- Decision: Breaking transport changes require major-version handling and contract documentation.
- Rationale: The frontend depends on stable payload shapes even though the API is primarily internal.
- Consequences: Future backend changes that alter payload shape or meaning must be planned as contract work.

### D-007: Frontend Runtime API Configuration Is Environment-Injected

- Status: Accepted
- Evidence: `firecasting-frontend/vite-react-frontend/docker-entrypoint.sh`, `firecasting-frontend/vite-react-frontend/src/config/runtimeEnv.ts`
- Decision: The deployed frontend image reads API base URL at runtime from generated `env.js` rather than relying only on baked build-time values.
- Rationale: The same built frontend can be promoted across environments.
- Consequences: Container/runtime changes must preserve `env.js` generation and compatible fallback behavior.

### D-008: Single-Instance Backend Is The Deliberate Near-Term Operating Model

- Status: Accepted
- Date: 2026-03-09
- Decision: Keep the backend single-instance for the near future.
- Rationale: The system runs on a single free-tier VM and horizontal scaling is not relevant in the near term.
- Consequences: Queue coordination and cache design can stay optimized for one instance until product or infrastructure needs change.

### D-009: No General Postgres Backup Automation For Now; Recovery Uses Reference-Point Restore

- Status: Accepted
- Date: 2026-03-09
- Decision: Do not add a general production Postgres backup process for now. Restore and failure recovery should go back to a known reference point, with future operator guidance optionally describing how to repopulate frequently used deterministic simulations into the DB.
- Rationale: This matches current operating constraints and maintainer preference.
- Consequences: Recovery planning should focus on reference-point restore plus optional rerun/warm-start guidance rather than a fuller backup platform.

### D-010: scheduleBased Is The Primary Simulation Engine

- Status: Accepted
- Date: 2026-03-09
- Decision: Treat the `scheduleBased` simulation engine as the primary engine for current product use.
- Rationale: Maintainer direction.
- Consequences: Future engine-selection changes or comparisons should be explicit and documented.

### D-011: Frontend Serialization Formats Should Prefer Backward Compatibility Via Upgrade

- Status: Accepted
- Date: 2026-03-09
- Decision: Scenario/share-link and replay bundle formats should aim for backward compatibility, primarily by upgrading older data into the current shape.
- Rationale: Maintainer direction.
- Consequences: Future format changes should include upgrader logic or migration rules rather than only invalidating older data.

### D-012: Placeholder Pages Exist As Visualized Extension Points

- Status: Accepted
- Date: 2026-03-09
- Decision: Treat placeholder pages as extension points that expose missing capabilities and future seams, not as a fixed delivery sequence.
- Rationale: Maintainer direction.
- Consequences: Roadmap prioritization should stay flexible, and placeholder pages can become either standalone tools or flow-integrated tools.

## Risks

Confirmed risks from repo evidence:

- SSE regressions are easy to introduce through middleware or routing changes because prod explicitly carries special-case routing and headers for that path.
- Operational durability intentionally relies on reference-point restore rather than automated Postgres backup, which makes recovery speed and restore correctness more important than backup orchestration.
- The backend is intentionally optimized for single-instance queue coordination and in-memory caches; if infrastructure constraints change later, the scale transition will need explicit design work.
- The frontend route surface is broader than the clearly evidenced backend/domain support, creating a risk of implementing placeholder pages faster than shared architecture matures.

## Assumptions

Assumption:

- The core near-term value of the system remains centered on simulation, run analysis, and planning workflows that can reuse the current simulation platform.
- The many placeholder planning routes are visual extension points, not already-approved delivery commitments.
- The backend docs folder, ADRs, and contract docs should remain the detailed source for backend semantics, while this file stays at the cross-repo level.

## Unknowns And Open Questions

Unknown:

- What is the precise operator workflow for preserving and restoring queue state when recovering to a reference point?
- What should the first curated set of "most used" deterministic simulations be if a warm-start/rerun process is added after restore?
- Which placeholder frontend surfaces should become standalone tools versus become part of the main simulation/planning flow?
- When frontend serialization formats change, where should upgrader logic live and how should compatibility be tested?

## Evidence Gaps

Missing inputs needed before making stronger architectural claims:

- A concrete queue-persistence and queue-restore design, if failure recovery must preserve queued work across process or VM recovery.
- A concrete operator runbook for restoring to a reference point and optionally repopulating popular deterministic simulations.
- Product prioritization for which placeholder surfaces graduate first and whether they should be standalone or flow-integrated.

## Maintenance Rules

When updating this file:

- Keep `Current State` factual and repo-backed.
- Move resolved unknowns into confirmed sections only after code, docs, or infra evidence exists.
- Add a new decision-log entry when a cross-repo architectural choice is made.
- Update the roadmap when a phase is completed, reprioritized, or invalidated.
- Prefer linking to subsystem docs instead of duplicating detailed backend or frontend reference material.

## Evidence Appendix

High-signal sources used to build and maintain this plan:

- Workspace overview: `.github/copilot-instructions.md`
- Deployment entry point: `firecasting/README.md`
- Deployment conventions: `firecasting/.github/copilot-instructions.md`
- Dev topology: `firecasting/deploy/dev/compose.yml`
- Prod topology and SSE routing: `firecasting/deploy/prod/compose.yml`
- Backend conventions: `firecasting-backend/.github/copilot-instructions.md`
- Backend documentation boundaries: `firecasting-backend/docs/index.md`
- Backend contract/versioning policy: `firecasting-backend/docs/contracts/api-versioning.md`
- Backend timing invariants: `firecasting-backend/docs/invariants/timing-model.md`
- Backend result-storage ADR: `firecasting-backend/docs/adr/0002-results-storage-volume.md`
- Backend module structure: `firecasting-backend/firecasting/pom.xml`
- Backend cache implementations: `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationSummariesCache.java`, `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationMetricSummariesCache.java`, `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationResultsCache.java`, `firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/simulation/SimulationTimingsCache.java`
- Frontend conventions: `firecasting-frontend/.github/copilot-instructions.md`
- Frontend route surface: `firecasting-frontend/vite-react-frontend/src/AppRoutes.tsx`
- Frontend API surface: `firecasting-frontend/vite-react-frontend/src/api/simulation.tsx`
- Frontend runtime config: `firecasting-frontend/vite-react-frontend/src/config/runtimeEnv.ts`
- Frontend container injection: `firecasting-frontend/vite-react-frontend/docker-entrypoint.sh`
- Frontend assumptions/discovery doc: `firecasting-frontend/vite-react-frontend/docs/assumptions-inventory.md`
