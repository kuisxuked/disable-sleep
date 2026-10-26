<div align="center">
  <img src="docs/assets/icon.png" width="84" alt="Disable Sleep 图标">
  <h1>Disable Sleep</h1>
  <p><strong>在菜单栏点一下，就能让 Mac 合盖后继续运行，不用反复输入终端命令。</strong></p>
  <p><a href="https://kuisxuked.github.io/disable-sleep/">项目主页</a> · <a href="https://github.com/kuisxuked/disable-sleep/releases/latest">下载 macOS 版</a> · <a href="README.md">English</a></p>
  <img src="docs/assets/demo.gif" width="760" alt="切换语言、禁止睡眠、选择永不、开始和取消倒计时的动态演示">
  <p><sub>演示录制自应用的真实原生界面，使用独立演示模式，不修改演示电脑的电源设置。</sub></p>
</div>

## 小巧，但够用

| 功能 | 用法 |
| --- | --- |
| 合盖继续运行 | 顶栏图标 → **Disable Sleep** 开关 |
| 定时开启或关闭 | 选择分钟数与操作，点「开始」，随时可取消 |
| 一直保持唤醒 | 时间选「永不」，点「开启」，直到手动关闭总开关 |
| 中英文切换 | 标题旁很小的 **中 / EN** 按钮 |
| 避开摄像头刘海 | 默认放在右侧，可按住 Command 拖动 |
| 后续开关免密 | 首次授权一次，只放行两条固定命令 |

## 快速上手（Quick Start）

[下载通用版 ZIP](https://github.com/kuisxuked/disable-sleep/releases/latest)，解压并打开 **Disable Sleep.app**。支持 **macOS 13+，Apple Silicon 和 Intel**。

也可以只用以下 **3 行**：

```sh
curl -fL https://github.com/kuisxuked/disable-sleep/releases/download/v1.4.1/DisableSleep-1.4.1-macOS-universal.zip -o DisableSleep.zip
ditto -x -k DisableSleep.zip .
open "Disable Sleep.app"
```

点顶栏的月亮／太阳图标。首次开关需要管理员授权一次，此后免密。需要开机自动运行时，可把应用加入「系统设置 → 通用 → 登录项」。

> **首次打开：** 此社区版本为本地签名，**没有 Apple 公证**，从网上下载后可能被 macOS 拦截。确认信任来源后，到「系统设置 → 隐私与安全 → 仍要打开」。参见 [Apple 官方说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)，无需全局关闭安全保护。

## 你需要知道的行为

- 开启执行 `pmset -a disablesleep 1`；关闭执行 `pmset -a disablesleep 0`。
- 这是系统级设置，同时影响电池与外接电源，也会禁止闲置睡眠；退出应用不会自动还原。关闭开关只是允许正常睡眠，不会立刻强制休眠；其他程序和 macOS 合盖模式也可能使电脑保持唤醒。合盖运行时请保持通风。
- 「永不」会取消已有倒计时，并一直禁止睡眠，直到手动关闭总开关。
- 倒计时支持 1–10080 分钟，一次一个。关闭总开关时暂停，重新开启后从剩余时间继续；关闭状态下新建的倒计时也会暂停。重启应用会保留暂停状态与剩余时间。
- 正在运行的倒计时在应用重新启动或电脑唤醒后，会在总开关开启时补执行；已暂停的倒计时会等你重新开启开关。倒计时**不会主动唤醒电脑**。

## 权限与隐私

首次设置会在 `/private/etc/sudoers.d/disablesleep-<当前 UID>` 写入一个由 root 拥有、权限 `0440` 的文件，只允许当前用户免密执行：

```text
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

不放行其他参数、Shell 或任意 `sudo`。同一用户运行的其他程序也可以执行这两条命令。程序不保存密码、不安装常驻 root 服务、不收集分析数据、不上传电源设置。安装前后均使用 `visudo` 校验，不修改主 sudoers 文件；需要系统保留默认的 `sudoers.d` 引用。

## 自行构建

安装 Apple Command Line Tools 后：

```sh
git clone https://github.com/kuisxuked/disable-sleep.git && cd disable-sleep
./build.sh && ./test.sh
open "Disable Sleep.app"
```

`./release.sh` 会构建 Intel + Apple Silicon 通用版，生成 ZIP 和 `SHA256SUMS.txt`。下载后可用 `shasum -a 256 -c SHA256SUMS.txt` 校验。测试不改动系统电源设置；具体合盖行为仍需在自己的硬件上验证。

## 卸载

想恢复正常睡眠时，先关闭总开关。用「活动监视器」退出应用，或在应用目录中执行：

```sh
open -n "Disable Sleep.app" --args --quit
sudo rm "/private/etc/sudoers.d/disablesleep-$(id -u)"
```

之后删除应用，并移除你添加的登录项。仅删除应用不会恢复睡眠或撤销免密授权。

## 分享与反馈

把[项目主页](https://kuisxuked.github.io/disable-sleep/)或[下载链接](https://github.com/kuisxuked/disable-sleep/releases/latest)发给朋友即可。[反馈问题](https://github.com/kuisxuked/disable-sleep/issues)时请附上 macOS 版本和 Mac 型号，勿上传密码或私人日志。

MIT 开源许可 · [kuisxuked](https://github.com/kuisxuked)
