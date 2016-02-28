#
# Copyright (C) 2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=empower-agent
PKG_VERSION:=20160228
PKG_RELEASE:=1
PKG_REV:=641b13bc19934820cc5db91237f067c1a2dbf1f3

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=https://github.com/rriggio/empower-agent.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=$(PKG_REV)
PKG_SOURCE_PROTO:=git

PKG_BUILD_DEPENDS:=empower-agent/host

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk

define Package/empower-agent
	SECTION:=net
	CATEGORY:=Network
	TITLE:=The EmPOWER Agent
	MAINTAINER:=Roberto Riggio <roberto.riggio@create-net.org>
	DEPENDS:=+kmod-tun +libpcap +libstdcpp
	URL:=http://www.read.cs.ucla.edu/
endef

define Package/empower-agent/Description
	The EmPOWER Agent
endef

EXTRA_CFLAGS=-MD

CONFIGURE_ARGS += \
	--enable-tools=host \
	--enable-userlevel \
	--enable-wifi \
	--enable-empower \
	--enable-diffserv \
	--disable-linuxmodule \
	--disable-dynamic-linking \

HOST_CONFIGURE_ARGS += \
	--enable-userlevel \
	--enable-wifi \
	--enable-empower \
	--disable-linuxmodule \

define Host/Compile
	$(call Host/Install/Default, tools elementmap.xml install)
endef

define Build/Compile
	(cd $(PKG_BUILD_DIR)/userlevel; \
		$(STAGING_DIR_HOST)/bin/click-mkmindriver -p $(PKG_NAME) -C $(STAGING_DIR_HOST) \
		-f $(PKG_BUILD_DIR)/elements/empower/samples/empower.click \
		-A --all -E Discard -E Print -E PrintWifi -E Strip -E Null -e SetTXRate -e SetTXRateHT \
		-E EmpowerPowerSaveBuffer; \
	);
	$(call Build/Install/Default, MINDRIVER=$(PKG_NAME) install)
endef

define Package/empower-agent/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/share/click
	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/etc/config/
	$(CP) ./files/empower.config $(1)/etc/config/empower
	$(INSTALL_BIN) ./files/empower.init $(1)/etc/init.d/empower
	$(INSTALL_BIN) ./files/empower_config.sh $(1)/usr/bin/empower_config.sh 
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/conf/wifi/write_handler $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/conf/wifi/read_handler $(1)/usr/bin/
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/$(PKG_NAME)click $(1)/usr/bin/click
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/click-align $(1)/usr/bin/click-align
	$(CP) $(PKG_INSTALL_DIR)/usr/share/click/elementmap.xml $(1)/usr/share/click/elementmap.xml
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,empower-agent))

