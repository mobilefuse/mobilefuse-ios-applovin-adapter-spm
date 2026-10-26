//
//  ALMobileFuseMediationAdapter.h
//  AppLovin MAX Mediation Adapter for MobileFuse
//

@import Foundation;
@import MobileFuseSDK;
@import AppLovinSDK;

#ifndef ALMobileFuseMediationAdapter_h
#define ALMobileFuseMediationAdapter_h

NS_ASSUME_NONNULL_BEGIN

@interface ALMobileFuseMediationAdapter : ALMediationAdapter<MASignalProvider, MAAdViewAdapter, MAInterstitialAdapter, MARewardedAdapter, MANativeAdAdapter, IMFInitializationCallbackReceiver>

@end

NS_ASSUME_NONNULL_END

#endif /* ALMobileFuseMediationAdapter_h */
