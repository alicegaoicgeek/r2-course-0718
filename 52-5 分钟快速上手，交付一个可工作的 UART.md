# 02 — 从小 UART 实战到 TDD 方法学

> 本篇用 UART 7O2 收发器作为最小可运行切口，完整走一遍 TDD 的真实执行过程——不是理论描述，是跑出过仿真波形的实跑记录。然后从实战延伸到 R2-TDD 方法学体系：三大难题如何映射到这个 100 行 RTL 的小项目，七不变量在这里做到了哪一步，以及从手工 TDD 到 AI 驱动 TDD 的跨度。

---

# Part 1：小 UART TDD 实战

## 1.1 为什么选 UART 7O2

讲 TDD 最怕的是选一个太简单的例子——加法器、计数器——测起来像在开玩笑，谁也感受不到"为什么需要 TDD"。也怕选一个太复杂的——PCIe 控制器——光理解协议就要三天，TDD 的节奏感全被淹没。

UART 7O2 卡在一个恰到好处的位置。

**协议参数**：50 MHz 系统时钟，921600 波特率，7 数据位，奇校验，2 停止位。帧结构是 `[start=0] [D0..D6] [parity] [stop1=1] [stop2=1]`，共 11 个位时间，一位约 1085 ns。

**为什么这个参数组合有教学价值**：

第一，波特率不是整数分频。50 MHz ÷ 921600 = 54.253...，小数部分 0.253 看起来不起眼，但如果取整成 54，到第 10 个位边界累积偏移就超过一个完整 UI——必然采错位。这逼出了 NCO（数值控制振荡器），而 NCO 是 VETO-01 一票否决项。这意味着 TDD 的测试必须能区分"取整分频"和"NCO 方案"的差异——如果测试做不到这一点，就不算有杀伤力。

第二，7O2 不是最常见的 UART 配置（常见的是 8N1），但正因为不常见，学员不能拿现成 IP 改改交差。7 位数据要正确处理奇校验（`parity = ~(^tx_data)`），2 停止位意味着 `rx_valid` 的时序锚点必须在 stop1 中心而不是 stop2 末尾——这是 VETO-05 一票否决项。

第三，TX 和 RX 是两个独立的功能域，但共享同一套波特率参数。TX 可以先做（不依赖 RX），RX 后做（依赖同步器、NCO 过采样、状态机）。这种依赖结构天然适合 TDD 的阶梯式推进：先绿 TX，再绿 RX，每一步都有可验证的里程碑。

第四，整个模块的 RTL 大约 100 行。这意味着一个晚上能从零跑完 L1 到 L2 的完整 RED-GREEN 循环，包括写测试、写 stub、实现 RTL、跑仿真、过 lint。反馈回路足够短，TDD 的节奏感才能体现出来。

## 1.2 规格三件套

项目用三份文档定义"做什么"：

|文档|职责|关键内容|
|---|---|---|
|Spec|定义行为|协议参数、模块接口、TX/RX 行为、NCO 强制要求、复位语义|
|Acceptance|定义验收边界|9 条 P0 验收项（AC-UART-01 到 09）、5 条 VETO 一票否决项|
|Timing|消除时序歧义|BIT_TIME=1085 ns、rx_valid 精确时刻（stop1 中心，单周期）、NCO 参数|

三件套的分工逻辑：Spec 定义"系统应该做什么"，Acceptance 定义"怎么算通过"，Timing 把 Spec 里的"停止位 1 中心"这种自然语言描述固化为"stop1 中心过采样点所在 clk 上升沿"——消除灰区。

**灰区固化**是这套规格的设计哲学。Spec 里凡是容易被误解的地方都标注了"灰区固化"，意思是"这一条没有解释空间，按字面执行"。比如 `rx_valid` 必须是单周期脉冲，在 stop1 中心置 1，下一拍必须回 0——Spec 里直接写了"禁止行为：rx_valid 不得多拍保持高电平"。这种精确化不是文档写得好看，是 TDD 能工作的前提：你没有精确的 Spec 就写不出精确的断言，写不出精确的断言就过不了 RED 阶段。

## 1.3 Feature Point 提取：9 条 AC → 9 级测试阶梯

验收文档定义了 9 条 P0 验收项。我们把它们映射成 9 个测试级别，按依赖关系排序：

|级别|AC-ID|测什么|RED 条件（对 stub）|GREEN 需要|
|---|---|---|---|---|
|L1|AC-BAUD-03|TX 位时间精度 ±2%|stub txd 恒为 1，无 TX 输出|TX NCO + 位状态机|
|L2|AC-FRM-01/02|TX 帧格式 + 奙校验|stub start=1, data=1111111, par=1，全错|TX 帧状态机（L1 已含）|
|L3|AC-RX-01|RX 基本接收 0x55|stub 无 rx_valid|RX NCO + 过采样 + 数据采样|
|L4|AC-RX-02|rx_valid 时点（stop1 中心，单周期）|stub 无 rx_valid|RX 状态机精确时序|
|L5|AC-RX-05|校验错检出 rx_perr|stub 无 rx_valid|RX 奇校验检查|
|L6|AC-RX-04|假起始检测（不误触发）|stub 不产生 rx_valid → **自然 PASS**|假起始检测逻辑|
|L7|AC-RX-06|表决抗噪|stub 无 rx_valid|3 点多数表决|
|L8|AC-RX-03|背靠背 3 字节|stub got 0 valid, want 3|RX 状态机连续接收|
|L9|AC-TX-01/02|TX busy + loopback|stub tx_busy never asserted|TX busy 时序 + 环回验证|

注意 L6 是个阴性测试——测的是"不该发生的事不发生"。stub 的 `rx_valid` 恒为 0，所以 L6 对 stub 自然 PASS。这符合预期：L6 测的是假起始检测的排除能力，而 stub 根本没有检测能力，自然不会误触发。这不算"测试无效"，但说明 L6 的杀伤力需要在 RTL 有 RX 功能后再验证——用故意注入假起始信号的方式确认 RTL 能正确拒绝。

## 1.4 L1 实战：RED-GREEN 全程

### 双循环结构

项目采用双循环 TDD：

- **内循环（dev_tests/）**：针对单个机制写微测试，快速验证，零证据效力。比如 `t_nco_tick.v` 只测 TX 位时间精度——拉高 `tx_start`，等 `txd` 拉低，然后逐位测量电平持续时间是否在 1085±22 ns 范围内。
    
- **外循环（harness/）**：9 级验收 testbench，第三方提供，只读不可修改。只有外循环 PASS 才算签收。
    

内循环帮你快速定位问题，外循环做最终裁决。两者的关系不是"内循环通过就放心了"，而是"内循环帮你调试，外循环确认你没骗自己"。

### 初始 RED：stub 跑 harness 全量

stub 是一个空壳模块——所有输出置安全默认值：`txd=1`（空闲电平）、`tx_busy=0`、`rx_valid=0`、`rx_perr=0`、`rx_data=0`。它通过 lint（所有信号都有驱动），但不通过任何功能测试。

跑全量 9 级测试的真实输出：

[L1] FAIL: no TX (timeout)  
[L2] FAIL: start=1, data=1111111, par=1 want 0  
[L3] FAIL: no rx_valid  
[L4] FAIL: no rx_valid  
[L5] FAIL: no rx_valid  
[L6] PASS  
[L7] FAIL: no rx_valid  
[L8] FAIL: got 0 valid, want 3  
[L9] FAIL: tx_busy never asserted  
=== 8 ERRORS ===

8 个 FAIL，1 个 PASS（L6 阴性测试）。这确认了测试框架的杀伤力——8/9 的测试能检测到"功能完全缺失"的状态。如果 stub 跑出来 9/9 PASS，说明测试框架本身有问题——测了个寂寞。

### 内环 RED → GREEN

内循环微测试 `t_nco_tick.v` 先对 stub 跑：

FAIL: no TX output

确认微测试本身有效——stub 不产生 TX，测试正确失败。

然后写最少的 RTL。L1 只需要 TX NCO + TX 状态机，不需要碰 RX。但 VETO-02 强制要求 `rxd` 必须经过两级同步器——即使 L1 不测 RX，lint 也不能放过未同步的 `rxd`。这逼出了一个工程教训：**lint 驱动基础设施**。

最初的 RTL 只写了 TX 逻辑，`rxd` 直接悬空。verilator 立刻报 `UNUSEDSIGNAL`：`rxd` 未被使用。加了同步器 `rxd_s1/rxd_s2` 之后，同步器输出 `rxd_s2` 又没人用——继续报 warning。再加边沿检测 `rxd_fall`，还是不够——`rxd_fall` 没被任何逻辑消费。最后加了一个最小 RX 状态机骨架：IDLE 状态检测到下降沿就跳到状态 1，状态 1 立刻回 IDLE。零功能，但用掉了所有信号，lint 干净。

这个过程本身就是 TDD 的体现——不是"我提前设计好了完整的架构"，而是"lint 告诉我缺什么，我加最少的代码让它过"。每一步都有明确的反馈：加同步器 → warning 消失；加边沿检测 → warning 消失；加状态机骨架 → lint 全绿。

RTL 写完后，内循环微测试对 RTL 跑：

PASS: TX bit times within +/-2%

内循环 GREEN。

### 外环验收

但内循环 PASS 不算数。只有外循环 harness 才有签收效力。跑 harness TC=1：

[L1] AC-BAUD-03: TX bit time accuracy  
  PASS  
=== ALL 1 TESTS PASS ===

L1 签收通过。

### Lint

verilator --lint-only -Wall uart_7o2.v  
=== LINT CLEAN ===

零 warning。VETO-04 通过。

### 回归验证

L1 GREEN 之后，必须确认没有破坏 stub 的 RED 状态——已有的测试不能因为加了 RTL 就意外变绿：

|检查|结果|
|---|---|
|微测试 vs RTL|PASS|
|harness TC=1 vs stub|FAIL（RED 保持）|
|harness 全量 vs stub|8 ERRORS（全红保持）|
|lint -Wall|零 warning|

这是棘轮机制：L1 的测试是一颗齿，锁住了 TX 位时间精度的正确性。后面写 L3 的 RX 逻辑时，如果改坏了 TX，L1 会立刻变红。

### L2：直接 GREEN 的合理性

L2 测的是 TX 帧格式——start 位、7 数据位、奇校验位、2 停止位。L1 实现 TX NCO 时已经写了完整的 11 拍帧状态机（start + 7 data + parity + 2 stop），所以 L2 对 stub RED 后，对 RTL 直接 GREEN。

这看起来像"跳过了 GREEN 阶段"，但实际上 L1 和 L2 测的是不同角度：L1 测的是位时间精度（每个 bit 持续多久），L2 测的是帧内容正确性（每个 bit 是什么值）。两者共享同一套 TX 逻辑，但断言目标不同。按 TDD 纪律，仍然先跑 stub 确认 RED，再跑 RTL 确认 GREEN——纪律没跳，只是 GREEN 来得快。

## 1.5 NCO 命门

这是整个项目最关键的技术决策，也是 VETO-01 一票否决项。

**问题**：50 MHz ÷ 921600 = 54.253... 个时钟周期每位。小数部分 0.253 怎么处理？

**取整方案**：每位 54 个 clk。实际位时间 = 54 × 20 ns = 1080 ns。理想 = 1085 ns。每 UI 偏差 = (1085 - 1080) / 1085 ≈ 0.46%。看起来很小？

但 UART 是连续 11 位的帧。到第 10 个位边界（stop1），累积偏移 = 10 × 0.46% = 4.6% UI。还在 ±2% 容忍范围内（注意：±2% 是单 UI 容差，不是累积容差）。

真正致命的是 RX 侧过采样。16× 过采样，理想 tick 间隔 = 54.253 / 16 ≈ 3.391 clk。如果取整为 3：

- 实际每 UI = 3 × 16 = 48 clk
    
- 理想 ≈ 54.253 clk
    
- 每 UI 偏差 = (54.253 - 48) / 54.253 ≈ **11.5%**
    
- 到第 10 个位边界累积偏移 = 10 × 11.5% = **115% UI**
    

115% 意味着什么？采样点已经偏移了超过一个完整位宽——你在采第 10 位的时候，实际采到的是第 9 位的数据。这不是精度问题，是功能错误。

**NCO 方案**：相位累加器。每个 clk 周期累加 `NCO_INC = BAUD_RATE × OVERSAMPLE = 921600 × 16 = 14_745_600`。当累加值 ≥ `CLK_FREQ = 50_000_000` 时，产生一个过采样 tick，并减去 50_000_000。

每 clk：phase += 14_745_600  
若 phase >= 50_000_000：phase -= 50_000_000，产生 1 个 os_tick

NCO 方案下，平均 tick 间隔 = 50_000_000 / 14_745_600 ≈ 3.391 clk——和理想值一致。最大误差 ±1 clk（≈ 1.8% UI），而且**误差不跨 UI 累积**——每次溢出回零都把误差清掉了。

这就是为什么 VETO-01 写的是"若实现采用简单取整过采样分频且声称/注释/报告认为'功能正确'，直接判不合格"。取整分频在低速 UART（比如 9600 baud）上可能恰好工作，但在 921600 baud 这种分数分频场景下必然崩。TDD 的测试要能区分这两种方案——L1 测位时间精度 ±2%，取整分频在 L1 可能勉强过（单 UI 偏差 0.46% < 2%），但到 L3/L4 测 RX 采样时就会暴露。

**Spec 质量放大器**：这个 NCO 问题的发现过程本身就是 TDD 价值的体现。Spec 里明确写了取整分频的后果计算——"到第 10 个位边界累积偏移 >100% UI → 必然采错位"。这不是 RTL 实现时才发现的问题，是在写 Spec 时就被定义清楚的。TDD 倒逼 Spec 精确化——如果你没有算出 11.5% 这个数字，你就写不出"取整分频必然采错位"的断言，写不出这个断言就无法在 RED 阶段排除取整方案。

## 1.6 工程教训

### iverilog 兼容性：fork/disable 不可靠

最初的内循环微测试和 harness testbench 使用了 `fork ... join_any disable` 结构来超时等待 TX 输出。iverilog 13.0 对这个结构的处理不可靠——有时正常工作，有时直接卡死触发 watchdog 超时。

**修复**：所有 fork/disable 替换为轮询 while 循环加超时计数器：

// 不可靠（iverilog 卡死）：  
fork: w1 begin @(negedge txd); gs=1; end begin #(BT*15); end join_any disable w1;  
​  
// 可靠（轮询替代）：  
to=0;  
while (txd!==1'b0 && to<2000) begin @(posedge clk); to=to+1; end

这不是"代码风格选择"，是"工具链约束驱动实现方式"。TDD 的反馈回路在这里体现为：写测试 → 跑 → 卡死 → 定位到 fork/disable → 换轮询 → 跑 → 绿。从卡死到修复大约 15 分钟，因为反馈足够快（仿真几秒就超时），定位足够准（只有 fork/disable 那段可疑）。

### lint 驱动基础设施

如 1.4 节所述，verilator 的 `UNUSEDSIGNAL` warning 逼出了 RX 基础设施：同步器 → 边沿检测 → 状态机骨架。这个过程的特点是**每一步都有明确反馈**——加一个结构，warning 消失一个。不需要提前规划"我要加完整的 RX 架构"，lint 会告诉你缺什么。

### stub 设计哲学

stub 不是"假实现"或"随便写的占位符"。stub 是**可验证的空白**：

- 安全默认值：`txd=1`（空闲电平，不会误触发 RX）、`rx_valid=0`（不会误报接收成功）
    
- 通过 lint：所有信号都有驱动，无悬空
    
- 不通过功能测试：8/9 FAIL，确认测试有杀伤力
    

这个设计确保了"框架对、功能空"的初始状态。如果 stub 的 `txd=0`（低电平），会误触发外部 RX 的起始位检测——虽然这个项目没有外部 RX，但 stub 的设计原则是"安全默认值"，不是"随便给个值"。

## 1.7 双循环纪律总结

|纪律|具体要求|为什么|
|---|---|---|
|内环零证据|dev_tests/ 全绿 ≠ 过关|微测试只验证单个机制，不能替代验收|
|外环唯一签核|只有 harness PASS 才算|第三方 testbench 是不可修改的 oracle|
|先红后绿|每级必须先确认 stub FAIL|直接绿 = 超前实现 = 停下审查|
|不超前|当前级别不需要的功能不碰|避免引入未测试的代码|
|lint 零 warning|含 waiver 掩盖的|VETO-04 一票否决|

---

# Part 2：从实战到方法学

## 2.1 三大难题在 UART 中的具体映射

R2-TDD 口播稿提出了三大难题：认知过载、恐惧熵增、歧义延迟。这三个不是抽象理论——它们在 UART 项目里有具体的表现。

### 认知过载 → 同时写 TX + RX 必然漏

认知科学告诉我们工作记忆容量是 7±2 个组块。写 UART RTL 时，如果同时做 TX 和 RX，大脑要同时处理：TX NCO 累加器逻辑、TX 帧状态机的 11 拍跳转、奇校验计算、RX 同步器、RX NCO 过采样、RX 3 点表决、RX 假起始检测、rx_valid 时序锚点……这些加起来远超 7 个组块。

**TDD 的解法**：三阶段认知分离。RED 阶段只做分析——"L1 测什么？TX 位时间精度。断言怎么写？测 txd 每位持续时间在 1085±22 ns。"不想实现。GREEN 阶段只做直觉——"TX NCO 怎么写？相位累加器，累加 BAUD_RATE，溢出时产生 tick。"不想优化。REFACTOR 阶段只做审美——"状态机 case 分支能不能合并？tx_idx 的编码能不能更清晰？"不改行为。

在 UART 项目里，这个分离的体现是：L1 只写 TX，L3 才写 RX。写 L1 的时候完全不需要想 RX 的过采样、表决、假起始——那些是后面的事。工作记忆一次只装一个功能域。

### 恐惧熵增 → 改 RX 怕崩 TX

想象你不用 TDD，一口气写完了 TX + RX 的 100 行 RTL。现在跑测试发现 RX 接收数据有偶发错误。你改了 RX 的采样逻辑——TX 会不会被影响？TX 和 RX 共享 `CLK_FREQ` 和 `BAUD_RATE` 参数，如果改参数影响 TX 位时间呢？你不敢改，因为你没有独立的 TX 测试来确认"TX 没变坏"。

**TDD 的解法**：棘轮机制。L1 的测试是一颗齿——锁住了 TX 位时间精度的正确性。你改 RX 代码后跑全量回归，L1 仍然 PASS，说明 TX 没被影响。Kent Beck 说："测试将恐惧转化为无聊。"不是"不怕了"，是"怕也没用，因为棘轮会保护你"。

在 UART 项目里，这个保护是实在的：L1/L2 GREEN 后，开始写 L3 的 RX 逻辑。RX 状态机加了一堆新信号——`rx_phase`、`os_tick`、`vote_cnt`、`sample_data`。跑全量回归，L1/L2 仍然 PASS。棘轮有效。

### 歧义延迟 → "stop1 中心"的精确化

Spec 里写的是"rx_valid 在停止位 1 中心采样点置 1"。什么是"中心"？是 UI 的正中间？还是过采样 tick 序列的中间一个？当拍设置还是下一拍？

在传统流程里，这个问题要等到调试阶段才暴露——你写完 RTL 跑测试，发现 rx_valid 的时序不对，然后回头查 Spec，发现"中心"这个词有歧义。延迟反馈 = 高调试成本。

**TDD 的解法**：可执行规格加秒级负反馈。Timing 文档把"中心"固化为"停止位 1 中心过采样点所在 clk 上升沿"——无歧义。RED 阶段写断言时，这个精确化定义直接变成代码：`@(posedge clk) rx_valid |=> !rx_valid`（单周期脉冲）。如果 RTL 的 rx_valid 多拍保持，断言立刻失败——不需要等调试阶段。

微序列器案例有一个更强的数据：104 条需求中 78 条在 TDD 过程中被改进和澄清。原始 Spec 写的是"如果输入被认为是 Active，则设置对应的 PENDING 标志"——什么是 Active？TDD 的 FP 提取阶段就会追问这个问题，因为你要写断言就必须知道"Active"的精确定义。这就是"Spec 质量放大器"——TDD 不只是验证方法，它倒逼 Spec 精确化。

## 2.2 R2-TDD 六步法 vs UART 实践

R2-TDD 的六步执行法是 READ → RED → GREEN → VERIFY → REFACTOR → UPDATE。逐条对照 UART 项目的执行过程：

|步骤|R2-TDD 定义|UART 项目实践|对齐度|
|---|---|---|---|
|READ|理解 Feature Point|读 Spec/Acceptance/Timing 三件套，确认 L1 测的是 TX 位时间精度|✅|
|RED|生成测试，必须 FAIL|写 `t_nco_tick.v`，对 stub 跑 → `FAIL: no TX output`|✅|
|GREEN|生成 RTL，让测试 PASS|写 TX NCO + 状态机，对 RTL 跑 → `PASS`|✅|
|VERIFY|所有断言通过，无警告|harness TC=1 PASS + lint -Wall 零 warning|✅|
|REFACTOR|lint 清理，回归测试|检查代码结构，跑全量回归确认无退化|✅|
|UPDATE|写入 tdd-state.json|更新执行记录文档，记录当前进度（L1/L2 PASS）|⚠️ 部分|

UPDATE 步骤在 UART 项目里是"更新执行记录文档"，而不是写 `tdd-state.json`。这是因为当前是手工 TDD，没有 AI 迭代的记忆丢失风险。但 R2-TDD 的 `tdd-state.json` 是为 AI 时代设计的——当 AI 跨 session 迭代时，外部化记忆防止"新功能覆盖旧能力"。

## 2.3 七个不变量检验

R2-TDD 定义了七个不变量。前四个跟软件 TDD 共享，后三个是芯片独有的。逐条检验在 UART 项目中的状态：

|#|不变量|UART 状态|说明|
|---|---|---|---|
|I1|规格一致性（每个 FP 追溯到 Spec）|✅|9 级测试全部对应 AC-ID，AC-ID 全部来自 Acceptance 文档|
|I2|断言覆盖性（信号集全覆盖）|⚠️|L1/L2 覆盖 TX 信号（txd, tx_busy, tx_start），RX 信号待 L3+ 补齐|
|I3|RED 阶段有效性（stub 必须让断言失败）|✅|stub 8/9 FAIL，L6 PASS 是阴性测试的合理表现|
|I4|GREEN 阶段正确性（绿了不能退回红）|✅|L1/L2 GREEN 后全量回归保持|
|I5|覆盖率闭合（toggle≥95%, line≥95%, branch≥90%）|❌ PENDING|当前未跑覆盖率工具，L1-L9 全部完成后进入覆盖率闭合阶段|
|I6|并发正确性（确定性，不依赖仿真器调度）|⚠️|TX 是纯时序逻辑，确定性无问题；RX 待实现后验证|
|I7|多抽象层一致性（行为级=RTL=门级）|❌ EXT|当前只有 RTL 级仿真，未做综合后门级仿真|

**关键差距**：I5（覆盖率闭合）和 I7（多抽象层一致性）是芯片 TDD 独有的，软件 TDD 完全不存在。UART 项目当前只做到了功能验证（r2-tdd 的 RED-GREEN 循环），还没进入覆盖率闭合阶段（r2-cov 的 gap 分析）。这是 80/20 法则的体现——功能验证抓 80% 的 Bug，覆盖率闭合抓剩下的 20%。

## 2.4 从小 UART 到大 UART

UART 7O2 是 100 行 RTL、9 个 Feature Point、1 个晚上的手工 TDD。工业级的"大 UART"是什么规模？

R2-TDD 口播稿里的三个案例给出了参照系：

|案例|RTL 行数|FP 数|断言数|GREEN 迭代|Token 消耗|
|---|---|---|---|---|---|
|GPIO 控制器|288 行|72 个|119 个|~1.0 次|$50|
|APB 总线桥|441 行|70 个|86 个|1.9 次|—|
|微序列器|4000 行|104 个|670 个|2.2 次|$200|
|**UART 7O2（本项目）**|**~100 行**|**9 个**|**~15 个**|**~1.0 次**|**手工**|

UART 7O2 的复杂度大约是 GPIO 案例的 1/3——但教学价值不在于规模，在于它用最小成本演示了完整的 TDD 循环：规格拆解 → Feature Point → RED → GREEN → REFACTOR → 回归 → lint。每一步都是真实执行过的，不是纸上谈兵。

**从手工 TDD 到 AI 驱动 TDD 的三个维度差异**：

**第一，规模**。手工 TDD 一个晚上做 9 个 FP；AI 驱动 TDD 一次跑 72-104 个 FP，从 Spec 提取到覆盖率闭合全自动化。微序列器案例人做需要 3-4 个月，AI 压缩了一个数量级。

**第二，AI 一致性错误**。这是 AI 时代特有的风险——AI 对 Spec 理解错了，生成的 RTL 和测试犯了同一个错，测试还 PASS。R2-TDD 的解法是异构 LLM：用不同模型分别生成 RTL 和测试，隔离上下文防止同源偏见。两个独立的 AI 不太可能犯同一个错。UART 项目当前是手工 TDD，没有这个问题——但如果用 AI 做，L3 的 RX 实现和 L3 的 testbench 必须用不同模型生成。

**第三，外部记忆**。手工 TDD 靠人脑和文档记录进度；AI 驱动 TDD 靠 `tdd-state.json`——外部化的状态文件，记录每个 FP 的验证状态、迭代次数、覆盖率数据。这是对抗 AI 记忆丢失的棘轮：锁住每一步已验证的进度，防止新功能覆盖旧能力。

**课程定位**：02 是从实战切入方法学的桥梁。Part 1 的小 UART 实战让读者亲手跑过 RED-GREEN 循环，感受过棘轮的保护力和反馈的速度；Part 2 的方法学映射让读者理解这三个体验背后有认知科学、控制论和证伪哲学的支撑。从 02 往后，课程会进入更大的 IP（GPIO、APB 桥、微序列器），引入 AI 驱动的自动化工具链（specx、r2-tdd、r2-cov），但底层逻辑不变：NO RTL WITHOUT A FAILING TEST FIRST。

---

> **素材索引**
> 
> - TDD 口播定稿：`/Users/gaoyuan/Projects/r2-video/tdd/oral_script_v2.md`
>     
> - TDD 深度解析：`/Users/gaoyuan/Projects/r2-obsidian/r2-note-2604-5/19-TDD深度解析：定义、第一性原理、本质与核心名言.md`
>     
> - TDD deep research：`/Users/gaoyuan/Projects/r2-obsidian/r2-note-2604-5/52-r2-tdd-deep-research.md`
>     
> - UART Spec：`/Users/gaoyuan/tmp/0528/t25/docs/01_UART7O2_Spec.md`
>     
> - UART 验收标准：`/Users/gaoyuan/tmp/0528/t25/docs/02_UART7O2_Acceptance.md`
>     
> - UART 时序规格：`/Users/gaoyuan/tmp/0528/t25/docs/03_UART7O2_Timing.md`
>     
> - 实战执行记录：`/Users/gaoyuan/WorkBuddy/2026-07-09-04-13-43/TDD执行设计-实跑记录.md`
>     
> - DVCon TDD 论文合集：`/Users/gaoyuan/Projects/r2-obsidian/r2-note-2605-3-WY/772-dvcon 路径下符合 TDD 方法的论文-合并-合集.md`
>     
> - 嘉祺 TDD 系列：`/Users/gaoyuan/Projects/r2-obsidian/R2进化论-2604-Alice/0406-TDD-IC-验证-嘉祺*.md`
>     
> - 4 月 R2-TDD 素材簇：`/Users/gaoyuan/Projects/r2-obsidian/R2进化论-2604-Alice/`
>