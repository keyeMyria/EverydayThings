//
//  ItemDialogViewController.h
//  EverydayThings
//
//  Created by Daisuke Hirata on 2014/04/25.
//  Copyright (c) 2014年 Daisuke Hirata. All rights reserved.
//

#import "QuickDialogController.h"

@class Item;

@interface ItemDialogViewController : QuickDialogController

// in
@property (nonatomic, strong) Item *item;

@end
