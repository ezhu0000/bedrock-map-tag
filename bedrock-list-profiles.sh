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

# 写入表头
echo "region,profile_name,inference_profile_arn,status,model_arn,map-migrated,Tagowner,environment,tagged-at" > "$CSV_FILE"
info "输出文件   : $CSV_FILE"

TOTAL=0

# ---------- 3. 按区域查询 ----------
for REGION in "${US_REGIONS[@]}"; do
  section "查询区域: $REGION"

  PROFILES_JSON=$(aws bedrock list-inference-profiles \
    --region "$REGION" \
    --type-equals APPLICATION \
    --query 'inferenceProfileSummaries[].{name:inferenceProfileName,arn:inferenceProfileArn,status:status,modelArn:models[0].modelArn}' \
    --output json 2>/dev/null) || { warn "[$REGION] 查询失败，跳过"; continue; }

  COUNT=$(echo "$PROFILES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

  if [ "$COUNT" -eq 0 ]; then
    info "[$REGION] 无 Application Inference Profile"
    continue
  fi

  info "[$REGION] 找到 $COUNT 个 Profile，获取标签中..."

  # 逐条处理，获取标签
  TMPFILE=$(mktemp /tmp/profiles_XXXXXX.json)
  echo "$PROFILES_JSON" > "$TMPFILE"

  python3 -c "
import sys, json, subprocess

with open('$TMPFILE') as f:
    data = json.load(f)

region = '$REGION'
csv    = '$CSV_FILE'

with open(csv, 'a') as out:
    for p in data:
        name      = p.get('name', '')
        arn       = p.get('arn', '')
        status    = p.get('status', '')
        model_arn = p.get('modelArn', '') or ''

        try:
            result = subprocess.run(
                ['aws', 'bedrock', 'list-tags-for-resource',
                 '--resource-arn', arn, '--region', region,
                 '--query', 'tags', '--output', 'json'],
                capture_output=True, text=True, timeout=10
            )
            tags_list = json.loads(result.stdout) if result.returncode == 0 else []
            tags = {t['key']: t['value'] for t in tags_list}
        except Exception:
            tags = {}

        def esc(v):
            return '\"' + v.replace('\"', '\"\"') + '\"' if ',' in v or '\"' in v else v

        row = ','.join([
            esc(region), esc(name), esc(arn), esc(status), esc(model_arn),
            esc(tags.get('map-migrated', '')),
            esc(tags.get('Tagowner', '')),
            esc(tags.get('environment', '')),
            esc(tags.get('tagged-at', ''))
        ])
        out.write(row + '\n')
        print('  ' + name)
"
  rm -f "$TMPFILE"

  TOTAL=$((TOTAL + COUNT))
done

# ---------- 4. 汇总 ----------
section "导出完成"
info "Account ID  : $ACCOUNT_ID"
info "总计 Profile: $TOTAL"
info "CSV 文件    : $(pwd)/$CSV_FILE"
