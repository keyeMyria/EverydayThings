//
//  ItemDialogViewController.m
//  EverydayThings
//
//  Created by Daisuke Hirata on 2014/04/25.
//  Copyright (c) 2014 Daisuke Hirata. All rights reserved.
//

#import "ItemDialogViewController.h"
#import "Item+Helper.h"
#import "ItemCategory+Helper.h"
#import "SearchAddressViewController.h"
#import "JANCodeReaderViewController.h"
#import "GeoFenceLocationSaveNotification.h"
#import "FAKFontAwesome.h"
#import "AmazonItem.h"

@interface ItemDialogViewController () <QuickDialogEntryElementDelegate>

// top
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *category;

// cycle t  o supply
@property (nonatomic)         BOOL stock;
@property (nonatomic, copy)   NSString *cycle;
@property(nonatomic, strong)  NSDate *lastPurchaseDate;

// geofence
@property (nonatomic)         BOOL geofence;
@property (nonatomic, copy)   NSString *location;

@property (nonatomic, strong) NSMutableDictionary *values;
@property (nonatomic, copy)   NSString *itemId;
@property (nonatomic, strong) NSNumber *latitude;
@property (nonatomic, strong) NSNumber *longitude;

@end

@implementation ItemDialogViewController

#pragma mark - view controller life cycle

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        QRootElement *_root = [[QRootElement alloc] init];
        _root.grouped = YES;
        _root.title = @"New Item";
        self.root = _root;
        self.resizeWhenKeyboardPresented =YES;
        UIBarButtonItem* saveItem = [[UIBarButtonItem alloc]  initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                   target:self
                                                                                   action:@selector(save:)];
        self.navigationItem.leftBarButtonItem = saveItem;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    if (self.item) {
        // update item
        self.root.title = self.item.name;
        self.itemId     = self.item.itemId;
        self.latitude   = self.item.latitude;
        self.longitude  = self.item.longitude;
    } else {
        // new item
        // add barcode button at left side.
        UIImage *image = [UIImage imageWithStackedIcons:@[[FAKFontAwesome barcodeIconWithSize:20]]
                                              imageSize:CGSizeMake(20, 20)];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:image
                                                                                  style:UIBarButtonItemStyleBordered
                                                                                 target:self
                                                                                action:@selector(barcode)];
    }

    [self createQuickDialogElementsWithItem:self.item];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:GeofenceLocationSaveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      NSDictionary *info = note.userInfo[GeofenceLocationSaveNotificationItem];
                                                      NSLog(@"location done %@", info[@"location"]);
                                                      self.location  = info[@"location"];
                                                      self.latitude  = info[@"latitude"];
                                                      self.longitude = info[@"longitude"];
                                                  }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.tabBarController.tabBar.hidden = YES;
    
    if (self.amazonItem) {
        if ([[ItemCategory categories] indexOfObject:self.amazonItem.category] == NSNotFound) {
            [ItemCategory itemCategoryWithName:self.amazonItem.category];
            [self reloadSectionTop];
        }
        self.name          = self.amazonItem.title;
        self.category      = self.amazonItem.category;
    }
}

#pragma mark - create dialog elements

- (void)createQuickDialogElementsWithItem:(Item *)item
{
    //
    // General section
    //
    QSection *sectionTop = [[QSection alloc] init];
    [self.root addSection:sectionTop];
    [sectionTop addElement:[self createNameEntryElement]];
    [sectionTop addElement:[self createCategoryRadioElement]];
    [sectionTop addElement:[self createBuyNowBooleanElement]];
    
    
    //
    // Cycle to resupply section
    //
    QSection *sectionCycleToResuplly = [[QSection alloc] initWithTitle:@"Cycle to supply"];
    sectionCycleToResuplly.footer = @"CYCLE TO SUPPLY helps you recognize an approximate time to supply this item based on a consumption cycle, avoid stockout items.";
    [self.root addSection:sectionCycleToResuplly];
    [sectionCycleToResuplly addElement:[self createStockBooleanElement]];
    if (self.item && [self.item.stock boolValue]) {
        [sectionCycleToResuplly addElement:[self createCycleEntryElement]];
        [sectionCycleToResuplly addElement:[self createtimeSpanRadioElement]];
        [sectionCycleToResuplly addElement:[self createlastPurchaseDateTimeInlineElement]];
    }
    
    
    //
    // Due date section
    //
    QSection *sectionDueDate = [[QSection alloc] initWithTitle:@"Due Date"];
    sectionDueDate.footer = @"This item will be shown in a Due date Tab, when a due date is coming within a month.";
    [self.root addSection:sectionDueDate];
    [sectionDueDate addElement:[self createDueDateDateTimeInlineElement]];
    
    
    //
    // Geofence
    //
    QSection *sectionGeofence = [[QSection alloc] initWithTitle:@"Geofence"];
    sectionGeofence.footer = @"Geofence reminds you only when BuyNow items you have is at the nearby location. Set a location you buy this item.";
    [self.root addSection:sectionGeofence];
    [sectionGeofence addElement:[self createGeofenceBooleanElement]];
    if (self.item && [self.item.geofence boolValue]) {
        [sectionGeofence addElement:[self createLocationButtonWithLabelElement]];
    }
    
    //
    // Memo
    //
    QSection *sectionMemo = [[QSection alloc] initWithTitle:@"Memo"];
    [self.root addSection:sectionMemo];
    [sectionMemo addElement:[self createMemoMultilineElement]];
    
}

#pragma mark - Create QuickDialog Element

#define WeakSelf __weak __typeof__(self)

- (QEntryElement *)createNameEntryElement
{
    QEntryElement *name;
    name = [[QEntryElement alloc] initWithTitle:@"Name"
                                          Value:self.item ? self.item.name : @""
                                    Placeholder:@"Enter name"];
    name.appearance.entryAlignment = NSTextAlignmentRight;
    name.key = @"name";
    return name;
}

- (QFontAwesomeRadioElement *)createCategoryRadioElement
{
    QFontAwesomeRadioElement *category;
    NSArray *categories = [ItemCategory categories];
    category = [[QFontAwesomeRadioElement alloc] initWithItems:categories
                                                      selected:self.item ? [categories indexOfObject:self.item.whichItemCategory.name] : 0
                                                         title:@"Category"];
    category.key = @"category";
    category.itemsImageNames = [ItemCategory iconNameWithCategoryName:categories];
    return category;
}

- (QBooleanElement *)createBuyNowBooleanElement
{
    QBooleanElement *buyNow;
    buyNow = [[QBooleanElement alloc] initWithTitle:@"Buy Now"
                                          BoolValue:self.item ? [self.item.buyNow boolValue] : NO];
    buyNow.key = @"buyNow";
    buyNow.image = [FAKFontAwesome imageWithIconName:@"shoppingCart"];
    return buyNow;
}

- (QButtonElement *)createPhotoButtonElement
{
    QButtonElement *photo;
    photo = [[QButtonElement alloc] initWithTitle:@"Photo"];
    photo.key = @"photo";
    photo.image = [UIImage imageWithStackedIcons:@[[FAKFontAwesome barcodeIconWithSize:20]]
                                       imageSize:CGSizeMake(20, 20)];
    photo.onSelected =  ^{
        NSLog(@"photo pushed");
    };
    return photo;
}

- (QBooleanElement *)createStockBooleanElement
{
    QBooleanElement * stock;
    stock = [[QBooleanElement alloc] initWithTitle:@"Stock"
                                         BoolValue:self.item ? [self.item.stock boolValue] : NO];
    stock.key = @"stock";
    stock.image = [FAKFontAwesome imageWithIconName:@"repeat"];
    WeakSelf weakSelf = self;
    stock.onSelected = ^{
        [weakSelf reloadSectionCycleToResuplly:weakSelf.stock];
        if (weakSelf.stock && !weakSelf.lastPurchaseDate) {
            weakSelf.lastPurchaseDate = [NSDate date];
        }
    };
    
    return stock;
}

- (QEntryElement *)createCycleEntryElement
{
    QEntryElement *cycle;
    cycle = [[QEntryElement alloc] initWithTitle:@"Cycle"
                                           Value:self.item ? [self.item.cycle stringValue] : @""
                                     Placeholder:@""];
    cycle.key = @"cycle";
    cycle.appearance.entryAlignment = NSTextAlignmentRight;
    cycle.keyboardType = UIKeyboardTypeNumberPad;
    return cycle;
}

- (QRadioElement *)createtimeSpanRadioElement
{
    QRadioElement *timeSpan;
    timeSpan = [[QRadioElement alloc] initWithItems:[Item timeSpans]
                                           selected:self.item ? [[Item timeSpans] indexOfObject:self.item.timeSpan] : 0
                                              title:@"Time Span"];
    timeSpan.key = @"timeSpan";
    return timeSpan;
}

- (QDateTimeInlineElement *)createlastPurchaseDateTimeInlineElement
{
    QDateTimeInlineElement *lastPurchaseDate;
    lastPurchaseDate = [[QDateTimeInlineElement alloc] initWithTitle:@"Last Purchase Date"
                                                                date:self.item ? self.item.lastPurchaseDate : nil
                                                             andMode:UIDatePickerModeDate];
    lastPurchaseDate.key = @"lastPurchaseDate";
    return lastPurchaseDate;
}

- (QDateTimeInlineElement *)createDueDateDateTimeInlineElement
{
    QDateTimeInlineElement *dueDate;
    dueDate = [[QDateTimeInlineElement alloc] initWithTitle:@"Due Date"
                                                       date:self.item ? self.item.dueDate : nil
                                                    andMode:UIDatePickerModeDate];
    dueDate.key = @"dueDate";
    dueDate.image = [FAKFontAwesome imageWithIconName:@"calendar"];
    return dueDate;
}

- (QBooleanElement *)createGeofenceBooleanElement
{
    QBooleanElement *geofence;
    geofence = [[QBooleanElement alloc] initWithTitle:@"Geofence"
                                            BoolValue:self.item ? [self.item.geofence boolValue] : NO];
    geofence.key = @"geofence";
    geofence.image = [FAKFontAwesome imageWithIconName:@"locationArrow"];
    WeakSelf weakSelf = self;
    geofence.onSelected = ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL globalGeofence = [defaults boolForKey:@"geofence"];
        if (weakSelf.geofence && !globalGeofence) {
            [weakSelf showAlert:@"Please enable Geofence in a Setting tab first."];
            weakSelf.geofence = NO;
        }
        [weakSelf reloadSectionGeofence:weakSelf.geofence];
    };
    return geofence;
}

- (QButtonWithLabelElement *)createLocationButtonWithLabelElement
{
    QButtonWithLabelElement *location;
    location         = [[QButtonWithLabelElement alloc] initWithTitle:@"Location"];
    location.key     = @"location";
    location.value   = self.item ? self.item.location : @"";
    WeakSelf weakSelf = self;
    location.onSelected =  ^{
        SearchAddressViewController *searchAddressViewController =
        [[weakSelf storyboard] instantiateViewControllerWithIdentifier:@"SearchAddressViewController"];
        [weakSelf.navigationController pushViewController:searchAddressViewController animated:YES];
    };
    return location;
}

- (QMultilineElement *)createMemoMultilineElement
{
    QMultilineElement *memo = [[QMultilineElement alloc] initWithTitle:@"" value:@""];
    memo.placeholder = @"favorite, where to stock...";
    memo.delegate    = self;    // for sync. QuickDialogEntryElementDelegate
    memo.textValue   = self.item ? self.item.memo : @"";
    memo.key = @"memo";
    memo.image = [FAKFontAwesome imageWithIconName:@"pencil"];
    return memo;
}

- (void)reloadSectionTop
{
    QSection* sectionTop = [self.root getSectionForIndex:0];
    QFontAwesomeRadioElement *categoryElement = (QFontAwesomeRadioElement *)[self.root elementWithKey:@"category"];
    [sectionTop removeElement:categoryElement];
    [sectionTop insertElement:[self createCategoryRadioElement] atIndex:1];
    [self.quickDialogTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)reloadSectionCycleToResuplly:(BOOL)enabled
{
    QSection* sectionCycleToResuplly = [self.root getSectionForIndex:1];

    if (enabled) {
        [sectionCycleToResuplly insertElement:[self createCycleEntryElement] atIndex:1];
        [sectionCycleToResuplly insertElement:[self createtimeSpanRadioElement] atIndex:2];
        [sectionCycleToResuplly insertElement:[self createlastPurchaseDateTimeInlineElement] atIndex:3];
    } else {
        QEntryElement *cycle = (QEntryElement *)[self.root elementWithKey:@"cycle"];
        QRadioElement *timeSpan = (QRadioElement *)[self.root elementWithKey:@"timeSpan"];
        QDateTimeInlineElement *lastPurchaseDate = (QDateTimeInlineElement *)[self.root elementWithKey:@"lastPurchaseDate"];
        [sectionCycleToResuplly removeElement:cycle];
        [sectionCycleToResuplly removeElement:timeSpan];
        [sectionCycleToResuplly removeElement:lastPurchaseDate];
    }
    
    [self.quickDialogTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)reloadSectionGeofence:(BOOL)enabled
{
    QSection* sectionGeofence = [self.root getSectionForIndex:3];
    
    if (enabled) {
        [sectionGeofence insertElement:[self createLocationButtonWithLabelElement] atIndex:1];
    } else {
        QButtonWithLabelElement *location = (QButtonWithLabelElement *)[self.root elementWithKey:@"location"];
        [sectionGeofence removeElement:location];
    }
    
    [self.quickDialogTableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - QuickDialogEntryElementDelegate

// this is for multiline text

- (void)QEntryEditingChangedForElement:(QEntryElement *)element andCell:(QEntryTableViewCell *)cell {
    cell.textField.text = element.textValue;
    [cell setNeedsLayout];
}

#pragma mark - quick dialog element property getter & setter

@synthesize name = _name;
@synthesize location = _location;
@synthesize geofence = _geofence;

- (NSString *)name
{
    QEntryElement *nameElement = (QEntryElement *)[self.root elementWithKey:@"name"];
    return nameElement.textValue;
}

- (void)setName:(NSString *)name
{
    QEntryElement *nameElement = (QEntryElement *)[self.root elementWithKey:@"name"];
    nameElement.textValue = name;
    [self.quickDialogTableView reloadCellForElements:nameElement, nil];
}

- (void)setCategory:(NSString *)category
{
    // get category index
    [ItemCategory itemCategoryWithName:category];
    NSArray *categories = [ItemCategory categories];
    NSUInteger index = [categories indexOfObject:category];
    
    QFontAwesomeRadioElement *categoryElement = (QFontAwesomeRadioElement *)[self.root elementWithKey:@"category"];
    categoryElement.selected = index;
    [self.quickDialogTableView reloadCellForElements:categoryElement, nil];
}

- (BOOL)stock
{
    QBooleanElement *stockElement = (QBooleanElement *)[self.root elementWithKey:@"stock"];
    return stockElement.boolValue;
}

- (NSString *)cycle
{
    QEntryElement *cycleElement = (QEntryElement *)[self.root elementWithKey:@"cycle"];
    return cycleElement.textValue;
}

- (void)setLastPurchaseDate:(NSDate *)lastPurchaseDate
{
    QDateTimeInlineElement *lastPurchaseDateElement = (QDateTimeInlineElement *)[self.root elementWithKey:@"lastPurchaseDate"];
    lastPurchaseDateElement.dateValue = lastPurchaseDate;
    [self.quickDialogTableView reloadCellForElements:lastPurchaseDateElement, nil];
}

- (NSString *)location
{
    QButtonWithLabelElement *locationElement = (QButtonWithLabelElement *)[self.root elementWithKey:@"location"];
    return locationElement.value;
}

- (void)setLocation:(NSString *)location
{
    QButtonWithLabelElement *locationElement = (QButtonWithLabelElement *)[self.root elementWithKey:@"location"];
    locationElement.value = location;
    [self.quickDialogTableView reloadCellForElements:locationElement, nil];
}

- (BOOL)geofence
{
    QBooleanElement *geofenceElement = (QBooleanElement *)[self.root elementWithKey:@"geofence"];
    return geofenceElement.boolValue;
}

- (void)setGeofence:(BOOL)geofence
{
    QBooleanElement *geofenceElement = (QBooleanElement *)[self.root elementWithKey:@"geofence"];
    geofenceElement.boolValue = geofence;
    [self.quickDialogTableView reloadCellForElements:geofenceElement, nil];
}

#pragma mark - normal property getter & setter

- (NSString *)itemId
{
    if (!_itemId) _itemId = [[NSString alloc] init];
    return _itemId;
}

- (NSNumber *)latitude
{
    if (!_latitude) _latitude = [[NSNumber alloc] init];
    return _latitude;
}

- (NSNumber *)longitude
{
    if (!_longitude) _longitude = [[NSNumber alloc] init];
    return _longitude;
}

- (NSMutableDictionary *)values
{
    if (self.root) {
        if (!_values) _values = [[NSMutableDictionary alloc] init];
        [self.root fetchValueIntoObject:_values];
        _values[@"itemId"] = [self.itemId length] ? self.itemId : @"NEW_ITEM_DUMMY_ID";
        if (self.latitude)  _values[@"latitude"]  = self.latitude;
        if (self.longitude) _values[@"longitude"] = self.longitude;
        return _values;
    } else {
        return nil;
    }
}

#pragma mark - action

- (void)save:(UIBarButtonItem *)sender
{
    // validation
    if (self.stock && [self.cycle length] == 0) {
        [self showAlert:@"Please enter cycle if you use stock."];
        return;
    }
    
    if (self.geofence && [self.location length] == 0) {
        [self showAlert:@"Please enter a location if you use geofence."];
        return;
    }
    
    if ([self.name length] != 0) {
        // save
        dispatch_async(dispatch_get_main_queue(), ^{
            [Item saveItem:self.values];
        });
    }
    
    // back to previous viewcontroller
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)barcode
{
    JANCodeReaderViewController *janCodeReaderViewController =
    [[self storyboard] instantiateViewControllerWithIdentifier:@"JANCodeReaderViewControllerID"];
    [self.navigationController pushViewController:janCodeReaderViewController animated:YES];
}

#pragma mark - Alert Methods

- (void) showAlert:(NSString *)alertText
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Error"
                                                      message:alertText
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
    [message show];
}



@end
