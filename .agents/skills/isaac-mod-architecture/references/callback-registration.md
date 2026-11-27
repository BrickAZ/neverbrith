# Callback Registration

Isaac callbacks are the spine of the mod. Keep registration explicit.

## Rules

- Keep each new or touched handler and its native binding adjacent in the same
  file. Blank lines, binding comments and necessary availability guards can
  separate them; unrelated functions should not. Consecutive bindings may share
  one handler. Inline handlers already keep this relationship visible.
- Avoid duplicate callbacks that scan the same entities or players for the same purpose.
- Keep callback filters explicit when the API supports them.
- Document load order when modules depend on shared ids or helpers.
- Record whether import itself registers callbacks or exports an explicit installer.
  A second consumer of an existing module reads its saved instance instead of
  re-executing a registering file. Installer guards apply to a live generation,
  and must allow a cleaned-up replacement to bind to the current Mod.
- If a callback is challenge-only, card-only, or item-only, gate it early.

## Preserving Existing Installation Phases

Do not move registration earlier merely to satisfy layout. If a handler must
remain available before its installation phase, retain its original definition
and put an explicit installer immediately after it:

```lua
return function(mod, deps)
    local installers = {}
    function mod:OnUpdate()
        return deps.Update()
    end
    function installers.InstallUpdate()
        return mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdate)
    end
    return installers
end
```

The discovered assembly layer saves that instance and calls `InstallUpdate()`
at the original registration position. Preserve outer guards, loops, relative
order, priority, filters, function identity and handler returns. Read callback
fields and filter values at the original installation time; pass late locals or
loop variables explicitly when they are outside the installer's lexical scope.
Do not sort or iterate an installer table to recreate the original sequence.

An installer is not automatically idempotent. Use the target's existing
installation/rollback contract, and do not invent an event bus or wrap an existing
handler just for layout. A generic registration helper receiving `fn` has no one
fixed handler: apply adjacency at its business call sites. Cross-file owners may
return private installation methods while the parent schedules them.

Apply this to the authorized new/touched binding groups. It does not authorize
a bulk migration of unrelated callbacks. Verify actual loaded registrations and
important ordering, using adequate existing tests or focused comparisons.

## Red Flags

- A callback has branches for many unrelated content types.
- A helper registers callbacks as a side effect that is not obvious from the loader.
- New code assumes an id table is initialized before it is loaded.
