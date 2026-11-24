# 已确认招式演出：游戏代码接入第一版

日期：2026-10-23。演出播放层已在当前安装目录由`main.lua`加载；720用V9，其余用已确认且与V8／V9同项字节一致的V7资源。未增加道具注册、道具池、伤害、消耗、气槽换算、OD按键、真实抓取或碰撞规则。

## 进游戏查看

重启游戏后进入一局，打开游戏控制台。直接播放：

```text
nbmotion wave
nbmotion dp
nbmotion dp od
nbmotion 360
nbmotion 360 od
nbmotion 720
```

可附方向，例如`nbmotion wave normal up`。只有一种波动，720仅普通版；其他已删除波动不出现在播放器内。老桑沿用已确认的日语声音事件，音高1，不改变音源。

要通过已确认输入规则触发，先执行以下任一命令：

```text
nbmotion arm wave
nbmotion arm dp
nbmotion arm dp od
nbmotion arm 360
nbmotion arm 360 od
nbmotion arm 720
```

之后按住主动键（默认空格）输入指令。波动为一次新的射击方向键按下；升龙使用已确认623及容错；360／720仍用WASD的四主方向一轮／两轮，窗口0.8秒／1.5秒。朝向由共享输入起手锁定。OD由本次预演命令选择，未定义正式OD操作或消耗。

`nbmotion stop`立即停止当前玩家的演出并退出预演输入；`nbmotion status`查看播放帧与输入诊断。控制台入口操作第一个玩家，Lua接口支持按玩家分别调用。预演模式会对该玩家启用既有原生攻击限制，并取消其原生活跃道具使用；不添加物品或修改充能。换房、死亡、退出或卸载会解除预演。

这些命令只预演已确认视觉和输入。示范目标仅在预演中显示；正式道具绑定表仍为空，尚不能靠捡到新道具来触发。

## 代码与调用合同

| 文件 | 职责 |
| --- | --- |
| [motion_presentation.lua](../../../../motion_presentation.lua) | 每玩家演出、当前外观的独立Sprite副本、普通房间构图与720特写、日语事件、控制台与清理 |
| [generated/motion_presentation.lua](../../../../generated/motion_presentation.lua) | 从保存后的已确认XML／锚点提取的变换数据；运行时不读取报告JSON |
| [tools/build-motion-presentation.py](../../../../tools/build-motion-presentation.py) | 可复现数据提取与`--check`；不改原始ANM2 |
| [motion_input.lua](../../../../motion_input.lua) | 成功执行后调用演出接口，显式预演输入仍复用原核心和攻击限制 |
| [main.lua](../../../../main.lua) | `MOTION_PRESENTATION_BEGIN/END`唯一加载块 |

正式玩法模块仍用`MotionInput:RegisterOwner`。执行回调成功返回`{ok=true}`后，播放器按`wave_tap/dp/circle_360/circle_720`映射普通演出；失败不播放。返回`presentation={variant='od',target=target}`可明确选择已确认OD和由玩法持有的目标；返回`presentation=false`可由玩法模块自己安排播放。没有恢复双波动等已撤下的演出。

也可直接调用：

```lua
Neverbirth.MotionPresentation:Play(player, 'circle_720', {
    variant='normal', facing=command.facing, target=ownedTarget,
})
```

返回`{ok=true}`或失败原因。真实摔技演出必须由调用方传入目标，不自动选择Boss或决定抓取资格；目标AI、位置、碰撞、锁定、伤害与无敌均仍由未来玩法合同负责。播放器只临时替代其渲染，不能代替抓取机制。

原玩家和服装贴图被复制到本模块独立Sprite上；不写玩家的Sprite、外观、位置、速度、HP、充能、碰撞或存档。渲染回调只读取当前帧。演出每次30Hz游戏更新推进一次，暂停不推进；新房间／新层／新局／退出／沙漏加载／死亡／卸载清理，正常结束后回到原生渲染。音效清理仅停止本模块发出的声音，同ID多人演出使用引用计数。

普通演出的逻辑锚点只进行一次`Isaac.WorldToScreen(player.Position)`转换。源X为前方距离，源Y为画面高度，换朝向不会把升空高度旋成横移；不混入`PositionOffset`、`SpriteOffset`或回调`RenderOffset`。720在V9第21–288帧使用屏幕构图，其余阶段回房间锚点；镜头切换不移动真实实体。玩家保持直立四向姿态，OD金边和薄金色覆盖沿用已确认颜色及强度，角色服装也参与覆盖。

## 检查与实机边界

- 专项Lua测试覆盖所有832个已确认帧在四向的3328帧播放、成功指令联动、失败不播、预演输入、原生使用取消、暂停、多人、原外观保护、反射过滤、坐标转换失败、资源失败和清理。
- Python专项检查原始资源哈希、12段ANM2、贴图／裁切／声音链、生成数据一致性，以及129个已删除候选仍不存在。
- 统一LuaAll回归、原始日志及实际退出码见[checks.json](checks.json)。初次回归暴露启动时过早创建声音管理器；已改为首次播放声音时创建，模组加载不触碰未使用的音频服务，修复前报告仍保留。
- 已尝试菜单内原生资源检查，进程在进入探针前退出，没有新日志或结果标记。[native/result.json](native/result.json)明确标为未验证；旁边保留的是旧日志，不能当本次原生证据。临时加载块已恢复，检查前后所观察的用户状态文件哈希未变。

代码接入与自动检查不代表已完成游戏内画面、实际键盘手感、真实目标、特殊人物／服装、不同分辨率、音效输出或第三方组合验收。逐项入口见[game-acceptance.md](game-acceptance.md)。
