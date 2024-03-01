#!/usr/bin/env bash
# 脚本地址：https://github.com/sublaim/clouddrive2
# 交流反馈QQ群：943950333
# set -x
chmod +x "$0"

# 字符串染色程序
if [[ -t 1 ]]; then
	tty_escape() { printf "\033[%sm" "$1"; }
else
	tty_escape() { :; }
fi
tty_universal() { tty_escape "0;$1"; } #正常显示
tty_mkbold() { tty_escape "1;$1"; }    #设置高亮
tty_underline="$(tty_escape "4;39")"   #下划线
tty_blue="$(tty_universal 34)"         #蓝色
tty_red="$(tty_universal 31)"          #红色
tty_green="$(tty_universal 32)"        #绿色
tty_yellow="$(tty_universal 33)"       #黄色
tty_bold="$(tty_universal 39)"         #加黑
tty_cyan="$(tty_universal 36)"         #青色
tty_reset="$(tty_escape 0)"            #去除颜色

if [[ $EUID -ne 0 ]]; then
	echo -e "${tty_red}非 root 用户，请用 sudo -i 切换并输入密码再运行${tty_reset}"
	exit 1
fi

# 系统检查
os_type=$(uname)
if [[ "$os_type" == "Linux" ]] && command -v systemctl >/dev/null 2>&1; then
	system_os="linux"
elif [[ "$os_type" == "Linux" ]] && command -v opkg >/dev/null 2>&1; then
	system_os="openwrt"
elif [[ "$os_type" == "Darwin" ]]; then
	system_os="macos"
else
	echo -e "${tty_red}系统未识别${tty_reset}"
	exit 1
fi

# 架构检查
# Get platform
if command -v uname >/dev/null 2>&1; then
	platform=$(uname -m)
else
	platform=$(arch)
fi

ARCH="UNKNOWN"

case "$platform" in
x86_64)
	ARCH=x86_64
	;;
aarch64 | arm64)
	ARCH=aarch64
	;;
armv7l)
	ARCH=armv7
	;;
*)
	echo -e "\r\n${tty_red}出错了，不支持的架构${tty_reset}\r\n"
	exit 1
	;;
esac

# 一键快速安装
fast_install() {
	default_value
	if [[ $system_os == "openwrt" ]] && command -v docker >/dev/null 2>&1; then
		docker_install
	else
		binary_install
	fi
	if [[ "$system_os" == "Linux" ]] && command -v docker >/dev/null 2>&1; then
		docker_install
	else
		binary_install
	fi
	if [[ "$system_os" == "macos" ]] && command -v docker >/dev/null 2>&1; then
		docker_install
	else
		binary_install
	fi
}

# 二进制安装
binary_install() {
	default_value
	case $system_os in
	"linux")
		download_clouddrive_binary
		binary_install_fuse3
		DAEMON
		SUCCESS
		;;
	"openwrt")
		download_clouddrive_binary
		binary_install_fuse3
		DAEMON
		SUCCESS
		;;
	"macos")
		download_clouddrive_binary
		binary_install_fuse3
		DAEMON
		SUCCESS
		;;
	*)
		echo "
      错误：您选择的序号不正确
      "
		;;
	esac
}

# docker 安装
docker_install() {
	if [ -z "$media_dir" ]; then
		select_version
		select_docker_path
	fi
	case $system_os in
	"openwrt")
		if ! grep -q "^mount --make-shared \/$" "/etc/rc.local"; then
			sed -i '/exit 0/i\mount --make-shared /' "/etc/rc.local"
		fi
		mount --make-shared /
		run_clouddrive_docker
		SUCCESS
		;;
	"linux")
		run_clouddrive_docker
		SUCCESS
		;;
	"macos")
		run_clouddrive_docker
		SUCCESS
		;;
	"*")
		echo -n "不支持的系统"
		;;
	esac
}

run_clouddrive_docker() {
	echo -e "${tty_green}正在下载 clouddrive 镜像，请稍候...${tty_reset}"
	mkdir -p "${cloudnas_dir}" "${config_dir}" "${media_dir}"
	docker pull "${docker_mirror}"cloudnas/clouddrive2:"${install_version}"
	docker run -d \
		--name clouddrive \
		--restart unless-stopped \
		--env CLOUDDRIVE_HOME=/Config \
		-v "${cloudnas_dir}":/CloudNAS:shared \
		-v "${config_dir}":/Config \
		-v "${media_dir}":/media:shared \
		--network host \
		--pid host \
		--privileged \
		--device /dev/fuse:/dev/fuse \
		"${docker_mirror}"cloudnas/clouddrive2:"${install_version}"
	if [ $? -eq 0 ]; then
		echo -e "${tty_green}clouddrive 容器已成功运行${tty_reset}"
	else
		echo -e "${tty_green}clouddrive 容器未能成功运行,请检查是否存在旧容器冲突${tty_reset}"
		exit 1
	fi
}

# 设置默认值
default_value() {
	mirror=${mirror:-https://mirro.ghproxy.com/}
	docker_mirror=${mirror:-ghproxy.com/}
	user_install_path=${user_install_path:-/opt/clouddrive}
	install_version=${install_version:-latest}
	cloudnas_dir=${cloudnas_dir:-/CloudNAS}
	config_dir=${config_dir:-/Config}
	media_dir=${media_dir:-/Media}
}

# 下载二进制文件
download_clouddrive_binary() {
	# Download clouddrive2
	case "$system_os" in
	openwrt | linux)
		os="linux"
		;;
	macos)
		os="macos"
		;;
	*)
		exit 0
		;;
	esac
	if [ ! -d "/tmp" ]; then
		mkdir -p /tmp
	fi
	if [[ "$install_version" == "latest" ]]; then
		clouddrive_version=$(curl -s https://api.github.com/repos/cloud-fs/cloud-fs.github.io/releases/latest |
			grep -Eo "\s\"name\": \"clouddrive-2-$os-$ARCH-.+?\.tgz\"" |
			awk -F'"' '{print $4}')
		echo -e "\r\n${tty_green}下载 clouddrive2 $VERSION ...${tty_reset}"
		curl -L ${mirror}https://github.com/cloud-fs/cloud-fs.github.io/releases/latest/download/"$clouddrive_version" \
			-o /tmp/clouddrive.tgz $CURL_BAR
	else
		clouddrive_version="clouddrive-2-$os-$ARCH-$install_version.tgz"
		echo -e "\r\n${tty_green}下载 clouddrive2 $VERSION ...${tty_reset}"
		curl -L ${mirror}https://github.com/cloud-fs/cloud-fs.github.io/releases/download/v"$install_version"/"$clouddrive_version" \
			-o /tmp/clouddrive.tgz $CURL_BAR
	fi
	if [ $? -eq 0 ]; then
		echo -e "clouddrive 下载完成"
	else
		echo -e "${tty_red}网络中断，请检查网络${tty_reset}"
		exit 1
	fi
	mkdir -p "$user_install_path"
	INSTALL_PATH="$user_install_path"
	tar zxf /tmp/clouddrive.tgz -C $INSTALL_PATH/
	mv $INSTALL_PATH/clouddrive-2*/* $INSTALL_PATH/ && rm -rf $INSTALL_PATH/clouddrive-2*
	if [ -f $INSTALL_PATH/clouddrive ]; then
		echo -e "${tty_green}校验文件成功\r\n${tty_reset}"
	else
		echo -e "${tty_red}校验 clouddrive-2-$os-$platform.tgz 文件失败！${tty_reset}"
		exit 1
	fi
	# remove temp
	rm -f /tmp/clouddrive*
	if [ ! -d "/CloudNAS" ]; then
		mkdir -p "/CloudNAS"
	fi
}

binary_install_fuse3() {
	if [[ "$system_os" == "openwrt" ]]; then
		echo -e "\r\n${tty_green}更新软件源...${tty_reset}"
		opkg update >/dev/null
		op_packages=("fuse3-utils" "libfuse3-3")
		INSTALL_SUCCESS="true"
		for op_pkg in "${op_packages[@]}"; do
			if ! opkg list-installed | grep -q "$op_pkg"; then
				opkg install "$op_pkg" >/dev/null
				if ! [ $? -eq 0 ]; then
					INSTALL_SUCCESS="false"
				fi
			fi
		done
		if [ "$INSTALL_SUCCESS" = "false" ]; then
			echo -e "${tty_red}安装 FUSE3 软件包失败，可能无法挂载${tty_reset}"
		fi
	fi

	if [[ "$system_os" == "macos" ]]; then
		if [ ! -f "/Library/Frameworks/macFUSE.framework/Versions/A/macFUSE" ]; then
			fuse_version=$(curl -s https://api.github.com/repos/osxfuse/osxfuse/releases/latest |
				grep -Eo '\s\"name\": \"macfuse-.+?\.dmg\"' |
				awk -F'"' '{print $4}')
			echo -e "\r\n${tty_green}下载 macFUSE $fuse_version ...${tty_reset}"
			curl -L ${mirror}https://github.com/osxfuse/osxfuse/releases/latest/download/$fuse_version \
				-o /tmp/macfuse.dmg $CURL_BAR
			sudo spctl --master-disable
			if [ $? -eq 0 ]; then
				echo -e "macFUSE 下载完成"
			else
				echo -e "${tty_red}网络中断，请检查网络${tty_reset}"
				exit 1
			fi
			hdiutil mount /tmp/macfuse.dmg
			installer -pkg "/Volumes/macFUSE/Install macFUSE.pkg" -target /
			hdiutil unmount /Volumes/macFUSE
			rm -rf /tmp/macfuse.dmg
		fi
	fi

	if [[ "$system_os" == "linux" ]]; then
		package_name="fuse3"
		if [ -f /etc/os-release ]; then
			. /etc/os-release
			case $ID in
			ubuntu | debian)
				apt-get update
				apt-get install -y $package_name
				;;
			centos)
				yum install -y $package_name
				;;
			arch | manjaro)
				pacman -Syu $package_name
				;;
			*)
				echo -e "${tty_red}未知: $ID, 可能无法挂载${tty_reset}"
				;;
			esac
		else
			echo -e "${tty_red}未知: $ID, 可能无法挂载${tty_reset}"
		fi
	fi
}

# 安装二进制文件并设置启动项
DAEMON() {
	case $system_os in
	"openwrt")
		touch /etc/init.d/clouddrive
		cat >/etc/init.d/clouddrive <<EOF
#!/bin/sh /etc/rc.common

USE_PROCD=1

START=99
STOP=99

start_service() {
    procd_open_instance
    procd_set_param command $INSTALL_PATH/clouddrive
    procd_set_param respawn
    procd_set_param pidfile /var/run/clouddrive.pid
    procd_close_instance
}
EOF
		chmod +x /etc/init.d/clouddrive
		/etc/init.d/clouddrive start
		/etc/init.d/clouddrive enable
		;;
	"linux")
		cat >/etc/systemd/system/clouddrive.service <<EOF
  [Unit]
  Description=clouddrive service
  Wants=network.target
  After=network.target network.service
  
  [Service]
  Type=simple
  WorkingDirectory=$INSTALL_PATH
  ExecStart=$INSTALL_PATH/clouddrive server
  KillMode=process
  
  [Install]
  WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl start clouddrive >/dev/null 2>&1
		systemctl enable clouddrive >/dev/null 2>&1
		;;
	"macos")
		cat >/Library/LaunchDaemons/clouddrive.plist <<EOF
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>clouddirve</string>
          <key>KeepAlive</key>
          <true/>
          <key>ProcessType</key>
          <string>Background</string>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>$INSTALL_PATH</string>
          <key>ProgramArguments</key>
          <array>
              <string>$INSTALL_PATH/clouddrive</string>
          </array>
      </dict>
  </plist>
EOF
		launchctl load -w /Library/LaunchDaemons/clouddrive.plist
		launchctl start /Library/LaunchDaemons/clouddrive.plist
		;;
	*)
		echo "
  错误：不支持的系统
  "
		;;
	esac
}

UNINSTALL() {
	if docker ps -a --format "{{.Names}}" | grep -q "clouddrive"; then
		docker stop clouddrive
		docker rm clouddrive
		echo "clouddrive 服务已停止并移除"
		docker images --format "{{.Repository}}:{{.Tag}}" | grep "cloudnas/clouddrive2" | xargs docker rmi
		echo -n "${tty_green}clouddrive 镜像已移除${tty_reset}"
	fi
	if [[ "$system_os" == "macos" ]]; then
		launchctl stop /Library/LaunchDaemons/clouddrive.plist >/dev/null 2>&1
		launchctl unload -w /Library/LaunchDaemons/clouddrive.plist >/dev/null 2>&1
		echo -e "${tty_green}清除残留文件${tty_reset}"
		rm -rf $INSTALL_PATH /Library/LaunchDaemons/clouddrive.plist >/dev/null 2>&1
	fi

	if [[ "$system_os" == "openwrt" ]]; then
		/etc/init.d/clouddrive stop >/dev/null 2>&1
		/etc/init.d/clouddrive disable >/dev/null 2>&1
		rm -rf $INSTALL_PATH "/etc/init.d/clouddrive" >/dev/null 2>&1
	elif [[ "$system_os" == "linux" ]]; then
		systemctl stop clouddrive >/dev/null 2>&1
		systemctl disable clouddrive >/dev/null 2>&1
		echo -e "${tty_green}清除残留文件${tty_reset}"
		rm -rf $INSTALL_PATH "/etc/systemd/system/clouddrive.service"
		systemctl daemon-reload
	fi

	if [ -d "/opt/clouddrive" ]; then
		rm -rf "/opt/clouddrive"
	fi

	echo -e "\r\n${tty_green}clouddrive2 已在系统中移除！${tty_reset}\r\n"
	exit 0
}

SUCCESS() {
	clear
	echo -e "${tty_green}clouddrive2 安装成功！${tty_reset}\r\n"
	echo -e "${tty_green}IP 地址请以实际为准${tty_reset}"
	if [ -n "$public_ipv4" ]; then
		echo -e "外网访问地址：${tty_green}http://$public_ipv4:19798/${tty_reset}"
	fi
	echo -e "内网访问地址：${tty_green}http://$(get-local-ipv4-select):19798/${tty_reset}\r\n"
	exit
}

# CURL 进度显示
if curl --help | grep progress-bar >/dev/null 2>&1; then # $CURL_BAR
	CURL_BAR="--progress-bar"
fi

# 获取IP
get-local-ipv4-using-hostname() {
	hostname -I 2>&- | awk '{print $1}'
}

# iproute2
get-local-ipv4-using-iproute2() {
	# OR ip route get 1.2.3.4 | awk '{print $7}'
	ip -4 route 2>&- |
		awk '{print $NF}' |
		grep -Eo --color=never '[0-9]+(\.[0-9]+){3}'
}

# net-tools
get-local-ipv4-using-ifconfig() {
	(ifconfig 2>&- || ip addr show 2>&-) |
		grep -Eo '^\s+inet\s+\S+' |
		grep -Eo '[0-9]+(\.[0-9]+){3}' |
		grep -Ev '127\.0\.0\.1|0\.0\.0\.0'
}

# 获取本机 IPv4 地址
get-local-ipv4() {
	set -o pipefail
	get-local-ipv4-using-hostname ||
		get-local-ipv4-using-iproute2 ||
		get-local-ipv4-using-ifconfig
}
get-local-ipv4-select() {
	local ips=$(get-local-ipv4)
	local retcode=$?
	if [ $retcode -ne 0 ]; then
		return $retcode
	fi
	grep -m 1 "^192\." <<<"$ips" ||
		grep -m 1 "^172\." <<<"$ips" ||
		grep -m 1 "^10\." <<<"$ips" ||
		head -n 1 <<<"$ips"
}

# 获取外网IP
get_public_ipv4() {
	curl -s ifconfig.me/ip |
		grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'
}

public_ipv4=$(get_public_ipv4)

# 这里有一个问题就是当没有docker时用户输入2的问题
# 安装方式
install_mode() {
	if command -v docker >/dev/null 2>&1; then
		echo -n "${tty_green}
    请选择安装方式：${tty_reset}" | sed 's/^\s\{4\}//'
		echo -n "${tty_cyan}
      1、二进制
      2、docker ${tty_reset}" | sed 's/^\s\{4\}//'
	else
		echo -n "${tty_green}
    请选择安装方式：${tty_reset}" | sed 's/^\s\{2\}//'
		echo -n "${tty_cyan}
      1、二进制 ${tty_reset}" | sed 's/^\s\{2\}//'
	fi

	while true; do
		echo -n "
    ${tty_yellow}请输入序号: ${tty_reset}" | sed 's/^\s\{4\}//'
		read MODE_NUM
		echo "${tty_reset}"
		case $MODE_NUM in
		"1")
			select_fast_mirror
			select_version
			select_binary_path
			binary_install
			break
			;;
		"2")
			docker_install
			select_version
			break
			;;
		*)
			echo "
      错误：您选择的序号不正确
      "
			;;
		esac
	done
}

# 镜像加速
select_fast_mirror() {
	echo -n "${tty_green}
  请选择加速通道：${tty_reset}" | sed 's/^\s\{2\}//'
	echo -n "${tty_cyan}
    1、二进制下载加速（一）
    2、docker下载加速（一）
    3、不加速 ${tty_reset}" | sed 's/^\s\{2\}//'
	echo -n "${tty_yellow}
  请输入序号并回车: ${tty_reset}" | sed 's/^\s\{2\}//'
	read FAST_NUM
	case $FAST_NUM in
	"1")
		mirror="https://mirror.ghproxy.com/"
		;;
	"2")
		docker_mirror="dockerproxy.com/"
		;;
	"3")
		mirror=""
		;;
	*)
		echo -n "${tty_red}
    错误：序号不正确
    ${tty_reset}"
		;;
	esac
}

# 版本选择
select_version() {
	while true; do
		echo -n "${tty_green}
    请选择安装的版本：${tty_reset}" | sed 's/^\s\{4\}//'
		echo -n "${tty_cyan}
    1、最新版
    2、旧版本 ${tty_reset}" | sed 's/^\s\{2\}//'
		echo -n "${tty_yellow}
    请输入序号并回车: ${tty_reset}" | sed 's/^\s\{4\}//'
		read input_version
		case "$input_version" in
		1)
			install_version="latest"
			break
			;;
		2)
			echo -en "\r\n${tty_green}请输入版本号并回车,如：0.6.6\r\n${tty_reset}" | sed 's/^\s\{6\}//'
			echo -n "${tty_yellow}版本号：${tty_reset}" | sed 's/^\s\{6\}//'
			read old_version
			if ! [[ $old_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
				echo -n "${tty_red}版本号格式不正确！${tty_reset}"
				exit 1
			fi
			install_version="$old_version"
			break
			;;
		*)
			echo -n "${tty_red}错误: 版本不存在，请重新输入有效的版本号。${tty_reset}"
			;;
		esac
	done
}

# 安装路径
select_binary_path() {
	while true; do
		echo -n "${tty_green}
    请选择安装的路径：${tty_reset}" | sed 's/^\s\{4\}//'
		echo -n "${tty_cyan}
    1、默认路径
    2、自定义路径 ${tty_reset}" | sed 's/^\s\{2\}//'
		echo -n "${tty_yellow}
    请输入序号并回车: ${tty_reset}" | sed 's/^\s\{4\}//'
		read input_path
		case "$input_path" in
		1)
			if [ -d "/opt/clouddrive" ]; then
				rm -rf "/opt/clouddrive"
			fi
			break
			;;
		2)
			echo -en "\r\n${tty_green}请输入安装路径并回车，如：/opt/clouddrive\r\n${tty_reset}" | sed 's/^\s\{6\}//'
			echo -n "${tty_yellow}路径：${tty_reset}" | sed 's/^\s\{6\}//'
			read input_dir
			# 获取目录的绝对路径
			mkdir -p "$input_dir"
			user_install_path=$(cd "$input_dir" && pwd)
			# 如果用户输入的目录以斜杠结尾，则去掉结尾的斜杠
			if [[ $input_dir == */ ]]; then
				user_install_path=${user_install_path%/}
			fi
			break
			;;
		*)
			echo -en "${tty_red}错误选项\r\n${tty_reset}"
			;;
		esac
	done
}

select_docker_path() {
	while true; do
		echo -n "${tty_green}
    请选择映射的路径：${tty_reset}" | sed 's/^\s\{4\}//'
		echo -n "${tty_cyan}
    1、默认路径
    2、自定义路径 ${tty_reset}" | sed 's/^\s\{2\}//'
		echo -n "${tty_yellow}
    请输入序号并回车: ${tty_reset}" | sed 's/^\s\{4\}//'
		read input_path
		case "$input_path" in
		1)
			default_value
			break
			;;
		2)
			echo -en "\r\n${tty_green}请映射目录并回车\r\n${tty_reset}" | sed 's/^\s\{6\}//'
			echo -n "${tty_yellow}容器中/CloudNAS映射到宿主机的目录：${tty_reset}" | sed 's/^\s\{6\}//'
			read input_cloudnas_dir
			mkdir -p "$input_cloudnas_dir"
			echo -n "${tty_yellow}容器中/Config映射到宿主机的目录：${tty_reset}" | sed 's/^\s\{6\}//'
			read input_config_dir
			mkdir -p "$input_config_dir"
			echo -n "${tty_yellow}容器中/Media映射到宿主机的目录：${tty_reset}" | sed 's/^\s\{6\}//'
			read input_media_dir
			mkdir -p "$input_media_dir"
			# 获取目录的绝对路径
			cloudnas_dir=$(cd "$input_cloudnas_dir" && pwd)
			# 如果用户输入的目录以斜杠结尾，则去掉结尾的斜杠
			if [[ $input_cloudnas_dir == */ ]]; then
				cloudnas_dir=${cloudnas_dir%/}
			fi

			config_dir=$(cd "$input_config_dir" && pwd)
			if [[ $input_config_dir == */ ]]; then
				config_dir=${config_dir%/}
			fi

			media_dir=$(cd "$input_media_dir" && pwd)
			if [[ $input_media_dir == */ ]]; then
				media_dir=${media_dir%/}
			fi
			break
			;;
		*)
			echo -en "${tty_red}错误选项\r\n${tty_reset}"
			;;
		esac
	done
}

while true; do
	echo -n "${tty_green}请选择：${tty_reset}"
	echo -n "${tty_cyan}
    1、快速安装  （一键安装）
    2、自定义安装（可选安装路径、方式等）
    3、卸载 ${tty_reset}" | sed 's/^\s\{2\}//'

	echo -n "
  ${tty_yellow}请输入序号并回车: ${tty_reset}" | sed 's/^\s\{2\}//'
	read INSTALL_NUM
	echo "${tty_reset}"
	case $INSTALL_NUM in
	"1")
		fast_install
		break
		;;
	"2")
		install_mode
		break
		;;
	"3")
		UNINSTALL
		break
		;;
	*)
		echo -en "
    ${tty_red}错误：您选择的序号不正确\r\n${tty_reset}"
		;;
	esac
done
