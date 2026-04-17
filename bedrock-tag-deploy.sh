#!/bin/bash
# ============================================================
# AWS Bedrock Inference Profile 创建 & 打标签 一键脚本
# 支持多美国区域：us-east-1 / us-east-2 / us-west-2
# 智能幂等：已存在的跳过，只创建缺少的
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

# ---------- 目标区域 ----------
US_REGIONS=("us-east-1" "us-east-2" "us-west-2")

# ---------- 标签（按需修改） ----------
TAG_MAP_MIGRATED="migDBLKHQS3LO"
TAG_OWNER="CDS-MAP"
TAG_ENV="production"

# ---------- 模型列表（name=profile名称, suffix=ARN中inference-profile/后面的部分） ----------
# 格式: "name|suffix"
MODELS=(
  "usclaudesonnet46|us.anthropic.claude-sonnet-4-6"
  "globalclaudesonnet46|global.anthropic.claude-sonnet-4-6"
  "usclaudeopus47|us.anthropic.claude-opus-4-7"
  "globalclaudeopus47|global.anthropic.claude-opus-4-7"
  "usclaudeopus46|us.anthropic.claude-opus-4-6-v1"
  "globalclaudeopus46|global.anthropic.claude-opus-4-6-v1"
  "usclaudeopus45|us.anthropic.claude-opus-4-5-20251101-v1:0"
  "globalclaudeopus45|global.anthropic.claude-opus-4-5-20251101-v1:0"
  "usclaudehaiku45|us.anthropic.claude-haiku-4-5-20251001-v1:0"
  "globalclaudehaiku45|global.anthropic.claude-haiku-4-5-20251001-v1:0"
  "usclaudesonnet45|us.anthropic.claude-sonnet-4-5-20250929-v1:0"
  "globalclaudesonnet45|global.anthropic.claude-sonnet-4-5-20250929-v1:0"
  "usclaudeopus41|us.anthropic.claude-opus-4-1-20250805-v1:0"
  "usclaudeopus4|us.anthropic.claude-opus-4-20250514-v1:0"
  "usclaudesonnet4|us.anthropic.claude-sonnet-4-20250514-v1:0"
  "globalclaudesonnet4|global.anthropic.claude-sonnet-4-20250514-v1:0"
)

# ---------- 1. 获取账号 ID ----------
section "获取 AWS 账号信息"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) \
  || error "无法获取 Account ID，请确认 CloudShell 已登录正确账号"
info "Account ID : $ACCOUNT_ID"
info "目标区域   : ${US_REGIONS[*]}"
info "模型数量   : ${#MODELS[@]}"

# ---------- 2. 按区域处理 ----------
TOTAL_CREATED=0
TOTAL_SKIPPED=0
TOTAL_FAILED=0

for REGION in "${US_REGIONS[@]}"; do
  section "处理区域: $REGION"

  # 获取该区域已有的 Application Inference Profile 名称列表
  EXISTING_NAMES=$(aws bedrock list-inference-profiles \
    --region "$REGION" \
    --type-equals APPLICATION \
    --query 'inferenceProfileSummaries[].inferenceProfileName' \
    --output text 2>/dev/null || echo "")

  CREATED=0
  SKIPPED=0
  FAILED=0

  for MODEL_ENTRY in "${MODELS[@]}"; do
    NAME="${MODEL_ENTRY%%|*}"
    SUFFIX="${MODEL_ENTRY##*|}"
    SOURCE_ARN="arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/${SUFFIX}"

    # 检查是否已存在同名 profile
    if echo "$EXISTING_NAMES" | grep -qw "$NAME"; then
      info "  [跳过] $NAME 已存在"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    # 创建 profile
    info "  [创建] $NAME ..."
    RESULT=$(aws bedrock create-inference-profile \
      --inference-profile-name "$NAME" \
      --model-source copyFrom="$SOURCE_ARN" \
      --tags \
        key=map-migrated,value="$TAG_MAP_MIGRATED" \
        key=Tagowner,value="$TAG_OWNER" \
        key=environment,value="$TAG_ENV" \
      --region "$REGION" \
      --query 'inferenceProfileArn' \
      --output text 2>&1) || true

    if echo "$RESULT" | grep -q "arn:aws:bedrock"; then
      info "  [成功] $NAME → $RESULT"
      CREATED=$((CREATED + 1))
    else
      warn "  [失败] $NAME : $RESULT"
      FAILED=$((FAILED + 1))
    fi
  done

  info "[$REGION] 新建: $CREATED  跳过: $SKIPPED  失败: $FAILED"
  TOTAL_CREATED=$((TOTAL_CREATED + CREATED))
  TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))
  TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
done

# ---------- 3. 汇总 ----------
section "执行汇总"
info "Account ID : $ACCOUNT_ID"
info "总计新建   : $TOTAL_CREATED"
info "总计跳过   : $TOTAL_SKIPPED"
if [ "$TOTAL_FAILED" -gt 0 ]; then
  warn "总计失败   : $TOTAL_FAILED （模型可能在该区域不可用，或 IAM 权限不足）"
else
  info "总计失败   : 0 ✓"
fi
