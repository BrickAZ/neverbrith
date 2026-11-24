# 固定构建免爆出口审计

源码 commit：4675b426d1ce7973595172984c366354e5bb66f9。EXE SHA256：530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627。

范围是实际进入 Entity_Player::TakeDamage 的原生爆炸专属保护。未产生命中的拆弹/碰撞规避、通用无敌、护盾和第三方取消不属于这个接口。完整反汇编保存在 take-damage-baseline.asm；地址仅描述本 EXE，加载必须重新核对构建和唯一特征。

## 判定清单

| 来源 / siteKey | 前置原生条件 | 改接点 | 允许目标 / 否决目标 | 保留行为 |
| --- | --- | --- | --- | --- |
| COLLECTIBLE_PYROMANIAC / pyromaniac.full-health | HasCollectible(223)，无 FIRE 位，有 EXPLOSION 位，红心已达原生容量 helper | 73ce93 的 JGE | 741614 / 73cf09 | 红心不足时原 JL 分支去 73ce99；火焰出口 73ce70 不改 |
| COLLECTIBLE_PYROMANIAC / pyromaniac.after-heal | 同上且原治疗路径已执行 | 73cf01 的 JMP | 741614 / 73cf09 | 原生效果生成和 AddHearts(1,false) 完整执行一次 |
| COLLECTIBLE_HOST_HAT / host-hat.before-feedback | HasCollectible(375)，ESI 为 EXPLOSION 位且非零 | 73cf24 的 JE | 73cf2a / 73cfec | 仅允许时执行 GuardLeft/Up/Right/Down 成功反馈；73d2e8 的投射物分支不改 |
| COLLECTIBLE_IPECAC / ipecac.qualified-bomb | 原字段 1341 或 1346+HasCollectible(52)；HasCollectible(149)；EXPLOSION；source spawnerType=1/3；Entity_Bomb 动态转换成功且原 bool[398] 非零 | 73d05e 的 JNE | 741614 / 73d064 | 原全部资格条件不重写；不推测两个未命名字段的其他玩法含义 |
| COLLECTIBLE_IPECAC / ipecac.qualified-knife | 原字段1346；HasCollectible(149)；EXPLOSION；source Type=8 | 73d090 的 JE | 741614 / 73d096 | 原吐根其他能力及非爆炸处理不改 |
| PLAYER_BABY_SKIN_20 / coop-baby.skin-20 | Variant=1，BabySkin=20，ESI 为 EXPLOSION 位且非零 | 73d0cc 的 JNE | 741614 / 73d0d2 | 其他皮肤/非爆炸分支不改；无 collectibleId |

各改接点栈平衡，EDI 为实际 Entity_Player，EBP 为原 TakeDamage frame。输入为 [EBP+08] float、[+0C/+10] flags、[+14] EntityRef*、[+18] countdown。调用原生桥接时必须保存 GP、EFLAGS、XMM/x87/MXCSR；桥接结果不能覆盖原伤害返回值。纵火狂否决继续点 73cf09 保留 ESI=4，因此宿主帽、吐根和宝宝仍会被判定。

## 覆盖闭合依据

- 函数区间 73c930–74163e 的全部低 flags 原值/局部副本读取已检查。直接 EXPLOSION mask 4：73cd87 为 Blasting Cap 的掉落副效果；73ce78 为纵火狂；73cf06 将 blast 位保留在 ESI；73dccc 为着色条件；740966 为后置效果/日志。高 flags 的 mask 4 位于 73cb43，属于高位通用拒绝，不能按低位 EXPLOSION 否决。
- ESI 从 73ce78/73cf06 起只在宿主帽、上述两条吐根分支、合作宝宝分支用作爆炸布尔量；73d106 将它覆盖为 source EntityRef。所有这些免爆返回均列入清单。之后 mask 4 的读取不产生额外免爆出口。
- 圣光斗篷、通用无敌/伤害冷却、火焰来源、Lost/Heart 等通用保护均继续原路径。FIRE+EXPLOSION 被纵火狂火焰出口提前挡下时，不强制破坏火焰防护。
- 反汇编 724f00 的开头与 EntityPlayer.zhl AddHearts 签名相符；73cefc 调用前推入 0 和 1，原作用保留。RTTI 数据 BEACAC 确认 Ipecac 的动态转换为 Entity_Bomb，BEAB18 为 Entity。
- callbackId=1485：固定枚举最高公开回调为1484，未在回调定义/调用中找到1485占用；新位图索引485处于500位范围。非回调枚举中同值不构成回调冲突。

这是一份固定构建的静态审计，不是实机验收；治疗精确表现、混合来源、死亡/续局和第三方组合仍需真实游戏记录。
