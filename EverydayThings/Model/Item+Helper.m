//
//  Item+Helper.m
//  EverydayThings
//
//  Created by Daisuke Hirata on 2014/04/22.
//  Copyright (c) 2014 Daisuke Hirata. All rights reserved.
//

#import "AppDelegate.h"
#import "Item+Helper.h"
#import "ItemCategory+Helper.h"
#import "GeoFenceMonitoringLocationReloadNotification.h"

@implementation Item (Helper)


+ (Item *)saveItem:(NSDictionary *)values
{
    Item *item = nil;
    NSManagedObjectContext *context = [AppDelegate sharedContext];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    request.predicate = [NSPredicate predicateWithFormat:@"itemId = %@", values[@"itemId"]];
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || error || ([matches count] > 1)) {
        // error
        item = nil; // not necessary. it's for readability
    } else if  ([matches count]) {
        // update
        item = [matches firstObject];
    } else {
        // insert
        item = [NSEntityDescription insertNewObjectForEntityForName:@"Item"
                                             inManagedObjectContext:context];
        item.itemId = [[NSUUID UUID] UUIDString];
    }
    
    if (item) {
        
        NSNumber *oldBuynow   = item.buyNow;
        NSNumber *oldElapsed  = item.elapsed;
        NSNumber *oldGeofence = item.geofence;
        NSString *oldLocation = item.location;
        
        item.name                = values[@"name"];
        item.buyNow              = values[@"buyNow"];
        item.stock               = values[@"stock"];
        item.lastPurchaseDate    = values[@"lastPurchaseDate"];
        item.dueDate             = values[@"dueDate"];
        item.cycle               = [values[@"cycle"] length] != 0 ?
                                        [NSDecimalNumber decimalNumberWithString:values[@"cycle"]] : nil;
        item.timeSpan            = [Item timeSpans][[values[@"timeSpan"] intValue]];
        item.whichItemCategory   = [ItemCategory itemCategoryWithIndex:[values[@"category"] intValue]];
        item.elapsed             = [item elapsedDaysAfterLastPurchaseDate] > [item cycleInDays] ? @1 : @0;

        item.location            = values[@"location"];
        item.geofence            = values[@"geofence"];
        item.latitude            = values[@"latitude"];
        item.longitude           = values[@"longitude"];
        item.memo                = values[@"memo"];

        NSError *error = nil;
        [context save:&error];
        if(error) {
            NSLog(@"could not save data : %@", error);
        } else {
            if (!([oldGeofence isEqualToNumber:item.geofence] &&
                  [oldBuynow isEqualToNumber:item.buyNow]     &&
                  [oldElapsed isEqualToNumber:item.elapsed]   &&
                  (oldLocation == item.location || [oldLocation isEqualToString:item.location]) )  ) {
                
                // geofence region changed.
                [[NSNotificationCenter defaultCenter] postNotificationName:GeofenceMonitoringLocationReloadNotification
                                                                    object:self
                                                                  userInfo:nil];
            }
        }
    }
    
    return item;
}

+ (void)updateElapsed
{
    NSLog(@"update elapsed status...");
    NSManagedObjectContext *context = [AppDelegate sharedContext];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    request.predicate = nil; // all of Item.
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (error) {
        // error
        NSLog(@"Error updateElpased");
    } else if  ([matches count]) {
        // update
        for (Item *item in matches) {
            item.elapsed = [item elapsedDaysAfterLastPurchaseDate] > [item cycleInDays] ? @1 : @0;
        }
        error = nil;
        [context save:&error];
        if(error) {
            NSLog(@"could not save data : %@", error);
        }
    }
}

+ (NSFetchRequest *)createRequestForBuyNowItems
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    request.predicate = [NSPredicate predicateWithFormat:@"buyNow = YES || elapsed = YES"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"whichItemCategory.name"
                                                              ascending:YES
                                                               selector:@selector(localizedStandardCompare:)]];
    return request;
        
}

+ (NSArray *)itemsForBuyNow
{
    NSFetchRequest *request = [self createRequestForBuyNowItems];
    
    NSError *error;
    NSArray *matches = [[AppDelegate sharedContext] executeFetchRequest:request error:&error];
    
    if (error) {
        // error
        NSLog(@"can not read geofence location data from item managed object");
    }
    
    return matches;
}


+ (NSFetchRequest *)createRequestForDueDateItems
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    
    // 1 month later
    NSDate *today = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setMonth:1];
    NSDate *nearFutureDate = [cal dateByAddingComponents:comps toDate:today options:0];
    request.predicate = [NSPredicate predicateWithFormat:@"dueDate < %@", nearFutureDate];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"dueDate"
                                                              ascending:YES]];
    
    return request;
}

+ (NSArray *)itemsForDueDateTab
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    
    // 1 week later
    NSDate *today = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setWeek:1];
    NSDate *nearFutureDate = [cal dateByAddingComponents:comps toDate:today options:0];
    request.predicate = [NSPredicate predicateWithFormat:@"dueDate < %@", nearFutureDate];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"dueDate"
                                                              ascending:YES]];
    
    NSError *error;
    NSArray *matches = [[AppDelegate sharedContext] executeFetchRequest:request error:&error];
    
    if (error) {
        // error
        NSLog(@"can not read due date items from item managed object");
    }
    
    return matches;
}

+ (NSArray *)itemsForGeofence
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    request.predicate = [NSPredicate predicateWithFormat:@"(buyNow = YES || elapsed = YES) && geofence = YES"];
    NSError *error;
    NSArray *matches = [[AppDelegate sharedContext] executeFetchRequest:request error:&error];
    
    if (!matches || error) {
        // error
        NSLog(@"can not read geofence location data from item managed object");
    }
    
    return matches;
}

+ (void)updateCategoryToNone:(NSString *)name
{
    NSLog(@"update category");
    NSManagedObjectContext *context = [AppDelegate sharedContext];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    request.predicate = [NSPredicate predicateWithFormat:@"whichItemCategory.name = %@", name];
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (error) {
        // error
        NSLog(@"Error updateElpased");
    } else if  ([matches count]) {
        // update
        for (Item *item in matches) {
            item.whichItemCategory = [ItemCategory itemCategoryWithName:@"None"];
        }
        error = nil;
        [context save:&error];
        if(error) {
            NSLog(@"could not save data : %@", error);
        }
    }
}


- (NSInteger)expiredWeeks
{
	// now - due date
	NSTimeInterval since = 0;
    
    if (self.dueDate) {
        since = [[NSDate date] timeIntervalSinceDate:self.dueDate];
    }
    
    // convert second into week
    return (NSInteger)since/(7*24*60*60);
}

- (NSInteger)elapsedDaysAfterLastPurchaseDate
{
	// now - last purchase date
	NSTimeInterval since = 0;
    
    if (self.lastPurchaseDate) {
        since = [[NSDate date] timeIntervalSinceDate:self.lastPurchaseDate];
    }
    
    // convert second into day
    return (NSInteger)since/(24*60*60);
}

- (NSInteger)cycleInDays
{
    NSInteger cycle = 0;
    
    if (![self.cycle isEqualToNumber:[NSDecimalNumber notANumber]]) {
        cycle = [self.cycle longValue];
        if ([self.timeSpan isEqualToString:@"Month"]) {
            cycle = [self.cycle longValue] * 30;
        } else if ([self.timeSpan isEqualToString:@"Year"]) {
            cycle = [self.cycle longValue] * 365;
        }
    }
    
    return cycle;
}

+ (NSArray *)timeSpans
{
    return @[@"Day", @"Month", @"Year"];
}

@end
