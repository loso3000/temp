#!/bin/bash

export KERNEL_VER="$(grep "KERNEL_PATCHVER:="  ./target/linux/x86/Makefile | cut -d = -f 2)"
date1='Ipv6-Jz S'`TZ=UTC-8 date +%Y.%m.%d -d +"12"hour`
# date1='Ipv6-S2022.02.01'
if [ "$KERNEL_VER" = "5.4" ]; then
    sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/$(shell TZ=UTC-8 date +%Y%m%d -d +12hour)-Ipv6-Jz-5.4-/g' include/image.mk
elif [ "$KERNEL_VER" = "5.10" ]; then
    sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/$(shell TZ=UTC-8 date +%Y%m%d -d +12hour)-Ipv6-Jz-5.10-/g' include/image.mk
elif [ "$KERNEL_VER" = "5.15" ]; then
    sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/$(shell TZ=UTC-8 date +%Y%m%d -d +12hour)-Ipv6-Jz-5.15-/g' include/image.mk
fi
# sed -i 's/$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/20220201-Ipv6-Jz-${str1}-/g' include/image.mk
echo "DISTRIB_REVISION='${date1} by Sirpdboy'" > ./package/base-files/files/etc/openwrt_release1
echo ${date1}' by Sirpdboy ' >> ./package/base-files/files/etc/banner
echo '---------------------------------' >> ./package/base-files/files/etc/banner

# sed -i "/DISTRIB_DESCRIPTION/ {s/'$/-immortalwrt-$(date +%YÄê%mÔÂ%dÈÕ)'/}" package/*/*/*/openwrt_release
# sed -i "/IMG_PREFIX:/ {s/=/=Immortal-\$(shell date +%m%d-%H%M -d +8hour)-/}" include/image.mk

exit 0
