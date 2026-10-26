#import "TangerineVlcPlugin.h"
#import <MobileVLCKit/MobileVLCKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <math.h>

@interface TangerineVlcSession : NSObject<FlutterPlatformView>
@property(nonatomic,strong) VLCMediaPlayer *player;
@property(nonatomic,strong) UIView *surface;
@property(nonatomic) BOOL resumeAfterInterruption;
@end
@implementation TangerineVlcSession
- (UIView *)view { return self.surface; }
- (instancetype)init {
  if((self=[super init])) {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:AVAudioSession.sharedInstance];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(routeChanged:) name:AVAudioSessionRouteChangeNotification object:AVAudioSession.sharedInstance];
  } return self;
}
- (void)interrupted:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(),^{
    NSUInteger type=[notification.userInfo[AVAudioSessionInterruptionTypeKey]unsignedIntegerValue];
    if(type==AVAudioSessionInterruptionTypeBegan){ self.resumeAfterInterruption=self.player.isPlaying;[self.player pause]; }
    else {BOOL resume=self.resumeAfterInterruption&&([notification.userInfo[AVAudioSessionInterruptionOptionKey]unsignedIntegerValue]&AVAudioSessionInterruptionOptionShouldResume);self.resumeAfterInterruption=NO;NSError *error=nil;if(resume&&[AVAudioSession.sharedInstance setActive:YES error:&error])[self.player play];}
  });
}
- (void)routeChanged:(NSNotification*)notification {
  if([notification.userInfo[AVAudioSessionRouteChangeReasonKey]unsignedIntegerValue]==AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
    dispatch_async(dispatch_get_main_queue(),^{self.resumeAfterInterruption=NO;[self.player pause];});
}
- (void)close {self.resumeAfterInterruption=NO;[NSNotificationCenter.defaultCenter removeObserver:self];[_player stop];_player.drawable=nil;_player=nil;}
- (void)dealloc { [self close]; }
@end
@interface TangerineRouteView:NSObject<FlutterPlatformView>
@property(nonatomic,strong) AVRoutePickerView *picker;
@end
@implementation TangerineRouteView
- (UIView*)view {return self.picker;}
@end

@implementation TangerineVlcPlugin {
  NSMutableDictionary<NSNumber*,TangerineVlcSession*> *_sessions;
  NSInteger _serial;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  TangerineVlcPlugin *plugin=[TangerineVlcPlugin new];
  plugin->_sessions=[NSMutableDictionary new];
  FlutterMethodChannel *channel=[FlutterMethodChannel methodChannelWithName:@"tangerine/playback" binaryMessenger:registrar.messenger];
  [registrar addMethodCallDelegate:plugin channel:channel];
  [registrar registerViewFactory:plugin withId:@"tangerine/vlc-video"];
  [registrar registerViewFactory:plugin withId:@"tangerine/vlc-route-picker"];
}
- (NSObject<FlutterMessageCodec> *)createArgsCodec { return [FlutterStandardMessageCodec sharedInstance]; }
- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id)args {
  if([args[@"routePicker"]boolValue]) {TangerineRouteView *route=[TangerineRouteView new];route.picker=[[AVRoutePickerView alloc]initWithFrame:frame];route.picker.prioritizesVideoDevices=NO;return route;}
  TangerineVlcSession *session=_sessions[args[@"id"]];
  if(!session) {session=[TangerineVlcSession new];session.surface=[[UIView alloc]initWithFrame:frame];}
  session.surface.frame=frame;
  return session;
}
- (NSArray*)capabilities { return @[@"transport",@"tracks",@"chapters",@"equalizer",@"aspect",@"crop",@"zoom",@"deinterlace",@"brightness",@"contrast",@"saturation",@"gamma",@"hue",@"audioDelay",@"subtitleDelay",@"diagnostics",@"routePicker"]; }
- (NSArray*)tracks:(NSArray*)indexes names:(NSArray*)names {
  NSMutableArray *rows=[NSMutableArray new];
  for(NSUInteger i=0;i<MIN(indexes.count,128);i++) [rows addObject:@{@"id":indexes[i],@"title":i<names.count?names[i]:@"Track"}];
  return rows;
}
- (double)number:(NSDictionary*)args key:(NSString*)key {
  id value=args[key];
  if(![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue])) @throw [NSException exceptionWithName:@"Argument" reason:@"Invalid numeric player value" userInfo:nil];
  return [value doubleValue];
}
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
 @try {
  NSDictionary *a=[call.arguments isKindOfClass:NSDictionary.class]?call.arguments:@{};
  if([call.method isEqual:@"preferences.catalog"]) { result(@[]); return; }
  if([call.method isEqual:@"create"]) {
    TangerineVlcSession *s=[TangerineVlcSession new];
    s.surface=[[UIView alloc]initWithFrame:CGRectMake(0,0,640,360)]; s.surface.backgroundColor=UIColor.blackColor;
    NSMutableArray *options=[NSMutableArray arrayWithObjects:@"--no-video-title-show",@"--avcodec-hw=none",nil];
    NSDictionary *allowed=@{@"fileCache":@"file-caching",@"networkCache":@"network-caching",@"audioLanguage":@"audio-language",@"subtitleLanguage":@"sub-language",@"encoding":@"subsdec-encoding"};
    NSDictionary *prefs=a[@"preferences"];
    for(NSString *key in allowed) { NSString *v=prefs[key]; if([v isKindOfClass:NSString.class]&&v.length<=256&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound) [options addObject:[NSString stringWithFormat:@"--%@=%@",allowed[key],v]]; }
    s.player=[[VLCMediaPlayer alloc]initWithOptions:options];
    if(!s.player){result([FlutterError errorWithCode:@"LIBVLC_RUNTIME" message:@"VideoLAN could not initialize this player." details:nil]);return;}
    s.player.drawable=s.surface;
    NSNumber *identity=@(++_serial); _sessions[identity]=s;
    result(@{@"id":identity,@"capabilities":[self capabilities]}); return;
  }
  NSNumber *identity=a[@"id"]; TangerineVlcSession *s=_sessions[identity];
  if(!s) { result([FlutterError errorWithCode:@"PLAYER_CLOSED" message:@"Native player has closed" details:nil]); return; }
  VLCMediaPlayer *p=s.player; NSString *method=call.method;
  if([method isEqual:@"dispose"]) { [s close]; [_sessions removeObjectForKey:identity]; result(nil); return; }
  if([method isEqual:@"open"]) {
    NSURL *url=[NSURL URLWithString:a[@"uri"]];
    if(![@[@"file",@"http",@"https",@"rtsp",@"rtmp",@"udp",@"rtp",@"srt"] containsObject:url.scheme.lowercaseString]) @throw [NSException exceptionWithName:@"Media" reason:@"Unsupported media address" userInfo:nil];
    NSError *error=nil; [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:&error];
    if(error) { result([FlutterError errorWithCode:@"AUDIO_SESSION" message:error.localizedDescription details:nil]); return; }
    if(![[AVAudioSession sharedInstance]setActive:YES error:&error]) { result([FlutterError errorWithCode:@"AUDIO_SESSION" message:error.localizedDescription details:nil]);return; }
    [p stop]; p.media=[VLCMedia mediaWithURL:url]; [p play];
  } else if([method isEqual:@"state"]) {
    result(@{@"position":@(MAX(0,p.time.intValue)),@"duration":@(MAX(0,p.media.length.intValue)),@"playing":@(p.isPlaying),
      @"completed":@(p.state==VLCMediaPlayerStateEnded),@"buffering":@(p.state==VLCMediaPlayerStateBuffering),@"error":@(p.state==VLCMediaPlayerStateError),
      @"volume":@(p.audio.volume),@"rate":@(p.rate),@"width":@(p.videoSize.width),@"height":@(p.videoSize.height),
      @"audio":[self tracks:p.audioTrackIndexes names:p.audioTrackNames],@"subtitles":[self tracks:p.videoSubTitlesIndexes names:p.videoSubTitlesNames],
      @"audioTrack":@(p.currentAudioTrackIndex),@"subtitleTrack":@(p.currentVideoSubTitleIndex),@"chapter":@(p.currentChapterIndex),@"chapters":@([p numberOfChaptersForTitle:-1]),
      @"metadata":@{@"Title":[p.media metadataForKey:VLCMetaInformationTitle]?:@"",@"Artist":[p.media metadataForKey:VLCMetaInformationArtist]?:@"",@"Album":[p.media metadataForKey:VLCMetaInformationAlbum]?:@""},@"statistics":p.media.stats?:@{},@"version":@"VideoLAN MobileVLCKit 3.6.0",@"capabilities":[self capabilities]}); return;
  } else if([method isEqual:@"play"]) {NSError *error=nil;if(![AVAudioSession.sharedInstance setActive:YES error:&error]){result([FlutterError errorWithCode:@"AUDIO_SESSION" message:error.localizedDescription details:nil]);return;}[p play];}
  else if([method isEqual:@"pause"]) {s.resumeAfterInterruption=NO;[p pause];}
  else if([method isEqual:@"seek"]) p.time=[VLCTime timeWithNumber:@(MAX(0,[self number:a key:@"value"]))];
  else if([method isEqual:@"rate"]) { double v=[self number:a key:@"value"]; if(v<.25||v>4) @throw [NSException exceptionWithName:@"Rate" reason:@"Invalid rate" userInfo:nil]; p.rate=v; }
  else if([method isEqual:@"volume"]) p.audio.volume=MAX(0,MIN(100,[self number:a key:@"value"]));
  else if([method isEqual:@"audioTrack"]) p.currentAudioTrackIndex=[self number:a key:@"value"];
  else if([method isEqual:@"subtitleTrack"]) p.currentVideoSubTitleIndex=[self number:a key:@"value"];
  else if([method isEqual:@"subtitle"]) { if([p addPlaybackSlave:[NSURL fileURLWithPath:a[@"value"]] type:VLCMediaPlaybackSlaveTypeSubtitle enforce:YES]!=0) @throw [NSException exceptionWithName:@"Subtitle" reason:@"Subtitle could not load" userInfo:nil]; }
  else if([method isEqual:@"chapter"]) p.currentChapterIndex=MAX(0,[self number:a key:@"value"]);
  else if([method isEqual:@"picture"]) {
    for(NSString *key in @[@"brightness",@"contrast",@"saturation",@"gamma",@"hue"]) if(a[key]) { p.adjustFilterEnabled=YES; [p setValue:a[key] forKey:key]; }
    if(a[@"aspect"]) p.videoAspectRatio=(char*)[a[@"aspect"]UTF8String];
    if(a[@"crop"]) p.videoCropGeometry=(char*)[a[@"crop"]UTF8String];
    if(a[@"zoom"]) p.scaleFactor=MAX(0,MIN(5,[self number:a key:@"zoom"]));
    if(a[@"deinterlaceMode"]) [p setDeinterlaceFilter:[a[@"deinterlaceMode"]isEqual:@"off"]?nil:a[@"deinterlaceMode"]];
    if(a[@"audioDelay"]) p.currentAudioPlaybackDelay=[self number:a key:@"audioDelay"]*1000000;
    if(a[@"subtitleDelay"]) p.currentVideoSubTitleDelay=[self number:a key:@"subtitleDelay"]*1000000;
  } else if([method isEqual:@"equalizer"]) {
    if(![a[@"enabled"]boolValue]) p.equalizer=nil;
    else { VLCAudioEqualizer *eq=[VLCAudioEqualizer new]; eq.preAmplification=MAX(-20,MIN(20,[self number:a key:@"preamp"])); NSArray *bands=a[@"bands"]; for(NSUInteger i=0;i<MIN(eq.bands.count,bands.count);i++) eq.bands[i].amplification=MAX(-20,MIN(20,[bands[i]floatValue])); p.equalizer=eq; }
  } else { result(FlutterMethodNotImplemented); return; }
  result(nil);
 } @catch(NSException *e) { result([FlutterError errorWithCode:@"LIBVLC" message:e.reason details:nil]); }
}
@end
