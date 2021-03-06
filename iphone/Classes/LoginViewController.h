//
//  LoginViewController.h
//  WhereBeUs
//
//  Created by Dave Peck on 11/29/09.
//  Copyright 2009 Code Orange. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FBConnect/FBConnect.h"


@interface LoginViewController : UIViewController<UITableViewDelegate, UITableViewDataSource> {
	IBOutlet UITableView *tableView;
	IBOutlet UIBarButtonItem *doneButton;
	IBOutlet UIButton *aboutButton;
	
	NSTimer *facebookTimer;
	NSTimer *twitterTimer;
	BOOL facebookActivity;
	BOOL twitterActivity;
}

@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic, retain) IBOutlet UIButton *aboutButton;

- (void)doneButtonPressed:(id)sender;
- (IBAction)aboutButtonPressed:(id)sender;

@end
