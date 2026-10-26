//
//  ALMobileFuseMediationAdapter.m
//  AppLovin MAX Mediation Adapter for MobileFuse
//

#import "ALMobileFuseMediationAdapter.h"
#import <MobileFuseSDK/MobileFuseSettings.h>

// Adapter version number is SDK_VERSION.ADAPTER_REVISION (e.g 1.0.0.000)
#define ADAPTER_REVISION (@"0") // Increment this if we need to release a patched adapter for a particular SDK version (and set to 0 for next new SDK version)
#define ADAPTER_NAME @"applovin_custom"

@interface ALMobileFuseMediationAdapterInitializationDelegate : NSObject <IMFInitializationCallbackReceiver>
@property (nonatomic, weak) ALMobileFuseMediationAdapter *parentAdapter;
@property (nonatomic, copy, nullable) void(^completionBlock)(MAAdapterInitializationStatus, NSString *_Nullable);
- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler;
@end

@interface ALMobileFuseMediationAdapterAdViewDelegate : NSObject<IMFAdCallbackReceiver>
@property (nonatomic, weak, readwrite) ALMobileFuseMediationAdapter *parentAdapter;
@property (nonatomic, strong, readwrite) id<MAAdViewAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate;
@end

@interface ALMobileFuseMediationAdapterInterstitialAdDelegate : NSObject<IMFAdCallbackReceiver>
@property (nonatomic, weak, readwrite) ALMobileFuseMediationAdapter *parentAdapter;
@property (nonatomic, strong, readwrite) id<MAInterstitialAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MAInterstitialAdapterDelegate>)delegate;
@end

@interface ALMobileFuseMediationAdapterRewardedAdDelegate : NSObject<IMFAdCallbackReceiver>
@property (nonatomic, weak, readwrite) ALMobileFuseMediationAdapter *parentAdapter;
@property (nonatomic, strong, readwrite) id<MARewardedAdapterDelegate> delegate;
@property (nonatomic, readwrite) BOOL grantedReward;
- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate;
@end

@interface ALMobileFuseMediationAdapterNativeAdDelegate : NSObject<IMFAdCallbackReceiver>
@property (nonatomic, weak, readwrite) ALMobileFuseMediationAdapter *parentAdapter;
@property (nonatomic, strong, readwrite) id<MANativeAdAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MANativeAdAdapterDelegate>)delegate;
@end

@interface ALMobileFuseMediationAdapter()

@property (nonatomic, strong, readwrite) MFInterstitialAd *interstitial;
@property (nonatomic, strong, readwrite) MFBannerAd *adView;
@property (nonatomic, strong, readwrite) MFRewardedAd *rewarded;
@property (nonatomic, strong, readwrite) MFNativeAd *native;

@property (nonatomic, strong, readwrite) ALMobileFuseMediationAdapterInterstitialAdDelegate *interstitialAdapterDelegate;
@property (nonatomic, strong, readwrite) ALMobileFuseMediationAdapterAdViewDelegate *adViewAdapterDelegate;
@property (nonatomic, strong, readwrite) ALMobileFuseMediationAdapterRewardedAdDelegate *rewardedAdapterDelegate;
@property (nonatomic, strong, readwrite) ALMobileFuseMediationAdapterNativeAdDelegate *nativeAdapterDelegate;

@property (nonatomic, copy) void (^initializationCompletionHandler)(MAAdapterInitializationStatus, NSString * _Nullable);

@end

@implementation ALMobileFuseMediationAdapter

#pragma mark - MAAdapter Methods

- (NSString *)SDKVersion
{
    return [MobileFuse version];
}

- (NSString *)adapterVersion
{
    return [NSString stringWithFormat: @"%@.%@", [self SDKVersion], ADAPTER_REVISION];
}

- (void)setAdapterInfo
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([MobileFuseSettings respondsToSelector:@selector(setSdkAdapter:)]) {
            [MobileFuseSettings setSdkAdapter:ADAPTER_NAME];
        }

        if ([MobileFuseSettings respondsToSelector:@selector(setSdkAdapterVersion:)]) {
            [MobileFuseSettings setSdkAdapterVersion:[self adapterVersion]];
        }
    });
}

- (void)initializeWithParameters:(id<MAAdapterInitializationParameters>)parameters completionHandler:(void (^)(MAAdapterInitializationStatus, NSString * _Nullable))completionHandler {
    [self setAdapterInfo];

    // If the SDK is already initialized, just give a success callback straight away
    if ([MobileFuse isReady]) {
        completionHandler(MAAdapterInitializationStatusInitializedSuccess, nil);
        return;
    }

    ALMobileFuseMediationAdapterInitializationDelegate *initializationDelegate = [[ALMobileFuseMediationAdapterInitializationDelegate alloc] initWithParentAdapter:self completionHandler:completionHandler];

    // Now initialize the MobileFuse SDK
    [MobileFuse initWithDelegate:initializationDelegate];

    completionHandler(MAAdapterInitializationStatusInitializing, nil);
}

- (void)destroy 
{
    if ( self.adView )
    {
        [self.adView destroy];
        self.adView = nil;
    }

    if ( self.interstitial )
    {
        [self.interstitial destroy];
        self.interstitial = nil;
    }

    if ( self.rewarded )
    {
        [self.rewarded destroy];
        self.rewarded = nil;
    }
    
    if ( self.native )
    {
        [self.native destroy];
        self.native = nil;
    }

    self.interstitialAdapterDelegate = nil;
    self.adViewAdapterDelegate = nil;
    self.rewardedAdapterDelegate = nil;
}

#pragma mark - MASignalProvider Methods

- (void)collectSignalWithParameters:(id<MASignalCollectionParameters>)parameters andNotify:(id<MASignalCollectionDelegate>)delegate
{
    [self log: @"Collecting signal..."];

    [self setAdapterInfo];

    MFBiddingTokenRequest* request = [[MFBiddingTokenRequest alloc] init];
    request.privacyPreferences = [self getPrivacyPreferences: parameters];
    request.isTestMode = parameters.isTesting;
    
    [MFBiddingTokenProvider getTokenWithRequest:request withCallback:^(NSString * _Nonnull token) {
        [delegate didCollectSignal:token];
    }];
}

#pragma mark - MAInterstitialAdapter Methods

- (void)loadInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *placementId = parameters.thirdPartyAdPlacementIdentifier;
        NSString *bidResponse = parameters.bidResponse;
        BOOL isBiddingAd = bidResponse != nil && [bidResponse al_isValidString];
        
        [self log: @"Loading %@interstitial ad for placement \"%@\"...", isBiddingAd ? @"bidding " : @"", placementId];
        
        if ( self.interstitial )
        {
            [self.interstitial destroy];
            self.interstitial = nil;
        }
        
        self.interstitialAdapterDelegate = [[ALMobileFuseMediationAdapterInterstitialAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
        self.interstitial = [[MFInterstitialAd alloc] initWithPlacementId: placementId];
        [self.interstitial registerAdCallbackReceiver: self.interstitialAdapterDelegate];
        [[ALUtils topViewControllerFromKeyWindow].view addSubview: self.interstitial];
        
        if ( isBiddingAd )
        {
            [self.interstitial loadAdWithBiddingResponseToken: bidResponse];
        }
        else
        {
            [self.interstitial loadAd];
        }
    });
}

- (void)showInterstitialAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MAInterstitialAdapterDelegate>)delegate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self log: @"Showing interstitial ad..."];
        
        if ( !self.interstitial )
        {
            [delegate didFailToDisplayInterstitialAdWithError: MAAdapterError.invalidLoadState];
            return;
        }
        
        if ( [self.interstitial isExpired] )
        {
            [self log: @"Failed to show interstitial ad because the ad has expired. Please try to ensure that you load ads near to the time that you intend to show them."];
            [delegate didFailToDisplayInterstitialAdWithError: MAAdapterError.adExpiredError];
            return;
        }
        
        if ( ![self.interstitial isLoaded] )
        {
            [delegate didFailToDisplayInterstitialAdWithError: MAAdapterError.adNotReady];
            return;
        }
        
        [self.interstitial showAd];
    });
}

#pragma mark - MARewardedAdapter Methods

- (void)loadRewardedAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MARewardedAdapterDelegate>)delegate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *placementId = parameters.thirdPartyAdPlacementIdentifier;
        NSString *bidResponse = parameters.bidResponse;
        BOOL isBiddingAd = bidResponse != nil && [bidResponse al_isValidString];
        
        [self log: @"Loading %@rewarded ad for placement \"%@\"...", isBiddingAd ? @"bidding " : @"", placementId];
        
        if ( self.rewarded )
        {
            [self.rewarded destroy];
            self.rewarded = nil;
        }
        
        self.rewardedAdapterDelegate = [[ALMobileFuseMediationAdapterRewardedAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
        self.rewarded = [[MFRewardedAd alloc] initWithPlacementId: placementId];
        [self.rewarded registerAdCallbackReceiver: self.rewardedAdapterDelegate];
        [[ALUtils topViewControllerFromKeyWindow].view addSubview: self.rewarded];
        
        if ( isBiddingAd )
        {
            [self.rewarded loadAdWithBiddingResponseToken: bidResponse];
        }
        else
        {
            [self.rewarded loadAd];
        }
    });
}

- (void)showRewardedAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MARewardedAdapterDelegate>)delegate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self log: @"Showing rewarded ad..."];
        
        if ( !self.rewarded )
        {
            [delegate didFailToDisplayRewardedAdWithError: MAAdapterError.invalidLoadState];
            return;
        }
        
        if ( [self.rewarded isExpired] )
        {
            [self log: @"Failed to show rewarded ad because the ad has expired. Please try to ensure that you load ads near to the time that you intend to show them."];
            [delegate didFailToDisplayRewardedAdWithError: MAAdapterError.adExpiredError];
            return;
        }
        
        if ( ![self.rewarded isLoaded] )
        {
            [delegate didFailToDisplayRewardedAdWithError: MAAdapterError.adNotReady];
            return;
        }
        
        [self.rewarded showAd];
    });
}

#pragma mark - MAAdViewAdapter Methods

- (void)loadAdViewAdForParameters:(id<MAAdapterResponseParameters>)parameters
                         adFormat:(MAAdFormat *)adFormat
                        andNotify:(id<MAAdViewAdapterDelegate>)delegate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *placementId = parameters.thirdPartyAdPlacementIdentifier;
        NSString *bidResponse = parameters.bidResponse;
        BOOL isBiddingAd = bidResponse != nil && [bidResponse al_isValidString];
        
        [self log: @"Loading %@%@ ad for placement \"%@\"...", isBiddingAd ? @"bidding " : @"", adFormat.label, placementId];
        
        if ( self.adView )
        {
            [self.adView destroy];
            self.adView = nil;
        }
        
        // Get ad size from the ad format, but allow the user to force it using a custom parameter
        NSDictionary *customData = [[parameters serverParameters] al_dictionaryForKey: @"custom_parameters"];
        MFBannerAdSize bannerSize = [self getBannerAdSizeFromAdFormat: adFormat];
        if ( customData[@"forcedSize"] )
        {
            // If the placement has a custom "forcedSize" parameter in its JSON, override with that
            [self log: @"Override ad size with size from custom data: %@", customData[@"forcedSize"]];
            bannerSize = [self getBannerAdSizeFromString: customData[@"forcedSize"]];
        }
        
        self.adViewAdapterDelegate = [[ALMobileFuseMediationAdapterAdViewDelegate alloc] initWithParentAdapter: self andNotify: delegate];
        self.adView = [[MFBannerAd alloc] initWithPlacementId: placementId withSize: bannerSize];
        [self.adView registerAdCallbackReceiver: self.adViewAdapterDelegate];
        
        // If the placement has a custom "initiallyMuted" parameter, use that to override initial mute state of banners
        if ( customData[@"initiallyMuted"] )
        {
            [self log: @"Override ad mute state with value from custom data: %@", [customData[@"initiallyMuted"] boolValue] ? @"YES" : @"NO"];
            [self.adView setMuted: [customData[@"initiallyMuted"] boolValue]];
        }
        
        if ( isBiddingAd )
        {
            [self.adView loadAdWithBiddingResponseToken: bidResponse];
        }
        else
        {
            [self.adView loadAd];
        }
    });
}

- (MFBannerAdSize)getBannerAdSizeFromAdFormat:(MAAdFormat *)adFormat
{
    if ( adFormat == MAAdFormat.banner)
    {
        // Represents a 320x50 banner advertisement
        [self log: @"%@ Ad size is 320x50", @(__PRETTY_FUNCTION__)];
        return MOBILEFUSE_BANNER_SIZE_320x50;
    }
    else if ( adFormat == MAAdFormat.leader )
    {
        // Represents a 728x90 leaderboard advertisement (for tablets)
        [self log: @"%@ Ad size is 728x90", @(__PRETTY_FUNCTION__)];
        return MOBILEFUSE_BANNER_SIZE_728x90;
    }
    else if ( adFormat == MAAdFormat.mrec )
    {
        // Represents a 300x250 rectangular advertisement
        [self log: @"%@ Ad size is 300x250", @(__PRETTY_FUNCTION__)];
        return MOBILEFUSE_BANNER_SIZE_300x250;
    }
    else
    {
        [self log: @"getBannerAdSizeFromAdFormat warning: Unsupported ad format specified, using default banner size"];
        return MOBILEFUSE_BANNER_SIZE_DEFAULT;
    }
}

- (MFBannerAdSize)getBannerAdSizeFromString:(NSString*)size
{
    NSDictionary *sizeMap = @{
        @"320x50":  @(MOBILEFUSE_BANNER_SIZE_320x50),
        @"300x50":  @(MOBILEFUSE_BANNER_SIZE_300x50),
        @"300x250": @(MOBILEFUSE_BANNER_SIZE_300x250),
        @"728x90":  @(MOBILEFUSE_BANNER_SIZE_728x90)
    };
    
    if ( sizeMap[size] )
    {
        return [sizeMap[size] integerValue];
    }
    return MOBILEFUSE_BANNER_SIZE_DEFAULT;
}

#pragma mark - MANativeAdAdapter Methods

- (void)loadNativeAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MANativeAdAdapterDelegate>)delegate {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *placementId = parameters.thirdPartyAdPlacementIdentifier;
        NSString *bidResponse = parameters.bidResponse;
        BOOL isBiddingAd = bidResponse != nil && [bidResponse al_isValidString];
        
        [self log: @"Loading %@native ad for placement \"%@\"...", isBiddingAd ? @"bidding " : @"", placementId];
        
        if ( self.native )
        {
            [self.native destroy];
            self.native = nil;
        }
        
        self.nativeAdapterDelegate = [[ALMobileFuseMediationAdapterNativeAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
        self.native = [[MFNativeAd alloc] initWithPlacementId: placementId];
        [self.native registerAdCallbackReceiver: self.nativeAdapterDelegate];
    
        if ( isBiddingAd )
        {
            [self.native loadAdWithBiddingResponseToken: bidResponse];
        }
        else
        {
            [self.native loadAd];
        }
    });

}

#pragma mark - Privacy

- (MobileFusePrivacyPreferences*)getPrivacyPreferences:(id<MAAdapterParameters>) parameters
{
    MobileFusePrivacyPreferences *prefs = [[MobileFusePrivacyPreferences alloc] init];
    
    NSNumber *isDoNotSell = parameters.doNotSell;
    if ( isDoNotSell )
    {
        [prefs setUsPrivacyConsentString: isDoNotSell.boolValue ? @"1YY-" : @"1YN-"];
    }
    else
    {
        [prefs setUsPrivacyConsentString: @"1---"];
    }
    
    if ( parameters.consentString )
    {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [prefs setIabConsentString: parameters.consentString];
        #pragma clang diagnostic pop
    }
    
    return prefs;
}

@end

@implementation ALMobileFuseMediationAdapterInitializationDelegate

#pragma mark - Initialization Delegate Methods

- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler {
    self = [super init];
    if (self) {
        _parentAdapter = parentAdapter;
        _completionBlock = [completionHandler copy];
    }
    return self;
}

- (void)onInitSuccess:(NSString *)appId withPublisherId:(NSString *)publisherId {
    [_parentAdapter log: @"Initialization succeeded"];
    if (_completionBlock) {
        _completionBlock(MAAdapterInitializationStatusInitializedSuccess, nil);
    }
}

- (void)onInitError:(NSString *)appId withPublisherId:(NSString *)publisherId withError:(MFAdError *)error {
    [_parentAdapter log: @"Error during initialization with message: %@", error.message];
    if (_completionBlock) {
        _completionBlock(MAAdapterInitializationStatusInitializedFailure, nil);
    }
}

@end

#pragma mark - Banner Delegate

@implementation ALMobileFuseMediationAdapterAdViewDelegate

- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate 
{
    self = [super init];
    if ( self ) 
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

// IMFAdCallbackReceiver delegate implementation

- (void)onAdLoaded:(MFAd *)ad 
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didLoadAdForAdView: ad];

    // Show the banner ad immediately
    dispatch_async(dispatch_get_main_queue(), ^{
        [(MFBannerAd *)ad showAdWithViewController: [ALUtils topViewControllerFromKeyWindow]];
    });
}

- (void)onAdNotFilled:(MFAd *)ad
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didFailToLoadAdViewAdWithError: MAAdapterError.noFill];
}

- (void)onAdClosed:(MFAd *)ad
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didHideAdViewAd];
}

- (void)onAdRendered:(MFAd *)ad
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didDisplayAdViewAd];
}

- (void)onAdExpanded:(MFAd *)ad
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didExpandAdViewAd];
}

- (void)onAdCollapsed:(MFAd *)ad
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didCollapseAdViewAd];
}

- (void)onAdClicked:(MFAd *)ad
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didClickAdViewAd];
}

- (void)onAdExpired:(MFAd *)ad
{
    [self.parentAdapter log: @"AdView %@", @(__PRETTY_FUNCTION__)];
}

- (void)onAdError:(MFAd *)ad withError:(MFAdError *)error {
    [self.parentAdapter log: @"AdView %@ with message: %@", @(__PRETTY_FUNCTION__), error.message];
    [self.delegate didFailToLoadAdViewAdWithError: MAAdapterError.internalError];
}

@end

#pragma mark - Interstitial Delegate

@implementation ALMobileFuseMediationAdapterInterstitialAdDelegate

- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

// IMFAdCallbackReceiver delegate implementation

- (void)onAdLoaded:(MFAd *)ad
{
    [self.parentAdapter log: @"Interstitial %@ with placement ID ", @(__PRETTY_FUNCTION__), ad.placementId];
    [self.delegate didLoadInterstitialAd];
}

- (void)onAdNotFilled:(MFAd *)ad
{
    [self.parentAdapter log: @"Interstitial %@ with placement ID ", @(__PRETTY_FUNCTION__), ad.placementId];
    [self.delegate didFailToLoadInterstitialAdWithError: MAAdapterError.noFill];
}

- (void)onAdClosed:(MFAd *)ad
{
    [self.parentAdapter log: @"Interstitial %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didHideInterstitialAd];
}

- (void)onAdRendered:(MFAd *)ad
{
    [self.parentAdapter log: @"Interstitial %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didDisplayInterstitialAd];
}

- (void)onAdClicked:(MFAd *)ad
{
    [self.parentAdapter log: @"Interstitial %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didClickInterstitialAd];
}

- (void)onAdExpired:(MFAd *)ad
{
    [self.parentAdapter log: @"Interstitial %@", @(__PRETTY_FUNCTION__)];
}

- (void)onAdError:(MFAd *)ad withError:(MFAdError *)error {
    [self.parentAdapter log: @"Interstitial %@ with message: %@", @(__PRETTY_FUNCTION__), error.message];
    [self.delegate didFailToLoadInterstitialAdWithError: MAAdapterError.internalError];
}

@end

#pragma mark - Rewarded Delegate

@implementation ALMobileFuseMediationAdapterRewardedAdDelegate

@synthesize grantedReward;

- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

// IMFAdCallbackReceiver delegate implementation

- (void)onAdLoaded:(MFAd *)ad
{
    [self.parentAdapter log: @"Rewarded %@ with placement ID ", @(__PRETTY_FUNCTION__), ad.placementId];
    [self.delegate didLoadRewardedAd];
}

- (void)onAdNotFilled:(MFAd *)ad {
    [self.parentAdapter log: @"Rewarded %@ with placement ID ", @(__PRETTY_FUNCTION__), ad.placementId];
    [self.delegate didFailToLoadRewardedAdWithError: MAAdapterError.noFill];
}

- (void)onAdRendered:(MFAd *)ad {
    [self.parentAdapter log: @"Rewarded %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didDisplayRewardedAd];
}

- (void)onUserEarnedReward:(MFAd *)ad
{
    [self.parentAdapter log: @"Rewarded %@", @(__PRETTY_FUNCTION__)];
    self.grantedReward = YES;
}

- (void)onAdClosed:(MFAd *)ad
{
    [self.parentAdapter log: @"Rewarded %@", @(__PRETTY_FUNCTION__)];
    if ( self.grantedReward )
    {
        MAReward *reward = self.parentAdapter.reward;
        [self.parentAdapter log: @"Rewarded ad user with reward: %@", reward];
        [self.delegate didRewardUserWithReward: reward];
        self.grantedReward = NO;
    }
    [self.delegate didHideRewardedAd];
}

- (void)onAdClicked:(MFAd *)ad
{
    [self.parentAdapter log: @"Rewarded %@", @(__PRETTY_FUNCTION__)];
    [self.delegate didClickRewardedAd];
}

- (void)onAdExpired:(MFAd *)ad
{
    [self.parentAdapter log: @"Rewarded %@", @(__PRETTY_FUNCTION__)];
}

- (void)onAdError:(MFAd *)ad withError:(MFAdError *)error {
    [self.parentAdapter log: @"Rewarded %@ with message: %@", @(__PRETTY_FUNCTION__), error.message];
    [self.delegate didFailToLoadRewardedAdWithError: MAAdapterError.internalError];
}

@end

#pragma mark - ALMobileFuseNativeAd

@interface ALMobileFuseNativeAd : MANativeAd

@property (nonatomic, weak) ALMobileFuseMediationAdapter *parentAdapter;
- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock;

@end

@implementation ALMobileFuseNativeAd

- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock
{
    self = [super initWithFormat: MAAdFormat.native builderBlock: builderBlock];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
    }
    return self;
}

- (BOOL)prepareForInteractionClickableViews:(NSArray<UIView *> *)clickableViews withContainer:(UIView *)container {
    @try {
        [self.parentAdapter.native registerViewForInteraction:container withClickableViews:clickableViews];
    }
    @catch (NSError *error) {
        NSLog(@"%s%@", "Error: MobileFuse SDK could not register view for interaction.", error.localizedDescription);
        return NO;
    }
    return YES;
}

@end

#pragma mark - Native Delegate

@implementation ALMobileFuseMediationAdapterNativeAdDelegate

- (instancetype)initWithParentAdapter:(ALMobileFuseMediationAdapter *)parentAdapter andNotify:(id<MANativeAdAdapterDelegate>)delegate {
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

// IMFAdCallbackReceiver delegate implementation

- (void)onAdLoaded:(MFAd *)ad {
    MFNativeAd *mfNativeAd = (MFNativeAd *)ad;
    self.parentAdapter.native = mfNativeAd;
    MANativeAd *maxNativeAd = [self buildMaxNativeAdFromMfNativeAd: mfNativeAd];
    [self.delegate didLoadAdForNativeAd: maxNativeAd withExtraInfo: nil];
}

- (MANativeAd *)buildMaxNativeAdFromMfNativeAd:(MFNativeAd *)nativeAd {
    MANativeAd *maxNativeAd = [[ALMobileFuseNativeAd alloc] initWithParentAdapter:self.parentAdapter builderBlock: ^(MANativeAdBuilder *builder) {
        builder.title = nativeAd.getTitle;
        builder.body = nativeAd.getDescriptionText;
        builder.callToAction = nativeAd.getCtaButtonText;
        builder.mediaView = nativeAd.getMainContentView;
        builder.mediaContentAspectRatio = [self calculateAspectRatioFromView:builder.mediaView];
        builder.advertiser = nativeAd.getSponsoredText;
        if ( nativeAd.getMainImage ) {
            builder.mainImage = [[MANativeAdImage alloc] initWithImage: nativeAd.getMainImage];
        }
        if ( nativeAd.getIconImage ) {
            builder.icon = [[MANativeAdImage alloc] initWithImage: nativeAd.getIconImage];
        }
    }];
    return maxNativeAd;
}

- (CGFloat)calculateAspectRatioFromView:(UIView *)videoView {
    CGFloat mediaContentAspectRatio = 0.0f;
    if ( videoView != nil && videoView.bounds.size.width > 0 && videoView.bounds.size.height > 0) {
        mediaContentAspectRatio = videoView.bounds.size.width / videoView.bounds.size.height;
    }
    return mediaContentAspectRatio;
}

@end
