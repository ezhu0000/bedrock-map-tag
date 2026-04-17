# Bedrock MAP Tag 一键部署脚本

在 AWS CloudShell 中，对美国三个区域（us-east-1 / us-east-2 / us-west-2）批量创建 Bedrock Application Inference Profile 并打 MAP 标签。

## 快速开始

打开 AWS CloudShell，直接运行以下命令下载并执行脚本：

```bash
curl -O https://raw.githubusercontent.com/ezhu0000/bedrock-map-tag/main/bedrock-tag-deploy.sh
# 如需修改标签值，请先编辑脚本中的 tags 部分，再执行

chmod +x bedrock-tag-deploy.sh
./bedrock-tag-deploy.sh -m <map-migrated值>
```

脚本会自动完成：
- 获取当前账号 ID
- 在 `us-east-1`、`us-east-2`、`us-west-2` 三个区域分别创建 Inference Profile
- 智能跳过已存在的 Profile，只创建缺少的
- 为每个新建 Profile 打上 MAP 标签（含打标签时间）
- 输出新建 / 跳过 / 失败汇总

**参数说明：**

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | map-migrated 标签值（**必填**） | 无 |
| `-o` | Tagowner 标签值（可选） | CDS-MAP |
| `-e` | environment 标签值（可选） | production |

示例：
```bash
./bedrock-tag-deploy.sh -m migDBLKH-DEMO
./bedrock-tag-deploy.sh -m migDBLKH-DEMO -o MyTeam -e staging
```

## 清理
> ⚠️ **请谨慎使用清理功能！** 删除 Inference Profile 后，关联的 MAP 标签也会一并移除，且操作不可逆。建议先在测试账号中验证，确认无误后再在生产环境执行。

如需删除所有已创建的 Inference Profile：

```bash
curl -O https://raw.githubusercontent.com/ezhu0000/bedrock-map-tag/main/bedrock-tag-cleanup.sh
chmod +x bedrock-tag-cleanup.sh
./bedrock-tag-cleanup.sh
```

执行前会有确认提示，输入 `yes` 才会删除。

## 修改标签值

`-o` 和 `-e` 参数可直接在命令行覆盖，`map-migrated` 通过 `-m` 必填传入，无需修改脚本文件。

## 所需 IAM 权限（如果不想单独配置权限，可以直接使用管理员用户执行脚本）

CloudShell 使用的角色需要包含以下权限：

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel*",
    "bedrock:GetInferenceProfile",
    "bedrock:ListFoundationModels",
    "bedrock:ListInferenceProfiles",
    "bedrock:TagResource",
    "bedrock:ListTagsForResource",
    "bedrock:CreateInferenceProfile",
    "aws-marketplace:ViewSubscriptions",
    "aws-marketplace:Subscribe"
  ],
  "Resource": "*"
}
```
