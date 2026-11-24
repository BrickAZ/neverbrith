# User Decision Authority

Use this rule whenever a task contains a design value, mechanic choice, reward
policy, pool or quality decision, visual direction, player-facing wording, or
other choice that belongs to the mod author.

## Authority Rules

- An explicit user decision is locked. Do not replace, rebalance, reinterpret,
  or silently "improve" it.
- A necessary, unresolved user choice is `TBD — user decision required`. An agent may offer a labeled
  `Suggestion` with its reason and tradeoff, but it is not approved input.
- A suggestion cannot silently become Lua, XML, ANM2, or a gameplay value. It
  needs direct user confirmation or an already-approved upstream design row.
- A field marked `已通过` in the established approval flow is authorized input;
  preserve it rather than asking the same design question again.
- The agent may choose technical implementation details that do not change the
  design decision: callback wiring, state storage, XML formatting, file
  placement, validation, and test scaffolding.

Unknown code owners, XML paths, runtime IDs, signatures and versions are
**Unverified — discovery required**. Trace the actual checkout and name remaining evidence gaps.

## Required Decision Block

Before implementation, record only the fields relevant to the task:

| Status | Meaning |
| --- | --- |
| Locked | Explicitly decided by the user. |
| Approved upstream | Already approved in the established design workflow. |
| TBD — user decision required | A needed design choice with no existing decision. |
| Suggestion | Optional proposal; needs approval before implementation. |

Do not invent numbers, rewards, restrictions, visual intent, or balance claims
to make this block look complete.
