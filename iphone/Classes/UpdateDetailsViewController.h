//
//  UpdateDetailsViewController.h
//  WhereBeUs
//
//  Created by Dave Peck on 1/7/10.
//  Copyright 2010 Code Orange. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UpdateAnnotation.h"
#import "AsyncImageView.h"


@interface UpdateDetailsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource, MKReverseGeocoderDelegate> {
	IBOutlet AsyncImageView *profileImageView;
	IBOutlet UILabel *displayNameView;
	IBOutlet UITableView *infoTableView;
	MKReverseGeocoder *reverseGeocoder;
	NSString *friendlyLocation;
	
	UpdateAnnotation *annotation;
}

@property (nonatomic, retain) AsyncImageView *profileImageView;
@property (nonatomic, retain) UILabel *displayNameView;
@property (nonatomic, retain) UITableView *infoTableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil annotation:(UpdateAnnotation *)annotation;

@end
