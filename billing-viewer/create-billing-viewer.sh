#!/bin/bash
# ============================================================
# 创建具有账单查看权限的 IAM 用户
# 适用于 AWS CloudShell
# ============================================================

set -e

# 设置变量
USERNAME="billing-viewer"
POLICY_NAME="BillingViewerPolicy-$(date +%Y%m%d%H%M%S)"

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

echo "[INFO] 账户ID: $ACCOUNT_ID"
echo "[INFO] 开始创建 IAM 用户: $USERNAME"

# 创建IAM用户
aws iam create-user \
  --user-name "$USERNAME" \
  --tags Key=Purpose,Value=BillingViewer Key=CreatedBy,Value=CLI Key=CreatedDate,Value="$(date +%Y-%m-%d)" \
  >/dev/null 2>&1 || echo "[WARN] 用户可能已存在，继续..."

# 创建登录配置
aws iam create-login-profile \
  --user-name "$USERNAME" \
  --password "$PASSWORD" \
  --password-reset-required \
  >/dev/null 2>&1 || \
aws iam update-login-profile \
  --user-name "$USERNAME" \
  --password "$PASSWORD" \
  --password-reset-required \
  >/dev/null 2>&1 || echo "[WARN] 登录配置更新失败"

# 创建账单查看策略
cat > /tmp/billing-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBillingConsoleAccess",
      "Effect": "Allow",
      "Action": [
        "aws-portal:ViewBilling",
        "aws-portal:ViewUsage"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowCostExplorerAccess",
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage",
        "ce:GetDimensionValues",
        "ce:GetReservationCoverage",
        "ce:GetReservationPurchaseRecommendation",
        "ce:GetReservationUtilization",
        "ce:GetUsageReport",
        "ce:ListCostCategoryDefinitions",
        "ce:DescribeCostCategoryDefinition"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowBudgetAccess",
      "Effect": "Allow",
      "Action": [
        "budgets:ViewBudget"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowBillingReportsAccess",
      "Effect": "Allow",
      "Action": [
        "cur:DescribeReportDefinitions",
        "billing:GetBillingData",
        "billing:GetBillingDetails",
        "billing:GetBillingNotifications",
        "billing:GetBillingPreferences",
        "billing:GetContractInformation",
        "billing:GetCredits",
        "billing:GetIAMAccessPreference",
        "billing:GetSellerOfRecord",
        "billing:ListBillingViews"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowAccountInformation",
      "Effect": "Allow",
      "Action": [
        "account:GetAccountInformation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowPaymentInformation",
      "Effect": "Allow",
      "Action": [
        "payments:ListPaymentPreferences",
        "payments:GetPaymentInstrument",
        "payments:GetPaymentStatus"
      ],
      "Resource": "*"
    }
  ]
}
EOF

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file:///tmp/billing-policy.json \
  --description "Policy for viewing billing information and cost data" \
  >/dev/null 2>&1 || echo "[WARN] 策略创建失败"

# 附加策略
aws iam attach-user-policy \
  --user-name "$USERNAME" \
  --policy-arn "$POLICY_ARN" \
  >/dev/null 2>&1 || echo "[WARN] 策略附加失败"

rm -f /tmp/billing-policy.json

# 输出关键信息
echo ""
echo "=================================================="
echo "  控制台URL : https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo "  用户名    : $USERNAME"
echo "  密码      : $PASSWORD"
echo "=================================================="
echo ""
echo "[NOTE] 首次登录需要修改密码"
echo "[NOTE] 如果 IAM 用户无法查看账单，需要 root 用户在控制台开启:"
echo "       Account -> IAM User and Role Access to Billing Information -> Activate IAM Access"
echo "       https://us-east-1.console.aws.amazon.com/billing/home#/account"
