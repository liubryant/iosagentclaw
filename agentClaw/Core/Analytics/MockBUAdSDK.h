//
//  MockBUAdSDK.h
//  agentClaw
//
//  Mock implementation of Pangle SDK for Xcode 12.3 compatibility
//  Replace with real SDK when upgrading to Xcode 14+
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: - Enums

typedef NS_ENUM(NSInteger, BUSplashAdCloseType) {
    BUSplashAdCloseTypeClickSkip = 1,
    BUSplashAdCloseTypeCountdownEnd = 2,
    BUSplashAdCloseTypeClickAd = 3
};

typedef NS_ENUM(NSInteger, BUInteractionType) {
    BUInteractionTypeUnknown = 0,
    BUInteractionTypeDownload = 1,
    BUInteractionTypeWebView = 2,
    BUInteractionTypeDeeplink = 3
};

// MARK: - BUAdError

@interface BUAdError : NSObject
@property (nonatomic, assign) NSInteger code;
@property (nonatomic, copy, nullable) NSString *localizedDescription;
@end

// MARK: - BUAdSlot

@interface BUAdSlot : NSObject
@property (nonatomic, copy, nullable) NSString *ID;
@end

// MARK: - BUMediationAdSlot

@interface BUMediationAdSlot : NSObject
@property (nonatomic, strong, nullable) NSNumber *limitPersonalAds;
@property (nonatomic, strong, nullable) NSNumber *limitProgrammaticAds;
@end

// MARK: - BUAdSDKConfiguration

@interface BUAdSDKConfiguration : NSObject
@property (nonatomic, copy, nullable) NSString *appID;
@property (nonatomic, assign) BOOL useMediation;
@property (nonatomic, strong, nullable) NSNumber *themeStatus;
@property (nonatomic, strong, readonly) BUMediationAdSlot *mediation;
@end

// MARK: - BUSplashAd

@class BUSplashAd;

@protocol BUSplashAdDelegate <NSObject>
@optional
- (void)splashAdLoadSuccess:(BUSplashAd *)splashAd;
- (void)splashAdLoadFail:(BUSplashAd *)splashAd error:(BUAdError *_Nullable)error;
- (void)splashAdRenderSuccess:(BUSplashAd *)splashAd;
- (void)splashAdRenderFail:(BUSplashAd *)splashAd error:(BUAdError *_Nullable)error;
- (void)splashAdWillShow:(BUSplashAd *)splashAd;
- (void)splashAdDidShow:(BUSplashAd *)splashAd;
- (void)splashAdDidClick:(BUSplashAd *)splashAd;
- (void)splashAdDidClose:(BUSplashAd *)splashAd closeType:(BUSplashAdCloseType)closeType;
- (void)splashAdViewControllerDidClose:(BUSplashAd *)splashAd;
- (void)splashDidCloseOtherController:(BUSplashAd *)splashAd interactionType:(BUInteractionType)interactionType;
- (void)splashVideoAdDidPlayFinish:(BUSplashAd *)splashAd didFailWithError:(NSError *_Nullable)error;
@end

@interface BUSplashAd : NSObject
@property (nonatomic, weak, nullable) id<BUSplashAdDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval tolerateTimeout;

- (instancetype)initWithSlot:(BUAdSlot *)slot adSize:(CGSize)adSize;
- (void)loadData;
@end

// MARK: - BUAdSDKManager

@interface BUAdSDKManager : NSObject
+ (void)setConfiguration:(BUAdSDKConfiguration *)configuration;
+ (void)startWithAsyncCompletionHandler:(void (^_Nullable)(BOOL success, NSError *_Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
