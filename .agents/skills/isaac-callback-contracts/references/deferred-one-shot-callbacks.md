# Deferred One-Shot Callbacks

Use when a helper queues work for a later callback opportunity. A project method
named `Mod:Load` or `Defer` is not a native loader or a readiness guarantee.

## Select The Opportunity

The REPENTOGON maintainer documentation checked on 2026-10-26 describes
[`MC_PRE_RENDER`](https://repentogon.com/enums/ModCallbacks.html#mc_pre_render)
as running before `Manager::Render()`, and
[`MC_POST_MODS_LOADED`](https://repentogon.com/enums/ModCallbacks.html#mc_post_mods_loaded)
as running after Lua scripts have loaded. Both have void return contracts.
Use the latter when the actual prerequisite is completion of script loading,
after verifying the target build; a provider's later async/ready state is still
a separate condition. Neither event alone proves a valid run, room or player.
Do not silently introduce REPENTOGON into a vanilla-only target.

For gameplay delay, select the project's proven update/time source and context
boundary instead of using render counts as elapsed seconds. For presentation,
choose the relevant render opportunity and verify its actual dispatch. No
arbitrary one-frame wait resolves a missing or circular dependency.

## Execution Contract

- Validate callable policy before registration/enqueue. If only Lua functions
  are supported, reject other values immediately; do not leave an inert wrapper.
- Specify at-most-one invocation/attempt, success, failure, cancellation and
  retry separately. A protected call does not undo partial effects or turn an
  error into success. Automatic retry needs its own bounded, idempotent contract.
- Claim/remove the pending task before calling user code. In a per-task native
  wrapper, detach the exact registered wrapper at that point. In a shared pump,
  remove the task from the pending batch; the owned pump may remain registered.
- Define tasks queued during a drain, order, cancellation of siblings and
  nested pump calls. Snapshotting a batch gives a later-pump boundary, not proof
  of a later native frame. Verify native registration-list mutation separately.
- Keep task return values out of a void callback's native return path. An
  arbitrary `false` from a job must not accidentally become engine control flow.
- Expiry, invalid context and owner disposal must release queued closures.
  Cancellation cannot interrupt an already running synchronous function or
  roll back its effects. Do not clear another instance's or mod's callbacks.

In the supplied pattern, non-functions skip cleanup and an exception before
`RemoveCallback` bypasses it. With a countdown, whether a retained wrapper retries
also depends on the due comparison; `== 0` after decrement can instead strand it.
Inspect actual control flow rather than declaring every fault a repeated call.

## Executable Queue Example

This is a small pure-Lua interface example, not a required project framework or
an engine scheduler. It has no timer or frame promise. `Pump` takes one batch;
new work is eligible only on a later non-reentrant `Pump` invocation. The optional
guard is checked once just before the task; false drops it, not waits/retries.
Each task is attempted at most once; failures are collected and reported after
the batch. Supply a reliable, non-throwing reporter through the project's error
path. If that reporter throws, the exception propagates after drain state is
released; no automatic task replay is performed.

```lua
return function(reportError)
    assert(type(reportError) == "function", "error reporter required")
    local pending, running = {}, nil
    local disposed, pumping = false, false
    local api = {}
    local function release(tasks)
        for _, task in ipairs(tasks) do task.run, task.valid = nil, nil end
    end
    function api.Defer(fn, valid)
        assert(not disposed, "dispatcher disposed")
        assert(type(fn) == "function", "task must be a function")
        assert(valid == nil or type(valid) == "function", "invalid context guard")
        local task = { run = fn, valid = valid }
        pending[#pending + 1] = task
        return function()
            local wasPending = task.run ~= nil
            task.run, task.valid = nil, nil
            return wasPending
        end
    end
    function api.Pump()
        if disposed or pumping then return end
        pumping = true
        local batch, errors = pending, {}
        pending, running = {}, batch
        for _, task in ipairs(batch) do
            local fn, valid = task.run, task.valid
            task.run, task.valid = nil, nil
            if not disposed and fn then
                local ok, err = pcall(function()
                    if (not valid or valid()) and not disposed then fn() end
                end)
                if not ok then errors[#errors + 1] = { value = err } end
            end
        end
        running, pumping = nil, false
        for _, failure in ipairs(errors) do reportError(failure.value) end
    end
    function api.Destroy()
        if disposed then return end
        disposed = true
        release(pending)
        if running then release(running) end
        pending = {}
    end
    return api
end
```

For a discovered **void-returning** callback, this companion adapter installs one
owned pump. `makeQueue` is the factory above, not a native Isaac symbol.
`callbackId` and lifecycle teardown timing are discovered by the caller; passing
the render callback is not a generic endorsement of gameplay in rendering.

```lua
return function(mod, callbackId, makeQueue, reportError)
    assert(callbackId ~= nil, "callback id required")
    local queue = makeQueue(reportError)
    local disposed = false
    local function onTick(_)
        queue.Pump()
    end
    mod:AddCallback(callbackId, onTick)
    return {
        Defer = queue.Defer,
        Destroy = function()
            if disposed then return end
            disposed = true
            queue.Destroy()
            mod:RemoveCallback(callbackId, onTick)
        end
    }
end
```

Run `lua <skill-dir>/tests/test-deferred-tasks.lua`. It extracts and executes both
blocks against a registration ledger, including re-entry, cancellation, errors,
guard failure, closure release and exact wrapper removal. It does not simulate
native event order, game clocks or unload timing. The task and delay lifetime
contract is in
`../../isaac-state-lifecycle/references/deferred-task-lifetime.md`.
