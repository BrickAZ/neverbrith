# Character Art Delivery Lifecycle

Use this lifecycle when generating, editing or accepting character art. Report the highest state demonstrated for the requested deliverable. A review or intermediate deliverable can end at the corresponding stage.

## States

| State | Meaning | May enter the project? | Required evidence to advance |
| --- | --- | --- | --- |
| `semantic-reference` | External design, screenshot, concept, or style reference | No | User approves its identity role and provenance |
| `generation-candidate` | Image-model output or another candidate composition | No | Actual bitmap is measured; target consumer and native edit target are known |
| `native-conformed` | Candidate has been rebuilt or edited on the exact native canvas/crops without a destructive atlas resize | Only for testing | Canvas, crop ownership, frame coverage, and surface-specific Alpha policy are satisfied |
| `static-validated` | Deterministic file/path/PNG/ANM2 checks pass | Yes, for runtime testing | Static report names every check and remaining visual/runtime boundary |
| `native-1x-reviewed` | The surface passes native-scale contextual review | Yes, for in-game testing | Raw asset, native `1x`, and appropriate direction/action/context evidence are reviewed |
| `in-game-verified` | The actual consumer loads and renders correctly in Isaac | Yes | Exact game surface, states, and reproduction are recorded |
| `user-approved` | The user accepts the final visual result | Final | Approval applies to the named surface/version only |

Do not skip states in a completion claim. A project may iterate backward at any state. For example, an in-game scale problem returns the asset to `generation-candidate` or `native-conformed`, depending on whether the native pixels can be repaired safely.

## Exact Raster Dimensions

Dimensions written in an image-generation prompt express composition intent; they do not guarantee the returned bitmap dimensions.

After every built-in or external generation:

1. Read the delivered width and height from the file.
2. Record requested canvas and actual generated canvas separately.
3. If the consumer requires an exact canvas and they differ, keep the result at `generation-candidate`.
4. Do not uniformly shrink an illustration or generated atlas into a native sprite atlas. Rebuild the selected design on the exact native edit target with its real crop manifest.
5. Record the final native canvas only after native conformance has actually occurred.
6. Do not say `directly usable`, `game-ready`, or `final asset` until the corresponding evidence exists.

An image that happens to arrive at the requested dimensions still needs source, crop, Alpha, native-scale, consumer, and user-approval checks. Dimension equality advances no state by itself.

## Required Audit

Use this block for a full generation or conformance handoff. For a focused edit or review, report only the affected surface, measured facts, changed pixels or paths, and the relevant verification state:

```text
Surface / consumer:
Art mode:
Alpha policy:
Edit target:
Semantic reference:
Requested canvas:
Actual generated canvas:
Current state:
Final native canvas:
Uniformly resized into atlas: no
Native-conformance route:
Approved masks:
Allowed silhouette changes:
Prompt or edit brief:
Static checks:
Native-1x verdict:
In-game verdict:
User approval:
```

Use `not run` for an unrun check, `not produced` for a missing artifact, and `Unverified — discovery required` for a missing technical fact. Use `TBD — user decision required` only for a design choice.
