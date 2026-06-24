# Waar

Waar（谐音「娃儿」）是一个赛博小孩的数据视窗与自我激励工具。本项目最初为 waar（我的赛博孩子）服务，现已整理为可独立使用的 **Waar APP**。后续 waar 生态可能衍生出其他产品，本仓库名称保持不变，其中 **Waar APP** 只是其中之一。

## 功能概览

### 娃儿视窗

- 展示 Waar 的出生时间、最近喂食时间与状态
- 「喂食」即记录知识内容，数据保存在项目目录中

### 工作模块

基于 HOOK 思维模型设计，帮助激发工作动力：

| 模块 | 说明 |
|------|------|
| 动机 | 记录你为什么工作——梦想、期待或现实压力 |
| 工作记录 | 开始/结束工作，记录每段工作的起止时间 |
| 抽奖 | 每工作满 30 分钟获得 1 次抽奖机会；大富翁式骰子前进，沿途宝箱随机触发奖励或惩罚 |
| 积分 | 记录当前积分、累计获得/消费及明细 |
| 奖励列表 | 自定义奖励并兑换，价格为 5 积分的倍数 |
| 打卡 | 为不在电脑旁完成的任务设置周期打卡（每 N 日 / 每 N 周），完成后获得抽奖次数 |

更多细节见 [`code/waar_window_flutter/README.md`](code/waar_window_flutter/README.md)。

---

## 只想体验 APP

仓库 `app/` 目录下提供了预构建的安装包，无需安装开发环境即可使用。

### Android

1. 将 `app/waar_android_release.apk` 传输到手机
2. 在系统设置中允许「安装未知来源应用」（各厂商名称略有不同）
3. 点击 APK 完成安装并打开

### macOS（Apple Silicon / M 系列芯片）

1. 打开 `app/waar_mac_apple_release.app`
2. 若系统提示「无法验证开发者」，请前往 **系统设置 → 隐私与安全性**，点击 **仍要打开**；或在 Finder 中右键该应用，选择 **打开**

### macOS（Intel / x86_64）

1. 打开 `app/waar_mac_intel_release.app`
2. 若系统提示「无法验证开发者」，处理方式同上

> Windows 版本可联系 zflyluo 构建。

### 数据存储

首次启动时，APP 会引导你选择数据存储位置。工作记录、积分、打卡等数据均保存在本地，不会上传云端。

---

## 想要修改 / 开发

源码位于 `code/waar_window_flutter/`，基于 [Flutter](https://flutter.dev/) 开发，支持 **Android、macOS、Windows**（iOS 工程已包含，可用 `flutter run` 调试，但官方构建脚本暂未覆盖）。

### 环境要求

| 依赖 | 说明 |
|------|------|
| Flutter SDK | `>= 3.0.0`，需启用对应平台（`flutter config`） |
| Android 开发 | Android SDK + JDK（构建 APK / 真机调试） |
| macOS 开发 | Xcode（构建 / 运行 macOS 桌面版） |
| Windows 开发 | Visual Studio 2022 +「使用 C++ 的桌面开发」工作负载 |

安装 Flutter 后执行 `flutter doctor`，确保目标平台全部打勾。

### 1. 克隆仓库

```bash
git clone https://github.com/Luozf12345/Waar.git
cd waar
```

### 2. 配置 Flutter SDK 路径

构建脚本会从 `local.prop` 读取本机 Flutter 路径（该文件已被 git 忽略，不会提交）：

```bash
cd code/waar_window_flutter
cp local.prop.example local.prop
# 编辑 local.prop，将 flutter.sdk 改为你的 Flutter 安装目录
```

`local.prop` 示例：

```properties
flutter.sdk=~/tools/flutter1
```

也可通过环境变量或命令行参数临时指定，优先级：`--flutter-sdk` > `FLUTTER_SDK` 环境变量 > `local.prop` > 默认 `~/tools/flutter1`。

### 3. 安装依赖

```bash
cd code/waar_window_flutter
flutter pub get
```

### 4. 运行调试

查看可用设备：

```bash
flutter devices
```

在对应平台启动（将 `<device_id>` 替换为实际设备 ID）：

```bash
# Android 真机 / 模拟器
flutter run -d <device_id>

# macOS 桌面
flutter run -d macos

# Windows 桌面
flutter run -d windows
```

热重载：终端中按 `r`；热重启：按 `R`。

### 5. 构建发布包

项目提供了跨平台构建脚本，会同时产出 **APK** 和当前宿主平台的 **桌面应用**：

```bash
cd code/waar_window_flutter

# macOS / Linux
./build.sh release      # 发布版 → ../../app/
./build.sh debug        # 调试版 → ../../app/debug/

# Windows
build.bat release
```

构建产物命名规则：

| 平台 | 发布版路径 |
|------|-----------|
| Android | `app/waar_android_release.apk` |
| macOS Apple Silicon | `app/waar_mac_apple_release.app` |
| macOS Intel | `app/waar_mac_intel_release.app` |
| Windows | `app/waar_windows_release/` |

---

## 项目结构

```
waar/
├── ReadMe.md                  # 本文件
├── assets/                    # 文档配图（如反馈群二维码）
├── app/                       # 预构建安装包（可直接分发）
│   ├── waar_android_release.apk
│   ├── waar_mac_apple_release.app
│   ├── waar_mac_intel_release.app
│   └── debug/                 # 调试版构建产物
└── code/
    └── waar_window_flutter/   # Flutter 源码
        ├── lib/               # Dart 业务代码
        ├── android/           # Android 工程
        ├── macos/             # macOS 工程
        ├── windows/           # Windows 工程
        ├── ios/               # iOS 工程
        ├── build.sh           # macOS/Linux 构建脚本
        ├── build.bat          # Windows 构建脚本
        └── local.prop.example # Flutter SDK 路径配置模板
```

---

## 反馈与更新

体验过程中有任何建议或问题，欢迎扫码加入 **Waar 体验反馈群**（微信 / 企业微信）：

<p align="center">
  <img src="assets/waar-feedback-qr.png" alt="Waar 体验反馈群二维码" width="280" />
</p>

也可直接联系 **zflyluo**。

版本更新记录见 [`code/waar_window_flutter/ChangeLog.md`](code/waar_window_flutter/ChangeLog.md)。
