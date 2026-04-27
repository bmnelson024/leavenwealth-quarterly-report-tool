I'm building a single-file client-side HTML/JS quarterly report builder for a property management company. The entire app lives in one file: `index.html` (currently ~3,300 lines). Please read the file before making any changes.

**What it does:** Produces polished PDF reports for rental properties. Supports three modes:

* **AppFolio** (single-property)
* **Buildium** (single-property)
* **Multi-Property / Investment** — combines multiple saved single-property reports into a portfolio report

Users upload financial files (income statements, rent rolls, bank statements, etc.), the app parses them and extracts metrics, then generates a formatted report with charts, narratives, and financial tables.

**Tech stack:**

* Pure client-side HTML/JS — no backend, no build step
* IndexedDB (with synchronous in-memory `_dbCache` layer) for all persistence
* Charts stored separately in IDB under `lw_charts_[key]` (single) and `lw_invcharts_[key]` (investment)
* Uploaded files stored separately in IDB under `lw_files_[key]` (single) and `lw_invfiles_[key]` (investment) — files serialized as `{t:'buf', d:base64}` for ArrayBuffers and `{t:'str', d:string}` for text
* Report data saved under `lw_save_[key]`; photos under `lw_photo_[name]`

**Key functions to know:**

* `processBuildium()` / `processDataAppFolio()` — parse uploaded files and compute metrics for single-property mode
* `parsePropertyMetrics(prop)` — same for investment mode per-property
* `processInvestmentData()` — aggregates per-property metrics into portfolio totals
* `buildInvestmentReport(m, n, ...)` — generates HTML for multi-property PDF
* `buildReport(m, n, ...)` — generates HTML for single-property PDF
* `importPropertyFromSave(propId, saveKey)` — imports a saved single-property report into investment mode
* `saveProgress()` / `loadSave(key)` — IDB persistence
* `saveChartsForKey` / `loadChartsForKey` — single-property chart persistence
* `saveInvChartsForKey` / `loadInvChartsForKey` — investment chart persistence
* `saveFilesForKey` / `loadFilesForKey` — single-property file persistence
* `saveInvFilesForKey` / `loadInvFilesForKey` / `applyInvFiles` — investment file persistence
* `_serializeFiles` / `_deserializeFiles` / `_bufToB64` / `_b64ToBuf` — ArrayBuffer ↔ base64 for IDB storage
* `dbSet(k, v)` — writes to `_dbCache` synchronously and IDB asynchronously
* `currentSaveKey()` — computes IDB key from property name + quarter
* `parseQuarterFromExcel(buffer, quarter)` — reads 12-month income statement, sums only the 3 current-quarter months
* `parsePriorQuarterFromExcel(buffer, quarter)` — extracts prior quarter figures from same file
* `showSavePrompt(onContinue)` — modal that fires when navigating forward without saving
* `confirmAndAdvance(nextStep)` / `confirmAndGenerate()` / `confirmAndGenerateInv()` — forward navigation wrappers that check `state._savedThisStep`

**Report structure — Single-property (AppFolio & Buildium):**
* Page 1: Cover
* Page 2: Summary — QoQ table + Income & Occupancy, Expenses, Capital Expenditures, Outlook narratives *(auto-splits to page 2b "Summary continued" if total narrative chars > 1,000 or Outlook alone > 500)*
* Page 3: Asset Overview (asset facts + cover photo) + Snapshot tiles + monthly occupancy
* Page 4: Financial Charts
* Page 5: Leasing stats + charts
* Page 6+: Rent Roll, Income Statement (paginated), Footnotes

**Report structure — Investment/Multi-Property:**
* Page 1: Cover
* Page 2: Summary — QoQ table + narratives *(auto-splits to page 2b if total narrative chars > 1,200 or Outlook alone > 500)*
* Page 3: Portfolio Snapshot
* Pages 4–5: Financial Charts
* Page 6: Leasing stats + charts
* Last page: Footnotes

**Snapshot tile order (both report types):**
* Row 1 (dark/highlighted): Total Income · Total Expenses · Net Operating Income
* Row 2: Avg Physical Occupancy · Avg Economic Occupancy · Cash on Hand *(single-property)* or Total Units *(investment)*

**Investment chart upload grid order** (2-column, paired so consolidated is left, per-property is right on same row):
* Operating Income vs. Pro Forma | Operating Income By Property
* Operating Expense vs. Pro Forma | Operating Expense By Property
* NOI vs. Pro Forma | NOI By Property
* Occupancy Rate | Occupancy Rate By Property
* Operating Income vs. Expense | Utility Income vs. Expenses
* Lease Expirations by Month | Rent Growth & Market Rent

**Investment report page layout:**
* Page 3 Leasing page tiles: Loss to Lease · New Leases · Lease Renewals · Prospect Inquiries · Prospect Applications · Total Delinquency
* Economic Occupancy (weighted) appears on Page 3 Snapshot tiles, NOT on the Leasing page

**Already-fixed bugs (do not re-fix):**
1. Buildium rent roll parsing — property name rows filtered with `/\d/.test(u)`
2. `getVacantFlag` — Tenants column check for Buildium vacancy detection
3. Leasing date columns — `Date activated` / `Start date` aliases
4. Renewal detection — "Lease type" column check with regex
5. Bank row selection — `.find()` with `Balance`/`Pending` column aliases
6. Total Units in investment report — fallback computation + `importPropertyFromSave` patches
7. Home screen badge — "Multi-Property" badge fix for investment saves
8. Investment chart legends — `height:auto` on chart images
9. Chart persistence — `loadAllInvCharts` calls `saveInvChartsForKey` after bulk upload
10. `parseDelim` null guard — returns `[]` immediately if input is not a string (fixes "text.replace is not a function" crash)

**Features built this session:**
* **Full file persistence** — all uploaded files (income statements, rent rolls, etc.) now save/restore via IDB alongside charts and metrics. ArrayBuffers serialized to base64 in 8KB chunks.
* **"Save before continuing?" modal** — fires when navigating forward (step 1→2, step 2→generate) if `state._savedThisStep` is false. "Save & Continue" calls `saveProgress()` then advances. Flag resets to false each time data is processed.
* **Narrative overflow protection** — both single-property and investment reports detect long narratives at generation time (char count threshold) and split Outlook onto a proper "Summary (continued)" page with header, footer, and correct page number. Prevents browser from slicing mid-paragraph when printing to PDF.
* **Snapshot tile reorder** — financial equation order on top row (Income → Expenses → NOI); occupancy metrics on bottom row.
* **Economic Occupancy on Page 3** — swapped onto Snapshot page (next to Physical Occupancy) for both single-property and investment reports. Total Delinquency moved to Leasing page in investment report.
* **Investment chart upload reorder** — paired so each consolidated chart sits directly beside its per-property counterpart.
* **AppFolio-only fork** — a separate `appfolio_tool.html` was created with Buildium stripped out and a `BRAND_*` constants system added for white-labeling.

**Architectural notes:**
* `parseDelim(text)` — guards against null/undefined; returns `[]` if text is not a string
* `rentRollRows` and `incomeRows` stripped from saves (large arrays, regenerate from saved files on re-process)
* Page numbering uses auto-incrementing `pg` object — `pg.v()` on every page footer, never hardcoded
* The `pg` counter handles conditional pages (page 2b) correctly — downstream numbers stay right regardless
* File types: income statement = ArrayBuffer (Excel); rent rolls / leasing / delinquency = text strings (CSV or XLSX-converted-to-CSV)
* `state._savedThisStep` — boolean, reset to `false` on `state.step=1`, set to `true` in `saveProgress()`
* Photos stored globally by property name (`lw_photo_[name]`), persist across quarters for same property
* IDB initialized with `navigator.storage.persist()` and `onerror` handler on `dbSet`

**Pending / known items for future work:**
* Monthly occupancy breakdown by month for both Physical and Economic Occupancy on the investment report Page 3 (deferred — needs pipeline changes in `parsePropertyMetrics` and `processInvestmentData` to expose `occ1/2/3` and monthly econ occ at portfolio level)

My next task is:
