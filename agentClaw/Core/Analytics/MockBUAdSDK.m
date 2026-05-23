//
//  MockBUAdSDK.m
//  agentClaw
//
//  Mock implementation of Pangle SDK for Xcode 12.3 compatibility
//

#import "MockBUAdSDK.h"

// MARK: - BUAdError

@implementation BUAdError
@end

// MARK: - BUAdSlot

@implementation BUAdSlot
@end

// MARK: - BUMediationAdSlot

@implementation BUMediationAdSlot
@end

// MARK: - BUAdSDKConfiguration

@implementation BUAdSDKConfiguration

- (instancetype)init {
    self = [super init];
    if (self) {
        _mediation = [[BUMediationAdSlot alloc] init];
    }
    return self;
}

@end

// MARK: - BUSplashAd

@implementation BUSplashAd

- (instancetype)initWithSlot:(BUAdSlot *)slot adSize:(CGSize)adSize {
    self = [super init];
    if (self) {
        NSLog(@"🔧 Mock BUSplashAd initialized (SlotID: %@)", slot.ID);
    }
    return self;
}

- (void)loadData {
    NSLog(@"🔧 Mock BUSplashAd loadData called");

    // Simulate async ad loading with success callback after 1 second
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(splashAdLoadSuccess:)]) {
            NSLog(@"🔧 Mock: Simulating ad load success");
            [self.delegate splashAdLoadSuccess:self];
        }

        // Simulate render success
        if ([self.delegate respondsToSelector:@selector(splashAdRenderSuccess:)]) {
            NSLog(@"🔧 Mock: Simulating ad render success");
            [self.delegate splashAdRenderSuccess:self];
        }

        // Simulate ad show
        if ([self.delegate respondsToSelector:@selector(splashAdDidShow:)]) {
            NSLog(@"🔧 Mock: Simulating ad show");
            [self.delegate splashAdDidShow:self];
        }

        // Simulate ad close after 3 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(splashAdDidClose:closeType:)]) {
                NSLog(@"🔧 Mock: Simulating ad close");
                [self.delegate splashAdDidClose:self closeType:BUSplashAdCloseTypeCountdownEnd];
            }
        });
    });
}

@end

// MARK: - BUAdSDKManager

@implementation BUAdSDKManager

static BUAdSDKConfiguration *_configuration = nil;

+ (void)setConfiguration:(BUAdSDKConfiguration *)configuration {
    _configuration = configuration;
    NSLog(@"🔧 Mock BUAdSDKManager configuration set (AppID: %@)", configuration.appID);
}

+ (void)startWithAsyncCompletionHandler:(void (^)(BOOL, NSError * _Nullable))completion {
    NSLog(@"🔧 Mock BUAdSDKManager starting (AppID: %@, Mediation: %@)",
          _configuration.appID,
          _configuration.useMediation ? @"YES" : @"NO");

    // Simulate async initialization
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"🔧 Mock: SDK initialization completed successfully");
        if (completion) {
            completion(YES, nil);
        }
    });
}

@end
