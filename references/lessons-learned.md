# 米宝OpcOS 开发经验库（踩坑与成功）

> 2026-08-15 优化实录。所有条目均经实测验证，供后续维护与二次开发参考。

---

## 一、网络与环境（国内实测）

### 1. GitHub 主域被墙，但子域可用
- **现象**：`git clone/push` 到 github.com 超时（134s），`github.com/archive/*.zip` 也超时
- **可用**：`api.github.com`（0.6s）、`codeload.github.com`（zip 下载）、`raw.githubusercontent.com`（单文件）
- **解法**：
  - 仓库下载：`curl -L https://codeload.github.com/<owner>/<repo>/zip/refs/heads/main`
  - 仓库推送：Git Contents API 逐文件 PUT（base64 内容），**中文文件名必须 URL 编码**（`urllib.parse.quote(path, safe='/')`）
  - 已存在文件更新需带 `sha`（先 GET 拿 sha），否则 422
- **教训**：不要假设 git 协议可用，先探测 `api.github.com` 连通性

### 2. pip 慢 → 清华镜像
```bash
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple <pkg>
# 或 uv: uv pip install --python <venv>/bin/python -i <镜像> <pkg>
```

### 3. HuggingFace 下载（fastembed 模型）
- **必须三件套**（缺一不可）：
```bash
export HF_ENDPOINT=https://hf-mirror.com   # 国内镜像
export HF_HUB_DISABLE_XET=1                 # 禁用 Xet 协议（镜像不兼容，否则 401）
```
- fastembed 模型首次下载约 90MB（bge-small-zh-v1.5），之后本地缓存

### 4. 系统缺 python3-venv / pip（PEP 668）
- **解法**：用 Hermes 自带 uv：`uv venv <path>` + `uv pip install --python <venv>/bin/python <pkg>`
- 后台进程 PATH 可能无 uv，用绝对路径 `/home/kellen/.hermes/bin/uv`

---

## 二、Hermes Profile Distribution（岗位包）

### 1. 官方通道安装
```bash
hermes profile install <本地目录或git URL> --alias -y
```
- 支持 git URL（`github.com/user/repo` 缩写）或含 `distribution.yaml` 的本地目录
- 安装后 `hermes profile update` 可升级（用户数据保留）

### 2. 三大硬约束（已踩坑）
| 约束 | 现象 | 解法 |
|------|------|------|
| `memories/` 是 USER_OWNED_EXCLUDE | distribution 包里的 seed/ 不会被复制进 profile | install.sh 安装后置种子写入 |
| `.env` 也是 USER_OWNED | 新 profile 无凭证，启动报 Unknown provider | install.sh 从主 profile 继承（按需+确认） |
| 未声明 distribution_owned 白名单 | 多余文件（build.sh 等）被全量复制 | manifest 声明 `distribution_owned: [SOUL.md, config.yaml, skills, cron]` |

### 3. custom provider 不在岗位 config 里
- 岗位引用 `custom:xxx` 报 `Unknown provider` → 需在岗位 config.yaml 写入 custom_providers 定义（含 base_url/key），或岗位直接配官方 provider

---

## 三、mem0 记忆层

### 1. 中文记忆优化（关键）
- **问题**：mem0 默认提取把中文翻译成英文（语义漂移），英文 embedding 模型中文检索差
- **解法**：
  - embedding 用 `BAAI/bge-small-zh-v1.5`（中文，512 维）
  - mem0 配置加 `custom_instructions` 强制保留输入语言（实测中文原文入库）
  - 检索精度对比：修复前 0.38-0.50 → 修复后 0.6-0.75

### 2. mem0 2.0.18 API 变更
- `search()` / `get_all()` 不接受顶层 `user_id` → 必须 `filters={"user_id": ...}`
- openai provider 的 base_url 字段名是 `openai_base_url`（不是 `base_url`）

### 3. 接入 Hermes（OSS 模式）
- `hermes memory setup` 向导默认值是 gpt-5-mini/text-embedding-3-small（**错误**），需手改 `~/.hermes/mem0.json`
- **向导的 Embedder 列表只有 openai/ollama，但运行时透传 mem0 原生配置**——手写 mem0.json 可用 fastembed
- **Hermes venv 缺 mem0 库**：lazy_deps 自动安装常失败，需手动 `uv pip install --python ~/.hermes/hermes-agent/venv/bin/python mem0ai fastembed`
- 运行时验证：qdrant collection 创建（512 维）→ 会话中 mem0_add/mem0_search 工具自动出现

### 4. 记忆读写成本（实测）
- 写入（add）：346-717 tokens/次（含历史回看），LLM 提取 1 次
- 检索（search）：**0 tokens**（纯向量，19ms/次）
- 密钥：存 `~/.hermes/opcos/.env`（600 权限），mem0.yaml 用 `${OPCOS_LLM_API_KEY}` 变量引用

---

## 四、成本核算（2026-08-15 实测）

### 真实账单数据（老板 deepseek-v4-flash）
- 日用量 1.03 亿 token，**缓存命中率 99.4%**（关键！之前假设 75% 严重高估成本）
- 日费用 ¥3.11 → 月约 ¥93
- 反推单价：缓存 ¥0.02 / 未命中 ¥1.0 / 输出 ¥2.0（每百万）

### 方案对比（真实用量）
| 方案 | 月成本 |
|------|--------|
| agnes（免费） | ¥0 |
| 腾讯混元福利（记忆专用） | ¥0 |
| 超网 Flash 套餐 | ¥52 |
| DeepSeek V4-Flash 直连（现价） | ¥93 |
| MiMo 按量 | ¥94 |
| Qwen Token Plan 139元 | ¥139（封顶） |
| DeepSeek V4-Flash（8/17 峰谷新价） | ¥256 |
| DeepSeek V4-Pro（8/17 峰谷新价） | ¥768 |

### 教训
- **Credits ≠ token**：MiMo 110 亿是 Credits，按 100:1 折算实际只有 1.1 亿 token 当量
- **模型选择决定成本**：同用量下贵模型贵 15 倍（GLM 6.5h vs Flash 2.3天/套餐）
- 峰谷定价：DeepSeek 高峰 5h/天（9-12, 14-18），夜间便宜一半

---

## 五、agnes-2.5-flash 能力实测

- **代码能力 7/7 通过**：FizzBuzz/回文/去重/LRU缓存/二分/生产者消费者并发/FastAPI CRUD（真实运行验证）
- 定位：记忆提取 + 简单/中等编码 + 简单文本（免费）
- 无 embedding 接口（`model_not_found`）——不能做向量化
- 结论：免费 + 代码可用 = 研发岗可用的高性价比选择

---

## 六、安全加固（skillhub 评审反馈）

1. **移除 curl|bash**：改为下载 + SHA256SUMS 校验 + 执行
2. **密钥不落明文**：.env 600 权限 + 配置变量引用
3. **.env 继承按需**：只挑 LLM 相关 key + 逐岗位确认 [y/N]
4. **镜像白名单 + 版本锁定**：仅清华 pypi/hf-mirror；mem0ai==2.0.18、fastembed==0.7.4
5. **敏感信息零泄露**：本地 skill、ZIP、远端 62 文件全部扫描通过

---

## 七、set-model.sh 三模式（岗位模型管理）

- `--all`：主 profile 模型一键同步全员
- `--plan`：按 8 职能组分配不同模型（自动检测可用模型池）
- 单岗位：`set-model.sh <role> <model> <provider> [base_url] [key]`
- **注意**：custom provider 需岗位 config 有定义，否则 Unknown provider
