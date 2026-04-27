# LeavenWealth Quarterly Report Builder — Project Brief

## What This Is
A single-file client-side HTML/JS tool (`index.html`) that parses AppFolio and Buildium property management CSV/Excel exports and generates formatted multi-page investor PDF reports. No backend. All processing happens in the browser. State is persisted via localStorage.

---

## File Locations
- **Active tool**: `index.html` (in this folder)
- **Pre-redesign backup**: `index_backup_before_redesign.html` (in this folder)
- **Working copy** (used for edits): `/sessions/charming-sharp-davinci/extracted_tool.html`
- After every edit, copy working copy to workspace: `cp /sessions/.../extracted_tool.html "/sessions/.../Quarterly Report Builder/index.html"`

---

## Tech Stack
- XLSX.js (cdnjs) for Excel parsing
- `FileReader` API — `readAsArrayBuffer` for Excel, `readAsText` for CSV/TSV
- `parseDelim(text)` — internal CSV/TSV parser (throws if text is null — always use `||""`)
- `parseExcel(buffer)` — AppFolio single-quarter Excel parser
- `parseQuarterFromExcel(buffer, quarter)` — Buildium/AppFolio 12-month Excel parser, extracts current quarter columns
- `parsePriorQuarterFromExcel(buffer, quarter)` — extracts previous quarter for comparison
- `parseCur(val)` — currency string to number
- `fmt(n)` / `fmtWhole(n)` — currency formatters
- `calcLossToLease(mkt, act)` — shared loss-to-lease helper

---

## State Object (global `state`)
Key fields: `source` (appfolio/buildium/investment), `step` (0/1/2), `files` (all uploaded file data), `metrics`, `prevMetrics`, `narratives`, `reportHTML`, `propertyName`, `currentQuarter`, `prevQuarterLabel`, `econOcc`, `charts`, `assetFacts`, `propertyPhoto`, `invProperties`, `invMetrics`, `invNarratives`, `invReportHTML`.

**Reset**: `resetAll()` clears everything. The "Start New Report" home button calls `resetAll()`. Mode selection buttons also clear cross-mode state.

---

## Report Structure (single-property)
Pages in order:
1. Cover (logo, property name, "Q1 · 2026" format quarter)
2. Summary (comparison table + 4 narrative blocks with dividers)
3. Asset Overview + Snapshot (6 cards + monthly occupancy row with actual month names)
4. Financial Charts (4 charts, 2×2 grid)
5. Leasing (8 uniform tiles 4-across + 4 leasing charts)
6. Capital Improvements table + Capex/Maintenance charts (merged, paginated at 20 items)
7. Income Statement — income section (paginated at 28 rows)
8. Income Statement — expense section through NOI only, truncated after NOI (paginated at 28 rows)
9. Rent Roll (paginated at 28 rows)
10. Footnotes/Disclosures (logo, numbered list)

---

## Income Statement Logic (Critical)

### `parseQuarterFromExcel` — `isSectionHeader` rule:
```javascript
const isSectionHeader = allZero && !isTotal && sectionGroupNames.has(label);
```
- `sectionGroupNames` built in first pass from "Total X" rows (strips "total " prefix)
- `indentCount <= 4` was intentionally removed — was causing zero-amount line items to render as green headers

### `parseExcel` (AppFolio) — same approach:
```javascript
peSectionGroupNames.add(lbl.replace(/^total\s+(for\s+)?/,"").trim());
// ...
const isSectionHeader = total===0 && !isTotal && peSectionGroupNames.has(lc.replace(/^total\s+(for\s+)?/,"").trim());
```

### `filterIncomeRows` in `buildReport`:
- Pass 1: keeps grand totals always, keeps section headers always, keeps non-null amount rows. Drops zero-amount sub-totals (e.g. "Total for Lease Violation" with $0).
- Pass 2: drops section headers with no visible children.
- `GRAND_TOTAL_LABELS` set: `total operating income`, `total income`, `total operating expense`, `total operating expenses`, `total expenses`, `noi - net operating income`, `net operating income`, `net income`

### NOI Truncation:
```javascript
const _noiIdx = _part2Raw.findIndex(r => {
  const l = r.label.toLowerCase().trim();
  return l==="noi - net operating income" || l==="net operating income" || l==="net income";
});
// Shows warning if not found. Nothing after NOI is rendered.
```

---

## Buildium Format Notes
- Income statement: 12-month Excel with MM-YYYY column headers
- Pattern: "Laundry Income" (header, no amount) → "Laundry Income" (indented, has amount) → "Total for Laundry Income"
- `parseColMonth` helper handles both MM-YYYY and "Jan YYYY" formats
- NOI label: "NOI - Net Operating Income"
- Required files: income, rr1, rr2, rr3, leasing, bank, delinquency
- Delinquency: "Delinquent Tenants" report, sum `Balance` column (positive values only)

## AppFolio Format Notes
- Trial Balance: GL Account 1150 → Cash on Hand (regex: `gl==="1150" || /^1150[\s\-:]/.test(gl)`)
- Delinquency: "Delinquency As Of" report, `Amount Receivable` column, find "Total" row
- Required files: income, rr1, rr2, rr3, leasingSummary, renewalSummary, trialBalance, delinquency
- Trial Balance can be Excel (ArrayBuffer) or CSV — auto-detected by file extension

---

## Key Bugs Fixed (all resolved)
1. Cash on Hand $0 — Trial Balance was Excel but read as text → fixed with auto file type detection
2. GL Account 1150 not matching "1150: Operating Account" format → regex fix
3. NOI wrong ($47k instead of $298k) — Buildium's labeled "NOI" row includes capex deductions → always calculate as `totalIncome - totalExpense`
4. Prior quarter data $0 — Buildium uses MM-YYYY month headers, not "Jan YYYY" → added `parseColMonth` helper
5. Zero-value line items showing as green section headers → removed `indentCount <= 4` fallback from `isSectionHeader`
6. Sub-totals with $0 (e.g. "Total for Lease Violation") showing blank → added sub-total zero filtering
7. Content after NOI showing in income statement → added NOI truncation
8. State bleed on "Start New Report" → changed to call `resetAll()`
9. `parseDelim(null)` crashes → all file reads now use `||""` guard
10. AppFolio `parseExcel` missing `sectionGroupNames` check → added first-pass collection same as `parseQuarterFromExcel`

---

## Investment Mode
- Multi-property (mix of AppFolio + Buildium)
- `parsePropertyMetrics(prop)` — parses a single property's files
- `processInvestmentData()` — loops properties, skips failures with warning (does NOT crash whole portfolio on one bad file)
- Null guards added for `rr3`, `delinquency` files in `parsePropertyMetrics`
- Investment report does NOT include per-property income statements (intentional — only aggregated totals)

---

## Error Handling Convention
- Use `showError(msg)` for all user-visible warnings/errors (red box in UI)
- Never use `console.warn` for anything the user needs to know
- All `console.warn` calls have been converted to `showError`

---

## Property Photos
- Saved to localStorage by property name — auto-loads for same property next quarter
- Intentional behavior — user doesn't re-upload every quarter
- Can be replaced by clicking upload button

---

## Known Limitations / Future Considerations
- Investment mode: no per-property income statement pages in report
- Capex table: paginated at 20 items per page (charts always on last capex page)
- Income statement: paginated at 28 rows per page
- The `Q_MONTHS` constant is kept (used by Buildium rent roll bulk-match helper)
