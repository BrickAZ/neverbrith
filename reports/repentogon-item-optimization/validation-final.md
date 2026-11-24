# 最终验证命令与结果

2026-09-05，代码冻结（含最终 EARLY 注册修复与神风异常计数测试）后由主代理重新执行。

## 命令

工作目录：`E:\Isaac - Repentance\mods\neverbrith`。

```powershell
$lua = 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe'
$luac = 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe'
$git = 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe'
# 逐脚本实际结果已保存；可按同一文件列表复跑：
$results = Get-Content -Raw 'reports/repentogon-item-optimization/test-results-final.json' | ConvertFrom-Json
foreach ($test in $results.Suite.Results) { & $lua $test.Path }
# diff中33个Lua + 5个新增Lua；其中RML的2个文件是既有脏改，只做回归检查：
$syntaxFiles = @(& $git diff --name-only -- '*.lua') + @(
    'tests/repentogon_bootstrap_test.lua', 'tests/repentogon_damage_dispatch_test.lua',
    'tests/repentogon_damage_order_test.lua', 'tests/repentogon_test_fixture.lua',
    'tests/fortune_custom_cache_behavior_test.lua'
)
$syntaxFiles = $syntaxFiles | Sort-Object -Unique
& $luac -p @syntaxFiles
& 'C:\Users\Anton\.codex\skills\isaac-validators\scripts\validate-isaac-mod.ps1' -Root . -ModObjectName Neverbirth
& '.\docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1' -Root .
& $git diff --check
# 显式 opt-in 的已知来源反例：
& $lua tests/big_dog_bark_behavior_test.lua --pending-p5
```

具体每项的输出和退出码保存于 test-results-final.json；原执行按基线清单与本轮相关测试去重逐个调用Lua，上述复跑命令读取同一最终文件列表。语法检查实际使用Git差异与五个新增文件的去重并集，共38个文件。

## 汇总

- 35套脚本：16通过、19失败；19个仍为执行前已有的16项缺include与3项旧文本断言。不是整库全绿。
- 新顺序组合测试：12/12；前置测试14类且重复加载；RML14项；鸿运测试包含旧两套合同适配。
- 38个Lua语法：exit 0。
- 通用验证器：19 warnings / 0 failures，exit 0；基线20 / 0。
- Neverbrith专用：273 warnings / 0 failures，exit 0；基线273 / 0。
- 警告逐条对比：无新增。少一条TrackCrazyCoconutCopies静态hotpath告警是扫描归类变化，不能宣称本轮优化了椰子（未改其生产逻辑）。专用扫描仍包含既有worktrees，未删目录或改验证器压低警告。
- git diff --check：exit 0，仅Git LF→CRLF转换提示，没有空白错误。收尾34个新增Lua/计划/报告的单独行尾空白扫描也为0问题；HEAD仍为8b736aa。
- P5反例：预期exit 1，取消碰撞＋同ID代码赠送错误计食物，expected0/got1。生产迁移暂停，没有删断言或改成绿色。

## 每个脚本

| 文件 | Exit | 结果 |
| --- | ---: | --- |
| tests/ace_anti_cheat_behavior_test.lua | 0 | localization tests passed; ACE anti-cheat behavior test passed |
| tests/angelbox_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/annihilation_behavior_test.lua | 0 | annihilation_behavior_test: ok |
| tests/between_death_and_life_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/big_dog_bark_behavior_test.lua | 0 | localization tests passed; Big Dog Bark behavior tests passed. |
| tests/blood_skull_gu_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/boss_order_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/burn_away_resentment_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/cleaver_character_behavior_test.lua | 0 | cleaver character behavior tests passed |
| tests/condom_utility_knife_behavior_test.lua | 1 | 既有Crazy Coconut XML断言 |
| tests/debug_controller_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/dice_set_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/dog_food_series_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/empty_cradle_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/folk_horror_items_behavior_test.lua | 1 | 既有Cleansed Wavy Cap XML断言 |
| tests/fortune_custom_cache_behavior_test.lua | 0 | fortune custom cache behavior tests passed (native order, lifecycle, dependency, 100-update performance) |
| tests/good_girl_of_babylon_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/kamikaze_squad_behavior_test.lua | 0 | kamikaze_squad_behavior_test: ok |
| tests/little_leather_shoes_behavior_test.lua | 0 | localization tests passed; little leather shoes behavior tests passed |
| tests/localization_test.lua | 0 | localization tests passed |
| tests/memory_disorder_behavior_test.lua | 0 | memory_disorder_behavior_test: ok |
| tests/moon_is_beautiful_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/musicbox_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/needletick_behavior_test.lua | 1 | 既有Needletick英文断言 |
| tests/repentogon_bootstrap_test.lua | 0 | REPENTOGON bootstrap tests passed (14 cases, repeated loads) |
| tests/repentogon_damage_dispatch_test.lua | 0 | localization tests passed; REPENTOGON 1.0.12a native Lua damage dispatch tests passed |
| tests/repentogon_damage_order_test.lua | 0 | REPENTOGON 1.0.12a real-registration damage order: 12 passed |
| tests/revive_my_love_behavior_test.lua | 0 | revive_my_love_behavior_test: 14 passed |
| tests/ring_of_the_seven_curses_behavior_test.lua | 0 | ring_of_the_seven_curses_behavior_test: ok |
| tests/shredded_tarot_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/sterilization_certificate_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/strong_laxative_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/tower_of_babel_behavior_test.lua | 1 | 既有缺include加载桩 |
| tests/uncut_cord_behavior_test.lua | 0 | uncut cord behavior tests passed |
| tests/yins_curse_behavior_test.lua | 0 | localization tests passed; Yin's Curse behavior tests passed. |

中途 angelbox/musicbox 曾因新P6生命周期注册而提前在nil枚举失败；补齐公共fixture中缺失的真实15/19后重新运行，已恢复至原有include失败。没有仅凭总数相同判断无回归。

未执行游戏内测试，不证明原生HP提交、护盾、额外生命HUD、动画、AI/爱心、爆炸半径、真实缓存顺序或实机帧耗时。
