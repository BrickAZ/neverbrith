---
name: isaac-performance-hotpaths
description: Review, design, implement, or write handoff prompts for Binding of Isaac: Repentance mod performance-sensitive update, render, entity-scan, spawn, and cache paths. Use whenever a mod stutters, has per-frame logic, repeatedly scans entities, spawns effects/projectiles frequently, rebuilds tables or sprites, or needs a performance review.
---

# Isaac Performance Hot Paths

Use `isaac-mod-context` first when the target project is unfamiliar. Discover the
actual callback, owner, resource, and state conventions before changing a hot path.

## Boundary

This skill optimizes measured or plausibly hot runtime paths. It does not choose
gameplay balance, invent project structure, or replace lifecycle ownership rules.
Use `isaac-callback-contracts`, `isaac-state-lifecycle`, `isaac-entities`,
`isaac-projectile-combat`, or `isaac-audio-render-feedback` for those concerns.

Default to official Isaac APIs. Treat REPENTOGON and every third-party library as
optional: use one only after the project explicitly declares it and runtime/API
availability is confirmed. Its absence must leave an official-API fallback or an
explicitly documented unsupported branch.

## Diagnose Before Optimizing

State which evidence is confirmed and which is `TBD`. Do not claim a measured
improvement without a reproducible observation.

For each suspect path, record:

- callback and frequency: event, room entry, entity update, every frame, render;
- scope: run, room, owner, entity, or a bounded work queue;
- work performed: scans, allocations, `Isaac.Spawn`, sprite/resource loading,
  table rebuilding, cache evaluation, or save serialization;
- trigger signal and correctness constraint;
- evidence method: profiler, debug counter, trace, controlled room, or `TBD`.

Treat `MC_POST_RENDER` as visual-only unless the project proves otherwise. Do not
move gameplay settlement into render merely to avoid an update callback.

## Safe Reduction Patterns

Choose the smallest pattern that preserves behavior:

- Replace all-entity scans every frame with an event, a room-dirty flag, a bounded
  cadence, or a maintained owner list when the project can prove list cleanup.
- Build sprites, lookup tables, colors, and static configuration once per resource
  lifecycle, not once per frame. Do not share mutable per-owner state accidentally.
- Spawn only on a state transition, cooldown edge, or queued budget. A spawn cap
  needs a defined owner and reset/cleanup condition.
- Re-evaluate player cache only when a cache-affecting state actually changed; do
  not call it once per frame as a substitute for state design.
- Keep work bounded in dense rooms. If skipping/defering work changes gameplay or
  visuals, identify that change and obtain a decision rather than silently throttling.

Do not create an optimization from a guess. In particular, do not cache entity
references across room/run boundaries without lifecycle validation, and do not
convert an owner-specific lookup into one global value.

## Required Review Questions

Before finalizing, answer:

1. What makes this path hot, and what evidence supports that conclusion?
2. Which work is removed, deferred, deduplicated, or bounded?
3. What state owns the optimization, and when is it invalidated?
4. How do co-op owners, room transitions, reloads, death, and entity removal behave?
5. Which behavior is intentionally unchanged, and what remains unmeasured?

## Output Contract

Return, in order:

1. Confirmed project facts and `TBD` facts.
2. Hot-path table: callback, frequency, scope, work, evidence, risk.
3. Chosen reduction and rejected alternatives.
4. Ownership, invalidation, cleanup, and co-op contract.
5. Verification plan separating static checks, controlled runtime checks, and
   in-game evidence.

Never describe a static scan or stub as an in-game performance result.
