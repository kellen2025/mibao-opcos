#!/bin/bash
# ══════════════════════════════════════════════════════════
#  协作部 · 模型管理器 (set-model.sh)
#  功能：为指定岗位 profile 切换模型/Provider
#  用法：
#    set-model.sh                    # 交互式选择岗位 + 模型
#    set-model.sh <role>             # 指定岗位，交互选模型
#    set-model.sh <role> <model> [provider] [base_url] [api_key]
#    set-model.sh --all              # ★ 一键同步：主 profile 模型 → 全部岗位
#  示例：
#    set-model.sh opc-coo qwen2.5-72b custom:qwen
#    set-model.sh opc-pm gpt-4o openai https://api.openai.com/v1 sk-xxx
#    set-model.sh --all              # 改主 profile 后同步全员
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
