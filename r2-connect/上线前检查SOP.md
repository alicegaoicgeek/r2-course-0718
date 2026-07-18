# 课程 HTML 上线前检查 SOP

> **谁接管**：按本清单从上到下勾，不要靠记忆。  
> **主上线文件（唯一真源）**：`/Users/gaoyuan/Desktop/r2-connect/课程地图-可视化-v4.html`  
> **附属**：`提示词加餐包-复制即用.md` · 母本 `r2-prompts.html`  
> **审计日期**：2026-07-18  

---

## 0. 先分清：哪些 HTML 要上线，哪些别碰

| 角色 | 路径 | 上线？ |
|------|------|--------|
| **主地图 · 唯一真源** | `~/Desktop/r2-connect/课程地图-可视化-v4.html` | ✅ 上线用这个 |
| 加餐包正文 | `~/Desktop/r2-connect/提示词加餐包-复制即用.md` | ✅ 与地图 11 号绑定 |
| 提示词母本 | `~/Workbuddy/2026-07-09-00-40-43/r2-prompts.html` | ⚪ 可选加餐外链，非地图主交付 |
| Swiss 海报 | `~/Desktop/r2-swiss/R2-实战笔记26篇课程地图_swiss.html` | ⚪ 海报用，无路径系统 |
| Swiss AIOS | `~/Desktop/r2-swiss/R2-AIOS课程地图_swiss.html` | ⚪ 海报用 |
| Workbuddy v3/v4/v5/门头* | `~/Workbuddy/2026-07-11-03-06-35/*` | ❌ **旧稿/实验，禁止当上线包** |
| 更早 Workbuddy 地图 | `2026-07-07*` / `2026-07-08*` | ❌ 归档 |
| 单篇可视化 | `r2-course-2606/85-…可视化.html` | ⚪ 单课附件，非地图 |

**铁律**：学员/小鹅通/交付包里只放 **r2-connect 目录**；不要塞 Workbuddy 历史版。

---

## 1. 上线前 10 分钟清单（必做）

### A. 文件与角色

- [ ] 打开的是 `r2-connect/课程地图-可视化-v4.html`（看路径栏，不是 Workbuddy）
- [ ] 同目录有 `提示词加餐包-复制即用.md`（约 50 条 3 分正文）
- [ ] 浏览器 **硬刷新**（Cmd+Shift+R），避免旧 localStorage 种子不跑

### B. 页面结构自检（肉眼 2 分钟）

- [ ] Part1 显示 **26 篇**（M1–M5）
- [ ] Part2 显示 AIOS 模块（P1–P4 + 解码）
- [ ] **11 号标题** = `提示词加餐包（复制即用·不讲课）`（不是 testcase 那句）
- [ ] **04 号** = 奶茶钱 EDA 平替相关标题仍在
- [ ] 路径总览面板能展开，md 输入框有内容（绿标签 = 有路径）

### C. 路径绿/橙抽检（打开路径总览）

**必绿（已 seed，打开后应有 md）**

| 编号 | 预期 |
|------|------|
| notes-04 | 68-8h+一杯奶茶钱…md |
| notes-11 | 提示词加餐包-复制即用.md |
| notes-01/02/05/06/… | ORANGE/NOTES 已登记项 |
| aios-07/08/21 | 72-eda / 55-knowledge / 87-dvbuild |
| aios-01～20 大部分 | r2-video 下 md |

**已知仍橙 / 路径问题（上线前要处理或接受）**

| 编号 | 问题 | 建议动作 |
|------|------|----------|
| notes-03 | 无 seed | 补路径或标「待写」 |
| notes-24 | 无 seed | 补路径或标「待写」 |
| aios-03/22–26 等 | 无 seed | 补路径或接受橙色 |
| **aios-16** | 指向 **不存在的** `…/68.md` | **必修**：改为 `68-r2-soc-integration：可定制的SOC开放集成平台.md` |
| **notes-15** | seed 写 `84.md` **不存在** | **必修**：改为 `84-EDA 流程与 AI 工作流的集成，打造你的专属 AI 专家团.md` |

### D. 加餐包抽检

- [ ] 打开加餐包 md，目录应有 **50 条**（不是只有 27 条）
- [ ] 抽 3 条：ai-10x 一条 + superpower 一条 + karpathy 一条，正文在 \`\`\` 里
- [ ] 母本 `r2-prompts.html?score=3` 能开（可选）

### E. 浏览器 Console（F12）

- [ ] 无红色 JS 报错
- [ ] 复制路径 / 勾选 1-2-3 / 打分框能写
- [ ] 「导出评级」若用提示词库：能下 JSON（仅 prompts 页）

### F. 交付打包

- [ ] 打包目录建议只含：
  ```
  r2-connect/
    课程地图-可视化-v4.html
    提示词加餐包-复制即用.md
    （可选）上线前检查SOP.md
  ```
- [ ] **不要**打包整个 Workbuddy 历史地图
- [ ] 若学员本机路径不同：路径总览里的 md 是你本机绝对路径 → 交付前说明「路径按讲师机；学员用导出/复制标题自建」或改成相对路径策略（见 §4）

---

## 2. 深度检查（有时间再做，约 30–45 分钟）

### 2.1 自动化路径体检（复制执行）

```bash
# 主地图内所有绝对路径是否存在
python3 - <<'PY'
from pathlib import Path
import re
t = Path("/Users/gaoyuan/Desktop/r2-connect/课程地图-可视化-v4.html").read_text()
paths = sorted(set(re.findall(r"/Users/gaoyuan/[^\s'\"`<>]+?\.(?:md|html)", t)))
miss = [p for p in paths if not Path(p).exists()]
print("total", len(paths), "missing", len(miss))
for m in miss: print("MISS", m)
PY
```

期望：**missing = 0**（当前审计至少 1 条：`68.md`；ORANGE 里 `84.md` 也要修）。

### 2.2 标题 vs 正文一致性（抽 5 节）

| 步骤 | 动作 |
|------|------|
| 1 | 路径总览点某课 md 路径 |
| 2 | `zed <路径>` 或打开文件 |
| 3 | 文件标题/首段是否覆盖地图 `tt` 文案 |
| 4 | 若只是近匹配（如 08 蒸馏文），接受则在备注写「近匹配」 |

### 2.3 版本冲突检查

```bash
# 若 connect 与 Workbuddy 同名文件都在，以 connect mtime 为准
ls -lt ~/Desktop/r2-connect/课程地图*.html \
       ~/Workbuddy/2026-07-11-03-06-35/课程地图-可视化-v4.html \
       ~/Workbuddy/2026-07-11-03-06-35/课程地图-可视化-v5.html
```

- [ ] connect-v4 **最新**
- [ ] 不把旧 v5/swiss 实验稿当主交付

### 2.4 内容红线（产品）

- [ ] 无误把「内部草稿/爬虫过程」当学员正文
- [ ] 加餐包定位：**赠送复制，不讲课**（地图标题已体现）
- [ ] 敏感：CDC 超长证明 prompt 在 3 分包内 → 知悉即可，非主课必讲

### 2.5 吴恩达 3 层 Loop（若本版要讲）

- [ ] 权威文：`r2-note-2605-3-WY/912-Loop Engineering-吴恩达 1.md`
- [ ] **当前未挂进地图 seed** → 若本期要讲，给 notes-19 或 aios-05 补路径；不讲则从 SOP 勾掉

---

## 3. 上线当天 5 步（临门）

1. **备份**  
   `cp 课程地图-可视化-v4.html 课程地图-可视化-v4.html.bak-$(date +%Y%m%d)`
2. **修必修路径**（aios-16、notes-15）→ 改 seed 或换新 SEED key 强制写入  
3. **硬刷新 + 抽检 04/11/一条 aios 绿**  
4. **加餐包 50 条目录扫一眼**  
5. **交付 zip / 上传小鹅通**（只 r2-connect 必要文件）

---

## 4. 路径与 localStorage 注意（防「我改了怎么还是旧的」）

| 现象 | 原因 | 处理 |
|------|------|------|
| 改了 HTML seed 不生效 | seed 键已写过 localStorage | **换新 SEED 名**（如后缀日期）或清站点 localStorage |
| 标签仍橙 | md 空 | 路径总览粘贴路径，或补 seed |
| 学员打开全橙 | 绝对路径是你机器的 | 预期行为；交付说明或改相对/网盘路径 |
| 11 号还是 testcase 标题 | 打开了旧 HTML | 确认文件路径是 r2-connect v4 |

清除本机地图存储（慎用，会丢勾选/打分）：

```js
// 在课程地图页 Console 执行
Object.keys(localStorage).filter(k=>k.includes('r2-course-map')).forEach(k=>localStorage.removeItem(k));
location.reload();
```

---

## 5. 角色分工（脑子乱时只看这张）

| 角色 | 只关心 |
|------|--------|
| **你（产品）** | 26+AIOS 标题对不对、11=加餐包、要不要讲 Ng 三层 |
| **本 SOP / Agent** | 路径是否存在、seed 是否生效、缺哪几号、打包清单 |
| **不要同时改** | Workbuddy 旧地图 + connect 真源（只改 connect） |

---

## 6. 当前审计快照（2026-07-18）— 上线阻塞项

### 阻塞（建议上线前修）

1. **aios-16** → `…/68.md` **不存在**  
   - 改为：`…/68-r2-soc-integration：可定制的SOC开放集成平台.md`（或你指定的定稿）
2. **notes-15** → `…/84.md` **不存在**  
   - 改为：`…/84-EDA 流程与 AI 工作流的集成，打造你的专属 AI 专家团.md`

### 非阻塞但记录

| 项 | 状态 |
|----|------|
| notes-03 / notes-24 | 无路径 seed，地图上可能仍橙 |
| aios-03、22–26、解码条 | 多无 seed |
| 吴恩达 912 三层 loop | 库内有，**未挂地图** |
| Workbuddy 多版地图 | 易混淆，交付时隔离 |
| 加餐包 | ✅ 50 条已写入 connect |
| prompts 母本 loop-engineering | ✅ 7 条已在 |

### 主地图健康摘要

| 指标 | 值 |
|------|-----|
| Part1 课数 | 26 |
| Part2+解码 | 32 |
| 一次性 SEED 数 | 9 |
| 加餐包条数 | 50 |
| 嵌入绝对路径抽样 miss | ≥1（68.md）+ notes-15 的 84.md |

---

## 7. 签核栏（上线时手填）

| 检查项 | 执行人 | 日期 | 通过 |
|--------|--------|------|------|
| §1 A–F 十分钟清单 | | | ☐ |
| aios-16 路径已修 | | | ☐ |
| notes-15 路径已修 | | | ☐ |
| 硬刷新后 04/11 绿 | | | ☐ |
| 加餐包 50 条确认 | | | ☐ |
| 交付包仅 r2-connect 必要文件 | | | ☐ |
| Console 无红错 | | | ☐ |

**签核人**：__________　**上线时间**：__________

---

## 8. Agent 可代劳的下一刀（你一句话即可）

说「修阻塞路径」→ 我直接改 v4 seed（aios-16 + notes-15）。  
说「补 03/24」→ 搜 2606 对齐后 seed。  
说「挂吴恩达 912」→ 挂到 notes-19 或 aios-05。  
说「打交付 zip」→ 只打包 r2-connect 上线集。
