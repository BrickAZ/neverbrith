-- Runs the documented queue and owned callback adapter, not Isaac's dispatcher.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local folder = assert(path:match("^(.*)/tests/[^/]+$"))
local file = assert(io.open(folder .. "/references/deferred-one-shot-callbacks.md", "rb"))
local document = file:read("*a"):gsub("\r\n", "\n")
file:close()
local blocks = {}
for block in document:gmatch("```lua\n(.-)\n```") do blocks[#blocks + 1] = block end
assert(#blocks == 2, "expected documented queue and callback adapter")
local mutation = arg[1]
local function replace(index, from, to)
    local start = assert(blocks[index]:find(from, 1, true), "mutation target missing")
    blocks[index] = blocks[index]:sub(1, start - 1) .. to .. blocks[index]:sub(start + #from)
end
if mutation == "--mutate-invalid" then
    replace(1, 'assert(type(fn) == "function", "task must be a function")', "-- validation omitted")
elseif mutation == "--mutate-reentry" then
    replace(1, "if disposed or pumping then return end", "if disposed then return end")
elseif mutation == "--mutate-removal" then
    replace(2, "mod:RemoveCallback(callbackId, onTick)",
        "mod:RemoveCallback(callbackId, function() end)")
else
    assert(mutation == nil, "unknown test argument")
end
local makeQueue = assert(load(blocks[1], "deferred-queue", "t", _G))()
local bind = assert(load(blocks[2], "deferred-adapter", "t", _G))()
local checks = 0
local function check(value, label)
    assert(value, label)
    checks = checks + 1
end
local function rejects(fn, label) check(not pcall(fn), label) end
local entries, removals, errors = {}, {}, {}
local mod = {}
function mod:AddCallback(id, fn)
    assert(type(fn) == "function")
    entries[#entries + 1] = { id = id, fn = fn }
end
function mod:RemoveCallback(id, fn)
    removals[#removals + 1] = { id = id, fn = fn }
    for i = #entries, 1, -1 do
        if entries[i].id == id and entries[i].fn == fn then table.remove(entries, i) end
    end
end
local function report(err) errors[#errors + 1] = tostring(err) end
local foreign = function() end
mod:AddCallback(1135, foreign)
rejects(function() makeQueue(nil) end, "an explicit error reporter is required")
rejects(function() bind(mod, nil, makeQueue, report) end, "missing callback rejected")
local binding = bind(mod, 1135, makeQueue, report)
local tick = entries[2].fn
check(#entries == 2 and tick ~= foreign, "one owned pump, foreign handler preserved")
rejects(function() binding.Defer(nil) end, "nil task rejected before enqueue")
rejects(function() binding.Defer("run") end, "string task rejected before enqueue")
rejects(function() binding.Defer(function() end, 1) end, "invalid guard rejected")
check(tick(mod) == nil, "empty pump is a void native callback")
local calls = 0
local completed = binding.Defer(function() calls = calls + 1; return false end)
check(#entries == 2, "tasks do not add native registrations")
check(tick(mod) == nil and calls == 1, "task return does not escape the native adapter")
tick(mod)
check(calls == 1 and completed() == false, "completed task cannot retry or cancel again")
local cancel = binding.Defer(function() error("cancelled task ran") end)
check(cancel() == true and cancel() == false, "pending cancellation is idempotent")
tick(mod)
check(#errors == 0, "cancelled task never runs")
local attempts, sibling = 0, 0
binding.Defer(function() attempts = attempts + 1; error("task exploded") end)
binding.Defer(function() sibling = sibling + 1 end)
tick(mod)
check(attempts == 1 and sibling == 1, "error does not stop remaining batch")
check(#errors == 1 and errors[1]:find("task exploded", 1, true), "failure is reported")
tick(mod)
check(attempts == 1 and #errors == 1, "failed task is consumed, not retried")
local guardCalls, guarded = 0, 0
binding.Defer(function() guarded = guarded + 1 end, function()
    guardCalls = guardCalls + 1
    return false
end)
tick(mod)
tick(mod)
check(guardCalls == 1 and guarded == 0, "invalid context is dropped at execution time")
binding.Defer(function() guarded = guarded + 1 end, function() error("guard exploded") end)
tick(mod)
check(#errors == 2 and guarded == 0, "guard failure is reported and consumes the task")
binding.Defer(function() error(nil) end)
tick(mod)
check(#errors == 3 and errors[3] == "nil", "nil-valued errors still produce a failure report")
local order = {}
binding.Defer(function()
    order[#order + 1] = "outer"
    binding.Defer(function() order[#order + 1] = "child" end)
    tick(mod)
end)
binding.Defer(function() order[#order + 1] = "sibling" end)
tick(mod)
check(table.concat(order, ",") == "outer,sibling", "nested enqueue and reentry cannot drain the new batch")
tick(mod)
check(table.concat(order, ",") == "outer,sibling,child", "nested task runs on a later pump invocation")
local cancelSibling, cancelledSiblingRan = nil, false
binding.Defer(function() check(cancelSibling(), "can cancel a later in-flight task") end)
cancelSibling = binding.Defer(function() cancelledSiblingRan = true end)
tick(mod)
check(not cancelledSiblingRan, "cancellation applies to the detached batch too")
local cancelSelf
cancelSelf = binding.Defer(function() check(cancelSelf() == false, "running task is no longer pending") end)
tick(mod)
local weak = setmetatable({}, { __mode = "v" })
local function capture(payload) return function() return payload end end
local payload = {}
weak[1] = payload
local release = binding.Defer(capture(payload))
payload = nil
release()
collectgarbage("collect")
check(weak[1] == nil, "cancellation releases captured payload even if handle survives")
local afterDestroy = 0
binding.Defer(function()
    binding.Defer(function() afterDestroy = afterDestroy + 1 end)
    binding.Destroy()
end)
binding.Defer(function() afterDestroy = afterDestroy + 1 end)
tick(mod)
check(afterDestroy == 0, "destroy cancels pending and remaining in-flight tasks")
binding.Destroy()
check(#removals == 1 and removals[1].fn == tick, "dispose removes exact owned wrapper once")
check(#entries == 1 and entries[1].fn == foreign, "dispose preserves foreign registration")
check(tick(mod) == nil and afterDestroy == 0, "stale saved wrapper cannot execute after dispose")
rejects(function() binding.Defer(function() end) end, "disposed instance rejects new work")
local replacement = bind(mod, 1135, makeQueue, report)
replacement.Defer(function() afterDestroy = afterDestroy + 1 end)
binding.Destroy()
entries[2].fn(mod)
check(afterDestroy == 1 and #entries == 2, "old disposal cannot remove replacement instance")
replacement.Destroy()
check(#entries == 1 and entries[1].fn == foreign, "replacement cleanup stays scoped")
local reporterThrows = true
local queue = makeQueue(function() if reporterThrows then error("reporter exploded") end end)
queue.Defer(function() error("first failure") end)
rejects(function() queue.Pump() end, "reporter failure is not silently swallowed")
reporterThrows = false
queue.Defer(function() calls = calls + 1 end)
queue.Pump()
check(calls == 2, "reporter failure leaves the pump guard released")
queue.Destroy()
local guardQueue = makeQueue(report)
local started = 0
guardQueue.Defer(function() started = started + 1 end, function()
    guardQueue.Destroy()
    return true
end)
guardQueue.Pump()
check(started == 0, "disposal during eligibility check prevents user work from starting")
print("Deferred task model checks passed: " .. checks .. "; native timing and lifecycle unverified")
