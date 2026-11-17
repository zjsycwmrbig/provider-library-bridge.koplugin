# 在线书库本地书架

[![Checks](https://github.com/zjsycwmrbig/provider-library-bridge.koplugin/actions/workflows/check.yml/badge.svg)](https://github.com/zjsycwmrbig/provider-library-bridge.koplugin/actions/workflows/check.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)

**Provider Library Bridge for KOReader** — expose books from online reading
plugins in KOReader's local library, with covers and provider badges.

把在线阅读插件的已知书架同步为 KOReader 本地书库中的占位书。默认包含尚未缓存
章节的书，也可以切换为只同步已有本地缓存的书。

当前包含三个 Provider：

- 番茄小说
- 微信读书
- Suwayomi

插件不会修改番茄小说或微信读书插件。点击占位书时，本插件通过各来源插件已有的
实例接口打开对应书。

当前为 **v0.7.0 公开预览版**。已完成 Kindle 安装、文件校验、Lua 测试及三款
默认封面的实机引擎渲染验证；重启后的完整书架显示、标签位置和点击跳转仍需进一步验证。

## 安装与升级

1. 安装并启用下方兼容表中的至少一个来源插件。默认同步“已知书架”，因此至少
   打开或刷新一次来源插件书架，让插件保存本地书架快照；若选择“仅已缓存”，还需
   在来源插件内缓存书籍章节。
2. 从 [Releases](https://github.com/zjsycwmrbig/provider-library-bridge.koplugin/releases)
   下载名为 provider-library-bridge.koplugin-vX.Y.Z.zip 的安装包。
3. 退出 KOReader，把压缩包中的 **provider-library-bridge.koplugin** 文件夹放入
   KOReader 的 plugins 目录。Kindle 上的典型路径为：

   ```text
   /mnt/us/koreader/plugins/provider-library-bridge.koplugin/main.lua
   ```

4. 重启 KOReader，进入 **工具 → 在线书库本地书架 → 立即同步**。

升级时先退出 KOReader，用新安装包替换同名插件文件夹，再重启并立即同步。
设置和封面缓存保存在插件目录之外。避免形成两层同名 .koplugin 文件夹。

首次发布前也可以克隆仓库后运行 ./scripts/package.sh 构建安装包。
GitHub 自动生成的 Source code ZIP 会包含仓库外层目录，建议使用 Release 附件。

## 兼容范围与依赖

| 组件 | 当前范围 |
| --- | --- |
| Kindle + KOReader | 已在 KOReader v2026.07.1 环境安装并验证封面渲染；完整 UI 验收仍在进行 |
| 默认书库路径 | /mnt/us/Books，目前按 Kindle 配置，尚未提供图形化路径选择 |
| [番茄小说插件](https://github.com/hesan1232/fanqie.koplugin) | 适配实例名 fanqie；依赖缓存目录、书架缓存和 openBook 接口；具体已测版本号暂未记录 |
| [微信读书插件](https://github.com/finlater/weread.koplugin) | 适配实例名 weread；已测环境日志为 v1.7.0，依赖缓存元数据和打开书籍接口 |
| [Suwayomi Client](https://github.com/LK4D4/suwayomi.koplugin) | 适配实例名 suwayomi；读取本地 Library 快照、章节缓存和下载账本，点击后进入章节列表 |
| Cover browser / SimpleUI | 普通列表显示来源文字；封面网格通过运行时补丁绘制标签，依赖内部布局，更新后可能需要重新适配 |
| Kobo / Android / 桌面端 | 尚未验证；默认路径和封面渲染能力可能需要适配 |

来源仓库链接用于说明适配目标；接口兼容性以实际安装版本为准。仅需安装使用的来源
插件，不要求两个都安装。占位书只保存元数据、封面和来源书号，不会下载或合并小说
正文；尚未缓存的书会在来源阅读界面中按需获取。

## 默认封面预览

下面三图由 Kindle 的 CRE/LunaSVG 引擎实际渲染，使用示例书名和作者；
它们是封面资源预览，并非书架截图。来源标签由书架界面单独叠加。

| 暗日 | 流线 | 墨格 |
| --- | --- | --- |
| ![暗日默认封面](docs/images/cover-eclipse.png) | ![流线默认封面](docs/images/cover-current.png) | ![墨格默认封面](docs/images/cover-lattice.png) |

[界面布局示意](docs/UI.md)展示来源标签和设置菜单的结构，尚未作为实机截图验证。

## 功能

- 可同步来源插件已知书架中的全部书，也可切换为只同步已缓存书籍；
- 可扫描来源插件，并逐个勾选参与同步的 Provider；
- Suwayomi 以漫画为单位生成一本占位书，而不是为每个章节生成一本；
- 为缓存和未缓存书生成很小的 HTML 占位书；
- 把来源标签保存在占位书 sidecar 中，不污染书名和封面；
- 将来源名称写入 KOReader 的系列和关键词元数据；
- 优先同步来源已有的封面，失败时从三套内置纯 SVG 封面中选择一套；
- 在普通列表右侧显示“番茄 · 大小”或“微信读书 · 大小”；
- 在封面网格上叠加不写入图片的来源 badge；
- 文件名和书名会移除括号、冒号、破折号等标点与符号；
- 占位页按卡片显示阅读进度、上次章节、章节缓存、本地占用和同步时间；
- 书架百分比直接使用来源阅读进度，不依赖占位 HTML 自身的页数；
- 占位书移动或放进新建文件夹后，同步会按 sidecar 身份重新发现原文件；
- 占位书作为唯一历史记录，来源章节文件自动归并回对应占位书；
- 手动同步；
- KOReader 运行期间的定时同步；
- 同步和打开进度提示显示在屏幕底部；
- 只删除本插件明确创建并带有效标记的占位文件。

## 目录

默认直接平铺写入：

```text
/mnt/us/Books/
├── 书名 [书号].html
├── 另一本书 [书号].html
└── ...
```

占位书文件名带有稳定书号，来源标签保存在对应的 `.sdr` 元数据中，例如：

```text
无人逝去 [7277393036894538793].html
三体全集 全三册 [695233].html
```

## 使用

在 KOReader 文件管理器中打开：

**工具 → 在线书库本地书架**

二级菜单包含：

- 立即同步
- 同步范围
- 同步来源
- 定时同步
- 同步间隔
- 上次同步
- 清除在线书库占位书

定时同步仅在 KOReader 运行期间生效，不在系统后台常驻。

“同步来源”会列出当前插件包含的全部 Provider。已安装并启用的来源插件显示为可勾选；
插件缺失或停用时显示“插件未启用”。“重新扫描来源插件”会重新加载 Provider 适配器
并刷新可用状态。

## 同步范围

默认范围是 **已知书架（含未缓存）**：

- 番茄读取来源插件保存的 `shelf_cache.lua`；此外仍会保留已有章节缓存的本地书。
- 微信读书优先读取来源插件 `library_db` 中的书架快照，并合并本地缓存记录。
- Suwayomi 合并 `library_cache`、`chapter_cache`、`chapter_ledger` 和阅读返回上下文。
- 已有官方封面会继续复用；未缓存书也会尝试获取书架提供的封面。
- 点击未缓存书时，番茄可联网打开目录；微信读书会先显示书籍详情，供下载或开始阅读。

“仅已缓存”范围沿用早期行为，只同步至少有一个本地缓存章节或完整文件的书。

同步本身不会为了更新书目而额外请求来源网络；请先在来源插件中刷新一次书架。
切换为更窄的范围不会自动删除之前已生成的占位书，需要时可先执行“清除在线书库占位书”
再重新同步。

Suwayomi 没有本地章节的 Library 漫画也会显示；`仅已缓存` 只保留至少有一个现存
本地 CBZ 的漫画。打开占位书会进入 Suwayomi 章节列表，后续下载、阅读和同步继续
由 Suwayomi 插件管理。

## 文件夹与路径

同步前会递归扫描目标书库中的 HTML 占位书，并读取对应的
`provider_library_placeholder` sidecar 标记。相同 Provider 和书号即使被移入
“已读”等新文件夹，也会复用移动后的路径，不会在根目录重新生成。

文件移动后，占位书索引和历史记录会更新到新路径。若同一本书发现多份已验证副本，
插件选择最近打开或修改的一份作为规范路径，不会自动删除另一份。

## 封面与显示

占位书通过 KOReader 的原生自定义封面机制写入。官方封面可能是 JPG/PNG，
默认封面从 SVG 模板生成，使用内置霞鹜文楷 Lite 渲染并缓存为 PNG，
避免部分界面的 SVG 渲染器不支持文字：

```text
书名.sdr/cover.jpg
书名.sdr/cover.png
```

可以在“封面网格”“带封面详细列表”等显示模式中显示。纯文字列表本来不显示图片。
来源标签单独绘制在书架界面中，不烘焙进封面。

书架进度写入 KOReader 原生 `percent_finished` 字段。来源进度为 42% 时，占位书
也显示 42%，达到 99.5% 后标记为完成。打开占位书时，来源插件切换到真实章节，
保存设置钩子会避免占位 HTML 的一页进度反向覆盖来源进度。

番茄在联网同步时还会调用来源插件的云端阅读进度接口，并优先使用服务端
`read_progress`；云端不可用时才回退到本地书架快照。同步会检查
`percent_finished` 是否真的等于占位书标记中的进度，即使其他书籍信息没有变化，
进度字段缺失或过期也会强制修复。

通用封面位于 `assets/generic-covers/`，由 `provider_library/generic_cover.lua`
按书籍生成标题和作者。三套封面分别是“暗日”“流线”和“墨格”，会根据
Provider 与书号稳定选择，因此同一本书不会每次同步都换封面。
已下载的官方封面会缓存并在离线同步时复用。Suwayomi 会读取其
`poster`/`manga_cover` 本地缩略图缓存；服务器可用时也会补抓封面。内置字体采用 SIL OFL 1.1，
来源为 https://github.com/lxgw/LxgwWenKai-Lite ，许可证随字体保存在 assets/fonts/OFL.txt。

Suwayomi 显示标题保留来源书名中的冒号等标点；其他来源继续使用通用标题符号清洗规则。

## 打开流程

1. 用户在本地书库点击占位书；
2. KOReader 加载占位 HTML；
3. 本插件读取 `.sdr` 中的 Provider 标记；
4. 保留占位书历史，并把来源章节历史归并到对应占位书；
5. 调用对应来源插件的打开方法；
6. 阅读进度和章节同步仍由来源插件管理；Suwayomi 会进入对应漫画的章节列表。

来源插件未启用或接口发生变化时，占位书会保留，并显示错误提示。

## 历史记录

KOReader 在文档打开时先写入 `ReadHistory`。本插件会把番茄、微信读书缓存目录中的
实际章节文件映射回对应占位书，因此 SimpleUI 历史中只显示一本来源一致的占位书。
以前同一本微信读书积累了多个章节历史时，下次同步会合并为一条，并保留最新时间。

历史映射保存在 KOReader 的全局设置中，来源插件和 SimpleUI 都不需要修改。

## Provider

Provider 位于 `provider_library/providers/`，由注册器动态发现，不限于番茄小说。

每个 Provider 需要实现：

```lua
return {
    id = "provider_id",
    label = "显示名称",
    tag = "标签",
    plugin_name = "来源插件实例名",
    scan = function(self, plugin_instance) ... end,
    open = function(self, plugin_instance, book) ... end,
}
```

`scan()` 返回书目数组；`open()` 调用来源插件已有接口。

Provider 还可以实现可选的进度刷新接口：

```lua
prepare = function(self, plugin_instance, book)
    ...
    return book
end
```

桥接插件会在打开占位书前调用 `prepare()`。番茄 Provider 使用它重新读取书架
缓存和云端阅读进度，避免落在同步占位书时保存的旧章节。

## 卸载与数据位置

如需移除占位书，先使用 **工具 → 在线书库本地书架 → 清除在线书库占位书**。
该操作仅针对带有效标记的本插件占位文件；不会清除来源插件缓存的章节。
随后退出 KOReader，删除 plugins/provider-library-bridge.koplugin 文件夹。

Kindle 上本插件的数据位置：

| 内容 | 路径 |
| --- | --- |
| 设置和占位书索引 | /mnt/us/koreader/settings/provider_library_bridge.lua |
| 下载封面、生成封面 | /mnt/us/koreader/provider-library-bridge/ |
| 占位书和 sidecar | /mnt/us/Books/ 下的 HTML 及同名 .sdr 目录 |

卸载插件不会自动删除上述数据。不要直接删除整个 Books、settings 或来源插件目录。

## 常见问题

- **菜单没有出现：** 检查文件夹层级、插件是否启用，然后重启 KOReader。菜单在文件管理器中显示。
- **同步为零：** 先确认来源插件已启用，并在来源插件中打开或刷新一次书架；若使用“仅已缓存”，还要确认书籍已有本地缓存。
- **封面未变化：** 升级后重启并立即同步，再刷新文件列表；纯文字模式不会显示封面。
- **打开后章节过旧：** 番茄会尝试读取最新本地和云端进度；网络失败时只能使用已有数据。
- **详情数据为空：** 来源插件未提供的字段显示暂无数据，不会从其他账户补取统计。
- **定时同步没有执行：** 只在 KOReader 运行且未挂起时检查，不会唤醒设备，也不创建系统后台服务。

更多问题请 [提交 Issue](https://github.com/zjsycwmrbig/provider-library-bridge.koplugin/issues/new/choose)，
提供相关版本与已脱敏日志。

## 开发、发布与许可证

- [开发与测试](docs/DEVELOPMENT.md)
- [贡献指南](CONTRIBUTING.md)
- [v0.7.0 发布说明](docs/releases/v0.7.0.md)
- 代码和原创 SVG： [AGPL-3.0](LICENSE)
- 内置字体：SIL OFL 1.1，见 [第三方声明](THIRD_PARTY_NOTICES.md)

本项目为社区插件，与 KOReader、番茄小说及微信读书的官方运营方无隶属关系。
