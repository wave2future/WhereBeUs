//
//  WhereBeUsAppDelegate.m
//  WhereBeUs
//
//  Created by Dave Peck on 10/27/09.
//  Copyright Code Orange 2009. All rights reserved.
//

#import "WhereBeUsAppDelegate.h"
#import "WhereBeUsState.h"
#import "TwitterCredentialsViewController.h"
#import "MapViewController.h"
#import "TweetViewController.h"

@implementation WhereBeUsAppDelegate

@synthesize window;
@synthesize navigationController;

- (void)showMapViewController:(BOOL)animated
{
	MapViewController *mapViewController = [[[MapViewController alloc] initWithNibName:@"MapViewController" bundle:nil] autorelease];
	[navigationController pushViewController:mapViewController animated:animated];
}

- (void)showTweetViewController:(BOOL)animated
{
	TweetViewController *tweetViewController = [[[TweetViewController alloc] initWithNibName:@"TweetViewController" bundle:nil] autorelease];
	[navigationController pushViewController:tweetViewController animated:animated];	
}

- (void)popViewController:(BOOL)animated
{
	[navigationController popViewControllerAnimated:YES];	
}

- (void)applicationDidFinishLaunching:(UIApplication *)application 
{   
	// Load our application state (potentially from a file)
	/* ignore return value */ [WhereBeUsState shared];

	[self showMapViewController:NO];
	[navigationController setNavigationBarHidden:YES animated:NO];
	

	[window addSubview:[navigationController view]];
    [window makeKeyAndVisible];
}


- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	// XXX TODO 
	return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application 
{
	WhereBeUsState *state = [WhereBeUsState shared];
	
	if (state.isDirty)
	{
		[state save];
	}
}

- (void)dealloc 
{
	[navigationController release];
	[window release];
	[super dealloc];
}


@end
