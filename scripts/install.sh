#!/bin/bash
# ══════════════════════════════════════════════════════════
#  米宝OpcOS v5.0.0 一键安装脚本
#  一人公司操作系统：秘书处 + 档案室 + 协作部 + 质检部
#  流程: 环境检测 → mem0记忆中枢(双选) → 岗位部署 → 档案室 → 验证
# ══════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
OPCOS_VENV="$HOME/.hermes/opcos-venv"

echo ""
echo "════════════════════════════════════════════"
echo "   米宝OpcOS v5.0.0 · 一人公司操作系统"
echo "════════════════════════════════════════════"
echo ""

# ─── Step 1: 基础环境 ───
info "Step 1/6: 检测基础环境..."
if ! command -v python3 &>/dev/null; then err "未检测到 Python3"; exit 1; fi
if ! command -v uv &>/dev/null && ! command -v hermes &>/dev/null; then
    err "未检测到 uv/hermes"; exit 1
fi
UV_BIN="$(command -v uv || echo "$HOME/.hermes/bin/uv")"
ok "Python $(python3 --version 2>&1 | awk '{print $2}')"

# ─── Step 2: 国内网络检测 ───
info "Step 2/6: 检测网络环境..."
IS_CHINA=false
if ! curl -s --connect-timeout 5 --max-time 8 https://pypi.org/simple/ &>/dev/null; then
    IS_CHINA=true
    warn "检测到国内网络，启用镜像加速"
    PIP_MIRROR="-i https://pypi.tuna.tsinghua.edu.cn/simple"
else
    PIP_MIRROR=""
    ok "网络连接正常"
fi

# ─── Step 3: mem0 记忆中枢安装（双分支交互） ───
info "Step 3/6: 安装 mem0 记忆中枢（秘书处 L2 层）..."

if [ ! -d "$OPCOS_VENV" ]; then
    "$UV_BIN" venv "$OPCOS_VENV" --python 3.12 >/dev/null 2>&1 || {
        "$UV_BIN" venv "$OPCOS_VENV" >/dev/null 2>&1; }
fi

if ! "$OPCOS_VENV/bin/python" -c "import mem0" &>/dev/null 2>&1; then
    info "安装 mem0ai（依赖轻量，核心8个包）..."
    "$UV_BIN" pip install --python "$OPCOS_VENV/bin/python" $PIP_MIRROR mem0ai >/dev/null 2>&1 || {
        err "mem0ai 安装失败，请检查网络后重试"; exit 1; }
fi
ok "mem0ai 已安装"

# ─── Step 3b: 记忆提取方案选择 ───
echo ""
echo "========================================"
echo "   秘书处 · 记忆提取方案选择"
echo "========================================"
echo ""
echo "  [A] 使用我的云端 API（推荐，零安装）"
echo "      - 自动读取 Hermes 已配置的模型路由"
echo "      - 或输入任意 OpenAI 兼容网关 base_url"
echo ""
echo "  [B] 使用 fastembed 本地向量（免费）"
echo "      - pip 安装 fastembed，自动下载模型"
echo "      - 完全离线，无需 API Key"
echo ""
read -p "请输入选择 [A/B]: " MEM_CHOICE
MEM_CHOICE=${MEM_CHOICE:-A}

case $MEM_CHOICE in
    a|A)
        info "配置云端 API 模式..."
        echo ""
        echo "  检测到 Hermes 已配置的模型路由："
        grep -E "^\s+provider:" "$HOME/.hermes/config.yaml" 2>/dev/null | head -5 | sed 's/^/    /' || true
        echo ""
        read -p "  LLM Provider [deepseek]: " LLM_PROVIDER
        LLM_PROVIDER=${LLM_PROVIDER:-deepseek}
        read -p "  API Key: " LLM_API_KEY
        read -p "  Base URL [回车用默认]: " LLM_BASE_URL
        read -p "  模型名 [deepseek-chat]: " LLM_MODEL
        LLM_MODEL=${LLM_MODEL:-deepseek-chat}
        # 写入 mem0 配置
        mkdir -p "$HOME/.hermes/opcos"
        cat > "$HOME/.hermes/opcos/mem0.yaml" << EOF
llm:
  provider: ${LLM_PROVIDER}
  config:
    model: ${LLM_MODEL}
    api_key: ${LLM_API_KEY}
    base_url: ${LLM_BASE_URL}
embedder:
  provider: fastembed
  config:
    model: BAAI/bge-small-en-v1.5
EOF
        ok "云端 API 配置已写入 ~/.hermes/opcos/mem0.yaml"
        ;;
    b|B)
        info "配置 fastembed 本地模式..."
        "$UV_BIN" pip install --python "$OPCOS_VENV/bin/python" $PIP_MIRROR fastembed >/dev/null 2>&1 || {
            err "fastembed 安装失败"; exit 1; }
        # 国内镜像三件套（实测必须）
        export HF_ENDPOINT=https://hf-mirror.com
        export HF_HUB_DISABLE_XET=1
        mkdir -p "$HOME/.hermes/opcos"
        cat > "$HOME/.hermes/opcos/mem0.yaml" << EOF
llm:
  provider: ollama
  config:
    model: llama3.1:8b
    ollama_base_url: http://localhost:11434
embedder:
  provider: fastembed
  config:
    model: BAAI/bge-small-en-v1.5
EOF
        ok "fastembed 配置已写入（本地离线）"
        ;;
    *)
        warn "无效选择，跳过 L2 记忆配置（仅 L1+L3）"
        ;;
esac

# ─── Step 4: 岗位 profiles 部署 ───
info "Step 4/6: 部署协作部岗位 profiles..."
PROFILES_DIR="$SKILL_DIR/profiles"
DEPLOYED=0
if [ -d "$PROFILES_DIR" ]; then
    for role_dir in "$PROFILES_DIR"/opc-*; do
        [ -d "$role_dir" ] || continue
        role_name="$(basename "$role_dir")"
        if hermes profile list 2>/dev/null | grep -q "$role_name"; then
            ok "岗位已存在: $role_name（跳过）"
        else
            hermes profile install "$role_dir" --alias -y >/dev/null 2>&1 && {
                # 凭证继承 + memories 种子（USER_OWNED_EXCLUDE 后置）
                if [ ! -f "$HOME/.hermes/profiles/$role_name/.env" ] && [ -f "$HOME/.hermes/.env" ]; then
                    cp "$HOME/.hermes/.env" "$HOME/.hermes/profiles/$role_name/.env"
                fi
                mkdir -p "$HOME/.hermes/profiles/$role_name/memories"
                [ -f "$role_dir/seed/USER.md" ] && cp "$role_dir/seed/USER.md" "$HOME/.hermes/profiles/$role_name/memories/USER.md"
                [ -f "$role_dir/seed/MEMORY.md" ] && cp "$role_dir/seed/MEMORY.md" "$HOME/.hermes/profiles/$role_name/memories/MEMORY.md"
                DEPLOYED=$((DEPLOYED+1))
                ok "岗位部署: $role_name"
            } || warn "岗位部署失败: $role_name"
        fi
    done
fi
[ "$DEPLOYED" -eq 0 ] && [ ! -d "$PROFILES_DIR" ] && warn "未找到岗位包目录 profiles/（可稍后手动部署）"

# ─── Step 5: 档案室初始化 ───
info "Step 5/6: 初始化档案室..."
ARCHIVES="$HOME/.hermes/archives"
for dir in 机制 方案 项目 会议 档案; do
    mkdir -p "$ARCHIVES/$dir"
done
[ -f "$ARCHIVES/INDEX.md" ] || cat > "$ARCHIVES/INDEX.md" << EOF
---
title: 档案室索引
created: $(date +%Y-%m-%d)
updated: $(date +%Y-%m-%d)
author: 米宝OpcOS
category: 机制
tags: [索引, 档案室]
status: active
version: 1.0
---

# 档案室索引

> 自动生成于 $(date +%Y-%m-%d)

## 机制/  框架级操作流程
## 方案/  管理设计方案
## 项目/  对外产出的项目文档
## 会议/  汇报纪要、决策记录
## 档案/  已完结交付物归档
EOF
ok "档案室已初始化: $ARCHIVES"

# ─── Step 6: 验证 ───
info "Step 6/6: 验证安装..."
echo ""
echo "════════ 米宝OpcOS 安装报告 ════════"
echo "[$( [ -d "$OPCOS_VENV" ] && echo ✅ || echo ❌ )] Python 环境"
echo "[$( "$OPCOS_VENV/bin/python" -c 'import mem0' &>/dev/null && echo ✅ || echo ❌ )] mem0 记忆中枢"
echo "[$( [ -f "$HOME/.hermes/opcos/mem0.yaml" ] && echo ✅ || echo ❌ )] 记忆配置"
echo "[$( hermes profile list 2>/dev/null | grep -c 'opc-' ) 个] 协作部岗位"
echo "[$( [ -d "$ARCHIVES/机制" ] && echo ✅ || echo ❌ )] 档案室"
echo "════════════════════════════════════"
echo ""
ok "米宝OpcOS 安装完成！重启 Hermes 生效。"
echo ""
echo "下一步："
echo "  1. hermes -p opc-coo chat   # 启动总参谋长"
echo "  2. skill_view name=mibao-opcos   # 加载四部门规范"
