# Frontend UI Plan: Visual Refresh, Navigation Rework, Phased Page Completion

Status: Maintainer-approved plan for `firecasting-frontend/`.

Date: 2026-08-07

Canonical cross-repo reference: `firecasting/docs/project-plan.md`. This document is the
detailed frontend-subsystem breakdown referenced from that plan's Roadmap (Phase 5, "Promote
Placeholder Planning Surfaces Through Shared Primitives") and Decision Log (D-013).

## Context

The frontend (`firecasting-frontend/vite-react-frontend`) has grown to 47 planned pages
across 10 nav groups, but only 17 are "live" — the rest are auto-generated skeleton pages
(`src/pages/skeleton/SkeletonPage.tsx`) with disabled buttons and placeholder inputs. The nav
drawer already hides skeleton routes (`LIVE_PATHS` in `src/components/AppNavDrawer.tsx`),
which is why it doesn't feel crowded yet — but as pages go live, some groups (Lifestyle: 13
items) will become unwieldy, and there's no consolidated design system: every page redefines
its own `cardStyle`/`inputStyle`/`chipStyle` inline (1,864 inline `style={{...}}` usages
app-wide; the Vite starter's default CSS is still untouched). The maintainer wants the app to
look and feel more polished, wants the nav restructured before it grows further, and wants a
phased plan for finishing the remaining ~30 pages.

Decisions made with the maintainer (2026-08-07):

- **Styling**: adopt Tailwind CSS (not just refined inline-style tokens).
- **Nav**: consolidate the 10 groups into ~4-5 top-level groups with collapsible sections,
  keeping the existing `/category/:categoryId` landing pages as the "see everything"
  overflow. Nav items should also get icons for visual scannability (see Phase 1).

Backend check (`firecasting-backend/firecasting/application/src/main/java/dk/gormkrings/FirecastingController.java`):
the backend only exposes simulation run/results/diff endpoints built around `PhaseRequest`
(`DEPOSIT`/`PASSIVE`/`WITHDRAW`, with `monthlyDeposit`, `yearlyIncreaseInPercentage`,
`withdrawRate`/`withdrawAmount`, variation bounds). There are **no** endpoints for lifestyle
calculators, portfolio tracking, community benchmarks, or sharing — confirming the
corresponding pages are meant to be local-only calculators (matching the pattern already used
by `MoneyPerspectivePage`, `DecisionJournalPage`, `NoSpendChallengeArenaPage`). Only Deposit
Strategy / Withdrawal Strategy / Policy Builder connect to real backend fields, and even then
the backend model is simpler than the current skeleton copy implies (no
guardrails/routing/bad-year-playbook fields exist yet) — called out explicitly in Phase 2.
This aligns with `project-plan.md`'s existing Assumption that "the many placeholder planning
routes are visual extension points, not already-approved delivery commitments" and with
D-012.

---

## Phase 0 — Design system foundation (Tailwind + shared primitives)

Do this first since every later phase builds on it.

1. **Install Tailwind v4** via `@tailwindcss/vite` (no separate `tailwind.config.js`/
   `postcss.config.js` needed — v4 configures via CSS). Add the plugin in `vite.config.ts`
   next to the existing `react()`/`VitePWA()` plugins.
2. In `src/index.css`, add `@import "tailwindcss";` and an `@theme` block that maps the
   existing `--fc-card-bg`, `--fc-card-border`, `--fc-card-text`, `--fc-subtle-bg`, etc. into
   Tailwind theme tokens, plus a proper type scale and spacing scale (the current `h1` is the
   untouched Vite default `3.2em` — needs a real scale). Keep dark/light via
   `prefers-color-scheme` (Tailwind v4's default `dark:` strategy) — matches current
   behavior; no manual toggle exists today so don't add one.
3. Add a small primitives folder `src/components/ui/`: `Button` (primary/secondary/ghost
   variants), `Card`, `Input`, `Select`, `Textarea`, `Chip`, `FieldRow`, `PageHeader`. These
   directly replace the repeated local consts (`cardStyle` alone is redefined in 16+ files;
   `inputStyle`/`chipStyle`/`primaryButtonStyle` similarly duplicated, e.g.
   `FireSimulatorPage.tsx:22-75`, `AssumptionsHubPage.tsx:75-100`,
   `pages/catalog/pageCatalog.tsx:214-229`).
4. Migrate the shared chrome that every page renders through, since fixing these fixes the
   feel of the whole app at once: `PageLayout.tsx`, `AppNavDrawer.tsx`, `LandingPage.tsx`,
   `CategoryLandingPage.tsx`, `skeleton/SkeletonPage.tsx`, `skeleton/SkeletonWidgets.tsx`,
   `AssumptionsSummaryBar.tsx`. Keep the `PageLayout` API (`variant`, `maxWidthPx`,
   `paddingPx`) unchanged so no callers need to change.
5. Leave the other 16 already-live pages on their current inline styles for now — don't do a
   big-bang rewrite. They get migrated opportunistically in Phase 7.

## Phase 1 — Navigation rework

1. Restructure `NAV_GROUPS` in `AppNavDrawer.tsx` from 10 flat groups into ~5:
   - **Home** (Home, Explainer, Feedback, Assumptions Hub, Security & Privacy) — small,
     always-relevant utility group.
   - **Simulate** (Tutor, FIRE Simulator, Legacy Simulator, Simulation Plan, Simulation
     Invest, Simulation Engine, Comparator, Stress Test Lab, Model Validation Suite,
     Explorer).
   - **Plan & Strategy** (Deposit Strategy, Withdrawal Strategy, Policy Builder, Scenario
     Library, FIRE Milestones, Confidence Funnel, Goal Planner, Uncertainty Tracks, Plan
     Report) — the "shape and track the plan" layer.
   - **Lifestyle Tools** (Salary Taxator, Money Perspectivator, Tax Optimizer, Time
     Accounting, Fixed vs Flexible Spending, Life Events, Side Hustle Lab, Housing Decision
     Studio, Household Negotiation, Family Mode, Debt Freedom, Emergency Buffer, Insurance
     Risk Shield) — largest group; still the same items as today's "Lifestyle", just
     collapsible.
   - **Track & Reflect** (Cashflow Command Center, Progress Tracker, Portfolio, Sequence
     Risk Radar, Decision Journal, Decision Replay, Happiness Tracker, Community Benchmarks,
     Advisor/Share Portal, No-Spend Challenge Arena).

   `NavGroup`'s shape (`id`, `title`, `to`, `items`) stays the same, so
   `CategoryLandingPage.tsx` and `LandingPage.tsx` (which both just consume `NAV_GROUPS`)
   keep working unchanged — regrouping is a single source-of-truth edit.
2. Add per-group collapse/expand state in `AppNavDrawer.tsx`: a chevron toggle on each group
   header, default state = expand only the group containing the current route, collapse the
   rest. Persist user overrides the same way `uiPreferences.tsx` persists prefs (new
   `src/state/navPreferences.ts`, same `localStorage` + React context pattern, its own
   `firecasting:navPrefs:v1` key).
3. **Icons**: give each nav group and each nav item a small leading icon for visual
   scannability (a flat list of 47 text labels is hard to scan; icons make groups
   recognizable at a glance and help the collapsed/expanded drawer read faster). Add a
   lightweight tree-shakeable icon dependency (e.g. `lucide-react`) rather than hand-rolling
   SVGs — pick one icon per `NavGroup` (shown next to the group header) and one per `NavItem`
   (shown next to the item label). Keep icons purely decorative (`aria-hidden`) since labels
   already carry the accessible name.
4. Keep the existing `isSkeletonRoute`/`LIVE_PATHS` filtering as-is — pages continue to
   appear in the nav only once they're actually built, which is what keeps the drawer sane
   during the rest of this rollout.

## Phase 2 — Strategy core (closes the simulation loop)

**Correction (2026-08-07): this phase turned out to already be done at the logic level.**
When Phase 1 work touched `AppNavDrawer.tsx`'s `LIVE_PATHS`, reading the actual page source
showed `PolicyBuilderPage.tsx`, `DepositStrategyPage.tsx`, and `WithdrawalStrategyPage.tsx`
are full bespoke implementations (729/431/448 lines respectively) with real rule/schedule
editors, local preview calculations, and profile save/load/export/import — not `SkeletonPage`
placeholders as originally assumed from the nav-visibility signal alone. They were simply
missing from `LIVE_PATHS`, which has now been fixed (see Phase 1 status).

What remains for these three pages is **only** a Tailwind restyle — they still use the
pre-Phase-0 local `cardStyle`/`chipStyle` inline-style pattern. That work has been folded into
Phase 7 rather than kept as a separate phase. Note for future work: `strategy/
StrategyScaffoldPage.tsx` is a generic profile-persistence scaffold that appears to be unused
dead code (not routed anywhere, superseded by the three bespoke pages) — worth a deliberate
remove-or-repurpose decision later, not addressed in this pass.

If the guardrail-trigger / contribution-routing-priority / bad-year-playbook fields visible in
these pages' UI ever need to actually affect a simulation run, that still requires a backend
`PhaseRequest` model extension (today's fields are `monthlyDeposit`, `initialDeposit`,
`yearlyIncreaseInPercentage`, `withdrawRate`/`withdrawAmount`, variation bounds — no guardrail/
routing/playbook concept exists there yet). That's unchanged from the original assessment and
still flagged as a maintainer decision, not a frontend-only task.

## Phase 3 — Reporting & milestones layer

Finish `FIRE Milestones`, `Confidence Funnel`, `Uncertainty Tracks`, `Plan Report`, `Goal
Planner`, `Scenario Library`. These read from existing simulation output
(`YearlySummary`/`MetricSummary`, already fetched via `src/api/simulation.tsx` and rendered in
`SimulationChart.tsx`/`YearlySummaryOverview.tsx`) — reuse those data shapes and chart
patterns (recharts is already a dependency) rather than inventing new ones.

## Phase 4 — Lifestyle calculator suite

Finish the 10 remaining Lifestyle-group skeletons: Time Accounting, Fixed vs Flexible
Spending, Life Events Simulator, Side Hustle Lab, Housing Decision Studio, Household
Negotiation Board, Family Mode Planner, Debt Freedom Optimizer, Emergency Buffer Optimizer,
Insurance Risk Shield. All are pure client-side calculators (no backend involvement, per the
controller check above) — pattern each one off `MoneyPerspectivePage.tsx`/
`lib/moneyPerspective/calculations.ts` (local calc functions + a page that wires inputs to
them) or `DecisionJournalPage.tsx` (local persisted log). These are independent of each other
and of Phase 2/3, so they can be built in any order or split across contributors.

## Phase 5 — Execute/operate dashboards

Finish `Cashflow Command Center`, `Portfolio`, `Sequence Risk Radar`. These are heavier:
Cashflow needs a real recurring-expense/calendar model that doesn't exist yet anywhere in the
app; Portfolio needs a holdings model; Sequence Risk Radar can likely reuse simulation
percentile output similar to Phase 3. Scope these individually before starting — they're the
least "just wire up existing data" of the remaining pages.

## Phase 6 — Reflect & validation (lowest priority / needs product decisions)

`Decision Replay`, `Happiness Tracker`, `Stress Test Lab`, `Model Validation Suite` are
buildable as local-only features similar to Phase 4. `Community Benchmarks` (needs an
anonymized aggregation backend + k-anonymity policy) and `Advisor/Share Portal` (needs
auth + permissioned sharing) require actual backend/product decisions before frontend work
starts — flag these to the maintainer rather than scaffolding fake functionality.

## Phase 7 — Retrofit already-live pages onto the design system

Once Phase 0's primitives exist, migrate the now-20 live pages off their local inline
`cardStyle`/`inputStyle` consts and onto `src/components/ui/*`, prioritized by traffic:
`FireSimulatorPage`, `AssumptionsHubPage`, `SimulationPage` first (most-used), then
`PolicyBuilderPage`/`DepositStrategyPage`/`WithdrawalStrategyPage` (see Phase 2 correction —
these are functionally complete, restyle only), then the rest. Lowest priority — do
opportunistically alongside other phases, not as a blocking phase.

---

## Verification

- `npm run dev` in `vite-react-frontend/`, visually check: nav collapse/expand persists
  across reload, group auto-expands on the active route, light/dark mode still matches
  `prefers-color-scheme`, `/` and `/category/:id` still render every item correctly after the
  `NAV_GROUPS` restructure.
- `npm run build` (runs `tsc -p tsconfig.app.json && vite build`) to catch type errors from
  the primitives migration.
- `npm run test` — existing suite (`NormalInputForm.*.test.tsx`, `AssumptionsHubPage.test.tsx`,
  `PolicyBuilderPage.test.tsx`, `DepositStrategyPage.test.tsx`, etc.) must keep passing;
  extend it for each newly-built page in Phases 2-6 following the existing per-page
  `*.test.tsx` pattern.
- `npm run verify` (lint + test + assumptions-registry check) before considering any phase
  done.

## Status Tracking

Update this section as phases complete (mirrors the "keep roadmap current" rule in
`project-plan.md`).

- [x] Phase 0 — Design system foundation (2026-08-07). Tailwind v4 installed via
      `@tailwindcss/vite`; `@theme` tokens in `index.css` map onto the existing `--fc-*`
      CSS variables so light/dark (`prefers-color-scheme`) kept working unchanged. Added
      `src/components/ui/` primitives (`Button`/`LinkButton`, `Card`/`Panel`, `Input`/
      `Textarea`/`Select`, `Chip`, `FieldRow`, `PageHeader`). Migrated the shared chrome:
      `pageCatalog.tsx`, `LandingPage.tsx`, `CategoryLandingPage.tsx`, `SkeletonPage.tsx`,
      `SkeletonWidgets.tsx`, `AssumptionsSummaryBar.tsx`. `PageLayout.tsx` left as-is
      (pure layout math, no visual styling to migrate). Build/tests/lint all green.
- [x] Phase 1 — Navigation rework (2026-08-07). `NAV_GROUPS` consolidated from 10 groups
      into 5 (Home, Simulate, Plan & Strategy, Lifestyle Tools, Track & Reflect) with a
      `lucide-react` icon per group and per item. Added per-group collapse/expand
      (`src/state/navPreferences.ts`, localStorage-backed, same pattern as
      `uiPreferences.tsx`) — default expands the group containing the active route,
      persists explicit user toggles. Verified visually with Playwright screenshots
      (pinned nav at wide viewport, collapse toggle, no console errors).
      **Correctness fix found and applied along the way**: `LIVE_PATHS` was stale —
      Policy Builder, Deposit Strategy, and Withdrawal Strategy already had complete,
      real implementations (full forms, local calculations, profile save/load/export/
      import) but were missing from `LIVE_PATHS`, so they were invisible in the nav.
      Added them. Also removed ~160 lines of dead/unreachable `skeletonRoutes` entries
      in `AppRoutes.tsx` for those same three paths — they were shadowed by the real
      `<Route>` entries and could never render.
- [x] Phase 2 — Strategy core (2026-08-07). **Scope corrected**: this phase was
      essentially already done at the logic level. `PolicyBuilderPage.tsx`,
      `DepositStrategyPage.tsx`, and `WithdrawalStrategyPage.tsx` are full bespoke
      implementations — not `SkeletonPage` wrappers — with rule/schedule editors, local
      preview calculations, and profile save/load/export/import via
      `strategy/strategyProfiles.ts`. The only remaining work — a Tailwind restyle onto the
      Phase 0 primitives (they still used the pre-Phase-0 inline `cardStyle`/`chipStyle`
      pattern) — was completed in this same pass rather than deferred to Phase 7. Added a
      `chipButtonClass` export to `src/components/ui/Chip.tsx` for the small pill-shaped
      toolbar buttons repeated ~12x per page. All existing tests
      (`PolicyBuilderPage.test.tsx`, `DepositStrategyPage.test.tsx`,
      `strategy/StrategyScaffoldPage.test.tsx`) kept passing unchanged, since only markup/
      styling changed, not behavior or `aria-label`s. Note: `strategy/
      StrategyScaffoldPage.tsx` is a generic scaffold component that turned out to be
      unused dead code (superseded by the three bespoke pages above, not routed anywhere)
      — left in place but flagged here for a future cleanup decision.
- [x] Phase 3 — Reporting & milestones layer (2026-08-07). Built all six pages for real:
      `ScenarioLibraryPage` (wired directly to existing `listSavedScenarios`/`deleteScenario`/
      `SIMULATION_TEMPLATES` — no new storage), `GoalPlannerPage` (local multi-goal
      priority-weighted split calculator with conflict warnings, localStorage-persisted),
      `FireMilestonesPage` (local buffer/coast/lean/FIRE compound-growth calculator off real
      `expectedReturnPct`/`safeWithdrawalPct` assumptions), `ConfidenceFunnelPage` and
      `UncertaintyTracksPage` (both read real P5/P25/median/P75/P95 quantile data from the
      user's most recent simulation run via a new shared hook,
      `src/state/latestSimulationResult.ts` — honest empty state when no run exists yet,
      verified via screenshot), `PlanReportPage` (assembles real assumptions + real last-run
      stats + a few threshold-driven "next actions", not fabricated numbers). Explicitly
      did **not** build the "compare interventions" side of Confidence Funnel (would need a
      second live simulation run to diff against) — pointed users at the existing Comparator
      page instead rather than fake it. All 6 pages verified with Playwright (no console
      errors, real/empty-state data paths both checked).
- [x] Phase 4 — Lifestyle calculator suite (2026-08-07). Built all 10 pages as real local
      calculators (no backend involvement, confirmed correct in Phase 0 research):
      `TimeAccountingPage`, `FixedVsFlexibleSpendingPage`, `LifeEventsSimulatorPage`
      (localStorage-persisted event timeline + cashflow-impact chart), `SideHustleLabPage`,
      `HousingDecisionStudioPage` (rent-vs-buy with real monthly mortgage amortization and
      home-equity tracking — see bug note below), `HouseholdNegotiationBoardPage`,
      `FamilyModePlannerPage` (localStorage-persisted childcare waves), `DebtFreedomOptimizerPage`
      (real snowball/avalanche amortization simulator, correct minimum-payment-then-cascade
      logic), `EmergencyBufferOptimizerPage` (transparent additive heuristic, explicitly
      labeled as such — not a statistical model), `InsuranceRiskShieldPage`. All wired into
      `AppRoutes.tsx` and `LIVE_PATHS`, verified with Playwright screenshots across all 10
      (no console errors).
      **Bug caught during visual verification**: Housing Decision Studio's first draft credited
      the home's *full* value appreciation against only the cash spent so far, producing a
      nonsensical "break-even year 1". Rewrote to track real loan amortization (principal vs
      interest split) and compare home equity (value minus remaining loan balance) against an
      invested-down-payment portfolio — break-even now lands at a plausible year 4 for the
      default inputs.
- [x] Phase 5 — Execute/operate dashboards (2026-08-07). `CashflowCommandCenterPage`
      (localStorage-persisted recurring items + annual spikes → real 12-month calendar with
      surplus/deficit highlighting), `PortfolioPage` (localStorage-persisted holdings →
      real weighted-average blended fee, largest-holding concentration score, account-type
      breakdown), `SequenceRiskRadarPage` (real P5/median/P95 data from the latest run,
      with a reference line marking the actual DEPOSIT→WITHDRAW phase transition read from
      `YearlySummary.phaseName` — plus a clearly-labeled local heuristic for a bad-year
      spending cut, not derived from the simulation). All verified with Playwright (no
      console errors, correct math spot-checked by hand against the screenshots).
- [x] Phase 6 — Reflect & validation (2026-08-07). Built the 4 pages that don't need a
      backend/product decision: `DecisionReplayPage` (reuses `DecisionJournalPage`'s existing
      localStorage entries via new exports — `listDecisionJournalEntries`,
      `DECISION_JOURNAL_STORAGE_KEY` — rather than duplicating storage), `HappinessTrackerPage`
      (localStorage daily log + real timeline chart), `StressTestLabPage` (local compounding
      model with a shock window, honestly labeled as "not a Monte Carlo simulation" with a
      pointer to the real FIRE Simulator for percentile-based results), `ModelValidationSuitePage`
      (6 real client-side coherence checks against live `Assumptions` values — e.g. SWR vs
      expected return, guardrail floor/ceiling ordering — not fabricated backtest results).
      **Deliberately left as skeletons**: `/community-benchmarks` (needs an anonymized
      aggregation backend + k-anonymity policy) and `/advisor-share-portal` (needs auth +
      permissioned sharing) — both require backend/product decisions the frontend can't make
      unilaterally, consistent with the original Phase 6 scope note. All 4 built pages
      verified with Playwright (no console errors; Model Validation Suite's checks correctly
      all pass against sane default assumptions).
- [~] Phase 7 — Retrofit remaining live pages (2026-08-08, in progress). Bug fix along the
      way: `/security-privacy` was incorrectly added to `LIVE_PATHS` during the Phase 1 nav
      rewrite while `SecurityPrivacyCenterPage.tsx` was still a `SkeletonPage` wrapper — since
      this app is genuinely local-storage-only (no accounts/sessions), built a real page
      instead of reverting: enumerates actual `firecasting:*` localStorage keys with sizes,
      exports them as JSON, and clears them, rather than reverting to hidden-skeleton.
      **Real regression caught and fixed globally**: Tailwind's Preflight reset strips
      `list-style`/margin from bare `<ul>`/`<ol>` — confirmed via screenshot that InfoPage's
      Glossary list silently lost its bullets. Rather than patching every untouched page,
      added one scoped rule in `index.css` (`ul:not([class]), ol:not([class])`) that restores
      browser defaults only for unclassed lists, fixing this risk app-wide in one place.
      Batch 1 complete (9 pages retrofitted, ~4700 lines, all verified build+test+lint+
      Playwright): `TutorialLandingPage`, `FeedbackPage`, `FireSimulatorPage`,
      `DecisionJournalPage`, `NoSpendChallengeArenaPage`, `SimulationSetupPages.tsx` (4
      components), `TutorialPage` (surgical edit — left ~600 lines of tutorial step data
      untouched), `SalaryAfterTaxPage`, `InfoPage`. Remaining: `SimulationPage.tsx` (896),
      `AdvancedInputForm.tsx` (1307), `ExplorePage.tsx` (1699), `AssumptionsHubPage.tsx`
      (1744), `RunDiffPage.tsx` (2670), `NormalInputForm.tsx` (4337),
      `MoneyPerspectivePage.tsx` (5415) — ~18k lines total, the app's most complex and most
      heavily-tested code (`NormalInputForm` alone has ~15 dedicated test files). Full
      rewrites of these carry real regression risk; flagged to maintainer before proceeding
      rather than churning through them under a general "continue" instruction.
      **Maintainer decision (2026-08-08): stop here.** These 7 files stay on the legacy
      inline-style system indefinitely — they already render correctly and consistently
      (same `--fc-*` CSS variables, dark/light theming intact), just without Tailwind utility
      classes. A styling-only pass isn't worth the regression risk on business-critical,
      heavily-tested code. Phase 7 is considered done: all pages that were reasonable to
      retrofit have been: the Phase 0 shared chrome, the Phase 2 strategy pages, and this
      batch of 9. If any of the 7 remaining files get touched for unrelated feature work in
      the future, migrating that specific file's styling opportunistically in the same PR is
      reasonable — but no dedicated pass is planned.
