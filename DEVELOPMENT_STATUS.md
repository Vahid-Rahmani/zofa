# Development Status

Living tracker for the Zova evidence-informed language-learning app. Updated at
the end of each work session. Phases are executed sequentially; a phase is only
marked complete after its implementation and verification (analyze + tests) pass.

## Build & verify

```powershell
C:\Users\DCI-Student\flutter\bin\flutter.bat analyze
C:\Users\DCI-Student\flutter\bin\flutter.bat test
```

## Completed phases

### Phase 1 — Optimized, scalable JSON dictionary

Status: **Complete** (implemented + verified; 47/47 tests green, analyze clean).

- Extended `DictionaryEntry` schema: `id`, `lemma`, `language`, `phonetic`,
  `gender`, `plural`, `synonyms`, `antonyms`, `relatedWords`,
  `irregularForms`, `alternateTranslations`, `topics`, `tags`, `frequency`,
  `audioRef`, `imageRef`. `effectiveId` falls back to a slug of the headword;
  `effectiveLemma` to the word.
- Resilient loader: `DictionaryEntry.validate` / `tryParse` let the engine skip
  malformed rows instead of crashing; `DictionaryService.lastSkippedCount`
  reports dropped rows for import sanity checks.
- `lib/data/services/normalize.dart`: pure `normalizeText`, `slug`,
  `headwordHash`, `isHeadwordQuery`.
- `lib/data/services/dictionary_index.dart`: sorted headword prefix table +
  level / POS / tag position buckets; serialised to a JSON sidecar.
- `lib/data/services/dictionary_service.dart`: immutable indexed engine with
  `loadPack` (background-isolate parse), `searchPaged` (pagination + filters),
  and `lookup` / `byId` / `byTag` / `byLevel` / `all` / `entries` /
  `wordCount` / `exampleCount` / `fromJsonString` / `fromPack` / `seedAsset`.
  CEFR level list `kCefrLevels` = A1..C2.
- `tool/import_dictionary.dart`: CLI (`import`, `build-index`, `stats`) that
  validates, dedupes and writes canonical entries + index sidecars.
- Generated sidecars: `assets/dictionary/english.index.json` (420 entries,
  A1:138 / A2:139 / B1:143) and `german.index.json` (341 entries); bundled
  offline via the `assets/dictionary/` glob in `pubspec.yaml`.
- UI: rewritten `dictionary_screen.dart` (debounced 300 ms paged search,
  A1–C2 level chips, POS / topic dropdowns, infinite scroll, entry detail with
  Save / Leitner buttons); Leitner "Word pool" card pulls words by level and
  bulk-adds them.
- Performance: 100k-entry build ≈ 1.0 s, indexed search suite ≈ 0.4 s (test
  asserts < 5 s).
- Tests: `test/dictionary_engine_test.dart` (index round-trip, `searchPaged`
  paging/prefix/Persian-query/filters, course-from-dictionary, scale,
  validation/resilience, `byId`/`byTag`, metadata round-trip),
  `test/dictionary_screen_test.dart` (3 widget tests).

Architectural decisions:

- JSON + sidecar index (positions, no duplicated headwords) over SQLite; a
  single `compute`-isolate parse keeps the UI smooth at 100k+ entries; no
  synthetic stress data.
- CEFR `level` doubles as difficulty; no separate difficulty field.
- Curated seed datasets preserved for continuity; large dumps are imported via
  the tool, never committed by hand.

## Current phase

### Phase 2 — Learning / spaced-repetition engine

Status: **Complete** (implemented + verified; 58/58 tests green, analyze clean).

- `lib/data/models/learning_state.dart`: `LearningStage` (`new` / `learning` /
  `review` / `mastered`) and immutable `LearningState` — Leitner box, stage,
  repetitions, interval days, SM-2 ease factor, due date, last-reviewed stamp,
  correct/incorrect history. Graceful JSON round-trip; `LearningState.legacy`
  migrates old box-only records (due immediately).
- `lib/data/services/spaced_repetition.dart`: deterministic, clock-injected
  scheduler (`now` closure injectable). Correct recall advances the box and
  grows intervals SM-2-style (1, 6, then `interval * ease`, mastered at 21+
  days); failure drops to box 1, resets repetitions, lowers ease (bounded to
  1.3..2.5) and keeps the word due today for retry. Exposes `dueQueue` /
  `dailyDueCount` / `isDue` for the daily review queue.
- `UserProgress`: `leitnerBoxes` (word -> int) is now a *derived* view;
  canonical storage is `learning` (word -> `LearningState`). Legacy
  `leitner_boxes` JSON migrates automatically; `toJson` writes both for
  backwards compatibility.
- `AppController`: injected `SpacedRepetitionScheduler`; `addToLeitner` seeds a
  fresh state, `reviewLeitnerCard` runs the scheduler, `removeFromLeitner`
  drops it; `learningState` / `scheduler` exposed to UI and tests.
- Leitner screen: stats card and box cards show "due today" counts driven by
  the scheduler.
- Tests (`test/spaced_repetition_test.dart`): new-state defaults, interval
  growth to mastery, failure reset, ease bounds, max box, `dueQueue` ordering,
  legacy migration, learning round-trip, and an `AppController` integration
  test over a fixed clock.

Architectural decisions:

- SM-2-style scheduling layered over the existing Leitner boxes (box drives the
  UI grouping, SM-2 fields drive *when* a card is due).
- Clock injected via closure so the engine is fully deterministic in tests.
- Single source of truth: `learning` map; `leitnerBoxes` is a compatibility
  view, so existing screens and saved data keep working.

## Next phase

### Phase 3 — Dashboard (next)

Not started. Planned scope: progress overview (daily streak, words learned,
due counts per box, per-level breakdown, recent activity), reading state from
`AppController.progress` + `SpacedRepetitionScheduler.dailyDueCount`.

## Remaining phases

- **Phase 4 — Roadmap**: skill tree / level progression UI driven by learner
  state.
- **Phase 5 — Mini-games**: recall games reusing dictionary + learning state.
- **Phase 6 — Multi-language**: Spanish / French / Italian dictionary packs and
  language selection.

## Known issues

- Bundled English dictionary is a curated 420-entry seed (A1/B1 only); B2–C2
  buckets are empty until a larger dump is imported.
- `android/app/build.gradle.kts` carries a pre-existing unrelated modification;
  it is excluded from commits.
