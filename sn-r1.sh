#!/bin/bash

# git clone -b openwrt-24.10-6.6 --single-branch --filter=blob:none https://github.com/padavanonly/immortalwrt-mt798x-24.10 immortalwrt-mt798x-24.10
# cd immortalwrt-mt798x-24.10

# git config --local https.proxy socks5://host.docker.internal:1080

# ./scripts/feeds update -a
# ./scripts/feeds install -a

# 复制 DTS 和配置文件
cp -f "$GITHUB_WORKSPACE/dts/filogic.mk" "target/linux/mediatek/image/filogic.mk"
cp -f "$GITHUB_WORKSPACE/dts/mt7981b-ph-hy3000-emmc.dts" "target/linux/mediatek/dts/mt7981b-ph-hy3000-emmc.dts"
cp -f "$GITHUB_WORKSPACE/dts/mt7981b-bt-r320-emmc.dts" "target/linux/mediatek/dts/mt7981b-bt-r320-emmc.dts"
cp -f "$GITHUB_WORKSPACE/dts/mt7981b-sl-3000-emmc.dts" "target/linux/mediatek/dts/mt7981b-sl-3000-emmc.dts"
cp -f "$GITHUB_WORKSPACE/dts/mt7981b-SN-R1-emmc.dts" "target/linux/mediatek/dts/mt7981b-SN-R1-emmc.dts"
cp -f "$GITHUB_WORKSPACE/dts/02_network" "target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
cp -f "$GITHUB_WORKSPACE/dts/01_leds" "target/linux/mediatek/filogic/base-files/etc/board.d/01_leds"
cp -f "$GITHUB_WORKSPACE/dts/platform.sh" "target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh"
cp -f "$GITHUB_WORKSPACE/dts/mediatek_filogic" "package/boot/uboot-envtools/files/mediatek_filogic"
echo "sn-r1 dts文件替换成功"

# theme
rm -rf feeds/luci/themes/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# homeproxy
rm -rf feeds/luci/applications/luci-app-homeproxy
git clone https://github.com/immortalwrt/homeproxy

# passwall
# rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
# git clone https://github.com/xiaorouji/openwrt-passwall-packages package/passwall-packages

# rm -rf feeds/luci/applications/luci-app-passwall
# git clone https://github.com/xiaorouji/openwrt-passwall package/passwall-luci
# git clone https://github.com/xiaorouji/openwrt-passwall2 package/passwall2-luci

# ssr-plus
# rm -rf package/helloworld
# git clone --depth=1 https://github.com/fw876/helloworld.git package/helloworldd
# git -C package/helloworld pull

# mosdns
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
rm -rf feeds/packages/net/v2ray-geodata
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2dat package/v2dat

# tailscale
# sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
# git clone https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# easytier
# git clone -b optional-easytier-web --single-branch https://github.com/icyray/luci-app-easytier package/luci-app-easytier
# sed -i 's/util.pcdata/xml.pcdata/g' package/luci-app-easytier/luci-app-easytier/luasrc/model/cbi/easytier.lua

# defconfig
# cp -f ../.config .config
# cp -f defconfig/mt7981-ax3000.config .config
sed -i 's|IMG_PREFIX:=|IMG_PREFIX:=$(shell TZ="Asia/Shanghai" date +"%Y%m%d")-24.10-6.6-|' include/image.mk
# make menuconfig
# 查找并修复 netif_rx_ni
TARGET_FILE=$(find package -path "*/mt_wifi/os/linux/rt_profile.c" 2>/dev/null | head -1)
if [ -n "$TARGET_FILE" ]; then
    sed -i 's/netif_rx_ni(/netif_rx(/g' "$TARGET_FILE"
    echo "已修复 $TARGET_FILE"
else
    echo "警告: 未找到 rt_profile.c，跳过修复"
fi
# ============================================================
# 1. 强制锁定设备为 sn_r1-emmc（解决找 bt-r320 的问题）
# ============================================================
echo "=== 强制设置设备为 sn_r1-emmc ==="
cd "$GITHUB_WORKSPACE/openwrt" || exit 1

# 清空干扰的 defconfig
> "$GITHUB_WORKSPACE/defconfig/mt7981-ax3000.config"

# 删除旧设备配置，只保留 sn_r1-emmc
sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_/d' .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sn_r1-emmc=y" >> .config

# 确保子目标正确
sed -i 's/^CONFIG_TARGET_mediatek_filogic=y//' .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config

# 清理其他子目标
sed -i '/^CONFIG_TARGET_mediatek_mt7981/d' .config

# 2. 添加 M.2（PCIe + NVMe）内核配置
echo "=== 添加 M.2 支持 ==="
cat >> .config << "EOF"
# PCIe 支持
CONFIG_PCI=y
CONFIG_PCIEPORTBUS=y
CONFIG_PCI_MSI=y
CONFIG_PCIE_MEDIATEK=y

# NVMe 驱动
CONFIG_BLK_DEV_NVME=y
CONFIG_NVME_CORE=y

# 可选：PCIe 热插拔（如果需要）
# CONFIG_HOTPLUG_PCI=y
# CONFIG_PCI_DEBUG=y
EOF

# 3. 执行 defconfig（会保留我们添加的配置）
make defconfig

# compile and build
# make download -j8
# make -j$(nproc)
