#!/bin/bash
# 铁壁四规自动诊断脚本
# 检查系统环境和依赖状态

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "    铁壁四规 自动诊断"
echo "══════════════════════════════════════════════════════════════════"
echo ""

# 检查项
PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local cmd="$2"
    
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $name"
        FAIL=$((FAIL + 1))
    fi
}

warn_check() {
    local name="$1"
    local cmd="$2"
    
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}!${NC} $name"
        WARN=$((WARN + 1))
    fi
}

echo "【环境检查】"
check "Python3" "command -v python3"
check "pip" "python3 -m pip --version"
check "bash" "command -v bash"
echo ""

echo "【铁壁四规文件】"
check "SKILL.md" "test -f ~/.hermes/skills/four-mechanisms/SKILL.md"
check "install.sh" "test -f ~/.hermes/scripts/install.sh"
check "mano.sh" "test -f ~/.hermes/scripts/mano.sh"
check "worker-ant-dispatch.sh" "test -f ~/.hermes/scripts/worker-ant-dispatch.sh"
echo ""

echo "【马诺防线工具】"
check "ruff" "command -v ruff"
check "pytest" "command -v pytest"
check "bandit" "command -v bandit"
echo ""

echo "【Hindsight】"
warn_check "hindsight-api" "command -v hindsight-api || pip show hindsight-api >/dev/null 2>&1"
warn_check "Hindsight配置" "test -f ~/.hindsight/profiles/hermes.env"
echo ""

echo "══════════════════════════════════════════════════════════════════"
echo "  通过: $PASS | 失败: $FAIL | 警告: $WARN"
if [ $FAIL -gt 0 ]; then
    echo -e "  ${RED}存在失败项，请检查${NC}"
elif [ $WARN -gt 0 ]; then
    echo -e "  ${YELLOW}有警告项，可选配置${NC}"
else
    echo -e "  ${GREEN}全部通过${NC}"
fi
echo "══════════════════════════════════════════════════════════════════"
