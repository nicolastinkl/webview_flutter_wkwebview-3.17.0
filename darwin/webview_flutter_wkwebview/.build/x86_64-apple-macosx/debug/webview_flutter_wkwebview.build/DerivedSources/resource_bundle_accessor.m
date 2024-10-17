#import <Foundation/Foundation.h>

NSBundle* webview_flutter_wkwebview_SWIFTPM_MODULE_BUNDLE() {
    NSURL *bundleURL = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"webview_flutter_wkwebview_webview_flutter_wkwebview.bundle"];

    NSBundle *preferredBundle = [NSBundle bundleWithURL:bundleURL];
    if (preferredBundle == nil) {
      return [NSBundle bundleWithPath:@"/Users/zeus/Documents/GitHub/webview_flutter_wkwebview_zeus/darwin/webview_flutter_wkwebview/.build/x86_64-apple-macosx/debug/webview_flutter_wkwebview_webview_flutter_wkwebview.bundle"];
    }

    return preferredBundle;
}