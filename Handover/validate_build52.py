#!/usr/bin/env python3
"""Static build-52 checks for environments without Xcode or an Apple SDK."""
from pathlib import Path
import json
import plistlib
import re
import hashlib
from PIL import Image
from openstep_parser import OpenStepDecoder
from tree_sitter import Language, Parser
import tree_sitter_swift

ROOT = Path(__file__).resolve().parents[1]
swift_files = sorted(ROOT.rglob("*.swift"))
parser = Parser(Language(tree_sitter_swift.language()))
bad = [path for path in swift_files if parser.parse(path.read_bytes()).root_node.has_error]
assert not bad, "Swift syntax errors: " + ", ".join(map(str, bad))

project = ROOT / "Bull.xcodeproj" / "project.pbxproj"
with project.open() as handle:
    OpenStepDecoder.ParseFromFile(handle)

plists = sorted(list(ROOT.rglob("*.plist")) + list(ROOT.rglob("*.entitlements")))
for path in plists:
    with path.open("rb") as handle:
        plistlib.load(handle)
with (ROOT / "BullWidgets" / "Info.plist").open("rb") as handle:
    widget_info = plistlib.load(handle)
assert widget_info["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension"
for path in sorted(ROOT.rglob("*.json")):
    json.loads(path.read_text())

catalog = ROOT / "SharedFigures" / "Figures.xcassets"
expected = [
    f"bull-figure-{role}-{stage}"
    for role in ("bull", "provider", "devil", "angel")
    for stage in range(1, 6)
]
for name in expected:
    path = catalog / f"{name}.imageset" / f"{name}.png"
    with Image.open(path) as image:
        assert image.mode == "RGBA" and image.size == (512, 768)
        alpha = image.getchannel("A")
        histogram, bounds = alpha.histogram(), alpha.getbbox()
        assert histogram[0] >= 512 * 768 * .15
        assert histogram[255] >= 512 * 768 * .05
        assert bounds and bounds[0] >= 1 and bounds[1] >= 1
        assert bounds[2] <= 511 and bounds[3] <= 767

artwork = json.loads((ROOT / "Handover/BUILD52-ARTWORK-MANIFEST.json").read_text())
assert len(artwork["figures"]) == 10
assert {(f["family"], f["stage"]) for f in artwork["figures"]} == {
    (family, stage) for family in ("titan", "sorcerer") for stage in range(1, 6)
}
for figure in artwork["figures"]:
    assert hashlib.sha256((ROOT / figure["source"]).read_bytes()).hexdigest() == figure["source_sha256"]
    assert hashlib.sha256((ROOT / figure["asset"]).read_bytes()).hexdigest() == figure["asset_sha256"]

project_text = project.read_text()
all_swift = "\n".join(path.read_text(errors="replace") for path in swift_files)
widget_text = (ROOT / "BullWidgets" / "BullWidgets.swift").read_text()
bundle = re.search(
    r"struct BullWidgetsBundle.*?var body: some Widget \{(.*?)\n    \}",
    widget_text,
    re.S,
).group(1)
widget_names = [
    "BullFaceOffWidget",
    "BullRoutineFiguresWidget",
    "BullPrioritiesWidget",
    "BullUrgeOverviewChartWidget",
    "BullUrgeBreakdownChartWidget",
]
registered = [name for name in widget_names if re.search(rf"\b{name}\(\)", bundle)]

assert len(re.findall(r"CURRENT_PROJECT_VERSION = 52;", project_text)) == 6
assert "MARKETING_VERSION = 3.4;" in project_text
assert "PRODUCT_BUNDLE_IDENTIFIER = com.ahmed.Bull;" in project_text
assert "PRODUCT_BUNDLE_IDENTIFIER = com.ahmed.Bull.BullWidgets;" in project_text
assert "DEVELOPMENT_TEAM = 8LT6DKBQL7;" in project_text
assert project_text.count("D35000000000000000000001 /* SharedFigures */") == 4
assert len(registered) == 5
assert "public let currentFourScoreVersion = 10" in all_swift
assert 'appendingPathComponent("bull-data-v15.json")' in all_swift
patterns_text = (ROOT / "Bull" / "PatternsView.swift").read_text()
for obsolete in (
    "Score / 100",
    "Values: period averages",
    "tap chart for a day",
    "Completed days · through yesterday",
    "Shortfall ranking",
    "Includes reconstructed historical components",
    "Red markers show logged relapses",
    "Sleep / HRV",
):
    assert obsolete not in patterns_text
assert "U: protection · B: building · weights" not in widget_text
assert "bull-widget-charts-v1" in all_swift
assert "relapse" not in re.search(
    r"struct BullWidgetChartPoint.*?\n\}",
    (ROOT / "SharedFigures" / "BullFigureArtwork.swift").read_text(),
    re.S | re.I,
).group(0)

test_count = len(re.findall(r"^\s*func test", all_swift, re.M))
print(f"PASS: {len(swift_files)} Swift files parse with no syntax errors")
print("PASS: Xcode project parses; identity, signing team and SharedFigures membership are preserved")
print(f"PASS: {len(plists)} property lists/entitlements and all JSON files parse")
print("PASS: widget Info.plist defines the WidgetKit extension point")
print("PASS: 20 production figure assets retain their RGBA transparency contract")
print("PASS: all ten approved-source and integrated-artwork hashes match the Build 52 manifest")
print("PASS: six configurations use build 52; five widgets are registered")
print("PASS: BullData remains v15; four-score version is 10")
print("PASS: graph-widget payload contains no relapse field")
print(
    f"INFO: {test_count} XCTest methods across "
    f"{len(list((ROOT / 'BullTests').glob('*.swift')))} files "
    "(source-checked, not executed without Xcode)"
)
