#!/bin/bash
# ══════════════════════════════════════════════════════════
#  敏感信息扫描器 (scan-secrets.sh)
#  用途：推送/发布仓库前，扫描所有文件是否含敏感信息
#  触发：铁律④——更新仓库前必查（GITHUB 推送/RELEASE 前必须运行）
#  用法：
#    scan-secrets.sh <目录>          # 扫描指定目录
#    scan-secrets.sh ~/.hermes/skills/opc-os
#  退出码: 0=干净  1=发现敏感信息（禁止推送）
# ══════════════════════════════════════════════════════════
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
FAIL=0

TARGET="${1:-.}"
echo "════════ 敏感信息扫描: $TARGET ════════"

# ─── 1. API Key 模式 ───
echo ""
echo "【1/5】API Key 检测..."
PATTERNS=(
    'sk-[a-zA-Z0-9]{10,}'              # OpenAI/DeepSeek/Agnes 等
    'ghp_[a-zA-Z0-9]{20,}'             # GitHub PAT
    'sk-tp-[a-zA-Z0-9]+'               # Token Plan key
    'sk-sp-[a-zA-Z0-9._-]+'            # 阿里云 MaaS key
    'AKIA[0-9A-Z]{16}'                 # AWS
    'AIza[0-9A-Za-z_-]{20,}'           # Google
)
HITS=$(grep -rnoE "$(IFS='|'; echo "${PATTERNS[*]}")" "$TARGET" 2>/dev/null | grep -v "scan-secrets.sh" | head -10)
if [ -n "$HITS" ]; then
    echo -e "  ${RED}✗ 发现 API Key:${NC}"
    echo "$HITS" | while read -r l; do echo "    $l" | sed -E 's/(sk-[a-zA-Z0-9]{4})[a-zA-Z0-9]+/\1***/g; s/(ghp_[a-zA-Z0-9]{4})[a-zA-Z0-9]+/\1***/g'; done
    FAIL=1
else
    echo -e "  ${GREEN}✓ 无 API Key${NC}"
fi

# ─── 2. 密码/密钥字段 ───
echo ""
echo "【2/5】密码/密钥字段检测..."
PASS_HITS=$(grep -rnoE "(password|passwd|secret|api_key|apikey|token)\s*[:=]\s*['\"]?[^'\"]{8,}" "$TARGET" 2>/dev/null \
    | grep -vE "api_key:\s*\\\$\{|password.*(提示|请输入)|\.env|scan-secrets" | head -10)
if [ -n "$PASS_HITS" ]; then
    echo -e "  ${YELLOW}! 发现疑似密钥字段（需人工确认是否真值）:${NC}"
    echo "$PASS_HITS" | while read -r l; do echo "    $l" | sed -E 's/([:=] ["'\''"]?[a-zA-Z0-9]{4})[a-zA-Z0-9]+/\1***/g'; done
    # 只警告不 FAIL（可能是变量模板），人工确认
else
    echo -e "  ${GREEN}✓ 无明文密钥字段${NC}"
fi

# ─── 3. 真实 key 值（已配置的） ───
echo ""
echo "【3/5】本机真实凭据比对（从 ~/.hermes/.env 提取）..."
ENV_FILE="$HOME/.hermes/.env"
if [ -f "$ENV_FILE" ]; then
    REAL_KEYS=$(grep -oE "=[A-Za-z0-9_-]{20,}" "$ENV_FILE" | tr -d '=' | sort -u | head -20)
    FOUND_REAL=0
    for key in $REAL_KEYS; do
        if grep -rq "$key" "$TARGET" 2>/dev/null; then
            echo -e "  ${RED}✗ 仓库中发现本机真实凭据片段: ${key:0:6}***${NC}"
            FOUND_REAL=1
            FAIL=1
        fi
    done
    [ "$FOUND_REAL" -eq 0 ] && echo -e "  ${GREEN}✓ 无本机真实凭据${NC}"
else
    echo -e "  ${YELLOW}! 未找到 ~/.hermes/.env，跳过比对${NC}"
fi

# ─── 4. 用户个人信息 ───
echo ""
echo "【4/5】用户个人信息检测（本机用户名/路径/邮箱）..."
USER_HITS=$(grep -rnoE "/home/[a-z0-9_]+|kellen2025@|(邮箱|手机号|电话)[:：][0-9@a-z]+" "$TARGET" 2>/dev/null \
    | grep -v "scan-secrets.sh\|distribution.yaml.*author\|example" | head -10)
if [ -n "$USER_HITS" ]; then
    echo -e "  ${YELLOW}! 发现疑似用户信息（确认是否应保留）:${NC}"
    echo "$USER_HITS" | while read -r l; do echo "    $l"; done
else
    echo -e "  ${GREEN}✓ 无用户个人信息${NC}"
fi

# ─── 5. 其他敏感（银行卡/身份证） ───
echo ""
echo "【5/5】金融/身份信息检测..."
FIN_HITS=$(grep -rnoE "([0-9]{4}[ -]?){4,}|[1-9][0-9]{16,17}|[0-9]{17}[0-9Xx]" "$TARGET" 2>/dev/null | grep -v "scan-secrets.sh" | head -5)
if [ -n "$FIN_HITS" ]; then
    echo -e "  ${RED}✗ 发现疑似银行卡/身份证号:${NC}"
    echo "$FIN_HITS" | while read -r l; do echo "    $l"; done
    FAIL=1
else
    echo -e "  ${GREEN}✓ 无金融/身份信息${NC}"
fi

echo ""
echo "════════════════════════════════════════"
if [ "$FAIL" -eq 1 ]; then
    echo -e "${RED}❌ 扫描未通过：发现敏感信息，禁止推送！${NC}"
    echo "   请清除上述内容或改为环境变量引用后重试。"
    exit 1
else
    echo -e "${GREEN}✅ 扫描通过：无敏感信息，可安全推送。${NC}"
    exit 0
fi
