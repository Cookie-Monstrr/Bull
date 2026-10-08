#!/usr/bin/env python3
"""Dependency-light static checks for Bull v3.4 Build 54.

This intentionally does not claim Swift type-checking: the delivery environment has no
Xcode or Apple SDK. It validates the project contract, property lists, JSON, artwork
dimensions/transparency, widget registration and the user-facing terminology touched by
this build.
"""
from pathlib import Path
import json
import plistlib
import re
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


project = ROOT / "Bull.xcodeproj" / "project.pbxproj"
project_text = project.read_text(encoding="utf-8")
require(project.exists(), "Xcode project is missing")
require(project_text.count("CURRENT_PROJECT_VERSION = 54;") == 6,
        "expected six Build 54 configuration versions")
require("CURRENT_PROJECT_VERSION = 53;" not in project_text,
        "a Build 53 configuration remains")
require("MARKETING_VERSION = 3.4;" in project_text, "marketing version changed")
require("PRODUCT_BUNDLE_IDENTIFIER = com.ahmed.Bull;" in project_text,
        "app bundle identity changed")
require("PRODUCT_BUNDLE_IDENTIFIER = com.ahmed.Bull.BullWidgets;" in project_text,
        "widget bundle identity changed")
require("DEVELOPMENT_TEAM = 8LT6DKBQL7;" in project_text, "signing team changed")
require(project_text.count("D35000000000000000000001 /* SharedFigures */") == 4,
        "SharedFigures is not present in all four synchronized target groups")

all_swift_paths = sorted(ROOT.rglob("*.swift"))
all_swift = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in all_swift_paths)
require((ROOT / "Bull" / "DailyInputReminder.swift").exists(),
        "daily input reminder queue source is missing")
require('appendingPathComponent("bull-data-v15.json")' in all_swift,
        "BullData v15 filename contract changed")
require("public let currentFourScoreVersion = 10" in all_swift,
        "four-score version contract changed")

for path in sorted(list(ROOT.rglob("*.plist")) + list(ROOT.rglob("*.entitlements"))):
    try:
        plistlib.loads(path.read_bytes())
    except Exception as exc:  # pragma: no cover - diagnostic path
        errors.append(f"invalid plist/entitlements {path.relative_to(ROOT)}: {exc}")
widget_info = ROOT / "BullWidgets" / "Info.plist"
try:
    widget_payload = plistlib.loads(widget_info.read_bytes())
    require(
        widget_payload["NSExtension"]["NSExtensionPointIdentifier"]
        == "com.apple.widgetkit-extension",
        "widget extension point changed",
    )
except Exception as exc:
    errors.append(f"invalid widget Info.plist: {exc}")

for path in sorted(ROOT.rglob("*.json")):
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - diagnostic path
        errors.append(f"invalid JSON {path.relative_to(ROOT)}: {exc}")

catalog = ROOT / "SharedFigures" / "Figures.xcassets"
expected_assets = [
    catalog / f"bull-figure-{role}-{stage}.imageset" / f"bull-figure-{role}-{stage}.png"
    for role in ("bull", "provider", "devil", "angel")
    for stage in range(1, 6)
]
for path in expected_assets:
    require(path.exists(), f"missing figure asset {path.relative_to(ROOT)}")
    if not path.exists():
        continue
    try:
        with Image.open(path) as image:
            require(image.mode == "RGBA", f"figure is not RGBA: {path.name}")
            require(image.size == (512, 768), f"figure dimensions changed: {path.name}")
            alpha = image.getchannel("A")
            histogram = alpha.histogram()
            bounds = alpha.getbbox()
            require(histogram[0] >= 512 * 768 * 0.15, f"insufficient transparency: {path.name}")
            require(histogram[255] >= 512 * 768 * 0.05, f"insufficient opaque artwork: {path.name}")
            require(bool(bounds) and bounds[0] >= 1 and bounds[1] >= 1,
                    f"artwork touches the top/left edge: {path.name}")
            require(bool(bounds) and bounds[2] <= 511 and bounds[3] <= 767,
                    f"artwork touches the bottom/right edge: {path.name}")
    except Exception as exc:
        errors.append(f"could not inspect figure {path.name}: {exc}")

widget_text = (ROOT / "BullWidgets" / "BullWidgets.swift").read_text(encoding="utf-8")
widget_names = [
    "BullFaceOffWidget", "BullRoutineFiguresWidget", "BullPrioritiesWidget",
    "BullUrgeOverviewChartWidget", "BullUrgeBreakdownChartWidget",
]
bundle_match = re.search(
    r"struct BullWidgetsBundle.*?var body: some Widget \{(.*?)\n    \}",
    widget_text,
    re.S,
)
require(bundle_match is not None, "widget bundle registration block is missing")
if bundle_match:
    registered = [name for name in widget_names if re.search(rf"\b{name}\(\)", bundle_match.group(1))]
    require(len(registered) == len(widget_names), "not all five widgets are registered")

require("bull-widget-charts-v1" in all_swift, "chart widget payload is missing")
chart_contract = re.search(
    r"struct BullWidgetChartPoint.*?\n\}",
    (ROOT / "SharedFigures" / "BullFigureArtwork.swift").read_text(encoding="utf-8"),
    re.S,
)
require(chart_contract is not None and "relapse" not in chart_contract.group(0).lower(),
        "relapse history leaked into the chart widget contract")

patterns_text = (ROOT / "Bull" / "PatternsView.swift").read_text(encoding="utf-8")
for obsolete in (
    "Score / 100", "Values: period averages", "tap chart for a day",
    "Completed days · through yesterday", "Shortfall ranking",
    "Includes reconstructed historical components", "Red markers show logged relapses",
    "Sleep / HRV", "Urge Defence",
):
    require(obsolete not in patterns_text, f"obsolete Stats wording remains: {obsolete}")
require("U: protection · B: building · weights" not in widget_text,
        "widget weight footer remains")
require("Urge Defence" not in all_swift, "old Urge Defence label remains in Swift")
require("In Progress" not in all_swift, "generic In Progress label remains in Swift")
require("Archived zone" not in all_swift, "stale Archived zone label remains in Swift")

test_count = len(re.findall(r"^\s*func test", all_swift, re.M))

if errors:
    for error in errors:
        print(f"FAIL: {error}")
    sys.exit(1)

print(f"PASS: {len(all_swift_paths)} Swift source files are present for Xcode compilation")
print("PASS: Build 54 configuration count, marketing version, bundle IDs and signing team preserved")
print("PASS: BullData v15 and four-score version 10 contracts remain present")
print("PASS: property lists, entitlements and JSON files parse")
print("PASS: WidgetKit extension point and five-widget registration are present")
print("PASS: 20 shared figure assets retain 512×768 RGBA/transparency bounds")
print("PASS: Stats/widget terminology and privacy contract checks passed")
print(f"INFO: {test_count} XCTest methods are source-present; XCTest execution is not available here")
