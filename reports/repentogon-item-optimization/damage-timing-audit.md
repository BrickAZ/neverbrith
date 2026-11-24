# P3：伤害提交时机的同版本源码审查

更新于2026-09-08：不把空摇篮、ACE 有效伤害计数、黑太岁寄生改为“只收到 POST 就算有效非零伤害”。本轮已将 ACE 的候选入口移到 POST，以排除取消/最终零量请求；后续HP观察保持原逻辑，玩家两项生产不改。**P3仅部分完成**，详见[第三批交付](2026-09-08-third-batch.md)。以下保留前次审查背景。

## 已查证

- 当前 1.0.12a 的 MC_POST_ENTITY_TAKE_DMG 存在；签名不含新版本 ExtraSource。
- 同 tag `repentogon/Patches/ASMPatches/ASMCallbacks.cpp` 的 POST hook 位于 Entity::TakeDamage / EntityPlayer::TakeDamage 返回路径。玩家分支按返回成功标志调用，特殊白火路径被排除。hook 本身不验证实际 HP 差额大于零。
- 原版 TakeDamage 文档说明伤害存在下一帧提交的缓冲。成功返回不等于此刻 HitPoints 已下降。多个同帧事件仍不能各自借一次最终 HP 下降证明每次都有效。
- 后续 1.1.0 修复说明涉及玩家 POST 伤害参数曾为零的问题，因此当前版本不能把 POST Damage > 0 作为唯一可靠真值。
- 当前项目的空摇篮会在 PRE 写入状态；ACE 把同帧候选延迟后共同检查 HP；黑太岁使用请求量。它们确实值得优化，但把旧问题迁移为另一种未经证明的“有效伤害”定义不能算完成。

## 实施前所缺的证据

真实游戏探针必须记录独立事件序号、PRE/POST 的参数、回调时的生命状态和下一次提交后的生命状态，并覆盖护盾取消、无敌帧、零伤害、同帧多个伤害、致死及黑/骨/魂心。只有能把“有效非零”归属到各自事件，才迁移计数。

当前没有运行游戏，以上游戏内探针**未验证**。此项不阻塞独立的同次金额重写、原生主动充能和模块失效修复。

原始来源：[1.0.12a 原生 hook](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/Patches/ASMPatches/ASMCallbacks.cpp#L248)、[同版本回调](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/docs/docs/enums/ModCallbacks.md#L331)、[原版 TakeDamage](https://wofsauge.github.io/IsaacDocs/rep/Entity.html#takedamage)。
