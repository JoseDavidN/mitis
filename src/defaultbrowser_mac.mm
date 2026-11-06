#include "defaultbrowser.h"

#include <memory>

#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

bool macIsDefaultBrowser()
{
    NSURL *handler = [NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"https://example.com"]];
    return handler && [handler.URLByStandardizingPath.path isEqualToString:NSBundle.mainBundle.bundleURL.URLByStandardizingPath.path];
}

// El sistema pregunta por http (su ventana de confirmar); https y los archivos
// de páginas se piden después, ya sin preguntar
void macMakeDefaultBrowser(std::function<void()> done)
{
    NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
    NSURL *app = NSBundle.mainBundle.bundleURL;
    auto callback = std::make_shared<std::function<void()>>(std::move(done));
    [workspace setDefaultApplicationAtURL:app toOpenURLsWithScheme:@"http" completionHandler:^(NSError *) {
        [workspace setDefaultApplicationAtURL:app toOpenURLsWithScheme:@"https" completionHandler:^(NSError *) {
            [workspace setDefaultApplicationAtURL:app toOpenContentType:UTTypeHTML completionHandler:^(NSError *) {
                dispatch_async(dispatch_get_main_queue(), ^{ (*callback)(); });
            }];
        }];
    }];
}
