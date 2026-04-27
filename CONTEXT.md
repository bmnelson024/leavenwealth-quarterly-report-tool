# LeavenWealth Quarterly Report Builder — Session Context

## File
`/sessions/nifty-youthful-edison/mnt/Quarterly Report Builder/index.html`
Single-file vanilla HTML/JS app, ~2,050 lines. No build process. Uses XLSX.js from cdnjs CDN.

---

## Architecture

- **State object** (`state`) holds all runtime data: source, propertyName, currentQuarter, files, metrics, narratives, charts, prevMetrics, assetFacts, econOcc, plus investment-mode fields (invProperties, invCharts, invNarratives, invMetrics, invLoan, invPrevMetrics).
- **`render()`** is the single re-render function. It writes to `document.getElementById("step-content").innerHTML`. Branches on `state.source` ('buildium' | 'appfolio' | 'investment' | null) and `state.step` (0, 1, 2).
- **localStorage** saves/resumes reports. Key format: `lw_save_{property}_{quarter}`. Index key: `lw_saves_index`.
- **Steps**: 0 = upload files, 1 = review metrics, 2 = narratives + generate / iframe preview.

### Key functions
| Function | Purpose |
|---|---|
| `parseExcel(buffer)` | Buildium income statement parser. Returns `{totalIncome, totalExpense, noi, capex, capexItems, incomeRows, monthCols}` |
| `parseQuarterFromExcel(buffer, quarter)` | AppFolio 12-month parser — sums only the 3 current-quarter month columns. Same return shape. |
| `parsePriorQuarterFromExcel(buffer, quarter)` | Extracts prior quarter totals from the same 12-month Excel. Returns `{income, expenses, noi, capex, prevLabel, expenseCategories}` |
| `extractExpenseCats(incomeRows)` | Returns `[{name, amount}]` of individual expense LINE ITEMS (not subtotals) in the expense section. Used for dynamic narrative. |
| `processDataAppFolio()` | Runs after file upload on AppFolio step 0. Parses all files, builds `state.metrics`, calls `genNarratives`. |
| `processBuildium()` | Same for Buildium. |
| `genNarratives(m)` | Generates narrative strings for income, expenses, capex, outlook. Expenses narrative is dynamic — identifies top Q/Q movers by individual line item. |
| `buildReport(...)` | Builds full ~11-page individual property HTML report. |
| `buildInvestmentReport(...)` | Builds full 14-page multi-property investment HTML report. |
| `onPropertyNameChange(val)` | Handles property name input. Auto-loads saved photo/assetFacts/prevOccupancy. Uses `renderKeepFocus()` internally to preserve caret position after re-renders. |
| `tryAutoLoadPriorOccupancy()` | Looks up localStorage for prior quarter saved report; loads prevMetrics from it. |

### LOGO constants (lines ~110-111)
`LOGO_FULL` and `LOGO_SYMBOL` are base64 PNG data URLs embedded directly in the JS. `LOGO_SYMBOL` is the standalone icon (used in report footers and the app header). `LOGO_FULL` is the full lockup (used on report cover pages).

---

## AppFolio Excel Format (critical)

The 12-month income statement has:
- Rows 1–12: metadata (property name, date range, etc.)
- Row 13: header row — "Account Name", "Apr 2025", "May 2025", ..., "Mar 2026", "Total"
- **The "Total" column is the full 12-month annual sum — NOT the current quarter.** Always use `parseQuarterFromExcel` which sums only the 3 current-quarter month columns.

**Indentation structure (leading spaces in column A):**
| Spaces | Type | Example |
|---|---|---|
| 0 | Top-level section header | `Operating Income & Expense` |
| 4 | Sub-section header | `Income`, `Expense` |
| 8 | Category header (ALL CAPS) OR standalone line item | `RENTS`, `OTHER INCOME`, `Prepaid Rent` |
| 12 | Sub-category header OR line item | `MARKETING`, `Rent Income` |
| 16 | Deep line item | `Advertising`, `Meals - 100%` |

**isSectionHeader logic** in `parseQuarterFromExcel`:
Two-pass approach:
1. First pass collects all labels that have a matching `"Total X"` row → `sectionGroupNames` Set.
2. A row is a section header if: `allZero && !isTotal && (indentCount <= 4 || sectionGroupNames.has(label))`.
This correctly excludes zero-amount standalone line items like `Prepaid Rent` (no "Total Prepaid Rent" exists).

---

## Income Statement Rendering (`makeRow`)

CSS classes for income statement (`.ist` table):
| Class | Appearance | Used for |
|---|---|---|
| `sec-hd` | Green tint bg, uppercase teal text | Top-level section header (`indentCount === 0`) |
| `sec-hd-inner` | Plain bold, no background | Nested section/category headers (`indentCount > 0`) |
| `tot` | Teal-light bg, double border | Grand totals (Total Income, Total Expense, NOI, Net Income) |
| `sub-tot` | Light green tint, bold, top border | Intermediate category totals (Total RENTS, Total MARKETING, etc.) |
| `sub` | 22px left indent | Indented line items |

**Grand totals set** (determines `tot` vs `sub-tot`):
`"total operating income"`, `"total income"`, `"total operating expense"`, `"noi - net operating income"`, `"net operating income"`, `"net income"`, `"total capital expenses"`, `"total for capital improvements"`

**Page split**: Income section (up to and including "Total Income" OR "Total Operating Income") goes on page 8; expenses + NOI on page 9.

---

## Expense Narrative (dynamic)

`extractExpenseCats(incomeRows)` collects individual non-total, non-header expense line items between `Total Income` and `Total Operating Expense`. `parsePriorQuarterFromExcel` returns `expenseCategories` using the same logic for prior quarter.

`genNarratives` compares current vs prior by name, sorts by absolute delta (descending), names top 3 movers:
> *"The primary drivers were Electric (down $4,100) and Landscaping (down $2,900)."*

Falls back gracefully: if only current data → lists top 2 by spend. If no category data → generic text.

---

## Rent Roll (AppFolio)

**Displayed columns only**: Unit, Bed/Bath, Lease From, Lease To, Mkt Rent, Rent.
Configured in `RR_COLS_AF` array in `processDataAppFolio`. Tags, Tenant, Status, Past Due removed.

**Rendering**: `table-layout:fixed` with `<colgroup>` widths — Unit/Bed/Bath at 11% each, remaining 4 columns at 19.5% each. Property name `<div class="pn">` removed from rent roll page (property is already in footer).

---

## UI / App Shell Changes

- **Header**: `<h1>` uses `<img id="lw-header-logo">` (no emoji). Src set via `document.getElementById('lw-header-logo').src = LOGO_SYMBOL` at page init.
- **Source selection tiles**: Buildium and AppFolio cards no longer show file-requirement description text (`.home-meta` removed). Investment Report card description kept.
- **Tab order fix**: `onPropertyNameChange` uses `renderKeepFocus()` which snapshots `document.activeElement.getAttribute('data-field')` before any `render()` call and restores focus + caret position after. Property Name input has `data-field="propertyName"`, Current Quarter has `data-field="currentQuarter"`.

---

## Investment Report Mode

- Triggered by `state.source = 'investment'`
- State: `state.investmentName`, `state.invProperties[]` (each with id, name, source, files, econOcc, metrics), `state.invCharts` (12 slots), `state.invNarratives`, `state.invMetrics`, `state.invLoan`
- `processInvestmentData()` calls `parsePropertyMetrics(prop)` per property, aggregates to portfolio totals
- `buildInvestmentReport()` generates 14-page HTML matching the MWP 4 Combined Q4 2025 Report structure

---

## Known Patterns / Gotchas

- `render()` replaces `el.innerHTML` entirely — any direct DOM manipulation is wiped on next render. Always update `state` and re-render.
- AppFolio uses `parseQuarterFromExcel`; Buildium uses `parseExcel`. Both return `incomeRows` in the same shape for the report renderer.
- `state.prevMetrics` shape: `{occupancy, income, expenses, noi, capex, expenseCategories[]}`. The `expenseCategories` field is populated for AppFolio (from `parsePriorQuarterFromExcel`) but NOT currently for Buildium (Buildium prior metrics come from localStorage saved reports which don't store expenseCategories).
- Prior quarter occupancy for AppFolio comes from `state.prevOccupancyInput` (manually entered or auto-loaded from saved report) since only the current quarter rent roll is uploaded.
- `QUARTER` and `PROPERTY` are default fallback constants defined in the CONFIG section.
