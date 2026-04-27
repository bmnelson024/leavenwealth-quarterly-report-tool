# New Session Starter — LeavenWealth Quarterly Report Builder

Paste this entire file as your first message in a new session.

---

## The App

Single-file vanilla HTML/JS app at:
**`/sessions/nifty-youthful-edison/mnt/Quarterly Report Builder/index.html`**
~2,050 lines. No build process. Uses XLSX.js (cdnjs CDN) and localStorage. Do NOT rewrite it — make targeted edits only.

A full technical reference is saved at:
`/sessions/nifty-youthful-edison/mnt/Quarterly Report Builder/CONTEXT.md`
Read that before making any changes to understand architecture, key functions, and current state.

---

## What It Does

A 3-step wizard for building quarterly investor reports for real estate properties:
- **Step 0**: Upload files + enter property name / quarter
- **Step 1**: Review parsed metrics
- **Step 2**: Edit narratives → generate PDF-ready HTML report in an iframe

Supports three modes: **Buildium** (individual property), **AppFolio** (individual property), **Investment Report** (multi-property, any mix of Buildium + AppFolio).

---

## Key Architecture

- `render()` → writes to `document.getElementById("step-content").innerHTML`. Wipes the DOM on every call — always update `state` then re-render.
- `state` object holds everything: source, propertyName, currentQuarter, files, metrics, narratives, prevMetrics, charts, assetFacts, econOcc, invProperties[], invCharts, invNarratives, invMetrics, invLoan.
- `parseQuarterFromExcel(buffer, quarter)` — AppFolio only. Sums the 3 current-quarter month columns. **Never use the "Total" column** — it's the full 12-month annual sum.
- `parsePriorQuarterFromExcel(buffer, quarter)` — extracts prior quarter from same 12-month Excel. Returns `{income, expenses, noi, capex, prevLabel, expenseCategories[]}`.
- `extractExpenseCats(incomeRows)` — individual expense line items (not subtotals) between Total Income and Total Expense. Used for dynamic narrative.
- `onPropertyNameChange(val)` — uses `renderKeepFocus()` internally to preserve focus/caret when render() fires during typing.

---

## AppFolio Excel Indentation (critical)

| Leading spaces | Row type |
|---|---|
| 0 | Top-level header (`Operating Income & Expense`) |
| 4 | Sub-header (`Income`, `Expense`) |
| 8 | Category header ALL CAPS (`RENTS`) OR standalone line item (`Prepaid Rent`) |
| 12 | Sub-category header ALL CAPS (`MARKETING`) OR line item (`Rent Income`) |
| 16 | Deep line item (`Advertising`) |

Section headers detected via two-pass: a zero-amount row is a header only if `indentCount <= 4` OR it has a matching `"Total X"` row elsewhere. This correctly excludes zero-amount line items like `Prepaid Rent`.

---

## Income Statement Table CSS Classes

| Class | Style | Used for |
|---|---|---|
| `sec-hd` | Green tint, uppercase teal | `indentCount === 0` section headers only |
| `sec-hd-inner` | Plain bold, left-aligned, no bg | Nested headers (`indentCount > 0`) |
| `tot` | Teal-light bg, double border | Grand totals (Total Income, Total Expense, NOI, etc.) |
| `sub-tot` | Light green tint, bold | Intermediate category totals (Total RENTS, etc.) |
| `sub` | 22px left indent | Indented line items |

All sec-hd/sec-hd-inner cells have explicit `text-align:left` to override the `td:last-child { text-align:right }` rule.

---

## Rent Roll (AppFolio)

6 columns only: Unit, Bed/Bath, Lease From, Lease To, Mkt Rent, Rent.
`table-layout:fixed` with `<colgroup>` widths (11% / 11% / 19.5% / 19.5% / 19.5% / 19.5%).
Property name `<div class="pn">` removed from rent roll page.

---

## UI Details

- App header: `<img id="lw-header-logo">` with src set to `LOGO_SYMBOL` at init. No emoji.
- Source selection tiles: Buildium and AppFolio cards have no file-requirement description text.
- Tab order: `data-field="propertyName"` and `data-field="currentQuarter"` on those inputs; `renderKeepFocus()` restores focus after auto-load re-renders.

---

## What's Working

- Buildium individual reports ✅
- AppFolio individual reports ✅ (income from 12-month Excel, prior quarter occupancy auto-loaded or manually entered)
- Investment Report (multi-property, 14-page) ✅
- Dynamic expense narrative (names top 3 individual line item movers Q/Q) ✅
- Income statement visual hierarchy (section headers, sub-headers, category totals, grand totals) ✅
- Rent roll trimmed to 6 columns, uniform widths ✅

---

## Continuing Work

When the user describes a new issue or feature, read CONTEXT.md first if you need deeper detail on any function. Make edits directly to `index.html` using the Edit tool. Always read the relevant section of the file before editing.
