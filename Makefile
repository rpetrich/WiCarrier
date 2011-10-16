ifeq ($(shell [ -f ./framework/makefiles/common.mk ] && echo 1 || echo 0),0)
all clean package install::
	git submodule update --init
	./framework/git-submodule-recur.sh init
	$(MAKE) $(MAKEFLAGS) MAKELEVEL=0 $@
else

TWEAK_NAME = WiCarrier
WiCarrier_OBJC_FILES = WiCarrier.m
WiCarrier_FRAMEWORKS = UIKit
WiCarrier_PRIVATE_FRAMEWORKS = SystemConfiguration
WiCarrier_LDFLAGS = -weak_framework MobileWiFi

TARGET_IPHONEOS_DEPLOYMENT_VERSION = 3.0

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

endif
