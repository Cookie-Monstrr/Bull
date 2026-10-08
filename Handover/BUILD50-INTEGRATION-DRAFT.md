# Build 50 integration draft — superseded

This checkpoint is retained only as process history. Asset preparation was
completed after explicit approval for local extraction. Use
`BUILD50-CHANGES-AND-TESTING.md` and the completed build 50 package.

---

Original draft follows.

The user approved the final twenty figure designs and requested integration into
the app and widgets. Code integration is prepared; the required twenty transparent
asset files are still missing. New art names intentionally do not fall back to
the rejected previous cast. Do not claim the new figures are installed.

## Code ready for completion

- SharedFigures/BullFigureArtwork.swift compiles into both app and widget targets.
  It defines four characters, one finite-safe score-to-stage mapping and one
  backwards-compatible App Group snapshot with all four scores.
- States/Routines switch in the Today figure card, using the displayed historical
  or current snapshot consistently with the rest of the page.
- Face Off keeps its existing widget kind with Bull State and Devil/Urge State.
- Build & Protect is a new medium widget: Provider/Bull Routine and Angel/Urge Routine.
  Tap routes to the existing privacy-gated priorities screen.
- Today's Priorities remains available. All three widget kinds reload after
  relevant updates; routine-only score changes now trigger publication.
- Missing/non-finite scores show an unavailable symbol and dash, never a weak stage.
  Finite values clamp to 0–100; stages start at 0, 20, 40, 60 and 80.
- Midnight entries blank yesterday's scores, including routine scores.
- Seven regression test methods added. No scoring formulas, data schema version,
  CloudKit permissions, historical totals or app identity changed.

## Blocking asset issue

The image-generation tool was asked to isolate each approved figure onto true
transparency. Returned PNGs instead contain a painted checkerboard and are RGB,
with no alpha channel. The batch was stopped. These rejected cutouts have NOT
been installed in the asset catalogs.

Image-generation tool instructions require explicit user permission before using
another method for image editing. Ask to use local image processing to extract
and clean the approved sheet art, preserving the original figures. Do not keep
regenerating them or substitute the checkerboard images.

## Approved source sheets

Originals are preserved in Approved-Figures beside this document:

- bull-state.png: corrected head at stage 2; armoured stages 4/5.
- bull-routine.png: Provider C, stronger outward energy stages 4/5.
- urge-state.png: final approved Devil E, unchanged in last art revision.
- urge-routine.png: Angel A with stronger defensive pose and barrier stages 4/5.

## Production asset contract

Twenty individual RGBA PNG files, named:
`bull-figure-{bull|provider|devil|angel}-{1|2|3|4|5}.png`.

Each uses a 512×768 transparent canvas, torso centre x=256, visible boot baseline
y=744. Preserve within-character scale progression; weak stages should not be
enlarged to look as mighty as the final stage. Keep horns, spear tips, feathers,
energy and capes visible with margin. For every stage check it against oxblood,
white and grey backgrounds at full and medium-widget display sizes.

Use Handover/install_figure_assets.py after twenty genuine transparent files
exist. It validates all files before writing the shared asset catalog. It only
copies ready PNGs and writes Xcode catalog metadata; it does not edit images.

## Validation so far

All Swift syntax trees parse using tree-sitter-swift. The Xcode project parses
using openstep_parser, and SharedFigures belongs to the app AND widget extension.
All six build configurations are 50. XCTest sources added but not run.
No Xcode/Swift SDK or physical Apple device is available here. Compilation,
rendering, XCTest and actual widget behaviour are unverified.

## Resume and finish

1. Obtain explicit permission for local image processing because the built-in
   generation path produced unusable transparency. Continue from approved sheets.
2. Prepare and inspect all twenty production PNGs; run the strict installer.
3. Check shared asset membership, image file sizes/alpha, references and no duplicates.
4. Run available source and package checks. Include device-test checklist for
   gallery, stacking, score boundaries, nil, midnight, privacy and historical dates.
5. Replace this draft README with a completed handover, package full project plus
   changes since build49, and save the final full project as the next version of
   library_file_id libfile_1ca31dc333848191afee083e5bfa6662 (retained current version 1).
   Never replace that last complete deliverable with this unfinished checkpoint.
6. User installs over the existing app using unchanged signing identity, never
   deleting Bull or clearing its data. No Git push or distribution before review.
