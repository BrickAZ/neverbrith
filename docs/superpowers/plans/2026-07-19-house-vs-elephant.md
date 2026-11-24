# 再契象实现计划

1. 在三份 items XML、三份 itempools XML、`main.lua` 名称/EID/横幅表中注册本地 ID 37；重新生成 neverbrith collectible registry。
2. 新增 `tests/house_vs_elephant_behavior_test.lua`，先固定 encounter、候选、Milk、共享三选、返回、中断与载体协调契约。
3. 在 `main.lua` 新增隔离的 `HOUSE_VS_ELEPHANT_BEGIN/END` 运行时块；复用项目 helper，避免全局 ItemConfig 扫描。
4. 为 Certificate 暴露最小 carrier suspend/restore API，并让其只在自己拥有载体时处理 -3 实体。
5. 更新 localization 与 Certificate registry 断言，运行 Lua 语法、行为测试、localization、XML 解析、neverbrith validator 与 diff check。
