#!/usr/bin/env bash

[[ x$REPO_FLODER = x ]] && \
(REPO_FLODER="lede" && echo "REPO_FLODER=lede" >>$GITHUB_ENV)

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
		[[ $z =~ ^# ]] || echo "CONFIG_PACKAGE_$z=y" >> .config
	done
}

_printf() {
	awk '{printf "%s %-40s %s %s %s\n" ,$1,$2,$3,$4,$5}'
}

clone_url() {
	for x in $@; do
		if [[ "$(grep "^https" <<<$x | grep -Ev "fw876|xiaorouji|hong")" ]]; then
			g=$(find package/ feeds/ -type d -name ${x##*/} 2>/dev/null)
			if ([[ -d "$g" ]] && mv -f $g ../); then
				p="1"; k="$g"
			else
				p="0"; k="package/A/${x##*/}"
			fi

			if [[ "$(grep -E "trunk|branches" <<<$x)" ]]; then
				svn export --force $x $k 1>/dev/null 2>&1 && f="1"
			else
				git clone -q $x $k && f="1"
			fi

			if [[ $f -eq 1 ]]; then
				if [[ $p -eq 1 ]]; then
					echo -e "$(color cg 替换) ${x##*/} [ $(color cg ✔) ]" | _printf
				else
					echo -e "$(color cb 添加) ${x##*/} [ $(color cb ✔) ]" | _printf
				fi
			else
				echo -e "$(color cr 拉取) ${x##*/} [ $(color cr ✕) ]" | _printf
				[[ $p -eq 1 && -d ../${g##*/} ]] && mv -f ../${g##*/} ${g%/*}/
			fi
			unset -v p f
		else
			for w in $(grep "^https" <<<$x); do
				if git clone -q $w ../${w##*/}; then
					for x in `ls -l ../${w##*/} | awk '/^d/{print $NF}' | grep -Ev '*dump|*dtest|*Deny|*dog|*ding'`; do
						g=$(find package/ feeds/ -maxdepth 5 -type d -name $x 2>/dev/null)
						if ([[ -d "$g" ]] && rm -rf $g); then
							k="$g"
						else
							k="package/A"
						fi

						if mv -f ../${w##*/}/$x $k; then
							[[ $k = $g ]] && \
							echo -e "$(color cg 替换) ${x##*/} [ $(color cg ✔) ]" | _printf || \
							echo -e "$(color cb 添加) ${x##*/} [ $(color cb ✔) ]" | _printf
						fi
						unset -v k g
					done
				fi
				rm -rf ../${w##*/}
			done
		fi
	done
}

case $REPOSITORY in
	"baiywt")
	REPO_URL="https://github.com/baiywt/openwrt"
	REPO_BRANCH="openwrt-21.02"
	;;
	"xunlong")
	REPO_URL="https://github.com/orangepi-xunlong/openwrt"
	REPO_BRANCH="openwrt-21.02"
	;;
	"lean"|"*")
	REPO_URL="https://github.com/coolsnowwolf/lede"
	;;
esac

[[ $REPO_BRANCH ]] && cmd="-b $REPO_BRANCH"

echo -e "$(color cy '拉取源码....')\c"
BEGIN_TIME=$(date '+%H:%M:%S')
git clone -q $cmd $REPO_URL $REPO_FLODER
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
[[ $PARTSIZE ]] || PARTSIZE=600
case $TARGET_DEVICE in
	"x86_64")
		cat >.config<<-EOF
		CONFIG_TARGET_x86=y
		CONFIG_TARGET_x86_64=y
		CONFIG_TARGET_ROOTFS_PARTSIZE=$PARTSIZE
		CONFIG_BUILD_NLS=y
		CONFIG_BUILD_PATENTED=y
		EOF
	;;
	"r4s"|"r2s"|"r2c")
		cat<<-EOF >.config
		CONFIG_TARGET_rockchip=y
		CONFIG_TARGET_rockchip_armv8=y
		CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-$TARGET_DEVICE=y
		CONFIG_TARGET_ROOTFS_PARTSIZE=$PARTSIZE
		CONFIG_BUILD_NLS=y
		CONFIG_BUILD_PATENTED=y
		EOF
	;;
	"r1-plus-lts"|"r1-plus")
		cat<<-EOF >.config
		CONFIG_TARGET_rockchip=y
		CONFIG_TARGET_rockchip_armv8=y
		CONFIG_TARGET_rockchip_armv8_DEVICE_xunlong_orangepi-$TARGET_DEVICE=y
		CONFIG_TARGET_ROOTFS_PARTSIZE=$PARTSIZE
		CONFIG_PACKAGE_kmod-mt76x0u=y
		CONFIG_PACKAGE_kmod-mt76x2u=y
		CONFIG_PACKAGE_kmod-r8125=y
		CONFIG_PACKAGE_kmod-rtl8821cu=y
		CONFIG_PACKAGE_kmod-rtl8812au-ac=y
		CONFIG_DRIVER_11AC_SUPPORT=y
		CONFIG_DRIVER_11N_SUPPORT=y
		CONFIG_DRIVER_11W_SUPPORT=y
		# CONFIG_PACKAGE_luci-app-wol is not set
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
	CONFIG_PACKAGE_luci-theme-bootstrap=y
	CONFIG_PACKAGE_luci-theme-material=y
	## remove
	CONFIG_TARGET_IMAGES_GZIP=y
	CONFIG_GRUB_IMAGES=y
	# CONFIG_GRUB_EFI_IMAGES is not set
	# CONFIG_VMDK_IMAGES is not set
	# CONFIG_PACKAGE_luci-app-unblockmusic is not set
	# CONFIG_PACKAGE_luci-app-wireguard is not set
	# CONFIG_PACKAGE_luci-app-ddns is not set
	# CONFIG_PACKAGE_luci-app-zerotier is not set
	# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set
	# CONFIG_PACKAGE_luci-app-xlnetacc is not set
	# CONFIG_PACKAGE_luci-app-uugamebooster is not set
	# Libraries
	CONFIG_PACKAGE_patch=y
	CONFIG_PACKAGE_diffutils=y
	CONFIG_PACKAGE_default-settings=y
EOF

config_generate="package/base-files/files/bin/config_generate"
TARGET=$(awk '/^CONFIG_TARGET/{print $1;exit;}' .config | sed -r 's/.*TARGET_(.*)=y/\1/')
DEVICE_NAME=$(grep '^CONFIG_TARGET.*DEVICE.*=y' .config | sed -r 's/.*DEVICE_(.*)=y/\1/')

color cy "自定义设置.... "
wget -qO package/base-files/files/etc/banner git.io/JoNK8
if [[ $REPOSITORY = "lean" && ${REPO_BRANCH#*-} != "21.02" ]]; then
	REPO_BRANCH="18.06"
	sed -i "/DISTRIB_DESCRIPTION/ {s/'$/-$REPOSITORY-${REPO_BRANCH#*-}-$(date +%Y年%m月%d日)'/}" package/*/*/*/openwrt_release
	sed -i "/VERSION_NUMBER/ s/if.*/if \$(VERSION_NUMBER),\$(VERSION_NUMBER),${REPO_BRANCH#*-}-SNAPSHOT)/" include/version.mk
	sed -i "/IMG_PREFIX:/ {s/=/=${REPOSITORY}-${REPO_BRANCH#*-}-\$(shell TZ=UTC-8 date +%m%d-%H%M)-/}" include/image.mk
	sed -i 's/option enabled.*/option enabled 1/' feeds/*/*/*/*/upnpd.config
	sed -i "/listen_https/ {s/^/#/g}" package/*/*/*/files/uhttpd.config
	sed -i "{
			/upnp/d;/banner/d;/openwrt_release/d;/shadow/d
			s|zh_cn|zh_cn\nuci set luci.main.mediaurlbase=/luci-static/bootstrap|
			s|indexcache|indexcache\nsed -i 's/root::0:0:99999:7:::/root:\$1\$RysBCijW\$wIxPNkj9Ht9WhglXAXo4w0:18206:0:99999:7:::/g' /etc/shadow|
			}" $(find package/ -type f -name "*default-settings")
	_packages "luci-app-argon-config luci-theme-argon luci-app-clash"
	clone_url "https://github.com/liuran001/openwrt-packages/trunk/luci-theme-argon
	https://github.com/liuran001/openwrt-packages/trunk/luci-app-clash
	https://github.com/liuran001/openwrt-packages/trunk/luci-app-argon-config"
else
	packages_url="adbyby luci-app-adbyby-plus luci-app-cifs-mount luci-app-cpufreq luci-app-usb-printer ntfs3-mount ntfs3-oot pdnsd-alt qBittorrent-static r8125 redsocks2 qtbase"
	for k in $packages_url; do
		clone_url "https://github.com/kiddin9/openwrt-packages/trunk/$k"
	done
fi
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

[[ ${REPO_BRANCH#*-} == "18.06" ]] && {
	for d in $(find feeds/ package/ -type f -name "index.htm"); do
		if grep -q "Kernel Version" $d; then
			sed -i 's|os.date(.*|os.date("%F %X") .. " " .. translate(os.date("%A")),|' $d
			# if ! grep "admin_status/index/" $d; then
				# sed -i '/<%+footer%>/i<fieldset class="cbi-section">\n\t<legend><%:天气%></legend>\n\t<table width="100%" cellspacing="10">\n\t\t<tr><td width="10%"><%:本地天气%></td><td > <iframe width="900" height="120" frameborder="0" scrolling="no" hspace="0" src="//i.tianqi.com/?c=code&a=getcode&id=22&py=xiaoshan&icon=1"></iframe>\n\t\t<tr><td width="10%"><%:柯桥天气%></td><td > <iframe width="900" height="120" frameborder="0" scrolling="no" hspace="0" src="//i.tianqi.com/?c=code&a=getcode&id=22&py=keqiaoqv&icon=1"></iframe>\n\t\t<tr><td width="10%"><%:指数%></td><td > <iframe width="400" height="270" frameborder="0" scrolling="no" hspace="0" src="https://i.tianqi.com/?c=code&a=getcode&id=27&py=xiaoshan&icon=1"></iframe><iframe width="400" height="270" frameborder="0" scrolling="no" hspace="0" src="https://i.tianqi.com/?c=code&a=getcode&id=27&py=keqiaoqv&icon=1"></iframe>\n\t</table>\n</fieldset>\n\n<%-\n\tlocal incdir = util.libpath() .. "/view/admin_status/index/"\n\tif fs.access(incdir) then\n\t\tlocal inc\n\t\tfor inc in fs.dir(incdir) do\n\t\t\tif inc:match("%.htm$") then\n\t\t\t\tinclude("admin_status/index/" .. inc:gsub("%.htm$", ""))\n\t\t\tend\n\t\tend\n\t\end\n-%>\n' $d
			# fi
		fi
	done
}

clone_url "
	https://github.com/destan19/OpenAppFilter
	https://github.com/messense/aliyundrive-webdav
	https://github.com/jerrykuku/luci-app-vssr
	https://github.com/jerrykuku/lua-maxminddb
	https://github.com/ntlf9t/luci-app-easymesh
	https://github.com/zzsj0928/luci-app-pushbot
	https://github.com/immortalwrt/luci/branches/openwrt-18.06-k5.4/applications/luci-app-passwall
	https://github.com/fw876/helloworld
	https://github.com/xiaorouji/openwrt-passwall
	https://github.com/jerrykuku/luci-app-jd-dailybonus
	https://github.com/kiddin9/openwrt-bypass/trunk/luci-app-bypass
	https://github.com/vernesong/OpenClash/trunk/luci-app-openclash
	https://github.com/immortalwrt/packages/trunk/net/qBittorrent-Enhanced-Edition
	https://github.com/project-lede/luci-app-godproxy
	https://github.com/yaof2/luci-app-ikoolproxy
"

packages_url="luci-app-bypass luci-app-filetransfer"
for k in $packages_url; do
	clone_url "https://github.com/kiddin9/openwrt-packages/trunk/$k"
done
# https://github.com/immortalwrt/luci/branches/openwrt-21.02/applications/luci-app-ttyd ##使用分支
echo -e 'pthome.net\nchdbits.co\nhdsky.me\nwww.nicept.net\nourbits.club' | \
tee -a $(find package/ feeds/luci/applications/ -type f -name "white.list" -or -name "direct_host" | grep "ss") >/dev/null

echo '<iframe src="https://ip.skk.moe/simple" style="width: 100%; border: 0"></iframe>' | \
tee -a {$(find package/ feeds/luci/applications/ -type d -name "luci-app-vssr")/*/*/*/status_top.htm,$(find package/ feeds/luci/applications/ -type d -name "luci-app-ssr-plus")/*/*/*/status.htm,$(find package/ feeds/luci/applications/ -type d -name "luci-app-bypass")/*/*/*/status.htm,$(find package/ feeds/luci/applications/ -type d -name "luci-app-passwall")/*/*/*/global/status.htm} >/dev/null
sed -i 's/option dports.*/option dports 2/' package/A/luci-app-vssr/root/etc/config/vssr

[[ "$TARGET_DEVICE" != "phicomm_k2p" ]] && {
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
	luci-app-pushbot
	#luci-app-smartinfo
	luci-app-softwarecenter
	luci-app-transmission
	luci-app-usb-printer
	luci-app-vssr
	luci-app-bypass
	luci-app-ikoolproxy
	"
}

sed -i '/dports/s/1/2/' $(find feeds/luci/applications/ -type d -name "luci-app-vssr")/root/etc/config/vssr
sed -i 's/default y/default n/g' $(find package/A/ feeds/luci/applications/ -type d -name "luci-app-bypass")/Makefile
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=4.4.2_v1.2.16/' $(find package/A/ feeds/ -type d -name "qBittorrent-static")/Makefile
sed -i '/hw_flow/s/1/0/;/sfe_flow/s/1/0/;/sfe_bridge/s/1/0/' $(find feeds/luci/applications/ -type d -name "luci-app-turboacc")/root/etc/config/turboacc
xd=$(find package/A/ feeds/ -type d -name "luci-app-ikoolproxy")
[[ -d $xd ]] && sed -i '/echo.*root/ s/^/[[ $time =~ [0-9]+ ]] \&\&/' $xd/root/etc/init.d/koolproxy

case $TARGET_DEVICE in
"newifi-d2")
	FIRMWARE_TYPE="sysupgrade"
	DEVICE_NAME="Newifi-D2"
	_packages "luci-app-easymesh"
	sed -i '/n) ipad/s/".*"/"192.168.2.1"/' $config_generate
	;;
"phicomm_k2p")
	FIRMWARE_TYPE="sysupgrade"
	_packages "luci-app-easymesh"
	DEVICE_NAME="Phicomm-K2P"
	_packages "luci-app-wrtbwmon"
	sed -i '/clash/d' .config
	sed -i '/n) ipad/s/".*"/"192.168.2.1"/' $config_generate
	;;
"r1-plus-lts"|"r1-plus"|"r4s"|"r2c"|"r2s")
	DEVICE_NAME="$TARGET_DEVICE"
	FIRMWARE_TYPE="sysupgrade"
	_packages "
	luci-app-adbyby-plus
	#luci-app-adguardhome
	#luci-app-amule
	luci-app-dockerman
	luci-app-netdata
	luci-app-qbittorrent
	#luci-app-smartdns
	luci-app-cpufreq
	luci-app-aliyundrive-webdav
	luci-app-deluge
	luci-app-wrtbwmon
	luci-app-turboacc
	#luci-app-passwall2
	#AmuleWebUI-Reloaded htop lscpu lsscsi lsusb nano pciutils screen webui-aria2 zstd tar pv
	#subversion-server #unixodbc #git-http
	"
	sed -i '/n) ipad/s/".*"/"192.168.2.1"/' $config_generate
	wget -qO package/base-files/files/bin/bpm git.io/bpm && chmod +x package/base-files/files/bin/bpm
	wget -qO package/base-files/files/bin/ansi git.io/ansi && chmod +x package/base-files/files/bin/ansi
	[[ $TARGET_DEVICE == 'r2s' || $TARGET_DEVICE == 'r2c' || $TARGET_DEVICE == 'r1-plus' || $TARGET_DEVICE == 'r1-plus-lts' ]] && \
	sed -i 's/5.15/5.4/g' target/linux/rockchip/Makefile
	;;
"asus_rt-n16")
	DEVICE_NAME="Asus-RT-N16"
	FIRMWARE_TYPE="n16"
	sed -i '/n) ipad/s/".*"/"192.168.2.130"/' $config_generate
	;;
"x86_64")
	DEVICE_NAME="x86_64"
	FIRMWARE_TYPE="squashfs-combined"
	sed -i '/n) ipad/s/".*"/"192.168.2.150"/' $config_generate
	_packages "
	luci-app-adbyby-plus
	luci-app-adguardhome
	#luci-app-amule
	luci-app-dockerman
	luci-app-netdata
	#luci-app-jd-dailybonus
	luci-app-poweroff
	luci-app-qbittorrent
	luci-app-smartdns
	luci-app-unblockmusic
	luci-app-aliyundrive-webdav
	luci-app-deluge
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
	sed -i '/n) ipad/s/".*"/"192.168.2.1"/' $config_generate
	# clone_url "https://github.com/tuanqing/install-program" && rm -rf package/A/install-program/tools
	_packages "attr bash blkid brcmfmac-firmware-43430-sdio brcmfmac-firmware-43455-sdio
	btrfs-progs cfdisk chattr curl dosfstools e2fsprogs f2fs-tools f2fsck fdisk getopt
	hostpad-common htop install-program iperf3 kmod-brcmfmac kmod-brcmutil kmod-cfg80211
	kmod-fs-exfat kmod-fs-ext4 kmod-fs-vfat kmod-mac80211 kmod-rt2800-usb kmod-usb-net
	kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-storage
	kmod-usb-storage-extras kmod-usb-storage-uas kmod-usb2 kmod-usb3 lm-sensors losetup
	lsattr lsblk lscpu lsscsi luci-app-adguardhome luci-app-cpufreq luci-app-dockerman
	luci-app-qbittorrent mkf2fs ntfs-3g parted pv python3 resize2fs tune2fs unzip
	uuidgen wpa-cli wpad wpad-basic xfs-fsck xfs-mkf luci-app-easymesh"

	# wget -qO feeds/luci/applications/luci-app-qbittorrent/Makefile https://raw.githubusercontent.com/immortalwrt/luci/openwrt-18.06/applications/luci-app-qbittorrent/Makefile
	# sed -i 's/-Enhanced-Edition//' feeds/luci/applications/luci-app-qbittorrent/Makefile
	sed -i 's/@arm/@TARGET_armvirt_64/g' $(find . -type d -name "luci-app-cpufreq")/Makefile
	sed -i "s/default 160/default $PARTSIZE/" config/Config-images.in
	sed -e 's/services/system/; s/00//' $(find . -type d -name "luci-app-cpufreq")/luasrc/controller/cpufreq.lua -i
	[ -d ../opt/openwrt_packit ] && {
		sed -i '{
		s|mv |mv -v |
		s|openwrt-armvirt-64-default-rootfs.tar.gz|$(ls *default-rootfs.tar.gz)|
		s|TGT_IMG=.*|TGT_IMG="${WORK_DIR}/unifreq-openwrt-${SOC}_${BOARD}_k${KERNEL_VERSION}${SUBVER}-$(date "+%Y-%m%d-%H%M").img"|
		}' ../opt/openwrt_packit/mk*.sh
		sed -i '/ KERNEL_VERSION.*flippy/ {s/KERNEL_VERSION.*/KERNEL_VERSION="5.15.4-flippy-67+"/}' ../opt/openwrt_packit/make.env
	}
	;;
esac

if [[ $REPOSITORY = "baiywt" || $REPOSITORY = "xunlong" ]] && [[ $TARGET_DEVICE =~ lts ]]; then
	_packages "autocore-arm default-settings default-settings-chn fdisk cfdisk e2fsprogs ethtool haveged htop wpad-openssl usbutils losetup"
	clone_url "
	https://github.com/brvphoenix/wrtbwmon/trunk/wrtbwmon
	https://github.com/brvphoenix/luci-app-wrtbwmon/trunk/luci-app-wrtbwmon
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/emortal/autocore
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/emortal/autosamba
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/emortal/automount
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/emortal/default-settings
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/utils/dtc
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/kernel/mt-drivers
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/kernel/shortcut-fe
	https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/kernel/fast-classifier
	"
	cat >>package/kernel/linux/modules/fs.mk<<-\EOF
	define KernelPackage/fs-ntfs3
	  SUBMENU:=$(FS_MENU)
	  TITLE:=NTFS3 Read-Write file system support
	  DEPENDS:=@LINUX_5_15 +kmod-nls-base
	  KCONFIG:= \
		CONFIG_NTFS3_FS \
		CONFIG_NTFS3_64BIT_CLUSTER=y \
		CONFIG_NTFS3_LZX_XPRESS=y \
		CONFIG_NTFS3_FS_POSIX_ACL=y
	  FILES:=$(LINUX_DIR)/fs/ntfs3/ntfs3.ko
	  AUTOLOAD:=$(call AutoLoad,30,ntfs3)
	endef
	define KernelPackage/fs-ntfs3/description
	 Kernel module for NTFS3 filesystem support
	endef
	$(eval $(call KernelPackage,fs-ntfs3))
	EOF
	rm -rf package/A/{AmuleWebUI-Reloaded,luci-app-amule}
	sed -i 's,-mcpu=generic,-march=armv8-a+crypto+crc -mabi=lp64,g' include/target.mk
	sed -i "/DISTRIB_DESCRIPTION/ {s/'$/-$REPOSITORY-$(date +%Y年%m月%d日)'/}" package/*/*/*/openwrt_release
	sed -i "/VERSION_NUMBER/ s/if.*/if \$(VERSION_NUMBER),\$(VERSION_NUMBER),${REPO_BRANCH#*-}-SNAPSHOT)/" include/version.mk
	sed -i "/IMG_PREFIX:/ {s/=/=${REPOSITORY}-${REPO_BRANCH#*-}-\$(shell date +%m%d-%H%M -d +8hour)-/}" include/image.mk
	sed -i "/listen_https/ {s/^/#/g}" package/*/*/*/files/uhttpd.config
	echo -e "# CONFIG_PACKAGE_dnsmasq is not set\nCONFIG_LUCI_LANG_zh_Hans=y" >> .config
	cpuinfo="$(find package/ -type d -name "autocore")" && \
	sed -i 's/"?"/"ARMv8 Processor"/' $cpuinfo/files/generic/cpuinfo
	sed -i "{
		/upnp/d;/banner/d
		s|auto|auto\nuci set luci.main.mediaurlbase=/luci-static/bootstrap|
		s^.*shadow$^sed -i 's/root::0:0:99999:7:::/root:\$1\$RysBCijW\$wIxPNkj9Ht9WhglXAXo4w0:18206:0:99999:7:::/g' /etc/shadow^
		}" $(find package/ -type f -name "*default-settings")
	[[ $IP ]] && \
	sed -i '/n) ipad/s/".*"/"'"$IP"'"/' $config_generate || \
	sed -i '/n) ipad/s/".*"/"192.168.2.1"/' $config_generate
	sed -i 's/+amule/+amule-dlp/' package/A/*/Makefile
	sed -i 's/^ping/-- ping/g' package/*/*/*/*/*/bridge.lua
	sed -i 's|\.\./\.\.|\$(TOPDIR)/feeds/luci|' package/A/*/Makefile
	sed -i '/oaf/d' .config
fi

for p in $(find package/A/ feeds/luci/applications/ -type d -name "po" 2>/dev/null); do
	if [[ "${REPO_BRANCH#*-}" == "21.02" ]]; then
		if [[ ! -d $p/zh_Hans && -d $p/zh-cn ]]; then
			ln -s zh-cn $p/zh_Hans 2>/dev/null
		fi
	else
		if [[ ! -d $p/zh-cn && -d $p/zh_Hans ]]; then
			ln -s zh_Hans $p/zh-cn 2>/dev/null
		fi
	fi
done

grep -q "luci-app-deluge" .config && [[ $TARGET_DEVICE =~ lts ]] && {
sed -i '/PKG_BUILD_DEPENDS/s/$/ !BUILD_NLS:gettext/' include/nls.mk
}
sed -i "s/\(PKG_HASH\|PKG_MD5SUM\|PKG_MIRROR_HASH\).*/\1:=skip/" feeds/packages/utils/containerd/Makefile

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
[[ $REPO_BRANCH =~ 21 ]] && \
echo "REPO_BRANCH=${REPO_BRANCH#*-}" >> $GITHUB_ENV || \
echo "REPO_BRANCH=18.06" >> $GITHUB_ENV
echo "DEVICE_NAME=$DEVICE_NAME" >>$GITHUB_ENV
echo "FIRMWARE_TYPE=$FIRMWARE_TYPE" >>$GITHUB_ENV
echo "ARCH=`awk -F'"' '/^CONFIG_TARGET_ARCH_PACKAGES/{print $2}' .config`" >>$GITHUB_ENV
echo "UPLOAD_RELEASE=true" >>$GITHUB_ENV

echo -e "\e[1;35m脚本运行完成！\e[0m"
