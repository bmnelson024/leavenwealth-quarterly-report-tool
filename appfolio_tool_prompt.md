I'm building a single-file client-side HTML/JS quarterly report builder for a property management company. The entire app lives in one file: `appfolio_tool.html` (currently ~3,050 lines). Please read the file before making any changes.

**What it does:** Produces polished PDF reports for rental properties. Supports two modes:

* **AppFolio** (single-property) — parses AppFolio exports and generates a formatted single-property investor report
* **Multi-Property / Investment** — combines multiple saved single-property AppFolio reports into a portfolio report

Users upload financial files (income statements, rent rolls, leasing summaries, trial balances, etc.), the app parses them and extracts metrics, then generates a formatted report with charts, narratives, and financial tables.

**Tech stack:**

* Pure client-side HTML/JS — no backend, no build step
* IndexedDB (with synchronous in-memory `_dbCache` layer) for all persistence
* Charts stored separately in IDB under `lw_charts_[key]` (single) and `lw_invcharts_[key]` (investment)
* Uploaded files stored separately in IDB under `lw_files_[key]` (single) and `lw_invfiles_[key]` (investment) — files are serialized (ArrayBuffer → base64, strings as-is)
* Report data saved under `lw_save_[key]`

**Branding system:** At the top of the `<script>` block there is a `BRAND_*` constants section:
```javascript
const BRAND_NAME = "Company Name";
const BRAND_PRIMARY = "#1a3a35";
const BRAND_ACCENT  = "#00c48c";
const BRAND_LIGHT   = "#e6f9f4";
const BRAND_BORDER  = "#c8e6de";
const BRAND_MUTED   = "#5a8070";
// LOGO_FULL and LOGO_SYMBOL are base64 placeholder logos below these constants
```
To rebrand for a new company, swap the `BRAND_*` values and replace the `LOGO_FULL` / `LOGO_SYMBOL` base64 strings.

**Key functions to know:**

* `processDataAppFolio()` — parses uploaded AppFolio files and computes metrics for single-property mode
* `parsePropertyMetrics(prop)` — same for investment mode per-property (AppFolio only)
* `processInvestmentData()` — aggregates per-property metrics into portfolio totals
* `buildInvestmentReport(m, n, ...)` — generates HTML for multi-property PDF
* `buildReport(m, n, ...)` — generates HTML for single-property PDF
* `importPropertyFromSave(propId, saveKey)` — imports a saved single-property report into investment mode
* `saveProgress()` / `loadSave(key)` — IDB persistence
* `saveChartsForKey` / `loadChartsForKey` — single-property chart persistence
* `saveInvChartsForKey` / `loadInvChartsForKey` — investment chart persistence
* `saveFilesForKey` / `loadFilesForKey` — single-property file persistence
* `saveInvFilesForKey` / `loadInvFilesForKey` / `applyInvFiles` — investment file persistence
* `_serializeFiles` / `_deserializeFiles` — converts ArrayBuffers ↔ base64 for IDB storage
* `dbSet(k, v)` — writes to `_dbCache` synchronously and IDB asynchronously
* `currentSaveKey()` — computes IDB key from property name + quarter
* `parseQuarterFromExcel(buffer, quarter)` — reads 12-month AppFolio income statement, sums only the 3 current-quarter months
* `parsePriorQuarterFromExcel(buffer, quarter)` — extracts prior quarter figures from same file

**This tool is AppFolio-only** — Buildium support was intentionally removed. Specifically:
* `processBuildium()` does not exist
* `calcOcc()` (Buildium rent roll occupancy) does not exist
* `loadAllRentRolls()` does not exist
* Investment mode properties are always AppFolio source — no source selector in the property card UI
* `addInvProperty()` sets `source:'appfolio'` automatically
* `processData()` always calls `processDataAppFolio()` directly

**Report structure — Single-property:**
* Page 1: Cover (property name, quarter, photo)
* Page 2: Summary — QoQ table + Income & Occupancy, Expenses, Capital Expenditures, Outlook narratives *(auto-splits to page 2b if narratives are long)*
* Page 3: Asset Overview (asset facts) + Snapshot tiles + monthly occupancy
* Page 4: Financial Charts (4-up)
* Page 5: Leasing stats + charts
* Page 6+: Rent Roll, Income Statement (paginated), Footnotes

**Report structure — Investment/Multi-Property:**
* Page 1: Cover
* Page 2: Summary — QoQ table + narratives *(auto-splits to page 2b if Outlook is long)*
* Page 3: Portfolio Snapshot tiles (Income → Expenses → NOI on top row; Physical Occ → Econ Occ → Total Units on bottom)
* Page 4–5: Financial Charts
* Page 6: Leasing stats + charts
* Last page: Footnotes

**Snapshot tile order (both report types):**
* Row 1 (dark/highlighted): Total Income · Total Expenses · Net Operating Income
* Row 2: Avg Physical Occupancy · Avg Economic Occupancy · Cash on Hand *(single-property)* or Total Units *(investment)*

**Features already built:**
* Full IDB persistence — all files, charts, photos, asset facts, metrics, narratives, narratives save/restore across sessions
* "Save before continuing?" modal prompt when navigating forward without saving
* Overflow detection for long narratives — auto-creates a proper "Summary (continued)" page with header, footer, and correct page number rather than letting browser slice mid-paragraph
* Bulk chart upload with filename auto-matching
* Investment chart upload grid ordered so consolidated chart is always left, per-property breakdown is always right on the same row
* Prior quarter comparison loaded from saved report or entered manually
* Property photos stored per property name, persist across quarters
* Economic Occupancy input (monthly m1/m2/m3) with weighted portfolio average in investment mode

**Known architectural notes:**
* `parseDelim(text)` guards against null/undefined input — returns `[]` immediately if text is not a string
* `rentRollRows` and `incomeRows` are intentionally stripped from saves (large arrays) — they regenerate when the user re-processes, which now works seamlessly since source files are persisted
* Page numbering uses an auto-incrementing `pg` object — `pg.v()` on every page footer, never hardcoded numbers
* File type detection: income statement is an ArrayBuffer (Excel), rent rolls / leasing / delinquency etc. are text strings (CSV or Excel-converted-to-CSV)

My next task is:
