## v5.0.1 (2026-08-15)

### 功能
- mem0 接入 Hermes 记忆链路（memory.provider=mem0，OSS 模式）：agnes 免费提取 + bge-small-zh 中文向量 + qdrant 本地库，跨会话记忆闭环实测通过
- SKILL.md 新增「记忆操作指南」：/mem 快捷指令设计、分层说明（L1 memory 工具 / L2 mem0_add+search / L3 session_search）
- 新增 references/lessons-learned.md 开发经验库（网络踩坑/mem0 接入/成本核算/agnes 能力实测）

### 优化
- set-model.sh 新增 --all（主配置同步全员）与 --plan（按职能组分配模型）模式
- install.sh：B 分支增加 ollama/llama.cpp 检测引导；远程安装岗位包自动下载兜底；read 容错支持非交互模式
- 记忆中文优化：embedding 换 bge-small-zh-v1.5 + custom_instructions 保留原文语言（实测检索精度 0.6-0.75）

### 安全（skillhub 评审）
- 移除 curl|bash 内联执行，改为下载 + SHA256SUMS 校验
- API key 改存 .env（600权限）+ 配置变量引用，不落明文
- .env 继承按需选择 + 逐岗位确认；镜像 URL 白名单 + 依赖版本锁定

# 变更日志

## v5.0.0 (2026-08-14)

### 品牌升级：铁壁四规 → 米宝OpcOS
- 定位从"技术 skill"升级为"一人公司操作系统（OPC）"
- 四大部门更名：历史书→秘书处 / 图书馆→档案室 / 工蚁→协作部 / 马诺防线→质检部

### 秘书处（记忆中枢）
- L2 层弃用 Hindsight（93依赖），改用 mem0（8核心依赖，qdrant本地）
- 云端API/fastembed 双分支交互安装
- 实测国内网络三件套：hf-mirror + 禁用Xet + 清华pip镜像

### 协作部（岗位协作）
- 10 岗位模型（COO/PM/前端/后端/数据库/设计师/安全/运营/财务/QA）
- 岗位 profile 走 Hermes 官方通道 `hermes profile install`
- 分级汇报机制（S/A/B/C）+ 结构化汇报模板
- 权限矩阵边界控制

### 质检部（五关验证）
- 防御对象扩展：低质量交付/越界/幻觉/空转
- 五关流程：交付质量→边界合规→证据验证→COO复审→CEO终审

### 档案室（文档档案）
- 5分类体系：机制/方案/项目/会议/档案

# 变更日志

## v4.6.1 (2026-07-08)

### SkillHub反馈优化
- 渠道区分：skillhub.cn专用README + GitHub专用README
- 优化错误提示：增加错误提示函数和帮助信息
- 集中避坑指南：FAQ新增避坑章节
- 自动诊断脚本：新增diagnose.sh
- 高级功能文档：新增docs/advanced-features.md
## v4.6.0 (2026-07-08)

### 马诺防线质量提升
- 增加Python代码质量评分（圈复杂度）
- 增加Bandit安全扫描
- 增加TypeScript类型检查
- 增加Go格式化检查
- 增加Rust Clippy检查
- 增加Dart分析支持

### 语言扩展
- Python: ruff + 质量评分 + bandit
- JavaScript/TypeScript: eslint + TypeScript类型检查
- Go: gofmt格式化检查
- Rust: Clippy检查
- Java: google-java-format
- Dart: dart analyze

## v4.5.0 (2026-07-08)

### 马诺防线优化
- 新增mano.sh统一入口脚本
- 为mano_engine.sh添加help功能
- 新增tests/test_manou.sh单元测试（17个测试）
- 修复mano_review.sh变量未绑定问题
- 修复mano_engine.sh参数解析问题

### 测试结果
- 马诺防线单元测试：17/17通过
- 工蚁单元测试：17/17通过

## v4.4.0 (2026-07-08)

### 专注Hermes平台
- 移除OpenClaw支持，专注Hermes生态
- 暂停工蚁阶段4（跨平台协作）
- 清理OpenClaw相关内容

### 工蚁模块状态
- 阶段1-3 已完成
- 阶段4 暂停（等待Hermes官方支持）

---

## v4.3.1 (2026-07-08)

### TRACE改进
- 新增references/use-cases-v2.md（10个使用场景示例）
- 新增tests/test_worker_ant.sh（17个单元测试）
- 新增docs/i18n.md（国际化支持文档）
- 测试全部通过：17/17

---

## v4.3.0 (2026-07-08)

### 阶段3完成
- 新增worker-ant-v3.sh脚本
- 依赖图管理（link/unlink/deps）
- 结果自动汇总（summary）
- 负载均衡（load/recommend）
- 修复worker-ant-dispatch.sh的-Q参数bug

---

## v4.2.1 (2026-07-08)

### 新增
- Sessions导出集成到图书馆机制
- 新增core/sessions-backup.md文档
- 每天20:00自动备份会话，保留60天

### 更新
- SKILL.md版本升级至v4.2.1
- 图书馆机制增加Sessions导出说明

---

## v4.2.0 (2026-07-08)

### 核心变更
- **install.sh 全面重写**
  - 新增基础环境检测（Python/pip/venv/PEP 668）
  - 新增虚拟环境自动创建（PEP 668兼容）
  - 新增GPU检测（NVIDIA/AMD/Apple）
  - 新增本地LLM检测（ollama/llama.cpp）
  - 新增网络环境检测（国内/海外）
  - 新增Hindsight三种配置选择
  - 新增初始化运行环境（MEMORY.md/INDEX.md）
  - 新增安装验证报告

- **SKILL.md 重写**
  - 新增Hindsight配置指南章节
  - 新增三种配置模式说明
  - 新增平台支持矩阵
  - 新增故障排除指南
  - 明确标注"不要安装hindsight-cli"

- **Hindsight文档重写**
  - 重写references/hindsight-china-setup.md
  - 重写plugins/hindsight/PLUGIN.md
  - 新增三种模式详细配置步骤
  - 新增平台支持矩阵
  - 新增常见问题解决方案

### Bug修复
- 修复install.sh不创建MEMORY.md的问题
- 修复install.sh不创建INDEX.md的问题
- 修复PEP 668环境下pip不可用的问题
- 修复Hindsight文档未区分本地/云端模式的问题
- 修复hindsight-cli被误安装的问题

### 依赖更新
- 要求huggingface-hub >= 1.5.0
- 要求sentence-transformers
- 要求hindsight-api（不是hindsight-cli）

---

## v4.1.0 (2026-06-20)

- 工蚁阶段2完成（任务队列+进度看板）
- 修正Memory无自动压缩的认知错误
- 新增3条Pitfall

---

## v4.0.0 (2026-06-19)

- 首次发布通用版
- 插件化架构
- 双平台支持（Hermes/OpenClaw）
- 一键安装脚本

