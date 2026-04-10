#!/bin/bash
# ============================================================
# AWS Bedrock Inference Profile 清理脚本
# 删除由 bedrock-tag-deploy.sh 创建的所有 Application Inference Profile
# 适用于 AWS CloudShell (Amazon Linux 2023)
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}========== $1 ==========${NC}"; }

US_REGIONS=("us-east-1" "us-east-2" "us-west-2")

# ---------- 1. 获取账号 ID ----------
section "获取 AWS 账号信息"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) \
  || error "无法获取 Account ID"
info "Account ID : $ACCOUNT_ID"
info "清理区域   : ${US_REGIONS[*]}"

# ---------- 2. 确认 ----------
echo ""
warn "此操作将删除以上区域中所有由部署脚本创建的 Application Inference Profile！"
read -r -p "确认继续？(输入 yes 继续): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  info "已取消"
  exit 0
fi

# ---------- 3. 按区域删除 ----------
TOTAL_DELETED=0
FAILED=()

for REGION in "${US_REGIONS[@]}"; do
  section "清理区域: $REGION"

  # 列出该账号下所有 APPLICATION 类型的 inference profile
  PROFILES=$(aws bedrock list-inference-profiles \
    --region "$REGION" \
    --type-equals APPLICATION \
    --query 'inferenceProfileSummaries[].inferenceProfileArn' \
    --output text 2>/dev/null) || { warn "[$REGION] 无法列出 Profile，跳过"; continue; }

  if [ -z "$PROFILES" ]; then
    info "[$REGION] 无 Application Inference Profile，跳过"
    continue
  fi

  for ARN in $PROFILES; do
    info "[$REGION] 删除: $ARN"
    if aws bedrock delete-inference-profile \
         --inference-profile-identifier "$ARN" \
         --region "$REGION" 2>/dev/null; then
      info "[$REGION] 已删除 ✓"
      TOTAL_DELETED=$((TOTAL_DELETED + 1))
    else
      warn "[$REGION] 删除失败: $ARN"
      FAILED+=("$ARN")
    fi
  done
done

# ---------- 4. 清理本地临时文件 ----------
section "清理本地临时文件"
TOOL_DIR="sample-bedrock-inference-profile-mgmt-tool"

if [ -d "$TOOL_DIR" ]; then
  # 删除生成的 yaml 和 csv
  find "$TOOL_DIR" -name "bedrock-profiles-*.yaml" -delete 2>/dev/null && info "已删除临时 yaml 文件"
  find "$TOOL_DIR" -name "inference_profiles_*.csv"  -delete 2>/dev/null && info "已删除临时 csv 文件"
else
  info "工具目录不存在，跳过本地文件清理"
fi

# ---------- 5. 汇总 ----------
section "清理汇总"
info "共删除 Profile 数: $TOTAL_DELETED"
if [ ${#FAILED[@]} -gt 0 ]; then
  warn "以下 ARN 删除失败，请手动处理："
  for F in "${FAILED[@]}"; do echo "  - $F"; done
else
  info "所有 Profile 清理完成 ✓"
fi
