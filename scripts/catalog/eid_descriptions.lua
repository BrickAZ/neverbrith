return function(Items, yinExplosionApiReady)
local EID_DESCRIPTIONS = {
    [Items.DriveGlove] = {
        en_us = { name = "Drive Glove", eidDescription = "6 Drive bars, independent of active charges#Move away from incoming attacks to guard; 1 bar per half heart#Hold Active: immobile blue parry, cannot shoot; costs 0.5 + 0.3/sec; ordinary parry returns 0.5#First 3 frames: Perfect Parry refills Drive and grants a shooting reward#Release within 6 frames after a parry: no recovery; otherwise 12 immobile frames#Press a movement direction during parry: spend 0.5 for a turning Drive Rush#Reverse after 4 movement frames to brake; shooting after 5 cancels rush#Rush/Perfect: one full charge, then 4 tears/sec for 3 seconds from your first shot; oldest reward only#Kills restore 1; natural recovery 0.1/sec, walking +50%#Empty Drive: damage and tears x0.75 until full; 20 seconds natural recovery#Blue parry excludes bombs and life payments; normal guard also excludes contact, lasers, floor and sourceless damage#Actual injury during rush deals double damage and stops it; shields do not" },
        zh_cn = { name = "斗气拳套", eidDescription = "独立6格斗气，不使用普通主动充能#朝攻击来向的后方按移动进行普通防御，每半心扣1格#按住主动键蓝防：不能移动或射击，启动0.5格，持续每秒0.3格；普通蓝防成功回0.5格#启动前3帧完美蓝防：斗气回满并授予射击奖励#成功后6帧内松手免后摇；其余松手进入12帧不能移动或射击的后摇#蓝防中按下移动方向立即绿冲，额外消耗0.5格；冲刺可平滑转向#移动满4帧可反向刹车，满5帧可射击取消#绿冲或完美蓝防：一次满蓄力，首次实际射击起3秒内射速至少4.0；重复保留最早奖励#击杀回1格；自然每秒回0.1格，有输入且实际行走加快50%#斗气归零力竭：攻击与射速乘0.75，满槽解除；自然20秒回满#蓝防不能挡炸弹或生命代价；普通防御还不能挡接触、激光、地板及无来源伤害#绿冲实际受伤翻倍并中断；防御和其他护盾挡住可继续" },
    },
    [Items.Blinky] = {
        en_us = { name = "Blinky", eidDescription = "Hold Active: absorb obstacles and ground pickups in a 30-degree cone; range follows your range stat#Ctrl + Active: open storage; arrows select; Active spits forward#Infinite storage for this run, including Continue and Glowing Hourglass; prices and independent choice items are preserved#Close press: 20% damage melee and permanent Wounded mark#Suction deals 50% damage to Wounded enemies every 15 frames; only suction kills store one red heart#Rock: 5 + 20% damage; poop: 2 + 30% damage and four half-damage droplets on hit#Chests: 20 damage and open once; spikes: three nail tears; TNT: 40 explosion damage; fireplaces: Bird's Eye flames#Tinted rocks break instead; giant poop cannot be absorbed; shopkeeper corpses give no drops" },
        zh_cn = { name = "凸眼鱼", eidDescription = "按住主动键：吸取前方总宽30度内的障碍和地面物品，距离随射程增加#Ctrl+主动键打开储物清单；方向键选择，主动键朝面向吐出#本局无限储物，继续游戏和发光沙漏保留；价格及同组选项独立保留#贴近时按下改为20%攻击力近战，永久标记受创#吸取对受创敌人每15帧造成50%攻击力伤害；仅吸取击杀存入一颗红心#石头：5+20%攻击；大便：2+30%攻击，命中分裂四颗半伤害粪滴#箱子：20伤害并开一次；尖刺：三根钉子；TNT：40爆炸伤害；火堆：鸟眼火焰#X石只破坏，巨型大便不可吸取；店主尸体无掉落" },
    },
    [Items.BombSuit] = {
        en_us = {
            name = "Bomb Suit",
            eidDescription = "After actual damage: +0.5 speed, cannot shoot, and immune to damage for 3 seconds#Then explode at your position using your current ordinary bomb damage and effects; the explosion cannot hurt you#Blood donation machines, IV Bag and Devil Beggars still hurt and never trigger this item#Extra copies do not stack; the timer does not refresh#The fuse follows you between rooms; death, item loss or exiting cancels it#Glowing Hourglass rewind cancels the fuse",
        },
        zh_cn = {
            name = "炸弹套装",
            eidDescription = "实际受伤后，3秒内移速+0.5、无法射击，并免疫除卖血外的伤害#随后在自身位置爆炸，沿用当前普通炸弹的伤害及特效；此次自爆不伤自己#献血机、IV袋、恶魔乞丐正常扣血，且不触发效果#多份不叠加，倒计时不刷新#换房继续倒计时；死亡、失去道具或退出时取消#发光沙漏回溯会取消状态",
        },
    },
    [Items.DivineLeftHand] = {
        en_us = { name = "Divine Left Hand, Demonic Right Hand", eidDescription = "Copies the last normally acquired collectible that is still held#Only passive items and familiars are eligible; a last active item makes use fail#All copies created by this item expire on the next floor#Does not grant one-time pickup resources#Failed use does not consume charge" },
        zh_cn = { name = "神的左手，恶魔之右手", eidDescription = "临时复制最后正常取得且仍持有的道具#只接受被动或跟班；最后取得的是主动时使用失败，不回溯#此道具创建的所有临时份数在下一层移除#不发放首次拾取资源#使用失败不消耗充能" },
    },
    [Items.EchoBaby] = {
        en_us = { name = "Echo Baby", eidDescription = "Spectral shooter: 3 damage every 28 frames#Immediately grants Conjoined#After acquiring this item, each new physical baby-tagged collectible copies its complete familiar group#Each such pickup has a 50% chance for +1 permanent damage, otherwise +0.5 permanent tears#Its own tears contribution stops at 5 tears per second; excess is remembered#Copies and bonuses remain for this run after losing the item; extra copies of Echo Baby do not multiply rewards" },
        zh_cn = { name = "回声宝宝", eidDescription = "每28帧发射3伤害灵体泪弹#直接获得连体变身#取得后，新拾取的宝宝标签实物道具会复制对应的完整跟班组#每次互斥抽取：50%永久+1攻击，否则永久+0.5射速#自身射速贡献最多加到5.0；超出部分仍记录，其他突破上限来源保留#失去本道具后本局复制与属性保留；多份本道具不倍增奖励" },
    },
    [Items.GodComplex] = {
        en_us = {
            name = "God Complex",
            eidDescription = "Only usable in an uncleared hostile room; lasts 8 seconds#Randomly grants one form, never the same form twice in a row#{{Warning}} Solar: suppresses normal direct attacks; burns nearby enemies, clears nearby ordinary enemy projectiles, and reduces speed#{{Warning}} War: double damage, faster tears, and piercing tears; directly killing a normal enemy or miniboss releases 8 hostile shots from its corpse#{{Warning}} Eye: automatically judges one target; your normal direct attacks (including explosive tears) can only hurt that target; indirect effects and real bombs can still hurt other enemies",
        },
        zh_cn = {
            name = "神性过载",
            eidDescription = "仅限未清理的敌对房使用，持续8秒#每次随机获得一种神性，且不会连续获得同一种#{{Warning}} 日冕：无法常规直接攻击，近身持续灼烧并清除近处普通敌方泪弹，移速降低#{{Warning}} 战争之手：攻击力翻倍、射速提高、泪弹穿透；直接击杀普通敌人或小Boss会在尸体处产生8向敌对泪弹#{{Warning}} 独眼审判：自动处刑单个目标；自身常规直接攻击（包括爆炸泪弹）只能伤害该目标，间接特效和真正炸弹仍可伤害其他敌人",
        },
    },
    [Items.IAmAGod] = {
        en_us = {
            name = "I Am a God",
            eidDescription = "Only usable in an uncleared hostile room#For 6 seconds: user damage x3, speed +0.30, range +4, shot speed +0.25, piercing and spectral tears#All players take double damage and lose damage invincibility frames during the declaration#This room permanently prevents heart drops and healing for everyone until the end of the floor, even after clearing or re-entering#At the end: clearing the room grants 1 golden chest; otherwise only the user takes 2 full red hearts of damage",
        },
        zh_cn = {
            name = "我即神明",
            eidDescription = "仅限未清理的敌对房使用#6秒内使用者攻击力×3、移速+0.30、射程+4、弹速+0.25，常规泪弹获得穿透与幽灵效果#宣告期间全员受到伤害×2且受伤无敌帧失效#本房本层永久不掉落生命且全员无法回复生命，清房、离开重进后仍然有效#结束时清房生成1个金色宝箱，否则仅使用者受到2颗红心伤害",
        },
    },
    [Items.HealthySleep] = {
        en_us = {
            name = "Healthy Sleep",
            eidDescription = "Spawns a bed in the starting room once per floor#A full night's sleep takes 8 hours of real time; progress stops while paused or out of the game#Hold a gameplay input for 15 frames to speed up sleep#Hold different inputs together for a greater speedup, with diminishing returns#While asleep, inputs only help you wake up sooner#Finishing sleep fully restores red hearts, then grants 3 soul hearts",
        },
        zh_cn = {
            name = "健康睡眠",
            eidDescription = "每层初始房间生成一张原版床，每层仅一次#睡眠进度需要现实时间8小时，暂停和退出时停止计时#持续按住游戏操作15帧后加速；不同操作可叠加，遵循平方根递减收益#睡眠中操作仅用于催醒#睡满后先补满红心，再获得3颗魂心",
        },
    },
    [Items.RingOfSevenCurses] = {
        en_us = {
            name = "Ring of the Seven Curses",
            eidDescription = "Only available in the starting room; disappears permanently when you leave#Permanently occupies your primary active slot for the rest of the run#Forces the Curses of Darkness, the Lost, the Unknown, and the Maze#Disables trinkets and flight; prevents sleeping in beds except Mom's Bed#{{Damage}} Damage x0.75#{{Tears}} Fire rate x0.75#{{Shotspeed}} Shot speed x1.25#{{Luck}} -5 luck#Doubles enemy health and the damage you take#Caps health at 6 hearts, keys at 2, bombs at 1, and coins at 20#Every 2 rooms, adds 1 charge to your character's built-in secondary active, if retained#Quality 4 and modded items cannot be picked up; an item you can pick up spawns beside each one#Rerolling a blocked item checks it again; active items dropped when equipping the ring do not grant replacements#Taking an item that costs hearts also adds 1 broken heart",
        },
        zh_cn = {
            name = "七咒之戒",
            eidDescription = "仅能在开局初始房间拾取，离开后永久消失#本局永久绑定主手主动栏#强制黑暗、迷失、未知、迷宫诅咒；禁用饰品栏与飞行#无法使用床，妈妈的床除外#{{Damage}}攻击力变为75%#{{Tears}}射击频率变为75%#{{Shotspeed}}弹速变为125%#{{Luck}}幸运-5#敌人生命与自身受到伤害翻倍#上限：6颗心、2钥匙、1炸弹、20硬币#每过2个房间，为保留的角色原生副手主动充能1格#品质4与模组道具保留但无法拾取，旁边生成1件可拾取道具#原底座重骰后重新判定；换下的原有主动不参与补偿#交易道具额外增加1颗碎心",
        },
    },
    [Items.MemoryDisorder] = {
        en_us = {
            name = "Memory Disorder",
            eidDescription = "Starting with the next room, entering a room turns you into a random unlocked character#Temporarily grants that character's starting items and abilities while preserving your existing build#Disguised as a random passive item no player has acquired this run; the disguise grants no item effects#Losing this item restores your original character#Once picked up, guarantees a Void portal after eligible endgame encounters for the rest of the run: Boss Rush, Hush, Mega Satan, and the final Greed Mode boss room",
        },
        zh_cn = {
            name = "记忆紊乱",
            eidDescription = "从下次进房开始，每次进房都会随机变为一名已解锁角色#角色初始组件随身份临时替换；正常构筑永久保留#外观随机伪装成本局所有玩家均未获得过的被动道具，不获得所示道具效果#失去本道具会恢复原始身份#本局曾拾取后，原版有效终局节点必定提供虚空入口",
        },
    },
    [Items.KamikazeSquad] = {
        en_us = {
            name = "Kamikaze Squad",
            eidDescription = "While enemies remain, spawns a friendly Mulliboom near you every 3 seconds#Up to 2 per player at a time#They chase the nearest enemy and explode on contact#Explosions deal normal Mulliboom damage with twice the radius#Clearing the room makes all remaining squad members explode",
        },
        zh_cn = {
            name = "神风特攻队",
            eidDescription = "房间内有敌人时，每3秒在身边召唤1只友好炸弹棉花怪#每名玩家最多同时存在2只#追逐最近敌人，接触后自爆#爆炸伤害与原版相同，范围翻倍#清房时剩余成员立即自爆",
        },
    },
    [Items.Annihilation] = {
        en_us = {
            name = "Annihilation",
            eidDescription = "For 5 seconds, emit a damaging aura and replace your tears with radial shockwaves#The aura deals 40% of your current damage every 4 frames#Each shockwave deals 100% of your current damage#{{Range}} Range x0.45#{{Tears}} Fire rate x0.60#Each enemy death extends the effect by 0.3 seconds#{{Collectible356}} Car Battery: each hit during the effect adds 1 charge to both your primary and secondary active items",
        },
        zh_cn = {
            name = "诛",
            eidDescription = "持续5秒：每4帧以光环造成当前攻击力40%的伤害#泪弹替换为环形冲击波，造成当前攻击力100%的伤害#{{Range}}射程变为45%#{{Tears}}射击频率变为60%#敌人死亡会延长0.3秒#{{Collectible356}}车载电池：诛状态期间每次命中为主手和副手主动道具各充能1格",
        },
    },
    [Items.NightOfTheCowards] = {
        en_us = {
            name = "Night of the Cowards",
            eidDescription = "Grants {{Collectible20}} Transcendence#Turns normal enemies into Hosts, Red Hosts, or Hard Hosts#All enemies emit a small fear aura#You cannot shoot while inside an aura; {{Fear}} Fear appears above you",
        },
        zh_cn = {
            name = "胆小鬼之夜",
            eidDescription = "获得{{Collectible20}}超凡升天#普通敌人会变为Host、红Host或硬Host#所有敌人脚下产生小型恐惧光环#进入光环会显示{{Fear}}恐惧且无法射击",
        },
    },
    [Items.ReviveMyLove] = {
        en_us = {
            name = "Arise, My Love!",
            eidDescription = "If no other revival is waiting to trigger, your first death this run plays its full animation#After the death and revival animations, revives you in the same room with {{Heart}} 1 full red heart and brief invincibility#Consumes 1 copy without removing your other revival items",
        },
        zh_cn = {
            name = "复活吧，我的爱人！",
            eidDescription = "没有其他复活待结算时，本局首次真正死亡会完整播放死亡过程#死亡动画与复活动画结束后，在当前房间以{{Heart}}1颗完整红心复活，并获得短暂无敌#消耗1份本道具；不会移除其他复活来源",
        },
    },
    [Items.BigDogBark] = {
        en_us = {
            name = "Big Dog Bark",
            eidDescription = "Hold the active item button until fully charged, then release to send the dog dashing in your movement direction#While standing still, uses your last movement direction#Releasing before full charge cancels the attack#Higher fire rate shortens the charge time#Dash damage: 5 + 5% of the enemy's max HP + 20% of your damage#After you pick up 4 food items this run, the dog also chews enemies automatically for 10% of their max HP",
        },
        zh_cn = {
            name = "大狗叫",
            eidDescription = "长按主动键蓄满后松开，沿移动方向放狗#未蓄满时松开会取消攻击#蓄力时间随射速缩短#冲刺伤害：5+目标最大生命值5%+攻击力20%#本局实际拾取4个食物标签道具后，自动咀嚼敌人并造成其最大生命值10%伤害",
        },
    },
    [Items.WindChargeRod] = {
        en_us = { name = "Wind Charge Rod", eidDescription = "Big Dog Bark no longer needs to charge#Press the active item button to send the dog dashing opposite your movement direction#While standing still, uses the opposite of your last movement direction" },
        zh_cn = { name = "蓄风棒", eidDescription = "大狗叫无需蓄力，按下即沿移动方向反向发射" },
    },
    [Items.EchoShard] = {
        en_us = { name = "Echo Shard", eidDescription = "Big Dog Bark's dash and echo leave creep that slows enemies and deals 1% of your damage every frame#After the dash, an echo retraces its path and deals 50% of the original dash's damage" },
        zh_cn = { name = "回响碎片", eidDescription = "大狗本体冲刺与回响都会留下减速水迹，每帧造成攻击力1%伤害#冲刺结束后回响重走原路径，并造成冲刺伤害的50%" },
    },
    [Items.AvadaKedavra] = {
        en_us = {
            name = "Avada Kedavra",
            eidDescription = "Replaces your weapon with Anti-Gravity Brimstone#While enemies remain, hold fire for 1 second, then release to cast#{{Damage}} Damage x5#Fire rate does not affect charge time#At full charge, keep holding to wait or adjust your aim; releasing early cancels the cast#{{Warning}} If a completed cast directly kills no enemies, you die and cannot revive from that death#In co-op, only the caster dies",
        },
        zh_cn = {
            name = "阿瓦达啃大瓜",
            eidDescription = "攻击替换为原版反重力硫磺火#有敌人时按住射击蓄力1秒，蓄满后松键施法#面板攻击力翻5倍；蓄力不受射速影响#蓄满可持续按住并调整方向；未蓄满松键取消#一次攻击完全结束后若未直接击杀敌人，施法者死亡且本次无法复活#合作模式只杀死施法者",
        },
    },
    [Items.YinsCurse] = {
        en_us = {
            name = "Yin's Curse",
            eidDescription = yinExplosionApiReady
                and "The first quality 4 item is replaced by {{Collectible149}} Ipecac#If you held {{Collectible260}} Black Candle when you picked up Yin's Curse, Ipecac spawns beside that item instead#Blocks explosion immunity unless the damaged player currently holds {{Collectible260}} Black Candle#Other effects and general protection still apply; Black Candle does not grant immunity"
                or "The first quality 4 item is replaced by {{Collectible149}} Ipecac#If you held {{Collectible260}} Black Candle when you picked up Yin's Curse, Ipecac spawns beside that item instead#Existing explosion immunity still works; Black Candle does not grant explosion immunity",
        },
        zh_cn = {
            name = "阴的诅咒",
            eidDescription = yinExplosionApiReady
                and "首个品质4道具会被{{Collectible149}}吐根酊取代#若拾取时持有黑蜡烛，则改为在其旁额外生成吐根酊#封锁爆炸免疫，除非实际受伤玩家当前持有{{Collectible260}}黑蜡烛#其他道具效果和通用保护照常生效；黑蜡烛本身不提供防爆"
                or "首个品质4道具会被{{Collectible149}}吐根酊取代#若拾取时持有黑蜡烛，则改为在其旁额外生成吐根酊#已有防爆效果目前仍会生效；{{Collectible260}}黑蜡烛本身不提供防爆",
        },
    },
    [Items.ACEAntiCheatSystem] = {
        en_us = {
            name = "ACE Anti-Cheat System",
            eidDescription = "Doubles the damage you take#Killing a normal enemy in one hit causes severe room slowdown and 3 FPS-style stuttering for 5 seconds#{{Warning}} Killing 3 normal enemies in one hit each in the same room kills the entire team",
        },
        zh_cn = {
            name = "ACE 反作弊系统",
            eidDescription = "受到的伤害翻倍#一击击杀普通敌人：全房间严重减速并呈现低帧卡顿，持续5秒#同一房间内一击击杀3个普通敌人：全队立即死亡",
        },
    },
    [Items.ProteinStrip] = {
        en_us = { name = "Protein Strip", eidDescription = "{{Heart}} +1 heart container#Fully restores red hearts#{{Damage}} +0.15 damage" },
        zh_cn = { name = "高蛋白肉条", eidDescription = "{{Heart}} +1红心上限并补满所有红心#{{Damage}} +0.15攻击" },
    },
    [Items.EnergyKibble] = {
        en_us = { name = "Energy Kibble", eidDescription = "{{Heart}} +1 heart container#Fully restores red hearts#{{Tears}} +0.15 fire rate" },
        zh_cn = { name = "活力狗饼干", eidDescription = "{{Heart}} +1红心上限并补满所有红心#{{Tears}} +0.15射速" },
    },
    [Items.LeanCan] = {
        en_us = { name = "Low-Fat Chow", eidDescription = "{{Heart}} +1 heart container#Fully restores red hearts#{{Speed}} +0.10 speed" },
        zh_cn = { name = "轻盈低脂罐头", eidDescription = "{{Heart}} +1红心上限并补满所有红心#{{Speed}} +0.10移速" },
    },
    [Items.DHAFishOil] = {
        en_us = { name = "DHA Fish Oil", eidDescription = "{{Heart}} +1 heart container#Fully restores red hearts#{{Range}} +0.40 range" },
        zh_cn = { name = "DHA 鱼油", eidDescription = "{{Heart}} +1红心上限并补满所有红心#{{Range}} +0.40射程" },
    },
    [Items.DentalChew] = {
        en_us = { name = "Dental Chew", eidDescription = "{{Heart}} +1 heart container#Fully restores red hearts#Your tears push normal, movable enemies in the tear's direction#Each copy adds 1.25 push strength, up to an enemy speed of 4.5#Each player can push the same enemy once every 8 frames" },
        zh_cn = { name = "护齿磨牙骨", eidDescription = "{{Heart}} +1红心上限并补满所有红心#自身泪弹会沿飞行方向轻推普通可移动敌人#每份推力1.25；速度上限4.5；同一敌人与玩家冷却8帧" },
    },
    [Items.LuckyLiverBites] = {
        en_us = { name = "Lucky Liver Bites", eidDescription = "{{Heart}} +1 heart container#Fully restores red hearts#{{Luck}} +0.25 luck" },
        zh_cn = { name = "幸运肝粒", eidDescription = "{{Heart}} +1红心上限并补满所有红心#{{Luck}} +0.25幸运" },
    },
    [Items.GoatMilkPudding] = {
        en_us = { name = "Goat Milk Pudding", eidDescription = "{{Heart}} +1 heart container#Fully restores red hearts#{{SoulHeart}} +0.5 soul heart" },
        zh_cn = { name = "羊奶布丁", eidDescription = "{{Heart}} +1红心上限并补满所有红心#{{SoulHeart}} +0.5魂心" },
    },
    [Items.Everchanging] = {
        en_us = {
            name = "Everchanging",
            eidDescription = "Gives you a random appearance for the run that takes priority over ordinary costumes#Additional copies choose a different appearance when possible#Unsupported characters keep their normal appearance",
        },
        zh_cn = {
            name = "千变万化",
            eidDescription = "本局获得一套确定性的高优先级外观样式#重复获得时，在可行情况下重抽不同样式#不兼容的角色骨架保留道具但不改变外观",
        },
    },
    [Items.HouseVsElephant] = {
        en_us = {
            name = "House VS Elephant",
            eidDescription = "Single-use active item; no charge required#Enter a gallery of passive and familiar items seen on pedestals this run that nobody on the team currently holds#Separate pedestals of the same item appear as separate choices#The team may take 3 items in total; taking the third returns everyone automatically#Use the previous page, next page, and return controls to browse or leave early#If fewer than 3 choices are available, fills the remaining slots with {{Collectible25}} Breakfast",
        },
        zh_cn = {
            name = "再契象",
            eidDescription = "一次性主动道具，无需充能#进入分页特殊房，陈列本局见过且当前全队无人持有的被动或跟班道具底座#同一道具的不同底座实例会重复出现#全队合计拿取3件，第三件会自动送全队返回#使用上一页、返回、下一页机关浏览或提前离开#候选不足3件时用{{Collectible25}}牛奶补足",
        },
    },
    [Items.CertificateOfNeverbirth] = {
        en_us = {
            name = "Certificate of Neverbirth",
            eidDescription = "Reusable debug active item; no charge required#Enter a gallery of all collectibles registered by neverbrith#Take as many items as you like; switching pages resets the items on that page#Use the return control to leave",
        },
        zh_cn = {
            name = "未生证明",
            eidDescription = "无需充能且不会消失的调试主动道具#进入分页陈列全部neverbrith注册收藏品的未生陈列室#可拿取任意数量道具；每次切页都会完整重建该页#只有使用返回机关才会离开陈列室",
        },
    },
    [Items.LittleLeatherShoes] = {
        en_us = {
            name = "Little Leather Shoes",
            eidDescription = "Normal enemies can return after death: a 33% chance the first time, then 22%, then 11%#Earn Traffic, representing audience attention, when you clear a room#Traffic gained equals the highest death count in a chain of returning enemies in that room#Reach 6, 8, or 12 Traffic to unlock rewards when you clear the floor's boss room#At 12 Traffic, choose between Exposure and Heat#Traffic is settled and reset each floor",
        },
        zh_cn = {
            name = "小皮鞋",
            eidDescription = "普通敌人死亡后可依次以33%、22%、11%概率返回#清房时，按本房有效敌人链中最高死亡次数获得流量#6、8、12点流量解锁Boss结算奖励#12点奖励中的曝光与热度二选一#流量每层检查并重置",
        },
    },
    [Items.TrafficUnboxing] = {
        en_us = {
            name = "Traffic: Unboxing",
            eidDescription = "Spawns 1 normal chest after the pickup animation#Does not appear in item pools",
        },
        zh_cn = {
            name = "流量：开箱",
            eidDescription = "拾取动画结束后生成1个普通宝箱#不会出现在道具池中",
        },
    },
    [Items.TrafficExposure] = {
        en_us = {
            name = "Traffic: Exposure",
            eidDescription = "Spawns 1 collectible from the current room's item pool",
        },
        zh_cn = {
            name = "流量：曝光",
            eidDescription = "拾取时从当前房间对应道具池生成1个道具",
        },
    },
    [Items.TrafficHeat] = {
        en_us = {
            name = "Traffic: Heat",
            eidDescription = "{{Tears}} +0.5 tears per second",
        },
        zh_cn = {
            name = "流量：热度",
            eidDescription = "{{Tears}} 永久+0.5射速",
        },
    },
    [Items.EssentialBalm] = {
        en_us = {
            name = "Essential Balm",
            eidDescription = "{{Damage}} +1 damage#{{Shotspeed}} -0.2 shot speed",
        },
        zh_cn = {
            name = "风油精",
            eidDescription = "↑ +1攻击力#↓ -0.2弹速",
        },
    },
    [Items.Wuhu] = {
        en_us = {
            name = "Wuhu!",
            eidDescription = "{{Speed}} +1 speed#{{Tears}} Sets fire rate to 30 tears per second#{{Damage}} +40 damage#{{Shotspeed}} -1 shot speed",
        },
        zh_cn = {
            name = "芜湖！~",
            eidDescription = "↑ +1移速#↑ 攻速上限达到30#↑ +40攻击力#↓ -1弹速",
        },
    },
    [Items.Chunyao] = {
        en_us = {
            name = "Aphrodisiac",
            eidDescription = "1-charge active item#Take damage with a base cost of half a heart; red hearts are used first#{{Warning}} This damage cannot kill you#For 3 seconds:#{{Damage}} +0.5 damage#{{Tears}} -0.5 tear delay (faster firing)#Charm effect and homing tears",
        },
        zh_cn = {
            name = "春药",
            eidDescription = "1充能主动道具#使用后受到基础半颗心伤害#{{Warning}} 优先扣红心#{{Warning}} 不致死#{{Damage}} +0.5攻击力#{{Tears}} 射击间隔-0.5#角色进入魅惑状态#眼泪获得追踪效果#持续3秒",
        },
    },
    [Items.Musicbox] = {
        en_us = {
            name = "Music Box",
            eidDescription = "12-charge active item#Grants 20 seconds of invincibility, turns your tears red, and plays music#{{Warning}} You die when the timer ends#Using it again does not extend the timer#At 0 charge, a lethal enemy hit consumes Music Box and activates it once#While active, Plan C still damages enemies but does not kill you#You need an extra life to survive the final death",
        },
        zh_cn = {
            name = "八音盒",
            eidDescription = "12充能主动道具#使用后进入20秒无敌状态，眼泪变红并播放八音盒音乐#{{Warning}} 倒计时结束时强制死亡#第二次使用不会延长倒计时#未充能且受到致死敌人伤害时，失去八音盒并自动触发一次#八音盒期间压制计划C的自杀死亡，但保留杀敌伤害#只有额外生命可以继续游戏",
        },
    },
    [Items.Angelbox] = {
        en_us = {
            name = "Angel Box",
            eidDescription = "{{Luck}} +3 luck while held#4-charge active item#Each player's first use spawns 1 full soul heart per red heart container#After that, absorbs only soul hearts you cannot hold; 4 charges are needed per use#Later uses at full charge attempt to open an Angel Room on the current floor#If you have not entered an Angel Room this floor, the first one also contains 1 quality-4 Angel Room item#Heart pickups have a 60% chance to spawn 1 extra full soul heart#While held, converts half of your Devil Deal chance into Angel Room chance",
        },
        zh_cn = {
            name = "天使盒",
            eidDescription = "持有时 {{Luck}} +3 幸运#4充能主动道具#每名玩家首次使用：每个红心容器生成1个完整魂心#之后只吸收装不下的魂心充能，满4格可再次使用#非首次满充能使用：本层尽力开启天使房#若本层尚未进入过天使房，首次进入时额外生成1个4级天使房道具#地上心掉落有60%概率额外生成1个完整魂心#持有时50%恶魔房概率转为天使房概率",
        },
    },
    [Items.Devilbox] = {
        en_us = {
            name = "Devil Box",
            eidDescription = "4-charge active item#Each player's first use spawns 1 full black heart per red heart container#After that, absorbs only black hearts you cannot hold; 4 charges are needed per use#Later uses at full charge attempt to open a Devil Room on the current floor#If you have not entered a Devil Room this floor, the first one also contains 1 quality-3 Devil Room item#Heart pickups have an 80% chance to spawn 1 extra black heart#While held, converts half of your Angel Room chance into Devil Deal chance",
        },
        zh_cn = {
            name = "恶魔盒",
            eidDescription = "4充能主动道具#每名玩家首次使用：每个红心容器生成1个完整黑心#之后只吸收装不下的黑心充能，满4格可再次使用#非首次满充能使用：本层尽力开启恶魔房#若本层尚未进入过恶魔房，首次进入时额外生成1个3级恶魔房道具#地上心掉落有80%概率额外生成1个黑心#持有时50%天使房概率转为恶魔房概率",
        },
    },
    [Items.UncutCord] = {
        en_us = {
            name = "Uncut Cord",
            eidDescription = "50% chance to delay incoming damage#Clear 2 enemy rooms without taking another hit to pay only half of the delayed damage, with a minimum of half a heart#Taking another hit makes you pay the full delayed damage immediately",
        },
        zh_cn = {
            name = "未剪断的脐带",
            eidDescription = "受到伤害时，50%概率将本次伤害变为延迟伤害#连续通过2个房间且未再次受伤后，只承受一半延迟伤害#若期间再次受伤，立即承受全部延迟伤害",
        },
    },
    [Items.ShreddedTarot] = {
        en_us = {
            name = "Shredded Tarot",
            eidDescription = "{{Luck}} +3 luck while held#Single-use active item#Removes card pickups from the current room#Every 3 cards removed spawn 1 Treasure Room item#Fewer than 3 cards: no effect and no item consumed#Disappears at the end of the floor if unused",
        },
        zh_cn = {
            name = "剪碎的塔罗",
            eidDescription = "持有时 {{Luck}} +3 幸运#一次性使用#移除当前房间内的地上卡牌#每移除3张卡牌，生成1个宝箱房道具#卡牌不足3张时不会消耗#空拍不算使用，本层结束仍会消失",
        },
    },
    [Items.BloodSkullGu] = {
        en_us = {
            name = "Blood Skull Gu",
            eidDescription = "3-charge active item#Sacrifices 1 familiar collectible you own#{{Damage}} +1.5 permanent damage#{{Range}} +1 permanent range#Drops 1-2 black hearts#If you have no familiar collectible to sacrifice, takes half a red heart of damage instead",
        },
        zh_cn = {
            name = "血颅蛊",
            eidDescription = "3充能主动道具#献祭1个属于你的跟班类道具#{{Damage}} 永久 +1.5 攻击#{{Range}} 永久 +1 射程#掉落1-2个黑心#没有可献祭跟班类道具时，反噬并受到半颗红心伤害",
        },
    },
    [Items.BossOrder] = {
        en_us = {
            name = "Boss's Order",
            eidDescription = "3-charge active item#Spawns 1 hostile enemy#Normal enemies are drawn from the current floor; bosses are drawn from the Boss Rush pool#Normal enemies have a 15% chance to become champions after spawning#Killing the target drops cards: 1 for a normal enemy, 2 for a champion, or 3 for a boss",
        },
        zh_cn = {
            name = "老大的指令",
            eidDescription = "3充能主动道具#生成1个敌对目标#小怪来源于当前层小怪池#头目来源于Boss Rush池#小怪生成后有15%概率变为精英#击杀后掉落卡牌：普通1张，精英2张，头目3张",
        },
    },
    [Items.BetweenDeathAndLife] = {
        en_us = {
            name = "Between Life and Death",
            eidDescription = "Picking this up starts a Death Certificate trial for the rest of the run#Enemies become champions whenever possible#Bosses become champions when possible; otherwise, they are strengthened#Defeating a floor boss spawns Death Certificate#This reward can trigger once per floor",
        },
        zh_cn = {
            name = "生死一念间",
            eidDescription = "拾取后，本局进入死证试炼：#所有敌人尽可能变为精英怪#Boss也会被精英化或强化#每层击败楼层Boss后，生成一个死亡证明#每层最多触发一次",
        },
    },
    [Items.CoinSewnSword] = {
        en_us = {
            name = "Coin-Sewn Sword",
            eidDescription = "3-charge active item#Spend up to 6 coins to fire the same number of coin blades in a 150-degree fan#Each blade deals 200% of your damage#Spending 6 coins also fires a piercing empowered blade that deals 600% of your damage#With no coins, take half a red heart of damage and fire 1 blood blade that deals 400% of your damage",
        },
        zh_cn = {
            name = "铜钱剑",
            eidDescription = "3充能主动道具#消耗至多6枚硬币，向前方150度释放等量铜钱剑气#每道剑气造成攻击力 x2.0 伤害#消耗满6枚时，额外释放造成 x6.0 伤害的贯穿剑气#没有硬币时，受到半红心伤害并释放1道造成 x4.0 伤害的血色剑气",
        },
    },
    [Items.CoinFacedMask] = {
        en_us = {
            name = "Coin-Faced Mask",
            eidDescription = "Enter a room with at least 5 coins to gain a mask#The mask confuses room enemies for 3 seconds#When hit by a monster, spend 5 coins to block that hit#Without enough coins, the mask breaks and your {{Luck}} luck is reduced by 2 for the room",
        },
        zh_cn = {
            name = "铜钱面具",
            eidDescription = "拥有至少5枚硬币时，进房获得假面#假面令本房敌人混乱3秒#被怪物伤害时消耗5枚硬币，免疫本次伤害#硬币不足时，假面破裂，{{Luck}} 本房间-2幸运",
        },
    },
    [Items.BlackTaisui] = {
        en_us = {
            name = "Black Taisui",
            eidDescription = "Builds up parasite points from healing, heart containers, and damage taken#Each red heart container adds 4 points; each half red heart healed adds 1; each half red heart lost to damage adds 2#With no red heart containers: each full soul or black heart healed adds 1 point; each half heart lost adds 1#0-7 points: {{Damage}} -0.5 damage, {{Speed}} -0.2 speed, and {{Luck}} -3 luck per copy; damage cannot fall below 1 and speed cannot fall below 0.5#8-15 points: {{Damage}} -0.5 damage; reveals hidden pedestal items and suppresses the Curses of the Blind, the Lost, and the Unknown, plus Wavy Cap's side effects#16+ points: keeps the reveal and protection effects, replaces the damage penalty with {{Damage}} +1.5 damage per copy, and spawns Meat Lump once#At 16+ points, also blocks 1 lethal hit per floor, except damage from IV Bag, Devil Deals, and curse room doors#All copies share parasite points; Meat Lump is still granted only once",
        },
        zh_cn = {
            name = "黑太岁",
            eidDescription = "红心治疗、红心容器和红心伤害会积累寄生值#每个红心容器+4；红心治疗每半心+1；红心伤害每半心+2#无红心容器时：魂心/黑心治疗每整心+1；魂心/黑心伤害每半心+1#0-7：每个黑太岁 {{Damage}} -0.5、{{Speed}} -0.2、{{Luck}} -3（攻击最低1，移速最低0.5）#8-15：{{Damage}} -0.5；揭示问号道具，并压制致盲/迷途/未知和波浪帽副作用#16+：保留揭示与压制效果，取消攻击减益；每个黑太岁 {{Damage}} +1.5；生成1次肉块#三阶段本体每层可挡1次致命伤；不挡献血袋、恶魔交易和诅咒门代价#多个黑太岁共享寄生值；肉块仍只生成一次",
        },
    },
    [Items.MeatLump] = {
        en_us = {
            name = "Meat Lump",
            eidDescription = "Each copy blocks 1 lethal hit#Leaves you with a little health and grants brief invincibility#The HUD's +N counter shows how many hits Meat Lump can still block#Does not appear in item pools",
        },
        zh_cn = {
            name = "肉块",
            eidDescription = "每个肉块可抵挡1次致命伤害#触发后保留少量生命，并获得短暂无敌#HUD +N 显示肉块剩余挡死次数#这个道具不存在于任何道具池里",
        },
    },
    [Items.CleansedWavyCap] = {
        en_us = {
            name = "Cleansed Wavy Cap",
            eidDescription = "Wavy Cap purified by Black Taisui#Each use: {{Speed}} -0.03 speed and {{Tears}} -0.75 tear delay (faster firing)#Leaving the room doubles the speed penalty accumulated there and keeps 40% of its tear-delay reduction#Clearing a room removes one use's worth of these lingering effects",
        },
        zh_cn = {
            name = "净化迷幻菇",
            eidDescription = "被黑太岁净化的迷幻蘑菇#使用后：{{Speed}} -0.03移速，{{Tears}} 射击间隔-0.75#离开房间时，本房间增减益转化：移速减益x2，射击间隔减免x0.4#清理房间后，移除相当于1次使用的残留增减益",
        },
    },
    [Items.GoodGirlOfBabylon] = {
        en_us = {
            name = "Good Girl of Babylon",
            eidDescription = "At full red health, become prim and proper:#{{Tears}} -0.6 tear delay (faster firing)#{{Luck}} +2 luck#Each enemy has a 15% chance to be charmed for 3 seconds#Clearing a room without taking red-heart damage has a 33% chance to drop a Tarot card, half a soul heart, or a penny#Taking red-heart damage breaks your composure:#{{Luck}} -2 luck for the room#Frightens enemies within a radius of 120 for 2 seconds#For 5 seconds: {{Damage}} +1.2 damage and {{Speed}} +0.15 speed",
        },
        zh_cn = {
            name = "巴比伦好女孩",
            eidDescription = "满红心时进入端正状态：#{{Tears}} 射击间隔-0.6#{{Luck}} +2幸运#每个敌人有15%概率被魅惑3秒#无红心伤害清房时，有33%概率掉落1张塔罗牌、半魂心或1枚硬币#受到红心伤害时端正破裂：#{{Luck}} 本房间-2幸运#恐惧120范围内敌人2秒#获得5秒巴比伦回声：{{Damage}} +1.2攻击力，{{Speed}} +0.15移速",
        },
    },
    [Items.DebugController] = {
        en_us = {
            name = "Debug Controller",
            eidDescription = "Opens a directional debug command menu#Use again to close it#While open, shooting directions select commands instead of firing tears#Supports debug commands 1 through 13",
        },
        zh_cn = {
            name = "调试控制器",
            eidDescription = "打开四向调试命令菜单#再次使用关闭菜单#菜单打开时仅射击方向用于选择，不会发射眼泪#可执行 debug 1 至 debug 13",
        },
    },
    [Items.StrongLaxative] = {
        en_us = {
            name = "Strong Laxative",
            eidDescription = "Treats all creep as friendly#Leaves slippery creep as you move#The creep slows grounded enemies and deals a base 10% of your damage every 10 frames#Supports Aquarius-style poison, burning, homing, and Playdough Cookie effects#Proptosis triples creep damage; Ipecac uses Aquarius's damage calculation#Lump of Coal and Sulfuric Acid add neither obstacle destruction nor distance-based damage; no explosions or Godhead aura#Each copy adds a 5% chance per second to spawn random poop, up to 100%#Spawns up to 15 poops per room",
        },
        zh_cn = {
            name = "强力泻药",
            eidDescription = "所有水迹视为己方水迹#移动时留下打滑水迹#打滑水迹使地面敌人减速，每10帧造成基础10%角色伤害#继承宝瓶座式协同：中毒、燃烧、追踪及黏土饼干随机效果#眼球突出：水迹伤害×3；吐根酊：使用宝瓶座的伤害计算基数#煤块与硫酸不破坏障碍物、不增加距离伤害；无爆炸和神性光环#每个副本每秒+5%概率生成随机大便（最高100%）#每个房间最多生成15个大便",
        },
    },
    [Items.TowerOfBabel] = {
        en_us = {
            name = "Tower of Babel",
            eidDescription = "All newly spawned creep disappears immediately#Affects enemy, neutral, and player-created creep",
        },
        zh_cn = {
            name = "通天塔",
            eidDescription = "本局游戏中，新生成的水渍会立刻消失#包括敌方、中立和玩家自己的水渍",
        },
    },
    [Items.TheMoonIsBeautiful] = {
        en_us = {
            name = "The Moon Is Beautiful",
            eidDescription = "Within 2 seconds of entering an uncleared room, go 1 full second without firing tears to activate:#{{Damage}} +1 damage and {{Luck}} +1 luck for the room#Marks all enemies in the room#The first player hit on each marked enemy releases a moonlight wave for 30% of your damage#Marked enemies have a 10% chance to drop an extra reward when killed#In boss rooms, bosses take 50% more damage from player tears for the room#Activates once per room",
        },
        zh_cn = {
            name = "月色真美",
            eidDescription = "进入未清理房间后，若前2秒内连续1秒不发射眼泪：#本房间+1伤害、+1幸运#并标记本房间所有敌人#被标记敌人第一次被玩家命中时释放月光波#月光波造成30%角色伤害#被标记敌人死亡时有10%概率掉落额外奖励#Boss房中，Boss本房间受到的玩家泪弹伤害+50%#每个房间最多触发一次",
        },
    },
    [Items.BurnAwayResentment] = {
        en_us = {
            name = "Burn Away the Resentment",
            eidDescription = "First pickup: gain 2 resentment stacks#Clearing an enemy room adds 1 stack; boss rooms add 2#{{Speed}} -0.04 speed per stack, down to a minimum of 0.5; up to 6 stacks#At 6 stacks, your first direct hit in the next enemy room deals 300% of your damage to all enemies and burns them for 3 seconds#Taking damage from an enemy at 3-6 stacks instead deals 50% of your damage per stack to all enemies and burns them for 3 seconds#On the next floor, each spent or unspent stack grants {{Damage}} +0.35 damage and {{Tears}} -0.12 tear delay (faster firing)",
        },
        zh_cn = {
            name = "焚尽郁结",
            eidDescription = "首次拾取获得2层郁结#清理敌对房间+1层，头目房总共+2层#{{Speed}} 每层-0.04移速（最低0.5），最多6层#满6层后，下一间敌对房的首次直接命中：全房造成300%角色伤害并燃烧3秒#3-6层受到真实敌方伤害时：每层造成50%角色伤害并燃烧3秒#下一层中，每层已消耗或未消耗的郁结提供 {{Damage}} +0.35攻击力和 {{Tears}} 射击间隔-0.12",
        },
    },
    [Items.Needletick] = {
        en_us = {
            name = "Void Needle",
            eidDescription = "Chance to fire a void needle: 5% at 0 luck, rising linearly to 15% at 10 luck; capped at 15%#On impact or when the needle breaks, instantly kills normal enemies within a radius of 80 around that point",
        },
        zh_cn = {
            name = "虚空针尖",
            eidDescription = "0幸运时5%概率发射；随幸运线性提升，10幸运时15%（最高15%）#虚空针尖泪弹秒杀80范围内附近普通敌人",
        },
    },
    [Items.CrazyCoconut] = {
        en_us = {
            name = "Crazy Coconut",
            eidDescription = "{{Damage}} Each copy grants +3 permanent damage#After that, picking up an item from a pedestal grants another +3 permanent damage per copy if that item does not increase your actual damage",
        },
        zh_cn = {
            name = "疯狂的椰子",
            eidDescription = "{{Damage}} 每个副本永久+3攻击力#之后，从道具底座拿到的每个实际不增加攻击力的道具：每个副本永久+3攻击力",
        },
    },
    [Items.FortuneRivallingHeavenGu] = {
        en_us = {
            name = "Fortune Rivalling Heaven Gu",
            eidDescription = "{{Luck}} Raises luck to the highest activation threshold among your supported items and trinkets#Only effects with a registered luck threshold are supported#Eligible room-clear, boss, chest, beggar, and machine rewards have a 10% chance to pay out a second time#Item pedestals have a 1% chance to spawn an extra item from the same pool#Coins have a 5% chance to spawn an extra Lucky Penny",
        },
        zh_cn = {
            name = "鸿运齐天蛊",
            eidDescription = "{{Luck}} 将幸运补足至所持已登记道具中的最高阈值#合法奖励事件有10%概率额外结算一次#每个道具底座有1%概率从同一池额外生成一个道具底座#每枚硬币有5%概率额外生成一枚幸运硬币",
        },
    },
    [Items.SterilizationCertificate] = {
        en_us = {
            name = "Sterilization Certificate",
            eidDescription = "Prevents enemies from summoning more enemies#Each blocked summon damages its summoner: normal enemies take 10 + 5% of their max HP; bosses take 3 + 1% of their max HP#Boss summons are only partially suppressed",
        },
        zh_cn = {
            name = "绝育证明",
            eidDescription = "阻止会生成敌人的敌人继续生成敌人#每次阻止生成时，对源敌人造成反噬：普通敌人10+最大生命5%，Boss 3+最大生命1%#Boss 召唤效果只会被部分削弱",
        },
    },
    [Items.Condom] = {
        en_us = {
            name = "Condom",
            eidDescription = "3-charge active item#Randomly removes up to 2 baby-tagged collectibles from future item spawns#Does not remove items you already own",
        },
        zh_cn = {
            name = "避孕套",
            eidDescription = "3充能主动道具#使用后，随机禁用最多2个未来可生成的宝宝标签道具#不会移除已经拥有的道具",
        },
    },
    [Items.UtilityKnife] = {
        en_us = {
            name = "Utility Knife",
            eidDescription = "{{Damage}} +1 damage#Gain 1 broken heart on pickup",
        },
        zh_cn = {
            name = "美工刀",
            eidDescription = "↑ +1攻击力#获得一颗碎心",
        },
    },
    [Items.Cleaver] = {
        en_us = {
            name = "Cleaver",
            eidDescription = "Only works for Stranger#Replaces tears with cleaver swings#Hitting an enemy's body deals 0.5 damage and strong knockback#Hitting its past shadow deals 200% of your damage",
        },
        zh_cn = {
            name = "柴刀",
            eidDescription = "仅 Stranger 可用#眼泪替换为柴刀挥砍#砍中敌人本体：0.5伤害并强力击退#砍中过去影子：造成2倍角色伤害",
        },
    },    [Items.EmptyCradle] = {
        en_us = {
            name = "Empty Cradle",
            eidDescription = "The first time you lose health each floor, the type of heart lost is recorded#Clear that room for a reward:#Red heart: 1 full red, soul, or black heart#Soul heart: 3 pennies, 1 key, or 1 bomb#Black heart: {{Damage}} +1.0 for this floor#Taking another hit before the room is clear downgrades the reward:#Red heart: half red or half soul heart#Soul heart: no extra reward#Black heart: {{Damage}} +0.5 for this floor",
        },
        zh_cn = {
            name = "空摇篮",
            eidDescription = "每层第一次有效受伤会记录损失的心形类型#清理当前房间后获得对应奖励：#红心：1个完整红心、魂心或黑心#魂心：获得1轮奖励，3硬币、1钥匙或1炸弹#黑心：本层 {{Damage}} +1.0攻击力#清房前再次受伤会降为基础奖励：#红心：半红心或半魂心#魂心：不再获得额外奖励轮次#黑心：本层 {{Damage}} +0.5攻击力",
        },
    },
    [Items.DS4] = {
        en_us = {
            name = "ds4",
            eidDescription = "{{Warning}} Effect not implemented yet",
        },
        zh_cn = {
            name = "ds4",
            eidDescription = "{{Warning}} 效果尚未实现",
        },
    },
}

local EID_LANGUAGE_ORDER = { "en_us", "zh_cn" }

return EID_DESCRIPTIONS, EID_LANGUAGE_ORDER
end
