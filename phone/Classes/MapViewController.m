//
//  MapController.m
//  WhereBeUs
//
//  Created by Dave Peck on 10/28/09.
//  Copyright 2009 Code Orange. All rights reserved.
//

#import "MapViewController.h"
#import "WhereBeUsAppDelegate.h"
#import "WhereBeUsState.h"
#import "Utilities.h"
#import "ConnectionHelper.h"
#import "JsonResponse.h"
#import "UpdateAnnotation.h"
#import "UpdateAnnotationView.h"

static const NSTimeInterval kUpdateTimerSeconds = 15;
#define kDefaultLatLonSpan 0.05

@interface MapViewController (Private)
@end

@implementation MapViewController


//------------------------------------------------------------------
// Properties
//------------------------------------------------------------------

@synthesize tweetButton;
@synthesize mapView;


//------------------------------------------------------------------
// Code To Poll For Updates From Server & Manage Annotations
//------------------------------------------------------------------

- (void)wbu_finishedGetUpdatesForHashtag:(JsonResponse *)response
{
	if (response == nil) { return; }

	NSDictionary *dictionary = [response dictionary];
	BOOL success = [(NSNumber *)[dictionary objectForKey:@"success"] boolValue];
	if (!success) { return; }
	
	// Inside this loop, we walk through all the updates returned by
	// the service. If the update corresponds to an annotation that is
	// not on the map, we add it. If the update corresponds to an annotation
	// that _is_ on the map, we update said annotation. Finally, after
	// looking at all the updates we got back from the service, we check to see
	// if we have any annotations left on the map that were _not_ part of the
	// service update list. If so, we remove those annotations.
	//
	// The final trick to all this is that the iPhone user's own annotation is
	// managed separately, so that it can update itself much more often. That said,
	// the service will return the iPhone user's update information too. We want to 
	// ignore that here.
	NSArray *updates = [dictionary objectForKey:@"updates"];
	WhereBeUsState *state = [WhereBeUsState shared];
				
	// STEP 1: mark all current annotations on the map as NOT VISITED
	for (id key in twitterUsernameToAnnotation)
	{
		UpdateAnnotation *annotation = (UpdateAnnotation *)[twitterUsernameToAnnotation objectForKey:key];
		annotation.visited = NO;
	}
	
	// STEP 2: walk through all update records returned by the service and create, 
	// or update, the corresponding map annotation
	for (NSDictionary *update in updates)
	{				
		NSString *updateUsername = (NSString *)[update objectForKey:@"twitter_username"];
		
		if (![state.twitterUsername isEqualToString:updateUsername])
		{					
			UpdateAnnotation *annotation = (UpdateAnnotation *)[twitterUsernameToAnnotation objectForKey:updateUsername];
			
			if (annotation == nil)
			{
				// an annotation for this username doesn't yet exist. Create it.
				annotation = [UpdateAnnotation updateAnnotationWithDictionary:update];
				annotation.visited = YES;
				[twitterUsernameToAnnotation setObject:annotation forKey:updateUsername];
				[self.mapView addAnnotation:annotation];
			}
			else
			{
				// an annotation already exists. Just update it.
				[annotation updateWithDictionary:update];
				annotation.visited = YES;
			}
		}
	}
	
	// STEP 3: see if there are any annotations on the map that should go away
	NSMutableArray *usernamesThatWentAway = [NSMutableArray arrayWithCapacity:1];
	
	for (id key in twitterUsernameToAnnotation)
	{
		UpdateAnnotation *annotation = (UpdateAnnotation *)[twitterUsernameToAnnotation objectForKey:key];
		
		if (![state.twitterUsername isEqualToString:annotation.twitterUsername] && !annotation.visited)
		{
			[self.mapView removeAnnotation:annotation];
			[usernamesThatWentAway addObject:annotation.twitterUsername];
		}
	}
	
	// (can't remove stuff from twitterUserNameToAnnotation while enumerating it!)
	for (id key in usernamesThatWentAway)
	{
		[twitterUsernameToAnnotation removeObjectForKey:key];
	}

	// Done updating! Make sure the map reflects our changes!
	[self forceAnnotationsToUpdate];	
	gettingLocationUpdates = NO;
}

- (void)updateTimerFired:(NSTimer *)timer
{
	if (!gettingLocationUpdates)
	{
		gettingLocationUpdates = NO; /* XXX YES; */
		// XXX TODO need new service API here
//		[ConnectionHelper wbu_getUpdatesForHashtagWithTarget:self action:@selector(wbu_finishedGetUpdatesForHashtag:) hashtag:[WhereBeUsState shared].currentHashtag];
	}
}

- (void)startWatchingForUpdates
{
	if (updateWatchingTimer == nil)
	{
		updateWatchingTimer = [[NSTimer scheduledTimerWithTimeInterval:kUpdateTimerSeconds target:self selector:@selector(updateTimerFired:) userInfo:nil repeats:YES] retain];
	}
	
	// force an immediate watch
	[updateWatchingTimer fire];
}

- (void)stopWatchingForUpdates
{
	if (updateWatchingTimer != nil)
	{
		[updateWatchingTimer invalidate];
		[updateWatchingTimer release];
		updateWatchingTimer = nil;
	}
}


//------------------------------------------------------------------
// Random Utilities For The View
//------------------------------------------------------------------

- (void)dealloc
{
	self.tweetButton = nil;
	self.mapView = nil;
	
	[twitterUsernameToAnnotation release];
	
	[locationManager stopUpdatingLocation];
	[locationManager release];
	
	[self stopWatchingForUpdates];
	
    [super dealloc];
}


//------------------------------------------------------------------
// Actions
//------------------------------------------------------------------

- (IBAction)tweetButtonPushed:(id)sender
{
//	WhereBeUsAppDelegate *appDelegate = (WhereBeUsAppDelegate *)[[UIApplication sharedApplication] delegate];
//// TODO davepeck	[appDelegate showTweetViewController:YES]; 
}


//------------------------------------------------------------------
// Map View Management
//------------------------------------------------------------------

- (void)centerAndZoomOnCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated
{
	// Region and Zoom
	MKCoordinateRegion region;
	MKCoordinateSpan span;
	
	span.latitudeDelta = kDefaultLatLonSpan;
	span.longitudeDelta = kDefaultLatLonSpan;
	
	region.span = span;
	region.center = coordinate;
	
	[mapView setRegion:	[mapView regionThatFits:region]	animated:animated];
}

- (MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id<MKAnnotation>)annotation
{
	// sanity check input
	if (annotation == nil)
	{
		return nil;
	}
	
	// we don't provide custom views for anything but UpdateAnnotations...
	if (![annotation isKindOfClass:[UpdateAnnotation class]])
	{
		return nil;
	}

	// Create, or reuse, an update annotation view
	UpdateAnnotationView *annotationView = (UpdateAnnotationView *) [theMapView dequeueReusableAnnotationViewWithIdentifier:@"UpdateAnnotation"];
	if (annotationView == nil)
	{
		annotationView = [[[UpdateAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"UpdateAnnotation" annotationManager:self] autorelease];
	}
	else
	{
		annotationView.annotation = annotation;
	}
	
	return annotationView;
}


//
// WhereBeUsAnnotationManager delegate -- basically just a clean way for
// annotation views to comunicate back to the map view controller...
//

- (void)forceAnnotationsToUpdate
{
	// This _actually_ works, which is all the more shocking because
	// if you send animated:YES, it doesn't do anything at all!
	[mapView setCenterCoordinate:mapView.region.center animated:NO];
}

- (CGRect)getScreenBoundsForRect:(CGRect)rect fromView:(UIView *)view
{
	WhereBeUsAppDelegate *appDelegate = (WhereBeUsAppDelegate *) [[UIApplication sharedApplication] delegate];
	UIWindow *window = (UIWindow *)appDelegate.window;
	return [window convertRect:rect fromView:view];
}

CGFloat fsign(CGFloat f)
{
	if (f < 0.0)
	{
		return -1.0;
	}
	else if (f > 0.0)
	{
		return 1.0;
	}
	
	return 0.0;
}

- (void)moveMapByDeltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY forView:(UIView *)view
{
	// how much do we want to move, _in the coordinate system of the requesting view_?
	// (the rectangle's origin isn't so interesting; the _size_ is key)
	CGRect deltaRect = CGRectMake(view.center.x, view.center.y, fabs(deltaX), fabs(deltaY));
	
	// how much motion does this imply in latitude/longitude space?
	MKCoordinateRegion deltaRegion = [mapView convertRect:deltaRect toRegionFromView:view];
	
	// where are we moving to?
	CLLocationCoordinate2D destination;
	destination.latitude = mapView.region.center.latitude + (fsign(deltaY) * deltaRegion.span.latitudeDelta);
	destination.longitude = mapView.region.center.longitude + (fsign(deltaX) * deltaRegion.span.longitudeDelta);
	
	// move!
	[mapView setCenterCoordinate:destination animated:YES];
}

- (void)deselectAnnotation:(id<MKAnnotation>)annotation animated:(BOOL)animated
{
	[mapView deselectAnnotation:annotation animated:animated];
}


//------------------------------------------------------------------
// Location Management for the current user, including annotations
//------------------------------------------------------------------

- (void)wbu_finishedPostUpdate:(JsonResponse *)response
{
	updatingLocation = NO;
}

- (void)updateServiceWithLocation
{
	return; /* TODO XXX */
	
	// update only if all the conditions are right to do so
	if (hasCoordinate && !updatingLocation)
	{
//		WhereBeUsState *state = [WhereBeUsState shared];
		// XXX TODO: need a new service URL
//		[ConnectionHelper wbu_postUpdateWithTarget:self action:@selector(wbu_finishedPostUpdate:) twitterUsername:state.twitterUsername twitterFullName:state.twitterFullName twitterProfileImageURL:state.twitterProfileImageURL hashtag:@"XXX REMOVE" message:@"XXX REMOVE" coordinate:currentCoordinate];			
	}
}

- (void)updateUserAnnotationWithCoordinate:(CLLocationCoordinate2D)coordinate
{
	return; /* TODO XXX */
	
	WhereBeUsState *state = [WhereBeUsState shared];
	UpdateAnnotation *annotationFromDictionary = (UpdateAnnotation *) [twitterUsernameToAnnotation objectForKey:state.twitterUsername];
	UpdateAnnotation *annotation = annotationFromDictionary;
	
	if (annotationFromDictionary == nil)
	{
		// an annotation for this username doesn't yet exist. Create it.
		annotation = [UpdateAnnotation updateAnnotationWithDictionary:[NSDictionary dictionary]];
	}
	
	annotation.twitterUsername = state.twitterUsername;
	annotation.twitterFullName = state.twitterFullName;
	annotation.twitterProfileImageURL = state.twitterProfileImageURL;
	[annotation setLatitude:currentCoordinate.latitude longitude:currentCoordinate.longitude];
	annotation.lastUpdate = [NSDate date];
	annotation.visited = NO;
	
	if (annotationFromDictionary == nil)
	{
		[twitterUsernameToAnnotation setObject:annotation forKey:state.twitterUsername];
		[self.mapView addAnnotation:annotation];
	}
	
	// force the map to redraw!
	[self forceAnnotationsToUpdate];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
	// STEP 0: reject any coordinates older than, say, three minutes
	if (fabs([newLocation.timestamp timeIntervalSinceNow]) > (3.0 * 60.0))
	{
		return;
	}

	#if TARGET_IPHONE_SIMULATOR
	CLLocationCoordinate2D university_zoka_coffee_seattle_wa;
	university_zoka_coffee_seattle_wa.latitude = 47.665916;
	university_zoka_coffee_seattle_wa.longitude = -122.297361;	
	newLocation = [[[CLLocation alloc] initWithCoordinate:university_zoka_coffee_seattle_wa altitude:newLocation.altitude horizontalAccuracy:newLocation.horizontalAccuracy verticalAccuracy:newLocation.verticalAccuracy timestamp:newLocation.timestamp] autorelease];
	#endif
	
	
	// STEP 1: if we have yet to see a valid coordinate, 
	// zoom in to that location on the map
	if (!hasCoordinate)
	{
		hasCoordinate = YES;
		bestHorizontalAccuracy = newLocation.horizontalAccuracy;
		[self centerAndZoomOnCoordinate:newLocation.coordinate animated:YES];
	}
	
	// STEP 2: if the accuracy of this coordinate is more than 200% of 
	// the previously best seen accuracy, reject the coordinate.
	if (newLocation.horizontalAccuracy > (bestHorizontalAccuracy * 2.0))
	{
		return;
	}
	
	// (and remember the best accuracy, if it has changed)
	if (newLocation.horizontalAccuracy < bestHorizontalAccuracy)
	{
		bestHorizontalAccuracy = newLocation.horizontalAccuracy;
	}
	
	// STEP 3: update our internal notion of where the user is
	currentCoordinate = newLocation.coordinate;
	[self updateUserAnnotationWithCoordinate:currentCoordinate];
	
	// STEP 4: if it's a good time, let the service know
	// about our new location.
	[self updateServiceWithLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	// XXX TODO
}


//------------------------------------------------------------------
// UIViewController overrides
//------------------------------------------------------------------

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    self = [super initWithNibName:nibName bundle:nibBundle];
    if (self != nil) 
	{
		// set up basic state
		updatingLocation = NO;
		gettingLocationUpdates = NO;
		hasCoordinate = NO;
		twitterUsernameToAnnotation = [[NSMutableDictionary dictionaryWithCapacity:1] retain];

		// build our location manager
		locationManager = [[CLLocationManager alloc] init];
		locationManager.distanceFilter = 20.0; /* don't update unless you've moved 20 meters or more */
		locationManager.desiredAccuracy = kCLLocationAccuracyBest; /* i think we definitely want this for our purposes, despite battery drain */
		locationManager.delegate = self;
		[locationManager startUpdatingLocation];		
    }
    return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	[self startWatchingForUpdates];		
}

- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload 
{
	// Release any retained subviews of the main view.
}

- (void)viewWillAppear:(BOOL)animated 
{	
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
	WhereBeUsState *state = [WhereBeUsState shared];
	if (!state.hasTwitterCredentials)
	{
		WhereBeUsAppDelegate *delegate = (WhereBeUsAppDelegate *) [[UIApplication sharedApplication] delegate];
		[delegate showTwitterCredentialsController];		
	}
	
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	WhereBeUsAppDelegate *delegate = (WhereBeUsAppDelegate *) [[UIApplication sharedApplication] delegate];
	[delegate.window setWindowDelegate:nil];	
    [super viewWillDisappear:animated];
}


@end
