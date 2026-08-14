---
name: mibao-opcos
version: 5.0.0
description: "米宝OpcOS：一人公司操作系统。秘书处(记忆中枢)、档案室(文档档案)、协作部(岗位协作)、质检部(五关验证)。所有Agent必须遵守。"
category: devops
author: kellen2025
license: MIT
platforms: [hermes]
tags: [opc, memory, collaboration, quality, documentation, governance]
---

# 米宝OpcOS v5.0.0

> 一人公司操作系统：老板 = CEO，Agent 团队 = 虚拟公司。
> 四部门缺一不可，违反任何部门的产出无效。

---

## 组织架构

```
┌─────────────────────────────────────────────────────┐
│            米宝OpcOS · 一人公司操作系统               │
├─────────────┬─────────────┬─────────────┬───────────┤
│   秘书处    │   档案室    │   协作部    │   质检部   │
│  记忆中枢   │  文档档案   │  岗位协作   │  五关验证  │
│  L1/L2/L3   │  5分类体系  │  岗位调度   │  防低质/   │
│             │             │  汇报闭环   │  越界/幻觉/│
│             │             │             │  空转     │
└─────────────┴─────────────┴─────────────┴───────────┘
```

**岗位模型**（老板 = CEO 人类；COO = 总参谋长，唯一直接向老板汇报）：

| 岗位 | Profile | 职责 | 边界 |
|------|---------|------|------|
| 总参谋长 COO | `opc-coo` | 任务拆解/调度/汇总汇报 | 无最终决策权，不写代码 |
| 产品经理 PM | `opc-pm` | 需求分析/PRD/方案 | 不写代码，不做设计 |
| 前端工程师 | `opc-fe` | 页面/交互/组件 | 不碰后端/数据库 |
| 后端工程师 | `opc-be` | API/服务/逻辑 | 不碰前端/数据库 |
| 数据库工程师 | `opc-db` | 表结构/迁移/查询 | 不碰业务代码 |
| 设计师 | `opc-design` | UI/UX/UE/视觉 | 不写业务代码 |
| 安全工程师 | `opc-sec` | 漏洞/权限/审计 | 不碰业务功能 |
| 运营增长 | `opc-mkt` | 内容/推广/增长 | 不决策预算 |
| 财务风控 | `opc-cfo` | 成本/预算/合规 | 不对外发布 |
| 质检官 QA | `opc-qa` | 五关验证执行 | 不参与生产 |

---

## 一键安装

```bash
# 方式1：官方通道（推荐）
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kellen2025/mibao-opcos/main/scripts/install.sh)"

# 方式2：手动
git clone https://github.com/kellen2025/mibao-opcos.git
cd mibao-opcos && bash scripts/install.sh
```

安装自动完成：环境检测 → mem0 记忆中枢（云端API/fastembed 双选）→ 岗位 profiles 一键部署（`hermes profile install`）→ 档案室初始化 → health-check 验证。

---

## 部门一：秘书处（记忆中枢）

> 原名"历史书"。三层记忆架构，让知识按热度分层存储。

```
┌─────────────────┬─────────────────┬─────────────────┐
│  L1 热缓存      │  L2 温存储      │  L3 冷存储      │
│  MEMORY.md      │  mem0(qdrant)   │  session_search │
│  每轮自动注入   │  语义检索       │  原始会话       │
└─────────────────┴─────────────────┴─────────────────┘
```

### 记忆写入验证流程
```
Agent准备写入
  ├─ ① 来源检查：用户告知 / 工具验证 / 自己推断(降级)
  ├─ ② 矛盾检查：与已有记忆矛盾 → 停止，问老板
  ├─ ③ 可发现性：一条命令能查到 → 不存
  └─ ④ 写入后校对：重新读取确认
```

### mem0 配置（L2）
- **云端 API 模式**（推荐）：复用 Hermes 已配置的模型路由，零额外安装
- **fastembed 本地模式**：`pip install fastembed`，免费离线，无需 GPU/ollama
- user_id 分区：`opc-coo` / `opc-pm` / `opc-fe` / `boss` 各自隔离

### 国内网络（实测三件套）
```bash
export HF_ENDPOINT=https://hf-mirror.com          # 模型下载镜像
export HF_HUB_DISABLE_XET=1                        # 禁用Xet协议(镜像不兼容)
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple mem0ai   # pip镜像
```

---

## 部门二：档案室（文档档案）

> 原名"图书馆"。文档管理规范，让知识井然有序。

### 5分类体系
| 类别 | 特征 | 例子 |
|------|------|------|
| **机制/** | 框架级操作流程 | OpcOS 四部门机制 |
| **方案/** | 管理设计方案 | 多Agent方案 |
| **项目/** | 对外产出 | 项目交付物 |
| **会议/** | 汇报纪要/决策记录 | COO 汇报存档 |
| **档案/** | 已完结交付物 | 历史项目归档 |

### 目录结构
```
~/.hermes/archives/
├── INDEX.md                     # 多维索引
├── INDEX_LOG.md                 # 变更日志
├── 机制/  方案/  项目/  会议/  档案/
```

### 强制规则
1. root 只允许 INDEX.md + INDEX_LOG.md + 分类文件夹
2. 每个 .md 文件必须含 YAML frontmatter
3. 写完文件立即更新 INDEX.md
4. status=archived 移入 档案/
5. 项目完结时清理项目段

---

## 部门三：协作部（岗位协作）

> 原名"工蚁"。多Agent协作规范，让团队高效协同。

### 任务流转闭环
```
老板指令
  → COO 拆解（任务卡：目标/验收标准/期限/预算）
  → 按能力表分配执行岗位
  → 执行岗产出（每步留痕）
  → QA 验收（质检部五关）
  → 不通过 → 打回执行岗（最多N次）
  → 通过 → COO 汇总 → 向老板汇报
```

### 汇报机制（核心）
| 级别 | 举例 | 汇报形式 |
|------|------|---------|
| S 级 | 战略/大项目 | 专项报告：目标/方案/成本/风险/建议 |
| A 级 | 交付项目 | 结构化简报：完成项/证据/偏差/下一步 |
| B 级 | 例行任务 | 一行状态：✓ 完成 / ⚠ 受阻+原因 |
| C 级 | 杂务 | 不单独汇报，随 A/B 汇总 |

**汇报模板（强制）**：
```
【任务】…  【级别】S/A/B/C
【目标】原始指令回放（防偏移）
【完成项】交付物清单 + 可验证证据
【偏差】与原指令不一致处 + 原因
【成本】耗时 / Token / 费用
【风险】遗留问题 + 建议
```

### 岗位边界（权限矩阵）
| 操作 | CEO | COO | PM | 研发 | MKT | CFO | QA |
|------|-----|-----|----|----|----|----|----|
| 修改核心配置 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 创建/删除 profile | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 写生产代码 | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| 对外发布/花钱 | ✅ | ❌ | ❌ | ❌ | ✅* | ✅* | ❌ |
| 终审验收 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅* |

> \* 需 CEO 预授权。

---

## 部门四：质检部（五关验证）

> 原名"马诺防线"。防御四类 Agent 故障：低质量交付 / 无视边界 / 幻觉 / 恶性空转。

### 五关验证流程
```
① 交付质量关（QA：验收清单逐项核对）
  → ② 边界合规关（QA：权限审计，越权即拦截）
  → ③ 证据验证关（QA：文件/测试/URL 实检，防幻觉）
  → ④ COO 复审（质量标准验收 + 总结报告 + 汇总）
  → ⑤ CEO 终审（老板拍板决策）
```

### 防御对象
| 故障类型 | 表现 | 防御机制 |
|---------|------|---------|
| ① 低质量交付 | 成果粗制滥造、缺项 | 验收清单逐项打勾，缺项打回 |
| ② 无视边界 | 越权操作、超范围执行 | 权限矩阵操作前校验 |
| ③ 幻觉 | 编造结果、虚假证据 | 证据链验证：无法验证 = 判无效 |
| ④ 恶性空转 | 反复重试无进展、烧Token | 空转检测：N次无进展自动上报 |

---

## 岗位 profile 部署（关键技术）

每个岗位是一个 Hermes profile distribution 包：
```
profiles/opc-coo/
├── distribution.yaml    # 清单（distribution_owned 白名单）
├── SOUL.md              # 岗位灵魂：身份+职责+边界+汇报规范
├── config.yaml          # 模型/工具配置
├── seed/
│   ├── USER.md          # 预写老板画像（install后种子写入）
│   └── MEMORY.md        # 预写岗位铁律
└── skills/              # 岗位专属技能
```

**注意**：`memories/` 与 `.env` 是 Hermes 用户数据保护目录（USER_OWNED_EXCLUDE），
不能随 distribution 分发，需 install.sh 安装后置种子写入 + 凭证继承。

---

## 故障排除

### Python 环境问题
```bash
# PEP 668 环境用 uv 建 venv（Hermes 自带 uv）
uv venv ~/.hermes/opcos-venv
uv pip install --python ~/.hermes/opcos-venv/bin/python mem0ai
```

### mem0 模型下载失败（国内网络）
```bash
export HF_ENDPOINT=https://hf-mirror.com
export HF_HUB_DISABLE_XET=1   # 关键：新版hf走Xet协议，镜像不兼容
```

### 岗位 profile 无凭证
```bash
# install.sh 自动从主 profile 继承 .env，无需手工
cp ~/.hermes/.env ~/.hermes/profiles/<name>/.env
```

---

## 文档

- 用户指南：`README.md`
- 详细规范：`core/`（四部门）
- 常见问题：`references/faq.md`
- 变更日志：`CHANGELOG.md`
