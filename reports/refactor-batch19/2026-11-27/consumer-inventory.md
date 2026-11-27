# 第 19 批逐件与共享能力清单

日期：2026-11-27。基线为本轮主代理冻结的实际未提交工作区，不使用 Git HEAD。结构核验与离线对照已完成；本批原生和人工验收状态见 delivery.md，不因已有独立文件自动升级。

## 逐件归属

| 道具 / ID | 实际入口及归属 | 正式依赖与状态 | 生命周期与保留政策 | 本批结果 |
| --- | --- | --- | --- | --- |
| 神的左手，恶魔之右手 / 61 | 根 divine_left_hand.lua 拥有历史同步、精确临时份数、复制/移除和回调；features/divine_left_hand/notices.lua 拥有提示 | 同一个 acquisition_state，自己的 divineLeftHand Scope；逻辑身份查询与身体历史键分开；原生历史 index/lineage 保留 | 同种子新局清本区；Continue 同步既有记录；换层只精确移除能证明归属的临时实物；歧义隔离，不按同 ID 猜删；沙漏参与者恢复本区和 granting | 四份同合同复制之一已切换；原 13 个行为场景旧新一致，结构已核验 |
| 回声宝宝 / 62 | 根 echo_baby.lua 拥有真实获取奖励、复制跟班、缓存、原生跟班回调 | acquisition_state 的获取订阅/快照，自己的 echoBaby Scope；复制记录与实体引用分离 | 新局清奖励并去掉旧复制跟班；Continue 保留本区、首个玩家更新重建缓存；沙漏只还原普通数据，原生房间恢复后再协调跟班，不提前删除竞争 | 复制已切换；原 25 个行为场景旧新一致，原生 AI 不由离线测试证明 |
| 凸眼鱼 / 64 | 根 blinky.lua 拥有吸取/近战/吐出/在途和生命周期；blinky_core.lua 拥有串行化规则和储物操作 | 显式 State/GetSelector；自己的 blinky Scope；选择器只负责输入展示，不拥有储物结算 | 储物不随共享沙漏回退；换房/退出归还在途，继续从持久记录归还；新局清本区；原价、选项与来源协调保持 | 既有模块满足职责归属，本批不改生产代码；原 15 个行为场景旧新一致 |
| 零分考卷 / 饰品 2 | 根 low_grade.lua 拥有耐久、实物迁移、伤害例外、熔炼与缓存；integrations/low_grade_eid.lua 单独负责可选 EID | acquisition_state 的 token/身体持有者及沙漏参与者；自己的 lowGrade Scope | Continue 保留匹配 runSeed 的账本；新局重建；移除/熔炼中间态延后协调；真实成功伤害才扣耐久；缺失沙漏快照沿旧空态恢复政策 | 复制已切换；既有完整生命周期和属性用例旧新一致 |

## 配套系统

| 系统 | 所有权与实例 | 接口/保留边界 |
| --- | --- | --- |
| scripts/systems/acquisition_state.lua | main 创建一个实例；持有获取候选、PRE_ADD 栈、temporary、awaiting、detached、newGround；只访问 pendingContent / pendingContentHourglass | 碰撞不是获取结算；订阅按登记顺序、错误记录后继续；沙漏参与者仍无序 pairs；新局/退出/房间的清理粒度不变 |
| scripts/runtime/player_identity.lua | 无状态纯查询 | 保留逻辑玩家与身体背包键；不替换 Blinky 储物或其他模块不同的身份政策 |
| scripts/runtime/snapshot_participants.lua | 每获取服务独立注册表 | 共享 CopyTree 作为复制依赖；capture/restore 的 nil、错误与执行顺序不改；不增加生命周期回调 |
| inventory_selector.lua | 每安装实例拥有会话、释放保护和输入递归计数；每身体会话、每控制器单所有者 | 触发请求、资格及执行仍属于调用者；回调与绑定同文件；Close/取消先移除会话再回调 |
| features/inventory_selector/entries.lua、text.lua | 分别产生背包展示行、处理文字字体；不拥有游戏结算 | GetTemporaryCount 可能同步/保存，条目 payload 保持原引用；展示不得直接改储物 |
| features/divine_left_hand/notices.lua | 临时提示 UI 的计时、绘制和清理 | 接收成功复制通知，不决定复制成败；由装配在旧位置安装回调 |
| pending_content_integration.lua | 只连接已安装服务、各件 Scope、提示与选择器，保存返回实例 | 正式 main 不依赖旧宽根回退；旧 context 工厂合同和 Mod 别名仍作兼容，不创建第二份状态 |

## 共享能力核验

| 候选 | 实际消费者 | 判定及证据 |
| --- | --- | --- |
| 普通无环数据树复制 | 临时复制、回声宝宝、零分考卷、获取服务 | 相同 type/pairs/递归值复制/非 table 直返算法合为 plain_data.CopyTree；四个旧副本删除。消费者实际执行计数与旧新行为对照通过 |
| 序列化复制 | Blinky Core.Clone | 保留独立：明确拒绝非 nil/number/string/boolean 叶值，错误合同不同。plain_data_test 检查该拒绝仍存在 |
| 射速换算 | 回声宝宝、零分考卷、既有 fire_rate | 保留差异：回声仅在 delay > -1 且正贡献时执行、最终受 5/s 剩余额度限制；零分使用 0.00001 下界和 5×倍率；fire_rate 的数值化/非负增量及 0.0001 下界不同。不能直接替换为同一函数改变边界 |
| 玩家身份 | 获取服务、临时复制、选择器、凸眼鱼、回声、零分 | 已复用按用途明确的服务查询；临时复制按身体历史归属、回声奖励逻辑归属与当前身体调度、零分逻辑 owner 与实体 holder 分开，不强行只用一个键 |
| 生命周期及存档区域初始化 | 各道具 | 区域版本/种子字段、空快照、重建/保存次数不同；使用共有 Scope 机制，校验与结算继续归道具 |
| 世界查询及输入错误处理 | 各道具、选择器、调试控制器 | Game/实体的必需/可选前提不同，普通 API 调用相似不单独构成公共抽象。未新增统一 pcall、世界缓存或输入仲裁 |
| 提示与条目制作 | 临时复制、选择器、凸眼鱼 | 既有私有展示模块沿用；不存在把同一份 gameplay 状态复制到新 UI 所有者的改动 |

## 旧入口与退出条件

本批根道具文件就是实际独立入口，继续保留，不另造空壳。“根目录旧文件”不自动是重复实现。pending_content_state.lua 只转发公共服务；公开 Mod 别名、Blinky 旧独立工厂回退和 integration 旧 context 支持继续用于兼容。只有确认外部消费者停止调用且有替代加载/生命周期证据后才撤去，不在本批删除。

共同算法四处迁移已完成，本批没有暂缓的同合同复制消费者。当前范围不代表全 Mod 重复算法清零；整轮清单由主代理汇总。
