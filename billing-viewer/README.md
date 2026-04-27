# 创建账单查看 IAM 用户

在 AWS CloudShell 中一键创建具有账单只读权限的 IAM 用户。

## 使用方式

```bash
curl -O https://raw.githubusercontent.com/ezhu0000/bedrock-map-tag/main/billing-viewer/create-billing-viewer.sh
chmod +x create-billing-viewer.sh
./create-billing-viewer.sh -p 'YourPassword123!'
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-p` | IAM 用户登录密码（**必填**） | 无 |
| `-u` | IAM 用户名（可选） | billing-viewer |

## 脚本功能

1. 创建 IAM 用户并设置控制台登录密码（首次登录需改密）
2. 创建并附加账单只读策略，包含：
   - Billing 控制台查看
   - Cost Explorer 访问
   - Budget 查看
   - 账单报告和支付信息查看
3. 输出登录 URL 和用户信息

## 前置条件

- 执行者需要有 IAM 管理权限
- 如需 IAM 用户查看账单，需 root 用户先激活 "IAM Access to Billing Information"（脚本会检测并提示操作步骤）
