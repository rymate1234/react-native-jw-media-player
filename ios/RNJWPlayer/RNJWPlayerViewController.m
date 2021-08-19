#import "RNJWPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation RNJWPlayerViewController

#pragma mark - RNJWPlayer allocation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rotated:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    @try {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:AVAudioSessionInterruptionNotification];
    } @catch(id anException) {
       
    }
}

- (void)initializeAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(audioSessionInterrupted:)
                                                 name: AVAudioSessionInterruptionNotification
                                               object: audioSession];
    
    NSError *setCategoryError = nil;
    BOOL success = [audioSession setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
    
    NSError *activationError = nil;
    success = [audioSession setActive:YES error:&activationError];
}

- (void)rotated:(NSNotification *)notification {
    if (UIDeviceOrientationIsLandscape(UIDevice.currentDevice.orientation)) {
        NSLog(@"Landscape");
    }

    if (UIDeviceOrientationIsPortrait(UIDevice.currentDevice.orientation)) {
        NSLog(@"Portrait");
    }
    
    [self layoutSubviews];
}

#pragma mark - RNJWPlayer styling

-(UIColor*)colorWithHexString:(NSString*)hex
{
    NSString *cString = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    // String should be 6 or 8 characters
    if ([cString length] < 6) return [UIColor grayColor];
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"]) cString = [cString substringFromIndex:2];
    
    if ([cString length] != 6) return  [UIColor grayColor];
    
    // Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString *rString = [cString substringWithRange:range];
    
    range.location = 2;
    NSString *gString = [cString substringWithRange:range];
    
    range.location = 4;
    NSString *bString = [cString substringWithRange:range];
    
    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    
    return [UIColor colorWithRed:((float) r / 255.0f)
                           green:((float) g / 255.0f)
                            blue:((float) b / 255.0f)
                           alpha:1.0f];
}



#pragma mark - RNJWPlayer props

-(BOOL)shouldAutorotate {
    return NO;
}

-(JWPlayerItem*)getPlayerItem:item
{
    JWPlayerItemBuilder* itemBuilder = [[JWPlayerItemBuilder alloc] init];
    
    NSString* newFile = [item objectForKey:@"file"];
    NSURL* url = [NSURL URLWithString:newFile];
    
    if (url && url.scheme && url.host) {
        [itemBuilder file:url];
    } else {
        NSString* encodedString = [newFile stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
        NSURL* encodedUrl = [NSURL URLWithString:encodedString];
        [itemBuilder file:encodedUrl];
    }
    
    id mediaId = item[@"mediaId"];
    if ((mediaId != nil) && (mediaId != (id)[NSNull null])) {
        [itemBuilder mediaId:mediaId];
    }
    
    id title = item[@"title"];
    if ((title != nil) && (title != (id)[NSNull null])) {
        [itemBuilder title:title];
    }
    
    id desc = item[@"desc"];
    if ((desc != nil) && (desc != (id)[NSNull null])) {
        [itemBuilder description:desc];
    }
    
    id image = item[@"image"];
    if ((image != nil) && (image != (id)[NSNull null])) {
        NSURL* imageUrl = [NSURL URLWithString:image];
        [itemBuilder posterImage:imageUrl];
    }
    
    id startTime = item[@"startTime"];
    if ((startTime != nil) && (startTime != (id)[NSNull null])) {
        [itemBuilder startTime:[startTime floatValue]];
    }

    NSMutableArray <JWMediaTrack*> *tracksArray = [[NSMutableArray alloc] init];
    id tracksItem = item[@"tracks"];
    if(tracksItem != nil) {
        NSArray* tracksItemArray = (NSArray*)tracksItem;
        if(tracksItemArray.count > 0) {
            for (id item in tracksItemArray) {
                NSString *file = [item objectForKey:@"file"];
                NSURL *fileUrl = [NSURL URLWithString:file];
                NSString *label = [item objectForKey:@"label"];
                
                JWMediaTrack *trackItem = [JWMediaTrack init];
                JWCaptionTrackBuilder* trackBuilder = [[JWCaptionTrackBuilder alloc] init];
                
                [trackBuilder file:fileUrl];
                [trackBuilder label:label];
                
                NSError* error = nil;
                trackItem = [trackBuilder buildAndReturnError:&error];
                
                [tracksArray addObject:trackItem];
            }
        }
    }
    if (tracksArray.count > 0) {
        [itemBuilder mediaTracks:tracksArray];
    }
    
    NSMutableArray <JWAdBreak*>* adsArray = [[NSMutableArray alloc] init];
    id ads = item[@"adSchedule"];
    if(ads != nil) {
        NSArray* adsAr = (NSArray*)ads;
        if(adsAr.count > 0) {
            for (id item in adsAr) {
                NSString *offsetString = [item objectForKey:@"offset"];
                NSString *tag = [item objectForKey:@"tag"];
                NSURL* tagUrl = [NSURL URLWithString:tag];
                
                JWAdBreak *adBreak = [JWAdBreak init];
                JWAdBreakBuilder* adBreakBuilder = [[JWAdBreakBuilder alloc] init];
                JWAdOffset* offset = [JWAdOffset fromString:offsetString];
                
                [adBreakBuilder offset:offset];
                [adBreakBuilder tags:@[tagUrl]];
                
                NSError* error = nil;
                adBreak = [adBreakBuilder buildAndReturnError:&error];
                
                [adsArray addObject:adBreak];
            }
        }
    }

    if (adsArray.count > 0) {
        [itemBuilder adSchedule:adsArray];
    }
    
    JWError* error = nil;
    return [itemBuilder buildAndReturnError:&error];
}

-(void)setPlaylist:(NSArray *)playlist
{
    if (playlist != nil && playlist.count > 0) {
        
//        JWAdClientJWPlayer = 0,
//      /// Google IMA
//        JWAdClientGoogleIMA = 1,
//      /// Google IMA DAI
//        JWAdClientGoogleIMADAI = 2,
//      /// An unrecognized ad client.
//        JWAdClientUnknown = 3,
        
//        JWAdsAdvertisingConfigBuilder* adConfigBuilder = [JWAdsAdvertisingConfigBuilder new];
        
//        id adClient = [playlist[0] objectForKey:@"adClient"];
//        if ((adClient != nil) && (adClient != (id)[NSNull null])) {
//            switch ([adClient intValue]) {
//                case 1:
//                    advertising.client = JWAdClientGoogima;
//                    break;
//                case 2:
//                    advertising.client = JWAdClientGoogimaDAI;
//                    break;
//                case 3:
//                    advertising.client = JWAdClientFreewheel;
//                    break;
//
//                default:
//                    advertising.client = JWAdClientVast;
//                    break;
//            }
//        } else {
//            advertising.client = JWAdClientVast;
//        }
//
//        config.advertising = advertising;
        
//        if ([playlist[0] objectForKey:@"adVmap"] != nil) {
//            id adVmap = [playlist[0] objectForKey:@"adVmap"];
//            if ((adVmap != nil) && (adVmap != (id)[NSNull null])) {
//                config.advertising.adVmap = adVmap;
//            }
//        }
        
//        if (_playerView == nil) {
//            [self reset];
            
//            _playerView.videoGravity = 0;
//            _playerView.captionStyle
        } else {
             [self continuePlaying];
        }
}

-(void)setStyling:(NSDictionary*)styling
{
    JWError* error = nil;
    
    if (styling != nil && (styling != (id)[NSNull null])) {
        JWPlayerSkinBuilder* skinStylingBuilder = [[JWPlayerSkinBuilder alloc] init];
        
        id colors = styling[@"colors"];
        if (colors != nil && (colors != (id)[NSNull null])) {
            JWTimeSliderStyleBuilder* timeSliderStyleBuilder = [[JWTimeSliderStyleBuilder alloc] init];
            
            id slider = colors[@"slider"];
            if (slider != nil && (slider != (id)[NSNull null])) {
                [timeSliderStyleBuilder maximumTrackColor:[self colorWithHexString:slider]];
            }
            
            id rail = colors[@"rail"];
            if (rail != nil && (rail != (id)[NSNull null])) {
                [timeSliderStyleBuilder minimumTrackColor:[self colorWithHexString:rail]];
            }
            
            id thumb = colors[@"thumb"];
            if (thumb != nil && (thumb != (id)[NSNull null])) {
                [timeSliderStyleBuilder thumbColor:[self colorWithHexString:thumb]];
            }
            
            JWTimeSliderStyle* timeSliderStyle = [timeSliderStyleBuilder buildAndReturnError:&error];
            
            [skinStylingBuilder timeSliderStyle:timeSliderStyle];
            
            id buttons = colors[@"buttons"];
            if (buttons != nil && (buttons != (id)[NSNull null])) {
                [skinStylingBuilder buttonsColor:[self colorWithHexString:buttons]];
            }
            
            id backgroundColor = colors[@"backgroundColor"];
            if (backgroundColor != nil && (backgroundColor != (id)[NSNull null])) {
                [skinStylingBuilder backgroundColor:[self colorWithHexString:backgroundColor]];
            }
            
            id fontColor = colors[@"fontColor"];
            if (fontColor != nil && (fontColor != (id)[NSNull null])) {
                [skinStylingBuilder fontColor:[self colorWithHexString:fontColor]];
            }
        }
        
        id font = styling[@"font"];
        if (font != nil && (font != (id)[NSNull null])) {
            id name = font[@"name"];
            id size = font[@"size"];
            
            if (name != nil && (name != (id)[NSNull null]) && size != nil && (size != (id)[NSNull null])) {
                [skinStylingBuilder font:[UIFont fontWithName:name size:[size floatValue]]];
            }
        }
        
        id showTitle = styling[@"showTitle"];
        if (showTitle != nil && (showTitle != (id)[NSNull null])) {
            [skinStylingBuilder titleIsVisible:showTitle];
        }
        
        id showDesc = styling[@"showDesc"];
        if (showDesc != nil && (showDesc != (id)[NSNull null])) {
            [skinStylingBuilder descriptionIsVisible:showDesc];
        }
        
        id capStyle = styling[@"capStyle"];
        if (capStyle != nil && (capStyle != (id)[NSNull null])) {
            JWCaptionStyleBuilder* capStyleBuilder = [[JWCaptionStyleBuilder alloc] init];
            
            id font = capStyle[@"font"];
            if (font != nil && (font != (id)[NSNull null])) {
                id name = font[@"name"];
                id size = font[@"size"];
                if (name != nil && (name != (id)[NSNull null]) && size != nil && (size != (id)[NSNull null])) {
                    [capStyleBuilder font:[UIFont fontWithName:name size:[size floatValue]]];
                }
            }
            
            id fontColor = capStyle[@"fontColor"];
            if (fontColor != nil && (fontColor != (id)[NSNull null])) {
                [capStyleBuilder fontColor:[self colorWithHexString:fontColor]];
            }
            
            id backgroundColor = capStyle[@"backgroundColor"];
            if (backgroundColor != nil && (backgroundColor != (id)[NSNull null])) {
                [capStyleBuilder backgroundColor:[self colorWithHexString:backgroundColor]];
            }
            
            id highlightColor = capStyle[@"highlightColor"];
            if (highlightColor != nil && (highlightColor != (id)[NSNull null])) {
                [capStyleBuilder highlightColor:[self colorWithHexString:highlightColor]];
            }
            
            id edgeStyle = capStyle[@"edgeStyle"];
            if (edgeStyle != nil && (edgeStyle != (id)[NSNull null])) {
                JWCaptionEdgeStyle finalEdgeStyle;
                switch ([edgeStyle intValue]) {
                    case 1:
                        finalEdgeStyle = JWCaptionEdgeStyleUndefined;
                        break;
                    case 2:
                        finalEdgeStyle = JWCaptionEdgeStyleNone;
                        break;
                    case 3:
                        finalEdgeStyle = JWCaptionEdgeStyleDropshadow;
                        break;
                    case 4:
                        finalEdgeStyle = JWCaptionEdgeStyleRaised;
                        break;
                    case 5:
                        finalEdgeStyle = JWCaptionEdgeStyleDepressed;
                        break;
                    case 6:
                        finalEdgeStyle = JWCaptionEdgeStyleUniform;
                        break;
    
                    default:
                        finalEdgeStyle = JWCaptionEdgeStyleUndefined;
                        break;
                }
                
                [capStyleBuilder edgeStyle:finalEdgeStyle];
            }
            
            JWCaptionStyle* captionStyle = [capStyleBuilder buildAndReturnError:&error];
            
            [skinStylingBuilder captionStyle:captionStyle];
        }
        
//        menuStyle
        
        JWPlayerSkin *skinStyling = [skinStylingBuilder buildAndReturnError:&error];
        
        _playerViewController.styling = skinStyling;
    }
}

-(void)setConfig:(NSDictionary*)config
{
    id license = config[@"license"];
    if ((license != nil) && (license != (id)[NSNull null])) {
        [JWPlayerKitLicense setLicenseKey:license];
    } else {
        NSLog(@"JW SDK License key not set.");
    }
    
    _backgroundAudioEnabled = config[@"backgroundAudioEnabled"];
    if (_backgroundAudioEnabled) {
        [self initializeAudioSession];
    }
    
    [self dismissPlayerViewController];
    
    _playerViewController = [JWPlayerViewController new];
    _playerViewController.delegate = self;
    
    id interfaceBehavior = config[@"interfaceBehavior"];
    if ((interfaceBehavior != nil) && (interfaceBehavior != (id)[NSNull null])) {
        switch ([interfaceBehavior intValue]) {
            case 0:
                _playerViewController.interfaceBehavior = JWInterfaceBehaviorNormal;
                break;
            case 1:
                _playerViewController.interfaceBehavior = JWInterfaceBehaviorHidden;
                break;
            case 2:
                _playerViewController.interfaceBehavior = JWInterfaceBehaviorAlwaysOnScreen;
                break;
            default:
                break;
        }
    }
    
    if (config[@"forceFullScreenOnLandscape"] != nil) {
        bool forceFullScreenOnLandscape = config[@"forceFullScreenOnLandscape"];
        _playerViewController.forceFullScreenOnLandscape = forceFullScreenOnLandscape;
    }
    
    if (config[@"forceLandscapeOnFullScreen"] != nil) {
        bool forceLandscapeOnFullScreen = config[@"forceLandscapeOnFullScreen"];
        _playerViewController.forceLandscapeOnFullScreen = forceLandscapeOnFullScreen;
    }
    
    if (config[@"enableLockScreenControls"] != nil) {
        bool enableLockScreenControls = config[@"enableLockScreenControls"];
        _playerViewController.enableLockScreenControls = enableLockScreenControls;
    }
    
    id styling = config[@"styling"];
    [self setStyling:styling];
    
    //    _playerViewController.adInterfaceStyle
//    _playerViewController.logo
//    _playerViewController.nextUpStyle
    
    id offlineMsg = config[@"offlineMessage"];
    if (offlineMsg != nil && offlineMsg != (id)[NSNull null]) {
        _playerViewController.offlineMessage = offlineMsg;
    }
    
    id offlineImg = config[@"offlineImage"];
    if (offlineImg != nil && offlineImg != (id)[NSNull null]) {
        NSURL* imageUrl = [NSURL URLWithString:offlineImg];
        if ([imageUrl isFileURL]) {
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageUrl]];
            _playerViewController.offlinePosterImage = image;
        }
    }
    
    NSMutableArray <JWPlayerItem *> *playlistArray = [[NSMutableArray alloc] init];
    if (config[@"items"] != nil && (config[@"items"] != (id)[NSNull null])) {
        NSArray* items = config[@"items"];
        for (id item in items) {
            JWPlayerItem *playerItem = [self getPlayerItem:item];
            [playlistArray addObject:playerItem];
        }
    }
    
    JWPlayerConfigurationBuilder *configBuilder = [[JWPlayerConfigurationBuilder alloc] init];
    
    [configBuilder playlist:playlistArray];
    
    if (config[@"autostart"] != nil && (config[@"autostart"] != (id)[NSNull null])) {
        bool autostart = config[@"autostart"];
        [configBuilder autostart:autostart];
    }
    
    if (config[@"repeat"] != nil && (config[@"repeat"] != (id)[NSNull null])) {
        bool repeatContent = config[@"repeat"];
        [configBuilder repeatContent:repeatContent];
    }
    
//            preload
//            JWRelatedContentConfiguration
//            [configBuilder related:(JWRelatedContentConfiguration * _Nonnull)]
    
    JWError* error = nil;
    JWPlayerConfiguration* configuration = [configBuilder buildAndReturnError:&error];
    [self presentPlayerViewController:configuration];
}

-(void)dismissPlayerViewController
{
    if (_playerViewController != nil) {
        [_playerViewController dismissViewControllerAnimated:NO completion:^{
            self->_playerViewController = nil;
        }];
    }
}

-(void)presentPlayerViewController:(JWPlayerConfiguration*)configuration
{
    _playerViewController.providesPresentationContextTransitionStyle = YES;
    _playerViewController.definesPresentationContext = YES;
    _playerViewController.modalPresentationStyle = UIModalPresentationCustom;
    _playerViewController.transitioningDelegate = self;
    _playerViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    UIWindow *window = (UIWindow*)[[UIApplication sharedApplication] keyWindow];
    [window.rootViewController presentViewController:_playerViewController animated:NO completion:nil];
    
    [_playerViewController.player configurePlayerWith:configuration];

    _playerViewController.playerView.delegate = self;
    _playerViewController.player.delegate = self;
//    _playerViewController.player.playbackStateDelegate = self; // this causes issue with ui
    _playerViewController.player.adDelegate = self;
    _playerViewController.player.avDelegate = self;
}

-(void)continuePlaying
{
//    if (_playerViewController != nil) {
////        _playerViewController.player.currentItem.videoSources
//        if (_playerViewController.player.currentItem.autostart) {
//            [_playerViewController.player play];
//        }
//    }
}

#pragma mark - JWPlayer Delegate

- (void)jwplayerIsReady:(id<JWPlayer>)player
{
    if (self.onPlayerReady) {
        self.onPlayerReady(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player failedWithError:(NSUInteger)code message:(NSString *)message
{
    if (self.onPlayerError) {
        self.onPlayerError(@{@"error": message});
    }
}

- (void)jwplayer:(id<JWPlayer>)player failedWithSetupError:(NSUInteger)code message:(NSString *)message
{
    if (self.onSetupPlayerError) {
        self.onSetupPlayerError(@{@"error": message});
    }
}

- (void)jwplayer:(id<JWPlayer>)player encounteredWarning:(NSUInteger)code message:(NSString *)message
{
    if (self.onPlayerWarning) {
        self.onPlayerWarning(@{@"warning": message});
    }
}

- (void)jwplayer:(id<JWPlayer> _Nonnull)player encounteredAdError:(NSUInteger)code message:(NSString * _Nonnull)message {
    if (self.onPlayerAdError) {
        self.onPlayerAdError(@{@"error": message});
    }
}


- (void)jwplayer:(id<JWPlayer> _Nonnull)player encounteredAdWarning:(NSUInteger)code message:(NSString * _Nonnull)message {
    if (self.onPlayerAdWarning) {
        self.onPlayerAdWarning(@{@"warning": message});
    }
}


#pragma mark - JWPlayer View Delegate

- (void)playerView:(JWPlayerView *)view sizeChangedFrom:(CGSize)oldSize to:(CGSize)newSize
{
    if (self.onPlayerSizeChange) {
        NSMutableDictionary* oldSizeDict = [[NSMutableDictionary alloc] init];
        [oldSizeDict setObject:[NSNumber numberWithFloat: oldSize.width] forKey:@"width"];
        [oldSizeDict setObject:[NSNumber numberWithFloat: oldSize.height] forKey:@"height"];
        
        NSMutableDictionary* newSizeDict = [[NSMutableDictionary alloc] init];
        [newSizeDict setObject:[NSNumber numberWithFloat: newSize.width] forKey:@"width"];
        [newSizeDict setObject:[NSNumber numberWithFloat: newSize.height] forKey:@"height"];
        
        NSMutableDictionary* sizesDict = [[NSMutableDictionary alloc] init];
        [sizesDict setObject:oldSizeDict forKey:@"oldSize"];
        [sizesDict setObject:newSizeDict forKey:@"newSize"];
        
        NSError* error = nil;
        NSData* data = [NSJSONSerialization dataWithJSONObject:sizesDict options:NSJSONWritingPrettyPrinted error: &error];
        self.onPlayerSizeChange(@{@"sizes": data});
    }
}

#pragma mark - JWPlayer View Controller Delegate

- (void)playerViewController:(JWPlayerViewController *)controller sizeChangedFrom:(CGSize)oldSize to:(CGSize)newSize
{
    if (self.onPlayerSizeChange) {
        NSMutableDictionary* oldSizeDict = [[NSMutableDictionary alloc] init];
        [oldSizeDict setObject:[NSNumber numberWithFloat: oldSize.width] forKey:@"width"];
        [oldSizeDict setObject:[NSNumber numberWithFloat: oldSize.height] forKey:@"height"];
        
        NSMutableDictionary* newSizeDict = [[NSMutableDictionary alloc] init];
        [newSizeDict setObject:[NSNumber numberWithFloat: newSize.width] forKey:@"width"];
        [newSizeDict setObject:[NSNumber numberWithFloat: newSize.height] forKey:@"height"];
        
        NSMutableDictionary* sizesDict = [[NSMutableDictionary alloc] init];
        [sizesDict setObject:oldSizeDict forKey:@"oldSize"];
        [sizesDict setObject:newSizeDict forKey:@"newSize"];
        
        NSError* error = nil;
        NSData* data = [NSJSONSerialization dataWithJSONObject:sizesDict options:NSJSONWritingPrettyPrinted error: &error];
        self.onPlayerSizeChange(@{@"sizes": data});
    }
}

- (void)playerViewController:(JWPlayerViewController *)controller screenTappedAt:(CGPoint)position
{
    if (self.onScreenTapped) {
        self.onScreenTapped(@{@"x": @(position.x), @"y": @(position.y)});
    }
}

- (void)playerViewController:(JWPlayerViewController *)controller controlBarVisibilityChanged:(BOOL)isVisible frame:(CGRect)frame
{
    if (self.onControlBarVisible) {
        self.onControlBarVisible(@{@"visible": @(isVisible)});
    }
}

- (JWFullScreenViewController * _Nullable)playerViewControllerWillGoFullScreen:(JWPlayerViewController * _Nonnull)controller {
    if (self.onFullScreenRequested) {
        self.onFullScreenRequested(@{});
    }
    return nil;
}

- (void)playerViewControllerDidGoFullScreen:(JWPlayerViewController *)controller
{
    if (self.onFullScreen) {
        self.onFullScreen(@{});
    }
}

- (void)playerViewControllerWillDismissFullScreen:(JWPlayerViewController *)controller
{
    if (self.onFullScreenExitRequested) {
        self.onFullScreenExitRequested(@{});
    }
}

- (void)playerViewControllerDidDismissFullScreen:(JWPlayerViewController *)controller
{
    if (self.onFullScreenExit) {
        self.onFullScreenExit(@{});
    }
}

- (void)playerViewController:(JWPlayerViewController *)controller relatedMenuClosedWithMethod:(enum JWRelatedInteraction)method
{
    
}

- (void)playerViewController:(JWPlayerViewController *)controller relatedMenuOpenedWithItems:(NSArray<JWPlayerItem *> *)items withMethod:(enum JWRelatedInteraction)method
{
    
}

- (void)playerViewController:(JWPlayerViewController *)controller relatedItemBeganPlaying:(JWPlayerItem *)item atIndex:(NSInteger)index withMethod:(enum JWRelatedInteraction)method
{
    
}

#pragma mark - AV Picture In Picture Delegate

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error
{
    
}

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    
}

#pragma mark - JWPlayer State Delegate

- (void)jwplayerContentIsBuffering:(id<JWPlayer>)player
{
    if (self.onBuffer) {
        self.onBuffer(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player updatedBuffer:(double)percent position:(JWTimeData *)time
{
    if (self.onUpdateBuffer) {
        self.onUpdateBuffer(@{@"percent": @(percent), @"position": time});
    }
}

- (void)jwplayer:(id<JWPlayer>)player didFinishLoadingWithTime:(NSTimeInterval)loadTime
{
    if (self.onLoaded) {
        self.onLoaded(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player isAttemptingToPlay:(JWPlayerItem *)playlistItem reason:(enum JWPlayReason)reason
{
    if (self.onAttemptPlay) {
        self.onAttemptPlay(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player isPlayingWithReason:(enum JWPlayReason)reason
{
    if (self.onPlay) {
        self.onPlay(@{});
    }
    
    _userPaused = NO;
    _wasInterrupted = NO;
}

- (void)jwplayer:(id<JWPlayer>)player willPlayWithReason:(enum JWPlayReason)reason
{
    if (self.onBeforePlay) {
        self.onBeforePlay(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player didPauseWithReason:(enum JWPauseReason)reason
{
    if (self.onPause) {
        self.onPause(@{});
    }
    
    if (!_wasInterrupted) {
        _userPaused = YES;
    }
}

- (void)jwplayer:(id<JWPlayer>)player didBecomeIdleWithReason:(enum JWIdleReason)reason
{
    if (self.onIdle) {
        self.onIdle(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player isVisible:(BOOL)isVisible
{
    if (self.onVisible) {
        self.onVisible(@{@"visible": @(isVisible)});
    }
}

- (void)jwplayerContentWillComplete:(id<JWPlayer>)player
{
    if (self.onBeforeComplete) {
        self.onBeforeComplete(@{});
    }
}

- (void)jwplayerContentDidComplete:(id<JWPlayer>)player
{
    if (self.onComplete) {
        self.onComplete(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player didLoadPlaylistItem:(JWPlayerItem *)item at:(NSUInteger)index
{
    if (self.onPlaylistItem) {
//        NSString *file = @"";
//        NSString *mediaId = @"";
//        NSString *title = @"";
//        NSString *desc = @"";
//
////        if (item.file != nil) {
////            file = item.file;
////        }
//
//        if (item.mediaId != nil) {
//            mediaId = item.mediaId;
//        }
//
//        if (item.title != nil) {
//            title = item.title;
//        }
//
//        if (item.description != nil) {
//            desc = item.description;
//        }
//
//        NSMutableDictionary *itemDict = [[NSMutableDictionary alloc] init];
//        [itemDict setObject:file forKey:@"file"];
//        [itemDict setObject:mediaId forKey:@"mediaId"];
//        [itemDict setObject:title forKey:@"title"];
//        [itemDict setObject:desc forKey:@"desc"];
//        [itemDict setObject:[NSNumber numberWithInteger:index] forKey:@"index"];
        
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:item options:NSJSONWritingPrettyPrinted error: &error];
        
        self.onPlaylistItem(@{@"playlistItem": [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], @"index": [NSNumber numberWithInteger:index]});
    }
}

- (void)jwplayer:(id<JWPlayer>)player didLoadPlaylist:(NSArray<JWPlayerItem *> *)playlist
{
    if (self.onPlaylist) {
//        NSMutableArray<NSData*>* playlistArray = [[NSMutableArray alloc] init];
//
//        for (JWPlayerItem* item in playlist) {
//            NSError *error;
//            NSString *file = @"";
//            NSString *mediaId = @"";
//            NSString *title = @"";
//            NSString *desc = @"";
//
//    //        if (item.file != nil) {
//    //            file = item.file;
//    //        }
//
//            if (item.mediaId != nil) {
//                mediaId = item.mediaId;
//            }
//
//            if (item.title != nil) {
//                title = item.title;
//            }
//
//            if (item.description != nil) {
//                desc = item.description;
//            }
//
//            NSMutableDictionary *itemDict = [[NSMutableDictionary alloc] init];
//            [itemDict setObject:file forKey:@"file"];
//            [itemDict setObject:mediaId forKey:@"mediaId"];
//            [itemDict setObject:title forKey:@"title"];
//            [itemDict setObject:desc forKey:@"desc"];
//
//            NSData* data = [NSJSONSerialization dataWithJSONObject:itemDict options:NSJSONWritingPrettyPrinted error: &error];
//            [playlistArray addObject:data];
//        }
        
        NSError *error;
        NSData* data = [NSJSONSerialization dataWithJSONObject:playlist options:NSJSONWritingPrettyPrinted error: &error];
        
        self.onPlaylist(@{@"playlist": [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]});
    }
}

- (void)jwplayerPlaylistHasCompleted:(id<JWPlayer>)player
{
    if (self.onPlaylistComplete) {
        self.onPlaylistComplete(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player usesMediaType:(enum JWMediaType)type
{
    
}

- (void)jwplayer:(id<JWPlayer>)player seekedFrom:(NSTimeInterval)oldPosition to:(NSTimeInterval)newPosition
{
    if (self.onSeek) {
        self.onSeek(@{@"from": @(oldPosition), @"to": @(newPosition)});
    }
}

- (void)jwplayerHasSeeked:(id<JWPlayer>)player
{
    if (self.onSeeked) {
        self.onSeeked(@{});
    }
}

- (void)jwplayer:(id<JWPlayer>)player playbackRateChangedTo:(double)rate at:(NSTimeInterval)time
{
    
}

#pragma mark - JWPlayer Ad Delegate

- (void)jwplayer:(id _Nonnull)player adEvent:(JWAdEvent * _Nonnull)event {
    if (self.onAdEvent) {
        self.onAdEvent(@{@"client": @(event.client), @"type": @(event.type)});
    }
}

#pragma mark - JWPlayer Cast Delegate

- (void)castController:(JWCastController * _Nonnull)controller castingBeganWithDevice:(JWCastingDevice * _Nonnull)device {
    
}

- (void)castController:(JWCastController * _Nonnull)controller castingEndedWithError:(NSError * _Nullable)error {
    
}

- (void)castController:(JWCastController * _Nonnull)controller castingFailedWithError:(NSError * _Nonnull)error {
    
}

- (void)castController:(JWCastController * _Nonnull)controller connectedTo:(JWCastingDevice * _Nonnull)device {
    
}

- (void)castController:(JWCastController * _Nonnull)controller connectionFailedWithError:(NSError * _Nonnull)error {
    
}

- (void)castController:(JWCastController * _Nonnull)controller connectionRecoveredWithDevice:(JWCastingDevice * _Nonnull)device {
    
}

- (void)castController:(JWCastController * _Nonnull)controller connectionSuspendedWithDevice:(JWCastingDevice * _Nonnull)device {
    
}

- (void)castController:(JWCastController * _Nonnull)controller devicesAvailable:(NSArray<JWCastingDevice *> * _Nonnull)devices {
    
}

- (void)castController:(JWCastController * _Nonnull)controller disconnectedWithError:(NSError * _Nullable)error {
    
}

#pragma mark - JWPlayer AV Delegate

- (void)jwplayer:(id<JWPlayer> _Nonnull)player audioTrackChanged:(NSInteger)currentLevel {
    
}

- (void)jwplayer:(id<JWPlayer> _Nonnull)player audioTracksUpdated:(NSArray<JWMediaSelectionOption *> * _Nonnull)levels {
    
}

- (void)jwplayer:(id<JWPlayer> _Nonnull)player captionPresented:(NSArray<NSString *> * _Nonnull)caption at:(JWTimeData * _Nonnull)time {
    
}

- (void)jwplayer:(id<JWPlayer> _Nonnull)player captionTrackChanged:(NSInteger)index {
    
}

- (void)jwplayer:(id<JWPlayer> _Nonnull)player qualityLevelChanged:(NSInteger)currentLevel {
    
}

- (void)jwplayer:(id<JWPlayer> _Nonnull)player qualityLevelsUpdated:(NSArray<JWVideoSource *> * _Nonnull)levels {
    
}

- (void)jwplayer:(id<JWPlayer> _Nonnull)player updatedCaptionList:(NSArray<JWMediaSelectionOption *> * _Nonnull)options {
    
}

#pragma mark - JWPlayer Interruption handling

-(void)audioSessionInterrupted:(NSNotification*)note
{
    if ([note.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        NSLog(@"Interruption notification");
        
        if ([[note.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] isEqualToNumber:[NSNumber numberWithInt:AVAudioSessionInterruptionTypeBegan]]) {
            [self audioInterruptionsStarted:note];
        } else {
            [self audioInterruptionsEnded:note];
        }
    }
}

-(void)audioInterruptionsStarted:(NSNotification *)note {
    _wasInterrupted = YES;
    [self.playerViewController.player pause];
}

-(void)audioInterruptionsEnded:(NSNotification *)note {
    if (!_userPaused) { // && _backgroundAudioEnabled
        [self.playerViewController.player play];
    }
}

#pragma mark - UIViewController Transitioning Delegate

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source
{
    _pController = [[RNJWPlayerPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    return _pController;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _pController.jwSuperView = self.superview;
    
    CGRect f;
    if (@available(iOS 11.0, *)) {
        f = self.superview.superview.superview.superview.safeAreaLayoutGuide.layoutFrame;
    } else {
        // Fallback on earlier versions
    }
    
    CGRect superFrame = self.superview.frame;
    superFrame.origin.y = f.origin.y;
    
    _pController.superFrame = superFrame;
}

@end
