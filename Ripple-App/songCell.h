//
//  songCell.h
//  Ripple-App
//
//  Created by William O'Connor on 4/22/15.
//  Copyright (c) 2015 Gooey Dee Bee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol rippleSongCellDelegate <NSObject>

- (void) drop;

@end

@interface songCell: UITableViewCell

@property (strong, nonatomic) NSDictionary* track;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *artistLabel;
@property (strong, nonatomic) UIImageView *albumCover;
@property (weak, nonatomic) id <rippleSongCellDelegate> delegate;


-(void) setData: (NSDictionary*)track;

@end
