#!/usr/bin/env bash
# 本脚本必须配合一键安装 clouddrive 脚本才有效
chmod +x "$0"

RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
PINK_COLOR='\e[1;35m'
SHAN='\e[1;33;5m'
RES='\e[0m'

if command -v opkg >/dev/null 2>&1; then
  if command -v docker >/dev/null 2>&1; then
    check_docker="exist"
  else
    if [ -e "/sbin/procd" ]; then
      check_procd="exist"
    else
      echo -e "\r\n${RED_COLOR}出错了，无法确定你当前的 Openwrt 发行版。${RES}\r\n"
      exit 1
    fi
  fi
else
  echo -e "\r\n${RED_COLOR}出错了，无法确定你当前的 Openwrt 发行版。${RES}\r\n"
  exit 1
fi
# 获取挂载路径
if [ "$check_docker" = "exist" ]; then
  mount_root_path=$(grep -A1 "source_path\s*=\s*\"/\"" /Config/config.toml | grep "mount_point" | awk -F'["]' '{print $2}')
elif [ "$check_procd" = "exist" ]; then
  mount_root_path=$(grep -A1 "source_path\s*=\s*\"/\"" /Waytech/CloudDrive2/config.toml | grep "mount_point" | awk -F'["]' '{print $2}')
else
  echo -e "${RED_COLOR}网盘未挂载到本地!${RES}"
  eixt 1
fi

get-local-ipv4-using-hostname() {
  hostname -I 2>&- | awk '{print $1}'
}

# iproute2
get-local-ipv4-using-iproute2() {
  # OR ip route get 1.2.3.4 | awk '{print $7}'
  ip -4 route 2>&- | awk '{print $NF}' | grep -Eo --color=never '[0-9]+(\.[0-9]+){3}'
}

# net-tools
get-local-ipv4-using-ifconfig() {
  ( ifconfig 2>&- || ip addr show 2>&- ) | grep -Eo '^\s+inet\s+\S+' | grep -Eo '[0-9]+(\.[0-9]+){3}' | grep -Ev '127\.0\.0\.1|0\.0\.0\.0'
}

# 获取本机 IPv4 地址
get-local-ipv4() {
  set -o pipefail
  get-local-ipv4-using-hostname || get-local-ipv4-using-iproute2 || get-local-ipv4-using-ifconfig
}
get-local-ipv4-select() {
  local ips=$(get-local-ipv4)
  local retcode=$?
  if [ $retcode -ne 0 ]; then
      return $retcode
  fi
  grep -m 1 "^192\." <<<"$ips" || \
  grep -m 1 "^172\." <<<"$ips" || \
  grep -m 1 "^10\." <<<"$ips" || \
  head -n 1 <<<"$ips"
}

# ------------- SMB -----------
# 检查内核模块
CHECK_SMB_KMOD() {
echo -e "${GREEN_COLOR}正在更新软件源...${RES}"
opkg update
if opkg list-installed | grep -q "samba4-server"; then
  KMOD_SMB_SUCCESS="true"
  SMB_VERSION="samba4"
elif opkg list-installed | grep -q "samba36-server"; then
  KMOD_SMB_SUCCESS="true"
  SMB_VERSION="samba"
else
  KMOD_SMB_SUCCESS="false"
fi
}

SMB_SHARES() {
echo -e "${GREEN_COLOR}正在检查必要的ipk包...${RES}"
# 安装必要的包
if [ "$SMB_VERSION" = "samba4" ]; then
  SMB_packages=("samba4-server" "samba4-libs")
elif [ "$SMB_VERSION" = "samba" ]; then
  SMB_packages=("luci-app-samba")
fi
INSTALL_SUCCESS="true"
for smb_pkg in "${SMB_packages[@]}"; do
    if ! opkg list-installed | grep -q "$smb_pkg"; then
        opkg install "$smb_pkg" > /dev/null
        if ! [ $? -eq 0 ]; then
            INSTALL_SUCCESS="false"
        fi
    fi
done

if [ "$INSTALL_SUCCESS" = "false" ]; then
    SMB_STATUS="failure"
else
    SMB_STATUS="succeed"
    SMB_SETTINGS
fi
}

SMB_SETTINGS() {
# 设置 SMB 密码
echo -e "${GREEN_COLOR}设置 SMB 默认密码${RES}"
# 默认密码
password="123456"
{
  echo "$password"
  echo "$password"
} | smbpasswd -a root

# 备份默认配置
if [ -f "/etc/config/$SMB_VERSION" ]; then
    cp /etc/config/"$SMB_VERSION" /etc/config/"$SMB_VERSION".bak
    rm -rf /etc/config/"$SMB_VERSION"
else
    mkdir -p /etc/config
    touch /etc/config/"$SMB_VERSION"
    chmod 600 /etc/config/"$SMB_VERSION"
fi

if [ -f "/etc/samba/smb.conf.template" ]; then
    cp /etc/samba/smb.conf.template /etc/samba/smb.conf.template.bak
fi

if [ -f "/etc/samba/smb.conf" ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
else
    mkdir -p /etc/config
    ln -s /var/etc/smb.conf /etc/samba/smb.conf
fi


# 设置 root 用户
if ! grep -q "#invalid users = root" /etc/samba/smb.conf.template; then
    if grep -q "invalid users = root" /etc/samba/smb.conf.template; then
        sed -i 's/invalid users = root/#invalid users = root/g' /etc/samba/smb.conf.template
    else
        echo -e "\t#invalid users = root" >> /etc/samba/smb.conf.template
    fi
fi

# 兼容低版本协议
if ! grep -q "server min protocol = NT1" /etc/samba/smb.conf.template; then
    echo -e "\tserver min protocol = NT1" >> /etc/samba/smb.conf.template
fi


if ! grep -qE "option name 'root'" /etc/config/"$SMB_VERSION" && ! grep -qE "option path '/CloudNAS'" /etc/config/"$SMB_VERSION"; then
cat << EOF >> /etc/config/"$SMB_VERSION"
config samba
    option charset 'UTF-8'
    option description 'Samba on OpenWRT'
    option name 'op'
    option homes '1'
    option macos '1'
    option workgroup 'WORKGROUP'
    option allow_legacy_protocols '1'

config sambashare
    option users 'root'
    option create_mask '0777'
    option dir_mask '0777'
    option name 'root'
    option read_only 'no'
    option force_root '1'
    option path '/CloudNAS'
    option inherit_owner 'yes'
EOF
fi

/etc/init.d/"$SMB_VERSION" start
/etc/init.d/"$SMB_VERSION" enable
echo -e "${GREEN_COLOR}SMB 设置完毕${RES}"
}


#------------- NFS --------------
# 检查内核模块
CHECK_NFS_KMOD() {
if ! opkg list-installed | grep -q "kmod-fs-nfsd"; then
  KMOD_NFS_SUCCESS="false"
else
  KMOD_NFS_SUCCESS="true"
  NFS_SHARES
fi
}

NFS_SHARES() {
echo -e "${GREEN_COLOR}正在设置 NFS 共享...${RES}"
# NFS依赖RPC服务
NFS_packages=("nfs-kernel-server" "nfs-kernel-server-utils" "nfs-utils" "nfs-utils-libs")
INSTALL_SUCCESS="true"
for nfs_pkg in "${NFS_packages[@]}"; do
    if ! opkg list-installed | grep -q "$nfs_pkg"; then
        opkg install "$nfs_pkg" > /dev/null
        if ! [ $? -eq 0 ]; then
            INSTALL_SUCCESS="false"
        fi
    fi
done

if [ "$INSTALL_SUCCESS" = "false" ]; then
    NFS_STATUS="failure"
else
    NFS_STATUS="succeed"
    NFS_SETTINGS
fi
}

NFS_SETTINGS() {
# 备份默认配置
if [ -f "/etc/config/nfs" ]; then
    cp /etc/config/nfs /etc/config/nfs.bak
    rm -rf /etc/config/nfs
else
    touch /etc/config/nfs
fi

if [ -f "/etc/exports" ]; then
    cp /etc/exports /etc/exports.bak
    rm -rf /etc/exports
else
    touch /etc/exports
fi

if [ ! -e "/etc/init.d/nfs" ]; then
    nfs_config="/etc/exports"
    nfs_bin="nfsd"
else
    nfs_config="/etc/config/nfs"
    nfs_bin="nfs"
fi


if [ "$nfs_config" = "/etc/config/nfs" ]; then
cat << EOF >> "$nfs_config"
config share
	option clients '*'
	option options 'ro,fsid=0,sync,nohide,no_subtree_check,insecure,no_root_squash'
	option path '$mount_root_path'
	option enabled '1'
EOF
else
cat << EOF >> "$nfs_config"
$mount_root_path    *(ro,fsid=0,sync,nohide,no_subtree_check,insecure,no_root_squash)
EOF
fi

/etc/init.d/"$nfs_bin" restart
/etc/init.d/"$nfs_bin" enable
echo -e "${GREEN_COLOR}NFS 设置完毕${RES}"
}


UNSHARE() {
# SMB
if [ -f "/etc/config/$SMB_VERSION.bak" ]; then
    if [ -f "/etc/config/$SMB_VERSION" ]; then
        rm -rf /etc/config/"$SMB_VERSION" && mv /etc/config/"$SMB_VERSION".bak /etc/config/"$SMB_VERSION"
    else
        mv /etc/config/"$SMB_VERSION".bak /etc/config/"$SMB_VERSION"
    fi
else
    rm -rf /etc/config/"$SMB_VERSION"
fi

if [ -f "/etc/samba/smb.conf.bak" ]; then
    if [ -f "/etc/samba/smb.conf" ]; then
        rm -rf  /etc/samba/smb.conf && mv /etc/samba/smb.conf.bak /etc/samba/smb.conf
    else
        mv /etc/samba/smb.conf.bak /etc/samba/smb.conf
    fi
else
    rm -rf /etc/samba/smb.conf
fi


# NFS
if [ -f "/etc/config/nfs.bak" ]; then
    if [ -f "/etc/config/nfs" ]; then
        mv /etc/config/nfs.bak /etc/config/nfs
    else
        mv /etc/config/nfs.bak /etc/config/nfs
    fi
else
    rm -rf /etc/config/nfs
fi

/etc/init.d/samba4 stop
/etc/init.d/samba4 disable

/etc/init.d/nfs stop
/etc/init.d/nfs disable
echo -e "\r\n${GREEN_COLOR}SMB/NFS共享已在系统中移除！${RES}\r\n"
}


SUCCESS() {
clear
# SMB
echo -e "${GREEN_COLOR}请用您的设备连接以下可用的共享服务${RES}\r\n"
if [ "$KMOD_SMB_SUCCESS" = "false" ]; then
  echo -e "${GREEN_COLOR}SMB 设置失败:${RES}"
  echo -e "${RED_COLOR}失败原因: 固件没有 SMB 内核模块${RES}"
elif [ "$SMB_STATUS" = "failure" ]; then
  echo -e "${GREEN_COLOR}SMB 设置失败:${RES}"
  echo -e "${RED_COLOR}失败原因: 软件源或网络${RES}"
else
  echo -e "${GREEN_COLOR}SMB 设置成功:${RES}"
  echo -e "SMB主机IP：${GREEN_COLOR}$(get-local-ipv4-select)${RES}"
  echo -e "SMB用户名：${GREEN_COLOR}root${RES}"
  echo -e "SMB默认密码：${GREEN_COLOR}$password${RES}"
  echo -e "SMB端口：${GREEN_COLOR}445 (可选)${RES}"
  echo -e "SMB路径：${GREEN_COLOR}/ (可选)${RES}\r\n"
fi

# NFS
if [ "$KMOD_NFS_SUCCESS" = "false" ]; then
  echo -e "${GREEN_COLOR}NFS 设置失败:${RES}"
  echo -e "${RED_COLOR}失败原因: 固件没有 NFS 内核模块${RES}"
elif [ "$NFS_STATUS" = "failure" ]; then
  echo -e "${GREEN_COLOR}NFS 设置失败:${RES}"
  echo -e "${RED_COLOR}失败原因: 软件源或网络${RES}"
else
  echo -e "${GREEN_COLOR}NFS 设置成功:${RES}"
  echo -e "NFS主机IP：${GREEN_COLOR}$(get-local-ipv4-select)${RES}"
  echo -e "NFS端口：${GREEN_COLOR}2049 (可选)${RES}"
  echo -e "NFS路径：${GREEN_COLOR}/ (可选)${RES}\r\n"
fi
}

if [ "$1" = "unshares" ]; then
  CHECK_SMB_KMOD
  UNSHARE
elif [ "$1" = "shares" ]; then
  CHECK_SMB_KMOD
  if [ "$KMOD_SMB_SUCCESS" = "true" ]; then
    SMB_SHARES
  fi
  CHECK_NFS_KMOD
  SUCCESS
else
  echo -e "${RED_COLOR} 错误的命令${RES}"
fi
