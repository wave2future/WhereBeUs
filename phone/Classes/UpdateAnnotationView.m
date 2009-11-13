//
//  UpdateAnnotationView.m
//  WhereBeUs
//
//  Created by Dave Peck on 11/5/09.
//  Copyright 2009 Code Orange. All rights reserved.
//

#import "UpdateAnnotationView.h"
#import "UpdateAnnotation.h"
#import "AsyncImageCache.h"

#define BUBBLE_PNG_WIDTH 55.0
#define BUBBLE_PNG_HEIGHT 68.0
#define BUBBLE_PNG_CENTEROFFSET_Y -23.0

#define BUBBLE_HOTSPOT_Y 58.0

#define IMAGE_LEFT 9.0
#define IMAGE_TOP 5.0
#define IMAGE_WIDTH 37.0
#define IMAGE_HEIGHT 37.0

#define IMAGE_STROKE_TOP 6.0
#define IMAGE_STROKE_WIDTH 36.0
#define IMAGE_STROKE_HEIGHT 36.0

#define FIXED_EXPANDED_WIDTH 270.0
#define FIXED_EXPANDED_HEIGHT 70.0
#define FIXED_EXPANDED_CENTEROFFSET_Y -22.0

#define FILL_WIDTH 1.0
#define FILL_HEIGHT 57.0
#define CENTER_WIDTH 41.0
#define CENTER_HEIGHT 70.0
#define LEFT_WIDTH 17.0
#define LEFT_HEIGHT 57.0
#define RIGHT_WIDTH 17.0
#define RIGHT_HEIGHT 57.0

#define kFadeTimerSeconds 0.025
#define kFadeIncrement 0.1

@interface UpdateAnnotationView (Private)
- (void)transitionToExpanded:(BOOL)animated;
- (void)transitionToCollapsed:(BOOL)animated;
@end

@implementation UpdateAnnotationView


//---------------------------------------------------------------------
// Static methods for accessing frequently-used images
//---------------------------------------------------------------------

+ (UIImage *)bubbleImage
{
	static UIImage *_bubbleImage;
	
	@synchronized (self)
	{
		if (_bubbleImage == nil)
		{
			_bubbleImage = [[UIImage imageNamed:@"bubble.png"] retain];
		}		
	}
	
	return _bubbleImage;
}

+ (UIImage *)defaultUserIcon
{
	static UIImage *_defaultUserIcon;
	
	@synchronized (self)
	{
		if (_defaultUserIcon == nil)
		{
			_defaultUserIcon = [[UIImage imageNamed:@"default37.png"] retain];
		}		
	}
	
	return _defaultUserIcon;
}

+ (UIImage *)leftCapImage
{
	static UIImage *_leftCapImage;
	
	@synchronized (self)
	{
		if (_leftCapImage == nil)
		{
			_leftCapImage = [[UIImage imageNamed:@"left.png"] retain];
		}		
	}
	
	return _leftCapImage;
}

+ (UIImage *)rightCapImage
{
	static UIImage *_rightCapImage;
	
	@synchronized (self)
	{
		if (_rightCapImage == nil)
		{
			_rightCapImage = [[UIImage imageNamed:@"right.png"] retain];
		}		
	}
	
	return _rightCapImage;
}

+ (UIImage *)centerImage
{
	static UIImage *_centerImage;
	
	@synchronized (self)
	{
		if (_centerImage == nil)
		{
			_centerImage = [[UIImage imageNamed:@"center.png"] retain];
		}		
	}
	
	return _centerImage;
}

+ (UIImage *)fillImage
{
	static UIImage *_fillImage;
	
	@synchronized (self)
	{
		if (_fillImage == nil)
		{
			_fillImage = [[UIImage imageNamed:@"fill.png"] retain];
		}		
	}
	
	return _fillImage;
}


//---------------------------------------------------------------------
// Initialization & Destruction
//---------------------------------------------------------------------

- (id)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier annotationManager:(id<WhereBeUsAnnotationManager>)theAnnotationManager
{
	self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
	if (self != nil)
	{
		initializing = YES;		
		self.opaque = NO;
		annotationManager = theAnnotationManager;		
		twitterUserIcon = nil;
		twitterIconPercent = 0.0;
		
		[self transitionToCollapsed:NO];
		
		UpdateAnnotation *updateAnnotation = (UpdateAnnotation *)annotation;
		[[AsyncImageCache shared] loadImageForURL:updateAnnotation.twitterProfileImageURL delegate:self];		
		
		self.canShowCallout = NO; /* we are the callout! */
		initializing = NO;
		self.exclusiveTouch = YES; /* we are the only ones who get our touches, darnit */
	}
	return self;
}

- (void)dealloc
{
	annotationManager = nil;
	
	[fadeTimer invalidate];
	[fadeTimer release];
	fadeTimer = nil;
	
	[twitterUserIcon release];
	twitterUserIcon = nil;
	
	[super dealloc];
}


//---------------------------------------------------------------------
// MKAnnotationView overrides
//---------------------------------------------------------------------

- (void)prepareForReuse
{
	[super prepareForReuse];
	[fadeTimer invalidate];
	[fadeTimer release];
	fadeTimer = nil;

	[twitterUserIcon release];
	twitterUserIcon = nil;
	
	twitterIconPercent = 0.0;		
	[self transitionToCollapsed:NO];	
}


//---------------------------------------------------------------------
// Geometry Helpers
//---------------------------------------------------------------------

CGFloat GetRectTop(CGRect rect)
{
	return rect.origin.y;
}

CGFloat GetRectLeft(CGRect rect)
{
	return rect.origin.x;
}

CGFloat GetRectBottom(CGRect rect)
{
	return rect.origin.y + rect.size.height;
}

CGFloat GetRectRight(CGRect rect)
{
	return rect.origin.x + rect.size.width;
}


//---------------------------------------------------------------------
// Custom View Drawing
//---------------------------------------------------------------------

- (void)drawExpandedRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias(context, NO);	
	UpdateAnnotation *updateAnnotation = (UpdateAnnotation *)self.annotation;
	
	//------------------------------------------------
	// Draw Background
	//------------------------------------------------
	
	// compute areas	
	CGSize frameSize = self.frame.size;
	CGRect leftCapRect = CGRectMake(0.0, 0.0, LEFT_WIDTH, LEFT_HEIGHT);
	CGRect rightCapRect = CGRectMake(frameSize.width - RIGHT_WIDTH, 0.0, RIGHT_WIDTH, RIGHT_HEIGHT);
	CGFloat centerImageCenterX = expansion_downArrowX;
	CGFloat centerImageX = centerImageCenterX - round(CENTER_WIDTH / 2.0);
	CGRect centerRect = CGRectMake(centerImageX, 0.0, CENTER_WIDTH, CENTER_HEIGHT);
	
	CGFloat leftCapRect_right = GetRectRight(leftCapRect);
	CGFloat centerRect_left = GetRectLeft(centerRect);
	CGRect leftFillRect = CGRectMake(leftCapRect_right, 0.0, centerRect_left - leftCapRect_right, FILL_HEIGHT);
	
	CGFloat rightCapRect_left = GetRectLeft(rightCapRect);
	CGFloat centerRect_right = GetRectRight(centerRect);
	CGRect rightFillRect = CGRectMake(centerRect_right, 0.0, rightCapRect_left - centerRect_right, FILL_HEIGHT);
	
	// draw areas
	[[UpdateAnnotationView leftCapImage] drawInRect:leftCapRect];
	[[UpdateAnnotationView rightCapImage] drawInRect:rightCapRect];
	[[UpdateAnnotationView centerImage] drawInRect:centerRect];
	[[UpdateAnnotationView fillImage] drawInRect:leftFillRect];
	[[UpdateAnnotationView fillImage] drawInRect:rightFillRect];
	
	//------------------------------------------------
	// Draw User Icon
	//------------------------------------------------
	
	CGRect iconStrokeRect = CGRectMake(GetRectRight(leftCapRect) - 6.0, 6.0, IMAGE_STROKE_WIDTH, IMAGE_STROKE_HEIGHT);
	CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 0.55);
	CGContextStrokeRect(context, iconStrokeRect);	
	
	CGContextSetShouldAntialias(context, YES);	

	CGRect iconDrawRect = CGRectMake(iconStrokeRect.origin.x + 1.0, 6.0, IMAGE_STROKE_WIDTH - 1, IMAGE_STROKE_HEIGHT -1);
	
	if (twitterUserIcon == nil)
	{
		[[UpdateAnnotationView defaultUserIcon] drawInRect:iconDrawRect];
	}
	else
	{
		if (twitterIconPercent >= 1.0)
		{
			[twitterUserIcon drawInRect:iconDrawRect];
		}
		else
		{
			[twitterUserIcon drawInRect:iconDrawRect blendMode:kCGBlendModeNormal alpha:twitterIconPercent];
			[[UpdateAnnotationView defaultUserIcon] drawInRect:iconDrawRect blendMode:kCGBlendModeNormal alpha:1.0 - twitterIconPercent];
		}
	}	
	
	
	//------------------------------------------------
	// Draw Title
	//------------------------------------------------

	CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.9);
	CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 0.9);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0, 1.0), 0.15, [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.6].CGColor);
	
	CGPoint titlePoint = CGPointMake(GetRectRight(iconDrawRect) + LEFT_WIDTH - 8.0, 5.0);
	[updateAnnotation.title drawAtPoint:titlePoint withFont:[UIFont boldSystemFontOfSize:16.0]];	
	
	
	//------------------------------------------------
	// Draw Subtitle
	//------------------------------------------------
	
	CGPoint subtitlePoint = CGPointMake(titlePoint.x, 26.0);
	[updateAnnotation.subtitle drawAtPoint:subtitlePoint withFont:[UIFont systemFontOfSize:12.0]];		
}

- (void)drawCollapsedRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGContextSetShouldAntialias(context, NO);	
	[[UpdateAnnotationView bubbleImage] drawAtPoint:CGPointMake(0.0, 0.0)];
	CGContextSetShouldAntialias(context, YES);
	
	if (twitterUserIcon == nil)
	{
		[[UpdateAnnotationView defaultUserIcon] drawAtPoint:CGPointMake(IMAGE_LEFT, IMAGE_TOP)];
	}
	else
	{
		if (twitterIconPercent >= 1.0)
		{
			[twitterUserIcon drawInRect:CGRectMake(IMAGE_LEFT, IMAGE_TOP, IMAGE_WIDTH, IMAGE_HEIGHT)];
		}
		else
		{
			[twitterUserIcon drawInRect:CGRectMake(IMAGE_LEFT, IMAGE_TOP, IMAGE_WIDTH, IMAGE_HEIGHT) blendMode:kCGBlendModeNormal alpha:twitterIconPercent];
			[[UpdateAnnotationView defaultUserIcon] drawInRect:CGRectMake(IMAGE_LEFT, IMAGE_TOP, IMAGE_WIDTH, IMAGE_HEIGHT) blendMode:kCGBlendModeNormal alpha:1.0 - twitterIconPercent];
		}
	}	
}

- (void)drawRect:(CGRect)rect
{
	if (self.selected)
	{
		[self drawExpandedRect:rect];
	}
	else
	{
		[self drawCollapsedRect:rect];
	}
}


//---------------------------------------------------------------------
// Fade Management For User Icon
//---------------------------------------------------------------------

- (void)fadeTimerFired:(NSTimer *)timer
{
	twitterIconPercent += kFadeIncrement;
	if (twitterIconPercent >= 1.0)
	{
		twitterIconPercent = 1.0;
		[fadeTimer invalidate];
		[fadeTimer release];
		fadeTimer = nil;
	}
	[self setNeedsDisplay];
}

- (void)fadeInNewUserIcon
{
	if (initializing)
	{
		// if we're just setting up and we have the icon,
		// don't do the fade in -- that's just a waste.
		twitterIconPercent = 1.0;
		return;
	}
	
	if (fadeTimer != nil)
	{
		[fadeTimer invalidate];
		[fadeTimer release];
		fadeTimer = nil;
	}
	
	twitterIconPercent = 0.0;
	fadeTimer = [[NSTimer scheduledTimerWithTimeInterval:kFadeTimerSeconds target:self selector:@selector(fadeTimerFired:) userInfo:nil repeats:YES] retain];
}


//---------------------------------------------------------------------
// AsyncImageCache Delegate
//---------------------------------------------------------------------

- (void)asyncImageCacheLoadedImage:(UIImage *)image forURL:(NSString *)url
{
	// just in case
	[twitterUserIcon release];
	twitterUserIcon = nil;

	// remember this image, if it corresponds to the expected URL
	UpdateAnnotation *updateAnnotation = (UpdateAnnotation *) self.annotation;
	if (image != nil && [url isEqualToString:updateAnnotation.twitterProfileImageURL])
	{
		twitterUserIcon = [image retain];
		[self fadeInNewUserIcon];
	}

	// force full redraw
	[self setNeedsDisplay];
}


//---------------------------------------------------------------------
// Expand/Collapse
//---------------------------------------------------------------------

- (void)transitionToExpanded:(BOOL)animated
{
	// figure out how big our expanded view's visible content will be
	UpdateAnnotation *updateAnnotation = (UpdateAnnotation *)self.annotation;
	CGSize titleSize = [updateAnnotation.title sizeWithFont:[UIFont boldSystemFontOfSize:16.0]];
	CGSize subtitleSize = [updateAnnotation.subtitle sizeWithFont:[UIFont systemFontOfSize:12.0]];
	CGFloat maxTextWidth = (titleSize.width > subtitleSize.width) ? titleSize.width : subtitleSize.width;
	CGFloat contentWidth = (LEFT_WIDTH - 6.0) + (RIGHT_WIDTH - 2.0) + (LEFT_WIDTH - 8.0) + (IMAGE_STROKE_WIDTH) + maxTextWidth;
	
	// where are we currently displayed on screen?
	CGRect currentScreenBounds = [annotationManager getScreenBoundsForRect:self.bounds fromView:self];
	CGFloat currentScreenCenterX = currentScreenBounds.origin.x + (currentScreenBounds.size.width / 2.0);
	
	// where will our horizontal extents be, on screen,
	// if we fully expand and put our down-arrow dead center?
	CGFloat futureScreenLeftX = currentScreenCenterX - (contentWidth / 2.0);
	CGFloat futureScreenRightX = currentScreenCenterX + (contentWidth / 2.0);
	CGFloat maxScreenRight = [[UIScreen mainScreen] bounds].size.width;

	// do we need to modify our position so we fit on the screen?
	CGFloat adjustX = 0.0;
	if ((futureScreenLeftX < 0) ^ (futureScreenRightX > maxScreenRight))
	{
		if (futureScreenLeftX < 0)
		{
			adjustX = -futureScreenLeftX; /* will be a positive value, aka move to the right */
		}
		else
		{
			adjustX = maxScreenRight - futureScreenRightX; /* will be a negative value, aka move to the left */
		}
	}
	
	// compute where the center of the down arrow should be, relative
	// to wherever we start drawing actual content in the view
	expansion_downArrowX = round((contentWidth / 2.0) - adjustX);
	
	// let's be careful, though. If we have to adjust too far, our left cap
	// (or right cap) image will overlap with the center/down-arrow image.
	// This calls for: moving the map itself! We want to move the map
	// exactly as many pixels as there is overlap, plus one pixel so that
	// we get a line of "fill" everywhere.
	CGFloat mapMoveX = 0.0;
	CGFloat overlapLeft = (expansion_downArrowX - round(CENTER_WIDTH / 2.0)) - (LEFT_WIDTH + 1.0);
	CGFloat overlapRight = (expansion_downArrowX + round(CENTER_WIDTH / 2.0)) - (contentWidth - RIGHT_WIDTH + 1.0);
		
	// the down arrow location is affected by our overlap adjustment, if any
	if (overlapLeft <= 0.0)
	{
		mapMoveX = overlapLeft;
		adjustX += overlapLeft;
		expansion_downArrowX = round((contentWidth / 2.0) - adjustX);
	}
	else if (overlapRight >= 0.0)
	{
		mapMoveX = overlapRight;
		adjustX += overlapRight;
		expansion_downArrowX = round((contentWidth / 2.0) - adjustX);
	}
		
	// TODO: (1) restrict annotation sizes to a maximum width (eg 300 wide)
	
	// redraw the annotation!
	self.bounds = CGRectMake(0.0, 0.0, contentWidth, FIXED_EXPANDED_HEIGHT);
	self.centerOffset = CGPointMake(adjustX, FIXED_EXPANDED_CENTEROFFSET_Y);
	[self setNeedsDisplay];		

	// move the map if desired
	if (mapMoveX != 0.0)
	{
		[annotationManager moveMapByDeltaX:mapMoveX deltaY:0.0 forView:self];
	}
	else 
	{
		[annotationManager forceAnnotationsToUpdate];
	}	
}

- (void)transitionToCollapsed:(BOOL)animated
{
	self.bounds = CGRectMake(0.0, 0.0, BUBBLE_PNG_WIDTH, BUBBLE_PNG_HEIGHT);
	self.centerOffset = CGPointMake(0.0, BUBBLE_PNG_CENTEROFFSET_Y);
	[self setNeedsDisplay];		
	[annotationManager forceAnnotationsToUpdate];			
}


//---------------------------------------------------------------------
// Touch Interception
//---------------------------------------------------------------------

- (void)setSelected:(BOOL)newSelected animated:(BOOL)animated
{
	if (newSelected != self.selected)
	{
		if (newSelected)
		{
			[self.superview bringSubviewToFront:self];			
			[self transitionToExpanded:animated];
		}
		else
		{
			[self transitionToCollapsed:animated];
		}		
	}
	
	[super setSelected:newSelected animated:animated];
}

// For now, we require that you touch outside _all_ annotations
// to collapse the currently expanded annotation.

//- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
//{
//	UITouch *touch = [touches anyObject];
//	if ([self pointInside:[touch locationInView:self] withEvent:event])
//	{
//		if ([touch tapCount] == 1)
//		{
//			if (self.selected)
//			{
//				[annotationManager deselectAnnotation:self.annotation animated:YES];
//			}
//		}
//	}
//}

@end