# R2-Verismart-AIOS：以 DUT 为中心的敏捷验证流水线

> 32 Agent Units · 5 Verification Layers · AI-Native Closed Loop
> R2 / 01 · 2026.06

## 开场

验证不是检查环节，而是 SOC 效能的流水线引擎。在硅片不可回退的物理约束下，于设计实现之前将真实意图转化为可自动判定的可执行契约，以最低成本穷举并暴露设计与意图之间的全部偏差。

现代 SoC 设计不断攀升的复杂度，已经把传统 RTL signoff 方法推到极限，造成验证瓶颈，要求前所未有的效率与创新。这不是一句口号，而是一组冰冷的数字：根据 2018 年 Wilson Research Group Verification 研究，设计与验证工程师如今把项目总体时间的将近 40% 花在调试上——而且这一比例仍在增长。调试吞噬掉将近五分之二的项目时间，意味着每一次回归、每一次 signoff，都拖着一条越来越长的尾巴。在这条尾巴上被消耗掉的，不是机器的时间，而是人的判断力。问题因此从「工具够不够强」悄悄转向「工具之间能不能被智能地编排起来」。

验证代表了反馈，是 harness 最重要的设计，没有之一。芯片智能体生成得再快，也只加快了执行端；代码越来越便宜，判断越来越贵。若没有验证管道，AI 只是超级个体玩具——写得出来，证明不了，更签不了。人在环路里逐条给反馈，工程上扛不住；除了关键节点的人签核，剩下只能靠工具反馈。验证像一张网，网的质量决定命中的质量和效率。

投资于验证是成功的关键。虽然设计成本降低了，但如果不在验证上投入足够资源，就无法在市场上取得成功。工具百花齐放，也没自动解决可复制：计划一份、环境一份、回归一份、覆盖一份，方法散落各处。每一种验证策略都无法单独完成任务。就像瑞士奶酪模型一样，只有将各种方法结合起来，才能在可接受的概率上证明没有缺陷。验证工作的本质，是在硅片不可回退之前，把真实意图转化成可自动判定的可执行契约。直到验证被重新定义为 SOC 效能的流水线引擎，从意图声明到工程效能的五层架构，才把散落的方法与工具编织成可执行、可度量、可自动判定的反馈系统——Vplan 锁意图边界，C/DSL 契约降验证代价，七层分层与三化压对齐损耗。

这套引擎就是 R2-Verismart-AIOS：以 DUT 为中心——接口、寄存器、存储、特性；感知、记忆、交互、执行环绕它转；formal_agent、sim_agent、regr_agent 在流水线里跑。调度主语是 DUT 特征，不是今天谁有空。核心原则只有一句——Harness 之内 Agent 自主，Harness 之外人签核：Agent 跑到机械 Oracle 全绿，人只在 #30 签一个字。32 个原子任务单元，五层架构（意图→契约→架构→质量→效能），AIOS 闭环驱动。计划细法去 829，挂了怎么查去 846。这儿讲智能体验证流水线怎么围着 DUT 跑到可签。

让 AI 执行，让机器裁判，让人签核。

## 组织与转向

智能体能从工程经验中学习。记忆让后面的会话不从零开始。边做边想——构建成本归零。代码、可执行契约是最好的文档。流程是信任不够的补偿机制。品味是模型无法替代的人类价值。

模型越强 → 构建成本越低 → 边做边想 → 想清楚再做。流程是信任不够的补偿 → 必须亲手砍掉旧流程。组织从经验中学习 → 个体员工跑得更快。品味（什么值得验、何时停）是模型无法替代的人类价值。Private Agent 天花板 = 键盘前那个人。Public Agent 价值 = 组织从经验中学习。

人：签核、品味、关键 merge（#30）。AI：生成、迭代、Harness 内自主闭环。没有验证管道和 Harness，AI 只是超级个体玩具。将反馈压到分钟级——短闭环内知道对错。TDD 属性层秒级反馈，单元层分钟级，集成层小时级。

换句话说，它追求的不是「再多一个更强的工具」，而是「让已有的强工具彼此会说话」。这里的关键词是「编排」。

## 产品一句话与内核

r2-verismart 是以 DUT 为中心的 AI Native 敏捷验证流水线。它用 32 个原子 Agent 单元、5 层验证架构（意图声明 → 可执行契约 → 验证架构 → 质量内建 → 工程效能），把传统串行验证变成 AIOS 驱动的闭环收敛。核心原则是 "Harness 之内 Agent 自主，Harness 之外人签核"，以 C/DSL 可执行契约为锚点，通过 TDD 三层（集成/单元/属性）+ 瑞士奶酪模型，将逃逸概率压到趋近于零。实测 2 颗工业级 SoC、71 个 IP，2 人 12 周交付 534K 行验证通过的 RTL。

Harness 之内 Agent 自主，Harness 之外人签核。32 个原子任务单元 + 五层验证架构，以 DUT 为中心，AIOS 闭环驱动。Vicky 是 R2 芯片研发 AIOS 中的验证架构师，跑 R2-verismart-AIOS，以 DUT 为中心，驱动 32 Agent Unit × 5 层验证架构迭代收敛。Harness 内 Agent 自主跑到机械 Oracle 全绿，人只在 #30 签一个字。

中心是 DUT：Interface、Registers、Memories、Features。感知：Read Spec/RTL、Tool Search、MCP Bus。记忆：plan.yaml、knowledge/、history/。交互：人签核、Agent 协作、反馈闭环。执行：formal_agent、sim_agent、regr_agent。

2026 年 2 月发布的 Questa One Agentic Toolkit，正是对这一转向的直接回应。它建立在业界领先的 Questa One 验证方案之上，以以人为中心的智能体工作流扩展 Questa One 方案：把智能直接嵌进这些工作流，而不是孤立工具。过去，RTL Code、Lint、CDC、Verification Planning、Debug 各自是独立可执行程序，彼此之间缺乏共享上下文；工程师在它们之间来回切换、搬运结果、人工衔接。Agentic Toolkit 要做的，是用专用 Agentic AI 自主推理、规划并执行策略，让这些原本孤立的应用被智能地协同起来——同时通过关键决策点的审批控制把工程师留在环路里。

编排的核心是 Model Context Protocol（MCP），一层标准化语义层。它的作用看似朴素，影响却很深：把 Questa One 工具从独立可执行程序，变成上下文感知的参与者，向框架无关的 AI Agent 暴露实时设计状态、验证进度与工具能力。在没有这样一层语义层之前，工具是「黑盒可执行程序」——它知道自己的状态，但外部世界无从得知；AI 想要驱动它，只能靠解析输出、模拟人工点击。MCP 把这种隐式状态显式化、标准化：任何一个遵循协议的 Agent，无论是哪个厂商、哪个框架，都可以直接读取「此刻设计长什么样、验证跑到哪一步、工具有什么能力」，而不必关心工具内部如何实现。这层标准化的语义层带来两个直接后果：第一，Agent 可以是框架无关的——同一套编排逻辑不被绑死在某个 AI 平台上；第二，互操作由 MCP 促成——新工具接入编排体系，只需暴露 MCP 接口，而无需改动 Agent 侧。

## 五层与可量产单元

L1 意图声明 → L2 可执行契约 → L3 验证架构 → L4 质量内建 → L5 工程效能。成本侧：试错成本 = 影响范围 × 验证代价 × 对齐损耗。产出侧：交付价值 = 可工作特性交付率 × 硅前置信度。

【第 1 层】意图声明 (DITL 驱动) — 控制影响范围。Vplan 保证输入 + 迭代用 Vplan 验收。DITL 业务流程梳理：用户场景 → 数据流；典型一天操作序列；关键操作 + 边缘情况。事件流拆解：基本流 + 备选流；组合覆盖；场景串联。验证策略四象限：高价值/高风险 → 优先；低价值/低风险 → 自动化；左移验证 / 右移收敛。analysis：Spec/RTL/Interface/Data/Permissions 解读。design：混合/合法/非法场景规划。review：人主导准确性/精确性/完整性。交付物：Vplan · DoD 定义 · CheckList · DITL 场景列表。门禁：Vplan 评审通过 · 优先级清晰 · 迭代验收有依据。

【第 2 层】可执行契约 — 控制验证代价。C/DSL 定义 Case；配置解耦；ref model 对比。Case 用 C/DSL 等公共方式编写，避免 SV 重编译。文件参数配置，减少命令行，提升灵活性。配置与实现分离；免重编译生成 Case。C/DSL 黄金模型；输入输出逐拍比对；固件/驱动协同；硅前硅后路径对齐。#A–C：C/DSL Case 生成、配置解耦、ref model 对比 → Case 集 · 对比报告。交付物：C/DSL 测试集 · 配置化解耦环境 · 参考模型比对报告。门禁：C Case 跑通 · 配置可生成 · 比对通过。

【第 3 层】验证架构 (7 层分层 + 三化) — 控制对齐损耗。环境流程化，暴露有限接口，每个人都能做。7 层验证结构（自顶向下 · Env 与 RTL 层次一致）：场景层 → 功能层 → 驱动层 → 传输层 → 事务层 → 数据链路层 → 物理层。原则：底层模块化保通用性；中层组合保适应性；大架构变化不伤底层；跨层级无感切换。formal_agent：连通性 / 属性 (SVA)。sim_agent：directed / constrained random / scene / perf。regr_agent：全量回归/失败分析。三化——并行化：多项目并行验证；多场景同时回归；智能代理编排；测试用例并发。可复用：水平/垂直复用；跨周期/项目复用；7 层模块化设计；配置解耦。自动化：消除人工 Checklist；每日/周构建无人值守；TDD 自动回归；回归失败率<10% 门禁。#22–28 七 Agent 并行。交付物：可复用验证平台 · 标准化 Agent/VIP · 开源验证栈。门禁：7 层结构搭建完成 · 三化能力落地 · 开源栈集成通过。

【第 4 层】质量内建 (TDD+ 重构) — 提升发布能力与稳定性。重构 + 单测 + 设计原则/模式，提升发布能力与稳定性。TDD：Integration / Unit / Property。顶层集成层（系统回归）← 场景覆盖/随机测试/小时级反馈；中层单元层（组件单测）← 验证库/分钟级反馈；底层属性层（形式化 SVA）← 时序契约/不可变规则/秒级反馈。瑞士奶酪：directed+random+formal+protocol+scene+performance——定向测试、约束随机、形式化验证、协议合规、场景测试、性能验证；叠加后 → 逃逸概率趋近于零。交付物：TDD 测试集 · 重构保护网 · 活文档。门禁：TDD 三层跑通 · 回归失败率。

【第 5 层】工程效能。每个迭代用 Vplan 验收。迭代流水线：DITL 分析 → Vplan 定义 → Case 生成 (C/DSL) → 执行回归 → 覆盖率收敛 → 问题修复 → 经验沉淀 → 持续改进。四大里程碑（意图契约收敛）：M1 意图契约锁定 → M2 验证架构收敛 → M3 场景覆盖收敛 → M4 Tape-in 就绪。#29–32 四里程碑门禁。cov_agent #29：Coverage 采样——功能/代码/断言覆盖 → Coverage Report。human #30：Sign-off 审查，关键节点人签字 → Sign-off Records。learn_agent #31–32：经验沉淀；写入 knowledge/；跨项目继承 → Knowledge Base Update。

analysis #1–9 Feature 隔离；Read Spec/RTL；隔离场景/接口/数据/寄存器 → DUT Feature Matrix。design #10–13 Feature 协同；混合场景规划；事务流/异常 → Scene Coverage Matrix。review #14–16 弱点检查；准确性/精确性/完整性 → Defect List（人审）。design #17–21 DoD 定义；任务清单/工时/优先级 → Vplan · DoD。#A–C C/DSL Case 生成、配置解耦、ref model 对比 → Case 集 · 对比报告。formal_agent #22–23 连通性/属性(SVA) → Formal Report。sim_agent #24–27 directed/constrained random/scene/perf → Sim logs + Waveforms。regr_agent #28 全量回归/失败分析 → Regression Pass Rate。cov_agent #29 功能/代码/断言覆盖 → Coverage Report。human #30 Sign-off 审查，关键节点人签字 → Sign-off Records。learn_agent #31–32 经验沉淀；写入 knowledge/；跨项目继承 → Knowledge Base Update。

意图契约化 + 验证左移：用 C/DSL 可执行 Case 替代文档验收，从 IP 级就构建穿透到 SoC 的验证管道网络，逃逸概率趋近于零。

Agentic Toolkit 不是概念演示，而是带着可量产 Agent 交付可度量结果。RTL Code Agent：围绕 RTL 代码相关任务，把原本琐碎的代码层面工作流接进编排体系。Lint Agent：把 Lint 检查从「跑一遍看一堆警告」变成有目标、有上下文的智能流程。CDC Agent：跨时钟域检查本身就是高度依赖上下文的任务，恰好契合 MCP 暴露实时设计状态的能力。Verification Planning Agent：把验证规划从静态文档变成可被 Agent 推理与调整的动态计划。Debug Agent：直接切入那 40% 被调试吞噬的时间。这些 Agent 的共同特征是「目标驱动」而非「逐步指令驱动」。工程师给出目标，Agent 自主推理策略、规划路径、执行动作；而在关键决策点，审批机制让人保持在环路里。结果是可度量的，而不是轶事性的。

## 证据与调度

实测 2 颗工业级 SoC、71 个 IP，2 人 12 周交付 534K 行验证通过的 RTL。

| Phase | # | Agent | 职责 | 交付物/门禁 |
|---|---|---|---|---|
| analysis | 1–9 | analysis | Feature 隔离；Read Spec/RTL；隔离场景/接口/数据/寄存器 | DUT Feature Matrix |
| design | 10–13 | design | Feature 协同；混合场景规划；事务流/异常 | Scene Coverage Matrix |
| review | 14–16 | review | 弱点检查；准确性/精确性/完整性 | Defect List（人审） |
| design | 17–21 | design | DoD 定义；任务清单/工时/优先级 | Vplan · DoD |
| design | A–C | design | C/DSL Case 生成；配置解耦；ref model 对比 | Case 集 · 对比报告 |
| execute | 22–23 | formal_agent | Formal；连通性/属性(SVA) | Formal Report |
| execute | 24–27 | sim_agent | directed/constrained random/scene/perf | Sim logs + Waveforms |
| execute | 28 | regr_agent | 全量回归/失败分析 | Regression Pass Rate |
| execute | 29 | cov_agent | 功能/代码/断言覆盖 | Coverage Report |
| review | 30 | human | Sign-off 审查；关键节点人签字 | Sign-off Records |
| learn | 31–32 | learn_agent | 经验沉淀；写入 knowledge/；跨项目继承 | Knowledge Base Update |

调度循环（AIOS Kernel）：[1] 读 DUT tags（e.g. tags/dut-feature-aes.yaml）[2] 读验证策略 plan.yaml [3] 扫描 status=pending 且 tag 匹配的 units [4] 按 DUT Feature 组织任务流（e.g. #1–9 并行隔离 → #10–13 混合场景 → …）。调度主语是 DUT 特征，不是今天谁有空。
最有说服力的证据来自联发科。联发科工程师在数小时内达到熟练，并完成通常需要数天的任务。在所引案例中，熟练所需时间从天级变为小时级，任务时间从天级被压缩。「Questa One Property Assist 利用生成式 AI 为我们节省数周工程时间；Questa One Regression Navigator 预测最可能失败的仿真测试并优先运行，从而节省数天的回归与调试时间。」——Chienlin Huang, MediaTek。前者缩短创造，后者缩短等待——两者合起来，正是验证工程里最耗时的两头。

## 人在环路：#30

Harness 之内 Agent 自主，Harness 之外人签核。Agent 跑到机械 Oracle 全绿，人只在签核点（#30）裁决。review #30 human：Sign-off 审查，关键节点人签字。cov_agent #29 → human sign-off #30 → learn_agent #31–32。
自主不等于放任。更快推进，同时不牺牲信任与严谨。这条底线通过三重机制落地：可配置的 oversight、human-in-the-loop 审批机制、直观导向。解放的是「搬运与等待」，保留的是「判断与签核」。控制权仍以工程师为中心——这正是「以人为中心的 Agentic AI 工作流」的真正含义。把工程师从重复任务中解放出来，同时保留人的 oversight，以实现可信的设计收敛。

## 支撑、调试邻域与收束

支撑层 — 组件化一切：可复用 agent / sequence / assertion / VIP；design pattern / split pattern；testcase / env / build / verification 管理。持久化存储 — AIOS 记忆：plan.yaml · units/ · deliverables/ · tags/ · history/ · knowledge/ · milestones/。Private Agent 天花板 = 键盘前那个人。Public Agent 价值 = 组织从经验中学习。DUT 交付侧：交付 → 设计 / 软件 / 硬件团队。交付物：Feature List · Interface 定义 · Register 描述 · 时序约束。反馈闭环：Coverage 空洞 → Regression 失败 → Sign-off 问题 → 驱动 DUT 变更。

自动对失败签名分桶：把成千上万条失败按特征归类，让根因分析从「一条一条看」变成「一类一类查」。定位导致失败的设计与 testbench 要素。隔离引入回归失败的源代码提交。调试层级因此被整体抬高——人不再陷在波形里数信号，而是在更高抽象层上做判断。

计划细法去 829，挂了怎么查去 846。

验证经理与总监——关心团队生产力如何可适应、可扩展地提升。RTL 设计与验证工程师——关心自己会不会被工具替代，答案是「不会，但会被重新定位到判断层」。SoC 架构师与集成工程师——关心 signoff 流程如何跨团队协同。正在探索 AI 驱动验证的工程师——关心这套架构能否与已有的 AI 工具链共存。

从孤立应用到智能编排，从黑盒可执行程序到上下文感知的参与者，从逐步指令到目标驱动——给出的不是又一颗更快的引擎，而是一条务实的路径：更可适应、可扩展的生产力，更快推进，同时不牺牲信任与严谨。把 AI 摆在了正确的位置——自主跑重复劳动，把人留在需要判断的地方，并用一层标准化的语义层让这一切可以被审计、可以被信任。

让 AI 执行，让机器裁判，让人签核。
