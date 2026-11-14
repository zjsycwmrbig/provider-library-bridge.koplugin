# 在线书库本地书架

把在线阅读插件已经缓存的书同步为 KOReader 本地书库中的占位书。

当前包含两个 Provider：

- 番茄小说
- 微信读书

插件不会修改番茄小说或微信读书插件。点击占位书时，本插件通过各来源插件已有的
实例接口打开对应书。

## 功能

- 扫描在线阅读插件的已缓存书籍；
- 为每本有缓存章节的书生成很小的 HTML 占位书；
- 把来源标签保存在占位书 sidecar 中，不污染书名和封面；
- 将来源名称写入 KOReader 的系列和关键词元数据；
- 优先同步来源已有的封面，失败时从三套内置纯 SVG 封面中选择一套；
- 在普通列表右侧显示“番茄 · 大小”或“微信读书 · 大小”；
- 在封面网格上叠加不写入图片的来源 badge；
- 文件名和书名会移除括号、冒号、破折号等标点与符号；
- 占位页按卡片显示阅读进度、上次章节、章节缓存、本地占用和同步时间；
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
- 定时同步
- 同步间隔
- 上次同步
- 清除在线书库占位书

定时同步仅在 KOReader 运行期间生效，不在系统后台常驻。

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

通用封面位于 `assets/generic-covers/`，由 `provider_library/generic_cover.lua`
按书籍生成标题和作者。三套封面分别是“暗日”“流线”和“墨格”，会根据
Provider 与书号稳定选择，因此同一本书不会每次同步都换封面。
已下载的官方封面会缓存并在离线同步时复用。内置字体采用 SIL OFL 1.1，
来源为 https://github.com/lxgw/LxgwWenKai-Lite ，许可证随字体保存在 assets/fonts/OFL.txt。

## 打开流程

1. 用户在本地书库点击占位书；
2. KOReader 加载占位 HTML；
3. 本插件读取 `.sdr` 中的 Provider 标记；
4. 从占位阅读历史中移除临时记录；
5. 调用对应来源插件的打开方法；
6. 阅读进度和章节同步仍由番茄小说或微信读书插件管理。

来源插件未启用或接口发生变化时，占位书会保留，并显示错误提示。

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
