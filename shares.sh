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
SMB_SHARES() {
echo -e "${GREEN_COLOR}正在更新软件源...${RES}"
opkg update
# 安装必要的包
SMB_packages=("samba4-server" "luci-app-samba4" "samba4-libs" "samba4-admin" "samba4-client")
INSTALL_SUCCESS=true
for smb_pkg in "${SMB_packages[@]}"; do
    if ! opkg list-installed | grep -q "$smb_pkg"; then
        opkg install "$smb_pkg" > /dev/null
        if ! [ $? -eq 0 ]; then
            INSTALL_SUCCESS=false
        fi
    fi
done

if [ "$INSTALL_SUCCESS" = false ]; then
    echo -e "${RED_COLOR}安装 SMB 软件包失败，请检查软件源和网络环境${RES}"
    SMB_STATUS="failure"
else
    SMB_SETTINGS
    SMB_STATUS="succeed"
fi
}

SMB_SETTINGS() {
# 设置 SMB 密码
read -s -p $'\033[0;32m请设置您的 smb 共享密码后回车: \033[0m' password1
echo
read -s -p $'\033[0;32m请再次输入您的 smb 共享密码后回车: \033[0m' password2
echo

if [ "$password1" != "$password2" ]; then
    echo -e "${RED_COLOR}错误: 两次密码不一致${RES}"
    exit 1
fi

(echo "$password1"; echo "$password1") | smbpasswd -a root

# 备份默认配置
if [ -f "/etc/config/samba4" ]; then
    cp /etc/config/samba4 /etc/config/samba4.bak
else
    mkdir -p /etc/config
    touch /etc/config/samba4
    chmod 600 /etc/config/samba4
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


if ! grep -qE 'config sambashare' /etc/config/samba4 && grep -qE "option path '/CloudNAS'" /etc/config/samba4; then
cat << EOF >> /etc/config/samba4
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

/etc/init.d/samba4 start
/etc/init.d/samba4 enable
echo -e "${GREEN_COLOR}SMB 设置完毕${RES}"
}


#------------- NFS --------------
NFS_SHARES() {
echo -e "${GREEN_COLOR}准备设置 NFS 共享${RES}"
# NFS依赖RPC服务
NFS_packages=("nfs-kernel-server" "nfs-kernel-server-utils" "nfs-utils" "nfs-utils-libs" "luci-app-nfs" "kmod-fs-nfsd" "kmod-fs-nfs-v4" "kmod-fs-nfs-v3" "kmod-fs-nfs-common-rpcsec" "kmod-fs-nfs-common" "kmod-fs-nfs")
INSTALL_SUCCESS=true
for nfs_pkg in "${NFS_packages[@]}"; do
    if ! opkg list-installed | grep -q "$nfs_pkg"; then
        opkg install "$nfs_pkg" > /dev/null
        if ! [ $? -eq 0 ]; then
            INSTALL_SUCCESS=false
        fi
    fi
done

if [ "$INSTALL_SUCCESS" = false ]; then
    echo -e "${RED_COLOR}安装 NFS 软件包失败，请检查软件源和网络环境${RES}"
    NFS_STATUS="failure"
else
    NFS_SETTINGS
    NFS_STATUS="succeed"
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


cat << EOF >> /etc/config/nfs
config share
	option clients '*'
	option options 'ro,fsid=0,sync,nohide,no_subtree_check,insecure,no_root_squash'
	option path '$mount_root_path'
	option enabled '1'
EOF

/etc/init.d/nfs enable
/etc/init.d/nfs start
echo -e "${GREEN_COLOR}NFS 设置完毕${RES}"
}


UNSHARE() {
# SMB
if [ -f "/etc/config/samba4.bak" ]; then
    if [ -f "/etc/config/samba4" ]; then
        rm -rf /etc/config/samba4 && mv /etc/config/samba4.bak /etc/config/samba4
    else
        mv /etc/config/samba4.bak /etc/config/samba4
    fi
else
    rm -rf /etc/config/samba4
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
    if [ "$SMB_STATUS" = "succeed" ]; then
      echo -e "${GREEN_COLOR}SMB 结果:${RES}"
      echo -e "SMB主机IP：${GREEN_COLOR}$(get-local-ipv4-select)${RES}"
      echo -e "SMB用户名：${GREEN_COLOR}root${RES}"
      echo -e "SMB密码：${GREEN_COLOR}$password2${RES}"
      echo -e "SMB端口：${GREEN_COLOR}445${RES}"
      echo -e "SMB路径：${GREEN_COLOR}/${RES}\r\n"
    else
        echo -e "${GREEN_COLOR}SMB 结果:${RES}"
        echo -e "${RED_COLOR}SMB 设置失败${RES}"
    fi
    
    if [ "$NFS_STATUS" = "succeed" ]; then
      # nfs
      echo -e "${GREEN_COLOR}NFS 结果:${RES}"
      echo -e "NFS主机IP：${GREEN_COLOR}$(get-local-ipv4-select)${RES}"
      echo -e "NFS端口：${GREEN_COLOR}2049${RES}"
      echo -e "NFS路径：${GREEN_COLOR}/${RES}\r\n"
    else
      echo -e "${GREEN_COLOR}NFS 结果:${RES}"
      echo -e "${RED_COLOR}NFS 设置失败${RES}"
    fi
}

if [ "$1" = "unshares" ]; then
  UNSHARE
elif [ "$1" = "shares" ]; then
  SMB_SHARES
  NFS_SHARES
  SUCCESS
else
  echo -e "${RED_COLOR} 错误的命令${RES}"
fi
