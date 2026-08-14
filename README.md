# 51（51 记账）

51 是一款原生简体中文界面的本地优先 iOS 记账应用，使用 SwiftUI、SwiftData 和本地 SQLite 构建。

## 项目架构

- 界面层：SwiftUI，所有用户可见文字、提示、错误信息、操作说明和视图内容均使用简体中文。
- 数据层：SwiftData + 本地 SQLite，支持离线使用，本地数据库是数据源。
- AI 引擎：支持多模态和大语言模型接口，包括 OpenAI 兼容接口、DeepSeek 和 Claude，可将中文自然语言及发票、收据图片解析为结构化交易。
- 账务层：账户、交易、分录、分类、负债、返现和多账户拆分支付均有明确模型。
- 导出层：导出 Beancount 纯文本复式记账格式。
- 备份层：支持 WebDAV、GitHub API 自动提交、iCloud Drive 和本地文件导出。

## 核心功能

- 全负债核算：信用卡、贷款和其他负债均可作为独立账户管理。
- 返现处理：返现计入收入，并冲销对应负债，保持原始消费和返现记录透明可审计。
- 多账户拆分支付：一笔交易可以由多个资产账户或负债账户共同支付。
- AI 快速记账：输入中文自然语言，或上传发票、收据图片，自动识别商户、金额、日期、分类、支付账户、负债和返现。
- Beancount 导出：生成可审计、可迁移的纯文本复式记账文件。

## 目录结构

```text
51-Accounting/
├── 51App.swift
├── Models/
│   ├── Account.swift
│   ├── Transaction.swift
│   ├── Posting.swift
│   └── Category.swift
├── AI/
│   └── AIBookkeepingManager.swift
├── Sync/
│   └── BackupManager.swift
├── Export/
│   └── BeancountExporter.swift
└── Views/
    ├── ContentView.swift
    ├── QuickAddAIView.swift
    ├── DashboardView.swift
    └── SettingsView.swift
```

## 中文化约定

应用中的用户界面、视图标题、按钮、提示、错误信息、日志、注释和 AI 默认提示词统一使用简体中文。代码标识符保留 Swift 约定，以便与系统框架和开发工具兼容。服务商密钥应保存到钥匙串或安全配置中，不要提交到代码仓库。

## 云端备份

- WebDAV：上传 JSON 或 Beancount 快照。
- GitHub：通过 GitHub API 将导出文件自动提交到指定仓库。
- iCloud Drive：写入应用的 iCloud 容器。
- 本地导出：通过系统分享面板导出 JSON 或 Beancount 纯文本。

创建 Xcode 的 SwiftUI 应用目标后，将源文件加入目标，并按需要启用 SwiftData 与 iCloud 权限。