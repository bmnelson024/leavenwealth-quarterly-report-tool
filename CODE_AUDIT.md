# Code Audit — Quarterly Report Builder

**Audited:** April 21, 2026
**File:** `index.html` (3,706 lines, single-file app)
**Context:** Post-Supabase migration review before adding new persistence features

This audit walks through every section of the code looking for bugs, leftovers from the IndexedDB → Supabase migration, redundancies, and safety concerns. Findings are grouped by severity. Nothing here is an emergency — the tool works — but the CRITICAL and HIGH items are worth fixing before layering on `qr_reports` / `qr_photos` / `qr_files`.

For each item I've noted: **what it is → where it lives → what could go wrong → how hard to fix (Small / Medium / Large)**.

---

## CRITICAL (fix before next feature)

### C1. XSS hole in the rent-roll table
**Where:** lines 1377 and 1384-1385

The rent-roll rendering code concatenates Excel header names and cell values directly into HTML without escaping:

```js
// line 1377 — headers from user's Excel file
const ths = rrHdr.map(function(h){ ... return '<th...>'+h+'</th>'; }).join("");

// lines 1384-1385 — cell values
const disp = isCur ? (...) : v;
return '<td...>'+disp+'</td>';
```

Every other place in the codebase uses the `escapeHtml()` helper you already have at line 199. These two spots got missed.

**What could go wrong:** If a rent-roll Excel file contained a cell like `<script>alert(1)</script>` or `<img src=x onerror=...>`, it would execute inside the generated report iframe. Real-world risk is low because all your Excel files come from Buildium/AppFolio exports, but it's a bad pattern and easy to fix.

**Fix (Small):** wrap both `h` and `disp` in `escapeHtml(...)`. 5-minute change.

---

### C2. Backup & Restore exposes ALL reports to every team member
**Where:** lines 323-351 (approx) — the `backupData()` / `restoreData()` functions

These functions dump and wipe the entire `qr_store` table. Because everyone on `@leavenwealth.com` shares the same Supabase cache (no row-level user scoping), this means:

- Anyone who signs in can download a backup file containing **every property's reports, asset facts, photos, and saved progress** — not just their own.
- Anyone can click Restore and **overwrite or wipe everyone's data**.

**What could go wrong:** An accidental click, a phishing sign-in, or someone on the team who shouldn't see all properties walking through this flow — all destroy or exfiltrate the whole team's data.

**Fix options (Medium):**
- **Easiest:** hide Backup/Restore behind a confirmation dialog that explicitly says "This affects ALL LeavenWealth data, not just yours." Show only to a hardcoded admin email list.
- **Better:** when we move to the new `qr_reports` table, add a `created_by` column and scope Restore to rows the user owns.
- **Best:** remove the feature entirely. Supabase already does automated backups; you probably don't need a client-side one.

---

## HIGH (should fix soon)

### H1. Dead code from the IndexedDB migration
**Where:** scattered — line 234, around line 350, and various branches

Leftover from when you used browser IndexedDB:

- `let _idbAvailable = true;` (line 234) — never set to `false` anywhere, kept only so other code doesn't break referencing it.
- `function migrateLegacyData(){}` — empty no-op that used to copy old IDB data into Supabase.
- Branches that check `if(_idbAvailable)` are now always true — safe but confusing.

**What could go wrong:** makes the file harder to read and maintain. Future-you (or future-me) sees these names and wonders what the IDB layer does.

**Fix (Small):** delete the dead flag, delete `migrateLegacyData()`, and remove any `if(_idbAvailable)` checks. ~30-minute cleanup.

---

### H2. Stale error messages still reference "browser storage"
**Where:** lines 514-518

```js
const onPersistErr = err => {
  const msg = (err && err.name === 'QuotaExceededError')
    ? "Storage full — delete some saved reports to free space."
    : "Could not persist save to browser storage: " + ... + ". Your changes are in memory only.";
  showError(msg);
};
```

Neither case is possible anymore. Supabase doesn't throw `QuotaExceededError`, and "browser storage" is no longer where data lives.

**What could go wrong:** if a save fails (network drop, auth expired, RLS rejection) the user sees misleading advice — they'll try to delete saved reports, which won't help.

**Fix (Small):** replace with accurate messages like "Could not save to cloud — check your connection or try signing out and back in."

---

### H3. Silent error swallowing
**Where:** multiple `catch(e){}` blocks — e.g. inside `deleteSave`, `xlsxToText`, the auth IIFE at line 3640

```js
try{ await sb.auth.signOut(); } catch(e) {}
```

Empty catches hide real problems. If signout fails because the network dropped, you'll still do `window.location.reload()` which may leave the Supabase session cookie intact — next page load will silently re-sign-in the same user.

**What could go wrong:** debugging becomes a nightmare. "Sign out" can appear to work but actually leave the user signed in.

**Fix (Small):** replace empty catches with at least `console.warn('signOut failed:', e)`. Ideally show a toast on failure.

---

### H4. Possible double-boot race on login
**Where:** lines 3688-3698 (the `bootstrap()` IIFE) interacting with `authSubmit` at 3605

Scenario: you land on the login screen. `bootstrap()` calls `sb.auth.getSession()`, which takes ~500ms. During that window you type your password and click Sign In. Now both `_bootAfterAuth` calls can run in parallel:

1. `bootstrap()` → `_bootAfterAuth(session.user)`
2. `authSubmit` → `_bootAfterAuth(data.user)`

Both will call `supaBootstrap()`, which starts with `for(const k of Object.keys(_dbCache)) delete _dbCache[k];`. In the worst case you get a half-loaded cache.

**What could go wrong:** rare — only triggers if the user is very fast. But when it does, you see missing saves or weird state until reload.

**Fix (Small):** add a guard flag at the top of `_bootAfterAuth`:
```js
if(_bootStarted) return;
_bootStarted = true;
```

---

### H5. Signup-confirmation flow leaves toggle link mislabeled
**Where:** lines 3615-3619

After a successful signup that requires email confirmation, the code updates `auth-title` and `auth-submit` but NOT the toggle link text (`auth-toggle-text` and `auth-toggle-link`). The user sees "Sign in" at the top of the form but "Already have one? Sign in" at the bottom — which is now redundant/confusing.

**Fix (Small):** update those two elements too, or just call `authToggleMode()` instead of manually setting text.

---

### H6. `_bootAfterAuth` failure is soft-handled but leaves the app broken
**Where:** lines 3647-3652

If `supaBootstrap()` throws, the app still opens with an empty `_dbCache`. The user sees no saved reports, uploads new data, clicks Save — and the save silently fails (since `sb.from().upsert()` will also fail for whatever reason caused the bootstrap to fail).

**What could go wrong:** user thinks their work was saved, but it wasn't.

**Fix (Medium):** when bootstrap fails, don't drop the auth overlay. Instead show a retry button. Alternatively, disable Save/Resume buttons across the app until bootstrap succeeds.

---

## MEDIUM (nice to fix when nearby)

### M1. `confirmAndGenerate` duplicated for single vs investment reports
**Where:** look for `confirmAndGenerate` and `confirmAndGenerateInv`

Almost identical functions. Maintenance burden — if you change one, you have to remember to change the other.

**Fix (Medium):** factor shared logic into one helper that takes a mode parameter.

---

### M2. Brittle quarter parsing in `importedQ`
**Where:** `parseQuarterFromExcel` and `parsePriorQuarterFromExcel`

Multiple regex patterns chained together, and when they all miss, it silently falls back to the current quarter. If Buildium ever changes its export header slightly (e.g. "Q1-2026" instead of "Q1 2026"), you'll see wrong quarter labels with no warning.

**Fix (Medium):** add an explicit "could not detect quarter — please confirm" UI state when all regexes miss.

---

### M3. NaN renders in loan inputs when empty
**Where:** `state.invLoan.principalInception` etc. around line 3568

When the user hasn't filled these in yet, `parseFloat("")` gives NaN, which then shows up as "NaN" in some rendered places.

**Fix (Small):** add `|| 0` or `|| ""` where you use these values.

---

### M4. `onAuthStateChange` only reacts to `SIGNED_OUT`
**Where:** lines 3700-3704

If a teammate signs in from another tab, this tab won't notice. Usually harmless, but if you're relying on cross-tab sync (you currently aren't), it would miss it.

**Fix (Small):** probably leave it alone — the current behavior is fine for single-user workflows. Flag only.

---

### M5. `dbSet` is fire-and-forget — "saved" before it's actually saved
**Where:** lines ~290-308

`dbSet` writes to the in-memory cache immediately and returns, then kicks off the Supabase upsert asynchronously. If the upsert fails, `onPersistErr` shows an error — but the cache already reflects the "saved" value, and the UI has already moved on.

**What could go wrong:** user sees an error toast but the data still appears saved in their saves list. If they close the tab, the change is lost.

**Fix (Medium):** either await the upsert in user-triggered save paths (show a spinner), or add a "pending save" visual indicator. Low priority since your team works mostly on solid connections.

---

### M6. `resetAll()` manually re-lists every state key
**Where:** lines 3566-3570

```js
state = {...state, showHome: ..., source: null, step: 0, propertyName: "", ...}
```

If you add a new state field and forget to reset it, it will leak between sessions.

**Fix (Small):** define the default state once at the top of the file (`const DEFAULT_STATE = { ... }`) and use `state = {...DEFAULT_STATE, showHome: ...}` in `resetAll()`.

---

### M7. `calcEconAvg` is duplicated
**Where:** function at line 3561, and inline calculation at line 3329

Same math in two places. If the rounding ever changes in one, the other drifts.

**Fix (Small):** replace the inline version with a call to `calcEconAvg()`.

---

## NIT (cleanup opportunities, no urgency)

### N1. Repeated `state.propertyName || ""` fallbacks all over the place
Could be a `getProp()` helper. Saves a few keystrokes, no functional impact.

### N2. Inconsistent console logging
Some failures use `console.warn`, some `console.error`, some nothing. Not a bug — just cosmetic.

### N3. Inline styles everywhere
Most of your UI uses inline `style="..."` attributes instead of CSS classes. Works fine. Painful to theme later.

### N4. `EMAIL_DOMAIN` is hardcoded
That's actually correct for this tool. Just flagging that if LeavenWealth ever rebrands, there's a single constant to change.

### N5. Enormous base64 logos embedded in the HTML
`LOGO_FULL` (line 174, ~94KB) and `LOGO_SYMBOL` (line 175, ~89KB). Adds ~180KB to every page load. Could be moved to separate files or to Supabase Storage. Not urgent.

---

## POSITIVES — things already done well

Worth calling out so we don't accidentally remove them in future cleanups:

1. **`escapeHtml` / `attrJs` helpers at lines 199-208** — the right defensive pattern. Just need to use them in the two spots in C1.
2. **Cache wipe at the top of `supaBootstrap`** — explicitly clears `_dbCache` before reload, preventing stale state between logins.
3. **`_isCacheOnlyKey` abstraction** — clean separation between "persist to Supabase" and "session-only" keys. Makes the free-tier quota strategy explicit.
4. **`onPersistErr` surfaces failures visibly** — even though the message text is stale (see H2), the pattern of surfacing errors in the UI is better than silent failure.
5. **`narrativesEdited` flag** — preserves user edits when they navigate back and forth between steps. Smart.
6. **Defense-in-depth on auth** — client-side email check + DB trigger + RLS means a bypass attempt has to defeat three layers.
7. **Auth overlay blocks UI until `_bootAfterAuth` completes** — prevents the "empty list flash" that plagues a lot of cloud-synced apps.
8. **Hard reload on sign-out** — cleanest possible way to clear in-memory state. Overkill is the right call here.

---

## Recommended Fix Order

If you want to tackle these in waves rather than all at once, my suggestion:

1. **Quick wins (one sitting, ~1-2 hours):** C1, H1, H2, H3, H5, M3, M6, M7
2. **Before new features (half-day):** C2, H4, H6
3. **When you're touching nearby code:** M1, M2, M5
4. **Whenever:** all NIT items

I'd recommend starting the new `qr_reports` / `qr_photos` / `qr_files` work only after #1 and #2 are done — the cleanup makes the new code easier to slot in cleanly, and C2 + H6 directly affect the data model we're about to build on.

---

## What's next

Let me know which findings you'd like me to fix first. I'll walk through each change before I make it, and won't touch anything destructive without your explicit sign-off.
