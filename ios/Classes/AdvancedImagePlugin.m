#import "AdvancedImagePlugin.h"
#if __has_include(<advanced_image/advanced_image-Swift.h>)
#import <advanced_image/advanced_image-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "advanced_image-Swift.h"
#endif

@implementation AdvancedImagePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAdvancedImagePlugin registerWithRegistrar:registrar];
}
@end
