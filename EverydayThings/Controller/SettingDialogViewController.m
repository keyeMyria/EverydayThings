//
//  SettingDialogViewController.m
//  EverydayThings
//
//  Created by Daisuke Hirata on 2014/04/24.
//  Copyright (c) 2014 Daisuke Hirata. All rights reserved.
//

#import "SettingDialogViewController.h"
#import "SearchAddressViewController.h"
#import "GeoFenceMonitoringLocationReloadNotification.h"
#import "UpdateApplicationBadgeNumberNotification.h"
#import "EditItemCategoryTableViewController.h"
#import "AAMFeedbackViewController.h"
#import "FAKFontAwesome.h"

#define APP_ID 385862462 //id from iTunesConnect

@interface SettingDialogViewController ()
@property (nonatomic, strong) UIImageView *ribbonView;
@end

@implementation SettingDialogViewController

#define WeakSelf __weak __typeof__(self)

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        QRootElement *_root = [[QRootElement alloc] init];
        _root.grouped = YES;
        _root.title = @"Setting";
        self.root = _root;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    
    //
    // category
    //
    QSection *categorySection = [[QSection alloc] initWithTitle:@"Item Category"];
    QButtonElement *categoryButton = [[QButtonElement alloc] initWithTitle:@"Edit Category"];
    WeakSelf weakSelf = self;
    categoryButton.onSelected = ^{
        EditItemCategoryTableViewController *editItemCategoryTableViewController =
        [[weakSelf storyboard] instantiateViewControllerWithIdentifier:@"EditItemCategoryTableViewController"];
        [weakSelf.navigationController pushViewController:editItemCategoryTableViewController animated:YES];
    };

    categoryButton.key = @"category";

    
    //
    // geofence
    //
    BOOL geofenceValue = [defaults boolForKey:@"geofence"];
    QSection *locationServiceSection = [[QSection alloc] initWithTitle:@"Location Service"];
    locationServiceSection.footer = @"Turn Location Services on when using Geofence functionality. Turn Wifi on for more accurate location service.";
    QBooleanElement *geofence = [[QBooleanElement alloc] initWithTitle:@"Use Geofence"
                                                             BoolValue:geofenceValue ? geofenceValue : NO];
    geofence.onSelected = ^{
        QBooleanElement *geofence = (QBooleanElement *)[[self root] elementWithKey:@"geofence"];
        [defaults setBool:geofence.boolValue forKey:@"geofence"];
        [defaults synchronize];
        // geofence region changed.
        [[NSNotificationCenter defaultCenter] postNotificationName:GeofenceMonitoringLocationReloadNotification
                                                            object:self
                                                          userInfo:nil];
    };
    geofence.image = [FAKFontAwesome imageWithIconName:@"locationArrow"];
    geofence.key = @"geofence";

    
    //
    // badge
    //
    BOOL baddeValue = [defaults boolForKey:@"badge"];
    QSection *homeScreenSection = [[QSection alloc] initWithTitle:@"Home Screen"];
    QBooleanElement *badge = [[QBooleanElement alloc] initWithTitle:@"Show App Badge"
                                                          BoolValue:baddeValue ? baddeValue : NO];
    badge.onSelected = ^{
        QBooleanElement *badge = (QBooleanElement *)[[self root] elementWithKey:@"badge"];
        [defaults setBool:badge.boolValue forKey:@"badge"];
        [defaults synchronize];
        // update application badge
        [[NSNotificationCenter defaultCenter] postNotificationName:UpdateApplicationBadgeNumberNotification
                                                            object:self
                                                          userInfo:nil];
    };
    badge.key = @"badge";

    
    //
    // Feedback
    //
    QSection *feedbackSection = [[QSection alloc] initWithTitle:@"Feedback"];
    QButtonElement *rateThisAppButton = [[QButtonElement alloc] initWithTitle:@"Rate & Write a Review"];
    rateThisAppButton.onSelected = ^{
        NSString *reviewURL = [NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%d", APP_ID];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:reviewURL]];
    };
    rateThisAppButton.image = [FAKFontAwesome imageWithIconName:@"apple"];
    QButtonElement *emailButton = [[QButtonElement alloc] initWithTitle:@"Mail to a developer"];
    emailButton.onSelected = ^{
        AAMFeedbackViewController *aamFeedbackViewController = [[AAMFeedbackViewController alloc] init];
        aamFeedbackViewController.toRecipients = [NSArray arrayWithObject:@"daisukihirata@gmail.com"];
        [weakSelf.navigationController pushViewController:aamFeedbackViewController animated:YES];
    };
    emailButton.image = [FAKFontAwesome imageWithIconName:@"envelopeO"];
    NSString *version = [NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    QLabelElement *versionElement  = [[QLabelElement alloc] initWithTitle:@"Version" Value:version];

    
    [self.root addSection:categorySection];
    [categorySection addElement:categoryButton];
    
    [self.root addSection:locationServiceSection];
    [locationServiceSection addElement:geofence];
    
    [self.root addSection:homeScreenSection];
    [homeScreenSection addElement:badge];
    
    [self.root addSection:feedbackSection];
    [feedbackSection addElement:rateThisAppButton];
    [feedbackSection addElement:emailButton];
    [feedbackSection addElement:versionElement];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    self.tabBarController.tabBar.hidden = NO;
    [[[UIApplication sharedApplication] keyWindow] addSubview:self.ribbonView];
    [super viewWillAppear:animated];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.ribbonView removeFromSuperview];
    self.ribbonView = nil;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.ribbonView removeFromSuperview];
    self.ribbonView = nil;
    [[[UIApplication sharedApplication] keyWindow] addSubview:self.ribbonView];
}

- (UIImageView *)ribbonView
{
    if (!_ribbonView) {
        
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        
        UIImage *image = [UIImage imageNamed:@"orange_ribbon"];
        CGFloat imgLen = 100.0f;
        
        CGRect rect;
        if (UIInterfaceOrientationLandscapeLeft == orientation) {
            CGRect mainRect = [[UIScreen mainScreen] bounds];
            rect = CGRectMake(0.0f, mainRect.size.height-imgLen, imgLen, imgLen);
            image = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:UIImageOrientationLeft];
        } else if (UIInterfaceOrientationLandscapeRight == orientation) {
            CGRect mainRect = [[UIScreen mainScreen] bounds];
            rect = CGRectMake(mainRect.size.width-imgLen, 0.0f, imgLen, imgLen);
            image = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:UIImageOrientationRight];
        } else {
            // normal portrait
            rect = CGRectMake(0.0f, 0.0f, imgLen, imgLen);
        }
        _ribbonView = [[UIImageView alloc] initWithImage:image];
        _ribbonView.frame = rect;
    }
    return _ribbonView;
}

@end
