ifeq ($(shell [ -f ./framework/makefiles/common.mk ] && echo 1 || echo 0),0)
all clean package install::
	git submodule update --init
	./framework/git-submodule-recur.sh init
	$(MAKE) $(MAKEFLAGS) MAKELEVEL=0 $@
else

TWEAK_NAME = WiCarrier
WiCarrier_OBJC_FILES = WiCarrier.m
WiCarrier_FRAMEWORKS = UIKit SystemConfiguration
WiCarrier_PRIVATE_FRAMEWORKS = MobileWiFi

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

endif
