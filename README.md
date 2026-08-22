# DSH 一键安装器

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（dsh）的 Windows 一键安装工具。

双击安装程序即可在目标电脑上：
1. 检测并（按需）安装 Node.js LTS；
2. 通过 npm 全局安装 `@deepseek-ai/dsh`；
3. 把启动器和图标放到 `%LOCALAPPDATA%\DeepSeekHarness`；
4. 在**桌面**和**开始菜单**创建名为 **DeepSeek Harness** 的快捷方式（图标来自 `assets/test2.png`）。

点击快捷方式后：
- 自动启动 dsh 服务（`dsh web --no-open`）；
- 用 **Microsoft Edge 应用模式**（`--app=http://127.0.0.1:3080`）打开 DSH Web UI；
- 得到一个**独立窗口、无地址栏/标签页**的“像程序一样”的界面；
- Edge 应用窗口在**任务栏**也会显示你提供的鲸鱼图标（通过专用应用快捷方式 `DeepSeekHarnessEdge.lnk` 绑定）。

## 目录结构

```
dsh-installer/
├─ assets/
│  ├─ test2.png        # 图标源文件（256×256）
│  ├─ dsh.ico          # 由 test2.png 生成的整套图标（16~256）
│  └─ icon-*.png       # 各尺寸 PNG（构建产物）
├─ src/
│  ├─ Installer.cs     # C# 启动器：UAC、解包资源、调用 PowerShell
│  ├─ install.ps1      # 安装逻辑：Node/dsh/快捷方式
│  └─ launch-dsh.cmd   # 启动器：起服务 + Edge App 模式 + 任务栏图标
├─ dist/
│  └─ DSH-Setup.exe    # 生成好的安装程序（仓库内已附带）
├─ build.ps1           # 可复现构建脚本
├─ README.md
└─ LICENSE
```

## 使用

把 `dist\DSH-Setup.exe` 拷贝到其它 Windows 电脑，双击即可。

命令行 / 无人值守：`DSH-Setup.exe --silent`

## 从源码构建

需要 Windows 系统，并满足：
- .NET Framework 4.x（自带 `csc.exe`）
- Windows PowerShell 5.1+
- 用于图标生成的 System.Drawing（PowerShell 自带）

```powershell
.uild.ps1
```

脚本会从 `assets/test2.png` 生成 `assets/dsh.ico`，并用 `csc.exe` 编译出 `dist\DSH-Setup.exe`。

## 开源许可

[MIT](./LICENSE)
