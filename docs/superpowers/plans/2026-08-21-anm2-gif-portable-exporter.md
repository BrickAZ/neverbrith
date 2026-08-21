# Portable ANM2 to GIF Exporter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a portable Windows application, `Anm2Gif.exe`, that batch-exports every named animation from selected Binding of Isaac ANM2 files to transparent GIFs.

**Architecture:** A Windows-only Rust crate separates immutable ANM2 parsing, deterministic asset resolution, timeline expansion, two-pass RGBA rendering, global-palette GIF encoding, atomic output, background batch orchestration, and a thin eframe GUI. The conversion core is a library with no GUI dependencies in its public interfaces, so parser, pixel, GIF, batch, and cancellation behavior can be tested without opening a window.

**Tech Stack:** Rust 1.85.0 MSVC, edition 2024; `quick-xml` 0.37.5; `png` 0.17.16; `gif` 0.13.1; `rayon` 1.10.0; `crossbeam-channel` 0.5.15; `eframe` 0.31.1 with the `glow` backend; `rfd` 0.15.3; `windows` 0.61.1; Rust built-in test runner.

## Global Constraints

- Target Windows 10/11 x64 and build `x86_64-pc-windows-msvc` with static CRT linkage.
- Ship exactly one runtime artifact at `tools/anm2gif/dist/Anm2Gif.exe`; do not require Python, FFmpeg, ImageMagick, .NET Runtime, an installer, or third-party DLLs beside it.
- Embed the OFL-licensed Noto Sans SC Regular font into the executable so approved Chinese UI labels render without a separately installed CJK font.
- Keep all new source under `tools/anm2gif/`; do not modify gameplay Lua, registration XML, source ANM2, or source PNG files.
- Read the PNG spritesheets referenced by each ANM2; an ANM2 alone does not contain pixels.
- Perform no network access and spawn no conversion helper process. The explicit user action “打开输出文件夹” may invoke Windows ShellExecute to open Explorer.
- Export every named animation, preserve source-relative directories, use a transparent one-bit GIF background, and use one fixed union crop per animation.
- Continue unrelated batch work after a file or animation failure; cancellation must preserve finished GIFs and remove temporary outputs.
- Write UTF-8 `anm2gif-report.txt` and keep automated/static proof, offline visual comparison, and in-game/runtime fidelity claims separate.
- GIF output uses at most 256 palette entries, reserves one transparent entry, distributes centisecond timing error deterministically, writes infinite looping only for `Loop=true`, and uses deterministic ordered alpha dithering.
- Commit `Cargo.lock`; all build and test commands use `--locked` after the initial lockfile is generated.
- No unsafe code outside the small Windows shell adapter in `src/platform/windows.rs`; document every unsafe call with its Win32 preconditions.
- Unless a step gives another working directory, run Cargo commands from `tools/anm2gif/`.

## File Map

| Path | Responsibility |
| --- | --- |
| `tools/anm2gif/Cargo.toml` | Pinned crate features, release profile, binary/library targets. |
| `tools/anm2gif/Cargo.lock` | Reproducible dependency graph. |
| `tools/anm2gif/rust-toolchain.toml` | Pinned Rust 1.85.0 MSVC toolchain. |
| `tools/anm2gif/.cargo/config.toml` | Static CRT target flag. |
| `tools/anm2gif/src/lib.rs` | Core module exports. |
| `tools/anm2gif/src/main.rs` | GUI entry point and release Windows subsystem selection. |
| `tools/anm2gif/src/model.rs` | Immutable parsed ANM2 and render-domain types. |
| `tools/anm2gif/src/diagnostic.rs` | Structured severity, location, and error records. |
| `tools/anm2gif/src/input.rs` | File/folder discovery, input roots, canonical deduplication. |
| `tools/anm2gif/src/output_path.rs` | Sanitized stable output path calculation and collision mapping. |
| `tools/anm2gif/src/parser.rs` | XML-to-model parser and unknown-field warnings. |
| `tools/anm2gif/src/assets.rs` | Exact spritesheet resolution, PNG decode, crop validation, preflight. |
| `tools/anm2gif/src/timeline.rs` | Delay expansion, held/interpolated values, hierarchy resolution, GIF timing. |
| `tools/anm2gif/src/render/geometry.rs` | Affine transforms, inverse nearest-neighbor sampling, bounds. |
| `tools/anm2gif/src/render/composite.rs` | Tint/color/alpha and straight-alpha source-over compositing. |
| `tools/anm2gif/src/render/mod.rs` | Bounds/palette pass and streaming composite pass. |
| `tools/anm2gif/src/palette.rs` | Deterministic histogram reduction, palette selection, alpha dithering. |
| `tools/anm2gif/src/gif_writer.rs` | GIF stream, delays, transparency, loop extension. |
| `tools/anm2gif/src/export.rs` | One-animation export and same-directory atomic replacement. |
| `tools/anm2gif/src/report.rs` | UTF-8 report records and aggregate summary. |
| `tools/anm2gif/src/batch.rs` | Bounded worker pool, progress messages, error isolation, cancellation. |
| `tools/anm2gif/src/gui.rs` | Queue window, dialogs, overwrite confirmation, progress states. |
| `tools/anm2gif/assets/NotoSansSC-Regular.otf` | Embedded Chinese UI glyph coverage; never shipped as a sidecar file. |
| `tools/anm2gif/src/platform/windows.rs` | ShellExecute and Windows atomic replace adapter. |
| `tools/anm2gif/tests/fixtures/` | Small synthetic XML/PNG fixtures owned by the tool tests. |
| `tools/anm2gif/tests/golden/` | Reviewed pre-quantization RGBA and reference manifests. |
| `tools/anm2gif/tests/*.rs` | Parser, path, pixel, GIF, batch, GUI-controller, and portability tests. |
| `tools/anm2gif/scripts/build-release.ps1` | Locked release build and one-file dist assembly. |
| `tools/anm2gif/scripts/verify-portable.ps1` | Dist contents, PE imports, launch, and source-integrity checks. |
| `tools/anm2gif/README.md` | User operation, limitations, build, test, and evidence boundary. |
| `tools/anm2gif/THIRD_PARTY_NOTICES.md` | Source-level dependency license notices; not a runtime DLL. |

---

### Task 1: Reproducible Rust Project and Immutable Core Types

**Files:**
- Create: `tools/anm2gif/Cargo.toml`
- Create: `tools/anm2gif/rust-toolchain.toml`
- Create: `tools/anm2gif/.cargo/config.toml`
- Create: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/src/main.rs`
- Create: `tools/anm2gif/src/model.rs`
- Create: `tools/anm2gif/src/diagnostic.rs`
- Create: `tools/anm2gif/tests/model_contract.rs`
- Create: `tools/anm2gif/Cargo.lock`

**Interfaces:**
- Produces: `Anm2Document`, `Animation`, `LayerTrack`, `TransformTrack`, `LayerFrame`, `TransformFrame`, `Transform`, `RectI`, `Vec2`, `Diagnostic`, `Severity`, and `SourceLocation`.
- Consumes: no earlier task interfaces.

- [ ] **Step 1: Install the development-only toolchain after obtaining command approval**

Run from PowerShell:

```powershell
winget install --id Rustlang.Rustup -e --scope user
rustup toolchain install 1.85.0-x86_64-pc-windows-msvc --profile minimal
rustup target add x86_64-pc-windows-msvc --toolchain 1.85.0
rustc +1.85.0 --version
```

Expected: `rustc 1.85.0`; if the MSVC linker is absent, install Visual Studio 2022 Build Tools with the “Desktop development with C++” workload before continuing. These are build-machine dependencies only and are never copied into `dist/`.

- [ ] **Step 2: Create the pinned crate configuration**

Create `Cargo.toml` with exact features:

```toml
[package]
name = "anm2gif"
version = "0.1.0"
edition = "2024"
license = "MIT"
publish = false

[lib]
name = "anm2gif"
path = "src/lib.rs"

[[bin]]
name = "Anm2Gif"
path = "src/main.rs"

[dependencies]
crossbeam-channel = "=0.5.15"
eframe = { version = "=0.31.1", default-features = false, features = ["default_fonts", "glow"] }
gif = "=0.13.1"
png = "=0.17.16"
quick-xml = "=0.37.5"
rayon = "=1.10.0"
rfd = "=0.15.3"
thiserror = "=2.0.12"
walkdir = "=2.5.0"
windows = { version = "=0.61.1", features = ["Win32_Foundation", "Win32_Storage_FileSystem", "Win32_UI_Shell", "Win32_UI_WindowsAndMessaging"] }

[dev-dependencies]
goblin = "=0.9.3"
tempfile = "=3.19.1"

[profile.release]
codegen-units = 1
lto = "fat"
opt-level = "s"
panic = "abort"
strip = "symbols"
```

Create `rust-toolchain.toml` and `.cargo/config.toml`:

```toml
[toolchain]
channel = "1.85.0"
profile = "minimal"
targets = ["x86_64-pc-windows-msvc"]
```

```toml
[target.x86_64-pc-windows-msvc]
rustflags = ["-C", "target-feature=+crt-static"]
```

- [ ] **Step 3: Write the failing model contract test**

```rust
use anm2gif::diagnostic::{Diagnostic, Severity, SourceLocation};
use anm2gif::model::{RectI, Transform, Vec2};

#[test]
fn defaults_are_identity_and_diagnostics_keep_location() {
    let t = Transform::default();
    assert_eq!(t.position, Vec2::ZERO);
    assert_eq!(t.scale, Vec2::new(1.0, 1.0));
    assert_eq!(t.alpha, 1.0);
    assert_eq!(RectI::new(1, 2, 3, 4).right(), 4);

    let d = Diagnostic::new(
        Severity::Error,
        "invalid layer reference",
        SourceLocation::animation("Idle").with_layer(7).with_tick(12),
    );
    assert_eq!(d.location.animation.as_deref(), Some("Idle"));
    assert_eq!(d.location.layer_or_null, Some(7));
    assert_eq!(d.location.tick, Some(12));
}
```

- [ ] **Step 4: Run the test and verify the missing-module failure**

Run: `cargo test --test model_contract`

Expected: FAIL because `anm2gif::model` and `anm2gif::diagnostic` do not exist.

- [ ] **Step 5: Implement the minimal complete domain types**

Define immutable public records with these exact shapes; all collections use source order unless their field is explicitly a map:

```rust
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Vec2 { pub x: f32, pub y: f32 }
impl Vec2 { pub const ZERO: Self = Self { x: 0.0, y: 0.0 }; pub const fn new(x: f32, y: f32) -> Self { Self { x, y } } }

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RectI { pub x: i32, pub y: i32, pub width: u32, pub height: u32 }
impl RectI {
    pub const fn new(x: i32, y: i32, width: u32, height: u32) -> Self { Self { x, y, width, height } }
    pub fn right(self) -> i32 { self.x + self.width as i32 }
    pub fn bottom(self) -> i32 { self.y + self.height as i32 }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Transform {
    pub pivot: Vec2,
    pub position: Vec2,
    pub scale: Vec2,
    pub rotation_deg: f32,
    pub tint: [f32; 3],
    pub color_offset: [i16; 3],
    pub alpha: f32,
    pub visible: bool,
    pub interpolate: bool,
}
impl Default for Transform {
    fn default() -> Self {
        Self { pivot: Vec2::ZERO, position: Vec2::ZERO, scale: Vec2::new(1.0, 1.0), rotation_deg: 0.0, tint: [1.0; 3], color_offset: [0; 3], alpha: 1.0, visible: true, interpolate: false }
    }
}
```

Add `SpriteSheet { id, declared_path }`, `LayerDef { id, sheet_id, parent_null_id }`, `LayerFrame { delay, crop, transform }`, `TransformFrame { delay, transform }`, ordered `LayerTrack`, `TransformTrack`, `Animation { name, frame_count, looped, root, layers, nulls, events, sounds }`, and `Anm2Document { source, fps, sheets, layer_defs, animations, warnings }`. Implement `Diagnostic::new`, `SourceLocation::animation`, `with_layer`, and `with_tick` exactly as used by the test. Export every module from `lib.rs`; keep `main.rs` as a compiling `fn main() {}` with the release-only `windows_subsystem = "windows"` attribute.

- [ ] **Step 6: Generate the lockfile and verify the baseline**

Run:

```powershell
cargo generate-lockfile
cargo fmt --check
cargo test --locked --test model_contract
cargo clippy --locked --all-targets -- -D warnings
```

Expected: all commands exit 0 and the test reports `1 passed`.

- [ ] **Step 7: Commit the isolated foundation**

```powershell
git add tools/anm2gif/Cargo.toml tools/anm2gif/Cargo.lock tools/anm2gif/rust-toolchain.toml tools/anm2gif/.cargo tools/anm2gif/src tools/anm2gif/tests/model_contract.rs
git commit -m "build: scaffold portable anm2 gif exporter"
```

### Task 2: Input Discovery, Deduplication, and Stable Output Paths

**Files:**
- Create: `tools/anm2gif/src/input.rs`
- Create: `tools/anm2gif/src/output_path.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/input_paths.rs`

**Interfaces:**
- Produces: `QueueBuilder::add_files`, `QueueBuilder::add_folder`, `QueuedInput`, `sanitize_component`, and `OutputPlanner::path_for`.
- Consumes: `Diagnostic`, `Severity` from Task 1.

- [ ] **Step 1: Write failing tests for roots, recursion, deduplication, and collisions**

```rust
#[test]
fn file_selection_uses_common_root_and_deduplicates_case_insensitively() {
    let root = fixture_tree();
    let a = root.join("pack/a/one.anm2");
    let b = root.join("pack/b/two.anm2");
    let mut q = QueueBuilder::new();
    q.add_files(vec![a.clone(), b.clone(), a]);
    assert_eq!(q.items().len(), 2);
    assert_eq!(q.items()[0].input_root, root.join("pack"));
}

#[test]
fn sanitized_name_collisions_receive_stable_hashes() {
    let mut planner = OutputPlanner::new(PathBuf::from("out"));
    let first = planner.path_for(Path::new("a.anm2"), Path::new(""), "A:B");
    let second = planner.path_for(Path::new("a.anm2"), Path::new(""), "A?B");
    assert_ne!(first, second);
    assert!(second.to_string_lossy().contains("A_B-"));
}
```

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test input_paths`

Expected: FAIL with unresolved imports for `QueueBuilder` and `OutputPlanner`.

- [ ] **Step 3: Implement discovery and queue identity**

Use these exact public records and behavior:

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct QueuedInput {
    pub path: PathBuf,
    pub input_root: PathBuf,
    pub relative_dir: PathBuf,
}

pub struct QueueBuilder {
    items: Vec<QueuedInput>,
    identities: HashSet<String>,
}

fn windows_identity(path: &Path) -> io::Result<(PathBuf, String)> {
    let canonical = path.canonicalize()?;
    let identity = canonical.as_os_str().to_string_lossy().to_lowercase();
    Ok((canonical, identity))
}
```

`add_files` filters extensions with `eq_ignore_ascii_case("anm2")`, computes the nearest common ancestor for that selection, gives drive-root-only groups a sanitized drive component, and retains the first queue entry when later selections overlap. `add_folder` uses `WalkDir` recursively, sorts canonical paths case-insensitively before insertion, and uses the selected folder as `input_root`.

- [ ] **Step 4: Implement deterministic output naming**

```rust
pub fn sanitize_component(original: &str) -> String {
    let mut s: String = original.chars().map(|c| {
        if c < '\u{20}' || matches!(c, '<' | '>' | ':' | '"' | '/' | '\\' | '|' | '?' | '*') { '_' } else { c }
    }).collect();
    while s.ends_with([' ', '.']) { s.pop(); }
    if s.is_empty() || is_reserved_windows_name(&s) { s = format!("_{s}"); }
    s
}

fn stable_short_hash(value: &str) -> String {
    let mut hash = 0xcbf29ce484222325u64;
    for byte in value.as_bytes() { hash ^= u64::from(*byte); hash = hash.wrapping_mul(0x100000001b3); }
    format!("{:08x}", hash as u32)
}
```

`OutputPlanner::path_for` returns `<root>/<relative>/<sanitized-stem>/<sanitized-animation>.gif`; it tracks case-insensitive final paths and appends `-<hash>` before `.gif` only when two originals map to the same path. It also returns a `NameMapping` record for every changed name.

- [ ] **Step 5: Run path tests and commit**

Run: `cargo fmt && cargo test --locked --test input_paths && cargo clippy --locked --all-targets -- -D warnings`

Expected: all pass; recursive output order is stable across two runs.

```powershell
git add tools/anm2gif/src tools/anm2gif/tests/input_paths.rs
git commit -m "feat: add deterministic batch input paths"
```

### Task 3: Strict ANM2 XML Parser and Structured Diagnostics

**Files:**
- Create: `tools/anm2gif/src/parser.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/parser.rs`
- Create: `tools/anm2gif/tests/fixtures/parser/minimal.anm2`
- Create: `tools/anm2gif/tests/fixtures/parser/empty-layer-root-null.anm2`
- Create: `tools/anm2gif/tests/fixtures/parser/invalid-reference.anm2`

**Interfaces:**
- Produces: `parse_anm2(path: &Path) -> Result<Anm2Document, ParseFailure>` and `ParseFailure`.
- Consumes: all Task 1 model and diagnostic types.

- [ ] **Step 1: Add focused XML fixtures and failing parser tests**

The minimal fixture must be literal, small, and independent of mod assets:

```xml
<AnimatedActor>
  <Info CreatedBy="anm2gif-test" Version="1" Fps="30"/>
  <Content>
    <Spritesheets><Spritesheet Path="sheet.png" Id="0"/></Spritesheets>
    <Layers><Layer Name="body" Id="0" SpritesheetId="0"/></Layers>
    <Nulls><Null Name="anchor" Id="3"/></Nulls>
  </Content>
  <Animations DefaultAnimation="Idle">
    <Animation Name="Idle" FrameNum="3" Loop="true">
      <RootAnimation><Frame XPosition="0" YPosition="0" Delay="3"/></RootAnimation>
      <LayerAnimations><LayerAnimation LayerId="0" Visible="true"><Frame XCrop="0" YCrop="0" Width="2" Height="2" XPivot="1" YPivot="1" Delay="3"/></LayerAnimation></LayerAnimations>
      <NullAnimations><NullAnimation NullId="3"><Frame XPosition="1" YPosition="2" Delay="3"/></NullAnimation></NullAnimations>
    </Animation>
  </Animations>
</AnimatedActor>
```

Test FPS, loop, ordered layers, empty `LayerAnimation`, root-only animation, negative coordinates, Delay, visibility, interpolation flags, unknown-attribute warnings, and invalid ID errors. Assert exact diagnostic location fields, not just message text.

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test parser`

Expected: FAIL because `parse_anm2` is missing.

- [ ] **Step 3: Implement the streaming parser**

Use `quick_xml::Reader`, `trim_text(true)`, an explicit element stack, and these helpers:

```rust
pub fn parse_anm2(path: &Path) -> Result<Anm2Document, ParseFailure> {
    let bytes = std::fs::read(path).map_err(ParseFailure::Io)?;
    parse_bytes(path, &bytes)
}

fn required<T: FromStr>(node: &BytesStart<'_>, key: &[u8], at: &SourceLocation) -> Result<T, ParseFailure>
where T::Err: Display;

fn optional<T: FromStr>(node: &BytesStart<'_>, key: &[u8], default: T, at: &SourceLocation) -> Result<T, ParseFailure>
where T::Err: Display;

fn warn_unknown_attributes(node: &BytesStart<'_>, allowed: &[&[u8]], at: &SourceLocation, warnings: &mut Vec<Diagnostic>);
```

Match every supported `Info`, `Spritesheet`, `Layer`, `Null`, `Animation`, `RootAnimation`, `LayerAnimation`, `NullAnimation`, `Frame`, `Event`, and `Sound` element. Preserve unknown elements and attributes as warnings containing their XML names. Reject duplicate IDs, zero FPS, missing animation names, missing layer/sheet/null references, negative Delay, and non-finite transform values. Accept empty tracks and root-only animations without synthesizing frames.

- [ ] **Step 4: Add a parser invariant pass**

After XML construction, call:

```rust
fn validate_document(document: &Anm2Document) -> Result<(), ParseFailure> {
    let sheet_ids: HashSet<u32> = document.sheets.iter().map(|s| s.id).collect();
    let layer_ids: HashSet<u32> = document.layer_defs.iter().map(|l| l.id).collect();
    for layer in &document.layer_defs {
        if !sheet_ids.contains(&layer.sheet_id) { return Err(ParseFailure::reference("spritesheet", layer.sheet_id)); }
    }
    for animation in &document.animations {
        for track in &animation.layers {
            if !layer_ids.contains(&track.layer_id) { return Err(ParseFailure::reference("layer", track.layer_id)); }
        }
    }
    Ok(())
}
```

Extend it for Null parents, frame counts, and duplicate animation names. Invalid references are errors; no guessed default IDs are allowed.

- [ ] **Step 5: Verify and commit**

Run: `cargo fmt && cargo test --locked --test parser && cargo test --locked && cargo clippy --locked --all-targets -- -D warnings`

Expected: all parser fixtures pass and malformed XML returns a structured error without panic.

```powershell
git add tools/anm2gif/src tools/anm2gif/tests/parser.rs tools/anm2gif/tests/fixtures/parser
git commit -m "feat: parse anm2 into validated document model"
```

### Task 4: Exact Spritesheet Resolution, PNG Decode, and Preflight

**Files:**
- Create: `tools/anm2gif/src/assets.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/assets.rs`
- Create: `tools/anm2gif/tests/fixtures/assets/valid.png`
- Create: `tools/anm2gif/tests/fixtures/assets/corrupt.png`

**Interfaces:**
- Produces: `resolve_sheet`, `decode_png_rgba`, `preflight_document`, `ResolvedSheet`, `DecodedSheet`, `PreparedDocument`, and `AssetError`.
- Consumes: `Anm2Document`, `QueuedInput`, `RectI`, `Diagnostic`.

- [ ] **Step 1: Write failing resolution and crop tests**

Cover exact ANM2-relative path, exact input-root-relative path, nearest ancestor `gfx` root, missing asset with attempted-root list, corrupt PNG, and crop overflow. Include two same-basename files in different directories and assert no recursive basename fallback occurs.

```rust
#[test]
fn gfx_resolution_uses_nearest_exact_ancestor() {
    let tree = gfx_tree_with_two_candidates();
    let resolved = resolve_sheet(&tree.anm2, &tree.input_root, Path::new("gfx/effects/sheet.png")).unwrap();
    assert_eq!(resolved, tree.nearest_candidate);
}

#[test]
fn crop_must_fit_decoded_rgba() {
    let image = DecodedSheet::solid(4, 4, [255, 0, 0, 255]);
    assert!(image.validate_crop(RectI::new(3, 3, 2, 2)).is_err());
}
```

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test assets`

Expected: FAIL with unresolved `assets` interfaces.

- [ ] **Step 3: Implement deterministic resolution and RGBA decode**

```rust
pub fn resolve_sheet(anm2: &Path, input_root: &Path, declared: &Path) -> Result<ResolvedSheet, AssetError> {
    let mut attempts = Vec::new();
    attempts.push(anm2.parent().unwrap_or(Path::new("")).join(declared));
    attempts.push(input_root.join(declared));
    if declared.components().next().is_some_and(|c| c.as_os_str().to_string_lossy().eq_ignore_ascii_case("gfx")) {
        let mut cursor = anm2.parent();
        while let Some(dir) = cursor { attempts.push(dir.join(declared)); cursor = dir.parent(); }
    }
    dedupe_attempts(&mut attempts);
    let matches: Vec<PathBuf> = attempts.iter().filter(|p| p.is_file()).cloned().collect();
    select_nearest_exact(matches, attempts)
}
```

`select_nearest_exact` gives precedence to rules 1, 2, then the nearest ancestor from rule 3. It reports all attempted paths when none exist and reports ambiguity only when the same precedence level produces more than one canonical target. `decode_png_rgba` uses `png::Decoder`, expands palette/grayscale formats to 8-bit RGBA, rejects malformed data, and returns `{ width, height, pixels }` with exactly `width * height * 4` bytes.

- [ ] **Step 4: Implement document preflight**

`preflight_document(document, input_root)` resolves and decodes every referenced sheet once into a `BTreeMap<u32, Arc<DecodedSheet>>`, validates every layer crop against the owning sheet, validates all references again at animation scope, and returns per-animation errors separately from document-fatal errors. Events, sounds, unknown supported-safe fields, and runtime-only features become warnings.

- [ ] **Step 5: Verify and commit**

Run: `cargo fmt && cargo test --locked --test assets && cargo test --locked && cargo clippy --locked --all-targets -- -D warnings`

Expected: exact path order is asserted; corrupt PNG and out-of-bounds crop fail without panic.

```powershell
git add tools/anm2gif/src tools/anm2gif/tests/assets.rs tools/anm2gif/tests/fixtures/assets
git commit -m "feat: resolve and preflight anm2 spritesheets"
```

### Task 5: Timeline Expansion, Interpolation, Hierarchy, and GIF Delays

**Files:**
- Create: `tools/anm2gif/src/timeline.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/timeline.rs`

**Interfaces:**
- Produces: `expand_animation(document, animation) -> Result<Vec<TimelineFrame>, TimelineError>`, `TimelineFrame`, `TimelineError`, `TimingResult`, and `gif_delays(fps, frame_count) -> Result<TimingResult, TimelineError>`.
- Consumes: parsed tracks and transforms from Task 1/3.

- [ ] **Step 1: Write failing table-driven timeline tests**

```rust
#[test]
fn thirty_fps_distributes_centisecond_error() {
    let result = gif_delays(30, 6).unwrap();
    assert_eq!(result.delays_cs, vec![3, 3, 4, 3, 3, 4]);
    assert_eq!(result.total_cs(), 20);
}

#[test]
fn delay_holds_then_interpolates_only_when_flagged() {
    let animation = fixture_animation_with_delays();
    let frames = expand_animation(&fixture_document(), &animation).unwrap();
    assert_eq!(frames.len(), animation.frame_count as usize);
    assert_eq!(frames[1].layers[0].transform.position.x, 0.0);
    assert_eq!(frames[2].layers[0].transform.position.x, 5.0);
}
```

Also cover missing immediate frames, empty tracks, visibility holds, shortest-angle rotation interpolation, scale/position/pivot/tint/alpha interpolation, Root plus Null parent chains, parent cycles, `Loop=true`, `Loop=false`, and FPS above 100 producing a duration warning while clamping each GIF delay to at least one centisecond.

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test timeline`

Expected: FAIL with missing timeline functions.

- [ ] **Step 3: Implement deterministic track sampling**

```rust
fn sample_track<T: Clone>(frames: &[Keyframe<T>], tick: u32, lerp: impl Fn(&T, &T, f32) -> T) -> Option<T> {
    let (current_index, local_tick) = locate_keyframe(frames, tick)?;
    let current = &frames[current_index];
    let next = frames.get(current_index + 1);
    if current.interpolate && current.delay > 0 {
        if let Some(next) = next {
            return Some(lerp(&current.value, &next.value, local_tick as f32 / current.delay as f32));
        }
    }
    Some(current.value.clone())
}
```

Build each integer timeline tick in source layer order. Missing tracks remain invisible; a gap after a keyframe holds that keyframe. Detect Null parent cycles with a visiting/visited depth-first traversal before producing any frames. Compose hierarchy records but leave pixel matrices to Task 6.

- [ ] **Step 4: Implement centisecond error accumulation**

```rust
pub fn gif_delays(fps: u32, frame_count: u32) -> Result<TimingResult, TimelineError> {
    if fps == 0 { return Err(TimelineError::ZeroFps); }
    let mut remainder = 0u64;
    let mut delays = Vec::with_capacity(frame_count as usize);
    let mut clamped = false;
    for _ in 0..frame_count {
        remainder += 100;
        let raw = remainder / u64::from(fps);
        remainder %= u64::from(fps);
        if raw == 0 { clamped = true; delays.push(1); } else { delays.push(raw.min(u64::from(u16::MAX)) as u16); }
    }
    Ok(TimingResult { delays_cs: delays, duration_warning: clamped })
}
```

- [ ] **Step 5: Verify and commit**

Run: `cargo fmt && cargo test --locked --test timeline && cargo test --locked && cargo clippy --locked --all-targets -- -D warnings`

Expected: the 30 FPS sequence is exactly `3,3,4`; hierarchy cycles return a structured error.

```powershell
git add tools/anm2gif/src tools/anm2gif/tests/timeline.rs
git commit -m "feat: expand anm2 timelines deterministically"
```

### Task 6: Two-Pass RGBA Renderer and Transform Reference Contract

**Files:**
- Create: `tools/anm2gif/src/render/mod.rs`
- Create: `tools/anm2gif/src/render/geometry.rs`
- Create: `tools/anm2gif/src/render/composite.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/render_geometry.rs`
- Create: `tools/anm2gif/tests/render_pixels.rs`
- Create: `tools/anm2gif/tests/fixtures/render/transform-contract.anm2`
- Create: `tools/anm2gif/tests/fixtures/render/transform-contract.png`
- Create: `tools/anm2gif/tests/golden/transform-contract.json`

**Interfaces:**
- Produces: `Renderer::analyze`, `Renderer::render_frame`, `RenderAnalysis`, `RgbaFrame`, `Affine2`, `source_over`.
- Consumes: `PreparedDocument`, `TimelineFrame`, decoded sheets.

- [ ] **Step 1: Establish the offline transform oracle before implementation**

Create a 3x3 test atlas with nine distinct opaque colors and an ANM2 containing separate named animations for pivot, translation, negative scale flip, 90-degree rotation, Root transform, Null-parent transform, tint, color offset, alpha, and two-layer overlap. Export each animation from Isaac Animation Editor or Anm2Ed to the exact PNG names below and record the tool/version in `transform-contract.json`:

```json
{
  "reference_tool": "Isaac Animation Editor",
  "reference_exports": {
    "Pivot": "reference/Pivot.png",
    "RootNullLayer": "reference/RootNullLayer.png",
    "TintOffsetAlpha": "reference/TintOffsetAlpha.png"
  }
}
```

Decode the committed reference PNGs to RGBA in the tests and compare their dimensions and complete pixel buffers; compute SHA-256 only for the human-readable test failure message. Do not commit the manifest unless all three referenced files exist and have been visually reviewed. If the reference editor produces a background, extract the sprite alpha bounds into a transparent PNG before committing it.

- [ ] **Step 2: Write failing geometry and pixel tests against explicit oracle pixels**

```rust
#[test]
fn source_over_uses_straight_alpha() {
    let mut dst = [0, 0, 255, 255];
    source_over(&mut dst, [255, 0, 0, 128]);
    assert_eq!(dst, [128, 0, 127, 255]);
}

#[test]
fn union_canvas_is_stable_and_has_one_pixel_margin() {
    let frames = render_fixture("Pivot");
    let analysis = Renderer::analyze(&frames).unwrap();
    assert_eq!(analysis.canvas, RectI::new(-2, -2, 5, 5));
    assert!(frames.iter().all(|f| f.width == 5 && f.height == 5));
}
```

Add exact assertions for rotation, flip, negative coordinates, Root/Null inheritance, layer order, tint/offset/alpha, fully transparent frames, and native 1x pixel hashes.

- [ ] **Step 3: Run and verify failure**

Run: `cargo test --locked --test render_geometry --test render_pixels`

Expected: FAIL because renderer modules are missing.

- [ ] **Step 4: Implement affine geometry and bounds**

```rust
impl Affine2 {
    pub fn layer(transform: Transform) -> Self {
        Self::translation(transform.position)
            * Self::rotation_degrees(transform.rotation_deg)
            * Self::scale(transform.scale)
            * Self::translation(Vec2::new(-transform.pivot.x, -transform.pivot.y))
    }
    pub fn transform_point(self, p: Vec2) -> Vec2 {
        Vec2::new(self.m11 * p.x + self.m21 * p.y + self.tx, self.m12 * p.x + self.m22 * p.y + self.ty)
    }
}
```

Compose `root * null_parent_chain * layer`. Compute bounds from transformed crop corners, then scan inverse-mapped nearest-neighbor pixels and shrink to actual alpha-bearing pixels. `Renderer::analyze` unions all frame bounds, adds exactly one transparent pixel on every side, and returns a 1x1 transparent canvas with a warning when the animation is empty.

- [ ] **Step 5: Implement color and straight-alpha compositing**

```rust
pub fn apply_color(mut px: [u8; 4], transform: Transform) -> [u8; 4] {
    for channel in 0..3 {
        let value = f32::from(px[channel]) * transform.tint[channel] + f32::from(transform.color_offset[channel]);
        px[channel] = value.round().clamp(0.0, 255.0) as u8;
    }
    px[3] = (f32::from(px[3]) * transform.alpha).round().clamp(0.0, 255.0) as u8;
    px
}

pub fn source_over(dst: &mut [u8; 4], src: [u8; 4]) {
    let sa = u32::from(src[3]);
    let da = u32::from(dst[3]);
    let out_a = sa + (da * (255 - sa) + 127) / 255;
    if out_a == 0 { *dst = [0; 4]; return; }
    for c in 0..3 {
        let premul = u32::from(src[c]) * sa + (u32::from(dst[c]) * da * (255 - sa) + 127) / 255;
        dst[c] = ((premul + out_a / 2) / out_a).min(255) as u8;
    }
    dst[3] = out_a.min(255) as u8;
}
```

Render layers strictly in ANM2 order on the fixed union canvas. If the offline oracle disproves a transform or color order, update both the named contract test and implementation in this task and record the reference evidence; do not weaken or delete the assertion.

- [ ] **Step 6: Verify reference hashes and commit**

Run: `cargo fmt && cargo test --locked --test render_geometry --test render_pixels && cargo clippy --locked --all-targets -- -D warnings`

Expected: all exact RGBA hashes match the reviewed offline reference.

```powershell
git add tools/anm2gif/src/render tools/anm2gif/src/lib.rs tools/anm2gif/tests/render_geometry.rs tools/anm2gif/tests/render_pixels.rs tools/anm2gif/tests/fixtures/render tools/anm2gif/tests/golden/transform-contract.json
git commit -m "feat: render anm2 frames to stable rgba canvases"
```

### Task 7: Deterministic Global Palette and Streaming GIF Encoder

**Files:**
- Create: `tools/anm2gif/src/palette.rs`
- Create: `tools/anm2gif/src/gif_writer.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/gif_output.rs`

**Interfaces:**
- Produces: `ColorHistogram`, `GlobalPalette::build`, `GlobalPalette::index_frame`, `GifError`, and `write_gif`.
- Consumes: `RenderAnalysis`, `RgbaFrame`, `TimingResult`, loop flag.

- [ ] **Step 1: Write failing deterministic GIF tests**

Decode generated bytes with `gif::DecodeOptions` and assert width, height, frame count, delays, transparent index 0, global palette presence, identical bytes on repeated exports, and loop behavior. Add a 50%-alpha checker test that asserts ordered dithering is stable by `(x, y, frame_index)`.

```rust
#[test]
fn loop_extension_matches_anm2_flag() {
    let looping = encode_fixture(true);
    let once = encode_fixture(false);
    assert_eq!(decode_repeat(&looping), Some(gif::Repeat::Infinite));
    assert_eq!(decode_repeat(&once), None);
}

#[test]
fn identical_inputs_produce_identical_bytes() {
    assert_eq!(encode_fixture(true), encode_fixture(true));
}
```

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test gif_output`

Expected: FAIL with missing palette/GIF interfaces.

- [ ] **Step 3: Implement the bounds-and-palette prepass**

`ColorHistogram` reduces RGB to 5 bits per channel for a bounded 32,768-bin count array. `GlobalPalette::build` reserves index 0 for transparency, sorts populated bins by count descending then RGB ascending, and deterministically splits color boxes along the channel with the largest range until there are at most 255 opaque colors. Each box emits its count-weighted average RGB. Empty input emits `[0,0,0]` only at transparent index 0.

```rust
const BAYER_4X4: [[u8; 4]; 4] = [[0,8,2,10], [12,4,14,6], [3,11,1,9], [15,7,13,5]];

fn keep_partial_alpha(alpha: u8, x: u32, y: u32, frame_index: u32) -> bool {
    let threshold = BAYER_4X4[((y + frame_index) & 3) as usize][(x & 3) as usize] * 16 + 8;
    alpha > threshold
}
```

Fully transparent pixels always map to 0; fully opaque pixels never map to 0. For retained pixels, choose the nearest palette RGB by squared Euclidean distance with the lower palette index as the tie-breaker.

- [ ] **Step 4: Implement streaming GIF output**

```rust
pub fn write_gif<W, F>(
    out: W,
    width: u16,
    height: u16,
    palette: &GlobalPalette,
    delays: &[u16],
    looped: bool,
    mut indexed_frame: F,
) -> Result<(), GifError>
where
    W: Write,
    F: FnMut(usize) -> Result<Vec<u8>, GifError>,
{
    let mut encoder = gif::Encoder::new(out, width, height, palette.bytes())?;
    if looped { encoder.set_repeat(gif::Repeat::Infinite)?; }
    for (index, delay) in delays.iter().copied().enumerate() {
        let mut frame = gif::Frame::default();
        frame.width = width;
        frame.height = height;
        frame.delay = delay;
        frame.transparent = Some(0);
        frame.buffer = Cow::Owned(indexed_frame(index)?);
        encoder.write_frame(&frame)?;
    }
    Ok(())
}
```

Use the animation-wide palette from the first pass and render/index one frame at a time in the second pass. Reject dimensions above `u16::MAX` with an animation-scoped error.

- [ ] **Step 5: Verify and commit**

Run: `cargo fmt && cargo test --locked --test gif_output && cargo test --locked && cargo clippy --locked --all-targets -- -D warnings`

Expected: deterministic byte comparison passes and `Loop=false` has no infinite Netscape extension.

```powershell
git add tools/anm2gif/src tools/anm2gif/tests/gif_output.rs
git commit -m "feat: encode deterministic transparent gifs"
```

### Task 8: Atomic Animation Export and UTF-8 Report

**Files:**
- Create: `tools/anm2gif/src/export.rs`
- Create: `tools/anm2gif/src/report.rs`
- Create: `tools/anm2gif/src/platform/mod.rs`
- Create: `tools/anm2gif/src/platform/windows.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/export_atomic.rs`
- Create: `tools/anm2gif/tests/report.rs`

**Interfaces:**
- Produces: `export_animation`, `AtomicOutput`, `ReportWriter`, `ReportRecord`, `ExportResult`.
- Consumes: parser, assets, timeline, renderer, palette, GIF, and output path interfaces.

- [ ] **Step 1: Write failing atomicity and report tests**

Inject an encoder closure that fails after one frame and assert the old target remains byte-for-byte unchanged and no `.anm2gif-*.tmp` survives. Test successful replace, first-time create, cancellation, UTF-8 Chinese paths, exact record order, sanitized mappings, and aggregate counts.

```rust
#[test]
fn failed_encode_preserves_existing_target() {
    let dir = tempfile::tempdir().unwrap();
    let target = dir.path().join("动画.gif");
    fs::write(&target, b"old").unwrap();
    let result = export_with_injected_failure(&target);
    assert!(result.is_err());
    assert_eq!(fs::read(&target).unwrap(), b"old");
    assert!(temp_outputs(dir.path()).is_empty());
}
```

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test export_atomic --test report`

Expected: FAIL with missing export/report types.

- [ ] **Step 3: Implement same-directory atomic output**

`AtomicOutput::new` creates `<target-name>.anm2gif-<process>-<counter>.tmp` in the final directory using `create_new(true)`. `commit` calls `sync_all`, closes the handle, then invokes Windows `MoveFileExW` with `MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH`. `Drop` removes an uncommitted temp file. Convert paths to NUL-terminated UTF-16 and reject embedded NULs before the unsafe call.

```rust
pub fn atomic_replace(temp: &Path, target: &Path) -> io::Result<()> {
    let from = wide_nul(temp)?;
    let to = wide_nul(target)?;
    unsafe {
        MoveFileExW(PCWSTR(from.as_ptr()), PCWSTR(to.as_ptr()), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)
            .map_err(io::Error::from)
    }
}
```

- [ ] **Step 4: Implement stable UTF-8 reporting**

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReportRecord {
    pub anm2_path: PathBuf,
    pub animation: Option<String>,
    pub layer_or_null: Option<u32>,
    pub tick: Option<u32>,
    pub severity: Severity,
    pub message: String,
}
```

Sort records by queue index, animation source order, tick, layer/null, then insertion index. Write without BOM as `ANM2 path -> animation name -> layer/null -> timeline frame -> severity -> message`, followed by successful outputs, every name mapping, unsupported runtime features, and aggregate success/warning/failure/skipped/cancelled counts.

- [ ] **Step 5: Verify and commit**

Run: `cargo fmt && cargo test --locked --test export_atomic --test report && cargo test --locked && cargo clippy --locked --all-targets -- -D warnings`

Expected: injected failure leaves the old target intact; the report decodes as UTF-8 and contains no debug stack trace.

```powershell
git add tools/anm2gif/src tools/anm2gif/tests/export_atomic.rs tools/anm2gif/tests/report.rs
git commit -m "feat: write gifs atomically with utf8 reports"
```

### Task 9: Bounded Batch Coordinator, Progress, Existing Outputs, and Cancellation

**Files:**
- Create: `tools/anm2gif/src/batch.rs`
- Modify: `tools/anm2gif/src/lib.rs`
- Create: `tools/anm2gif/tests/batch.rs`

**Interfaces:**
- Produces: `BatchPlan::preflight`, `BatchRunner::start`, `CancellationToken`, `ProgressEvent`, `ExistingOutputPolicy`, `BatchSummary`.
- Consumes: Tasks 2–8 conversion core.

- [ ] **Step 1: Write failing batch isolation tests**

Cover four-worker cap, one corrupt ANM2 among valid inputs, one animation-local failure, overwrite/skip/cancel policy, duplicate selections, no new scheduling after cancellation, finished-output preservation, temp cleanup, and immutable ordered progress messages.

```rust
#[test]
fn failure_does_not_abort_unrelated_animations() {
    let plan = mixed_valid_invalid_plan();
    let summary = run_for_test(plan, ExistingOutputPolicy::Overwrite, CancellationToken::new());
    assert_eq!(summary.succeeded, 2);
    assert_eq!(summary.failed, 1);
    assert!(summary.report_written);
}

#[test]
fn worker_count_is_bounded() {
    assert_eq!(worker_count_for(1), 1);
    assert_eq!(worker_count_for(4), 4);
    assert_eq!(worker_count_for(64), 4);
}
```

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test batch`

Expected: FAIL with unresolved batch interfaces.

- [ ] **Step 3: Implement preflight and one-time overwrite policy**

`BatchPlan::preflight` parses every queue item, resolves assets, counts named animations, calculates every output path, and returns `existing_outputs: Vec<PathBuf>`. The GUI must choose one `ExistingOutputPolicy::{Overwrite, Skip, CancelBatch}` before `BatchRunner::start`; workers never display dialogs.

- [ ] **Step 4: Implement bounded workers and cancellation**

```rust
pub fn worker_count_for(logical_cpus: usize) -> usize { logical_cpus.clamp(1, 4) }

#[derive(Clone, Default)]
pub struct CancellationToken(Arc<AtomicBool>);
impl CancellationToken {
    pub fn new() -> Self { Self::default() }
    pub fn cancel(&self) { self.0.store(true, Ordering::Release); }
    pub fn is_cancelled(&self) -> bool { self.0.load(Ordering::Acquire) }
}
```

Build one local Rayon pool with `ThreadPoolBuilder::num_threads(worker_count_for(available_parallelism))`. Check cancellation before scheduling each animation and at the safe boundary between rendered frames. Send `ProgressEvent::{InputReady, AnimationStarted, FrameCompleted, AnimationFinished, InputFinished, BatchFinished}` through a cloned crossbeam sender. Catch task errors as `ExportResult`; do not panic or terminate the process.

- [ ] **Step 5: Verify and commit**

Run: `cargo fmt && cargo test --locked --test batch -- --test-threads=1 && cargo test --locked && cargo clippy --locked --all-targets -- -D warnings`

Expected: all isolation/cancellation tests pass repeatedly; no test leaves temp files.

```powershell
git add tools/anm2gif/src tools/anm2gif/tests/batch.rs
git commit -m "feat: coordinate resilient cancellable batch exports"
```

### Task 10: Single-Window Queue GUI and Native Dialogs

**Files:**
- Create: `tools/anm2gif/src/gui.rs`
- Modify: `tools/anm2gif/src/main.rs`
- Modify: `tools/anm2gif/src/platform/windows.rs`
- Create: `tools/anm2gif/tests/gui_state.rs`

**Interfaces:**
- Produces: `AppController`, `AppState::{Empty, Ready, Exporting, Completed}`, and the `eframe::App` shell.
- Consumes: queue, preflight, batch, report, progress, cancellation, and output-folder shell adapter.

- [ ] **Step 1: Write failing controller-state tests without opening a window**

```rust
#[test]
fn export_requires_inputs_and_output_folder() {
    let mut app = AppController::default();
    assert_eq!(app.state(), AppState::Empty);
    app.accept_inputs(fixture_inputs());
    assert!(!app.can_start());
    app.set_output_root(PathBuf::from("out"));
    assert_eq!(app.state(), AppState::Ready);
    assert!(app.can_start());
}

#[test]
fn start_becomes_stop_and_cancel_is_cooperative() {
    let mut app = ready_controller();
    app.start(ExistingOutputPolicy::Overwrite).unwrap();
    assert_eq!(app.primary_action_label(), "停止");
    app.stop();
    assert!(app.cancellation_token().unwrap().is_cancelled());
}
```

Also test clear queue, duplicate additions, per-row status updates, aggregate footer counts, one overwrite prompt per batch, and completion transition.

- [ ] **Step 2: Run and verify failure**

Run: `cargo test --locked --test gui_state`

Expected: FAIL because `AppController` is missing.

- [ ] **Step 3: Implement the testable controller**

Keep dialogs and rendering out of the controller. `accept_inputs`, `set_output_root`, `clear`, `preflight`, `start`, `stop`, and `poll_progress` are deterministic methods. During export, disable file/folder/output selection and clear; primary action calls `stop`. On completion, retain rows and output root so “打开输出文件夹” is available.

- [ ] **Step 4: Implement the approved eframe window**

Use `rfd::FileDialog::pick_files` with an `anm2` filter, `pick_folder` for recursive input, and another `pick_folder` for output. The central queue shows filename, source-relative directory, animation count, and `就绪/警告/失败/跳过/成功`. The footer shows queued ANM2 count, animation count, total progress, current ANM2/animation, and aggregate completion counts.

Vendor Noto Sans SC Regular under its OFL license and install it first in egui proportional and monospace families:

```rust
fn install_chinese_font(ctx: &egui::Context) {
    let mut fonts = egui::FontDefinitions::default();
    fonts.font_data.insert("noto-sc".into(), egui::FontData::from_static(include_bytes!("../assets/NotoSansSC-Regular.otf")).into());
    for family in [egui::FontFamily::Proportional, egui::FontFamily::Monospace] {
        fonts.families.entry(family).or_default().insert(0, "noto-sc".into());
    }
    ctx.set_fonts(fonts);
}
```

```rust
fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions { viewport: egui::ViewportBuilder::default().with_title("ANM2 to GIF").with_inner_size([980.0, 640.0]), ..Default::default() };
    eframe::run_native("ANM2 to GIF", options, Box::new(|cc| Ok(Box::new(gui::Anm2GifApp::new(cc)))))
}
```

Use a single modal confirmation when `BatchPlan::existing_outputs` is non-empty with “覆盖全部 / 跳过已有 / 取消”. `open_output_folder` uses `ShellExecuteW` only after an explicit button click and reports failure in the status bar.

- [ ] **Step 5: Run automated GUI-state checks and a manual window smoke test**

Run:

```powershell
cargo fmt
cargo test --locked --test gui_state
cargo clippy --locked --all-targets -- -D warnings
cargo run --locked --bin Anm2Gif
```

Expected: tests pass; the window remains responsive; file multi-select and folder dialogs open; Start is disabled until inputs/output exist; Stop cancels cooperatively; no export runs on the UI thread.

- [ ] **Step 6: Commit the GUI slice**

```powershell
git add tools/anm2gif/src tools/anm2gif/assets/NotoSansSC-Regular.otf tools/anm2gif/tests/gui_state.rs
git commit -m "feat: add native batch exporter window"
```

### Task 11: Repository Samples, Golden Pixels, and End-to-End Batch Verification

**Files:**
- Create: `tools/anm2gif/tests/reference_samples.rs`
- Create: `tools/anm2gif/tests/end_to_end.rs`
- Create: `tools/anm2gif/tests/reference-manifest.json`
- Create: `tools/anm2gif/tests/golden/reference/`

**Interfaces:**
- Produces: offline evidence for entity, effect, UI, and standalone costume inputs.
- Consumes: complete conversion core and batch coordinator.

- [ ] **Step 1: Define the exact read-only sample manifest**

Use these repository files and their declared PNG sheets without altering them:

```json
[
  { "kind": "entity", "anm2": "../../resources/gfx/Effects/BigDogBark/big_dog_entity.anm2" },
  { "kind": "effect", "anm2": "../../resources/gfx/Effects/TheMoonIsBeautiful/moon_mark_wave.anm2" },
  { "kind": "ui", "anm2": "../../resources/gfx/UI/traffic_meter.anm2" },
  { "kind": "costume", "anm2": "../../resources/gfx/characters/costume_blue_banana_peel.anm2" }
]
```

At test start, hash each ANM2 and every resolved PNG. At test end, hash them again and assert exact equality.

- [ ] **Step 2: Write failing end-to-end assertions**

For every named animation in every valid supported sample, assert the expected output path exists, decodes as GIF, has one stable width/height for all frames, has the parser-derived frame count and accumulated duration, and matches loop semantics. Assert `anm2gif-report.txt` contains the source path and every output path. Run the same batch twice into separate temp directories and compare complete GIF bytes.

- [ ] **Step 3: Capture and review pre-quantization golden frames**

For every unique `(spritesheet, crop, animation, layer, timeline frame)` render state used by the four samples, export RGBA before palette conversion. Deduplicate only byte-identical RGBA buffers after recording all source locations. Produce native 1x and 4x nearest-neighbor contact sheets on checkerboard, solid white, and a room-like background. Review pivot, layer order, crop edges, and alpha visually; store only approved RGBA hashes and compact PNG contact sheets under `tests/golden/reference/`.

The acceptance note must say “offline reference comparison” and must not claim runtime player/costume composition, shaders, Lua replacement, or in-game proof.

- [ ] **Step 4: Run full deterministic and integrity suite**

Run:

```powershell
cargo test --locked --test reference_samples --test end_to_end -- --test-threads=1
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
```

Expected: every supported named animation exports; repeated GIF bytes match; source hashes are unchanged; warnings explicitly identify runtime-only or unsupported features.

- [ ] **Step 5: Commit reference evidence**

```powershell
git add tools/anm2gif/tests/reference_samples.rs tools/anm2gif/tests/end_to_end.rs tools/anm2gif/tests/reference-manifest.json tools/anm2gif/tests/golden/reference
git commit -m "test: verify exporter against representative anm2 assets"
```

### Task 12: Release Packaging, PE Dependency Gate, Documentation, and Clean-Windows Acceptance

**Files:**
- Create: `tools/anm2gif/scripts/build-release.ps1`
- Create: `tools/anm2gif/scripts/verify-portable.ps1`
- Create: `tools/anm2gif/tests/portable_pe.rs`
- Create: `tools/anm2gif/README.md`
- Create: `tools/anm2gif/THIRD_PARTY_NOTICES.md`
- Create: `tools/anm2gif/dist/Anm2Gif.exe`

**Interfaces:**
- Produces: final one-file artifact and evidence checklist.
- Consumes: complete application.

- [ ] **Step 1: Write the failing PE import and dist-shape test**

```rust
#[test]
fn release_imports_only_windows_system_dlls() {
    let exe = release_exe();
    let bytes = std::fs::read(exe).unwrap();
    let pe = goblin::pe::PE::parse(&bytes).unwrap();
    let allowed = [
        "advapi32.dll", "bcrypt.dll", "comctl32.dll", "comdlg32.dll", "dwmapi.dll",
        "gdi32.dll", "imm32.dll", "kernel32.dll", "ntdll.dll", "ole32.dll",
        "opengl32.dll", "shell32.dll", "shlwapi.dll", "user32.dll", "uxtheme.dll",
        "ws2_32.dll",
    ];
    for import in pe.imports { assert!(allowed.contains(&import.dll.to_ascii_lowercase().as_str()), "unexpected DLL: {}", import.dll); }
}
```

The PowerShell verifier also asserts `dist/` contains exactly one file named `Anm2Gif.exe` and no `.dll`.

- [ ] **Step 2: Run and verify the expected pre-build failure**

Run: `cargo test --locked --test portable_pe --release`

Expected: FAIL because the release artifact has not been assembled at the expected path.

- [ ] **Step 3: Implement locked release packaging**

`build-release.ps1` must stop on errors and run exactly:

```powershell
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$artifact = Join-Path $project 'target\x86_64-pc-windows-msvc\release\Anm2Gif.exe'
$dist = Join-Path $project 'dist'
cargo test --manifest-path (Join-Path $project 'Cargo.toml') --locked
cargo clippy --manifest-path (Join-Path $project 'Cargo.toml') --locked --all-targets -- -D warnings
cargo build --manifest-path (Join-Path $project 'Cargo.toml') --locked --release --target x86_64-pc-windows-msvc
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Get-ChildItem -LiteralPath $dist -File | Remove-Item -Force
Copy-Item -LiteralPath $artifact -Destination (Join-Path $dist 'Anm2Gif.exe')
```

Before the cleanup line, resolve `$dist` and assert it equals the exact repository path `tools\anm2gif\dist`; never use a wildcard or unresolved variable as a destructive target.

- [ ] **Step 4: Document use and evidence boundaries**

`README.md` must cover: file multi-select, recursive folder selection, output selection, all-animation export shape, overwrite/skip/cancel, progress/stop behavior, report location, intrinsic PNG requirement, GIF palette/alpha limits, unsupported runtime composites/shaders/Lua replacement, build commands, and test commands. State that static and offline reference checks do not prove in-game composite correctness.

Generate `THIRD_PARTY_NOTICES.md` from the locked dependency licenses, include the Noto Sans SC Open Font License notice and vendored font version, and verify that every direct dependency is represented. Do not place license files or any DLL beside `dist/Anm2Gif.exe`; notices remain in source distribution.

- [ ] **Step 5: Build and run local release gates**

Run:

```powershell
& .\scripts\build-release.ps1
cargo test --locked --test portable_pe --release
& .\scripts\verify-portable.ps1
Get-FileHash -Algorithm SHA256 .\dist\Anm2Gif.exe
```

Expected: test suite and Clippy pass; PE imports are allowlisted Windows system DLLs; `dist/` contains only `Anm2Gif.exe`; the executable opens without a console window and exports a representative multi-file batch.

- [ ] **Step 6: Perform clean Windows 10/11 x64 acceptance**

Copy only `Anm2Gif.exe` to a clean Windows 10/11 x64 VM with no Rust, Python, FFmpeg, ImageMagick, or .NET Runtime installed. Verify native file/folder dialogs, recursive queueing, output selection, one overwrite prompt, progress, cancellation cleanup, valid GIF output, UTF-8 report, no network access, and no helper process. Record OS build, EXE SHA-256, batch inputs, output counts, and observed system DLLs in the release evidence section of `README.md`.

- [ ] **Step 7: Commit the release artifact and evidence**

```powershell
git add tools/anm2gif/scripts tools/anm2gif/tests/portable_pe.rs tools/anm2gif/README.md tools/anm2gif/THIRD_PARTY_NOTICES.md tools/anm2gif/dist/Anm2Gif.exe
git commit -m "release: package portable anm2 gif exporter"
```

## Final Verification Checklist

- [ ] `cargo fmt --check` exits 0.
- [ ] `cargo clippy --locked --all-targets -- -D warnings` exits 0.
- [ ] `cargo test --locked` exits 0 with parser, path, asset, timeline, pixel, GIF, atomicity, batch, GUI-state, reference, and PE tests included.
- [ ] Two identical batches produce byte-identical GIFs and reports except for deliberately recorded absolute output roots.
- [ ] All named animations from the four representative samples are accounted for as success, warning, failure, or skipped; none silently disappear.
- [ ] A failure in one ANM2 or animation does not abort unrelated exports.
- [ ] Cancellation removes only current temporary files and preserves completed GIFs.
- [ ] Source ANM2 and PNG hashes are unchanged.
- [ ] Every GIF uses one stable canvas, transparent index 0, deterministic palette/dithering, correct duration, and correct loop extension behavior.
- [ ] `dist/` contains exactly `Anm2Gif.exe`; its PE imports contain no third-party DLL.
- [ ] Clean Windows 10/11 x64 launch and representative batch evidence is recorded.
- [ ] Completion language distinguishes automated tests, offline reference comparison, clean-machine portability, and excluded in-game/runtime composition.

## Spec Coverage Index

- GUI states, dialogs, queue, progress, stop, and open-folder action: Tasks 9–10.
- Multi-file/folder discovery, roots, recursion, deduplication, relative layout, sanitization, collisions: Task 2.
- Deterministic spritesheet resolution, PNG decode, crop validation, preflight: Tasks 3–4.
- Empty tracks, Root/Null/layer data, delays, visibility, interpolation, warnings, invalid references: Tasks 1, 3, and 5.
- Union bounds, nearest-neighbor transform, native layer order, tint/color/alpha, transparent empty animation: Task 6.
- Global palette, transparency, alpha dithering, timing, looping, streaming encode: Tasks 5 and 7.
- Atomic writes, smallest-safe failure scope, UTF-8 report, cancellation cleanup: Tasks 8–9.
- Representative entity/effect/UI/costume evidence and per-crop visual review: Task 11.
- Single-file release, no runtime install, no third-party DLL, clean-Windows verification: Task 12.
