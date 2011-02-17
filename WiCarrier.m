#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

#include <ifaddrs.h>
#include <arpa/inet.h>

CHDeclareClass(SBStatusBarDataManager);
CHDeclareClass(UIStatusBarServiceItemView);
CHDeclareClass(SBStatusBarCarrierView);
CHDeclareClass(SBStatusBarOperatorNameView);
CHDeclareClass(SBWiFiManager);

#define IS_IOS_42_OR_LATER() (kCFCoreFoundationVersionNumber >= 550.52)

static SBStatusBarCarrierView *carrierView;
static SBStatusBarDataManager *dataManager;

static SCNetworkReachabilityRef reachability;
static BOOL useHost;

typedef struct __WiFiNetwork *WiFiNetworkRef;
extern BOOL WiFiNetworkIsWPA(WiFiNetworkRef network);
extern BOOL WiFiNetworkIsEAP(WiFiNetworkRef network);

struct StatusBarData
{
    char itemIsEnabled[20];
    char timeString[64];                // TimeItem
    int gsmSignalStrengthRaw;           // SignalStrength
    int gsmSignalStrengthBars;          // SignalStrength
    char serviceString[100];            // Service
    char serviceImageBlack[100];        // Service
    char serviceImageSilver[100];       // Service
    char operatorDirectory[1024];       // Service
    unsigned int serviceContentType;    // Service
    int wifiSignalStrengthRaw;          // DataNetwork
    int wifiSignalStrengthBars;         // DataNetwork
    unsigned int dataNetworkType;       // DataNetwork
    int batteryCapacity;                // Battery, BatteryPercent
    unsigned int batteryState;          // Battery
    int bluetoothBatteryCapacity;       // BluetoothBattery
    int thermalColor;                   // ThermalColor
    bool slowActivity;                  // Activity
    char activityDisplayId[256];
    bool bluetoothConnected;            // Bluetooth
    bool displayRawGSMSignal;           // SignalStrength
    bool displayRawWifiSignal;          // DataNetwork
};

struct StatusBarData42 {
	char itemIsEnabled[22];
	char timeString[64];
	int gsmSignalStrengthRaw;
	int gsmSignalStrengthBars;
	char serviceString[100];
	char serviceImageBlack[100];
	char serviceImageSilver[100];
	char operatorDirectory[1024];
	unsigned int serviceContentType;
	int wifiSignalStrengthRaw;
	int wifiSignalStrengthBars;
	unsigned int dataNetworkType;
	int batteryCapacity;
	unsigned int batteryState;
	char notChargingString[150];
	int bluetoothBatteryCapacity;
	int thermalColor;
	bool slowActivity;
	char activityDisplayId[256];
	bool bluetoothConnected;
	char recordingAppString[100];
	bool displayRawGSMSignal;
	bool displayRawWifiSignal;
};

@interface SBStatusBarDataManager : NSObject {
	struct StatusBarData _data;
	NSInteger _actions;
	BOOL _itemIsEnabled[20];
	BOOL _itemIsCloaked[20];
	NSInteger _updateBlockDepth;
	BOOL _dataChangedSinceLastPost;
	NSDateFormatter *_timeItemDateFormatter;
	NSTimer *_timeItemTimer;
	NSString *_timeItemTimeString;
	BOOL _cellRadio;
	BOOL _registered;
	BOOL _simError;
	BOOL _simulateInCallStatusBar;
	NSString *_serviceString;
	NSString *_serviceImageBlack;
	NSString *_serviceImageSilver;
	NSString *_operatorDirectory;
	BOOL _showsActivityIndicatorOnHomeScreen;
	NSInteger _thermalColor;
}
+ (id)sharedDataManager;
- (id)init;
- (void)dealloc;
- (void)beginUpdateBlock;
- (void)endUpdateBlock;
- (void)setStatusBarItem:(NSInteger)item enabled:(BOOL)enabled;
- (void)setStatusBarItem:(NSInteger)item cloaked:(BOOL)cloaked;
- (void)updateStatusBarItem:(NSInteger)item;
- (void)sendStatusBarActions:(NSInteger)actions;
- (void)enableLock:(BOOL)lock time:(BOOL)time;
- (void)setShowsActivityIndicatorOnHomeScreen:(BOOL)screen;
- (void)setTelephonyAndBluetoothItemsCloaked:(BOOL)cloaked;
- (void)setAllItemsExceptBatteryCloaked:(BOOL)cloaked;
- (void)setThermalColor:(NSInteger)color;
- (void)_initializeData;
- (void)_dataChanged;
- (void)_postData;
- (void)_updateTimeString;
- (void)_updateTimeItem;
- (void)_updateAirplaneMode;
- (void)_updateSignalStrengthItem;
- (void)_updateServiceItem;
- (void)_updateDataNetworkItem;
- (void)_updateBatteryItem;
- (void)_updateBatteryPercentItem;
- (void)_updateBluetoothItem;
- (void)_updateBluetoothBatteryItem;
- (void)_updateTTYItem;
- (void)_updateVPNItem;
- (void)_updateCallForwardingItem;
- (void)_updateActivityItem;
- (void)_updatePlayItem;
- (void)_updateLocationItem;
- (void)_updateRotationLockItem;
- (void)_updateThermalColorItem;
- (void)_registerForNotifications;
- (void)_unregisterForNotifications;
- (void)_significantTimeOrLocaleChange;
- (void)_didWakeFromSleep;
- (void)_batteryStatusChange;
- (void)_operatorChange;
- (void)_signalStrengthChange;
- (void)_ttyChange;
- (void)_callForwardingChange;
- (void)_vpnChange;
- (void)_dataNetworkChange;
- (void)_airplaneModeChange;
- (void)_bluetoothChange;
- (void)_bluetoothBatteryChange;
- (void)_locationStatusChange;
- (void)_rotationLockChange;
- (void)_configureTimeItemDateFormatter;
- (void)_stopTimeItemTimer;
- (void)_restartTimeItemTimer;
- (void)_updateTelephonyState;
- (void)toggleSimulatesInCallStatusBar;
- (NSString *)_displayStringForSIMStatus:(id)simstatus;
- (NSString *)_displayStringForRegistrationStatus:(int)registrationStatus;
- (void)_getBlackImageName:(NSString **)blackImageName silverImageName:(NSString **)silverImageName directory:(NSString **)directory forFakeCarrier:(NSString *)fakeCarrier;
- (BOOL)_getBlackImageName:(NSString **)blackImageName silverImageName:(NSString **)silverImageName directory:(NSString **)directory forOperator:(NSString *)anOperator statusBarCarrierName:(NSString **)carrierName;
@end

@class UIStatusBarItem;

@interface UIStatusBarItemView : UIView
@end

@interface UIStatusBarServiceItemView : UIStatusBarItemView
@end


static inline void ForceUpdate()
{
	[dataManager beginUpdateBlock];
	[dataManager _updateServiceItem];
	[dataManager endUpdateBlock];
	[carrierView operatorNameChanged];
}

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	ForceUpdate();
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

static inline NSString *GetNewNetworkName()
{
	// Load Reachability
	if (reachability == NULL) {
		reachability = SCNetworkReachabilityCreateWithName(NULL, [@"www.apple.com" UTF8String]);
		if (reachability) {
			SCNetworkReachabilityContext context = { 0, NULL, NULL, NULL, NULL };
			SCNetworkReachabilitySetCallback(reachability, ReachabilityCallback, &context);
			SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		}
	}
	if (useHost)
		return GetIPAddress();
	// Load manager
	SBWiFiManager *manager = [CHClass(SBWiFiManager) sharedInstance];
	NSString *networkName = [manager currentNetworkName];
	// Get network details
	WiFiNetworkRef currentNetwork = CHIvar(manager, _currentNetwork, WiFiNetworkRef);
	if (currentNetwork != NULL) {
		if (!WiFiNetworkIsWPA(currentNetwork) && !WiFiNetworkIsEAP(currentNetwork)) {
			const unichar secureChars[] = { 0xE145, 0x20 };
			networkName = [[NSString stringWithCharacters:secureChars length:2] stringByAppendingString:networkName];
		}
	}
	return networkName;
}

// 4.x

CHOptimizedMethod(2, self, void, SBStatusBarDataManager, setStatusBarItem, NSInteger, item, enabled, BOOL, enabled)
{
	CHSuper(2, SBStatusBarDataManager, setStatusBarItem, item, enabled, enabled || (item == 4));
}

CHOptimizedMethod(0, self, void, SBStatusBarDataManager, _updateServiceItem)
{
	if (dataManager != self) {
		[dataManager release];
		dataManager = [self retain];
	}
	CHSuper(0, SBStatusBarDataManager, _updateServiceItem);
	if (IS_IOS_42_OR_LATER()) {
		struct StatusBarData42 *data = CHIvarRef(self, _data, struct StatusBarData42);
		if (data) {
			NSString *text = GetNewNetworkName();
			if (text) {
				[text getCString:&data->serviceString[0] maxLength:100 encoding:NSUTF8StringEncoding];
				data->serviceImageBlack[0] = 0;
				data->serviceImageSilver[0] = 0;
				data->operatorDirectory[0] = 0;
				NSString **serviceStringRef = CHIvarRef(self, _serviceString, NSString *);
				if (serviceStringRef) {
					[*serviceStringRef release];
					*serviceStringRef = nil;
				}
				[self _dataChanged];
			}
		}
	} else {
		struct StatusBarData *data = CHIvarRef(self, _data, struct StatusBarData);
		if (data) {
			NSString *text = GetNewNetworkName();
			if (text) {
				[text getCString:&data->serviceString[0] maxLength:100 encoding:NSUTF8StringEncoding];
				data->serviceImageBlack[0] = 0;
				data->serviceImageSilver[0] = 0;
				data->operatorDirectory[0] = 0;
				NSString **serviceStringRef = CHIvarRef(self, _serviceString, NSString *);
				if (serviceStringRef) {
					[*serviceStringRef release];
					*serviceStringRef = nil;
				}
				[self _dataChanged];
			}
		}
	}
}

CHOptimizedMethod(2, super, id, UIStatusBarServiceItemView, initWithItem, UIStatusBarItem *, item, style, NSInteger, style)
{
	if ((self = CHSuper(2, UIStatusBarServiceItemView, initWithItem, item, style, style))) {
		self.userInteractionEnabled = YES;
	}
	return self;
}

CHOptimizedMethod(2, super, void, UIStatusBarServiceItemView, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	useHost = !useHost;
	ForceUpdate();
	CHSuper(2, UIStatusBarServiceItemView, touchesEnded, touches, withEvent, event);
}

// 3.x

CHOptimizedMethod(1, self, void, SBStatusBarCarrierView, setOperatorName, NSString *, name)
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
	NSString *networkName = GetNewNetworkName();
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


CHOptimizedMethod(1, self, id, SBStatusBarCarrierView, operatorIconForName, NSString *, name)
{
	return nil;
}

CHOptimizedMethod(1, self, void, SBStatusBarCarrierView, startOperatorNameLooping, id, looping)
{
}

CHOptimizedMethod(2, super, void, SBStatusBarCarrierView, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	useHost = !useHost;
	ForceUpdate();
	CHSuper(2, SBStatusBarCarrierView, touchesEnded, touches, withEvent, event);
}

CHOptimizedMethod(2, self, void, SBStatusBarOperatorNameView, setOperatorName, NSString *, name, fullSize, BOOL, fullSize)
{
	CHSuper(2, SBStatusBarOperatorNameView, setOperatorName, name, fullSize, YES);
}

CHOptimizedMethod(0, self, void, SBWiFiManager, _updateCurrentNetwork)
{
	CHSuper(0, SBWiFiManager, _updateCurrentNetwork);
	ForceUpdate();
}

CHConstructor
{
	if (CHLoadLateClass(SBStatusBarDataManager)) {
		CHHook(2, SBStatusBarDataManager, setStatusBarItem, enabled);
		CHHook(0, SBStatusBarDataManager, _updateServiceItem);
		CHLoadLateClass(UIStatusBarServiceItemView);
		CHHook(2, UIStatusBarServiceItemView, initWithItem, style);
		CHHook(2, UIStatusBarServiceItemView, touchesEnded, withEvent);
	} else {
		CHLoadLateClass(SBStatusBarCarrierView);
		CHHook(1, SBStatusBarCarrierView, setOperatorName);
		CHHook(1, SBStatusBarCarrierView, operatorIconForName);
		CHHook(1, SBStatusBarCarrierView, startOperatorNameLooping);
		CHHook(2, SBStatusBarCarrierView, touchesEnded, withEvent);	
		CHLoadLateClass(SBStatusBarOperatorNameView);
		CHHook(2, SBStatusBarOperatorNameView, setOperatorName, fullSize);
	}
	
	CHLoadLateClass(SBWiFiManager);
	CHHook(0, SBWiFiManager, _updateCurrentNetwork);
}
