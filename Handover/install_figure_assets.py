#!/usr/bin/env python3
"""Install already-prepared RGBA PNGs; never modifies their image pixels."""
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image


def install(source: Path, project: Path) -> None:
    pending = []
    for role in ("bull", "provider", "devil", "angel"):
        for stage in range(1, 6):
            name = f"bull-figure-{role}-{stage}"
            path = source / f"{name}.png"
            if not path.is_file():
                raise ValueError(f"Missing production asset: {path.name}")
            with Image.open(path) as image:
                if image.mode != "RGBA" or image.size != (512, 768):
                    raise ValueError(f"{path.name}: expected 512x768 RGBA, got {image.size} {image.mode}")
                alpha = image.getchannel("A")
                histogram = alpha.histogram()
                if histogram[0] < 512 * 768 * 0.15 or histogram[255] < 512 * 768 * 0.05:
                    raise ValueError(f"{path.name}: missing genuine transparent space or solid figure")
                bounds = alpha.getbbox()
                if bounds is None or bounds[0] < 1 or bounds[1] < 1 or bounds[2] > 511 or bounds[3] > 767:
                    raise ValueError(f"{path.name}: artwork touches the canvas edge")
            pending.append((name, path))
    catalog = project / "SharedFigures" / "Figures.xcassets"
    catalog.mkdir(parents=True, exist_ok=True)
    info = {"author": "xcode", "version": 1}
    (catalog / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
    for name, path in pending:
        imageset = catalog / f"{name}.imageset"
        imageset.mkdir(exist_ok=True)
        shutil.copyfile(path, imageset / path.name)
        metadata = {"images": [{"filename": path.name, "idiom": "universal"}],
                    "info": info, "properties": {"template-rendering-intent": "original"}}
        (imageset / "Contents.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Installed {len(pending)} validated transparent assets into {catalog}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    install(args.source.resolve(), args.project.resolve())
