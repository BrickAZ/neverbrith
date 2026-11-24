# 阿瓦达啃大瓜：原生发射回调修复

## 结果与未解决项

已修复一个有匹配版本源码、当前游戏磁盘文件和失败回归测试支持的发射阻断。
**尚未在游戏内验收，也尚未确认用户补充的“完全没有蓄力条”的前置原因。**
当前游戏日志最后更新时间为 2026-09-15 23:37:30；仅记录了道具 runtime ID 789，未记录蓄力或失败发射诊断。

## 路由与范围

主路径：玩家攻击替换 / REPENTOGON 原生 Weapon 回调。
次路径：按玩家持有的临时蓄力与施法状态、现有控制台诊断、回归验证。
实现归属：根目录 avada_kedavra.lua；main.lua 仅提供既有加载与道具 ID 接线。
沿用已实现的 30 游戏帧蓄力、5 倍攻击力、直接击杀成功、未击杀时施法者死亡及其复活拦截规则。
本次仅修改 avada_kedavra.lua 和 tests/avada_kedavra_behavior_test.lua，并保存本目录证据。

## 确定根因

本机 resources/scripts/main_ex.lua 声明普通 REPENTOGON 1.0.12a。
对应版本 CustomCallbacks.cpp 将 MC_POST_WEAPON_FIRE 放在基类 Weapon::Fire 返回之后。
但本机 isaac-ng.exe 的 Weapon_Brimstone::Fire 会先调用该基类，再执行自身的蓄力判定和原生发射。
离线定位得到硫磺火函数 0x94e850、基类函数 0x942e20；前者在 0x94e893 调用后者，随后才读取蓄力。
这次检查只读取磁盘 EXE，没有附加、读取或修改游戏进程内存，也没有修改 EXE。

原逻辑的 postWeapon 在该回调里执行 SetCharge(0)，使原生硫磺火随后读到零蓄力。
同一个回调还提前标记 nativePassed，而激光归属逻辑拒绝 nativePassed 后才生成的原生主激光。
因此即便蓄力完成，原生攻击仍可被自身逻辑阻止或删除。

来源：
- [1.0.12a CustomCallbacks.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp)
- [1.0.12a Weapon_Brimstone.zhl](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/Weapon_Brimstone.zhl)
- [1.0.12a LuaWeapon.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/LuaWeapon.cpp)
- 当前磁盘函数的最小反汇编片段：native-order.txt。

## 修复

- postWeapon 只记录经过基类回调的事实，不再清零蓄力或提前关闭施法上下文。
- 原生主激光在该回调之后生成时仍可继承正确施法者和 5 倍伤害。
- 保留原有 swirl 观察和失败发射超时；引擎未生成攻击时不会伪造失败死亡。
- avada_status 增加当前 phase 和本房间最高 peak 蓄力，避免打开控制台时松键把现场证据全部清掉。
- 现有测试把回调移至原生输出之前；新增断言能让修复前代码因“蓄力提前归零”失败。

## 验证

- 修复前原有行为测试：通过，但调用顺序错误，不能暴露此问题。
- 新增原生调用顺序回归：修复前失败，修复后通过。
- 新增诊断状态回归：添加诊断前失败，添加后通过。
- 当前 avada_kedavra_behavior_test.lua：通过，覆盖直接击杀、失败死亡、合作归属、取消/换房及武器恢复等 Lua 逻辑。
- Lua 5.4.6 / luac 语法检查：通过。
- avada_kedavra_registration_test.ps1：通过。
- annihilation_behavior_test.lua：通过。
- revive_my_love_behavior_test.lua：14 通过。
- localization_test.lua：通过。
- 通用 validate-isaac-mod.ps1 -Root . -ModObjectName Neverbirth：0 失败、11 警告（Breakfast 原版资源引用 3 项、主模块热点提示 7 项、玩家 0 提示 1 项）。
- folk_horror_items_behavior_test.lua：未通过，停在第 813 行 Cleansed Wavy Cap 的 XML timed-charge 断言；该道具及其 XML 不在本次修改中，后续民俗道具断言未执行。
- 本次 final.patch 的反向应用预检与 whitespace=error-all：通过。

以上脚本和离线原生证据不能代替实际键盘/手柄输入、可见蓄力条、反重力硫磺火表现、碰撞和复活顺序的游戏验证。

## 下一步现场核验

重新启动游戏以加载新模块，在持有阿瓦达啃大瓜且有敌人的房间，持续按住一个射击方向。
若仍无蓄力条/攻击，打开控制台执行 avada_status，提供完整输出。
peak=0 表示本房未进入有效蓄力；phase 会区分未初始化、敌人门槛、控制禁用及无射击输入。
peak>0 表示曾进入蓄力，应继续定位显示或原生发射；peak=30 表示完成过蓄力。
如需进一步追踪，现有 avada_trace on 开启诊断，复现后 avada_trace off 关闭。

## 文件备份

两个 .before 文件保留本轮修复前的原始字节；final.patch 仅描述本轮两份代码/测试文件的差异。
未提交或发布本轮改动。
