# Neverbirth My Stuff 本地 ID 迁移表

状态：**已锁定**。已有道具不得因 XML 排序或其他 mod 加载顺序而改号；新道具只能追加未使用的本地 ID。

原生映射：`content/items*.xml id="N"` → `NeverbirthDeathItems.anm2` 的 frame `N` → 图集 cell `N`。

原生入口：三个 `content/items*.xml` 的 `deathanm2="gfx/UI/NeverbirthDeathItems.anm2"`，从 **content** 目录解析到 `content/gfx/UI/NeverbirthDeathItems.anm2`。该 ANM2 通过 `../../../resources/gfx/UI/NeverbirthDeathItems.png` 引用共享图集。不要将此入口放回 `resources`，也不要使用运行时全局道具 ID 作为帧号。

2026-09-23：补齐 23 个原本全透明的可见道具格。当前 59 个登记 ID 中，55 个可见道具均有草图；隐藏 ID 33–36 保留透明格。新增草图由内置 imagegen 根据现有彩色道具图生成，再整理为 16×16 像素及现有三色墨色。只替换缺失格，其他 777 个图集格保持像素一致。源图、提示词、生成图和原生尺寸预览见 `reports/mystuff-20260923/`。

检查命令：`powershell -ExecutionPolicy Bypass -File tools/validate_mystuff_local_ids.ps1`。该检查覆盖全部本地 ID、三语言映射、content 加载入口、ANM2 相对图片路径、帧几何和可见图标非空；实际暂停菜单、死亡遗书和收藏页仍需完整重启游戏后验证。

| 本地 ID | 道具名 | 彩色 gfx | My Stuff 源图 | 状态 |
| ---: | --- | --- | --- | --- |
| 1 | EssentialBalm | P_EssentialBalm.png | P_EssentialBalm_mystuff.png | 已映射 |
| 2 | Wuhu | Wuhu.png | Wuhu_mystuff.png | 已映射 |
| 3 | Uncut Cord | UncutCord.png | UncutCord_mystuff.png | 已映射 |
| 4 | Sterilization Certificate | SterilizationCertificate.png | SterilizationCertificate_mystuff.png | 已映射 |
| 5 | Empty Cradle | EmptyCradle.png | EmptyCradle_mystuff.png | 已映射 |
| 6 | Shredded Tarot | ShreddedTarot.png | ShreddedTarot_mystuff.png | 已映射 |
| 7 | Blood Skull Gu | BloodSkullGu.png | BloodSkullGu_mystuff.png | 已映射 |
| 8 | Boss's Order | BossOrder.png | BossOrder_mystuff.png | 已映射 |
| 9 | Between Death and Life | BetweenDeathAndLife.png | BetweenDeathAndLife_mystuff.png | 已映射 |
| 10 | Coin-Sewn Sword | CoinSewnSword.png | CoinSewnSword_mystuff.png | 已映射 |
| 11 | Coin-Faced Mask | CoinFacedMask.png | CoinFacedMask_mystuff.png | 已映射 |
| 12 | Black Taisui | BlackTaisui.png | BlackTaisui_mystuff.png | 已映射 |
| 13 | Meat Lump | BlackTaisuiMeat.png | BlackTaisuiMeat_mystuff.png | 已映射 |
| 14 | Cleansed Wavy Cap | PurifiedMushroom.png | PurifiedMushroom_mystuff.png | 已映射 |
| 15 | Good Girl of Babylon | GoodGirlOfBabylon.png | GoodGirlOfBabylon_mystuff.png | 已映射 |
| 16 | Condom | Condom.png | Condom_mystuff.png | 已映射 |
| 17 | Debug Controller | DebugController.png | DebugController_mystuff.png | 已映射 |
| 18 | Strong Laxative | StrongLaxative.png | StrongLaxative_mystuff.png | 已映射 |
| 19 | Tower of Babel | TowerOfBabel.png | TowerOfBabel_mystuff.png | 已映射 |
| 20 | The Moon Is Beautiful | collectible_the_moon_is_beautiful.png | collectible_the_moon_is_beautiful_mystuff.png | 已映射 |
| 21 | Burn Away the Resentment | BurnAwayResentment.png | BurnAwayResentment_mystuff.png | 已映射 |
| 22 | Needletick | Needletick.png | Needletick_mystuff.png | 已映射 |
| 23 | Crazy Coconut | CrazyCoconut.png | CrazyCoconut_mystuff.png | 已映射 |
| 24 | Fortune Rivalling Heaven Gu | fortune_rivalling_heaven_gu.png | icon-24.png | 已补齐 |
| 25 | Utility Knife | UtilityKnife.png | UtilityKnife_mystuff.png | 已映射 |
| 26 | Cleaver | Cleaver.png | Cleaver_mystuff.png | 已映射 |
| 27 | Aphrodisiac | Chunyao.png | Chunyao_mystuff.png | 已映射 |
| 28 | Musicbox | Musicbox.png | Musicbox_mystuff.png | 已映射 |
| 29 | Angelbox | Angelbox.png | Angelbox_mystuff.png | 已映射 |
| 30 | Devilbox | Devilbox.png | Devilbox_mystuff.png | 已映射 |
| 31 | ds4 | ds4.png | ds4_mystuff.png | 已映射 |
| 32 | Little Leather Shoes | little_leather_shoes.png | 主图标缩放占位 | 已映射；隐藏衍生 ID 33–35 不进入 My Stuff |
| 33 | Traffic: Unboxing | traffic_unboxing.png | — | 隐藏道具，保留透明格 |
| 34 | Traffic: Exposure | traffic_exposure.png | — | 隐藏道具，保留透明格 |
| 35 | Traffic: Heat | traffic_heat.png | — | 隐藏道具，保留透明格 |
| 36 | Certificate of Neverbirth | certificate_of_neverbirth.png | — | 隐藏道具，保留透明格 |
| 37 | House VS Elephant | saikeissho.png | icon-37.png | 已补齐 |
| 38 | Everchanging | Everchanging.png | icon-38.png | 已补齐 |
| 39 | Protein Strip | protein_strip.png | icon-39.png | 已补齐 |
| 40 | Energy Kibble | energy_kibble.png | icon-40.png | 已补齐 |
| 41 | Lean Can | lean_can.png | icon-41.png | 已补齐 |
| 42 | DHA Fish Oil | dha_fish_oil.png | icon-42.png | 已补齐 |
| 43 | Dental Chew | dental_chew.png | icon-43.png | 已补齐 |
| 44 | Lucky Liver Bites | lucky_liver_bites.png | icon-44.png | 已补齐 |
| 45 | Goat Milk Pudding | goat_milk_pudding.png | icon-45.png | 已补齐 |
| 46 | ACE Anti-Cheat System | ace_anti_cheat_blue.png | icon-46.png | 已补齐 |
| 47 | Yin's Curse | yins_curse.png | icon-47.png | 已补齐 |
| 48 | Big Dog Bark | big_dog_bark.png | icon-48.png | 已补齐 |
| 49 | Wind Charge Rod | wind_charge_rod.png | icon-49.png | 已补齐 |
| 50 | Echo Shard | echo_shard.png | icon-50.png | 已补齐 |
| 51 | Revive My Love | revive_my_beloved.png | icon-51.png | 已补齐 |
| 52 | Night of the Cowards | NightOfTheCowards.png | icon-52.png | 已补齐 |
| 53 | Annihilation | Annihilation.png | icon-53.png | 已补齐 |
| 54 | Kamikaze Squad | KamikazeSquad.png | icon-54.png | 已补齐 |
| 55 | Memory Disorder | Collectibles_025_Breakfast.png | icon-55.png | 已补齐，沿用现有早餐盒外形 |
| 56 | Ring of the Seven Curses | RingOfTheSevenCurses.png | icon-56.png | 已补齐 |
| 57 | Avada Kedavra | AvadaKedavraMelon.png | AvadaKedavraMelon_mystuff.png | 保留已有草图 |
| 58 | Healthy Sleep | healthy_sleep.png | icon-58.png | 已补齐 |
| 59 | I Am a God | i_am_a_god.png | icon-59.png | 已补齐 |
| 60 | God Complex | god_complex.png | GodComplex_death_cell.png | 已接入；原生界面实机待验收 |
| 61 | Divine Left Hand, Demonic Right Hand | divine_left_hand.png | reports/batch-completion/icon-61.png | 已接入；原生界面实机待验收 |
| 62 | Echo Baby | echo_baby.png | reports/batch-completion/icon-62.png | 已接入；原生界面实机待验收 |
| 63 | Bomb Suit | bomb_suit.png | reports/bomb-suit/2026-10-03/death-cell-63.png | 已接入；原生界面实机待验收 |
| 64 | Blinky | blinky.png | reports/blinky/2026-10-03/death-cell-64.png | 已接入；原生界面实机待验收 |
| 65 | Drive Glove | drive_glove_v1.png | resources/gfx/UI/DriveItem/v1/drive_glove_sketch.png | 已接入；第65格以外像素保持，原生界面待人工验收 |
| 66 | 360 | zangief_360.png | 沿用图集已有第66格 | 用户确认先复用现有图标；正式注册，原生界面待验收 |
| 67 | 720 | zangief_720.png | 沿用图集已有第67格 | 用户确认先复用现有图标；正式注册，原生界面待验收 |
| 68 | Wave / 波动 | motion_wave.png | reports/motion-items/2026-10-23/registration-v1/motion_wave-sketch.png | 从确认波体提取临时彩色图标，独立16px墨色转换；原生界面待验收 |
| 69 | Dragon Punch / 升龙 | motion_dp.png | reports/motion-items/2026-10-23/registration-v1/motion_dp-sketch.png | 从确认火焰提取临时彩色图标，独立16px墨色转换；原生界面待验收 |

2026-10-02：本轮仅追加格 61/62，其他格与修改前副本像素一致；原生 ANM2 的 800 帧结构不变。资源检查和实际命令见[交付记录](../reports/batch-completion/2026-10-02-delivery.md)，不等于原生菜单已验收。

2026-10-23：四件正式招式道具注册完成，只写原先透明的68/69格；其余798格（包括66/67）逐像素不变，800帧ANM2逐字节不变。名称、临时图标复用／提取方案和本轮仅演出已获用户确认；详见[正式注册交付](../reports/motion-items/2026-10-23/registration-v1/delivery.md)。
