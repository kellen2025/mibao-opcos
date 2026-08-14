#!/bin/bash
# ══════════════════════════════════════════════════════════
#  协作部 · 模型管理器 (set-model.sh)
#  功能：为指定岗位 profile 切换模型/Provider
#  用法：
#    set-model.sh                    # 交互式选择岗位 + 模型
#    set-model.sh <role>             # 指定岗位，交互选模型
#    set-model.sh <role> <model> [provider] [base_url] [api_key]
#    set-model.sh --all              # ★ 一键同步：主 profile 模型 → 全部岗位
#    set-model.sh --plan             # ★★ 按职能分组分配不同模型（10岗位×N模型）
#  示例：
#    set-model.sh opc-coo qwen2.5-72b custom:qwen
#    set-model.sh opc-pm gpt-4o openai https://api.openai.com/v1 sk-xxx
#    set-model.sh --all              # 改主 profile 后同步全员
#    set-model.sh --plan             # 不同职能配不同模型
# ══════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 全部岗位
ALL_ROLES="opc-coo opc-pm opc-fe opc-be opc-db opc-design opc-sec opc-mkt opc-cfo opc-qa"

# ─── 参数解析 ───
ROLE="${1:-}"
MODEL="${2:-}"
PROVIDER="${3:-}"
BASE_URL="${4:-}"
API_KEY="${5:-}"

# ─── --plan 模式：按职能分组分配不同模型 ───
if [ "$ROLE" = "--plan" ] || [ "$ROLE" = "-p" ]; then
    # 职能分组定义：组名 -> 岗位列表
    declare -A PLAN_GROUPS=(
        ["调度管理"]="opc-coo"
        ["产品规划"]="opc-pm"
        ["研发工程"]="opc-fe opc-be opc-db"
        ["设计创意"]="opc-design"
        ["安全保障"]="opc-sec"
        ["运营增长"]="opc-mkt"
        ["财务风控"]="opc-cfo"
        ["质量验证"]="opc-qa"
    )
    # 检测可用模型池（从主配置 + custom_providers 读取）
    echo "════════ 可用模型池 ════════"
    MODELS_POOL=()
    MAIN_MODEL=$(hermes config get model.default 2>/dev/null || true)
    MAIN_PROVIDER=$(hermes config get model.provider 2>/dev/null || true)
    if [ -n "$MAIN_MODEL" ]; then
        MODELS_POOL+=("$MAIN_MODEL|$MAIN_PROVIDER")
        echo "  [1] $MAIN_MODEL (provider: $MAIN_PROVIDER)"
    fi
    # custom providers 的模型
    CUSTOM_NAMES=$(python3 -c "
import yaml
cfg = yaml.safe_load(open('$HOME/.hermes/config.yaml'))
for cp in cfg.get('custom_providers', []):
    models = cp.get('models') or {}
    for m in (models.keys() if isinstance(models, dict) else [models]):
        print(f'{m}|custom:{cp[\"name\"]}|{cp.get(\"base_url\",\"\")}')
" 2>/dev/null || true)
    IDX=2
    while IFS='|' read -r m p b; do
        [ -z "$m" ] && continue
        MODELS_POOL+=("$m|$p")
        echo "  [$IDX] $m (provider: $p)"
        IDX=$((IDX+1))
    done <<< "$CUSTOM_NAMES"
    if [ ${#MODELS_POOL[@]} -eq 0 ]; then
        err "未检测到可用模型。请先配置主 profile 模型: hermes model"
        exit 1
    fi
    echo ""

    # 为每个职能组选择模型
    echo "════════ 按职能分组配置 ════════"
    echo "（输入对应模型序号，回车=保持该组当前模型）"
    echo ""
    declare -A PLAN_RESULT
    for group in 调度管理 产品规划 研发工程 设计创意 安全保障 运营增长 财务风控 质量验证; do
        roles="${PLAN_GROUPS[$group]}"
        first_role=$(echo "$roles" | awk '{print $1}')
        cur=$(hermes -p "$first_role" config get model.default 2>/dev/null | head -1 || true)
        read -r -p "  [$group] ($roles) 当前:$cur → 模型序号: " SEL || true
        if [ -n "$SEL" ] && [ "$SEL" -ge 1 ] 2>/dev/null && [ "$SEL" -le "${#MODELS_POOL[@]}" ]; then
            PLAN_RESULT[$group]="${MODELS_POOL[$((SEL-1))]}"
        else
            PLAN_RESULT[$group]=""
        fi
    done

    echo ""
    echo "════════ 分配预览 ════════"
    for group in 调度管理 产品规划 研发工程 设计创意 安全保障 运营增长 财务风控 质量验证; do
        roles="${PLAN_GROUPS[$group]}"
        if [ -n "${PLAN_RESULT[$group]:-}" ]; then
            m="${PLAN_RESULT[$group]%%|*}"
            p="${PLAN_RESULT[$group]##*|}"
            echo "  $group ($roles) → $m ($p)"
        else
            echo "  $group ($roles) → 保持不变"
        fi
    done
    echo ""
    read -r -p "  确认应用? [y/N]: " CONFIRM2 || true
    if [ "${CONFIRM2:-n}" != "y" ] && [ "${CONFIRM2:-n}" != "Y" ]; then
        warn "已取消"
        exit 0
    fi

    # 应用
    APPLIED=0
    for group in 调度管理 产品规划 研发工程 设计创意 安全保障 运营增长 财务风控 质量验证; do
        [ -z "${PLAN_RESULT[$group]:-}" ] && continue
        m="${PLAN_RESULT[$group]%%|*}"
        p="${PLAN_RESULT[$group]##*|}"
        for r in ${PLAN_GROUPS[$group]}; do
            hermes -p "$r" config set model.default "$m" >/dev/null 2>&1 || true
            hermes -p "$r" config set model.provider "$p" >/dev/null 2>&1 || true
            APPLIED=$((APPLIED+1))
        done
    done
    echo ""
    ok "已按职能分配模型到 $APPLIED 个岗位。重启岗位会话生效。"
    exit 0
fi

# ─── --all 模式：同步主 profile 模型到全部岗位 ───
if [ "$ROLE" = "--all" ] || [ "$ROLE" = "-a" ]; then
    info "读取主 profile (default) 模型配置..."
    MAIN_MODEL=$(hermes config get model.default 2>/dev/null || true)
    MAIN_PROVIDER=$(hermes config get model.provider 2>/dev/null || true)
    MAIN_BASE_URL=$(hermes config get model.base_url 2>/dev/null || true)
    if [ -z "$MAIN_MODEL" ] || [ -z "$MAIN_PROVIDER" ]; then
        err "主 profile 未配置模型。请先运行: hermes model（选择模型后重试）"
        exit 1
    fi
    info "主配置: $MAIN_MODEL (provider: $MAIN_PROVIDER)"
    echo ""
    read -r -p "  同步到全部 10 个岗位? [y/N]: " CONFIRM || true
    if [ "${CONFIRM:-n}" != "y" ] && [ "${CONFIRM:-n}" != "Y" ]; then
        warn "已取消"
        exit 0
    fi
    SYNCED=0
    for r in $ALL_ROLES; do
        if hermes profile list 2>/dev/null | grep -q "$r"; then
            hermes -p "$r" config set model.default "$MAIN_MODEL" >/dev/null 2>&1 || true
            hermes -p "$r" config set model.provider "$MAIN_PROVIDER" >/dev/null 2>&1 || true
            if [ -n "$MAIN_BASE_URL" ]; then
                hermes -p "$r" config set model.base_url "$MAIN_BASE_URL" >/dev/null 2>&1 || true
            fi
            SYNCED=$((SYNCED+1))
        fi
    done
    echo ""
    ok "已同步 $MAIN_MODEL 到 $SYNCED 个岗位。重启岗位会话生效。"
    exit 0
fi

if [ -z "$ROLE" ]; then
    echo "请选择岗位："
    i=1
    for r in $ALL_ROLES; do
        echo "  [$i] $r"
        i=$((i+1))
    done
    read -r -p "  输入序号: " SEL || true
    ROLE=$(echo "$ALL_ROLES" | cut -d' ' -f"${SEL:-1}")
fi

# 校验岗位存在
if ! hermes profile list 2>/dev/null | grep -q "$ROLE"; then
    err "岗位 $ROLE 未部署。先运行 install.sh 部署。"
    exit 1
fi
PROFILE_HOME="$HOME/.hermes/profiles/$ROLE"

# ─── 交互输入模型 ───
if [ -z "$MODEL" ]; then
    echo ""
    echo "当前模型: $(hermes -p "$ROLE" config get model 2>/dev/null | head -1 || echo 未知)"
    echo "常见模型示例："
    echo "  deepseek-chat / deepseek-reasoner (DeepSeek)"
    echo "  gpt-4o / gpt-4o-mini (OpenAI)"
    echo "  claude-sonnet-4 / claude-haiku-4 (Anthropic)"
    echo "  gemini-2.0-flash (Google)"
    echo "  qwen2.5-72b (阿里/自定义)"
    echo ""
    read -r -p "  输入模型名: " MODEL || true
    [ -z "$MODEL" ] && { err "模型名不能为空"; exit 1; }
fi

# ─── 交互输入 provider ───
if [ -z "$PROVIDER" ]; then
    echo ""
    echo "Provider 选项："
    echo "  deepseek / openai / anthropic / gemini / custom:<名称>"
    read -r -p "  Provider [deepseek]: " PROVIDER || true
    PROVIDER=${PROVIDER:-deepseek}
fi

# ─── 交互输入 base_url（custom 时必需）───
if [[ "$PROVIDER" == custom:* ]] && [ -z "$BASE_URL" ]; then
    read -r -p "  Base URL (如 https://api.xxx.com/v1): " BASE_URL || true
    [ -z "$BASE_URL" ] && { err "custom provider 必须提供 Base URL"; exit 1; }
fi

# ─── 交互输入 API key（可选）───
if [ -z "$API_KEY" ] && [ -z "$(grep -E "^${PROVIDER^^}.*API_KEY" "$PROFILE_HOME/.env" 2>/dev/null)" ]; then
    echo ""
    read -rsp "  API Key（回车跳过，用已有凭证）: " API_KEY || true
    echo ""
fi

# ─── 写入配置 ───
info "为 $ROLE 设置模型: $MODEL (provider: $PROVIDER)..."

# 1. 设置 provider
if [[ "$PROVIDER" == custom:* ]]; then
    CUSTOM_NAME="${PROVIDER#custom:}"
    hermes -p "$ROLE" config set model.provider "custom:$CUSTOM_NAME" >/dev/null 2>&1
else
    hermes -p "$ROLE" config set model.provider "$PROVIDER" >/dev/null 2>&1
fi

# 2. 设置模型
hermes -p "$ROLE" config set model.default "$MODEL" >/dev/null 2>&1

# 3. 设置 base_url（custom 或显式提供时）
if [ -n "$BASE_URL" ]; then
    hermes -p "$ROLE" config set model.base_url "$BASE_URL" >/dev/null 2>&1
fi

# 4. 写入 API key 到岗位 .env（如提供）
if [ -n "$API_KEY" ]; then
    ENV_FILE="$PROFILE_HOME/.env"
    touch "$ENV_FILE" && chmod 600 "$ENV_FILE"
    KEY_NAME="${PROVIDER^^}"
    KEY_NAME="${KEY_NAME//-/_}_API_KEY"
    # 移除旧的 key 行再追加
    sed -i "/^${KEY_NAME}=/d" "$ENV_FILE" 2>/dev/null || true
    echo "${KEY_NAME}=${API_KEY}" >> "$ENV_FILE"
    ok "API Key 已写入 $ROLE/.env（600权限）"
fi

# ─── 验证 ───
echo ""
echo "════════ 设置结果 ════════"
hermes -p "$ROLE" config get model 2>/dev/null | head -5
echo "════════════════════════"
ok "$ROLE 模型已更新。重启该岗位会话生效: hermes -p $ROLE chat"
