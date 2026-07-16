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
