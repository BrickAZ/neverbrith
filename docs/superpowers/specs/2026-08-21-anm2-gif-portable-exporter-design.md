# Portable ANM2 to GIF Exporter Design

**Date:** 2026-08-21
**Status:** Approved
**Target:** Windows 10/11 x64
**Product name:** ANM2 to GIF (`Anm2Gif.exe`)

## Goal

Build a portable, single-file Windows application that exports Binding of Isaac `.anm2` animations to GIF without requiring Python, FFmpeg, ImageMagick, .NET Runtime, an installer, or third-party DLLs beside the executable.

The application must:

- open a native file picker that supports selecting one or multiple `.anm2` files;
- open a native folder picker and recursively discover `.anm2` files;
- deduplicate files added through overlapping selections;
- let the user select an output directory;
- export every named animation from every accepted `.anm2`;
- preserve the input-relative directory structure;
- use a transparent background and one stable, automatically cropped canvas per animation;
- continue a batch when one file or animation fails;
- expose progress and precise errors in the GUI and in a UTF-8 report;
- ship as one self-contained `Anm2Gif.exe`.

The tool reads referenced PNG spritesheets. This asset dependency is intrinsic to ANM2 because the file stores animation metadata rather than pixel data.

## Non-goals and fidelity boundary

Version 1 does not:

- modify source ANM2 or PNG files;
- reproduce sound or animation events inside GIF;
- execute Lua, XML registration, runtime spritesheet replacement, shaders, or game code;
- merge separate player-body, costume, hair, familiar, or effect ANM2 files into one runtime composite;
- claim in-game correctness from offline export results.

The supported contract is the visual content owned by one ANM2 and its referenced PNG spritesheets. Runtime-only composition or shaders are reported as outside the format boundary rather than guessed.

GIF itself is limited to 256 palette entries and one-bit transparency. The exporter reserves a transparent palette index, uses deterministic alpha quantization for partially transparent pixels, and reports that this cannot preserve full RGBA alpha.

## Technical route

Implement a new Rust application rather than wrapping an existing editor or calling an external encoder.

- The GUI and native Windows dialogs are compiled into the executable.
- XML parsing, PNG decoding, pixel transforms, palette generation, and GIF encoding use Rust libraries linked into the binary.
- The release build statically links the supported C runtime configuration and relies only on standard Windows system APIs and graphics components.
- The application performs no network access and spawns no external process.
- Source code lives in an isolated `tools/anm2gif/` Rust project. It must not change mod gameplay files, registration XML, Lua, or source art.
- The distributable is produced as `tools/anm2gif/dist/Anm2Gif.exe`.

## User interface

Use the approved single-window queue layout.

### Empty state

- `选择文件` opens a multi-select `.anm2` file dialog.
- `选择文件夹` opens a folder dialog and recursively scans for `.anm2`.
- `清空列表` removes queued inputs without touching disk.
- `选择位置` sets the output root.
- `开始导出` stays disabled until at least one input and one output directory are valid.

### Ready state

Each queued row shows:

- file name and source-relative directory;
- number of discovered named animations;
- `就绪`, `警告`, or `失败` status.

Version 1 has fixed export rules rather than an advanced settings panel:

- export every named animation;
- transparent background;
- preserve source-relative directories;
- compute one union crop for the complete animation.

The footer reports queued ANM2 count and total animation count.

### Exporting state

- The GUI remains responsive while a bounded background worker pool performs conversion.
- The window shows total progress and the current ANM2 and animation.
- `开始导出` becomes `停止`; cancellation stops scheduling new animations, lets the active frame operation reach a safe boundary, removes temporary outputs, and preserves completed GIFs.

### Completed state

- The queue reports success, warning, failure, or skipped state per input.
- The footer reports aggregate counts.
- The user can open the selected output directory through the system shell.

## Input roots and output layout

### Multiple-file selections

For files selected together, their nearest common ancestor is the input root. When files have no useful common directory below a drive root, use a sanitized drive label as the first relative component so unrelated paths cannot collide.

### Folder selections

The selected folder is the input root. Recursive discovery preserves every directory below it.

### Deduplication

Canonicalize each selected file to an absolute Windows path and deduplicate case-insensitively for queue identity. Preserve the actual on-disk spelling in reports and output labels. This queue rule does not permit loose or guessed spritesheet resolution.

### Output shape

For each input:

```text
<output-root>\<input-relative-directory>\<anm2-stem>\<animation-name>.gif
```

Sanitize Windows-invalid characters in ANM2 stems and animation names. If sanitization creates a collision, append a stable short hash derived from the original name. Record every mapping in the report.

When existing target GIFs are detected, show one batch-level confirmation before export with overwrite, skip, and cancel actions. Never display one confirmation dialog per file.

## Asset resolution

Resolve every spritesheet path deterministically and record the winning route.

1. Interpret the path exactly relative to the ANM2 directory.
2. Interpret it exactly relative to the selected input root.
3. For a path rooted at `gfx`, walk upward from the ANM2 directory to the volume root and test each ancestor joined to the exact declared path. Use the nearest exact ancestor match and record it as the resource root. The selected input root controls output layout but does not artificially stop asset discovery.

Do not use a recursive basename search and do not silently select a similarly named PNG. Missing or ambiguous spritesheets fail the affected ANM2 with the declared path and attempted roots in the report.

Decode PNG as RGBA and reject corrupt images. Validate every crop rectangle against decoded image bounds before rendering.

## ANM2 model

The parser builds an immutable document model containing:

- `Info` values including FPS;
- spritesheet identifiers and paths;
- layer identifiers, order, spritesheet ownership, and parent/null relationships;
- animation names, frame counts, loop flags, RootAnimation, LayerAnimations, NullAnimations, delays, visibility, and interpolation flags;
- frame crop, pivot, position, scale, rotation, tint, color offset, and alpha values;
- events and sounds as reportable non-visual metadata.

Empty `LayerAnimation` and root-only animation nodes are valid input shapes. The parser must not assume that every animation or layer contains an immediate frame.

Unknown XML elements or attributes are preserved as structured warnings. Invalid references are errors rather than defaults.

## Timeline expansion

For each named animation:

1. Expand keyframes according to their Delay values onto an integer ANM2 timeline.
2. Resolve visibility and held values for gaps according to ANM2 semantics.
3. Apply interpolation only to fields defined as interpolated by the format and current frame flags.
4. Combine Root, Null, and Layer transforms in the validated parent order.
5. Convert ANM2 timeline ticks to GIF centiseconds.

GIF centiseconds cannot always express the ANM2 frame duration exactly. Use deterministic error accumulation so rounding error is distributed across frames and the complete animation duration stays as close as possible to the ANM2 duration.

- `Loop=true` writes an infinite GIF loop extension.
- `Loop=false` writes no infinite-loop extension and plays once.

## Rendering

Rendering uses two passes per animation.

### Bounds and palette pass

For each timeline frame and visible layer:

- validate and crop the source region;
- apply pivot, position, scale, flip, rotation, Root transform, and relevant Null transform;
- compute the transformed alpha-bearing bounds;
- accumulate a bounded color histogram from transformed, tinted pixels for the animation-wide GIF palette without retaining completed frames.

Union every frame bound and add a one-pixel transparent safety margin. The resulting rectangle is the fixed canvas for every frame of that animation. Empty animations produce a warning and a minimal transparent GIF rather than an invalid zero-sized file.

### Composite pass

For every timeline frame:

- crop the exact source rectangle;
- apply nearest-neighbor transforms suitable for Isaac pixel art;
- apply tint, color offset, and alpha in a documented order verified against reference output;
- composite layers in ANM2 order with straight-alpha source-over blending;
- place the result on the fixed union canvas.

After the first pass finalizes both the union canvas and global palette, frame operations stream through the encoder instead of retaining the complete rendered batch in memory.

## GIF encoding

- Build one deterministic global palette per animation to avoid palette flicker between frames.
- Reserve one palette entry for transparency.
- Quantize RGB colors consistently across all frames.
- Convert partial alpha to binary GIF transparency using deterministic ordered alpha dithering; fully transparent and fully opaque pixels stay exact.
- Preserve the computed frame delays and loop behavior.
- Write to a temporary file in the destination directory, flush and close it, then atomically replace or create the final target.

## Concurrency and resource limits

Use a bounded background worker pool capped at the smaller of four workers or the available logical CPU count. Each animation uses a bounds-and-palette prepass and streaming encode so batch memory does not scale with the total number of output frames.

GUI messages are immutable progress events sent from workers to the UI thread. Worker failures are converted into structured results; no worker may terminate the complete application.

## Error handling and reporting

Preflight each ANM2 before scheduling its animations:

- XML parse validity;
- named animation presence;
- spritesheet resolution and PNG decode;
- crop bounds;
- layer, Root, Null, and frame references;
- supported and unsupported attributes.

Failure scope is the smallest safe unit:

- a corrupt document or unresolved required spritesheet fails that ANM2;
- an animation-local invalid reference fails that animation while later animations continue when safe;
- output write failure fails only that GIF;
- cancellation prevents new work and cleans temporary files.

Write `<output-root>\anm2gif-report.txt` in UTF-8. Each record contains:

```text
ANM2 path -> animation name -> layer/null -> timeline frame -> severity -> message
```

The report also contains successful output paths, sanitized-name mappings, aggregate counts, and declared unsupported runtime features. It must not contain stack traces unless a debug build is used.

## Test strategy

### Parser tests

Use focused fixtures for:

- one and multiple spritesheets;
- empty LayerAnimation nodes;
- Root-only and Null-parented animations;
- missing, held, and interpolated frames;
- negative coordinates and pivots;
- differing Delay and Loop values;
- invalid IDs, paths, and XML.

### Renderer tests

Compare decoded RGBA frame buffers before GIF quantization for:

- crop and pivot placement;
- scale, rotation, flip, and negative coordinates;
- tint, color offset, alpha, and source-over blending;
- Root and Null transform inheritance;
- union bounds stability and transparent safety margin.

Golden comparisons use representative entity, costume, effect, and UI ANM2 files. Review each unique ANM2 crop/frame at native 1x and a 4x nearest-neighbor view on checkerboard, solid white, and a representative room-like background.

### GIF tests

Decode generated GIFs and assert:

- file validity;
- width and height;
- frame count and total duration;
- loop extension behavior;
- transparent palette index;
- deterministic palette and bytes for identical inputs;
- no partial or corrupt target after injected failure or cancellation.

### Batch tests

Cover:

- file multi-select and recursive folder discovery;
- overlapping selection deduplication;
- preservation of relative directories;
- invalid Windows filename characters and stable collisions;
- existing-output overwrite, skip, and cancel behavior;
- continued conversion after individual failures;
- report contents and UTF-8 paths.

### Portability test

Run the release executable in a clean Windows 10/11 x64 environment without Rust, Python, FFmpeg, ImageMagick, or .NET Runtime installed. Verify that:

- the GUI and native dialogs open;
- no third-party DLL is required beside the EXE;
- no external process or network access occurs;
- a representative multi-file batch exports valid GIFs.

### Reference comparison boundary

Compare representative frames and timing against the Isaac Animation Editor or Anm2Ed as offline reference evidence. Keep this separate from in-game proof. Runtime composite, shader, and dynamic replacement fidelity remains outside the version 1 completion claim.

## Acceptance criteria

The feature is accepted when:

1. One portable `Anm2Gif.exe` runs on clean Windows 10/11 x64 without installing dependencies.
2. The approved single-window UI supports multi-file selection, recursive folder selection, queue clearing, output-folder selection, progress, cancellation, and completion status.
3. All named animations from valid supported ANM2 inputs are exported with preserved relative directories.
4. Output uses a stable transparent union canvas, valid GIF timing, and ANM2 loop semantics.
5. Ordinary entity, effect, UI, and standalone costume samples pass parser, pixel, GIF, batch, and reference-comparison checks.
6. Missing assets, unsupported constructs, invalid frames, naming collisions, cancellation, and output failures are reported without aborting unrelated work.
7. Source ANM2 and PNG files remain byte-for-byte unchanged.
8. The completion report distinguishes automated/static proof, offline visual comparison, and features that still require or cannot receive in-game proof.
