#!/usr/bin/env python3
"""Build the bundled, offline exercise seed from a pinned Free Exercise DB snapshot."""

import argparse
import hashlib
import json
import re
from pathlib import Path


SOURCE_REVISION = "f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5"
SOURCE_SHA256 = "5bb747e3fc658f095a60dcbf6d53c96627acdcc6ffb6fffde86f7e26995d40bf"
ROOT = Path(__file__).resolve().parents[1]
CURATED_ALIASES = {
    "Bicycling_Stationary": ["Stationary Bike", "Exercise Bike", "Stationary Cycling"],
    "Bodyweight_Squat": ["Bodyweight Squats", "Air Squat", "Air Squats"],
}


def normalized(value: str) -> str:
    aliases = {"dumbbells": "dumbbell", "kettlebells": "kettlebell",
               "pullup": "pull up", "pullups": "pull up",
               "pushup": "push up", "pushups": "push up",
               "chinup": "chin up", "chinups": "chin up"}
    return " ".join(aliases.get(token, token) for token in re.findall(r"[a-z0-9]+", value.casefold().replace("&", " and ")))


def current_names() -> set[str]:
    source = (ROOT / "AscendFit/ExerciseCatalog/ExerciseCatalog.swift").read_text()
    names = set()
    for match in re.finditer(r'e\(\d+, "([^"]+)", \[([^\]]*)\]', source):
        names.add(normalized(match.group(1)))
        names.update(normalized(alias) for alias in re.findall(r'"([^"]+)"', match.group(2)))
    if len(names) < 100:
        raise ValueError("Could not read the maintained Ascend Fit exercise names")
    return names


def category(entry: dict) -> str:
    source = entry["category"]
    if source == "cardio":
        return "cardio"
    if source == "stretching":
        return "mobility"
    if source in {"olympic weightlifting", "strongman"}:
        return "fullBody"
    muscles = set(entry["primaryMuscles"])
    if muscles & {"quadriceps", "hamstrings", "glutes", "calves", "adductors", "abductors"}:
        return "legs"
    if "chest" in muscles:
        return "chest"
    if muscles & {"lats", "middle back", "lower back", "traps"}:
        return "back"
    if "shoulders" in muscles:
        return "shoulders"
    if muscles & {"biceps", "triceps", "forearms"}:
        return "arms"
    if "abdominals" in muscles:
        return "core"
    return "other"


def equipment(entry: dict) -> str:
    raw = entry.get("equipment")
    name = entry["name"].casefold()
    if raw == "machine":
        if entry["id"] == "Bicycling_Stationary":
            return "Stationary bike"
        for token, label in [
            ("treadmill", "Treadmill"), ("elliptical", "Elliptical machine"),
            ("stationary bike", "Stationary bike"), ("rowing machine", "Rowing machine"),
            ("stair", "Stair machine"),
        ]:
            if token in name:
                return label
    labels = {
        "body only": "Bodyweight",
        "e-z curl bar": "EZ bar",
        "kettlebells": "Kettlebells",
        "bands": "Resistance band",
        "medicine ball": "Medicine ball",
        "exercise ball": "Exercise ball",
        "foam roll": "Foam roller",
    }
    if raw and raw != "other":
        return labels.get(raw, raw.capitalize())
    for token, label in [
        ("trap bar", "Trap bar"), ("smith", "Smith machine"),
        ("machine", "Machine"), ("cable", "Cable machine"),
        ("band", "Resistance band"), ("dumbbell", "Dumbbells"),
        ("barbell", "Barbell"), ("kettlebell", "Kettlebell"),
        ("plate", "Weight plate"), ("ring", "Gymnastic rings"),
        ("rope", "Rope"), ("ab roller", "Ab wheel"),
    ]:
        if token in name:
            return label
    return "Unspecified"


def modality(entry: dict) -> tuple[str, int, int, int]:
    kind = entry["category"]
    name = entry["name"].casefold()
    if kind == "cardio":
        return "timed", 1, 1, 0
    if kind == "stretching" or entry.get("force") == "static":
        return "timed", 2, 1, 30
    if "assisted" in name and ("pull-up" in name or "chin-up" in name):
        return "assisted", 3, 8, 120
    if entry.get("equipment") == "body only" or kind == "plyometrics":
        return "bodyweight", 3, 10, 90
    if kind == "olympic weightlifting":
        return "weighted", 3, 3, 150
    if kind == "powerlifting":
        return "weighted", 3, 5, 150
    return "weighted", 3, 10, 90


def description(entry: dict) -> str:
    steps = [" ".join(step.split()) for step in entry.get("instructions", []) if step.strip()]
    if steps:
        first = steps[0]
        return first if len(first) <= 220 else first[:219].rsplit(" ", 1)[0] + "…"
    return f"{entry['name']} using {equipment(entry).lower()}."


def stable_id(source_id: str) -> int:
    # Fixed by the upstream slug, so adding or removing other rows never changes an ID.
    return 1_000_000_000 + int.from_bytes(hashlib.sha256(source_id.encode()).digest()[:6], "big") % 900_000_000_000


def build(raw: bytes) -> dict:
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Source bytes differ from the pinned Free Exercise DB snapshot")
    known = current_names()
    output = []
    ids = set()
    for entry in sorted(json.loads(raw), key=lambda item: item["id"]):
        key = normalized(entry["name"])
        if key in known:
            continue
        known.add(key)
        exercise_id = stable_id(entry["id"])
        if exercise_id in ids:
            raise ValueError(f"Exercise ID collision: {entry['id']}")
        ids.add(exercise_id)
        mode, sets, reps, rest = modality(entry)
        output.append({
            "id": exercise_id,
            "sourceID": entry["id"],
            "name": entry["name"],
            "aliases": CURATED_ALIASES.get(entry["id"], []),
            "category": category(entry),
            "equipment": equipment(entry),
            "muscles": [muscle.title() for muscle in entry["primaryMuscles"]],
            "description": description(entry),
            "modality": mode,
            "defaultSeconds": 300 if entry["category"] == "cardio" else 30 if mode == "timed" else None,
            "defaultSets": sets,
            "defaultReps": reps,
            "defaultRestSeconds": rest,
        })
    return {"sourceRevision": SOURCE_REVISION, "exercises": output}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Pinned upstream dist/exercises.json")
    parser.add_argument("--output", type=Path, default=ROOT / "AscendFit/Resources/free-exercise-db-catalog.json")
    args = parser.parse_args()
    catalog = build(args.source.read_bytes())
    args.output.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"Wrote {len(catalog['exercises'])} supplemental exercises to {args.output}")


if __name__ == "__main__":
    main()
