/*
 * macOS TurboModule registration for ffmpeg-kit-extended.
 *
 * The consuming React Native application receives this registration through
 * CocoaPods/autolinking. End users call FFmpegKitExtended.initialize() from
 * TypeScript; they do not create or register the C++ module manually.
 */

#import <Foundation/Foundation.h>
#import "FFmpegKitExtendedImpl.h"
#import <ReactCommon/CxxTurboModuleUtils.h>

@interface FFmpegKitExtendedOnLoad : NSObject
@end

@implementation FFmpegKitExtendedOnLoad

using namespace facebook::react;

+ (void)load
{
  registerCxxModuleToGlobalModuleMap(
      std::string(FFmpegKitExtendedImpl::kModuleName),
      [](std::shared_ptr<CallInvoker> jsInvoker) {
        return std::make_shared<FFmpegKitExtendedImpl>(jsInvoker);
      });
}

@end
