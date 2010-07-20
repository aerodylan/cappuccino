/*
 * CPClipView.j
 * AppKit
 *
 * Created by Francisco Tolmasky.
 * Copyright 2008, 280 North, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import "CPView.j"

#include "CoreGraphics/CGGeometry.h"


/*! 
    @ingroup appkit
    @class CPClipView

    CPClipView allows you to define a clip rect and display only that portion of its containing view.  
    It is used to hold the document view in a CPScrollView.
*/
@implementation CPClipView : CPView
{
    CPView          _documentView;
    CPScrollView    _scrollView;
    BOOL            _copiesOnScroll;
}

- (id)initWithFrame:(CGRect)aFrame
{
    var self = [super initWithFrame:aFrame];
    
    if (self)
        _copiesOnScroll = YES;
}

// Setting the Document View

/*!
    Sets the document view to be \c aView.
    @param aView the new document view. It's frame origin will be changed to \c (0,0) after calling this method.
*/
- (void)setDocumentView:(CPView)aView
{
    if (_documentView == aView)
        return;

    var defaultCenter = [CPNotificationCenter defaultCenter];
    
    if (_documentView)
    {
        [defaultCenter
            removeObserver:self
                      name:CPViewFrameDidChangeNotification
                    object:_documentView];

        [defaultCenter
            removeObserver:self
                      name:CPViewBoundsDidChangeNotification
                    object:_documentView];
        
        [_documentView removeFromSuperview];
    }
    
    _documentView = aView;
    
    if (_documentView)
    {
        [self addSubview:_documentView];
        
        [self setBoundsOrigin:[_documentView frame].origin];
        [self setBackgroundColor:[_documentView backgroundColor]];
        
        if ([_documentView respondsToSelector:@selector(drawsBackground)])
            [self setDrawsBackground:[_documentView drawsBackground]];
        
		[_documentView setPostsFrameChangedNotifications:YES];
		[_documentView setPostsBoundsChangedNotifications:YES];

		[defaultCenter
            addObserver:self
               selector:@selector(viewFrameChanged:)
                   name:CPViewFrameDidChangeNotification 
                 object:_documentView];

		[defaultCenter
            addObserver:self
               selector:@selector(viewBoundsChanged:)
                   name:CPViewBoundsDidChangeNotification 
                 object:_documentView];
    }
    
    [_scrollView _setDocumentMinFrameSize:[_documentView _minimumFrameSize]];
    [_scrollView reflectScrolledClipView:self];
}

/*!
    Returns the document view.
*/
- (id)documentView
{
    return _documentView;
}

// Scrolling

/*!
    Scrolls the clip view to the specified point. The method
    sets its bounds origin to \c aPoint.
*/
- (void)scrollToPoint:(CGPoint)aPoint
{
    [self setBoundsOrigin:[self constrainScrollPoint:aPoint]];
}

- (BOOL)autoscroll:(CPEvent)anEvent 
{
    var bounds = [self bounds],
        eventLocation = [self convertPoint:[anEvent locationInWindow] fromView:nil],
        deltaX = 0,
        deltaY = 0;

    if (_CGRectContainsPoint(bounds, eventLocation))
        return NO;

    var scrollView = _scrollView;
    
    if (!scrollView || [scrollView hasVerticalScroller])
    {
        if (eventLocation.y < _CGRectGetMinY(bounds))
            deltaY = _CGRectGetMinY(bounds) - eventLocation.y;
        else if (eventLocation.y > _CGRectGetMaxY(bounds))
            deltaY = _CGRectGetMaxY(bounds) - eventLocation.y;
        if (deltaY < -bounds.size.height)
            deltaY = -bounds.size.height;
        if (deltaY > bounds.size.height)
            deltaY = bounds.size.height;
    }

    if (!scrollView || [scrollView hasHorizontalScroller])
    {
        if (eventLocation.x < _CGRectGetMinX(bounds))
            deltaX = _CGRectGetMinX(bounds) - eventLocation.x;
        else if (eventLocation.x > _CGRectGetMaxX(bounds))
            deltaX = _CGRectGetMaxX(bounds) - eventLocation.x;
        if (deltaX < -bounds.size.width)
            deltaX = -bounds.size.width;
        if (deltaX > bounds.size.width)
            deltaX = bounds.size.width;
    }

	return [self _scrollToPoint:_CGPointMake(bounds.origin.x - deltaX, bounds.origin.y - deltaY)];
}

/*!
    Returns a new point that may be adjusted from \c aPoint
    to make sure it lies within the document view.
    @param aPoint
    @return the adjusted point
*/
- (CGPoint)constrainScrollPoint:(CGPoint)aPoint
{
    if (!_documentView)
        return _CGPointMakeZero();

    var documentFrame = [_documentView frame];
    
    aPoint.x = MAX(0.0, MIN(aPoint.x, MAX(_CGRectGetWidth(documentFrame) - _CGRectGetWidth(_bounds), 0.0)));
    aPoint.y = MAX(0.0, MIN(aPoint.y, MAX(_CGRectGetHeight(documentFrame) - _CGRectGetHeight(_bounds), 0.0)));

    return aPoint;
}

// Determining Scrolling Efficiency

- (void)setCopiesOnScroll:(BOOL)flag
{        
    _copiesOnScroll = !!flag;
}

- (BOOL)copiesOnScroll
{
    return _copiesOnScroll;
}

// Getting the Visible Portion

/*!
    Returns the rectangle defining the document view’s frame, 
    adjusted to the size of the receiver if the document view is smaller.
    
    In other words, this rectangle is always at least as large as the receiver itself.
*/
- (CGRect)documentRect
{
    if (_documentView)
    {
        var documentFrame = [_documentView frame],
            bounds = [self bounds],
            rect = _CGRectMake(_CGRectGetMinX(documentFrame),
                               _CGRectGetMinY(documentFrame),
                               MAX(_CGRectGetWidth(documentFrame), _CGRectGetWidth(bounds)),
                               MAX(_CGRectGetHeight(documentFrame), _CGRectGetHeight(bounds)));
            
        return rect;
    }
    else
        return _CGRectMakeZero();
}

/*!
    Returns the exposed rectangle of the receiver’s document view, 
    in the document view’s own coordinate system.
*/
- (CGRect)documentVisibleRect
{
    return [self convertRect:_bounds toView:_documentView];
}

// Working With Background Color

- (BOOL)drawsBackground
{
    return _drawsBackground;
}

- (void)setDrawsBackground:(BOOL)drawsBackground
{
    if (_drawsBackground == drawsBackground)
        return;
        
    _drawsBackground = !!drawsBackground;
    
    [self setNeedsDisplay:YES];
}

- (void)setBackgroundColor:(CPColor)aColor
{
    if ([[self backgroundColor] isEqual:aColor])
        return;
        
    [super setBackgroundColor:aColor];
    [self setNeedsDisplay:YES];
}

// CPView Overrides

- (void)setFrame:(CGRect)frameRect
{
    var frame = [self frame];
    
    if (_CGRectEqualToRect(frameRect, frame))
        return;
        
    [super setFrame:frameRect];
    [self _documentViewChanged];
}

- (void)setFrameSize:(CGSize)aSize
{
    var size = [self frameSize];
    
    if (_CGSizeEqualToSize(aSize, size))
        return;
        
    [super setFrameSize:aSize];
    
    // setFrameSize is invoked by setFrame, avoid duplicate _documentViewChanged messages
    if (!_inhibitFrameAndBoundsChangedNotifications)
        [self _documentViewChanged];
}

- (void)setFrameOrigin:(CGPoint)aPoint
{
    var origin = [self frameOrigin];
    
    if (_CGPointEqualToPoint(aPoint, origin))
        return;
        
    [super setFrameOrigin:aPoint];
    
    // setFrameOrigin is invoked by setFrame, avoid duplicate _documentViewChanged messages
    if (!_inhibitFrameAndBoundsChangedNotifications)
        [self _documentViewChanged];
}

- (void)setBounds:(CGRect)aRect
{
    var bounds = [self bounds];
    
    if (_CGRectEqualToRect(aRect, bounds))
        return;
        
    [super setBounds:aRect];
    
    [_scrollView reflectScrolledClipView];
    [_documentView setNeedsDisplay:YES];
}

- (void)setBoundsSize:(CGSize)aSize
{
    var size = [self bounds].size;
    
    if (_CGSizeEqualToSize(aSize, size))
        return;
        
    [super setBoundsSize:aSize];
    
    // setBoundsSize is invoked by setBounds, avoid duplicate _documentViewChanged messages
    if (!_inhibitFrameAndBoundsChangedNotifications)
    {
        [_scrollView reflectScrolledClipView];
        [_documentView setNeedsDisplay:YES];
    }
}

- (void)setBoundsOrigin:(CGPoint)newOrigin
{
    var oldBounds = [self bounds],
        oldOrigin = oldBounds.origin;

    if (_CGPointEqualToPoint(newOrigin, oldOrigin))
        return;

    // setBoundsOrigin is invoked by setBounds, avoid duplicate _documentViewChanged messages
    if (_inhibitFrameAndBoundsChangedNotifications || !_documentView)
    {
        [super setBoundsOrigin:newOrigin];
        return;
    }
    
    // Code below ported from GNUstep
    var newBounds = _CGRectMakeCopy(oldBounds),
        intersection;

    newBounds.origin = newOrigin;

    if (_copiesOnScroll && [self window])
    {
        /*
            Copy the portion of the view that is common before and after
            scrolling. Then the document view needs to redraw the remaining areas.
        */

        intersection = CGRectIntersection(oldBounds, newBounds);
        intersection = CGRectIntersection(intersection, [self visibleRect]);
        intersection = [self _integralRect:intersection];

        /*
            At this point, intersection is the rectangle containing the
            image we can recycle from the old to the new situation. We
            must not make any assumption on its position/size, because it
            has been intersected with visible rect, which is an arbitrary
            rectangle as far as we know.
        */
        var zeroRect = _CGRectMakeZero();
        
        if (_CGRectEqualToRect(intersection, zeroRect))
        {
            // No recyclable part, docview should redraw everything
            [super setBoundsOrigin: newBounds.origin];
            [_documentView setNeedsDisplayInRect:[self documentVisibleRect]];
        }
        else
        {
            var dx = newBounds.origin.x - oldBounds.origin.x,
                dy = newBounds.origin.y - oldBounds.origin.y;

            // Copy the intersection to the new position
            [self scrollRect:intersection by:_CGSizeMake(-dx, -dy)];

            // Change coordinate system to the new one
            [super setBoundsOrigin:newBounds.origin];

            // Get the rectangle representing intersection in the new
            // bounds (mainly to keep code readable)
            intersection.origin.x -= dx;
            intersection.origin.y -= dy;

            /*
                Now mark everything which is outside intersection as
                needing to be redrawn by hand. NB: During simple usage -
                scrolling in a single direction (left/rigth/up/down) -
                and a normal visible rect, only one of the following
                rects will be non-empty.
            */

            // To the left of intersection
            var bounds = [self bounds],
                redrawRect = _CGRectMake(_CGRectGetMinX(bounds), 
                                         _CGRectGetMinY(bounds),
                                         _CGRectGetMinX(intersection) - _CGRectGetMinX(bounds),
                                         _CGRectGetHeight(bounds));
            
            if (!_CGRectIsEmpty(redrawRect))
                [_documentView setNeedsDisplayInRect:[self convertRect:redrawRect toView:_documentView]];

            // To the right of the intersection
            redrawRect = _CGRectMake(_CGRectGetMaxX(intersection), 
                                     _CGRectGetMinY(bounds),
                                     _CGRectGetMaxX(bounds) - _CGRectGetMaxX(intersection),
                                     _CGRectGetHeight(bounds));
                                     
            if (!_CGRectIsEmpty(redrawRect))
                [_documentView setNeedsDisplayInRect:[self convertRect:redrawRect toView:_documentView]];

            // Above the intersection
            redrawRect = _CGRectMake(_CGRectGetMinX(bounds), 
                                     _CGRectGetMinY(bounds),
                                     _CGRectGetWidth(bounds),
                                     _CGRectGetMinY(intersection) - _CGRectGetMinY(bounds));
            
            if (!_CGRectIsEmpty(redrawRect))
                [_documentView setNeedsDisplayInRect:[self convertRect:redrawRect toView:_documentView]];

            // Below the intersection
            redrawRect = _CGRectMake(_CGRectGetMinX(bounds), 
                                     _CGRectGetMaxY(intersection),
                                     _CGRectGetWidth(bounds),
                                     _CGRectGetMaxY(bounds) - _CGRectGetMaxY(intersection));
                                     
            if (!_CGRectIsEmpty(redrawRect))
                [_documentView setNeedsDisplayInRect:[self convertRect:redrawRect toView:_documentView]];
        }
    }
    else // _copiesOnScroll == NO
    {
        // Don't copy anything, docview draws it all
        [super setBoundsOrigin:newBounds.origin];
        [_documentView setNeedsDisplayInRect:[self documentVisibleRect]];
    }

    [_scrollView reflectScrolledClipView:self];
}

/*!
    Handles a CPViewBoundsDidChangeNotification.
    @param aNotification the notification event
*/
- (void)viewBoundsChanged:(CPNotification)aNotification
{
    [_scrollView reflectScrolledClipView:self];
}

/*!
    Handles a CPViewFrameDidChangeNotification.
    @param aNotification the notification event
*/
- (void)viewFrameChanged:(CPNotification)aNotification
{
    var bounds = [self bounds];
    
    [self _scrollToPoint:bounds.origin];
    [_scrollView reflectScrolledClipView:self];
}

- (void)viewDidMoveToSuperview:(CPView)newSuperview
{
    if ([newSuperview isKindOfClass:[CPScrollView class]])
        _scrollView = newSuperview;
    else
        _scrollView = nil;
}

@end

@implementation CPClipView (CPClipViewPrivate)

- (void)_scrollToPoint:(CGPoint)aPoint
{ 
    var proposedBounds = [self bounds], 
        proposedVisibleRect,
        newVisibleRect,
        newBounds;

    // Give documentView a chance to adjust its visible rectangle 
    proposedBounds.origin = aPoint; 
    proposedVisibleRect = [self convertRect:proposedBounds toView:_documentView];
    newVisibleRect = [_documentView adjustScroll:proposedVisibleRect]; 
    newBounds = [self convertRect:newVisibleRect fromView:_documentView]; 

    [self scrollToPoint:newBounds.origin]; 
}

- (void)_documentViewChanged
{
    [self setBoundsOrigin:[self constrainScrollPoint:[self bounds].origin]];
    [_scrollView reflectScrolledClipView:self];
}

- (CGRect)_integralRect:(CGRect)aRect
{
    var origin = _CGPointMake(ROUND(_CGRectGetMinX(aRect)), ROUND(_CGRectGetMinY(aRect))),
        bottomRight = _CGPointMake(ROUND(_CGRectGetMaxX(aRect)), ROUND(_CGRectGetMaxY(aRect))),
        rect = _CGRectMake(origin.x, origin.y, bottomRight.x - origin.x, bottomRight.y - origin.y);
        
    return rect;
}

@end


var CPClipViewDocumentViewKey = @"CPScrollViewDocumentView",
    CPClipViewDrawsBackgroundKey = @"CPClipViewDrawsBackground",
    CPClipViewCopiesOnScrollKey = @"CPClipViewCopiesOnScroll";

@implementation CPClipView (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [super initWithCoder:aCoder])
    {        
        _drawsBackground = [aCoder decodeBoolForKey:CPClipViewDrawsBackgroundKey];
        _copiesOnScroll = [aCoder decodeBoolForKey:CPClipViewCopiesOnScrollKey];
        
        [self setDocumentView:[aCoder decodeObjectForKey:CPClipViewDocumentViewKey]];
    }
    
    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];
    
    [aCoder encodeObject:_documentView forKey:CPClipViewDocumentViewKey];
    [aCoder encodeBool:_drawsBackground forKey:CPClipViewDrawsBackgroundKey];
    [aCoder encodeBool:_copiesOnScroll forKey:CPClipViewCopiesOnScrollKey];
}

@end
