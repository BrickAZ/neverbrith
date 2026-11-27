# 固定恢复场景性能结果

2026-11-27（Europe/Warsaw）。使用最终 package-03 与本轮冻结工作区基线，原生 recovery_flow 场景；两组各有旧新 150/0 断言。

预设方法、阈值和计时分辨率见 [performance-method.md](performance-method.md)。每次跳过前 60 更新，固定测量 61..1085；POST_UPDATE 1025 样本、玩家效果更新 1024 样本，场景 SUMMARY 即冻结。

| 组 | 窗口 | 基线均值 ms | 候选均值 ms | 基线 / 候选 p95 ms | 基线 / 候选最大 ms |
| --- | --- | --- | --- | --- | --- |
| 1 | post_update | 0.560976 | 0.537561 | 1 / 1 | 4 / 6 |
| 1 | player_effect_update | 0.062500 | 0.054688 | 1 / 1 | 2 / 2 |
| 2 | post_update | 0.527805 | 0.480000 | 1 / 1 | 7 / 8 |
| 2 | player_effect_update | 0.062500 | 0.045898 | 1 / 0 | 2 / 2 |

每次扫描 62 次、保存 34 次；除以 1025 更新后两侧完全相同。两轮均未超过预先规定的均值/p95调查门槛，也没有增加扫描/保存率。均值变化不作为性能改善结论。

有无计时的原生断言轨迹逐条一致，见 [instrumentation-equivalence.json](instrumentation-equivalence.json)；这证明本场景观察保持，不证明探针零开销。整数毫秒量化下校准 0 只表示低于分辨率。窗口包含其他启用 Mod，不覆盖整个引擎帧、渲染、多人、高实体/特效及全部换房/保存/沙漏峰值。

实际命令均使用 C:/msys64/ucrt64/bin/python.exe：

- `compare-native.py recovery-baseline-bounded-01 recovery-candidate-bounded-01 --require-performance --output performance-comparison-01.json`：退出 0。
- `compare-native.py recovery-baseline-bounded-02 recovery-candidate-bounded-02 --require-performance --output performance-comparison-02.json`：退出 0。
- `instrumentation-equivalence.py`：退出 0。

[第一组](performance-comparison-01.json) / [第二组](performance-comparison-02.json)保留全部指标、阈值、归一化率和原始 attempt。探针及比较器修正与反例见 [工具交付](control-ownership/report-tools-delivery.md)。
