# Bedrock MAP Tag 一键部署脚本

在 AWS CloudShell 中，对美国三个区域（us-east-1 / us-east-2 / us-west-2）批量创建 Bedrock Application Inference Profile 并打 MAP 标签。

## 快速开始

打开 AWS CloudShell，直接运行以下命令下载并执行脚本：

```bash
curl -O https://raw.githubusercontent.com/ezhu0000/bedrock-map-tag/main/bedrock-tag-deploy.sh
# 如需修改标签值，请先编辑脚本中的 tags 部分，再执行

chmod +x bedrock-tag-deploy.sh
./bedrock-tag-deploy.sh
```

脚本会自动完成：
- 获取当前账号 ID
- 安装依赖、clone 工具仓库
- 在 `us-east-1`、`us-east-2`、`us-west-2` 三个区域分别创建 Inference Profile
- 为每个 Profile 打上 MAP 标签
- 验证标签并输出汇总结果

## 清理

如需删除所有已创建的 Inference Profile：

```bash
curl -O https://raw.githubusercontent.com/ezhu0000/bedrock-map-tag/main/bedrock-tag-cleanup.sh
chmod +x bedrock-tag-cleanup.sh
./bedrock-tag-cleanup.sh
```

执行前会有确认提示，输入 `yes` 才会删除。

## 修改标签值

下载脚本后，编辑 tags 部分再执行：

```yaml
tags:
  - key: map-migrated
    value: migEDQGF-DEMO   # ← 改这里
  - key: Tagowner
    value: CDS-MAP         
  - key: environment
    value: production
```

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
