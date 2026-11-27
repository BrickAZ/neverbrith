---
name: isaac-repentogon-world
description: Use when developing or reviewing REPENTOGON room configuration, Level room placement, RoomDescriptor state, Ambush waves, or deterministic world previews for Binding of Isaac mods. Covers GetNextWave/GetNextWaves, nil/false placement failures, shared room weights, and engine RNG ownership. 中文触发：忏悔龙房间、楼层放置、挑战房波次、Boss Rush、房间预览、世界状态。
---

# ISAAC REPENTOGON World

先沿用已确认的项目与用户授权。用户已选择 required REPENTOGON 时，直接实现该路线，不重新询问依赖选择。技术事实缺失由 Agent 读取项目、官方文档和目标版本源码解决；仅真正未决的用户选择进入下述 TBD 流程。

## User Decisions and Technical Discovery

Read the [shared decision and evidence policy](../isaac-mod-context/references/tbd-disclosure.md).

## 工作入口

1. 未知目标模组先用 `isaac-mod-context`。共同依赖 [isaac-repentogon-compat](../isaac-repentogon-compat/SKILL.md) 的依赖/版本门禁与 [isaac-repentogon-dev](../isaac-repentogon-dev/SKILL.md) 的开发流程；门禁成功后才进入本技能。
2. 明确此次操作属于配置注册、地图放置、运行中房间状态、波次控制或预览。全局表存在不证明当前对局可用；访问游戏对象前检查 `Isaac.IsInGame()`，回调中重新取得当前 Level/RoomDescriptor。
3. 按表只读必要参考；其中 1.1.2g 是核验基线，不自动代表用户安装版本。区别官方文档、tag 源码与源码推断。

| 表面 | 必读参考 |
|---|---|
| RoomConfig、RoomDescriptor、Level、维度与门 | `references/rooms.md` |
| Ambush、普通/Boss 挑战房、Boss Rush | `references/ambush.md` |
| RNG、预览、共享状态、恢复与续局 | `references/rng-and-ownership.md` |

## 执行合同

- `RoomConfig` 是配置；`RoomDescriptor` 是地图记录；当前 `Room` 是活跃实例。保持这三者边界。
- 预检用 `CanPlaceRoom` / 候选位置；提交用 `TryPlaceRoom`，检查 falsy 返回并保留原逻辑。预览不调用放置、减权或生成。
- `GetNextWave` 必须房型守卫和 nil 分支；1.1.2g 的 `GetNextWaves` 有明确实现缺陷，不作为严格只读预览的默认路线。
- 每项写入记录所有者、影响范围、触发时机和退出/续局/重载恢复。共享最大波数不按猜测覆盖回默认值。
- 拓扑/自定义房间网络转交 `isaac-room-networks`、`isaac-rooms-stages`；生命周期转交 `isaac-state-lifecycle`；不把 StageAPI 当隐含依赖。

## 交付与验证

交付精确 API/版本证据、预览与提交路径、失败值处理、所有权及生命周期、实际测试结果。用隔离测试覆盖菜单态、配置缺失、nil/false、无有效位置、维度、重复调用、RNG/权重不变；地图可通行、波次实机行为和续局必须游戏内另验。未运行则明确标记未验，不以源码或静态通过替代。
