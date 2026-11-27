# Public Library Usage Must Be Saved

Before adding or reusing a shared capability, read the target project's existing
API index and usage notes, then verify them against the owning source. Discover
the documentation location; do not require a particular folder or framework.

Creating a library or changing a public export is complete only when the same
delivery includes its implementation, an actual consumer, persistent usage
documentation, and checks appropriate to the affected contract. Do not leave the
only detailed explanation in chat or create an unused abstraction for hypothetical
future consumers.

Document the applicable details, with a real usage example:

- Purpose, export shape, import/create operation, dot/colon call convention,
  instance owner and dependency injection.
- Each public function's parameters, types, units, defaults, returns and the
  meaning of missing values or failure.
- Preconditions, initialization/event timing and side effects, including callback
  registration, RNG advancement, pool requests, world changes and saving.
- Whether returned tables/entities are shared references or copies; permitted
  mutation, invalidation and rebinding rules.
- Responsibility for new run, continue, room/floor transitions, rewind and
  unloading, preserving the target project's established semantics.
- At least one actual consumer and the relevant validation entry point. Reuse
  adequate existing tests; add coverage for behavior changes or real gaps.

Keep short signature/return comments near public exports and cross-module usage
in the project's API documentation. Update those notes with the public contract;
do not duplicate project-private APIs across generic Skills. A private helper or
TestAPI does not become a production public interface merely to fill this list.

Simple APIs need only the details that apply. Persistent documentation is a
technical deliverable, not a required final-answer heading or table format.
For instance identity and import side effects, see
[module-loading-and-exports.md](module-loading-and-exports.md).
