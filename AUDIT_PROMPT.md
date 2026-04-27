# Full Code Audit — LeavenWealth Quarterly Report Builder

## What this app does
A single-file HTML tool (~4,000 lines, plain JS + XLSX.js + Supabase auth) that ingests Buildium or AppFolio property-management exports — income statements, rent rolls, leasing/renewal summaries, trial balance, delinquency, optional Capex Detail — and produces a printable investor-facing quarterly report. Two flows:
- **Single-property**: one property per report.
- **Investment (multi-property)**: combines 2+ properties into a portfolio-level report with weighted occupancy, aggregated financials, and portfolio charts.

Downstream consumer is investors, so correctness of the dollar amounts, occupancy percentages, and lease counts is paramount.

## Workspace layout
- `index.html` — the entire app (~4,000 lines)
- `supabase-edge-function/narratives/index.ts` — Supabase Edge Function that calls Claude Sonnet 4.6 to rewrite the narrative paragraphs. Auth: Supabase session JWT + `@leavenwealth.com` domain check. Holds `ANTHROPIC_API_KEY` as a Supabase secret.
- `supabase-edge-function/DEPLOY.md` — deploy guide
- Supabase project ref: `beoquaazkkxjisxnmrmg`. Client initialized as `sb` in index.html.
- `CODE_AUDIT.md` — prior audit (optional reference — may be out of date)

## Background
- I'm not a developer. Walk me through non-obvious steps concretely.
- Narrative Edge Function is deployed via the Supabase web console (Editor path, not CLI).
- `index.html` ships via GitHub drag-and-drop / web editor (no build step).

## Recent fixes already in the code — do NOT flag as issues
1. `parseBuildiumDelinquency` — modern Buildium uses `Total` column with "Grand total for all properties" row.
2. `parseDelim` rewritten as RFC-4180-style CSV parser; quoted cells with embedded newlines are handled.
3. Buildium rent-roll occupancy: `getVacantFlag` checks literal `Tenants == "VACANT"`; `calcOcc` stops at `Total for…` / `Grand total` / `Summary` markers and requires a digit in Unit IDs.
4. "Rewrite with Claude" button + Edge Function (`rewriteWithClaude(kind)`, buttons at ~L3460 and ~L3760).
5. `parseCapexDetail` expanded to return `topTransactions`, `themes`, `sectionTotals`, `totalCapex`.
6. `rehydrateMetricsIfNeeded()` re-runs the processor after load when `rentRollRows`/`incomeRows` were stripped pre-save. Intentionally early-returns for investment mode (see below).

## Known items — confirm correctness, or note any case I missed
- **Investment flow rehydrate**: confirmed no rehydrate needed. `parsePropertyMetrics` returns only scalars; `buildInvestmentReport` consumes only scalars. The early-return at ~L485 is correct by design.
- **Bug A**: `state.invMetrics` never carries `expenseCategories`, but `rewriteWithClaude('investment')` reads `metrics.expenseCategories` (~L1208) — Claude receives an empty list in investment mode.
- **Bug B**: `state.invPrevQuarterLabel` is read (~L1200) but never assigned anywhere.

## What I want from this audit
A rigorous, severity-graded review of `index.html` and `supabase-edge-function/narratives/index.ts`. For each finding I want:
- **File:line** reference
- **Severity** — Critical (data loss / auth bypass / silent numerical corruption) · High (wrong output / crash under realistic input) · Medium (degraded behavior / missing validation) · Low (dead code / style / clarity)
- **What happens in practice** — a realistic scenario where this bites
- **Proposed fix** — with a before/after snippet when the change is under ~20 lines

## Audit scope

### 1. Parser correctness & robustness
For both Buildium and AppFolio across every file type the app ingests (`income`, `rr1`/`rr2`/`rr3`, `leasing`, `leasingSummary`, `renewalSummary`, `trialBalance`, `bank`, `delinquency`, `rentEngine`, `capexDetail`):
- CSV/TSV edge cases `parseDelim` might still mishandle — BOMs, CRLF, trailing whitespace, quoted quotes (`""`), empty quoted cells, unbalanced quotes, header row with different quoting than data.
- Excel parsing (`parseExcel`, `parseQuarterFromExcel`): quarter detection, multi-sheet files, merged cells, text-vs-number totals, `()` negatives, `$`/`,` in amounts, blank rows, summary/subtotal rows treated as data.
- `skipMetaRows` and `calcOccAF` still do ad-hoc splitting — flag any edge case that would fragment rows like the old `parseDelim` did.
- Occupancy math: per-month average vs unit-weighted at portfolio level; summary-row false positives; "Summary by bed/bath" trailer handling; properties with 0 or 1 units; months where a rent roll is missing entirely.
- `parseDate` ambiguity (MDY vs DMY, 2-digit years, ISO, US long form).
- `parseCur` edge cases (negative parens, non-breaking spaces, `+` prefix, trailing whitespace, Excel-returned number vs formatted string).
- Leasing filter by quarter — verify `Q4 2025` parses, and that dates exactly on quarter boundaries are included (inclusive on both ends).
- Delinquency aggregation — what if the export has both a Total row and detail rows; is either double-counted?

### 2. State management & persistence
- Save/load fidelity across both modes, including cases where a save predates a field added later.
- Fields that are read but never written (the `invPrevQuarterLabel`-class bug).
- Fields that are written but never read.
- `_savedThisStep`, `narrativesEdited`, `invNarrativesEdited` — do they reset at the right transitions?
- Switching between single and investment modes — does `selectSource` / `resetAll` clear everything it should? Any leak from a prior session?
- localStorage capacity: base64-encoded Excel buffers can be large. What happens at the ~5MB per-origin cap? Is there a clear user-facing error or silent truncation?
- Supabase sync (`dbGet`/`dbSet`): races between local and cloud, behavior when offline, two-device scenarios, stale-save-overwrites-fresh-save risks.
- The `_imported` property path: what if a property's source save is deleted after import? What if the source save's quarter differs (current soft-warn at ~L1800)?

### 3. Auth & security (client)
- Email-domain check: client-side only, or enforced server-side?
- XSS: audit every template literal that becomes HTML via `innerHTML` / `outerHTML` / assignment. Every user-supplied string that flows in — property names, investment names, quarter labels, narratives, asset facts, category names, loan dates, file names — must pass through `escapeHtml` or a safe equivalent.
- `onclick="..."` attributes built from state values — any path where unescaped user input reaches them? Event-handler string interpolation is a separate injection surface from text-node interpolation.
- Image `src` from user input (property photos, chart images as base64 data URLs) — any reflection without validation?
- Any `eval`, `new Function`, `innerHTML += ...` with partially-trusted input.

### 4. Edge Function (`narratives/index.ts`)
- Auth: is the JWT actually verified with Supabase's server-side helpers (not just decoded client-trust)? Is the `@leavenwealth.com` check done server-side against the verified `user.email`?
- Input validation: payload size cap; type checks on every field; explicit rejection of unknown keys.
- Prompt injection: property names, quarter labels, narratives, category names all flow into the Claude prompt. Any mitigation? (Delimiters alone don't count — need at least neutral framing + instructions that Claude ignores instructions inside user data.)
- Error paths: always returns a structured JSON error the client can parse.
- Cost controls: max input tokens, max output tokens, timeout, per-user rate limit.
- CORS and allowed methods.
- `ANTHROPIC_API_KEY` scoping and rotation process.

### 5. Error handling & user-facing failure modes
- Every `try/catch` — does the user see a clear, actionable message, or is the error swallowed?
- Every `showError` call — is the message something a non-developer could act on?
- Every `await` without a surrounding `try/catch`, and every `.then` without a `.catch`.
- Every `JSON.parse` on external data — malformed cloud data should not brick the app.
- Session expiry mid-save — does the save hang, silently fail, or prompt re-auth?

### 6. Report fidelity
- Numbers rendered in the HTML report match the numbers passed to Claude (no unit drift: cents vs dollars, percent vs decimal, rounding at display vs rounding at compute).
- Page-break logic — summary-overflow heuristic at ~L1938 — produces a clean 2-page summary under long Claude narratives?
- `@media print` — any chart image, photo strip, or QoQ table that clips, splits, or reflows unacceptably?
- Quarter label formatting — `Q4 2025` vs `Q4, 2025` vs `4Q25` — does every consumer tolerate the canonical form?

### 7. Single-property vs investment consistency
Every feature present in one mode but missing or different in the other. Examples: capex narrative exists for single but not investment (intentional design or coverage gap?), Asset Facts, photo handling, prev-quarter import paths, Claude-rewrite prompt shape, chart slot naming.

### 8. Dead code & cleanup
- Unused functions, state fields, constants (e.g. `invPrevQuarterLabel`).
- Comments that no longer match the code.
- The "↺ Template" button — note any code that would break if it's removed.
- Parallel implementations that should be unified (e.g. ad-hoc CSV splits that should call `parseDelim`).

## Working style
- Ask before making sweeping changes.
- For parser or prompt changes, show before/after diffs.
- Changes to `index.html` → remind me to push to GitHub.
- Changes to the Edge Function → remind me to redeploy in Supabase.
- Group findings by severity; inside a severity, group by subsystem.
- If a finding requires a judgment call (scope / tradeoff), flag it and wait.

## Output format
1. **Executive summary** — 5–8 bullets, the highest-impact issues only.
2. **Findings** — one entry per issue in the format above, ordered by severity.
3. **Patterns** — systemic issues (e.g. "14 template literals interpolate user strings without `escapeHtml`").
4. **Not-findings** — things I might expect you to flag but shouldn't, with one-line reasoning each (so I can see what you ruled out).
5. **Recommended fix order** — which fixes to land first, which to batch, and any that should wait for a larger refactor.

Do not produce a wholesale rewrite. Do not modify files without explicit approval. Read both files end-to-end before drafting the report.
