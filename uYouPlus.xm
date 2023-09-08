#import "Header.h"

// Tweak's bundle for Localizations support - @PoomSmart - https://github.com/PoomSmart/YouPiP/commit/aea2473f64c75d73cab713e1e2d5d0a77675024f
NSBundle *uYouPlusBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
 	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"uYouPlus" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/Application Support/uYouPlus.bundle")];
    });
    return bundle;
}
NSBundle *tweakBundle = uYouPlusBundle();

// Keychain fix
static NSString *accessGroupID() {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound)
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status != errSecSuccess)
            return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];

    return accessGroup;
}

//
static BOOL IsEnabled(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

//
# pragma mark - uYou's patches
// Workaround for qnblackcat/uYouPlus#10
%hook UIViewController
- (UITraitCollection *)traitCollection {
    @try {
        return %orig;
    } @catch(NSException *e) {
        return [UITraitCollection currentTraitCollection];
    }
}
%end

// Prevent uYou player bar from showing when not playing downloaded media
%hook PlayerManager
- (void)pause {
    if (isnan([self progress]))
        return;
    %orig;
}
%end

%hook YTAppDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    BOOL didFinishLaunching = %orig;

    if (IsEnabled(@"flex_enabled")) {
        [[%c(FLEXManager) performSelector:@selector(sharedManager)] performSelector:@selector(showExplorer)];
    }

    return didFinishLaunching;
}
- (void)appWillResignActive:(id)arg1 {
    %orig;
         if (IsEnabled(@"flex_enabled")) {
        [[%c(FLEXManager) performSelector:@selector(sharedManager)] performSelector:@selector(showExplorer)];
    }
}
%end

# pragma mark - YouTube's patches
%hook YTHotConfig
- (BOOL)disableAfmaIdfaCollection { return NO; }
%end

// Remove “Play next in queue” from the menu (@PoomSmart) - qnblackcat/uYouPlus#1138
%group gHidePlayNextInQueue
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    return renderer.icon.iconType == 251 ? NO : %orig;
}
%end
%end

// Reposition "Create" Tab to the Center in the Pivot Bar - qnblackcat/uYouPlus#107
/*
static void repositionCreateTab(YTIGuideResponse *response) {
    NSMutableArray<YTIGuideResponseSupportedRenderers *> *renderers = [response itemsArray];
    for (YTIGuideResponseSupportedRenderers *guideRenderers in renderers) {
        YTIPivotBarRenderer *pivotBarRenderer = [guideRenderers pivotBarRenderer];
        NSMutableArray<YTIPivotBarSupportedRenderers *> *items = [pivotBarRenderer itemsArray];
        NSUInteger createIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
            return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEuploads"];
        }];
        if (createIndex != NSNotFound) {
            YTIPivotBarSupportedRenderers *createTab = [items objectAtIndex:createIndex];
            [items removeObjectAtIndex:createIndex];
            NSUInteger centerIndex = items.count / 2;
            [items insertObject:createTab atIndex:centerIndex]; // Reposition the "Create" tab at the center
        }
    }
}
%hook YTGuideServiceCoordinator
- (void)handleResponse:(YTIGuideResponse *)response withCompletion:(id)completion {
    repositionCreateTab(response);
    %orig(response, completion);
}
- (void)handleResponse:(YTIGuideResponse *)response error:(id)error completion:(id)completion {
    repositionCreateTab(response);
    %orig(response, error, completion);
}
%end
*/

// Fix streched artwork in uYou's player view
%hook ArtworkImageView
- (id)imageView {
    UIImageView * imageView = %orig;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    // Make artwork a bit bigger
    UIView *artworkImageView = imageView.superview;
    if (artworkImageView != nil && !artworkImageView.translatesAutoresizingMaskIntoConstraints) {
        [artworkImageView.leftAnchor constraintEqualToAnchor:artworkImageView.superview.leftAnchor constant:16].active = YES;
        [artworkImageView.rightAnchor constraintEqualToAnchor:artworkImageView.superview.rightAnchor constant:-16].active = YES;
    }
    return imageView;
}
%end

# pragma mark - Tweaks
// IAmYouTube - https://github.com/PoomSmart/IAmYouTube/
%hook YTVersionUtils
+ (NSString *)appName { return YT_NAME; }
+ (NSString *)appID { return YT_BUNDLE_ID; }
%end

%hook GCKBUtils
+ (NSString *)appIdentifier { return YT_BUNDLE_ID; }
%end

%hook GPCDeviceInfo
+ (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook OGLBundle
+ (NSString *)shortAppName { return YT_NAME; }
%end

%hook GVROverlayView
+ (NSString *)appName { return YT_NAME; }
%end

%hook OGLPhenotypeFlagServiceImpl
- (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook APMAEU
+ (BOOL)isFAS { return YES; }
%end

%hook GULAppEnvironmentUtil
+ (BOOL)isFromAppStore { return YES; }
%end

%hook SSOConfiguration
- (id)initWithClientID:(id)clientID supportedAccountServices:(id)supportedAccountServices {
    self = %orig;
    [self setValue:YT_NAME forKey:@"_shortAppName"];
    [self setValue:YT_BUNDLE_ID forKey:@"_applicationIdentifier"];
    return self;
}
%end

%hook NSBundle
- (NSString *)bundleIdentifier {
    NSArray *address = [NSThread callStackReturnAddresses];
    Dl_info info = {0};
    if (dladdr((void *)[address[2] longLongValue], &info) == 0)
        return %orig;
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    if ([path hasPrefix:NSBundle.mainBundle.bundlePath])
        return YT_BUNDLE_ID;
    return %orig;
}
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ([key isEqualToString:@"CFBundleIdentifier"])
        return YT_BUNDLE_ID;
    if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"])
        return YT_NAME;
    return %orig;
}
// Fix Google Sign in by @PoomSmart and @level3tjg (qnblackcat/uYouPlus#684)
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *info = %orig.mutableCopy;
    NSString *altBundleIdentifier = info[@"ALTBundleIdentifier"];
    if (altBundleIdentifier) info[@"CFBundleIdentifier"] = altBundleIdentifier;
    return info;
}
%end

// Fix login for YouTube 18.13.2 and higher @BandarHL
%hook SSOKeychainHelper
+ (NSString *)accessGroup {
    return accessGroupID();
}
+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix login for YouTube 17.33.2 and higher - @BandarHL
// https://gist.github.com/BandarHL/492d50de46875f9ac7a056aad084ac10
%hook SSOKeychainCore
+ (NSString *)accessGroup {
    return accessGroupID();
}

+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix App Group Directory by move it to document directory
%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    if (groupIdentifier != nil) {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        return [documentsURL URLByAppendingPathComponent:@"AppGroup"];
    }
    return %orig(groupIdentifier);
}
%end

// YTMiniPlayerEnabler: https://github.com/level3tjg/YTMiniplayerEnabler/
%hook YTWatchMiniBarViewController
- (void)updateMiniBarPlayerStateFromRenderer {
    if (IsEnabled(@"ytMiniPlayer_enabled")) {}
    else { return %orig; }
}
%end

// YTNoHoverCards: https://github.com/level3tjg/YTNoHoverCards
%hook YTCreatorEndscreenView
- (void)setHidden:(BOOL)hidden {
    if (IsEnabled(@"hideHoverCards_enabled"))
        hidden = YES;
    %orig;
}
%end
 
// YTCastConfirm: https://github.com/JamieBerghmans/YTCastConfirm
%hook MDXPlaybackRouteButtonController
- (void)didPressButton:(id)arg1 {
    if (IsEnabled(@"castConfirm_enabled")) {
        NSBundle *tweakBundle = uYouPlusBundle();
        YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
            %orig;
        } actionTitle:LOC(@"MSG_YES")];
        alertView.title = LOC(@"CASTING");
        alertView.subtitle = LOC(@"MSG_ARE_YOU_SURE");
        [alertView show];
	} else {
    return %orig;
    }
}
%end

// %hook YTSectionListViewController
// - (void)loadWithModel:(YTISectionListRenderer *)model {
//     NSMutableArray <YTISectionListSupportedRenderers *> *contentsArray = model.contentsArray;
//     NSIndexSet *removeIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTISectionListSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
//         YTIItemSectionRenderer *sectionRenderer = renderers.itemSectionRenderer;
//         YTIItemSectionSupportedRenderers *firstObject = [sectionRenderer.contentsArray firstObject];
//         return firstObject.hasPromotedVideoRenderer || firstObject.hasCompactPromotedVideoRenderer || firstObject.hasPromotedVideoInlineMutedRenderer;
//     }];
//     [contentsArray removeObjectsAtIndexes:removeIndexes];
//     %orig;
// }
// %end

// YTClassicVideoQuality: https://github.com/PoomSmart/YTClassicVideoQuality
%hook YTIMediaQualitySettingsHotConfig // (works for YouTube 18.19.1-latest)

%new(B@:) - (BOOL)enableQuickMenuVideoQualitySettings { return NO; }

%end

// %hook YTVideoQualitySwitchControllerFactory
// - (id)videoQualitySwitchControllerWithParentResponder:(id)responder {
//     Class originalClass = %c(YTVideoQualitySwitchOriginalController);
//     return originalClass ? [[originalClass alloc] initWithParentResponder:responder] : %orig;
// }
// %end

// A/B flags
%hook YTColdConfig 
- (BOOL)respectDeviceCaptionSetting { return NO; } // YouRememberCaption: https://poomsmart.github.io/repo/depictions/youremembercaption.html
- (BOOL)isLandscapeEngagementPanelSwipeRightToDismissEnabled { return YES; } // Swipe right to dismiss the right panel in fullscreen mode
%end

// NOYTPremium - https://github.com/PoomSmart/NoYTPremium/
%hook YTCommerceEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTInterstitialPromoEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromosheetEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromoThrottleController
- (BOOL)canShowThrottledPromo { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)arg1 { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)arg1 { return NO; }
%end

%hook YTIShowFullscreenInterstitialCommand
- (BOOL)shouldThrottleInterstitial { return YES; }
%end

%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1 surveyParentResponder:(id)arg2 {}
%end

%hook YTIOfflineabilityFormat
%new
- (int)availabilityType { return 1; }
%new
- (BOOL)savedSettingShouldExpire { return NO; }
%end

// YTShortsProgress - https://github.com/PoomSmart/YTShortsProgress/
%hook YTReelPlayerViewController
- (BOOL)shouldEnablePlayerBar { return YES; }
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldEnablePlayerBar { return YES; }
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return YES; }
- (BOOL)mobileShortsTablnlinedExpandWatchOnDismiss { return YES; }
%end

%hook YTHotConfig
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return YES; }
%end

// YTNoTracking - https://github.com/arichorn/YTNoTracking/
%hook YTICompactLinkRenderer
- (BOOL)hasTrackingParams { return NO; }
%end

%hook YTIReelPlayerOverlayRenderer
- (BOOL)hasTrackingParams { return NO; }
%end

// YTNoPaidPromo: https://github.com/PoomSmart/YTNoPaidPromo
%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {
    if (IsEnabled(@"hidePaidPromotionCard_enabled")) {}
    else { return %orig; }
}
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    if ([[overlay overlayIdentifier] isEqualToString:@"player_overlay_paid_content"] && IsEnabled(@"hidePaidPromotionCard_enabled")) return;
    %orig;
}
%end

%hook YTInlineMutedPlaybackPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {
    if (IsEnabled(@"hidePaidPromotionCard_enabled")) {}
    else { return %orig; }
}
%end

// YTNoModernUI - @arichorn
%group gYTNoModernUI
%hook YTVersionUtils // YTNoModernUI Original Version
+ (NSString *)appVersion { return @"17.38.10"; }
%end

%hook YTSettingsCell // made by Dayanch96
- (void)setDetailText:(id)arg1 {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = infoDictionary[@"CFBundleShortVersionString"];

    if ([arg1 isEqualToString:@"17.38.10"]) {
        arg1 = appVersion;
    } %orig(arg1);
}
%end

%hook YTInlinePlayerBarContainerView // Red Progress Bar - YTNoModernUI
- (id)quietProgressBarColor {
    return [UIColor redColor];
}
%end

%hook YTSegmentableInlinePlayerBarView // Old Buffer Bar - YTNoModernUI
- (void)setBufferedProgressBarColor:(id)arg1 {
     [UIColor colorWithRed:0.65 green:0.65 blue:0.65 alpha:0.60];
}
%end

%hook YTQTMButton
- (BOOL)buttonModernizationEnabled { return NO; }
%end

%hook YTSearchBarView
- (BOOL)_roundedSearchBarEnabled { return NO; }
%end

%hook YTColdConfig
// Disable Modern Content - YTNoModernUI
- (BOOL)creatorClientConfigEnableStudioModernizedMdeThumbnailPickerForClient { return NO; }
- (BOOL)cxClientEnableModernizedActionSheet { return NO; }
- (BOOL)enableClientShortsSheetsModernization { return NO; }
- (BOOL)enableTimestampModernizationForNative { return NO; }
- (BOOL)mainAppCoreClientIosEnableModernOssPage { return NO; }
- (BOOL)modernizeElementsTextColor { return NO; }
- (BOOL)modernizeElementsBgColor { return NO; }
- (BOOL)modernizeCollectionLockups { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableEpUxUpdates { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableModernButtonsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableModernButtonsForNativeLongTail { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableModernTabsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigIosEnableSnackbarModernization { return NO; }
// Disable Rounded Content - YTNoModernUI
- (BOOL)iosDownloadsPageRoundedThumbs { return NO; }
- (BOOL)iosRoundedSearchBarSuggestZeroPadding { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedThumbnailsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedThumbnailsForNativeLongTail { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedTimestampForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedDialogForNative { return NO; }
// Disable Darker Dark Mode - YTNoModernUI
- (BOOL)enableDarkerDarkMode { return NO; }
- (BOOL)useDarkerPaletteBgColorForElements { return NO; }
- (BOOL)useDarkerPaletteTextColorForElements { return NO; }
- (BOOL)uiSystemsClientGlobalConfigUseDarkerPaletteTextColorForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigUseDarkerPaletteBgColorForNative { return NO; }
// Disable Ambient Mode - YTNoModernUI
- (BOOL)disableCinematicForLowPowerMode { return NO; }
- (BOOL)enableCinematicContainer { return NO; }
- (BOOL)enableCinematicContainerOnClient { return NO; }
- (BOOL)enableCinematicContainerOnTablet { return NO; }
- (BOOL)iosCinematicContainerClientImprovement { return NO; }
- (BOOL)iosEnableGhostCardInlineTitleCinematicContainerFix { return NO; }
- (BOOL)iosUseFineScrubberMosaicStoreForCinematic { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicPlaylists { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicPlaylistsPostMvp { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicTablets { return NO; }
// 16.42.3 Styled YouTube Channel Page Interface - YTNoModernUI
- (BOOL)channelsClientConfigIosChannelNavRestructuring { return NO; }
- (BOOL)channelsClientConfigIosMultiPartChannelHeader { return NO; }
// Disable Optional Content - YTNoModernUI
- (BOOL)elementsClientIosElementsEnableLayoutUpdateForIob { return NO; }
- (BOOL)supportElementsInMenuItemSupportedRenderers { return NO; }
- (BOOL)isNewRadioButtonStyleEnabled { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableButtonSentenceCasingForNative { return NO; }
%end

%hook YTHotConfig
- (BOOL)liveChatIosUseModernRotationDetectiom { return NO; } // Disable Modern Content (YTHotConfig)
- (BOOL)iosShouldRepositionChannelBar { return NO; }
- (BOOL)enableElementRendererOnChannelCreation { return NO; }
%end
%end

// Hide YouTube Logo
%group gHideYouTubeLogo
%hook YTHeaderLogoController
- (YTHeaderLogoController *)init {
    return NULL;
}
%end
%end

// Hide YouTube Heatwaves in Video Player (YouTube v17.19.2-latest) - @level3tjg - https://www.reddit.com/r/jailbreak/comments/v29yvk/
%group gHideHeatwaves
%hook YTInlinePlayerBarContainerView
- (BOOL)canShowHeatwave { return NO; }
%end
%end

# pragma mark - Hide Notification Button && SponsorBlock Button
%hook YTRightNavigationButtons
- (void)layoutSubviews {
    %orig;
    if (IsEnabled(@"hideNotificationButton_enabled")) {
        self.notificationButton.hidden = YES;
    }
    if (IsEnabled(@"hideSponsorBlockButton_enabled")) { 
        self.sponsorBlockButton.hidden = YES;
    }
}
%end

// YTReExplore: https://github.com/PoomSmart/YTReExplore/
%group gReExplore
static void replaceTab(YTIGuideResponse *response) {
    NSMutableArray <YTIGuideResponseSupportedRenderers *> *renderers = [response itemsArray];
    for (YTIGuideResponseSupportedRenderers *guideRenderers in renderers) {
        YTIPivotBarRenderer *pivotBarRenderer = [guideRenderers pivotBarRenderer];
        NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [pivotBarRenderer itemsArray];
        NSUInteger shortIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
            return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEshorts"];
        }];
        if (shortIndex != NSNotFound) {
            [items removeObjectAtIndex:shortIndex];
            NSUInteger exploreIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
                return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:[%c(YTIBrowseRequest) browseIDForExploreTab]];
            }];
            if (exploreIndex == NSNotFound) {
                YTIPivotBarSupportedRenderers *exploreTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForExploreTab] title:@"Explore" iconType:292];
                [items insertObject:exploreTab atIndex:1];
            }
            break;
        }
    }
}
%hook YTGuideServiceCoordinator
- (void)handleResponse:(YTIGuideResponse *)response withCompletion:(id)completion {
    replaceTab(response);
    %orig(response, completion);
}
- (void)handleResponse:(YTIGuideResponse *)response error:(id)error completion:(id)completion {
    replaceTab(response);
    %orig(response, error, completion);
}
%end
%end

// Hide Subscriptions Notification Badge
%group gHideSubscriptionsNotificationBadge
%hook YTPivotBarIndicatorView
- (void)didMoveToWindow {
    [self setHidden:YES];
    %orig();
}
%end
%end

// BigYTMiniPlayer: https://github.com/Galactic-Dev/BigYTMiniPlayer
%group Main
%hook YTWatchMiniBarView
- (void)setWatchMiniPlayerLayout:(int)arg1 {
    %orig(1);
}
- (int)watchMiniPlayerLayout {
    return 1;
}
- (void)layoutSubviews {
    %orig;
    self.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - self.frame.size.width), self.frame.origin.y, self.frame.size.width, self.frame.size.height);
}
%end

%hook YTMainAppVideoPlayerOverlayView
- (BOOL)isUserInteractionEnabled {
    if([[self _viewControllerForAncestor].parentViewController.parentViewController isKindOfClass:%c(YTWatchMiniBarViewController)]) {
        return NO;
    }
        return %orig;
}
%end
%end

// YTSpeed - https://github.com/Lyvendia/YTSpeed
%group gYTSpeed
%hook YTVarispeedSwitchController
- (id)init {
	id result = %orig;

	const int size = 17;
	float speeds[] = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 5.0};
	id varispeedSwitchControllerOptions[size];

	for (int i = 0; i < size; ++i) {
		id title = [NSString stringWithFormat:@"%.2fx", speeds[i]];
		varispeedSwitchControllerOptions[i] = [[%c(YTVarispeedSwitchControllerOption) alloc] initWithTitle:title rate:speeds[i]];
	}

	NSUInteger count = sizeof(varispeedSwitchControllerOptions) / sizeof(id);
	NSArray *varispeedArray = [NSArray arrayWithObjects:varispeedSwitchControllerOptions count:count];
	MSHookIvar<NSArray *>(self, "_options") = varispeedArray;

	return result;
}
%end

%hook MLHAMQueuePlayer
- (void)setRate:(float)rate {
    MSHookIvar<float>(self, "_rate") = rate;
	MSHookIvar<float>(self, "_preferredRate") = rate;

	id player = MSHookIvar<HAMPlayerInternal *>(self, "_player");
	[player setRate: rate];

	id stickySettings = MSHookIvar<MLPlayerStickySettings *>(self, "_stickySettings");
	[stickySettings setRate: rate];

	[self.playerEventCenter broadcastRateChange: rate];

	YTSingleVideoController *singleVideoController = self.delegate;
	[singleVideoController playerRateDidChange: rate];
}
%end 

%hook YTPlayerViewController
%property (nonatomic, assign) float playbackRate;
- (void)singleVideo:(id)video playbackRateDidChange:(float)rate {
	%orig;
}
%end
%end

# pragma mark - uYouPlus
// Video Player Options
// Skips content warning before playing *some videos - @PoomSmart
%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert { [self confirmAlertDidPressConfirm]; }
%end

// Portrait Fullscreen by Dayanch96
%group gPortraitFullscreen
%hook YTWatchViewController
- (unsigned long long)allowedFullScreenOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}
%end
%end

// Disable snap to chapter
%hook YTSegmentableInlinePlayerBarView
- (void)didMoveToWindow {
    %orig;
    if (IsEnabled(@"snapToChapter_enabled")) {
        self.enableSnapToChapter = NO;
    }
}
%end

// Disable Pinch to zoom
%hook YTColdConfig
- (BOOL)videoZoomFreeZoomEnabledGlobalConfig {
    return IsEnabled(@"pinchToZoom_enabled") ? NO : %orig;
}
%end

// YTStockVolumeHUD - https://github.com/lilacvibes/YTStockVolumeHUD
%group gStockVolumeHUD
%hook YTVolumeBarView
- (void)volumeChanged:(id)arg1 {
        %orig(nil);
}
%end

%hook UIApplication 
- (void)setSystemVolumeHUDEnabled:(BOOL)arg1 forAudioCategory:(id)arg2 {
        %orig(true, arg2);
}
%end
%end

// Disable Double Tap to Seek
%hook YTMainAppVideoPlayerOverlayViewController
- (BOOL)allowDoubleTapToSeekGestureRecognizer {
    return IsEnabled(@"disableDoubleTapToSkip_enabled") ? NO : %orig;
}
%end

// Video Controls Overlay Options
// Hide CC / Autoplay switch / Enable Share Button / Enable Save to Playlist Button
%hook YTMainAppControlsOverlayView
- (void)setClosedCaptionsOrSubtitlesButtonAvailable:(BOOL)arg1 { // hide CC button
    return IsEnabled(@"hideCC_enabled") ? %orig(NO) : %orig;
}
- (void)setAutoplaySwitchButtonRenderer:(id)arg1 { // hide Autoplay
    if (IsEnabled(@"hideAutoplaySwitch_enabled")) {}
    else { return %orig; }
}
- (void)setShareButtonAvailable:(BOOL)arg1 {
    if (IsEnabled(@"enableShareButton_enabled")) {
        %orig(YES);
    } else {
        %orig(NO);
    }
}
- (void)setAddToButtonAvailable:(BOOL)arg1 {
    if (IsEnabled(@"enableSaveToButton_enabled")) {
        %orig(YES);
    } else {
        %orig(NO);
    }
}
%end

// Hide HUD Messages
%hook YTHUDMessageView
- (id)initWithMessage:(id)arg1 dismissHandler:(id)arg2 {
    return IsEnabled(@"hideHUD_enabled") ? nil : %orig;
}
%end

// Hide Watermark
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark {
    if (IsEnabled(@"hideChannelWatermark_enabled")) {}
    else { return %orig; }
}
%end

// Hide Next & Previous button
%group gHidePreviousAndNextButton
%hook YTColdConfig
- (BOOL)removeNextPaddleForSingletonVideos { return YES; }
- (BOOL)removePreviousPaddleForSingletonVideos { return YES; }
%end

// %hook YTMainAppControlsOverlayView // this is only used for v16.42.3 (incompatible with YouTube v17.xx.x-newer)
// - (void)layoutSubviews { // hide Next & Previous legacy buttons
//     %orig;
//     if (IsEnabled(@"hidePreviousAndNextButton_enabled")) { 
//    	      MSHookIvar<YTMainAppControlsOverlayView *>(self, "_nextButton").hidden = YES;
//         MSHookIvar<YTMainAppControlsOverlayView *>(self, "_previousButton").hidden = YES;
//        MSHookIvar<YTTransportControlsButtonView *>(self, "_nextButtonView").hidden = YES;
//    MSHookIvar<YTTransportControlsButtonView *>(self, "_previousButtonView").hidden = YES;
//     }
// }
// %end
%end

// Hide Dark Overlay Background
%group gHideOverlayDarkBackground
%hook YTMainAppVideoPlayerOverlayView
- (void)setBackgroundVisible:(BOOL)arg1 isGradientBackground:(BOOL)arg2 {
    %orig(NO, arg2);
}
%end
%end

// Replace Next & Previous button with Fast forward & Rewind button
%group gReplacePreviousAndNextButton
%hook YTColdConfig
- (BOOL)replaceNextPaddleWithFastForwardButtonForSingletonVods { return YES; }
- (BOOL)replacePreviousPaddleWithRewindButtonForSingletonVods { return YES; }
%end
%end

// Hide Shadow Overlay Buttons (Play/Pause, Next, previous, Fast forward & Rewind buttons)
%group gHideVideoPlayerShadowOverlayButtons
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTTransportControlsButtonView *>(self, "_previousButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_nextButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekBackwardAccessibilityButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekForwardAccessibilityButtonView").backgroundColor = nil;
    MSHookIvar<YTPlaybackButton *>(self, "_playPauseButton").backgroundColor = nil;
}
%end
%end

// Bring back the Red Progress Bar and Gray Buffer Progress
%group gRedProgressBar
%hook YTInlinePlayerBarContainerView
- (id)quietProgressBarColor {
    return [UIColor redColor];
}
%end

%hook YTSegmentableInlinePlayerBarView
- (void)setBufferedProgressBarColor:(id)arg1 {
     [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.90];
}
%end
%end

// Disable the right panel in fullscreen mode
%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled {
    return IsEnabled(@"hideRightPanel_enabled") ? NO : %orig;
}
%end

// Shorts Controls Overlay Options
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    if ((IsEnabled(@"hideBuySuperThanks_enabled")) && ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.suggested_action"])) { 
        self.hidden = YES; 
    }
}
%end

%hook YTReelWatchRootViewController
- (void)setPausedStateCarouselView {
    if (IsEnabled(@"hideSubcriptions_enabled")) {}
    else { return %orig; }
}
%end

%hook YTShortsStartupCoordinator
- (id)evaluateResumeToShorts { 
    return IsEnabled(@"disableResumeToShorts") ? nil : %orig;
}
%end

// App Settings Overlay Options
%group gDisableDontEatMyContentSection
%hook YTSettingsSectionItemManager
- (void)updateDEMCSectionWithEntry:(id)arg1 {} // DontEatMyContent
%end
%end

%group gDisableReturnYouTubeDislikeSection
%hook YTSettingsSectionItemManager
- (void)updateRYDSectionWithEntry:(id)arg1 {} // Return YouTube Dislike
%end
%end

%group gDisableYouPiPSection
%hook YTSettingsSectionItemManager
- (void)updateYouPiPSectionWithEntry:(id)arg1 {} // YouPiP
%end
%end

%group gDisableTryNewFeaturesSection
%hook YTSettingsSectionItemManager
- (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg1 {} // Try New Features
%end
%end

%group gDisableAutoplaySection
%hook YTSettingsSectionItemManager
- (void)updateAutoplaySectionWithEntry:(id)arg1 {} // Autoplay
%end
%end

%group gDisableNotificationsSection
%hook YTSettingsSectionItemManager
- (void)updateNotificationSectionWithEntry:(id)arg1 {} // Notifications
%end
%end

%group gDisableHistoryAndPrivacySection
%hook YTSettingsSectionItemManager
- (void)updateHistoryAndPrivacySectionWithEntry:(id)arg1 {} // History And Privacy
- (void)updateHistorySectionWithEntry:(id)arg1 {} // History
- (void)updatePrivacySectionWithEntry:(id)arg1 {} // Privacy
%end
%end

%group gDisableLiveChatSection
%hook YTSettingsSectionItemManager
- (void)updateLiveChatSectionWithEntry:(id)arg1 {} // Live chat
%end
%end

// Miscellaneous
// Disable hints - https://github.com/LillieH001/YouTube-Reborn/blob/v4/
%group gDisableHints
%hook YTSettings
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%hook YTUserDefaults
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%end

// Stick Navigation bar
%group gStickNavigationBar
%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return YES; } 
%end
%end

// Hide the Chip Bar (Upper Bar) in Home feed
%group gHideChipBar
%hook YTMySubsFilterHeaderView 
- (void)setChipFilterView:(id)arg1 {}
%end

%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(id)arg1 {}
%end

%hook YTHeaderContentComboView
- (void)setFeedHeaderScrollMode:(int)arg1 { %orig(0); }
%end

// Hide the chip bar under the video player?
// %hook YTChipCloudCell // 
// - (void)didMoveToWindow {
//     %orig;
//     self.hidden = YES;
// }
// %end
%end

%group giPhoneLayout
%hook UIDevice
- (long long)userInterfaceIdiom {
    return NO;
} 
%end
%hook UIStatusBarStyleAttributes
- (long long)idiom {
    return YES;
} 
%end
%hook UIKBTree
- (long long)nativeIdiom {
    return NO;
} 
%end
%hook UIKBRenderer
- (long long)assetIdiom {
    return NO;
} 
%end
%end

// YT startup animation
%hook YTColdConfig
- (BOOL)mainAppCoreClientIosEnableStartupAnimation {
    return IsEnabled(@"ytStartupAnimation_enabled") ? YES : NO;
}
%end

# pragma mark - ctor
%ctor {
    // Load uYou first so its functions are available for hooks.
    // dlopen([[NSString stringWithFormat:@"%@/Frameworks/uYou.dylib", [[NSBundle mainBundle] bundlePath]] UTF8String], RTLD_LAZY);

    %init;
    if (IsEnabled(@"reExplore_enabled")) {
        %init(gReExplore);
    }
    if (IsEnabled(@"bigYTMiniPlayer_enabled") && (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad)) {
        %init(Main);
    }
    if (IsEnabled(@"hideSubscriptionsNotificationBadge_enabled")) {
        %init(gHideSubscriptionsNotificationBadge);
    }
    if (IsEnabled(@"hidePreviousAndNextButton_enabled")) {
        %init(gHidePreviousAndNextButton);
    }
    if (IsEnabled(@"replacePreviousAndNextButton_enabled")) {
        %init(gReplacePreviousAndNextButton);
    }
    if (IsEnabled(@"hideOverlayDarkBackground_enabled")) {
        %init(gHideOverlayDarkBackground);
    }
    if (IsEnabled(@"hideVideoPlayerShadowOverlayButtons_enabled")) {
        %init(gHideVideoPlayerShadowOverlayButtons);
    }
    if (IsEnabled(@"hidePlayNextInQueue_enabled")) {
        %init(gHidePlayNextInQueue);
    }
    if (IsEnabled(@"disableHints_enabled")) {
        %init(gDisableHints);
    }
    if (IsEnabled(@"redProgressBar_enabled")) {
        %init(gRedProgressBar);
    }
    if (IsEnabled(@"stickNavigationBar_enabled")) {
        %init(gStickNavigationBar);
    }
    if (IsEnabled(@"hideChipBar_enabled")) {
        %init(gHideChipBar);
    }
    if (IsEnabled(@"ytSpeed_enabled")) {
        %init(gYTSpeed);
    }
    if (IsEnabled(@"portraitFullscreen_enabled")) {
        %init(gPortraitFullscreen);
    }
    if (IsEnabled(@"iPhoneLayout_enabled") && (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)) {
        %init(giPhoneLayout);
    }
    if (IsEnabled(@"stockVolumeHUD_enabled")) {
        %init(gStockVolumeHUD);
    }
    if (IsEnabled(@"hideYouTubeLogo_enabled")) {
        %init(gHideYouTubeLogo);
    }
    if (IsEnabled(@"hideHeatwaves_enabled")) {
        %init(gHideHeatwaves);
    }
    if (IsEnabled(@"ytNoModernUI_enabled")) {
        %init(gYTNoModernUI);
    }
    if (IsEnabled(@"disableDontEatMyContentSection_enabled")) {
        %init(gDisableDontEatMyContentSection);
    }
    if (IsEnabled(@"disableReturnYouTubeDislikeSection_enabled")) {
        %init(gDisableReturnYouTubeDislikeSection);
    }
    if (IsEnabled(@"disableYouPiPSection_enabled")) {
        %init(gDisableYouPiPSection);
    }
    if (IsEnabled(@"disableTryNewFeaturesSection_enabled")) {
        %init(gDisableTryNewFeaturesSection);
    }
    if (IsEnabled(@"disableAutoplaySection_enabled")) {
        %init(gDisableAutoplaySection);
    }
    if (IsEnabled(@"disableNotificationsSection_enabled")) {
        %init(gDisableNotificationsSection);
    }
    if (IsEnabled(@"disableHistoryAndPrivacySection_enabled")) {
        %init(gDisableHistoryAndPrivacySection);
    }
    if (IsEnabled(@"disableLiveChatSection_enabled")) {
        %init(gDisableLiveChatSection);
    }

    // Disable updates
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"automaticallyCheckForUpdates"];

    // Don't show uYou's welcome screen cuz it's currently broken (fix #1147)
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"showedWelcomeVC"];

    // Disable broken options of uYou
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"disableAgeRestriction"]; // Disable Age Restriction Disabled - Reason is the same as above.

    // Change the default value of some options
    NSArray *allKeys = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys];
    if (![allKeys containsObject:@"relatedVideosAtTheEndOfYTVideos"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"relatedVideosAtTheEndOfYTVideos"]; 
    }
    if (![allKeys containsObject:@"shortsProgressBar"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shortsProgressBar"]; 
    }
    if (![allKeys containsObject:@"RYD-ENABLED"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"RYD-ENABLED"]; 
    }
    if (![allKeys containsObject:@"YouPiPEnabled"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"YouPiPEnabled"]; 
    }
}
