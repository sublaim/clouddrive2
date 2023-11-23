
# 通知
2023年11月21日之前的命令由于更换镜像地址已无法使用.  

# 一键安装 Clouddrive2 脚本
脚本非官方出品，由于官方帮助不适合新手故写此脚本。指在帮助新手用户快速使用 clouddrive2 挂载网盘。

## 目录
- [通知](#通知)
- [一键安装 Clouddrive2 脚本](#一键安装-clouddrive2-脚本)
  - [目录](#目录)
  - [推荐码](#推荐码)
  - [安装](#安装)
    - [安装命令](#安装命令)
    - [卸载命令](#卸载命令)
  - [安卓](#安卓)
    - [安装 (未ROOT设备)](#安装-未root设备)
    - [安装 (已ROOT设备)](#安装-已root设备)
    - [卸载](#卸载)
  - [一键开启 SMB 与 NFS 共享](#一键开启-smb-与-nfs-共享)
    - [共享](#共享)
    - [取消共享](#取消共享)
  - [如何更新?](#如何更新)
  - [在哪运行？](#在哪运行)
    - [OpenWRT](#openwrt)
    - [Mac](#mac)
    - [Linux](#linux)
    - [安卓](#安卓-1)
  - [问与答](#问与答)
    - [通规问题](#通规问题)
    - [安装问题](#安装问题)
    - [安装后问题](#安装后问题)
    - [安卓问题](#安卓问题)
  - [问题反馈群](#问题反馈群)

## 推荐码
使用推荐码购买cd2会员最高可以优惠100元  

我的推荐码：**`Xm3K25D3`**

支持
- [X] Linux
- [X] MacOS
- [X] OpenWRT
- [X] Android-Termux
- [X] 理论上支持所有安装了 docker 的设备如: iStore OS
- [X] 理论上支持所有 OpenWRT 及其衍生的系统

## 安装
### 安装命令
- Mac、Linux、OpenWRT等 在「终端」运行下面的「命令」  
- 不知道在哪里运行这些命令？[点击查看](#在哪运行)  
- 镜像加速和代理的区别? [点击查看](#通规问题)  
- 由于镜像站经常被墙或其它原因经常变动导致无法使用请用下面的「代理」命令,前提是你有开了代理  
- 优先使用 docker 的安装方式.如果没有docker会使用其它方式安装  

```shell
# 国内镜像加速
curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2.sh" | bash -s install mirror
# 代理
curl -fsSL "https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2.sh" | bash -s install
```

### 卸载命令
```shell
# 国内镜像加速
curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2.sh" | bash -s uninstall mirror
# 代理
curl -fsSL "https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2.sh" | bash -s uninstall
```

## 安卓
安卓在termux里运行下面的「命令」  

### 安装 (未ROOT设备)
- 以下命令2选1  
```shell
# 镜像加速
curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2-termux.sh" | bash -s install mirror
# 代理
curl -fsSL "https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2-termux.sh" | bash -s install
```

### 安装 (已ROOT设备)
- 以下命令2选1  
```shell
# 镜像加速
curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2-termux.sh" | bash -s install root mirror
# 代理
curl -fsSL "https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2-termux.sh" | bash -s install root
```

### 卸载
- 以下命令2选1  
```shell
# 镜像加速
curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2-termux.sh" | bash -s uninstall
# 代理
curl -fsSL "https://raw.githubusercontent.com/sublaim/clouddrive2/main/cd2-termux.sh" | bash -s uninstall
```

## 一键开启 SMB 与 NFS 共享
- **前提是使用一键安装脚本安装的 cd2 且网盘挂载目录为/CloudNAS**  
- 只支持 Openwrt 系列及其衍生版, 大部分设备可以开启 SMB, NFS能不能开启看固件  
- GL.iNET 设备需要提前在主路由界面 -> 应用程序 -> 网络共享或文件共享 -> 开启 samba  

### 共享
- 以下命令2选1  
```shell
# 国内镜像加速
curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/sublaim/clouddrive2/main/shares.sh" | bash -s shares
# 代理
curl -fsSL "https://raw.githubusercontent.com/sublaim/clouddrive2/main/shares.sh" | bash -s shares
```

### 取消共享
- 以下命令2选1  
```shell
# 国内镜像加速
curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/sublaim/clouddrive2/main/shares.sh" | bash -s unshares
# 代理
curl -fsSL "https://raw.githubusercontent.com/sublaim/clouddrive2/main/shares.sh" | bash -s unshares
```


## 如何更新?
请使用官方内置的更新方式: 点击右上角的`!`号

<img src="./images/update1.png" width="20%">

<img src="./images/update2.png" width="30%">

## 在哪运行？
### OpenWRT
在左侧菜单里一般有「终端」或「TTYD 终端」，登录用户名一般为root，密码为你的OP密码。  
如果没有, 请使用 ssh 连接.

<img src="./images/op1.png" width="50%">

<img src="./images/op2.png" width="50%">

### Mac
打开「启动器」在上面的「搜索框」搜索「终端」或「terminal」  

第1步  

<img src="./images/mac1.png" width="30%">   
第2步  

<img src="./images/mac2.png" width="70%">   

### Linux
Linux 桌面环境下的「终端」名称不同, 可自行查找

### 安卓
打开「Termux」输入命令

<img src="./images/termux.png" width="20%">


## 问与答
这里解决的问题主要来源于群友的反馈

### 通规问题
**国内镜像加速和代理有什么区别？**  
> *镜像加速优点是不使用代理工具可以运行. 缺点是镜像加速地址经常失效导致命令经常变动.*  
> *代理优点是命令不会变动. 代理缺点是国内无法直接使用需要改hosts或其它代理的方式才能运行.*  

**cd2安装在了哪里?**  
> *docker默认挂载点在 /CloudNAS*  
> *安卓默认安装在/data/data/com.termux/files/home/clouddrive/*  
> *其它平台默认安装在 /opt/clouddrive/*  

**怎么修改默认的SMB密码?**  
> *smbpasswd -a root*  

### 安装问题  
**-ash: bash: not found**  
**curl: (23) Failure writing output to destination**  
> *多出现在 GL.iNet 上的 MTxxxx设备上.*  
> *使用 opkg install bash 安装bash即可*  

**curl: (35) Recv failure: Connection reset by peer**  
> *重启「终端」*  

**docker: Error response from daemon: path /CloudAS is mounted on/ but it is nota shared mount.**  
> *把 `mount --make-shared /` 插入到「启动项」->「本地启动脚本」中的 'exit 0' 之前*  

### 安装后问题
**IO Error find fusermount binary failed CannotFindBinaryPath**  
> *FUSE3缺失*  
> *OP使用opkg update && opkg install fuse3-utils libfuse3-3 安装.*  
> *Linux因各发行版不同自行安装*  

**IO error fusemount run failed**  
> *ls /dev/fuse | grep fuse 如果没有没输出则是缺少fuse模块*  

**登录一直提示连接超时**  
> *用「卸载命令」再重装*

**为何挂载后 Emby/Jellyfin 看不到这个挂载目录**  
> *在 Emby/Jellyfin 的 docker run 命令中加入 -v /CloudNAS:/CloudNAS 即可将目录挂载到 Emby/Jellyfin 容器*   

**怎么修改为只有指定设备才能访问 NFS 分享的文件(默认不限制)**  
> *在`/etc/config/nfs`文件中把`*`替换为指定设备的IP*  

### 安卓问题
**为什么 termux 无法挂载网盘到本地？**  
> *非Root用户无法挂载。*  

**非 root 设备可以用 root 命令吗？**  
> *不可以，用了会无法启动。*  

## 问题反馈群
- QQ讨论群: 943950333 ，加群链接：[点击加入](https://qm.qq.com/q/EroEmk0kkq "交流反馈")  

<img src="./images/QRcode.png" width="20%">
