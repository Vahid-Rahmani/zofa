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

### Phase 3 — 3-way multilingual architecture (English <-> German <-> Persian)

Status: **Complete** (implemented + verified; 69/69 tests green, analyze clean).

- `DictionaryEntry` now models a full **3-way bridge**: `word` (target
  headword), `translation` (canonical Persian gloss), `englishTranslation`
  (English gloss), `persianDefinition` / `englishDefinition` (fuller meanings)
  and `example` with `persianExample` / `englishExample` translations.
  `translationIn(code)` / `definitionIn(code)` / `exampleIn(code)` pick the
  explanation-language rendering; `exampleTranslation` / `persianTranslation`
  remain as legacy read aliases and legacy JSON keys (`persian_translation`,
  `example_translation`) migrate automatically. `english_translation` is now a
  required field (validation + `tryParse`).
- `concept` links the same idea across target dictionaries (`apple` /
  `der Apfel`); `effectiveConcept` / `effectiveId` fall back to the headword
  slug. `DictionaryService` gained `byConcept` / `hasConcept` and `search`
  now scans glosses, definitions and example translations (Latin headword
  queries still use the index prefix table).
- `lib/data/models/language_settings.dart`: `AppLanguage` (`en` / `fa`) and
  `LanguageSettings` with independent `uiLanguage` + `translationLanguage`,
  `isRtlUi`, JSON round-trip.
- `lib/core/state/language_controller.dart`: persisted language preferences
  (loaded at boot from `LocalStore.getLanguageSettings`, saved on change).
  Injected into `AppController` (exposed as `controller.language`) and
  provided at the root; `ZovaApp` sets `MaterialApp.locale` and overrides
  `Directionality` for RTL Persian UI.
- `tool/core_vocabulary.dart`: idempotent symmetric corpus builder that merges
  the parallel EN/DE dictionaries into the 3-way model (concept linking,
  curated definitions, German supplements for missing counterparts, English
  glosses/examples for German-only concepts). Hard checks fail the run on
  asymmetry, non-round-tripping entries or duplicate headwords.
- Regenerated assets: `english.json` (420) and `german.json` (430) plus both
  `.index.json` sidecars — every entry carries word + Persian + English gloss,
  definitions and example translations; German nouns keep their article.
- UI: dictionary cards and detail (translation + meaning + example), My Words
  and Leitner cards/review flashcard now render through
  `translationIn`/`definitionIn`/`exampleIn`; My Words and Leitner resolve
  saved words across **both** target dictionaries.
- New `language_settings_screen.dart` (interface + translation language),
  reachable from Profile.
- Tests: new `test/language_settings_test.dart` (model/JSON, controller
  persistence, settings screen); `dictionary_engine_test.dart` extended with
  legacy-JSON migration and 3-way helper tests; widget/auth/dictionary tests
  updated for the provider tree and broader search behaviour.

Architectural decisions:

- The learner's preferred *translation language* is a separate persisted
  preference from the *interface language*, so a Persian speaker can keep a
  Persian UI while reading English glosses (and vice versa).
- "English" in the 3-way bridge means the target-dictionary language, not the
  UI language; `translationIn` etc. render whichever explanation language is
  chosen.
- Supplements carry a `de-` id prefix and are never used as match partners, so
  re-running the corpus tool is byte-stable and idempotent.

## Next phase

### Phase 4 — Dashboard (next)

Not started. Planned scope: progress overview (daily streak, words learned,
due counts per box, per-level breakdown, recent activity), reading state from
`AppController.progress` + `SpacedRepetitionScheduler.dailyDueCount`.

## Remaining phases

- **Phase 5 — Roadmap**: skill tree / level progression UI driven by learner
  state.
- **Phase 6 — Mini-games**: recall games reusing dictionary + learning state.
- **Phase 7 — Multi-language**: Spanish / French / Italian dictionary packs and
  language selection.

## Known issues

- Bundled English dictionary is a curated 420-entry seed (A1/B1 only); B2–C2
  buckets are empty until a larger dump is imported.
- The reader (`books/reader_screen.dart`) still reads the legacy Persian
  `exampleTranslation` alias; making it fully language-aware is deferred.
- `android/app/build.gradle.kts` carries a pre-existing unrelated modification;
  it is excluded from commits.
