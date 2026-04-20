#!/bin/bash
# ============================================================
# AWS Bedrock Application Inference Profile 列表导出脚本
# 遍历美国三个区域，导出所有 Application Inference Profile 到 CSV
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

# ---------- 2. 准备 CSV 文件 ----------
TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
CSV_FILE="inference_profiles_${ACCOUNT_ID}_${TIMESTAMP}.csv"
echo "region,profile_name,inference_profile_arn,status,model_arn,map-migrated,Tagowner,environment,tagged-at" > "$CSV_FILE"
info "输出文件   : $CSV_FILE"

TOTAL=0

# ---------- 3. 按区域查询 ----------
for REGION in "${US_REGIONS[@]}"; do
  section "查询区域: $REGION"

  # 用 text 格式逐字段输出，避免 JSON 解析问题
  # 输出格式: name\tarn\tstatus\tmodelArn
  PROFILES_TEXT=$(aws bedrock list-inference-profiles \
    --region "$REGION" \
    --type-equals APPLICATION \
    --query 'inferenceProfileSummaries[].[inferenceProfileName,inferenceProfileArn,status,models[0].modelArn]' \
    --output text 2>/dev/null) || { warn "[$REGION] 查询失败，跳过"; continue; }

  if [ -z "$PROFILES_TEXT" ]; then
    info "[$REGION] 无 Application Inference Profile"
    continue
  fi

  COUNT=$(echo "$PROFILES_TEXT" | wc -l)
  info "[$REGION] 找到 $COUNT 个 Profile，获取标签中..."

  while IFS=$'\t' read -r NAME ARN STATUS MODEL_ARN; do
    [ -z "$ARN" ] && continue

    # 获取标签
    TAGS_JSON=$(aws bedrock list-tags-for-resource \
      --resource-arn "$ARN" \
      --region "$REGION" \
      --query 'tags' \
      --output json 2>/dev/null || echo "[]")

    TAG_MAP=$(echo "$TAGS_JSON" | python3 -c "
import sys, json
tags = {t['key']: t['value'] for t in json.load(sys.stdin)}
print('\t'.join([
    tags.get('map-migrated',''),
    tags.get('Tagowner',''),
    tags.get('environment',''),
    tags.get('tagged-at','')
]))" 2>/dev/null || echo "   ")

    IFS=$'\t' read -r T_MAP T_OWNER T_ENV T_TIME <<< "$TAG_MAP"

    echo "${REGION},${NAME},${ARN},${STATUS},${MODEL_ARN},${T_MAP},${T_OWNER},${T_ENV},${T_TIME}" >> "$CSV_FILE"
    info "  $NAME  →  $ARN"
  done <<< "$PROFILES_TEXT"

  TOTAL=$((TOTAL + COUNT))
done

# ---------- 4. 汇总 ----------
section "导出完成"
info "Account ID  : $ACCOUNT_ID"
info "总计 Profile: $TOTAL"
info "CSV 文件    : $(pwd)/$CSV_FILE"
