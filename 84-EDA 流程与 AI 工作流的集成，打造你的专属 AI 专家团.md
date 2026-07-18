# EDA 流程 × AI 工作流集成方案（V2.0 终稿）

**——专属 AI 专家团构建：技术团队落地执行手册**

工具链：Synopsys（VCS / DC / PT / ICC2 / Verdi / Formality）｜ 流程基座：三刀法 + DITL 切分 + 短闭环 PPA 优化 ｜ 运行时：Claude Code Dynamic Workflow

---

## 一、立论：每条架构决策都有已验证的证据，不赌方向

本方案是两版草案经四轮迭代对比后的收敛稿，所有关键取舍均可溯源：

1. **工具接入走"薄 wrapper + CLI"，不走 naive MCP。** 2026 年证据链已收敛：全量注入工具 schema 时，接 10 个服务器即烧掉 40k–150k tokens，工具数超约 20 个 Agent 准确率从 90%+ 崩至 13.62%；MCP 浏览器控制 2–4 秒 vs CLI 封装约 100ms。活下来的是 disciplined tool access——轻量、按需加载、可审计。EDA 场景 log 巨大、license 昂贵、调用频繁，token 效率与可审计性是生死线。
    
2. **流程骨架复用三刀法，不从绿地重建。** 团队已有想清楚的"特性隔离 → 短闭环优化 → 端到端对齐"方法论和成熟 Tcl/Python 胶水代码。让 AI 把已解决的问题再解决一遍，本身就是最大的试错成本。AI 的角色是**执行者和放大器**，不是流程发明者。
    
3. **反馈信号必须来自 signoff 级工具。** 初版草案曾假设用 Yosys 做短闭环 PPA 代理——已否决：开源综合与 DC 的 PPA 相关性不可靠，AI 朝错误反馈信号全速优化是最高危失败模式。短闭环直接跑 DC 小模块综合（分钟级，够"短"）。
    
4. **多智能体规模受红线约束。** ChatDev 多 Agent 协作成功率 67%→33%，AppWorld 45%→6%。专家编制收敛为 3+2，专家间禁止自由对话，协作必经确定性门控。
    
5. **运行时选 Claude Code Dynamic Workflow，设计规范用 PocketFlow 三原语。** 并发调度、中断恢复由托管运行时负责，省下自研成本；每个 phase = 一个 Flow、每个子 Agent = 一个 Node（prep 读状态 → exec 调 wrapper → post 写状态），中间结果全部落盘文件，不进主上下文。
    

## 二、总体架构：五层模型

┌────────────────────────────────────────────────────────────┐  
│ L5 治理层   凭证管理 · 调用审计 · 成本看板 · 人工签字卡点     │  
├────────────────────────────────────────────────────────────┤  
│ L4 编排层   DW 主脚本（三刀法 DAG）→ 派生子 Agent → 门控裁决 │  
├────────────────────────────────────────────────────────────┤  
│ L3 专家层   3 专家 + 2 裁决（§三），均为标准 Node            │  
├────────────────────────────────────────────────────────────┤  
│ L2 工具层   wrapper：r2-dc-syn / r2-pt-report / r2-vcs-sim / │  
│             r2-fm-sec / r2-log-triage / r2-verdi-dump ...    │  
├────────────────────────────────────────────────────────────┤  
│ L1 状态层   文件系统：INDEX.md + state/*.json + checkpoints/ │  
│             + reports/ + workflows/ + wrappers/              │  
└────────────────────────────────────────────────────────────┘

核心原则：**显式状态优于隐式上下文**——一切中间状态文件落盘，支持人类 review、git diff、auto-research 迭代；**结构化优于文本**——wrapper 输出 JSON 摘要 + 原始报告路径，AI 只做决策不做解析；**复用优于重写**——存量胶水代码加薄层转结构化接口继续使用。

## 三、AI 专家团编制：3 + 2

第一阶段只建五个角色，全部为标准 Node，角色间不直接对话，一切经状态文件传递，由主脚本路由：

|角色|职责|工具白名单（≤8）|挂载规则|
|---|---|---|---|
|E-RTL 设计专家|RTL 编写/重构、三段式 FSM、复位策略、Stub 生成|lint-check, cdc-check, diff-apply, rtl-fmt|rtl-coding-checklist、阻塞/非阻塞决策树、三段式 FSM、复位设计指南|
|E-PPA 优化专家|短闭环核心：读基线 → 建议下一组综合/约束参数|dc-syn, pt-report, qor-diff, area-speed-est|面积速度权衡框架；只建议参数，不判收敛|
|E-DEBUG 专家|仿真失败分类、波形定位、反例最小化|vcs-sim, verdi-dump, log-triage, urg-cov|定位→假设→验证三步法；结论结构化入案例库|
|O-ORACLE 门控|确定性判定：收敛、QoR 门、lint/cdc 零 waiver|converge-check, golden-diff, checklist-run|纯脚本判定，无 LLM 自由裁量|
|O-ADV 对抗审查|专挑毛病：边界条件、X 传播、时钟域、安全态|cdc-check, xprop-run, formal-lite|对抗 checklist；一票回退权|

**编制纪律**：每个专家工具 ≤8（实测 5–15 最佳区间的下半段，留扩展余量）；E-RTL 产出必须过 lint+cdc 零 waiver 门；E-PPA 每轮建议须附"上一轮决策理由"写入状态文件；新增角色需评审——堆角色是负优化，不是扩展。

## 四、工具层：wrapper 五条硬规范

每个 wrapper 是一个薄脚本（封装存量 Tcl/Python），统一约定：**输入明确 schema，输出 ≤2KB JSON 摘要 + 原始文件落盘路径**。示例：

./wrappers/dc-syn --top core_alu --corner ss --effort high  
# → {"wns":-0.12,"tns":-4.3,"area":18234,"power":85.2,  
#    "qor":"/reports/run_8813/core_alu.qor.rpt","db":"/checkpoints/knife2/core_alu.ddc"}

1. **惰性加载**：工具定义不进系统提示词，专家运行时 `--list` / `--help` 自查（实测省 96–99% tokens）。
    
2. **log 不进上下文**：wrapper 只回摘要；需细节用 `log-triage --grep` 按需取片段。
    
3. **零内置凭证**：license/集群凭证走环境变量 + 短时 token，禁止静态密钥落配置（postmark-mcp、Smithery 泄露 3000+ 凭证是前车之鉴）。
    
4. **只读优先**：写操作（r2-diff-apply、r2-eco-apply）必须携带 Oracle 签发的任务令牌，支持 dry-run。
    
5. **单测覆盖**：每个 wrapper 配单测与真实样本回放——80% 的"AI 失败"是工具问题；工具描述重写曾把成功率从 34% 拉到 100%。wrapper 质量是本方案第一优先级工程。
    

## 五、状态与记忆层：文件即共享存储

/project_root/  
├── INDEX.md                 # 人类可读总览：当前刀、PPA 基线、待办  
├── state/  
│   ├── global.json          # 仅主脚本写：刀序、目标、冻结标记  
│   └── modules/<mod>.json   # 仅该模块子 Agent 写：边界、基线、尝试史  
├── checkpoints/             # .ddc / 仿真快照，按刀与模块分目录  
├── reports/                 # 结构化 PPA 历史、迭代 summary  
├── workflows/               # DW 编排脚本（git 管理，可复用模板）  
└── wrappers/                # 工具薄封装 + 单测

三条状态纪律：

- **多 writer 结构**：global.json 只有主脚本写，模块文件只有对应子 Agent 写——从结构上消除 16 路并发下的锁竞争（初版单文件 + 锁的方案已否决）。
    
- **上下文四层管理**：寄存器（本轮中间态，任务结束即弃）/ 缓存（编码规范、SDC 约定、waiver 清单，启动预加载）/ 内存（裁决历史，超限遮蔽旧输出——比摘要省一半成本）/ 磁盘（log、波形、报告，永不预加载，按需取回）。实测 40 分钟 Agent 运行中 84% 上下文从未被再次访问。
    
- **知识沉淀**：Debug 专家每次定位结论入历史 bug 案例库；收敛的 workflow 脚本参数化后跨项目复用。
    

## 六、三刀法落地：流程与门控

**第一刀：特性隔离 + DITL 切分 + Stub 生成** 主脚本派子 Agent 并行处理各模块切分，E-RTL 生成 Stub 与接口边界，写入 `state/modules/*.json`（边界、依赖、stub 路径）。出口门：O-ORACLE 校验边界一致性 + lint 零错；O-ADV 抽查时钟域与接口假设。主脚本依裁决决定进第二刀或调整切分。

**第二刀：短闭环 PPA 优化（核心迭代层）** 每模块一个闭环：`读基线 → E-PPA 建议参数 → r2-dc-syn / r2-pt-report → 结果落盘 → r2-converge-check 判定`。

- **收敛判定必须是脚本**：`r2-converge-check` 做阈值判定（WNS/area/power 达标，或连续 N 轮改善 <ε 即冻结）。LLM 只在未收敛时提下一组参数——把"是否停"从 AI 手里拿走，是本方案对抗幻觉的第一道闸。
    
- 每轮迭代生成 summary 落盘（参数、PPA 变化、决策理由），支持人类 review 与 auto-research。
    
- 并发上限 16 路（DW 实测约束），按模块 Map 分片，结果进 Store 汇总。
    

**第三刀：端到端对齐 + Hierarchy-Preserving 综合** 主脚本按第二刀冻结结果生成最终编排：组装优化后模块，DC 层次化综合 + Formality SEC 等价验证 + PT 全芯片时序。出口门：SEC 零差异、时序达标、INDEX.md 锁定最终 PPA 基线。

**编排纪律**：每环出口必有确定性校验（lint 零错 / 收敛达标 / SEC 通过），用脚本把每环准确率钉死——多环节按 95%/环衰减，五环只剩 77%，门控是唯一的对抗手段。流程调整只改 workflows/ 脚本（版本化），不改专家 prompt：改 spec 比改代码划算。

## 七、安全与治理

- **人在回路三个签字点**：Spec 冻结、网表 freeze、ECO 入主干。AI 是生产力倍增器，不是 signoff 责任人；ICC2 物理实现操作一律人审后执行。
    
- **供应链**：wrapper 自研、钉版本、哈希校验；外部组件引入需安全评审（工具投毒攻击成功率实测约 73%）。
    
- **审计**：全部 wrapper 调用记录（谁、何时、参数、结果哈希）；license 与 token 消耗按项目入看板。
    
- **auto-research 加闸**：迭代子 Agent 读 INDEX.md + 最新 summary 提的改进建议只进待办区，进 workflow 主干必须人工 merge——保留自我迭代能力，锁死发散风险。
    

## 八、路线图：先验地基，再动工

**第 1 周｜地基校验（零试错的关键一周）** ① 建目录结构与 state schema（§五原样可用）；② 选 1 个试点模块（建议：有历史人工优化数据的模块，基线现成）；③ 封装 dc-syn / pt-report / log-triage 三个 wrapper 并配单测；④ 若仍想保留开源快迭代通道，本周做一次 Yosys-vs-DC PPA 相关性实验并记录结论，相关性差即弃。**出口：wrapper 单测全绿 + 试点模块基线数据入库。**

**第 2–4 周｜短闭环打通** 单模块短闭环 PPA 优化全流程跑通；O-ORACLE 收敛判定接管；每轮 summary 落盘。**验收（对比该模块人工历史基线）：达到同等 PPA 的迭代周期 ≤ 人工的 50%，最终 WNS/area/power 不劣化。**

**第 5–8 周｜三刀法全流程** 扩展至三刀完整链路；O-ADV 对抗审查接入；auto-research 带闸上线；Debug 专家接入仿真失败分类。**验收：切分后多模块并行优化总周期 ≤ 原串行流程 50%；失败分类准确率 ≥80%（以人工复核为准）；RTL 返工轮次 ≤2。**

**第 9 周起｜按数据扩展** 视前两阶段数据决定是否解冻综合/实现方向更多专家角色；向 signoff 环节延伸（ICC2 保留人审）；workflow 模板跨项目复用。

## 九、风险登记与不做清单

|风险|对策|
|---|---|
|wrapper 质量差导致误判|第一优先级工程：单测 + 真实样本回放，未全绿不进闭环|
|AI 幻觉穿过门控|门控全部脚本判定，LLM 无判定权；O-ADV 一票回退|
|反馈信号失真|第 1 周相关性实验兜底；信号源只用 DC/PT/Formality|
|license/算力失控|并发 ≤16 + 看板限额 + 回归去重|
|自我迭代发散|auto-research 人工 merge 闸|

**不做清单**：不做物理实现自动化（仅报告解读与 ECO 建议）；不上重型 Agent 框架；不上全量 MCP；不上单文件共享状态；专家不超过 5 个（第一阶段）；不用开源工具数据做优化决策依据。

## 十、一句话总结

**用薄 wrapper 把 Synopsys 工具链变成省 token、可审计的专家双手，用文件状态落盘让每一步可 review，用三刀法承载流程、DW 承载运行时、PocketFlow 三原语承载设计规范，用确定性门控和对抗审查锁死幻觉与多智能体负效果——第一周先验地基，八周内见到缩短一半的迭代周期。**