#!/bin/bash
# ══════════════════════════════════════════════════════════
#  米宝OpcOS 自动诊断脚本
#  检查: 环境 / 秘书处(mem0) / 协作部(岗位) / 档案室
# ══════════════════════════════════════════════════════════
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }

echo "════════════════════════════════════════════"
echo "    米宝OpcOS v5.0.0 自动诊断"
echo "════════════════════════════════════════════"
echo ""

echo "【环境检查】"
command -v python3 >/dev/null && ok "Python3 $(python3 --version 2>&1 | awk '{print $2}')" || fail "Python3"
command -v hermes >/dev/null && ok "Hermes" || fail "Hermes"
command -v uv >/dev/null 2>&1 && ok "uv" || warn "uv（可用 hermes 内置）"
[ -d "$HOME/.hermes/opcos-venv" ] && ok "opcos-venv" || warn "opcos-venv 未创建"
echo ""

echo "【部门一 · 秘书处（mem0 记忆中枢）】"
if [ -x "$HOME/.hermes/opcos-venv/bin/python" ]; then
    "$HOME/.hermes/opcos-venv/bin/python" -c "import mem0" &>/dev/null 2>&1 && ok "mem0 已安装" || fail "mem0 未安装"
else
    fail "venv 缺失"
fi
[ -f "$HOME/.hermes/opcos/mem0.yaml" ] && ok "mem0 配置 ($(grep -A1 '^llm:' "$HOME/.hermes/opcos/mem0.yaml" | grep provider | awk '{print $2}'))" || warn "mem0 配置缺失（未配置L2，仅L1+L3）"
echo ""

echo "【部门三 · 协作部（岗位 profiles）】"
DEPLOYED=$(hermes profile list 2>/dev/null | grep -c 'opc-')
[ "$DEPLOYED" -gt 0 ] && ok "已部署 $DEPLOYED 个岗位" || warn "无岗位部署"
for role in opc-coo opc-pm opc-fe opc-be opc-db opc-design opc-sec opc-mkt opc-cfo opc-qa; do
    if hermes profile list 2>/dev/null | grep -q "$role"; then
        [ -f "$HOME/.hermes/profiles/$role/SOUL.md" ] && ok "$role: SOUL.md ✓" || warn "$role: SOUL.md 缺失"
        [ -f "$HOME/.hermes/profiles/$role/memories/MEMORY.md" ] && ok "$role: MEMORY.md ✓" || warn "$role: MEMORY.md 缺失"
        [ -f "$HOME/.hermes/profiles/$role/.env" ] && ok "$role: .env ✓" || warn "$role: .env 缺失"
    else
        warn "$role: 未部署"
    fi
done
echo ""

echo "【部门二 · 档案室】"
[ -d "$HOME/.hermes/archives" ] && ok "档案室根目录" || fail "档案室未创建"
for dir in 机制 方案 项目 会议 档案; do
    [ -d "$HOME/.hermes/archives/$dir" ] && ok "分类: $dir/" || fail "分类: $dir/ 缺失"
done
[ -f "$HOME/.hermes/archives/INDEX.md" ] && ok "INDEX.md" || fail "INDEX.md 缺失"
echo ""

echo "【部门四 · 质检部】"
[ -f "$(dirname "$0")/install.sh" ] && ok "install.sh 存在" || warn "install.sh 缺失"
bash -n "$(dirname "$0")/install.sh" &>/dev/null && ok "install.sh 语法正确" || fail "install.sh 语法错误"
echo ""

echo "════════════════════════════════════════════"
