#!/bin/bash
# ============================================================
# 创建具有账单查看权限的 IAM 用户
# 使用 AWS 托管策略 job-function/Billing
# 适用于 AWS CloudShell
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 设置变量
USERNAME="billing-viewer"

# 参数解析
usage() {
  echo "用法: $0 -p <密码>"
  echo "  -p  IAM 用户登录密码（必填），需满足 AWS 密码策略"
  echo "  -u  IAM 用户名（可选，默认: billing-viewer）"
  echo "示例: $0 -p 'MyP@ssw0rd!'"
  exit 1
}

while getopts "p:u:h" opt; do
  case $opt in
    p) PASSWORD="$OPTARG" ;;
    u) USERNAME="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

[ -z "$PASSWORD" ] && { echo "[ERROR] 缺少必填参数 -p <密码>，运行 $0 -h 查看帮助"; exit 1; }

# 获取账户ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) \
  || { echo "[ERROR] 无法获取AWS身份信息"; exit 1; }

echo "[1/4] 创建 IAM 用户..."
if aws iam get-user --user-name "$USERNAME" >/dev/null 2>&1; then
  USERNAME="${USERNAME}-$(date +%m%d)"
  echo "       用户已存在，使用: $USERNAME"
fi
aws iam create-user \
  --user-name "$USERNAME" \
  --tags Key=Purpose,Value=BillingViewer Key=CreatedBy,Value=CLI Key=CreatedDate,Value="$(date +%Y-%m-%d)" \
  >/dev/null 2>&1 || { echo "[ERROR] 创建用户 $USERNAME 失败"; exit 1; }

echo "[2/4] 设置登录密码..."
aws iam create-login-profile \
  --user-name "$USERNAME" \
  --password "$PASSWORD" \
  --password-reset-required \
  >/dev/null 2>&1 || \
aws iam update-login-profile \
  --user-name "$USERNAME" \
  --password "$PASSWORD" \
  --password-reset-required \
  >/dev/null 2>&1 || { echo "[ERROR] 密码设置失败"; exit 1; }

echo "[3/4] 附加 AWS 托管账单策略..."
aws iam attach-user-policy \
  --user-name "$USERNAME" \
  --policy-arn "arn:aws:iam::aws:policy/job-function/Billing" \
  >/dev/null 2>&1 || { echo "[ERROR] 账单策略附加失败"; exit 1; }

echo "[4/4] 附加修改密码权限..."
cat > /tmp/change-password-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:ChangePassword",
        "iam:GetAccountPasswordPolicy"
      ],
      "Resource": "arn:aws:iam::*:user/${aws:username}"
    }
  ]
}
EOF

CHANGE_PWD_POLICY="AllowChangePassword-$(date +%Y%m%d%H%M%S)"
aws iam create-policy \
  --policy-name "$CHANGE_PWD_POLICY" \
  --policy-document file:///tmp/change-password-policy.json \
  >/dev/null 2>&1 || true

aws iam attach-user-policy \
  --user-name "$USERNAME" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${CHANGE_PWD_POLICY}" \
  >/dev/null 2>&1 || true

rm -f /tmp/change-password-policy.json

echo ""
echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}  创建成功!${NC}"
echo -e "${GREEN}  控制台URL : https://${ACCOUNT_ID}.signin.aws.amazon.com/console${NC}"
echo -e "${GREEN}  用户名    : ${USERNAME}${NC}"
echo -e "${GREEN}  密码      : ${PASSWORD}${NC}"
echo -e "${GREEN}  (首次登录需要修改密码)${NC}"
echo -e "${GREEN}===================================================${NC}"
echo ""
echo -e "${YELLOW}[NOTE] 如果 IAM 用户无法查看账单，需要 root 用户在控制台开启:${NC}"
echo -e "${YELLOW}       Account -> IAM User and Role Access to Billing Information -> Activate IAM Access${NC}"
echo -e "${YELLOW}       https://us-east-1.console.aws.amazon.com/billing/home#/account${NC}"
