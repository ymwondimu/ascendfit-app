# Offline exercise catalog

Ascend Fit bundles 103 maintained exercises and 839 supplemental exercises adapted from [Free Exercise DB](https://github.com/yuhonas/free-exercise-db). The source snapshot is commit `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`; its `dist/exercises.json` SHA-256 is `5bb747e3fc658f095a60dcbf6d53c96627acdcc6ffb6fffde86f7e26995d40bf`. The upstream repository describes the dataset as public domain; its license is copied in [THIRD_PARTY_FREE_EXERCISE_DB_LICENSE.md](THIRD_PARTY_FREE_EXERCISE_DB_LICENSE.md).

`scripts/build_exercise_catalog.py` deterministically converts that snapshot into `AscendFit/Resources/free-exercise-db-catalog.json`. It omits names already present in the maintained catalog, groups entries for the manual picker, normalizes common equipment labels, and creates stable numeric IDs from upstream slugs. Existing IDs 1–102 remain unchanged. The app bundles the compact JSON and requires no network access to browse or match exercises. Images are not included.

To regenerate the resource after deliberately updating the pinned source, update the revision and SHA-256 in the generator, download that exact revision, then run:

```sh
python3 scripts/build_exercise_catalog.py /path/to/pinned/exercises.json
make generate
```

Catalog size measures breadth, not real-world recognition. We still need a consented, representative corpus of coach-written workouts to measure the share of exercise lines that match automatically and to audit false matches. A unique name plus compatible equipment may match automatically; ambiguous or conflicting entries remain available for explicit review or exact-name custom import.
