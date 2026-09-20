// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_share.h"

#import <UIKit/UIKit.h>
#include <QString>

static UIViewController *qupilPresenter()
{
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive)
            continue;
        for (UIWindow *candidate in windowScene.windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (!window && windowScene.windows.count > 0)
            window = windowScene.windows.firstObject;
        if (window)
            break;
    }
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController)
        controller = controller.presentedViewController;
    return controller;
}

bool qupilSharePdf(const QString &filePath, const QString &title, QString *errorMessage)
{
    if (filePath.isEmpty()) {
        if (errorMessage)
            *errorMessage = QStringLiteral("PDF path is empty.");
        return false;
    }

    NSString *path = filePath.toNSString();
    NSString *subject = title.toNSString();
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = qupilPresenter();
        if (!presenter)
            return;
        NSURL *url = [NSURL fileURLWithPath:path];
        UIActivityViewController *activity =
            [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                              applicationActivities:nil];
        activity.title = subject;
        UIPopoverPresentationController *popover = activity.popoverPresentationController;
        if (popover) {
            popover.sourceView = presenter.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                            CGRectGetMidY(presenter.view.bounds), 1, 1);
            popover.permittedArrowDirections = 0;
        }
        [presenter presentViewController:activity animated:YES completion:nil];
    });
    return true;
}
