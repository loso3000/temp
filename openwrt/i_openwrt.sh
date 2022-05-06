#!/usr/bin/env bash
# set -x

[[ x$REPO_FLODER = x ]] && \
(REPO_FLODER="openwrt" && echo "REPO_FLODER=openwrt" >>$GITHUB_ENV)
[[ $TARGET_DEVICE = "phicomm_k2p" ]] &&  VERSION="super"
KERNEL_VER="5.4"
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

clashcore() {
mkdir -p files/etc/openclash/core

OPENCLASH_MAIN_URL=$( curl -sL https://api.github.com/repos/vernesong/OpenClash/releases/tags/Clash | grep /clash-linux-$1 | awk -F '"' '{print $4}')
# OFFICAL_OPENCLASH_MAIN_URL=$(curl -sL https://api.github.com/repos/Dreamacro/clash/releases/tags/v1.3.5 | grep /clash-linux-$1 | awk -F '"' '{print $4}')
CLASH_TUN_URL=$(curl -sL https://api.github.com/repos/vernesong/OpenClash/releases/tags/TUN-Premium | grep /clash-linux-$1 | awk -F '"' '{print $4}')
CLASH_GAME_URL=$(curl -sL https://api.github.com/repos/vernesong/OpenClash/releases/tags/TUN | grep /clash-linux-$1 | awk -F '"' '{print $4}')

wget -qO- $OPENCLASH_MAIN_URL | tar xOvz > files/etc/openclash/core/clash
# wget -qO- $OFFICAL_OPENCLASH_MAIN_URL | gunzip -c > files/etc/openclash/core/clash
wget -qO- $CLASH_TUN_URL | gunzip -c > files/etc/openclash/core/clash_tun
wget -qO- $CLASH_GAME_URL | tar xOvz > files/etc/openclash/core/clash_game
echo -e "$(color cy 'clash-'$1' 内核下载成功！....')\c"
chmod +x files/etc/openclash/core/clash*
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
        exit 1
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

clone_url() {
    for x in $@; do
        if [[ "$(grep "^https" <<<$x | grep -Ev "helloworld|pass|build")" ]]; then
            g=$(find package/ feeds/ -maxdepth 5 -type d -name ${x##*/} 2>/dev/null)
            if ([[ -d "$g" ]] && rm -rf $g); then
                p="1"; k="$g"
            else
                p="0"; k="package/A/${x##*/}"
            fi

            if [[ "$(grep -E "trunk|branches" <<<$x)" ]]; then
                if svn export -q --force $x $k; then
                    f="1"
                fi
            else
                if git clone -q $x $k; then
                    f="1"
                fi
            fi
            [[ $f = "" ]] && echo -e "$(color cr 拉取) ${x##*/} [ $(color cr ✕) ]" | _printf
            [[ $f -lt $p ]] && echo -e "$(color cr 替换) ${x##*/} [ $(color cr ✕) ]" | _printf
            [[ $f = $p ]] && \
                echo -e "$(color cg 替换) ${x##*/} [ $(color cg ✔) ]" | _printf || \
                echo -e "$(color cb 添加) ${x##*/} [ $(color cb ✔) ]" | _printf
            unset -v p f k
        else
            for w in $(grep "^https" <<<$x); do
                if git clone -q $w ../${w##*/}; then
                    for x in `ls -l ../${w##*/} | awk '/^d/{print $NF}' | grep -Ev '*pulimit|*dump|*dtest|*Deny|*dog|*ding'`; do
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
                        unset -v p k
                    done
                fi
                rm -rf ../${w##*/}
            done
        fi
    done
}
[[ $REPO_BRANCH ]] && cmd="-b $REPO_BRANCH" || cmd="-b openwrt-18.06-k5.4"
REPO_URL=https://github.com/immortalwrt/immortalwrt
# REPO_URL=https://github.com/coolsnowwolf/lede
# cmd="master"

echo -e "$(color cy 当前的机型) $(color cb ${REPO_BRANCH}-${TARGET_DEVICE}-${VERSION})"
echo -e "$(color cy '拉取源码....')\c"
BEGIN_TIME=$(date '+%H:%M:%S')

git clone --depth 1 $REPO_URL -b $cmd  $REPO_FLODER
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
[ $PARTSIZE ] || PARTSIZE=920
case "$TARGET_DEVICE" in
    "x86_64")
        cat >.config<<-EOF
        # CONFIG_TARGET_ROOTFS_INITRAMFS is not set
        # CONFIG_TARGET_ROOTFS_CPIOGZ is not set
        CONFIG_TARGET_ROOTFS_SQUASHFS=y
        CONFIG_TARGET_x86=y
        CONFIG_TARGET_x86_64=y
        CONFIG_TARGET_KERNEL_PARTSIZE=64
        CONFIG_TARGET_ROOTFS_PARTSIZE=$PARTSIZE
        CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=256
        CONFIG_TARGET_UBIFS_FREE_SPACE_FIXUP=y
        # CONFIG_TARGET_ROOTFS_EXT4FS is not set
        CONFIG_TARGET_UBIFS_JOURNAL_SIZE=""
        CONFIG_GRUB_IMAGES=y
        CONFIG_GRUB_EFI_IMAGES=y
        # CONFIG_VMDK_IMAGES is not set
        # CONFIG_GRUB_CONSOLE is not set
        # CONFIG_ISO_IMAGES is not set
        # CONFIG_VDI_IMAGES is not set
        CONFIG_PACKAGE_myautocore-x86=y
        CONFIG_BUILD_NLS=y
        CONFIG_BUILD_PATENTED=y
EOF

cat  ../configx/extra-drivers.config >>.config

    ;;
    "r4s"|"r2c"|"r2r"|"r2s")
        cat >.config<<-EOF        
        CONFIG_TARGET_rockchip=y
        CONFIG_TARGET_rockchip_armv8=y
        CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-$TARGET_DEVICE=y
        # CONFIG_TARGET_rockchip_armv8_DEVICE_pine64_rockpro64 is not set
        # CONFIG_TARGET_rockchip_armv8_DEVICE_radxa_rock-pi-4 is not set
        # CONFIG_TARGET_rockchip_armv8_DEVICE_xunlong_orangepi-r1-plus is not set
        # CONFIG_TARGET_rockchip_armv8_DEVICE_xunlong_orangepi-r1-plus-lts is not set
        CONFIG_TARGET_ROOTFS_PARTSIZE=$PARTSIZE
        CONFIG_BUILD_NLS=y
        CONFIG_BUILD_PATENTED=y
EOF

cat  ../configx/extra-drivers.config >>.config
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
        if [[ "${REPO_BRANCH#*-}" = "18.06" || "${REPO_BRANCH#*-}" = "18.06-dev" ]]; then
            cat >.config<<-EOF
            CONFIG_TARGET_brcm47xx=y
            CONFIG_TARGET_brcm47xx_mips74k=y
            CONFIG_TARGET_brcm47xx_mips74k_DEVICE_asus_rt-n16=y
EOF
        else
            cat >.config<<-EOF
            CONFIG_TARGET_bcm47xx=y
            CONFIG_TARGET_bcm47xx_mips74k=y
            CONFIG_TARGET_bcm47xx_mips74k_DEVICE_asus_rt-n16=y
            # CONFIG_TARGET_IMAGES_GZIP is not set
EOF
        fi
    ;;
    "armvirt_64_Default")
        cat >.config<<-EOF
        CONFIG_TARGET_armvirt=y
        CONFIG_TARGET_armvirt_64=y
        CONFIG_TARGET_armvirt_64_Default=y
EOF
    ;;
esac
    cat >>.config<<-EOF
    CONFIG_KERNEL_BUILD_USER="win3gp"
    CONFIG_KERNEL_BUILD_DOMAIN="OpenWrt"
    CONFIG_GRUB_TIMEOUT="0"
    CONFIG_PACKAGE_ipv6helper=y
    CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
    CONFIG_ALL_NONSHARED=y
    ## luci app
    ddns-scripts=y
    ddns-scripts_dnspod=y
    ddns-scripts_aliyun=y
    ddns-scripts_cloudflare.com-v4=y
    CONFIG_PACKAGE_miniupnpd-igdv1=y
    CONFIG_PACKAGE_luci-app-arpbind=y
    CONFIG_PACKAGE_luci-app-upnp=y
    CONFIG_PACKAGE_luci-app-ddns=y
    CONFIG_PACKAGE_luci-app-wolplus=y
    CONFIG_PACKAGE_luci-app-advanced=y
    CONFIG_PACKAGE_luci-app-beardropper=y
    CONFIG_PACKAGE_luci-app-rebootschedule=y
    CONFIG_PACKAGE_luci-app-cowbping=y
    CONFIG_PACKAGE_luci-app-control-speedlimit=y
    CONFIG_PACKAGE_luci-app-control-parentcontrol=y
    CONFIG_PACKAGE_luci-app-zerotier=y
    
    CONFIG_PACKAGE_luci-app-vlmcsd=y
    CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client=y
    CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server=y
    CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=n
    CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server=n
    CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Client=y
    CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Server=y
    CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Rust_Client=n
    CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Rust_Server=n    
    ## remove
    # CONFIG_TARGET_IMAGES_GZIP is not set
    # CONFIG_PACKAGE_autosamba is not set
    # CONFIG_PACKAGE_luci-app-autoreboot is not set
    # CONFIG_PACKAGE_luci-app-filetransfer is not set
    # CONFIG_PACKAGE_luci-app-wol is not set
    # CONFIG_PACKAGE_luci-app-adbyby-plus is not set
    # CONFIG_PACKAGE_luci-app-accesscontrol is not set
    # CONFIG_PACKAGE_luci-app-samba is not set
    # CONFIG_PACKAGE_luci-app-unblockmusic is not set
    # CONFIG_PACKAGE_default-settings-chn is not set
    ## Libraries
    CONFIG_GRUB_TIMEOUT="0"
    # CONFIG_LINUX_5_10=y
    # CONFIG_TESTING_KERNEL=y
    CONFIG_PACKAGE_block-mount=y
    CONFIG_PACKAGE_openssh-sftp-server=y
    CONFIG_PACKAGE_automount=y
    CONFIG_PACKAGE_fdisk=y
    CONFIG_PACKAGE_patch=y
    CONFIG_PACKAGE_diffutils=y
    CONFIG_PACKAGE_default-settings=y
    CONFIG_PACKAGE_luci-theme-opentopd=y
    CONFIG_BRCMFMAC_SDIO=y
    CONFIG_LUCI_LANG_en=y
    CONFIG_LUCI_LANG_zh_Hans=y
EOF

config_generate="package/base-files/files/bin/config_generate"
color cy "自定义设置.... "
sed -i "s/192.168.1.1/192.168.8.1/" $config_generate

rm -rf feeds/*/*/{netdata,smartdns,wrtbwmon,adguardhome,luci-app-smartdns,luci-app-timecontrol,luci-app-smartinfo,luci-app-socat,luci-app-beardropper}
rm -rf package/*/{autocore,autosamba,default-settings}
rm -rf feeds/*/*/{luci-app-adguardhome,luci-app-appfilter,open-app-filter,luci-app-openclash,luci-app-vssr,luci-app-ssr-plus,luci-app-passwall,luci-app-syncdial,luci-app-zerotier,luci-app-wrtbwmon,luci-app-koolddns}

git clone https://github.com/sirpdboy/build.git ./package/build
git clone https://github.com/sirpdboy/sirpdboy-package ./package/diy
git clone https://github.com/loso3000/other ./package/other
# rm -rf  ./package/build/luci-app-netspeedtest
rm -rf  package/emortal/autocore
rm -rf  package/emortal/autosamba
rm -rf  package/emortal/default-settings
rm ./package/build/autocore
rm ./package/build/pass/luci-app-ssr-plus
rm -rf ./feeds/packages/net/smartdns
rm -rf ./feeds/packages/net/wrtbwmon
rm -rf ./feeds/luci/applications/luci-app-netdata
rm -rf ./feeds/packages/admin/netdata
rm -rf ./feeds/luci/applications/luci-app-dockerman
rm -rf ./feeds/luci/applications/luci-app-samba4
rm -rf ./feeds/luci/applications/luci-app-samba
rm -rf ./feeds/luci/applications/luci-app-wol
rm -rf ./feeds/luci/applications/luci-app-unblockneteasemusic
rm -rf ./feeds/luci/applications/luci-app-accesscontrol
rm -rf ./feeds/luci/applications/luci-app-beardropper

wget -qO package/base-files/files/etc/banner https://raw.githubusercontent.com/sirpdboy/build/master/banner
wget -qO package/base-files/files/etc/profile https://raw.githubusercontent.com/sirpdboy/build/master/profile
wget -qO package/base-files/files/etc/sysctl.conf https://raw.githubusercontent.com/sirpdboy/sirpdboy-package/master/set/sysctl.conf
#curl -fsSL  https://raw.githubusercontent.com/sirpdboy/build/master/banner > ./package/base-files/files/etc/banner
#curl -fsSL  https://raw.githubusercontent.com/sirpdboy/build/master/profile > package/base-files/files/etc/profile
#curl -fsSL  https://raw.githubusercontent.com/sirpdboy/sirpdboy-package/master/set/sysctl.conf > ./package/base-files/files/etc/sysctl.conf

sed -i 's/option enabled.*/option enabled 0/' feeds/*/*/*/*/upnpd.config
sed -i 's/option dports.*/option enabled 2/' feeds/*/*/*/*/upnpd.config
sed -i "s/ImmortalWrt/OpenWrt/" {$config_generate,include/version.mk}
sed -i "/listen_https/ {s/^/#/g}" package/*/*/*/files/uhttpd.config
echo "修改默认主题"
#sed -i 's/+luci-theme-bootstrap/+luci-theme-opentopd/g' feeds/luci/collections/luci/Makefile
sed -i 's/bootstrap/opentopd/g' feeds/luci/collections/luci/Makefile
#echo "other"

# sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=165535' package/base-files/files/etc/sysctl.conf
# sed -i 's/16384/165535/g' ./package/kernel/linux/files/sysctl-nf-conntrack.conf
#koolproxy
git clone https://github.com/iwrt/luci-app-ikoolproxy.git package/luci-app-ikoolproxy
sed -i 's,1).dep,11).dep,g' ./package/luci-app-ikoolproxy/luasrc/controller/koolproxy.lua 
curl -fsSL  https://raw.githubusercontent.com/sirpdboy/build/master/mwan3/files/etc/config/mwan3   > ./feeds/packages/net/mwan3/files/etc/config/mwan3
echo "poweroff"
curl -fsSL  https://raw.githubusercontent.com/sirpdboy/other/master/patch/poweroff/poweroff.htm > ./feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_system/poweroff.htm 
curl -fsSL  https://raw.githubusercontent.com/sirpdboy/other/master/patch/poweroff/system.lua > ./feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua

sed -i 's/option commit_interval.*/option commit_interval 1h/g' feeds/packages/net/nlbwmon/files/nlbwmon.config #修改流量统计写入为1
sed -i 's#option database_directory /var/lib/nlbwmon#option database_directory /etc/config/nlbwmon_data#g' feeds/packages/net/nlbwmon/files/nlbwmon.config #修改流量统计数据存放默认位置
git clone https://github.com/immortalwrt/luci-app-unblockneteasemusic.git  ./package/diy/luci-app-unblockneteasemusic

[[ -d "package/A" ]] || mkdir -m 755 -p package/A
    # https://github.com/kiddin9/openwrt-bypass
    #https://github.com/loso3000/openwrt-passwall
    #https://github.com/jerrykuku/luci-app-vssr.git
    # https://github.com/sirpdboy/sirpdboy-package/
    # https://github.com/coolsnowwolf/packages/trunk/libs/qttools
    # https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent
    # https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent-static
    # https://github.com/coolsnowwolf/packages/trunk/libs/qtbase
    #  https://github.com/coolsnowwolf/packages/trunk/utils/btrfs-progs
    # https://github.com/sirpdboy/diy/trunk/luci-app-netspeedtest
    # https://github.com/sirpdboy/luci-theme-opentopd.git
    # https://github.com/fw876/helloworld
clone_url "
    https://github.com/fw876/helloworld
    https://github.com/messense/aliyundrive-webdav/trunk/openwrt/aliyundrive-webdav
    https://github.com/messense/aliyundrive-webdav/trunk/openwrt/luci-app-aliyundrive-webdav
    https://github.com/linkease/nas-packages-luci/trunk/luci/luci-app-linkease
    https://github.com/linkease/nas-packages/trunk/network/services/linkease
    https://github.com/rufengsuixing/luci-app-zerotier.git
    https://github.com/rufengsuixing/luci-app-syncdial.git 
    https://github.com/tindy2013/openwrt-subconverter
    https://github.com/zxlhhyccc/luci-app-v2raya.git
    https://github.com/kiddin9/luci-app-dnsfilter
    https://github.com/QiuSimons/openwrt-mos
    https://github.com/jerrykuku/luci-theme-argon.git
    https://github.com/kiddin9/luci-theme-edge.git
    https://github.com/destan19/OpenAppFilter
    https://github.com/ntlf9t/luci-app-easymesh
    https://github.com/zzsj0928/luci-app-pushbot
    https://github.com/jerrykuku/luci-app-jd-dailybonus
    https://github.com/ophub/luci-app-amlogic/trunk/luci-app-amlogic
    https://github.com/vernesong/OpenClash/trunk/luci-app-openclash
    https://github.com/lisaac/luci-lib-docker/trunk/collections/luci-lib-docker
"
# https://github.com/immortalwrt/luci/branches/openwrt-21.02/applications/luci-app-ttyd ## 分支
echo -e 'pthome.net\nchdbits.co\nhdsky.me\nwww.nicept.net\nourbits.club' | \
tee -a $(find package/A/ feeds/luci/applications/ -type f -name "white.list" -or -name "direct_host" | grep "ss") >/dev/null

# echo '<iframe src="https://ip.skk.moe/simple" style="width: 100%; border: 0"></iframe>' | \
# tee -a {$(find package/A/ feeds/luci/applications/ -type d -name "luci-app-vssr")/*/*/*/status_top.htm,$(find package/A/ feeds/luci/applications/ -type d -name "luci-app-ssr-plus")/*/*/*/status.htm,$(find package/A/ feeds/luci/applications/ -type d -name "luci-app-bypass")/*/*/*/status.htm,$(find package/A/ feeds/luci/applications/ -type d -name "luci-app-passwall")/*/*/*/global/status.htm} >/dev/null

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

sed -i 's/option dports.*/option dports 2/' feeds/luci/applications/luci-app-vssr/root/etc/config/vssr

[[ $TARGET_DEVICE = "phicomm_k2p" || $VERSION = "super" ]] || {
    _packages "
    automount autosamba-samba4 axel kmod-rt2500-usb kmod-rtl8187
    luci-app-aria2
    luci-app-cifs-mount
    luci-app-diskman
    luci-app-hd-idle
    luci-app-pushbot
    luci-app-transmission
    luci-app-usb-printer
    luci-app-vssr
    luci-app-ssr-plus
    luci-app-bypass
    luci-app-passwall
    luci-app-openclash
    luci-app-socat
    luci-app-dnsfilter
    luci-app-samba4
    luci-app-netspeedtest
    luci-app-webadmin
    luci-app-unblockneteasemusic
    "
    trv=`awk -F= '/PKG_VERSION:/{print $2}' feeds/packages/net/transmission/Makefile`
    wget -qO feeds/packages/net/transmission/patches/tr$trv.patch raw.githubusercontent.com/hong0980/diy/master/files/transmission/tr$trv.patch
    [[ -d package/A/qtbase ]] && rm -rf feeds/packages/libs/qt5
}

[[ "$REPO_BRANCH" == "openwrt-21.02" ]] && {
    # sed -i 's/services/nas/' feeds/luci/*/*/*/*/*/*/menu.d/*transmission.json
    sed -i 's/^ping/-- ping/g' package/*/*/*/*/*/bridge.lua
} || {
    [[ $TARGET_DEVICE == phicomm_k2p ]] || _packages "luci-app-smartinfo"
    for d in $(find feeds/ package/ -type f -name "index.htm"); do
        if grep -q "Kernel Version" $d; then
            sed -i 's|os.date(.*|os.date("%F %X") .. " " .. translate(os.date("%A")),|' $d

        fi
    done
}

for p in $(find package/A/ feeds/luci/applications/ -maxdepth 2 -type d -name "po" 2>/dev/null); do
    if [[ "${REPO_BRANCH#*-}" == "21.02" ]]; then
        if [[ ! -d $p/zh_Hans && -d $p/zh-cn ]]; then
            ln -s zh-cn $p/zh_Hans 2>/dev/null
            printf "%-13s %-33s %s %s %s\n" \
            $(echo -e "添加zh_Hans $(awk -F/ '{print $(NF-1)}' <<< $p) [ $(color cg ✔) ]")
        fi
    else
        if [[ ! -d $p/zh-cn && -d $p/zh_Hans ]]; then
            ln -s zh_Hans $p/zh-cn 2>/dev/null
            printf "%-13s %-33s %s %s %s\n" \
            `echo -e "添加zh-cn $(awk -F/ '{print $(NF-1)}' <<< $p) [ $(color cg ✔) ]"`
        fi
    fi
done

x=$(find package/A/ feeds/luci/applications/ -type d -name "luci-app-bypass" 2>/dev/null)
[[ -f $x/Makefile ]] && sed -i 's/default y/default n/g' "$x/Makefile"

case "$TARGET_DEVICE" in
"newifi-d2")
    DEVICE_NAME="Newifi-D2"
    FIRMWARE_TYPE="sysupgrade"
    sed -i '/openclash/d' .config
    sed -i '/netspeedtest/d' .config
    sed -i '/bypass/d' .config
    sed -i '/passwall/d' .config
    ;;
"r4s"|"r2c"|"r2r"|"r2s")
    DEVICE_NAME="$TARGET_DEVICE"
    FIRMWARE_TYPE="sysupgrade"
    
    _packages "
    luci-app-adguardhome
    luci-app-ssr-plus
    luci-app-bypass
    luci-app-passwall
    luci-app-vssr
    luci-app-openclash
    luci-app-socat
    luci-app-samba4
    luci-app-smartdns
    luci-app-unblockneteasemusic
    luci-theme-argon
    luci-theme-edge
    "
    [[  $VERSION = plus ]] && {
    
    _packages "
    #luci-app-adguardhome
    #luci-app-adguardhome_INCLUDE_binary
    #luci-app-vssr
    luci-app-ssr-plus
    luci-app-bypass
    #luci-app-passwall
    luci-app-openclash
    luci-app-socat
    luci-app-samba4
    luci-app-webadmin
    luci-app-unblockneteasemusic
    #luci-app-dnsfilter
    #luci-app-dockerman
    #luci-app-netdata
    #luci-app-qbittorrent
    #luci-app-netspeedtest
    #luci-app-smartdns
    #luci-app-deluge
    #luci-app-nlbwmon
    #luci-app-wrtbwmon
    luci-app-usb-printer
    #luci-app-pushbot
    #luci-app-ikoolproxy
    #luci-app-cifs-mount
    luci-app-uugamebooster
    #luci-app-aliyundrive-webdav
    #luci-app-usb-printer
    luci-theme-argon
    luci-theme-edge
    luci-app-passwall_INCLUDE_Brook
    luci-app-passwall_INCLUDE_ChinaDNS_NG
    luci-app-passwall_INCLUDE_Haproxy
    luci-app-passwall_INCLUDE_Hysteria
    luci-app-passwall_INCLUDE_Kcptun
    luci-app-passwall_INCLUDE_NaiveProxy
    luci-app-passwall_INCLUDE_PDNSD
    luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client
    luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server
    luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client
    luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server
    luci-app-passwall_INCLUDE_Simple_Obfs
    luci-app-passwall_INCLUDE_Trojan_Plus
    luci-app-passwall_INCLUDE_V2ray
    luci-app-passwall_INCLUDE_Xray
    #AmuleWebUI-Reloaded htop lscpu lsscsi lsusb nano pciutils screen webui-aria2 zstd tar pv
    #subversion-server #unixodbc #git-http

    #USB3.0支持
    kmod-usb2 kmod-usb2-pci kmod-usb3 autosamba-samba4
    kmod-fs-nfsd kmod-fs-nfs kmod-fs-nfs-v4

    #3G/4G_Support
    kmod-usb-acm kmod-usb-serial kmod-usb-ohci-pci kmod-sound-core

    #USB_net_driver
    kmod-mt76 kmod-mt76x2u kmod-rtl8821cu kmod-rtl8192cu kmod-rtl8812au-ac
    kmod-usb-net-asix-ax88179 kmod-usb-net-cdc-ether kmod-usb-net-rndis
    usb-modeswitch kmod-usb-net-rtl8152-vendor kmod-usb-printer 
    "
    # sed -i 's/qbittorrent_dynamic:qbittorrent/qbittorrent_dynamic:qBittorrent-Enhanced-Edition/g' package/feeds/luci/luci-app-qbittorrent/Makefile
    sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=4.4.1_v1.2.15/' $(find package/A/ feeds/ -type d -name "qBittorrent-static")/Makefile
    wget -qO package/base-files/files/bin/bpm git.io/bpm && chmod +x package/base-files/files/bin/bpm
    wget -qO package/base-files/files/bin/ansi git.io/ansi && chmod +x package/base-files/files/bin/ansi
    grep CONFIG_TARGET_ROOTFS_PARTSIZE .config
    KERNEL_VER="$(grep "KERNEL_PATCHVER:="  ./target/linux/armvirt/Makefile | cut -d = -f 2)"
    }
    ;;
"phicomm_k2p")
    DEVICE_NAME="Phicomm-K2P"
    FIRMWARE_TYPE="sysupgrade"
    sed -i '/openclash/d' .config
    sed -i '/netspeedtest/d' .config
    sed -i '/bypass/d' .config
    sed -i '/passwall/d' .config
    ;;
"asus_rt-n16")
    DEVICE_NAME="Asus-RT-N16"
    FIRMWARE_TYPE="n16"
    sed -i '/openclash/d' .config
    sed -i '/netspeedtest/d' .config
    sed -i '/bypass/d' .config
    sed -i '/passwall/d' .config
    sed -i '/openclash/d' .config
    ;;
"x86_64")
    DEVICE_NAME="x86_64"
    FIRMWARE_TYPE="squashfs-combined"
    _packages "
    luci-app-smartdns
    luci-theme-argon
    luci-theme-edge
    luci-app-bypass
    luci-app-adguardhome
    #luci-app-vssr
    luci-app-ssr-plus
    #luci-app-passwall
    luci-app-openclash
    luci-app-v2ray
    #luci-app-netspeedtest
    luci-app-unblockneteasemusic
    luci-app-samba4
    luci-app-webadmin
    luci-app-socat
    #USB3.0支持
    kmod-usb2 kmod-usb2-pci kmod-usb3
    kmod-fs-nfsd kmod-fs-nfs kmod-fs-nfs-v4
    #3G/4G_Support
    kmod-usb-acm kmod-usb-serial kmod-usb-ohci-pci kmod-sound-core
    #USB_net_driver
    kmod-mt76 kmod-mt76x2u kmod-rtl8821cu kmod-rtl8192cu kmod-rtl8812au-ac
    kmod-usb-net-asix-ax88179 kmod-usb-net-cdc-ether kmod-usb-net-rndis
    #docker
    kmod-dm kmod-dummy kmod-ikconfig kmod-veth
    kmod-nf-conntrack-netlink kmod-nf-ipvs
    #x86
    acpid ath10k-firmware-qca9888 autosamba-samba4 kmod-igc
    ath10k-firmware-qca988x ath10k-firmware-qca9984
    brcmfmac-firmware-43602a1-pcie irqbalance wget kmod-ntfs-3g
    kmod-alx kmod-ath10k kmod-bonding kmod-drm-ttm kmod-backlight
    kmod-igbvf kmod-iwlwifi kmod-ixgbevf e2fsprogs wget htop
    kmod-mmc-spi kmod-r8168 kmod-rtl8xxxu kmod-sdhci ppp-mod-pptp xl2tpd uqmi
    kmod-tg3 lm-sensors-detect snmpd kmod-vmxnet3 f2fs-tools f2fsck resize2fs
    "
    [[  $VERSION = "mini" || $VERSION = "dz" ]] && {
    _packages "
    luci-app-smartdns
    luci-app-diskman
    luci-app-nlbwmon
    luci-app-wrtbwmon
    luci-app-vssr
    luci-app-adguardhome
    luci-app-ssr-plus
    luci-app-unblockneteasemusic
    luci-app-pushbot
    luci-app-dnsfilter
    luci-app-ikoolproxy
    luci-app-ttyd
    luci-app-turboacc
    luci-app-mwan3
    luci-app-syncdial
    kmod-usb-printer kmod-lp tree usbutils tmate gotop usb-modeswitch kmod-usb-serial-wwan kmod-usb-serial-option kmod-usb-serial
    "
    }
    # kmod-drm-ttm kmod-backlight
    [[  $VERSION = "plus" ]] && {
    _packages "
    luci-app-adguardhome
    luci-app-dockerman
    luci-app-smartdns
    luci-app-control-timewol
    luci-app-hd-idle
    luci-app-diskman
    luci-app-baidupcs-web
    luci-app-nlbwmon
    luci-app-wrtbwmon
    luci-app-vssr
    luci-app-ssr-plus
    luci-app-ikoolproxy
    luci-app-cifs-mount
    luci-app-uugamebooster
    luci-app-usb-printer
    luci-app-ttyd
    luci-app-turboacc
    luci-app-dnsto
    luci-app-pushbot
    luci-app-dnsfilter
    luci-app-kodexplorer
    luci-app-uhttpd
    luci-app-vsftpd
    #luci-app-mosdns
    luci-app-koolddns
    #luci-app-linkease
    luci-app-tencentddns
    luci-app-cifs-mount
    luci-app-unblockneteasemusic
    luci-app-mwan3
    luci-app-syncdial
    luci-app-rclone
    luci-app-pppoe-server
    luci-app-ipsec-serve
    #luci-app-docker
    #luci-app-dockerman
    luci-app-softethervpn
    luci-app-udpxy
    luci-app-oaf
    luci-app-transmission
    luci-app-mwan3helper
    luci-app-familycloud
    luci-app-nps
    luci-app-frpc
    luci-app-nfs
    luci-app-aria2
    luci-app-openvpn-server
    luci-app-aliyundrive-webdav
    kmod-usb-printer kmod-lp
    "
    }
    [[  $VERSION = "dz" ]] && {
    _packages "
    luci-app-uugamebooster
    luci-app-linkease
    luci-app-webadmin
    luci-app-udpxy
    luci-app-aliyundrive-webdav
    "
    }

    # sed -i 's/qbittorrent_dynamic:qbittorrent/qbittorrent_dynamic:qBittorrent-Enhanced-Edition/g' package/feeds/luci/luci-app-qbittorrent/Makefile
    # sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=4.4.1_v1.2.15/' $(find package/A/ feeds/ -type d -name "qBittorrent-static")/Makefile
    # wget -qO package/base-files/files/bin/bpm git.io/bpm && chmod +x package/base-files/files/bin/bpm
    # wget -qO package/base-files/files/bin/ansi git.io/ansi && chmod +x package/base-files/files/bin/ansi
    grep CONFIG_TARGET_ROOTFS_PARTSIZE .config
    clashcore amd64

     KERNEL_VER=`grep "KERNEL_PATCHVER:="  target/linux/x86/Makefile | cut -d = -f 2`
    ;;
"armvirt_64_Default")
        KERNEL_VER=`grep "KERNEL_PATCHVER:="  target/linux/rockchip/Makefile | cut -d = -f 2`

    DEVICE_NAME="armvirt-64-default"
    FIRMWARE_TYPE="armvirt-64-default-rootfs"
    sed -i '/easymesh/d' .config
    [[  $VERSION = plus ]] && {
    _packages "attr bash blkid brcmfmac-firmware-43430-sdio brcmfmac-firmware-43455-sdio luci-app-samba4
    btrfs-progs cfdisk chattr curl dosfstools e2fsprogs f2fs-tools f2fsck fdisk getopt
    hostpad-common htop install-program iperf3 kmod-brcmfmac kmod-brcmutil kmod-cfg80211
    kmod-fs-ext4 kmod-fs-vfat kmod-mac80211 kmod-rt2800-usb kmod-usb-net autosamba-samba4
    kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-storage
    kmod-usb-storage-extras kmod-usb-storage-uas kmod-usb2 kmod-usb3 lm-sensors losetup
    lsattr lsblk lscpu lsscsi luci-app-adguardhome luci-app-cpufreq luci-app-dockerman
    mkf2fs ntfs-3g parted pv python3 resize2fs tune2fs unzip
    uuidgen wpa-cli wpad wpad-basic xfs-fsck xfs-mkfs bsdtar pigz gawk perl perl-http-date
    perlbase-getopt perlbase-time perlbase-unicode perlbase-utf8 luci-app-amlogic"
    echo "CONFIG_PERL_NOCOMMENT=y" >>.config
    
    clashcore armv8

    sed -i "s/default 160/default $PARTSIZE/" config/Config-images.in
    # sed -i 's/@arm/@TARGET_armvirt_64/g' $(find package/A/ feeds/ -type d -name "luci-app-cpufreq")/Makefile
    # sed -e 's/services/system/; s/00//' $(find package/A/ feeds/ -type d -name "luci-app-cpufreq")/luasrc/controller/cpufreq.lua -i
    }
    ;;
esac


echo -e "$(color cy '个性配置....')\c"

sed -i 's/"Argon 主题设置"/"Argon设置"/g' `grep "Argon 主题设置" -rl ./`
sed -i 's/"Turbo ACC 网络加速"/"网络加速"/g' `grep "Turbo ACC 网络加速" -rl ./`
sed -i 's/"网络存储"/"存储"/g' `grep "网络存储" -rl ./`
sed -i 's/"USB 打印服务器"/"打印服务"/g' `grep "USB 打印服务器" -rl ./`
sed -i 's/"带宽监控"/"监控"/g' `grep "带宽监控" -rl ./`
sed -i 's/实时流量监测/流量/g'  `grep "实时流量监测" -rl ./`
sed -i 's/解锁网易云灰色歌曲/解锁灰色歌曲/g'  `grep "解锁网易云灰色歌曲" -rl ./`
sed -i 's/解除网易云音乐播放限制/解锁灰色歌曲/g'  `grep "解除网易云音乐播放限制" -rl ./`
sed -i 's/家庭云//g'  `grep "家庭云" -rl ./`

sed -i 's/aMule设置/电驴下载/g' ./feeds/luci/applications/luci-app-amule/po/zh-cn/amule.po
sed -i 's/监听端口/监听端口 用户名admin密码adminadmin/g' ./feeds/luci/applications/luci-app-qbittorrent/po/zh-cn/qbittorrent.po

sed -i 's/a.default = "0"/a.default = "1"/g' ./feeds/luci/applications/luci-app-cifsd/luasrc/controller/cifsd.lua   #挂问题
# echo  "        option tls_enable 'true'" >> ./feeds/luci/applications/luci-app-frpc/root/etc/config/frp   #FRP穿透问题
sed -i 's/invalid/# invalid/g' ./package/network/services/samba36/files/smb.conf.template  #共享问题
sed -i '/mcsub_renew.datatype/d'  ./feeds/luci/applications/luci-app-udpxy/luasrc/model/cbi/udpxy.lua  #修复UDPXY设置延时55的错误
sed -i '/filter_/d' ./package/network/services/dnsmasq/files/dhcp.conf   #DHCP禁用IPV6问题
sed -i 's/请输入用户名和密码。/欢迎使用!请输入用户密码~/g' ./feeds/luci/modules/luci-base/po/zh-cn/base.po   #用户名密码

#version
date1='Ipv6-R'`TZ=UTC-8 date +%Y.%m.%d -d +"12"hour`
date1='Ipv6-S20220506'
case "$VERSION" in
"mini")
       sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/20220501-Ipv6-Mini-5.4-/g' include/image.mk
       #date1='Ipv6-Mini-5.4 S20220401'
       #sed -i 's/IMG_PREFIX:=.*/$(shell TZ=UTC-8 date +%Y%m%d -d +12hour)-Ipv6-Mini-5.4-$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))/g' include/image.mk
    ;;
"plus")
        sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/20220501-Ipv6-Plus-5.4-/g' include/image.mk
       #date1='Ipv6-Plus-5.4 S20220401'
       #sed -i 's/IMG_PREFIX:=.*/$(shell TZ=UTC-8 date +%Y%m%d -d +12hour)-Ipv6-Plus-5.4-$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))/g' include/image.mk
       ;;
"dz")
       sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/20220501-Ipv6-Dz-5.4-/g' include/image.mk
       #sed -i 's/IMG_PREFIX:=.*/$(shell TZ=UTC-8 date +%Y%m%d -d +12hour)-Ipv6-Dz-5.4-$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))/g' include/image.mk
       #date1='Ipv6-Dz-5.4 S20220401'
       ;;
"*")
        sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/20220501-Ipv6-Super-/g' include/image.mk
        #date1='Ipv6-Super S20220401'
        #sed -i 's/IMG_PREFIX:=.*/$(shell TZ=UTC-8 date +%Y%m%d -d +12hour)-Ipv6-Super-$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))/g' include/image.mk
        ;;
 
esac
echo "=date1=${date1}==   -----  =VERSION=$VERSION=="  

echo "DISTRIB_REVISION='${date1} '" > ./package/base-files/files/etc/openwrt_release1
echo ${date1}' ' >> ./package/base-files/files/etc/banner
echo '---------------------------------' >> ./package/base-files/files/etc/banner

chmod +x ./package/*/root/etc/init.d/*  
chmod +x ./package/*/root/usr/*/*  
chmod +x ./package/*/*/root/etc/init.d/*  
chmod +x ./package/*/*/root/usr/*/*  
chmod +x ./package/*/*/*/root/etc/init.d/*  
chmod +x ./package/*/*/*/root/usr/*/*
status

echo -e "$(color cy '更新配置....')\c"
sed -i 's/^[ \t]*//g' ./.config
make defconfig 1>/dev/null 2>&1
cat .config
status

# echo "SSH_ACTIONS=true" >>$GITHUB_ENV #SSH后台
# echo "UPLOAD_PACKAGES=false" >>$GITHUB_ENV
# echo "UPLOAD_SYSUPGRADE=false" >>$GITHUB_ENV
echo "UPLOAD_BIN_DIR=true" >>$GITHUB_ENV
# echo "UPLOAD_FIRMWARE=false" >>$GITHUB_ENV
echo "UPLOAD_COWTRANSFER=false" >>$GITHUB_ENV
# echo "UPLOAD_WETRANSFER=false" >> $GITHUB_ENV
echo "CACHE_ACTIONS=true" >> $GITHUB_ENV
echo "DEVICE_NAME=$DEVICE_NAME" >>$GITHUB_ENV
echo "FIRMWARE_TYPE=$FIRMWARE_TYPE" >>$GITHUB_ENV
echo "ARCH=`awk -F'"' '/^CONFIG_TARGET_ARCH_PACKAGES/{print $2}' .config`" >>$GITHUB_ENV
echo -e "\e[1;35m脚本运行完成！\e[0m"
