# Shared Helpers And Constants

Shared helpers are useful when they make repeated logic safer.

## Good Shared Helpers

- Stable id lookup tables.
- Player key helpers.
- State reset helpers.
- XML/language helper scripts.
- Validator scripts.
- Debug logging wrappers that can be disabled.

## Rules

- Keep helpers small and named by what they do.
- Avoid helper modules that import every content module.
- Keep one-off item policy local unless an explicit independent responsibility justifies a boundary. Do not require a second consumer for a real persistence/API boundary or approved infrastructure, and do not generalize a speculative future use case.
- Keep constants close to the content type unless many modules need them.

For returned tables/factories, shared-instance identity, result ownership and
query/effect separation, read [module-loading-and-exports.md](module-loading-and-exports.md).
Private locals remain usable through exported closures; a shared helper does
not require exposing all internal state or importing the module again per caller.
