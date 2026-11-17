# 开发与发布

## 本地检查

依赖 Lua 5.1 或 LuaJIT，以及 Bash、zip、unzip。无需 Calibre，也无需连接 Kindle
即可运行单元测试。

    ./scripts/check.sh
    LUA_BIN=lua5.1 ./scripts/check.sh
    ./scripts/package.sh

每个 spec 使用独立 Lua 进程。测试会模拟 KOReader 模块，覆盖书名清洗、模板资源
查找、Provider 同步范围、文件夹路径重发现、历史记录归并、原生阅读进度、
封面输出接口、详情卡片及离线官方封面缓存。不能替代设备 UI 验证。

package.sh 固定输出目录名 provider-library-bridge.koplugin，避免 clone 到不同
名称目录后产生 KOReader 无法识别的安装包。dist/ 是生成文件，不提交到源码。

## 设备验证

scripts/verify_device_covers.lua 在设备 KOReader 目录运行：

    BRIDGE_PLUGIN_PATH=/mnt/us/koreader/plugins/provider-library-bridge.koplugin BRIDGE_TEST_OUTPUT=/tmp/bridge-cover-check ./luajit - < /path/to/verify_device_covers.lua

脚本仅在指定输出目录生成三款测试封面，不打开设备屏幕、不触发书库同步。
需自行清理测试输出。真实封面验证还应检查：官方封面优先、离线复用、中文书名、
长标题、角标位置、缓存失效及新版对旧占位书的迁移。

## Provider 接口

Provider 位于 provider_library/providers，由 registry 动态发现。
必须提供 id、label、tag、plugin_name、scan(self, instance, options)、
open(self, instance, book)。
可提供 prepare(self, instance, book) 在打开前更新进度。

options.scope 为 known_shelf 或 cached_only。known_shelf 应合并来源插件的已知
书架和已有本地缓存；cached_only 只返回已有缓存的书。

scan 返回书目数组，包含 book_id、title、author、缓存章节数、总章节数、cover_url、
cover_path、book 等字段。book 是传递给来源插件的参数；不要将账号或 Token 放入其中。
progress_percent 接受百分数或 0～1 比例，但应保持来源侧单位一致；未知数据保持 nil。

## 发布

1. 更新 _meta.lua 中的版本，并新增 docs/releases/vX.Y.Z.md。
2. 运行检查、打包和相关实机验收。注明已测和未测范围。
3. 提交所有改动；本仓库维护约定的提交信息以 [ai] 开头。
4. 推送 main 后创建标签，例如 git tag v0.6.0，再 git push origin v0.6.0。
5. Release 工作流验证标签与版本一致，自动创建预发布版并附 ZIP、SHA256SUMS。
6. 充分实机验证后，在 GitHub 编辑 Release，取消 prerelease 标记。

自动发布默认始终为预发布，避免将尚未完成设备验收的版本当成稳定版。
没有标签时，普通 push 只执行 Checks，不会创建 Release。

## 资源与许可

Lua 和原创 SVG 使用 AGPL-3.0；内置字体使用 OFL。新增依赖需补充
THIRD_PARTY_NOTICES.md。文档图片仅使用原创示意图或虚构信息的渲染样本。
