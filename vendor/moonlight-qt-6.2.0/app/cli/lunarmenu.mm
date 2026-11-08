#import <AppKit/AppKit.h>
#include <functional>

static std::function<void()> quitLunar;
static std::function<void()> closeStream;
static NSMenu* lunarMenuBar;

@interface LunarStreamMenu : NSObject
- (void)quit:(id)sender;
- (void)close:(id)sender;
- (void)windowBecameKey:(NSNotification*)notification;
@end

@implementation LunarStreamMenu
- (void)quit:(id)sender { quitLunar(); }
- (void)close:(id)sender { closeStream(); }
- (void)windowBecameKey:(NSNotification*)notification {
    NSApp.mainMenu = lunarMenuBar;
    NSWindow* window = notification.object;
    if (window.title.length == 0 || (window.styleMask & NSWindowStyleMaskFullScreen)) return;
    window.styleMask |= NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    BOOL hasDisconnect = NO;
    for (NSTitlebarAccessoryViewController* accessory in window.titlebarAccessoryViewControllers) {
        if ([accessory.view.identifier isEqualToString:@"LunarDisconnect"]) hasDisconnect = YES;
    }
    if (!hasDisconnect) {
        auto accessory = [NSTitlebarAccessoryViewController new];
        auto view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 108, 28)];
        view.identifier = @"LunarDisconnect";
        auto button = [NSButton buttonWithTitle:@"Disconnect" target:self action:@selector(close:)];
        button.frame = NSMakeRect(0, 2, 102, 24);
        button.toolTip = @"End this stream and keep the remote desktop running.";
        button.accessibilityLabel = @"Disconnect stream";
        [view addSubview:button];
        accessory.view = view;
        accessory.layoutAttribute = NSLayoutAttributeRight;
        [window addTitlebarAccessoryViewController:accessory];
    }
    for (NSNumber* type in @[@(NSWindowCloseButton), @(NSWindowMiniaturizeButton), @(NSWindowZoomButton)]) {
        NSButton* button = [window standardWindowButton:(NSWindowButton)type.integerValue];
        button.hidden = NO;
        button.enabled = YES;
    }
}
@end

void installLunarMenu(std::function<void()> quit, std::function<void()> close)
{
    quitLunar = std::move(quit);
    closeStream = std::move(close);
    static LunarStreamMenu* target = [LunarStreamMenu new];
    [[NSNotificationCenter defaultCenter] addObserver:target selector:@selector(windowBecameKey:)
                                               name:NSWindowDidBecomeKeyNotification object:nil];
    auto bar = [NSMenu new];
    auto appItem = [NSMenuItem new];
    auto appMenu = [[NSMenu alloc] initWithTitle:@"Lunar"];
    auto quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Lunar" action:@selector(quit:) keyEquivalent:@"q"];
    quitItem.target = target;
    [appMenu addItemWithTitle:@"Hide Lunar" action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:quitItem];
    appItem.submenu = appMenu;
    [bar addItem:appItem];
    auto fileItem = [NSMenuItem new];
    auto fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    auto closeItem = [[NSMenuItem alloc] initWithTitle:@"Close Stream" action:@selector(close:) keyEquivalent:@"w"];
    closeItem.target = target;
    [fileMenu addItem:closeItem];
    fileItem.submenu = fileMenu;
    [bar addItem:fileItem];
    lunarMenuBar = bar;
    NSApp.mainMenu = bar;
}
