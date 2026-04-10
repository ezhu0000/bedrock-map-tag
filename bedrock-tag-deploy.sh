#!/bin/bash
# ============================================================
# AWS Bedrock Inference Profile 创建 & 打标签 一键脚本
# 支持多美国区域：us-east-1 / us-east-2 / us-west-2
# 适用于 AWS CloudShell (Amazon Linux 2023)
# ============================================================

set -e

# ---------- 颜色输出 ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}========== $1 ==========${NC}"; }

# ---------- 目标区域列表（美国）----------
US_REGIONS=("us-east-1" "us-east-2" "us-west-2")

# ---------- 1. 获取当前账号 ID ----------
section "获取 AWS 账号信息"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) \
  || error "无法获取 Account ID，请确认 CloudShell 已登录正确账号"
info "Account ID : $ACCOUNT_ID"
info "将在以下区域创建 Profile: ${US_REGIONS[*]}"

# ---------- 2. 安装依赖 ----------
section "安装系统依赖"
sudo yum install -y git -q
info "git 就绪"

# ---------- 3. Clone 工具仓库 ----------
section "准备工具仓库"
TOOL_DIR="sample-bedrock-inference-profile-mgmt-tool"
if [ -d "$TOOL_DIR" ]; then
  warn "目录 $TOOL_DIR 已存在，执行 git pull..."
  git -C "$TOOL_DIR" pull --quiet
else
  git clone https://github.com/aws-samples/sample-bedrock-inference-profile-mgmt-tool.git
fi
cd "$TOOL_DIR"

# ---------- 4. Python 虚拟环境 ----------
section "准备 Python 环境"
python3 -m venv venv
source venv/bin/activate
pip install -q -r requirements.txt
info "依赖安装完成"

# ---------- 5. 按区域循环执行 ----------
FAILED_REGIONS=()

for REGION in "${US_REGIONS[@]}"; do
  section "处理区域: $REGION"

  # 生成该区域的 yaml 文件
  YAML_FILE="bedrock-profiles-${REGION}.yaml"
  info "生成 $YAML_FILE ..."

  cat > "$YAML_FILE" << YAML
region: ${REGION}
tags:
  - key: map-migrated
    value: migEDQGF-DEMO
  - key: Tagowner
    value: CDS-MAP
  - key: environment
    value: production
bedrock-profiles:
  - name: usclaudesonnet46
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-sonnet-4-6
  - name: globalclaudesonnet46
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/global.anthropic.claude-sonnet-4-6
  - name: usclaudeopus46
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-opus-4-6-v1
  - name: globalclaudeopus46
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/global.anthropic.claude-opus-4-6-v1
  - name: usclaudeopus45
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-opus-4-5-20251101-v1:0
  - name: globalclaudeopus45
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/global.anthropic.claude-opus-4-5-20251101-v1:0
  - name: usclaudehaiku45
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0
  - name: globalclaudehaiku45
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/global.anthropic.claude-haiku-4-5-20251001-v1:0
  - name: usclaudesonnet45
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-sonnet-4-5-20250929-v1:0
  - name: globalclaudesonnet45
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/global.anthropic.claude-sonnet-4-5-20250929-v1:0
  - name: usclaudeopus41
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-opus-4-1-20250805-v1:0
  - name: usclaudeopus4
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-opus-4-20250514-v1:0
  - name: usclaudesonnet4
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-sonnet-4-20250514-v1:0
  - name: globalclaudesonnet4
    model_type: inference
    model_id: arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/global.anthropic.claude-sonnet-4-20250514-v1:0
YAML

  # 执行工具
  info "[$REGION] 开始创建 Inference Profile 并打标签..."
  if python3 bedrock_inference_profile_management_tool.py -f "./$YAML_FILE"; then
    info "[$REGION] 创建完成 ✓"
  else
    warn "[$REGION] 执行失败，继续下一个区域"
    FAILED_REGIONS+=("$REGION")
    continue
  fi

  # 验证：取最新 CSV 的第一条 ARN
  CSV_FILE=$(ls -t inference_profiles_*.csv 2>/dev/null | head -1)
  if [ -n "$CSV_FILE" ]; then
    SAMPLE_ARN=$(awk -F',' 'NR==2{print $2}' "$CSV_FILE" | tr -d '"' | tr -d ' ')
    if [ -n "$SAMPLE_ARN" ]; then
      info "[$REGION] 验证标签: $SAMPLE_ARN"
      if aws bedrock list-tags-for-resource \
           --resource-arn "$SAMPLE_ARN" \
           --region "$REGION" 2>/dev/null; then
        info "[$REGION] 标签验证成功 ✓"
      else
        warn "[$REGION] 标签验证失败，请手动检查"
      fi
    fi
    # 重命名 CSV 避免下次循环混淆
    mv "$CSV_FILE" "${CSV_FILE%.csv}_${REGION}.csv"
  fi
done

# ---------- 6. 汇总结果 ----------
section "执行汇总"
info "Account ID : $ACCOUNT_ID"
info "成功区域   : $(echo "${US_REGIONS[@]}" | tr ' ' '\n' | grep -v "$(IFS='|'; echo "${FAILED_REGIONS[*]}")" | tr '\n' ' ')"
if [ ${#FAILED_REGIONS[@]} -gt 0 ]; then
  warn "失败区域   : ${FAILED_REGIONS[*]}"
  warn "请检查失败区域的模型是否已在该区域开通，或 IAM 权限是否足够"
else
  info "所有区域执行成功 ✓"
fi
info "CSV 结果文件均在目录: $(pwd)"
ls -1 inference_profiles_*.csv 2>/dev/null || true
