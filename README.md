# 米宝OpcOS v5.0.0

> 一人公司操作系统（OPC Operating System）：老板 = CEO，Agent 团队 = 虚拟公司。

[![Version: 5.0.0](https://img.shields.io/badge/Version-5.0.0-brightgreen.svg)](https://github.com/kellen2025/mibao-opcos)
[![Platform: Hermes](https://img.shields.io/badge/Platform-Hermes-blue.svg)](https://github.com/NousResearch/hermes-agent)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 简介

米宝OpcOS 是一套**一人公司操作系统**，把 Agent 团队组织成一家有岗位、有流程、有汇报、有验收、有档案的虚拟公司。所有产出必须经得起验证、向老板（CEO）交付价值。

```
┌─────────────────────────────────────────────────────┐
│            米宝OpcOS · 一人公司操作系统               │
├─────────────┬─────────────┬─────────────┬───────────┤
│   秘书处    │   档案室    │   协作部    │   质检部   │
│  记忆中枢   │  文档档案   │  岗位协作   │  五关验证  │
└─────────────┴─────────────┴─────────────┴───────────┘
```

| 部门 | 职能 | 核心机制 |
|------|------|----------|
| **秘书处** | 记忆中枢 | 三层记忆：L1 MEMORY.md / L2 mem0 / L3 session_search |
| **档案室** | 文档档案 | 5 分类体系：机制/方案/项目/会议/档案 |
| **协作部** | 岗位协作 | 10 岗位模型 + 任务流转闭环 + 分级汇报 + 权限矩阵 |
| **质检部** | 五关验证 | 防低质交付/越界/幻觉/空转，五关验收 |

---

## 一键安装

```bash
# 官方通道（推荐）
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kellen2025/mibao-opcos/main/scripts/install.sh)"

# 或手动
git clone https://github.com/kellen2025/mibao-opcos.git
cd mibao-opcos && bash scripts/install.sh
```

安装脚本自动完成：
1. ✅ 环境检测（Python/uv/网络）
2. ✅ mem0 记忆中枢（云端 API / fastembed 双分支交互选择）
3. ✅ 协作部岗位 profiles 一键部署（hermes profile install 官方通道）
4. ✅ 档案室初始化（5 分类）
5. ✅ health-check 验证报告

---

## 岗位模型（协作部）

| 岗位 | Profile | 职责 | 边界 |
|------|---------|------|------|
| 总参谋长 COO | `opc-coo` | 任务拆解/调度/汇总汇报 | 无最终决策权 |
| 产品经理 PM | `opc-pm` | 需求分析/PRD/方案 | 不写代码/不做设计 |
| 前端工程师 | `opc-fe` | 页面/交互/组件 | 不碰后端 |
| 后端工程师 | `opc-be` | API/服务/逻辑 | 不碰前端 |
| 数据库工程师 | `opc-db` | 表结构/迁移 | 不碰业务代码 |
| 设计师 | `opc-design` | UI/UX/视觉 | 不写业务代码 |
| 安全工程师 | `opc-sec` | 漏洞/权限/审计 | 不碰业务功能 |
| 运营增长 | `opc-mkt` | 内容/推广/增长 | 不决策预算 |
| 财务风控 | `opc-cfo` | 成本/预算/合规 | 不对外发布 |
| 质检官 QA | `opc-qa` | 五关验证 | 不参与生产 |

---

## 汇报机制

| 级别 | 场景 | 形式 |
|------|------|------|
| S 级 | 战略/大项目 | 专项报告 |
| A 级 | 交付项目 | 结构化简报（完成项/证据/偏差/下一步） |
| B 级 | 例行任务 | 一行状态 |
| C 级 | 杂务 | 随 A/B 汇总 |

---

## 文档

- 详细规范：`SKILL.md`
- 部门机制：`core/`（秘书处/档案室/协作部/质检部）
- 岗位包：`profiles/`
- 安装脚本：`scripts/install.sh`
- 常见问题：`references/faq.md`

## 许可证

MIT License
