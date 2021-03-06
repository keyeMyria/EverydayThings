//
//  DueDateTableViewController.m
//  EverydayThings
//
//  Created by Daisuke Hirata on 2014/04/22.
//  Copyright (c) 2014 Daisuke Hirata. All rights reserved.
//

#import "DueDateTableViewController.h"
#import "AppDelegate.h"
#import "Item+Helper.h"
#import "ItemCategory+Helper.h"

@interface DueDateTableViewController ()

@end

@implementation DueDateTableViewController

#pragma mark - View Controller Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSFetchRequest *request = [Item createRequestForDueDateItems];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                        managedObjectContext:[AppDelegate sharedContext]
                                                                          sectionNameKeyPath:@"expiredWeeks"
                                                                                   cacheName:nil];
}

#pragma mark - Table view data source delegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Expire List Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    Item *item = [self.fetchedResultsController objectAtIndexPath:indexPath];

    // adjust font size by text length
    cell.textLabel.minimumScaleFactor = 0.5f;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd"];
    
    cell.textLabel.text = item.name;
    cell.detailTextLabel.text = [formatter stringFromDate:item.dueDate];
    cell.detailTextLabel.textColor = ([[NSDate date] compare:item.dueDate] == NSOrderedDescending) ?
                                            [UIColor hexToUIColor:@"ff6347" alpha:1.0] : [UIColor grayColor];
    cell.imageView.image = [ItemCategory iconWithCategoryName:item.whichItemCategory.name];
    if ([item.geofence boolValue]) {
        cell.accessoryView = [self geofenceImageViewMonitored:[self.locationManager monitoredRegion:item.location]
                                                 insideRegion:[self.locationManager insideRegion:item.location]];
    } else {
        cell.accessoryView = nil;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSInteger sectionWeek = [[[[self.fetchedResultsController sections] objectAtIndex:section] name] intValue];
    
    return [self weekName:sectionWeek];
}

- (NSString *)weekName:(NSInteger) weekNumber
{
    NSString *weekName = nil;
    
    if (weekNumber > 1) {
        weekName = [NSString stringWithFormat:@"%li weeks ago", (long)weekNumber];
    } else if (weekNumber == 1) {
        weekName = [NSString stringWithFormat:@"Last Week"];
    } else if (weekNumber == 0) {
        weekName = [NSString stringWithFormat:@"Within a Week"];
    } else if (weekNumber == -1) {
        weekName = [NSString stringWithFormat:@"Within two Weeks"];
    } else {
        weekName = [NSString stringWithFormat:@"Within a Month"];
    }
    
    return weekName;
}


@end
