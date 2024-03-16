export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

export ADDITIONAL_CFLAGS = -I$(THEOS_PROJECT_DIR)/Tweaks -Wno-module-import-in-extern-c
export libcolorpicker_ARCHS = arm64
export libFLEX_ARCHS = arm64

ifndef YOUTUBE_VERSION
YOUTUBE_VERSION = 19.08.2
endif
ifndef UYOU_VERSION
UYOU_VERSION = 3.0.3
endif
PACKAGE_VERSION = $(YOUTUBE_VERSION)-$(UYOU_VERSION)

INSTALL_TARGET_PROCESSES = YouTube
TWEAK_NAME = uYouPlus

ifneq ($(or $(IPA),$($(TWEAK_NAME)_IPA)),)
MODULES = jailed
undefine THEOS_PACKAGE_SCHEME
endif

$(TWEAK_NAME)_FILES := $(wildcard Sources/*.xm) $(wildcard Sources/*.x)
$(TWEAK_NAME)_FRAMEWORKS = UIKit Security
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -DTWEAK_VERSION=\"$(PACKAGE_VERSION)\"
$(TWEAK_NAME)_INJECT_DYLIBS = Tweaks/uYou/Library/MobileSubstrate/DynamicLibraries/uYou.dylib $(THEOS_OBJ_DIR)/libFLEX.dylib $(THEOS_OBJ_DIR)/iSponsorBlock.dylib $(THEOS_OBJ_DIR)/YouTubeDislikesReturn.dylib $(THEOS_OBJ_DIR)/YouPiP.dylib $(THEOS_OBJ_DIR)/YTABConfig.dylib $(THEOS_OBJ_DIR)/YTUHD.dylib $(THEOS_OBJ_DIR)/DontEatMyContent.dylib $(THEOS_OBJ_DIR)/YTVideoOverlay.dylib $(THEOS_OBJ_DIR)/YouMute.dylib $(THEOS_OBJ_DIR)/YouQuality.dylib $(THEOS_OBJ_DIR)/IAmYouTube.dylib $(THEOS_OBJ_DIR)/YTClassicVideoQuality.dylib $(THEOS_OBJ_DIR)/NoYTPremium.dylib $(THEOS_OBJ_DIR)/YoutubeSpeed.dylib
$(TWEAK_NAME)_EMBED_LIBRARIES = $(THEOS_OBJ_DIR)/libcolorpicker.dylib
$(TWEAK_NAME)_EMBED_BUNDLES = $(wildcard Bundles/*.bundle)
$(TWEAK_NAME)_EMBED_EXTENSIONS = $(wildcard Extensions/*.appex)

include $(THEOS)/makefiles/common.mk

_ALDERIS_XCODE_INSTALL_DIR = $(_THEOS_LOCAL_DATA_DIR)/$(THEOS_OBJ_DIR_NAME)/install_Alderis$(if $(_THEOS_FINAL_PACKAGE),.xcarchive/Products)
_ALDERIS_BUILD_PATH = $(_ALDERIS_XCODE_INSTALL_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Frameworks
export _THEOS_INTERNAL_LDFLAGS := -L$(THEOS_OBJ_DIR) -F$(_ALDERIS_BUILD_PATH) $(_THEOS_INTERNAL_LDFLAGS)
$(TWEAK_NAME)_EMBED_FRAMEWORKS += $(_ALDERIS_BUILD_PATH)/Alderis.framework

SUBPROJECTS += Tweaks/Alderis Tweaks/FLEXing/libflex Tweaks/iSponsorBlock Tweaks/Return-YouTube-Dislikes Tweaks/YouPiP Tweaks/YTABConfig Tweaks/YTUHD Tweaks/DontEatMyContent Tweaks/YTVideoOverlay Tweaks/YouMute Tweaks/YouQuality Tweaks/YTClassicVideoQuality Tweaks/NoYTPremium Tweaks/YTSpeed # Tweaks/IAmYouTube
include $(THEOS_MAKE_PATH)/aggregate.mk

include $(THEOS_MAKE_PATH)/tweak.mk

REMOVE_EXTENSIONS = 1
CODESIGN_IPA = 0

UYOU_PATH = Tweaks/uYou
UYOU_DEB_NAME = com.miro.uyou_$(UYOU_VERSION)_iphoneos-arm$(if $(filter $(THEOS_PACKAGE_SCHEME),rootless),64).deb
UYOU_DEB = $(UYOU_PATH)/$(UYOU_DEB_NAME)
UYOU_DYLIB = $(UYOU_PATH)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries/uYou.dylib
UYOU_FILTER = $(UYOU_PATH)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries/uYou.plist
UYOU_BUNDLE = $(UYOU_PATH)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Application\ Support/uYouBundle.bundle

internal-clean::
	@rm -rf $(UYOU_PATH)/*

before-all::
	@if [[ ! -f $(UYOU_DEB) ]]; then \
		$(PRINT_FORMAT_BLUE) "Downloading uYou"; \
	fi
before-all::
	@if [[ ! -f $(UYOU_DEB) ]]; then \
 		curl -s https://miro92.com/repo/debs/$(UYOU_DEB_NAME) -o $(UYOU_DEB); \
 	fi; \
	tar -xf $(UYOU_DEB) -C Tweaks/uYou; tar -xf Tweaks/uYou/data.tar* -C Tweaks/uYou; \
	if [[ ! -f $(UYOU_DYLIB) || ! -d $(UYOU_BUNDLE) ]]; then \
		$(PRINT_FORMAT_ERROR) "Failed to extract uYou"; exit 1; \
	fi;
before-package::
	@cp $(UYOU_DYLIB) $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries
	@cp $(UYOU_FILTER) $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries
	@cp -r $(UYOU_BUNDLE) $(THEOS_STAGING_DIR)/Library/Application\ Support/
	@mv $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Frameworks/Alderis.framework/Alderis $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Frameworks/Alderis.framework/Alderis-ios14
	@ln -s Alderis-ios14 $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Frameworks/Alderis.framework/Alderis
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PlugIns; cp -r $(THEOS_PROJECT_DIR)/Extensions/*.appex $(THEOS_STAGING_DIR)/Library/PlugIns
	@mkdir -p $(THEOS_STAGING_DIR)/Library/Application\ Support; cp -r Localizations/uYouPlus.bundle $(THEOS_STAGING_DIR)/Library/Application\ Support/