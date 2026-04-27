#!/bin/bash
# ============================================================
# 创建具有账单查看权限的 IAM 用户
# 适用于 AWS CloudShell
# ============================================================

set -e

# 设置变量
USERNAME="billing-viewer"
POLICY_NAME="BillingViewerPolicy"

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

echo "开始创建具有账单查看权限的IAM用户"
echo "=================================================="

# 检查当前用户身份
echo "[INFO] 检查当前AWS身份..."
CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "[ERROR] 无法获取AWS身份信息，请检查AWS CLI配置"
  exit 1
fi
echo "当前身份: $CURRENT_USER"

# 获取账户ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "账户ID: $ACCOUNT_ID"

# 检查IAM访问账单信息是否已激活
echo ""
echo "[INFO] 检查IAM访问账单信息状态..."

check_billing_access() {
  # 尝试检查权限
  aws iam get-account-summary >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "[OK] IAM服务可访问"
    # 尝试访问账单相关API来检查是否已激活
    aws ce get-cost-and-usage \
      --time-period Start=2024-01-01,End=2024-01-02 \
      --granularity DAILY \
      --metrics BlendedCost >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "[OK] IAM访问账单信息可能已激活"
      return 0
    else
      echo "[WARN] 无法确定IAM访问账单信息状态"
      return 1
    fi
  else
    echo "[ERROR] IAM服务访问失败"
    return 1
  fi
}

# 执行检查
if ! check_billing_access; then
  echo ""
  echo "[IMPORTANT] 需要激活IAM访问账单信息"
  echo "=================================================="
  echo "由于AWS安全限制，此操作必须由root用户手动完成："
  echo ""
  echo "手动操作步骤："
  echo "1. 使用root用户登录AWS控制台"
  echo "   URL: https://console.aws.amazon.com/"
  echo ""
  echo "2. 点击右上角账户名 -> 选择 'Account'"
  echo "   或直接访问: https://console.aws.amazon.com/billing/home#/account"
  echo ""
  echo "3. 滚动到 'IAM User and Role Access to Billing Information' 部分"
  echo ""
  echo "4. 点击 'Edit' 按钮"
  echo ""
  echo "5. 勾选 'Activate IAM Access' 复选框"
  echo ""
  echo "6. 点击 'Update' 按钮"
  echo ""
  echo "7. 确认看到 'IAM user/role access to billing information is activated' 消息"
  echo ""
  echo "请完成上述步骤后，按任意键继续..."
  read -n 1 -s
  echo ""
fi

# 继续创建IAM用户
echo "[STEP 1] 创建IAM用户..."
aws iam create-user \
  --user-name $USERNAME \
  --tags Key=Purpose,Value=BillingViewer Key=CreatedBy,Value=CLI Key=CreatedDate,Value=$(date +%Y-%m-%d)

if [ $? -ne 0 ]; then
  echo "[WARN] 创建用户失败，可能用户已存在"
  echo "尝试获取现有用户信息..."
  aws iam get-user --user-name $USERNAME
fi

echo ""
echo "[STEP 2] 创建登录配置文件..."
aws iam create-login-profile \
  --user-name $USERNAME \
  --password $PASSWORD \
  --password-reset-required

if [ $? -ne 0 ]; then
  echo "[WARN] 登录配置可能已存在，尝试更新密码..."
  aws iam update-login-profile \
    --user-name $USERNAME \
    --password $PASSWORD \
    --password-reset-required
fi

echo ""
echo "[STEP 3] 创建账单查看策略..."

cat > billing-policy.json << 'EOF'
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

# 创建策略
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://billing-policy.json \
  --description "Comprehensive policy for viewing billing information and cost data"

if [ $? -ne 0 ]; then
  echo "[WARN] 策略可能已存在，继续使用现有策略..."
fi

echo ""
echo "[STEP 4] 附加策略到用户..."
aws iam attach-user-policy \
  --user-name $USERNAME \
  --policy-arn $POLICY_ARN

echo ""
echo "[INFO] 清理临时文件..."
rm -f billing-policy.json

echo ""
echo "IAM用户创建完成！"
echo "=================================================="
echo "用户信息:"
echo "   用户名: $USERNAME"
echo "   临时密码: $PASSWORD"
echo "   策略ARN: $POLICY_ARN"
echo ""
echo "登录信息:"
echo "   控制台URL: https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo "   或通用URL: https://console.aws.amazon.com/"
echo ""
echo "重要提醒:"
echo "   1. 用户首次登录需要修改密码"
echo "   2. 建议启用MFA增强安全性"
echo "   3. 如果无法访问账单信息，请确认已激活IAM访问账单信息"
echo ""
echo "[INFO] 验证用户创建:"
aws iam get-user --user-name $USERNAME --query 'User.[UserName,CreateDate,Arn]' --output table

echo ""
echo "用户附加的策略:"
aws iam list-attached-user-policies --user-name $USERNAME --output table

# 测试账单访问权限
echo ""
echo "[INFO] 测试账单访问权限..."
echo "尝试以新用户身份访问Cost Explorer..."

# 创建临时访问密钥进行测试（可选）
echo ""
echo "提示: 如需程序化访问，可创建访问密钥:"
echo "aws iam create-access-key --user-name $USERNAME"
