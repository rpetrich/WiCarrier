#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

#include <ifaddrs.h>
#include <arpa/inet.h>

CHDeclareClass(SBStatusBarCarrierView);
CHDeclareClass(SBStatusBarOperatorNameView);
CHDeclareClass(SBWiFiManager);
CHDeclareClass(SpringBoard);

CHDeclareClass(SBAwayController);
CHDeclareClass(SBWiFiAlertItem);
CHDeclareClass(SBAlertItemsController);

static SBStatusBarCarrierView *carrierView;

static SCNetworkReachabilityRef reachability;
static BOOL useHost;

typedef struct __WiFiManagerClient *WiFiManagerClientRef;
extern CFArrayRef WiFiManagerClientCopyNetworks(WiFiManagerClientRef managerClient);

typedef struct __WiFiNetwork *WiFiNetworkRef;
extern BOOL WiFiNetworkIsWPA(WiFiNetworkRef network);
extern BOOL WiFiNetworkIsEAP(WiFiNetworkRef network);

extern CFArrayRef _WiFiCreateRecordsFromNetworks(CFArrayRef networks);

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	[carrierView operatorNameChanged];
}

static inline NSString *GetIPAddress()
{
	NSString *result = nil;
	struct ifaddrs *interfaces;
	char str[INET_ADDRSTRLEN];
	if (getifaddrs(&interfaces))
		return nil;
	struct ifaddrs *test_addr = interfaces;
	while (test_addr) {
		if(test_addr->ifa_addr->sa_family == AF_INET) {
			if (strcmp(test_addr->ifa_name, "en0") == 0) {
				inet_ntop(AF_INET, &((struct sockaddr_in *)test_addr->ifa_addr)->sin_addr, str, INET_ADDRSTRLEN);
				result = [NSString stringWithUTF8String:str];
				break;
			}
		}
		test_addr = test_addr->ifa_next;
	}
	freeifaddrs(interfaces);
	return result;
}

CHMethod(1, void, SBStatusBarCarrierView, setOperatorName, NSString *, name)
{
	// Save view for later
	if (carrierView != self) {
		[carrierView release];
		carrierView = [self retain];
	}
	// Load Reachability
	if (reachability == NULL) {
		reachability = SCNetworkReachabilityCreateWithName(NULL, [@"www.apple.com" UTF8String]);
		if (reachability) {
			SCNetworkReachabilityContext context = { 0, NULL, NULL, NULL, NULL };
			SCNetworkReachabilitySetCallback(reachability, ReachabilityCallback, &context);
			SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		}
	}
	NSString *networkName;
	if (useHost) {
		networkName = GetIPAddress();
	} else {
		// Load manager
		SBWiFiManager *manager = [CHClass(SBWiFiManager) sharedInstance];
		networkName = [manager currentNetworkName];
		// Get network details
		WiFiNetworkRef currentNetwork = CHIvar(manager, _currentNetwork, WiFiNetworkRef);
		if (currentNetwork != NULL) {
			if (!WiFiNetworkIsWPA(currentNetwork) && !WiFiNetworkIsEAP(currentNetwork)) {
				const unichar secureChars[] = { 0xE145, 0x20 };
				networkName = [[NSString stringWithCharacters:secureChars length:2] stringByAppendingString:networkName];
			}
		}
	}
	// Use Carrier name if no network is present
	if ([networkName length] == 0)
		networkName = name;
	// Perform Original Behaviour
	CHSuper(1, SBStatusBarCarrierView, setOperatorName, networkName);
	// Set Frame
	CGRect frame = [self frame];
	frame.size.width = [networkName sizeWithFont:[self textFont] constrainedToSize:(CGSize){ 100.0f, frame.size.height} lineBreakMode:UILineBreakModeClip].width;
	[self setFrame:frame];
	// Set Operator Name Frame
	SBStatusBarOperatorNameView *_operatorNameView = CHIvar(self, _operatorNameView, SBStatusBarOperatorNameView *);
	frame.origin = [_operatorNameView frame].origin;
	[_operatorNameView setFrame:frame];
	// Reflow statusbar
	SBStatusBarContentsView *_contentsView = CHIvar(self, _contentsView, SBStatusBarContentsView *);
	[_contentsView reflowContentViewsNow];
}


CHMethod(1, id, SBStatusBarCarrierView, operatorIconForName, NSString *, name)
{
	return nil;
}

CHMethod(1, void, SBStatusBarCarrierView, startOperatorNameLooping, id, looping)
{
}

CFRunLoopTimerRef touchTimer;

void touchTimerCallback()
{
	if (touchTimer) {
		CFRelease(touchTimer);
		touchTimer = NULL;
	}
	if ([[CHClass(SBAwayController) sharedAwayController] isLocked])
		return;
	// Create Alert
	SBWiFiAlertItem *alert = [[CHAlloc(SBWiFiAlertItem) init] autorelease];
	[CHSharedInstance(SBAlertItemsController) activateAlertItem:alert];
	SBWiFiManager *wiFiManager = CHSharedInstance(SBWiFiManager);
	if (wiFiManager) {
		// Load list of saved networks
		CFArrayRef networks = WiFiManagerClientCopyNetworks(CHIvar(wiFiManager, _manager, WiFiManagerClientRef));
		CFArrayRef records = _WiFiCreateRecordsFromNetworks(networks);
		CFRelease(networks);
		[alert setNetworks:(NSArray *)records];
		CFRelease(records);
		// Scan for list of visible networks
		[wiFiManager setDelegate:[UIApplication sharedApplication]];
		[wiFiManager scan];
	}
}

CHMethod(2, void, SBStatusBarCarrierView, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	if (!touchTimer) {
		touchTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, [NSDate timeIntervalSinceReferenceDate] + 0.5f, 0.0f, 0, 0, (CFRunLoopTimerCallBack)touchTimerCallback, NULL);
		CFRunLoopAddTimer(CFRunLoopGetCurrent(), touchTimer, kCFRunLoopCommonModes);
	}
	CHSuper(2, SBStatusBarCarrierView, touchesBegan, touches, withEvent, event);
}

CHMethod(2, void, SBStatusBarCarrierView, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	if (touchTimer) {
		CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), touchTimer, kCFRunLoopCommonModes);
		CFRelease(touchTimer);
		touchTimer = NULL;
		useHost = !useHost;
		[carrierView operatorNameChanged];
	}
	CHSuper(2, SBStatusBarCarrierView, touchesEnded, touches, withEvent, event);
}

CHMethod(2, void, SBStatusBarOperatorNameView, setOperatorName, NSString *, name, fullSize, BOOL, fullSize)
{
	CHSuper(2, SBStatusBarOperatorNameView, setOperatorName, name, fullSize, YES);
}

CHMethod(0, void, SBWiFiManager, _updateCurrentNetwork)
{
	CHSuper(0, SBWiFiManager, _updateCurrentNetwork);
	[carrierView operatorNameChanged];
}

CHMethod(2, void, SpringBoard, wifiManager, SBWiFiManager *, wifiManager, scanCompleted, id, scan)
{
	id alert = [CHSharedInstance(SBAlertItemsController) alertItemOfClass:CHClass(SBWiFiAlertItem)];
	if (alert)
		[alert setNetworks:scan];
	CHSuper(2, SpringBoard, wifiManager, wifiManager, scanCompleted, scan);
}

CHConstructor
{
	CHLoadLateClass(SBStatusBarCarrierView);
	CHHook(1, SBStatusBarCarrierView, setOperatorName);
	CHHook(1, SBStatusBarCarrierView, operatorIconForName);
	CHHook(1, SBStatusBarCarrierView, startOperatorNameLooping);
	CHHook(2, SBStatusBarCarrierView, touchesBegan, withEvent);
	CHHook(2, SBStatusBarCarrierView, touchesEnded, withEvent);
	
	CHLoadLateClass(SBStatusBarOperatorNameView);
	CHHook(2, SBStatusBarOperatorNameView, setOperatorName, fullSize);
	
	CHLoadLateClass(SBWiFiManager);
	CHHook(0, SBWiFiManager, _updateCurrentNetwork);
	
	CHLoadLateClass(SpringBoard);
	CHHook(2, SpringBoard, wifiManager, scanCompleted);
	
	CHLoadLateClass(SBAwayController);
	CHLoadLateClass(SBWiFiAlertItem);
	CHLoadLateClass(SBAlertItemsController);
}
