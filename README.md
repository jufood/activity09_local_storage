# In-Class Activity 09 — Local Storage, Part II

## Fall Festival Roster & Card Catalogue

**Project:** `act8` (extended from In-Class Activity 08)  
**Pathway:** Undergraduate  
**Platform tested:** Pixel 7 Android Emulator, Android 16 (API 36)  
**Framework:** Flutter / Dart  
**Database:** SQLite via `sqflite`  
**Database file:** `MyDatabase.db`  
**Schema:** Version 1 → Version 2

## 1. Overview

This project extends my Activity 08 Fall Festival Roster without replacing its existing SQLite database. The original guest CRUD screen remains available. Activity 09 adds a folder-and-card catalogue: a folder can contain multiple cards, and every card belongs to one folder. The app supports creating and deleting folders; creating, reading, editing, and deleting cards by their integer IDs; displaying folder card counts; validation; delete confirmations; and a placeholder when a card image reference is missing.

I used fictional test records only.

## 2. Schema and Migration

The existing `my_table` was retained:

| Column | Type |
|---|---|
| `_id` | `INTEGER PRIMARY KEY` |
| `name` | `TEXT NOT NULL` |
| `age` | `INTEGER NOT NULL` |

Version 2 adds:

```sql
CREATE TABLE folders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
);

CREATE TABLE cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  suit TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  image_ref TEXT,
  folder_id INTEGER NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
);

CREATE INDEX idx_cards_folder_id ON cards(folder_id);
```

`DatabaseHelper.init()` opens the same `MyDatabase.db` filename with database version 2. `onConfigure` enables `PRAGMA foreign_keys = ON`. For an existing version-1 installation, `onUpgrade` creates only the new catalogue tables and index; `onCreate` creates both the original guest table and catalogue schema on a fresh installation. No code intentionally drops or recreates `my_table` during migration. SQLite's `onCreate` / `onUpgrade` callbacks run in the sqflite-managed transaction.

**Delete policy:** `ON DELETE CASCADE` removes cards when their parent folder is deleted. That is appropriate for disposable catalogue cards that belong exclusively to the folder. In a record-keeping application with legally or operationally important records, `RESTRICT`, reassignment, or soft deletion would be safer. The UI asks for confirmation before deleting a folder or card.

**Image choice:** `image_ref` is nullable. The app shows a suit-based fallback when the reference is missing. The image is not required to use the card. Images are not stored as BLOBs; paths/URLs are references, not embedded image data.

## 3. Architecture and Features

- `lib/database_helper.dart`: database opening, schema versioning, old guest CRUD, new folder/card CRUD, and read-only PRAGMA diagnostics.
- `lib/main.dart`: original guest roster and Activity 09 folder/card interfaces.
- Existing guest screen remains accessible through the app navigation.
- Folder counts use a `LEFT JOIN` so empty folders can still be listed.
- Reads and writes target stable database IDs, not list positions or names; ID-based queries use bound `whereArgs`.
- Card titles can be duplicated; folder names must be unique.
- Validation blocks whitespace-only titles and folder names. The interface gives feedback for rejected actions.

**Architecture limitation to check before submission:** The official rubric requests separate typed `Folder` and `CardRecord` classes with `fromMap()` / `toMap()` plus a repository boundary. Confirm these are present in the final source; the helper alone does not prove that requirement is met.

## 4. Activity 08 Data-Preservation Evidence

The original installed database contained three guest records before the version-2 change:

| Guest ID | Name | Age |
|---:|---|---:|
| 2 | River | 35 |
| 3 | Acorn | 0 |
| 4 | Oak | 130 |

**Before:** 3 rows. **After launching the updated app:** the same three IDs, names, ages, and row count appeared on the guest screen. Evidence: `evidence/T1_before.png` and the post-upgrade guest screen observation.

The project's earlier Activity 08 tests (guest add, edit, delete, validation, and persistence) were completed before this assignment. Activity 09 testing below is a separate sequence.

## 5. Activity 09 Manual Test Matrix (T1–T6)

The actions and observations below reflect the interactive tests performed on the Android emulator. The UI screenshots and conversation established the reported counts and names; **actual database-generated folder/card IDs, write-affected-row counts, and PRAGMA query outputs have not yet been transcribed** and should be collected rather than guessed.

| Test | Action / Input | Expected | Observed | Status |
|---|---|---|---|---|
| T1a — Upgrade preservation | Launch updated app on existing Activity 08 installation | Original guest rows unchanged; version-2 schema created | Guest IDs 2, 3, 4 retained with same names/ages; folder catalogue displayed and worked | Pass for visible preservation; PRAGMA checks pending |
| T1b — Fresh create | Run version 2 on **separate disposable** Android target | Both guest and catalogue tables created; empty folder opens | Not run/documented | Not tested |
| T2 — Parent-child create | Create `Atlas` and `Harbor`; add two `Compass` cards to Atlas (Hearts and Spades); add `Signal` (Diamonds) to Harbor, with empty `image_ref` | Atlas 2 cards; Harbor 1 card; 3 distinct card IDs | Atlas displayed 2, Harbor 1; cards created in selected folders | Pass for UI behavior; record actual IDs |
| T3 — Edit identity | Edit Hearts `Compass` to `Compass revised` with new notes; start editing Spades `Compass` then Cancel | Only selected card changes; Cancel does not write; counts remain 2 and 1 | Hearts title updated; Spades remained `Compass`; counts unchanged | Pass for UI behavior; affected-row result not captured |
| T4 — Cold restart | Stop app, force-stop/relaunch same installed app without clearing storage | IDs, names, values, and folder counts persist | Atlas 2, Harbor 1 and card names persisted on relaunch | Pass for visible persistence; document exact stop procedure/IDs |
| T5 — Delete behavior | Cancel card delete, then delete Spades `Compass`; cancel folder delete, then delete `Atlas` | Cancel has no effect; card removal leaves Atlas 1; deleting Atlas cascades remaining child; Harbor/Signal remain | Atlas removed with its last child; Harbor remained with 1 Signal card | Pass for visible behavior; SQL orphan check pending |
| T6 — Validation and fallback | Open `Signal` with null image; try whitespace-only title; whitespace-only folder name; duplicate `Harbor` folder name | Placeholder displayed; invalid inputs rejected; original records unchanged | Suit fallback shown; invalid attempts rejected, including message `Folder name cannot be blank. Nothing saved.`; Harbor remained one folder with one card | Pass |

### Evidence files

- `evidence/T1_before.png` — original version-1 guest data before upgrade.
- `evidence/T2_cards.png` — the catalogue with Atlas and Harbor card counts.
- `evidence/T4_after.png` — catalogue displayed after relaunch.
- `evidence/analysis_output.txt` — actual `flutter analyze` output.

These are the Activity 09 evidence filenames. Other pre-existing files in `evidence/` may belong to Activity 08 and should not be relabeled as Activity 09 results.

### Additional read-only verification to record

The helper provides diagnostics that can be used on the actual open connection:

```sql
PRAGMA user_version;
PRAGMA foreign_keys;
PRAGMA foreign_key_list(cards);
PRAGMA index_list(cards);
SELECT _id, name, age FROM my_table ORDER BY _id;
```

**Not yet captured in this README:** actual version value, `foreign_keys` status, foreign-key/index query outputs, numerical folder/card IDs, affected-row counts, and a SQL query verifying zero cards reference the deleted Atlas folder. Do not mark these as completed until measured.

## 6. Build, Run, and Analyze

From the project directory:

```powershell
flutter pub get
flutter devices
flutter run -d emulator-5554
flutter analyze 2>&1 | Tee-Object -FilePath .\evidence\analysis_output.txt
flutter build apk --release
```

**Analyzer result observed:** `No issues found! (ran in 2.9s)` on October 12, 2026.

**Release APK installation/smoke test:** pending. The eventual built APK should be installed and tested on a disposable Android device/emulator without erasing the original database needed for migration evidence.

## 7. Known Limitations / Outstanding Verification

- The version-2 **fresh-install path** has not yet been separately demonstrated (T1b).
- Explicit PRAGMA diagnostics and SQL orphan checks still need to be recorded.
- Actual folder/card IDs and affected-row counts were not captured in this document.
- Release APK build/install/smoke test has not yet been reported.
- Verify typed models and clean repository separation against the official rubric before final submission.
- This app's data is device-local SQLite; it is not automatically encrypted, backed up, or synced.

## 8. Submission Checklist

Submit **three separate items** to iCollege:

1. `github_link.txt` — direct URL to the individual's accessible GitHub repository.
2. `Activity09_Lastname_Firstname.apk` — built release APK, installed and smoke-tested on Android.
3. `Lastname_Firstname_CriticalThinking.docx` — reflection prompts 1–3 and **exactly two** of U1–U4, using personal evidence, plus AI-use disclosure and student identification.

GitHub source must include this README, Flutter source and dependency files, the original Part I helper/schema and version-2 migration, and the Activity 09 evidence folder. Exclude build outputs, `.dart_tool`, secrets, and any real personal data.

## 9. Learning Summary

I extended a single-table Flutter/SQLite app into a related two-table catalogue and verified the visible preservation of the original guest records. The tests showed why row IDs, foreign keys, explicit delete behavior, input validation, and restart testing matter. Remaining diagnostics are reported as incomplete rather than represented as results that were not directly observed.
