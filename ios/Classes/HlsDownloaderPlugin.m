#import "HlsDownloaderPlugin.h"
#if __has_include(<hls_downloader/hls_downloader-Swift.h>)
#import <hls_downloader/hls_downloader-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "hls_downloader-Swift.h"
#endif

@implementation HlsDownloaderPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftHlsDownloaderPlugin registerWithRegistrar:registrar];
}
@end
