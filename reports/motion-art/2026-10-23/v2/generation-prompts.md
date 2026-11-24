# 图像生成提示词

工具：内置`image_gen.imagegen`，三次均`transparent_background=true`。没有使用CLI/API备用方式。原始生成PNG逐字节保存于`source-images/`，游戏侧副本位于`resources/gfx/Effects/MotionShowcase/v2/`；实际尺寸和非均匀摆放按解码后Alpha发现，不以提示词的网格尺寸为事实。

## 人物动作表

支持参考图：`E:/Isaac - Repentance/resources/gfx/characters/costumes/character_001_isaac.png`。原生贴图只作为人物和风格参考。

```text
Create a game-ready sprite atlas for a Binding of Isaac mod, using the attached vanilla Isaac atlas only as style and character reference. Deliver a transparent RGBA PNG at 1024x768. EXACTLY a 4 column x 3 row regular grid of 256x256 cells. No labels, no text, no gridlines, no backdrops, no FX. Each cell contains ONE complete Isaac, bald pale pink naked chibi tearful Isaac with the same huge round head, tiny torso, tiny legs, black pixel outlines, three flat skin shades, pixel art suitable for nearest-neighbor reduction to 64x64 per cell. Preserve recognizable Isaac, no fighter clothing, no hair. Every sprite centered horizontally in its cell, feet baseline y=224 relative to cell, all head and raised hands stay inside the cell with 16px margins, no neighboring cells overlap. Cell order row-major: 1 facing right crouching with right fist pulled low near hip, left arm guarding, bent knees, preparation for uppercut; 2 facing right fierce rising uppercut, RIGHT arm fully extended upwards beside head, fist highest, left fist near waist, one knee raised and other leg extended down, unmistakably punching; 3 facing right peak of flaming shoryuken pose, same raised fist silhouette but arched torso and both feet off ground, no fire; 4 facing right landing from uppercut, one knee down, lowered fist. Row2 four wrestler grip poses WITHOUT victim: 5 front view both arms clasped tightly around an imaginary waist just in front of head/chest, squat legs spread; 6 right side view same grip with forearms forward, squat legs; 7 back view same grip with bald back of head and back torso, bent elbows outside head; 8 left side same grip. Row3: 9 front view dramatic super intro with BOTH arms raised high and spread in V, open palms, standing legs apart; 10 front view flexing both biceps fists at head height, confident determined eyebrow expression; 11 facing right hadoken push, both hands pushed together forward at chest height, deep grounded stance, torso leans forward; 12 facing right cupping a small imaginary ball at the waist with BOTH palms, deep bent legs, hadoken windup. These are precisely posed character sprites, not a scene. No actual energy balls, swords, shockwaves, accessories, shadows or enemies. Crisp deliberate pixel art, limited palette, genuine alpha-zero outside silhouettes.
```

输出：`exec-f553cb1a-5080-441a-b365-38830fe29b3e.png`，实际1448×1086。逐组件取12个姿势，使用独立脚底锚点。

## 波动四帧

```text
Game sprite atlas: four Hadoken energy projectile animation cels for a Binding of Isaac pixel art mod. Transparent PNG. Exactly 4 equally spaced columns, single row, one isolated blue projectile per cell. All projectiles travel RIGHT. Each has a rounded convex luminous spherical leading edge on the RIGHT, a bright white-cyan core with swirled churning BLUE energy, and a ragged flowing tapering blue flame tail stretching toward LEFT. Clear recognizable Street Fighter Hadoken silhouette, never a blade, never a sword crescent, no circular rings, no sharp front tip, no lightning loops. Four cels vary the flame billows and tail turbulence modestly but keep the same size, centerline and rounded leading edge position. Each occupies approximately 80x42 pixel art logical resolution but output large. Hand-crafted crisp chunky pixels, limited palette 7 blues from dark blue outline to almost white. No characters, no floor, no text, no labels, no grid or borders, no opaque rectangular backing, no glow spreading outside the sprite. Separate complete sprites with ample transparent margins, true alpha outside energy silhouettes. All four have the exact same side-view orientation.
```

输出：`exec-2b4bbf91-059a-4fd3-9846-42195d7fa72f.png`，实际2172×724。

## 升龙火焰四帧

```text
Transparent pixel-art sprite atlas for a Binding of Isaac mod: exactly FOUR separate vertical fire aura animation cels arranged in a single horizontal row, ample transparent gaps. No labels, no text or grid. Each cel is a continuous upward-rushing orange/yellow flame plume shaped to wrap a rising uppercut: broad turbulent orange billows around the lower third, tapered curling side tongues along the torso, the top reaches an upward punch fist; coherent connected fire from base to tip, never a stack of separate balls or dots, no rings, no sword-shaped slash. Broadest part around bottom-middle, leaning subtly right as it rises. White-yellow hot core with uneven holes of real transparency through the middle to let the character show behind it. Orange/red edges and dark reddish single-pixel outline, chunky limited-palette Isaac-like pixel art, NOT smooth bloom or realistic fire. Each cel approximately 28 wide x 60 high logical pixels, shown at large output resolution. Four time cels have same height and center, slightly flickering silhouettes. ONLY fire, no hands, no people, no ground, no shadow, no opaque background. Real RGBA alpha outside and inside the open holes.
```

输出：`exec-f9e5e2ff-f7b0-4fa2-aa71-5dfc2359ca04.png`，实际尺寸以PNG解码与manifest SHA-256为准。第一次使用原版火泪叠放形成分离火点，离线查看后已在本轮最终候选中换为连续火焰表；没有作为另一套正式资源保留。
