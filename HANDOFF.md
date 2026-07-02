# טופס ביקור שבועי — Project Handoff

## What this is

A single-file HTML/CSS/JS Progressive Web App (PWA) for **TAMA 38 (תמ"א 38) construction supervision**. A construction supervisor fills out weekly site visit reports, tracks stage statuses, logs issues/findings, uploads photos, and generates Word (.doc) reports. Fully RTL Hebrew, mobile-first.

---

## File Locations

| File | Purpose |
|------|---------|
| `טופס_ביקור_שבועי.html` | Main app (~2058 lines, single file) |
| `sw.js` | Service worker for PWA offline support |
| `manifest.json` | PWA manifest |

All three files live in the same folder:
```
C:\Users\tai\AppData\Roaming\Claude\local-agent-mode-sessions\67afbd8b-4832-498b-9ad1-9f41c638243b\21fb8274-b095-450a-9a07-964dca06a409\local_18867336-1905-4b60-8ad7-addbdf9a1f81\outputs\
```

---

## Persistence — localStorage Keys

| Key | Contents |
|-----|----------|
| `pikuach_settings` | projects[], stageCategories, apiKey, projectCustomStages, projectDescriptions |
| `pikuach_history` | archived visit records (visitHistory[]) |
| `pikuach_drafts` | auto-save drafts per project |
| `pikuach_lastStates` | last stage statuses per project |
| `pikuach_dbxToken` | Dropbox access token |
| `pikuach_pin` | admin PIN (default "1234") |
| `pikuach_lastProject` | last active project name |

Photos are **never persisted to localStorage** — only session memory (`state.stagePhotos`) and Dropbox URLs (`state.stagePhotoLinks`).

---

## State Object

```js
let state = {
  project:'', visitDate:'', visitTime:'',
  supervisorName:'', siteManager:'', projectType:'',
  stages:{}, stageNotes:{}, issues:[],
  stagePhotos:{}, issuePhotos:{},         // session-only, cleared on project switch
  stagePhotoLinks:{}, issuePhotoLinks:{}, // Dropbox URLs, persisted in archive
  planWeek1:[], planWeek1Other:'',
  planWeek2:[], planWeek2Other:'',
  nextVisitDate:'', overallProgress:'',
  photoDesc:'', dropboxLink:'',
  generalNotes:'', photoCount:0,
  generalPhotos:[]                        // [{dataUrl, desc}] — session-only
};
```

## Settings Object

```js
let settings = {
  projects:[],
  stageCategories: DEFAULT_CATS,   // 8 categories, editable
  apiKey:'',                        // Claude API key for AI features
  projectCustomStages:{},           // { projectName: [{cat:0-7, name:'Hebrew'}] }
  projectDescriptions:{}            // { projectName: 'free text description' }
};
```

---

## Stage Categories (DEFAULT_CATS) — indices 0–7

| # | Name |
|---|------|
| 0 | טרום חפירה וקדם עבודה |
| 1 | שלד הבניין |
| 2 | טרום טיח – תשתיות |
| 3 | טיח ואיטום |
| 4 | גמרים – מעטפת |
| 5 | גמרים – פנים דירה |
| 6 | מערכות בניין |
| 7 | עבודות חוץ ופיתוח |

---

## Stage Status Options (OPTS)

```js
const OPTS = [
  {key:'done',     lbl:'✓ בוצע',     cls:'done'},
  {key:'prog',     lbl:'בביצוע',     cls:'prog'},
  {key:'notyet',   lbl:'○ טרם',      cls:'notyet'},
  {key:'na',       lbl:'לא רלוונטי', cls:'na'},
  {key:'finished', lbl:'🏁 הסתיים',  cls:'finished'}
];
```

- `finished` stages are **hidden from the form** but appear in reports with 🏁
- `finished` counts as 100% in progress calc and unlocks the next category (same as `done`)

---

## Key Functions

### Core Flow

```js
selectProject(name)    // saves current draft, loads new project, calls rebuildAll()
rebuildAll()           // syncs entire DOM from state — calls buildStages, buildPlanSection,
                       // renderIssues, updateCatLocks, updatePlanLock, updateProgressBar
buildStages()          // renders categories; SKIPS stages where state.stages[s]==='finished'
isCatUnlocked(i)       // true if admin/lockOverride OR prev cat has done/finished OR all prev are na
calcProgress()         // returns 0–100 or null
autoSave()             // debounced 800ms → saves state to projectDrafts[project]
archiveVisit()         // saves snapshot to visitHistory[], clears draft
```

### Photos

```js
compressImg(dataUrl, maxDim=1400, quality=0.80)   // general compression
compressForReport(dataUrl)                          // → maxDim=450, quality=0.75
triggerCam(type, key, useGallery)                  // type: 'stage'|'issue'|'general'
addGeneralPhotoToStrip(idx, src, desc)             // renders photo card with textarea + AI button
delGeneralPhoto(idx)
updateGeneralPhotoDesc(idx, val)
improvePhotoDesc(idx)                              // Claude Haiku improves photo description
```

### Reports

```js
generateCurrentVisitReport()     // async; session photos only; downloads .doc
generateHistoricalReport()       // filters visitHistory[]; includes stagePhotoLinks; downloads .doc
downloadAsDoc(contentHtml, filename)   // wraps in Word-compatible HTML, triggers browser download
openReportInBlob(html)           // kept for fallback; opens HTML in new tab
```

**Critical**: `generateCurrentVisitReport` uses **only** `state.stagePhotos` (session memory). It does NOT include `state.stagePhotoLinks` (old Dropbox archive links). Historical report is the opposite — it reads `stagePhotoLinks` from archived visits.

### AI Features (require `settings.apiKey`)

```js
parseSmartText()      // fills stage statuses from free Hebrew text (smart AI section)
learnFromProject()    // adds custom stages from project description textarea
improvePhotoDesc(idx) // improves per-photo description text
```

All AI calls use:
```js
fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': settings.apiKey,
    'anthropic-version': '2023-06-01',
    'anthropic-dangerous-direct-browser-access': 'true'
  },
  body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: ..., messages: [...] })
})
```

### Dropbox

```js
saveDbxToken()          // stores token, updates UI
uploadAllPending()      // uploads all session photos to Dropbox
uploadStagePhoto(sname, idx, dataUrl)
uploadIssuePhoto(id, idx, dataUrl)
```

API: `/files/upload` + `/sharing/create_shared_link_with_settings`  
Token: `let dbxToken` (runtime) + `localStorage 'pikuach_dbxToken'`  
Links saved to: `state.stagePhotoLinks[stageName][]` and `state.issuePhotoLinks[issueId][]`

---

## UI Sections (top to bottom)

1. **Top bar** — title, 🔐 admin badge, ☁️ Dropbox button, 🔐 admin button
2. **Projects bar** — pill buttons per project + ⚙️ manage
3. **🤖 מילוי חכם – AI** — free text → auto-fill stage statuses via Claude or keyword fallback
4. **📖 תיאור הפרויקט** — project description + "⚡ למד מהפרויקט" → adds custom stages per project
5. **📋 פרטי ביקור** — date/time (auto-stamped), supervisor, site manager, project type
6. **🏗️ שלבי הבנייה** — sequentially locked categories; each stage has status buttons + notes textarea + photo strip
7. **⚠️ ממצאים** — issues list with severity (גבוהה/בינונית/נמוכה), description, required action, target date, photos
8. **📋 תכנית עבודה** — week 1 / week 2 checkboxes; locked until any stage is `done`/`finished`; manual unlock button
9. **📷 תמונות כלליות ו-Dropbox** — general photos (per-photo description card + ✨ AI improve) + Dropbox connect/upload
10. **📝 הערות כלליות** — free text notes
11. **Bottom bar** — progress %, 📁 archive, 📊 report, 📤 share, 💾 save

---

## Locking Logic

- **Stage categories**: Category N+1 is locked until category N has ≥1 `done`/`finished` OR all stages in N are `na`
- **Work plan**: Locked until any stage is `done`/`finished`. Has a "פתח ידנית" manual unlock button (`planManualUnlock` flag)
- **Admin override**: `isAdmin` or `lockOverride` bypasses all locking
- `isCatUnlocked(i)` checks: `isAdmin || lockOverride || (prev cat has done/finished) || (all prev are na)`

---

## Admin Mode

- PIN-protected via `doAdminLogin()`, PIN stored in `pikuach_pin` (default `"1234"`)
- Shows "🔐 אדמין" badge in top bar
- Available options: change PIN, toggle lock override (`lockOverride`), reset current visit, export/import full JSON backup

---

## Project Learning Feature (`learnFromProject`)

1. User writes free-text project description in `#projectBriefText`
2. Clicks "⚡ למד מהפרויקט"
3. If `settings.apiKey` set → calls Claude Haiku with list of 8 categories, asks for unique stages JSON
4. Keyword fallback map covers: בריכה, ג׳קוזי, חניה תת-קרקעית, מחסן, ממ"ד, מרתף, גינה, חדר כושר, פנטהאוז, לובי, גג ירוק, חדר קהילה, ספא, חדר אשפה, מבנה ציבור
5. New stages saved to `settings.projectCustomStages[projectName][]`
6. `cats()` function merges them at runtime: `base[cat].stages.push(name)`
7. Custom stages are **per-project only** — don't affect other projects

---

## General Photos System

- `state.generalPhotos = [{dataUrl, desc}]` — session-only array
- `#genPhotosArea` div holds the photo cards; `#generalPhotosStrip` is the outer container
- Each card rendered by `addGeneralPhotoToStrip(idx, src, desc)` shows: thumbnail + description textarea + ✨ improve button (if API key) + × delete
- On project switch, `state.generalPhotos = []` and area is cleared
- Archive saves `generalPhotosDescs: [{desc}]` (descriptions only, no dataUrls)
- Report includes compressed photos with their descriptions

---

## Report Format (Word .doc)

`downloadAsDoc(contentHtml, filename)` wraps content in:
```html
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns="http://www.w3.org/TR/REC-html40" dir="rtl">
```
With `﻿` BOM prefix and `application/msword` MIME type. Word opens `.doc` HTML files natively and allows full editing.

---

## Potential Next Features

- Export/import full data backup as JSON file (cross-device sync workaround)
- True `.docx` generation using a JS library (e.g. `docx` npm package via CDN)
- Push notifications for scheduled next visit date
- Issue resolution tracking across multiple visits
- Photo gallery viewer inside the archive per visit
- Cloud sync / multi-user collaboration
