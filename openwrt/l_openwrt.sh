#!/usr/bin/env bash
# set -x

[[ x$REPO_FLODER = x ]] && \
(REPO_FLODER="lede" && echo "REPO_FLODER=lede" >>$GITHUB_ENV)

# shopt -s extglob expand_aliases
# shopt -os emacs histexpand history monitor
# echo -E "1)字符后移70$(echo -en "\033[70G[ " && echo -e "ok ]")"
# echo -E "2)字符后移70$(printf "\033[70G[ ok ]\n")"

color() {
	case $1 in
		cy)
		echo -e "\033[1;33m$2\033[0m"
		;;
		cr)
		echo -e "\033[1;31m$2\033[0m"
		;;
		cg)
		echo -e "\033[1;32m$2\033[0m"
		;;
		cb)
		echo -e "\033[1;34m$2\033[0m"
		;;
	esac
}

status() {
	CHECK=$?
	END_TIME=$(date '+%H:%M:%S')
	_date=" ==>用时 $(($(date +%s -d "$END_TIME") - $(date +%s -d "$BEGIN_TIME"))) 秒"
	[[ $_date =~ [0-9]+ ]] || _date=""
	if [ $CHECK = 0 ]; then
		printf "%35s %s %s %s %s %s %s\n" \
		`echo -e "[ $(color cg ✔)\033[0;39m ]${_date}"`
	else
		printf "%35s %s %s %s %s %s %s\n" \
		`echo -e "[ $(color cr ✕)\033[0;39m ]${_date}"`
	fi
}

_packages() {
	for z in $@; do
		[[ "$(grep -v '^#' <<<$z)" ]] && echo "CONFIG_PACKAGE_$z=y" >> .config
	done
}

_printf() {
	awk '{printf "%s %-40s %s %s %s\n" ,$1,$2,$3,$4,$5}'
}

REPO_URL="https://github.com/coolsnowwolf/lede"
[[ $REPO_BRANCH ]] && cmd="-b $REPO_BRANCH"

echo -e "$(color cy '拉取源码....')\c"
BEGIN_TIME=$(date '+%H:%M:%S')
git clone -q $REPO_URL $cmd $REPO_FLODER
status

cd $REPO_FLODER || exit
echo -e "$(color cy '更新软件....')\c"
BEGIN_TIME=$(date '+%H:%M:%S')
./scripts/feeds update -a 1>/dev/null 2>&1
status

echo -e "$(color cy '安装软件....')\c"
BEGIN_TIME=$(date '+%H:%M:%S')
./scripts/feeds install -a 1>/dev/null 2>&1
status

: >.config
PARTSIZE=`echo $[$RANDOM%5+6]`
case $TARGET_DEVICE in
	"x86_64")
		cat >.config<<-EOF
		CONFIG_TARGET_x86=y
		CONFIG_TARGET_x86_64=y
		CONFIG_TARGET_ROOTFS_PARTSIZE=${PARTSIZE}00
		CONFIG_BUILD_NLS=y
		CONFIG_BUILD_PATENTED=y
		EOF
	;;
	"r4s"|"r2c"|"r2r")
		cat >.config<<-EOF
		CONFIG_TARGET_rockchip=y
		CONFIG_TARGET_rockchip_armv8=y
		CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-$TARGET_DEVICE=y
		CONFIG_TARGET_ROOTFS_PARTSIZE=750
		CONFIG_BUILD_NLS=y
		CONFIG_BUILD_PATENTED=y
		EOF
	;;
	"newifi-d2")
		cat >.config<<-EOF
		CONFIG_TARGET_ramips=y
		CONFIG_TARGET_ramips_mt7621=y
		CONFIG_TARGET_ramips_mt7621_DEVICE_d-team_newifi-d2=y
		EOF
	;;
	"phicomm_k2p")
		cat >.config<<-EOF
		CONFIG_TARGET_ramips=y
		CONFIG_TARGET_ramips_mt7621=y
		CONFIG_TARGET_ramips_mt7621_DEVICE_phicomm_k2p=y
		EOF
	;;
	"asus_rt-n16")
		cat >.config<<-EOF
		CONFIG_TARGET_bcm47xx=y
		CONFIG_TARGET_bcm47xx_mips74k=y
		CONFIG_TARGET_bcm47xx_mips74k_DEVICE_asus_rt-n16=y
		EOF
	;;
	"armvirt_64_Default")
		cat >.config<<-EOF
		CONFIG_TARGET_armvirt=y
		CONFIG_TARGET_armvirt_64=y
		CONFIG_TARGET_armvirt_64_Default=y
		EOF
	;;
	*)
		cat >.config<<-EOF
		CONFIG_TARGET_x86=y
		CONFIG_TARGET_x86_64=y
		CONFIG_TARGET_ROOTFS_PARTSIZE=900
		EOF
	;;
esac

cat >> .config <<-EOF
	CONFIG_KERNEL_BUILD_USER="win3gp"
	CONFIG_KERNEL_BUILD_DOMAIN="OpenWrt"
	## luci app
	CONFIG_PACKAGE_luci-app-accesscontrol=y
	CONFIG_PACKAGE_luci-app-adblock-plus=y
	CONFIG_PACKAGE_luci-app-bridge=y
	CONFIG_PACKAGE_luci-app-cowb-speedlimit=y
	CONFIG_PACKAGE_luci-app-cowbping=y
	CONFIG_PACKAGE_luci-app-cpulimit=y
	CONFIG_PACKAGE_luci-app-ddnsto=y
	CONFIG_PACKAGE_luci-app-easymesh=y
	CONFIG_PACKAGE_luci-app-filebrowser=y
	CONFIG_PACKAGE_luci-app-filetransfer=y
	CONFIG_PACKAGE_luci-app-network-settings=y
	CONFIG_PACKAGE_luci-app-oaf=y
	CONFIG_PACKAGE_luci-app-passwall=y
	CONFIG_PACKAGE_luci-app-rebootschedule=y
	CONFIG_PACKAGE_luci-app-ssr-plus=y
	CONFIG_PACKAGE_luci-app-ttyd=y
	CONFIG_PACKAGE_luci-app-upnp=y
	## luci theme
	CONFIG_PACKAGE_luci-theme-material=y
	## remove
	CONFIG_TARGET_IMAGES_GZIP=y
	CONFIG_GRUB_IMAGES=y
	# CONFIG_GRUB_EFI_IMAGES is not set
	# CONFIG_VMDK_IMAGES is not set
	# CONFIG_PACKAGE_luci-app-unblockmusic is not set
	# CONFIG_PACKAGE_luci-app-xlnetacc is not set
	# CONFIG_PACKAGE_luci-app-uugamebooster is not set
	# Libraries
	CONFIG_PACKAGE_patch=y
	CONFIG_PACKAGE_diffutils=y
	CONFIG_PACKAGE_default-settings=y
EOF

m=$(awk -F/ '{print $(NF-1)}' <<<$REPO_URL)
[[ "$m" == "coolsnowwolf" ]] && m="lean"
[[ "$REPO_BRANCH" == "main" || -z "$REPO_BRANCH" ]] && REPO_BRANCH="18.06"
config_generate="package/base-files/files/bin/config_generate"
TARGET=$(awk '/^CONFIG_TARGET/{print $1;exit;}' .config | sed -r 's/.*TARGET_(.*)=y/\1/')
DEVICE_NAME=$(grep '^CONFIG_TARGET.*DEVICE.*=y' .config | sed -r 's/.*DEVICE_(.*)=y/\1/')

color cy "自定义设置.... "
wget -qO package/base-files/files/etc/banner git.io/JoNK8
sed -i "/DISTRIB_DESCRIPTION/ {s/'$/-$m-$(date +%Y年%m月%d日)'/}" package/*/*/*/openwrt_release
sed -i "/IMG_PREFIX:/ {s/=/=$m-$REPO_BRANCH-\$(shell date +%m%d-%H%M -d +8hour)-/}" include/image.mk
sed -i 's/option enabled.*/option enabled 1/' feeds/*/*/*/*/upnpd.config
sed -i "/listen_https/ {s/^/#/g}" package/*/*/*/files/uhttpd.config
sed -i "{
		/upnp/d;/banner/d;/openwrt_release/d;/shadow/d
		s|zh_cn|zh_cn\nuci set luci.main.mediaurlbase=/luci-static/bootstrap|
		s|indexcache|indexcache\nsed -i 's/root::0:0:99999:7:::/root:\$1\$RysBCijW\$wIxPNkj9Ht9WhglXAXo4w0:18206:0:99999:7:::/g' /etc/shadow\nsed -i 's/ Mod by Lienol//g' /usr/lib/lua/luci/version.lua|
		}" $(find package/ -type f -name "zzz-default-settings")
	
cat <<-\EOF >feeds/packages/lang/python/python3/files/python3-package-uuid.mk
	define Package/python3-uuid
	$(call Package/python3/Default)
	  TITLE:=Python $(PYTHON3_VERSION) UUID module
	  DEPENDS:=+python3-light +libuuid
	endef

	$(eval $(call Py3BasePackage,python3-uuid, \
		/usr/lib/python$(PYTHON3_VERSION)/uuid.py \
		/usr/lib/python$(PYTHON3_VERSION)/lib-dynload/_uuid.$(PYTHON3_SO_SUFFIX) \
	))
EOF

[[ "$REPO_BRANCH" == "19.07" ]] || {
	for d in $(find feeds/ package/ -type f -name "index.htm"); do
		if grep -q "Kernel Version" $d; then
			sed -i 's|os.date(.*|os.date("%F %X") .. " " .. translate(os.date("%A")),|' $d
			# if ! grep "admin_status/index/" $d; then
				# sed -i '/<%+footer%>/i<fieldset class="cbi-section">\n\t<legend><%:天气%></legend>\n\t<table width="100%" cellspacing="10">\n\t\t<tr><td width="10%"><%:本地天气%></td><td > <iframe width="900" height="120" frameborder="0" scrolling="no" hspace="0" src="//i.tianqi.com/?c=code&a=getcode&id=22&py=xiaoshan&icon=1"></iframe>\n\t\t<tr><td width="10%"><%:柯桥天气%></td><td > <iframe width="900" height="120" frameborder="0" scrolling="no" hspace="0" src="//i.tianqi.com/?c=code&a=getcode&id=22&py=keqiaoqv&icon=1"></iframe>\n\t\t<tr><td width="10%"><%:指数%></td><td > <iframe width="400" height="270" frameborder="0" scrolling="no" hspace="0" src="https://i.tianqi.com/?c=code&a=getcode&id=27&py=xiaoshan&icon=1"></iframe><iframe width="400" height="270" frameborder="0" scrolling="no" hspace="0" src="https://i.tianqi.com/?c=code&a=getcode&id=27&py=keqiaoqv&icon=1"></iframe>\n\t</table>\n</fieldset>\n\n<%-\n\tlocal incdir = util.libpath() .. "/view/admin_status/index/"\n\tif fs.access(incdir) then\n\t\tlocal inc\n\t\tfor inc in fs.dir(incdir) do\n\t\t\tif inc:match("%.htm$") then\n\t\t\t\tinclude("admin_status/index/" .. inc:gsub("%.htm$", ""))\n\t\t\tend\n\t\tend\n\t\end\n-%>\n' $d
			# fi
		fi
	done
}

clone_url() {
	for x in $@; do
		if [[ "$(grep "^http" <<<$x)" ]]; then
				g=$(find package/ feeds/ -maxdepth 5 -type d -name ${x##*/})
				if ([[ -d "$g" && ${g##*/} != "build" ]] && rm -rf $g); then
					p="1"
				else
					p="0"; g="package/A/${x##*/}"
				fi

				if [[ "$(grep -E "trunk|branches" <<<$x)" ]]; then
					if svn export -q --force $x $g; then
						f="1"
					fi
				else
					if git clone -q $x $g; then
						f="1"
					fi
				fi
				[[ $f = "" ]] && echo -e "$(color cr 拉取) ${x##*/} [ $(color cr ✕) ]" | _printf
				[[ $f -lt $p ]] && echo -e "$(color cr 替换) ${x##*/} [ $(color cr ✕) ]" | _printf
				[[ $f = $p ]] && \
					echo -e "$(color cg 替换) ${x##*/} [ $(color cg ✔) ]" | _printf || \
					echo -e "$(color cb 添加) ${x##*/} [ $(color cb ✔) ]" | _printf
				unset -v p f g
		fi
	done
}
packages_url="axel lsscsi netdata deluge luci-app-deluge libtorrent-rasterbar Mako python-pyxdg python-rencode python-setproctitle  luci-app-ddnsto luci-app-bridge luci-app-diskman luci-app-poweroff luci-app-cowbping luci-app-dockerman luci-app-smartinfo luci-app-filebrowser AmuleWebUI-Reloaded luci-app-qbittorrent luci-app-softwarecenter luci-app-rebootschedule luci-app-cowb-speedlimit luci-app-network-settings luci-lib-docker"
for k in $packages_url; do
	clone_url "https://github.com/hong0980/build/trunk/$k"
done

clone_url "
	https://github.com/fw876/helloworld
	https://github.com/destan19/OpenAppFilter
	#https://github.com/kiddin9/openwrt-packages
	https://github.com/jerrykuku/luci-app-vssr
	https://github.com/jerrykuku/lua-maxminddb
	https://github.com/ntlf9t/luci-app-easymesh
	https://github.com/zzsj0928/luci-app-pushbot
	https://github.com/xiaorouji/openwrt-passwall
	https://github.com/small-5/luci-app-adblock-plus
	https://github.com/jerrykuku/luci-app-jd-dailybonus
	https://github.com/kiddin9/openwrt-bypass/trunk/luci-app-bypass
	https://github.com/vernesong/OpenClash/trunk/luci-app-openclash
	https://github.com/immortalwrt/packages/trunk/net/qBittorrent-Enhanced-Edition
"
# https://github.com/immortalwrt/luci/branches/openwrt-21.02/applications/luci-app-ttyd ##使用分支
echo -e 'pthome.net\nchdbits.co\nhdsky.me\nwww.nicept.net\nourbits.club' | \
tee -a $(find package/ feeds/luci/applications/ -type f -name "white.list" -or -name "direct_host" | grep "ss") >/dev/null

echo '<iframe src="https://ip.skk.moe/simple" style="width: 100%; border: 0"></iframe>' | \
tee -a {$(find package/ feeds/luci/applications/ -type d -name "luci-app-vssr")/*/*/*/status_top.htm,$(find package/ feeds/luci/applications/ -type d -name "luci-app-ssr-plus")/*/*/*/status.htm,$(find package/ feeds/luci/applications/ -type d -name "luci-app-bypass")/*/*/*/status.htm,$(find package/ feeds/luci/applications/ -type d -name "luci-app-passwall")/*/*/*/global/status.htm} >/dev/null
sed -i 's/option dports.*/option dports 2/' package/A/luci-app-vssr/root/etc/config/vssr

[[ "$TARGET_DEVICE" != "phicomm_k2p" ]] && {
	clone_url "
	https://github.com/hong0980/build/trunk/aria2
	https://github.com/hong0980/build/trunk/ariang
	https://github.com/hong0980/build/trunk/webui-aria2
	https://github.com/hong0980/build/trunk/luci-app-aria2
	https://github.com/hong0980/build/trunk/transmission
	https://github.com/hong0980/build/trunk/luci-app-amule
	https://github.com/hong0980/build/trunk/luci-app-transmission
	https://github.com/hong0980/build/trunk/transmission-web-control
	"
	trv=`awk -F= '/PKG_VERSION:/{print $2}' feeds/packages/net/transmission/Makefile`
	wget -qO feeds/packages/net/transmission/patches/tr$trv.patch raw.githubusercontent.com/hong0980/diy/master/files/transmission/tr$trv.patch
	_packages "
	automount autosamba axel kmod-rt2500-usb kmod-rtl8187
	luci-app-aria2
	luci-app-cifs-mount
	luci-app-control-weburl
	luci-app-openclash
	luci-app-diskman
	luci-app-hd-idle
	luci-app-kickass
	luci-app-pushbot
	luci-app-smartinfo
	luci-app-softwarecenter
	luci-app-transmission
	luci-app-usb-printer
	luci-app-vssr
	luci-app-bypass
	"
}
x=$(find package/ feeds/luci/applications/ -type d -name "luci-app-bypass" 2>/dev/null)
[[ -f $x/Makefile ]] && sed -i 's/default y/default n/g' "$x/Makefile"

case $TARGET_DEVICE in
"newifi-d2")
	FIRMWARE_TYPE="sysupgrade"
	DEVICE_NAME="Newifi-D2"
	sed -i "s/192.168.1.1/192.168.2.1/" $config_generate
	;;
"phicomm_k2p")
	FIRMWARE_TYPE="sysupgrade"
	DEVICE_NAME="Phicomm-K2P"
	;;
"r4s"|"r2c"|"r2r")
	DEVICE_NAME="$TARGET_DEVICE"
	FIRMWARE_TYPE="sysupgrade"
	_packages "
	luci-app-adbyby-plus
	#luci-app-adguardhome
	#luci-app-amule
	luci-app-dockerman
	luci-app-netdata
	#luci-app-jd-dailybonus
	luci-app-poweroff
	luci-app-qbittorrent
	luci-app-smartdns
	luci-app-unblockmusic
	luci-app-deluge
	luci-app-passwall_INCLUDE_Brook
	luci-app-passwall_INCLUDE_ChinaDNS_NG
	luci-app-passwall_INCLUDE_Haproxy
	luci-app-passwall_INCLUDE_Hysteria
	luci-app-passwall_INCLUDE_Kcptun
	luci-app-passwall_INCLUDE_NaiveProxy
	luci-app-passwall_INCLUDE_PDNSD
	luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client
	luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server
	luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client
	luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client
	luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server
	luci-app-passwall_INCLUDE_Simple_Obfs
	luci-app-passwall_INCLUDE_Trojan_GO
	luci-app-passwall_INCLUDE_Trojan_Plus
	luci-app-passwall_INCLUDE_V2ray
	luci-app-passwall_INCLUDE_V2ray_Plugin
	luci-app-passwall_INCLUDE_Xray
	#AmuleWebUI-Reloaded htop lscpu lsscsi lsusb nano pciutils screen webui-aria2 zstd tar pv
	#subversion-server #unixodbc #git-http

	#USB3.0支持
	kmod-usb2 kmod-usb2-pci kmod-usb3
	kmod-fs-nfsd kmod-fs-nfs kmod-fs-nfs-v4

	#3G/4G_Support
	kmod-usb-acm kmod-usb-serial kmod-usb-ohci-pci kmod-sound-core

	#USB_net_driver
	kmod-mt76 kmod-mt76x2u kmod-rtl8821cu kmod-rtl8192cu kmod-rtl8812au-ac
	kmod-usb-net-asix-ax88179 kmod-usb-net-cdc-ether kmod-usb-net-rndis
	usb-modeswitch kmod-usb-net-rtl8152-vendor
	"
	sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=4.4.1_v1.2.15/' $(find package/A/ feeds/ -type d -name "qBittorrent-static")/Makefile
	wget -qO package/base-files/files/bin/bpm git.io/bpm && chmod +x package/base-files/files/bin/bpm
	wget -qO package/base-files/files/bin/ansi git.io/ansi && chmod +x package/base-files/files/bin/ansi
	grep CONFIG_TARGET_ROOTFS_PARTSIZE .config
	;;
"asus_rt-n16")
	DEVICE_NAME="Asus-RT-N16"
	FIRMWARE_TYPE="n16"
	sed -i "s/192.168.1.1/192.168.2.130/" $config_generate
	;;
"x86_64")
	DEVICE_NAME="x86_64"
	FIRMWARE_TYPE="squashfs-combined"
	sed -i "s/192.168.1.1/192.168.2.150/" $config_generate
	_packages "
	luci-app-adbyby-plus
	luci-app-adguardhome
	#luci-app-amule
	luci-app-dockerman
	luci-app-netdata
	luci-app-openclash
	#luci-app-jd-dailybonus
	luci-app-poweroff
	luci-app-qbittorrent
	luci-app-smartdns
	luci-app-unblockmusic
	luci-app-deluge
	luci-app-passwall_INCLUDE_Brook
	luci-app-passwall_INCLUDE_ChinaDNS_NG
	luci-app-passwall_INCLUDE_Haproxy
	luci-app-passwall_INCLUDE_Hysteria
	luci-app-passwall_INCLUDE_Kcptun
	luci-app-passwall_INCLUDE_NaiveProxy
	luci-app-passwall_INCLUDE_PDNSD
	luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client
	luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server
	luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client
	luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client
	luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server
	luci-app-passwall_INCLUDE_Simple_Obfs
	luci-app-passwall_INCLUDE_Trojan_GO
	luci-app-passwall_INCLUDE_Trojan_Plus
	luci-app-passwall_INCLUDE_V2ray
	luci-app-passwall_INCLUDE_V2ray_Plugin
	luci-app-passwall_INCLUDE_Xray
	#AmuleWebUI-Reloaded ariang bash htop lscpu lsscsi lsusb nano pciutils screen webui-aria2 zstd tar pv
	#subversion-server #unixodbc #git-http

	#USB3.0支持
	kmod-usb-audio kmod-usb-printer
	kmod-usb2 kmod-usb2-pci kmod-usb3

	#nfs
	kmod-fs-nfsd kmod-fs-nfs kmod-fs-nfs-v4

	#3G/4G_Support
	kmod-mii kmod-usb-acm kmod-usb-serial
	kmod-usb-serial-option kmod-usb-serial-wwan

	#Sound_Support
	kmod-sound-core kmod-sound-hda-codec-hdmi
	kmod-sound-hda-codec-realtek
	kmod-sound-hda-codec-via
	kmod-sound-hda-core kmod-sound-hda-intel

	#USB_net_driver
	kmod-mt76 kmod-mt76x2u kmod-rtl8821cu kmod-rtlwifi
	kmod-rtl8192cu kmod-rtl8812au-ac kmod-rtlwifi-usb
	kmod-rtlwifi-btcoexist kmod-usb-net-asix-ax88179
	kmod-usb-net-cdc-ether kmod-usb-net-rndis usb-modeswitch
	kmod-usb-net-rtl8152-vendor kmod-usb-net-asix

	#docker
	kmod-br-netfilter kmod-dm kmod-dummy kmod-fs-btrfs
	kmod-ikconfig kmod-nf-conntrack-netlink kmod-nf-ipvs kmod-veth

	#x86
	acpid alsa-utils ath10k-firmware-qca9888 blkid
	ath10k-firmware-qca988x ath10k-firmware-qca9984
	brcmfmac-firmware-43602a1-pcie irqbalance
	kmod-8139cp kmod-8139too kmod-alx kmod-ath10k
	kmod-bonding kmod-drm-ttm kmod-fs-ntfs kmod-i40e
	kmod-i40evf kmod-igbvf kmod-iwlwifi kmod-ixgbe
	kmod-ixgbevf kmod-mlx4-core kmod-mlx5-core
	kmod-mmc-spi kmod-pcnet32 kmod-r8125 kmod-r8168
	kmod-rt2800-usb kmod-rtl8xxxu kmod-sdhci
	kmod-sound-i8x0 kmod-sound-via82xx kmod-tg3
	kmod-tulip kmod-usb-hid kmod-vmxnet3 lm-sensors-detect
	qemu-ga smartmontools snmpd
	"
	sed -i '/easymesh/d' .config
	sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=4.4.1_v1.2.15/' $(find package/ feeds/ -type d -name "qBittorrent-static")/Makefile
	rm -rf package/lean/rblibtorrent
	# rm -rf feeds/packages/libs/libtorrent-rasterbar
	# sed -i 's/||x86_64//g' package/lean/luci-app-qbittorrent/Makefile
	# sed -i 's/:qbittorrent/:qBittorrent-Enhanced-Edition/g' package/lean/luci-app-qbittorrent/Makefile
	wget -qO package/base-files/files/bin/bpm git.io/bpm && chmod +x package/base-files/files/bin/bpm
	wget -qO package/base-files/files/bin/ansi git.io/ansi && chmod +x package/base-files/files/bin/ansi
	grep CONFIG_TARGET_ROOTFS_PARTSIZE .config
	;;
"armvirt_64_Default")
	DEVICE_NAME="armvirt-64-default"
	FIRMWARE_TYPE="armvirt-64-default"
	sed -i '/easymesh/d' .config
	sed -i "s/192.168.1.1/192.168.2.110/" $config_generate
	# clone_url "https://github.com/tuanqing/install-program" && rm -rf package/A/install-program/tools
	_packages "attr bash blkid brcmfmac-firmware-43430-sdio brcmfmac-firmware-43455-sdio
	btrfs-progs cfdisk chattr curl dosfstools e2fsprogs f2fs-tools f2fsck fdisk getopt
	hostpad-common htop install-program iperf3 kmod-brcmfmac kmod-brcmutil kmod-cfg80211
	kmod-fs-exfat kmod-fs-ext4 kmod-fs-vfat kmod-mac80211 kmod-rt2800-usb kmod-usb-net
	kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-storage
	kmod-usb-storage-extras kmod-usb-storage-uas kmod-usb2 kmod-usb3 lm-sensors losetup
	lsattr lsblk lscpu lsscsi luci-app-adguardhome luci-app-cpufreq luci-app-dockerman
	luci-app-qbittorrent mkf2fs ntfs-3g parted pv python3 resize2fs tune2fs unzip
	uuidgen wpa-cli wpad wpad-basic xfs-fsck xfs-mkf"

	# wget -qO feeds/luci/applications/luci-app-qbittorrent/Makefile https://raw.githubusercontent.com/immortalwrt/luci/openwrt-18.06/applications/luci-app-qbittorrent/Makefile
	# sed -i 's/-Enhanced-Edition//' feeds/luci/applications/luci-app-qbittorrent/Makefile
	sed -i 's/@arm/@TARGET_armvirt_64/g' $(find . -type d -name "luci-app-cpufreq")/Makefile
	sed -i 's/default 160/default 600/' config/Config-images.in
	sed -e 's/services/system/; s/00//' $(find . -type d -name "luci-app-cpufreq")/luasrc/controller/cpufreq.lua -i
	[ -d ../opt/openwrt_packit ] && {
		sed -i '{
		s|mv |mv -v |
		s|openwrt-armvirt-64-default-rootfs.tar.gz|$(ls *default-rootfs.tar.gz)|
		s|TGT_IMG=.*|TGT_IMG="${WORK_DIR}/unifreq-openwrt-${SOC}_${BOARD}_k${KERNEL_VERSION}${SUBVER}-$(date "+%Y-%m%d-%H%M").img"|
		}' ../opt/openwrt_packit/mk*.sh
		sed -i '/ KERNEL_VERSION.*flippy/ {s/KERNEL_VERSION.*/KERNEL_VERSION="5.15.4-flippy-67+"/}' ../opt/openwrt_packit/make.env
		# sed -e '/shadow/d; /BANNER=/d' ../opt/openwrt_packit/mk*.sh -i
		# cd ../opt/openwrt_packit
		# (
		# sed -i "s/#KERNEL_VERSION/KERNEL_VERSION/" make.env
		# #sed -i '2,10 s/\(#\)\(.*\)/\2/' make.env
		# OLD=$(grep \+o\" make.env)
		# NEW=$(grep \+\" make.env)
		# cp make.env makesfe.env
		# KV=$(find /opt/kernel/ -name "boot*+o.tar.gz" | awk -F '[-.]' '{print $2"."$3"."$4"-"$5"-"$6}')
		# KVS=$(find /opt/kernel/ -name "boot*+.tar.gz" | awk -F '[-.]' '{print $2"."$3"."$4"-"$5"-"$6}')
		# sed -i "s/$NEW/#$NEW/; s/^KERNEL_VERSION.*/KERNEL_VERSION=\"$KV\"/" make.env
		# sed -i "s/$OLD/#$OLD/; s/SFE_FLAG=.*/SFE_FLAG=1/; s/FLOWOFFLOAD_FLAG=.*/FLOWOFFLOAD_FLAG=0/" makesfe.env
		# sed -i "s/^KERNEL_VERSION.*/KERNEL_VERSION=\"$KVS\"/" makesfe.env
		# for F in *.sh; do cp $F ${F%.sh}_sfe.sh; done
		# find ./* -maxdepth 1 -path "*_sfe.sh" | xargs -i sed -i 's/make\.env/makesfe\.env/g' {}
		# )
		# cd -
	}
	;;
esac

echo -e "$(color cy 当前的机型) $(color cb $m-${DEVICE_NAME})"
echo -e "$(color cy '更新配置....')\c"
BEGIN_TIME=$(date '+%H:%M:%S')
make defconfig 1>/dev/null 2>&1
status

# echo "SSH_ACTIONS=true" >>$GITHUB_ENV #SSH后台
# echo "UPLOAD_PACKAGES=false" >>$GITHUB_ENV
# echo "UPLOAD_SYSUPGRADE=false" >>$GITHUB_ENV
echo "UPLOAD_BIN_DIR=false" >>$GITHUB_ENV
# echo "UPLOAD_FIRMWARE=false" >>$GITHUB_ENV
echo "UPLOAD_COWTRANSFER=false" >>$GITHUB_ENV
# echo "UPLOAD_WETRANSFER=false" >> $GITHUB_ENV
echo "CACHE_ACTIONS=true" >> $GITHUB_ENV
echo "DEVICE_NAME=$DEVICE_NAME" >>$GITHUB_ENV
echo "FIRMWARE_TYPE=$FIRMWARE_TYPE" >>$GITHUB_ENV
echo "ARCH=`awk -F'"' '/^CONFIG_TARGET_ARCH_PACKAGES/{print $2}' .config`" >>$GITHUB_ENV
echo "UPLOAD_RELEASE=true" >>$GITHUB_ENV

echo -e "\e[1;35m脚本运行完成！\e[0m"
