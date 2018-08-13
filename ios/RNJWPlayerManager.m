#import <JWPlayer_iOS_SDK/JWPlayerController.h>

#import "RNJWPlayerManager.h"
#import "RNJWPlayerNativeView.h"

#import "RCTUIManager.h"

@interface RNJWPlayerManager ()
@property(nonatomic, strong)RNJWPlayerNativeView *playerView;
@end

@implementation RNJWPlayerManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
    return [[RNJWPlayerNativeView alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(onBeforePlay, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlay, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPause, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onBuffer, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onSetupPlayerError, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlayerError, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onTime, RCTBubblingEventBlock);

RCT_EXPORT_VIEW_PROPERTY(file, NSString);
RCT_EXPORT_VIEW_PROPERTY(autoPlay, BOOL);

RCT_REMAP_METHOD(state,
                 tag:(nonnull NSNumber *)reactTag
                 stateWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNJWPlayerNativeView *> *viewRegistry) {
        RNJWPlayerNativeView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNJWPlayerNativeView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNJWPlayerNativeView, got: %@", view);
            
            NSError *error = [[NSError alloc] init];
            reject(@"no_player", @"There is no player", error);
        } else {
            if (view.player) {
                resolve([NSNumber numberWithInt:[view.player state]]);
            } else {
                NSError *error = [[NSError alloc] init];
                reject(@"no_player", @"There is no player", error);
            };
        }
    }];
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber *)reactTag) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNJWPlayerNativeView *> *viewRegistry) {
        RNJWPlayerNativeView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNJWPlayerNativeView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNJWPlayerNativeView, got: %@", view);
        } else {
            [view.player pause];
        }
    }];
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber *)reactTag) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNJWPlayerNativeView *> *viewRegistry) {
        RNJWPlayerNativeView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNJWPlayerNativeView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNJWPlayerNativeView, got: %@", view);
        } else {
            [view.player play];
        }
    }];
}

@end
