#!/usr/bin/env python3
"""Static build-50 checks for environments without Xcode or an Apple SDK."""
from pathlib import Path
import json
import plistlib
import re
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
json_files = sorted(ROOT.rglob("*.json"))
for path in json_files:
    json.loads(path.read_text())

catalog = ROOT / "SharedFigures" / "Figures.xcassets"
expected = [f"bull-figure-{role}-{stage}"
            for role in ("bull", "provider", "devil", "angel")
            for stage in range(1, 6)]
images = []
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
    images.append(path)

project_text = project.read_text()
all_swift = "\n".join(path.read_text(errors="replace") for path in swift_files)
widget_text = (ROOT / "BullWidgets" / "BullWidgets.swift").read_text()
bundle = re.search(r"struct BullWidgetsBundle.*?var body: some Widget \{(.*?)\n    \}",
                   widget_text, re.S).group(1)
registered = re.findall(r"\b(?:BullFaceOffWidget|BullRoutineFiguresWidget|BullPrioritiesWidget)\(\)",
                        bundle)

assert len(re.findall(r"CURRENT_PROJECT_VERSION = 50;", project_text)) == 6
# One group definition plus root, app-target and widget-target references.
assert project_text.count("D35000000000000000000001 /* SharedFigures */") == 4
assert len(registered) == 3
assert len(set(expected)) == 20

print(f"PASS: {len(swift_files)} Swift files parse with no syntax errors")
print("PASS: Xcode project parses; SharedFigures belongs to app and widget")
print(f"PASS: {len(plists)} property lists and {len(json_files)} JSON files parse")
print("PASS: widget Info.plist defines the required WidgetKit NSExtension dictionary")
print(f"PASS: {len(images)} production RGBA assets validated ({sum(p.stat().st_size for p in images)} bytes)")
print("PASS: six configurations use build number 50; three widgets registered")
print(f"INFO: {len(re.findall(r'^\s*func test', all_swift, re.M))} XCTest methods across "
      f"{len(list((ROOT / 'BullTests').glob('*.swift')))} files (not executed without Xcode)")
