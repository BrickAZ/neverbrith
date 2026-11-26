# Module Boundaries

Use module boundaries to reduce confusion, not to decorate the codebase.

## Good Boundaries

- One content type per module family: items, trinkets, cards, entities, challenges.
- Extract repeated stable logic when sharing improves its ownership or correctness. Two real call sites are useful evidence, not a minimum: a clear persistence boundary, external-API adapter, or user-approved infrastructure may justify a module with one current consumer. State its responsibility and avoid speculative generalization.
- Content registration separate from behavior when the file grows hard to scan.
- Test files named after behavior or content.

## Bad Boundaries

- Splitting every small item into a new architecture before patterns stabilize.
- Hiding callbacks behind generic magic.
- Moving code only because a file is long, without reducing repeated logic.
- Creating helpers that know about every item.

## Review Question

Can a future agent find the relevant code from the content identity in less than a minute?
