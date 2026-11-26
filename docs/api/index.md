# 本发布分支的公共接口入口

此分支发布 Isaac Skill、退役副本和必要检查入口，模组运行代码保持其 Git 基线。工作区中的公共库拆分及 callback 布局重构未包含在此次 Skill 发布中。

当前代码可用的对外接口以[兼容指南](../../COMPATIBILITY.zh-CN.md)为入口，并核对 [main.lua](../../main.lua) 与[项目地图](../agent/project-map.md)定位的实际拥有者。不要从另一个 checkout 的 `scripts/runtime`、`scripts/systems` 名称推断本分支已经实现对应模块。

新增或修改公共库必须按[开发规范](../agent/development-conventions.md)在同一批交付源码、真实消费者、详细使用说明和检查，并将其真实模块加入本索引。后续整合模块重构时，应同时合并该重构自带的逐模块 API 页面；本页不代替那些接口合同。
