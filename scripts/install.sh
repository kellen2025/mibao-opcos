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

        # ── 检测本地 LLM 运行时（记忆提取必需）──
        echo ""
        info "检测本地 LLM 运行时（记忆提取需要）..."
        LOCAL_LLM="none"
        if command -v ollama &>/dev/null; then
            LOCAL_LLM="ollama"
            ok "检测到 ollama: $(ollama --version 2>&1 | head -1)"
        elif command -v llama-server &>/dev/null || command -v llama-cli &>/dev/null || command -v llama.cpp &>/dev/null; then
            LOCAL_LLM="llamacpp"
            ok "检测到 llama.cpp"
        fi

        if [ "$LOCAL_LLM" = "none" ]; then
            echo ""
            warn "未检测到 ollama / llama.cpp。记忆提取需要一个本地 LLM。"
            echo ""
            echo "  请选择："
            echo "    [1] 我现在安装 ollama（推荐，约1分钟）"
            echo "        curl -fsSL https://ollama.com/install.sh | sh"
            echo "        安装完成后输入任意键继续检测"
            echo "    [2] 我已有 llama.cpp（自行启动 server 后继续）"
            echo "    [3] 跳过本地 LLM，仅使用 L1+L3 记忆（无向量检索）"
            echo "    [4] 切换回云端 API 方案"
            read -p "  请输入选择 [1-4]: " LLM_CHOICE
            LLM_CHOICE=${LLM_CHOICE:-3}
            case $LLM_CHOICE in
                1)
                    info "请先安装 ollama，再回来继续。安装命令："
                    echo "  curl -fsSL https://ollama.com/install.sh | sh"
                    echo "  安装完成后运行: $0"
                    echo "  或输入 'r' 立即重试检测"
                    read -p "  安装完成后按回车继续，或输入 r 立即重试: " RETRY
                    if [ "${RETRY:-}" != "r" ] && [ "${RETRY:-}" != "R" ]; then
                        info "等待 ollama 安装完成..."
                        while ! command -v ollama &>/dev/null; do sleep 5; done
                    fi
                    command -v ollama &>/dev/null && { LOCAL_LLM="ollama"; ok "ollama 已就绪: $(ollama --version 2>&1 | head -1)"; } || warn "仍未检测到 ollama"
                    ;;
                2)
                    info "请自行启动 llama.cpp server（如: llama-server -m model.gguf --port 8080）"
                    read -p "  启动完成后按回车继续: " _
                    if command -v llama-server &>/dev/null || curl -s --max-time 3 http://localhost:8080/v1/models &>/dev/null; then
                        LOCAL_LLM="llamacpp"; ok "llama.cpp 服务已就绪"
                    else
                        warn "未检测到 llama.cpp，降级为仅 L1+L3"
                    fi
                    ;;
                4)
                    info "切换云端 API 方案，请重新运行安装脚本并选择 A"
                    ;;
                *)
                    warn "跳过本地 LLM，仅使用 L1+L3 记忆"
                    ;;
            esac
        fi

        # ── 写入 mem0 配置 ──
        mkdir -p "$HOME/.hermes/opcos"
        if [ "$LOCAL_LLM" = "ollama" ]; then
            # 检测可用模型
            OLLAMA_MODEL=""
            if command -v ollama &>/dev/null; then
                OLLAMA_MODEL=$(ollama list 2>/dev/null | awk 'NR>1{print $1; exit}')
            fi
            if [ -z "$OLLAMA_MODEL" ]; then
                echo ""
                warn "ollama 无可用模型。请拉取一个（如: ollama pull qwen2.5:7b）"
                read -p "  拉取完成后按回车继续: " _
                OLLAMA_MODEL=$(ollama list 2>/dev/null | awk 'NR>1{print $1; exit}')
            fi
            OLLAMA_MODEL=${OLLAMA_MODEL:-llama3.1:8b}
            cat > "$HOME/.hermes/opcos/mem0.yaml" << EOF
llm:
  provider: ollama
  config:
    model: ${OLLAMA_MODEL}
    ollama_base_url: http://localhost:11434
embedder:
  provider: fastembed
  config:
    model: BAAI/bge-small-en-v1.5
EOF
            ok "mem0 配置已写入（ollama + ${OLLAMA_MODEL}，纯离线）"
        elif [ "$LOCAL_LLM" = "llamacpp" ]; then
            cat > "$HOME/.hermes/opcos/mem0.yaml" << EOF
llm:
  provider: litellm
  config:
    model: openai/llama3
    api_base: http://localhost:8080/v1
    api_key: local
embedder:
  provider: fastembed
  config:
    model: BAAI/bge-small-en-v1.5
EOF
            ok "mem0 配置已写入（llama.cpp + localhost:8080，纯离线）"
        else
            warn "无本地 LLM，跳过 L2 配置（仅 L1+L3）"
        fi
        ;;
    *)
        warn "无效选择，跳过 L2 记忆配置（仅 L1+L3）"
        ;;
esac

# ─── Step 4: 岗位 profiles 部署 ───
info "Step 4/6: 部署协作部岗位 profiles..."
PROFILES_DIR="$SKILL_DIR/profiles"
DEPLOYED=0

# 远程模式兜底：本机无 profiles/ 时从 GitHub 拉取岗位包
if [ ! -d "$PROFILES_DIR" ]; then
    warn "本机未找到岗位包目录，尝试从 GitHub 下载..."
    PROFILES_DIR="$HOME/.hermes/opcos-profiles"
    if [ ! -d "$PROFILES_DIR" ]; then
        REPO_URL="https://github.com/kellen2025/mibao-opcos/archive/refs/heads/main.zip"
        if curl -sL --connect-timeout 15 --max-time 60 -o /tmp/opcos-profiles.zip "$REPO_URL" 2>/dev/null; then
            mkdir -p /tmp/opcos-extract && unzip -q -o /tmp/opcos-profiles.zip -d /tmp/opcos-extract 2>/dev/null
            SRC_PROFILES=$(find /tmp/opcos-extract -maxdepth 2 -type d -name "profiles" | head -1)
            if [ -n "$SRC_PROFILES" ] && [ -d "$SRC_PROFILES" ]; then
                cp -r "$SRC_PROFILES" "$PROFILES_DIR"
                ok "岗位包已从 GitHub 下载"
            else
                err "岗位包下载失败"
                PROFILES_DIR="$SKILL_DIR/profiles"
            fi
        else
            err "GitHub 下载失败，请手动部署岗位"
            PROFILES_DIR="$SKILL_DIR/profiles"
        fi
    fi
fi

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
