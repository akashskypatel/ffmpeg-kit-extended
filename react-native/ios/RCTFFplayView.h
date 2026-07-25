#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Native iOS rendering surface behind the public React Native `FFplayView`.
 *
 * Applications size and position it with normal React Native view styles. Mount
 * the view before starting video playback; audio-only FFplay sessions do not
 * require it. The implementation preserves aspect ratio and displays a black
 * background where letterboxing is needed.
 */
@interface RCTFFplayView : RCTViewComponentView
@end

NS_ASSUME_NONNULL_END
