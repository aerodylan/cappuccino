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
    CPView  _documentView;
}

- (void)setDrawsBackground:(BOOL)drawsBackground
{
    if (_drawsBackground == drawsBackground)
        return;
        
    _drawsBackground = !!drawsBackground;
    
    [self setNeedsDisplay:YES];
}

- (BOOL)drawsBackground
{
    return _drawsBackground;
}

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
}

/*!
    Returns the document view.
*/
- (id)documentView
{
    return _documentView;
}

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
            documentFrame = _CGRectOffset(documentFrame, -_CGRectGetMinX(documentFrame), -CGRectGetMinY(documentFrame)),
            clipFrame = [self frame],
            clipFrame = _CGRectOffset(clipFrame, -_CGRectGetMinX(clipFrame), -CGRectGetMinY(clipFrame));
            
        return CGRectUnion(documentFrame, clipFrame);
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
    return _documentView ? [_documentView visibleRect] : _CGRectMakeZero();
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

/*!
    Scrolls the clip view to the specified point. The method
    sets its bounds origin to \c aPoint.
*/
- (void)scrollToPoint:(CGPoint)aPoint
{
    [self setBoundsOrigin:[self constrainScrollPoint:aPoint]];
}

- (CGPoint)_scrollPoint
{
    return [self bounds].origin;
}

- (void)setFrame:(CGRect)frameRect
{
    var oldFrame = [self frame];
    //console.log('CPClipView -setFrame: %f, %f', frameRect.size.width, frameRect.size.height);
    [super setFrame:frameRect];
    
    if (!_CGRectEqualToRect(oldFrame, frameRect))
        [self _selfBoundsChanged];
}

- (void)setBoundsOrigin:(CGPoint)newOrigin
{
    var oldOrigin = [self bounds].origin;
    
    [super setBoundsOrigin:newOrigin];
    
    if (!_CGPointEqualToPoint(oldOrigin, newOrigin))
        [self _selfBoundsChanged];
}

- (void)_selfBoundsChanged
{
    //console.log('CPClipView -_selfBoundsChanged: %f, %f', [self bounds].size.width, [self bounds].size.height);
    [self _reflectDocumentViewChanged];
}

/*!
    Handles a CPViewBoundsDidChangeNotification.
    @param aNotification the notification event
*/
- (void)viewBoundsChanged:(CPNotification)aNotification
{
    [self _reflectDocumentViewChanged];
}

/*!
    Handles a CPViewFrameDidChangeNotification.
    @param aNotification the notification event
*/
- (void)viewFrameChanged:(CPNotification)aNotification
{
    var view = [aNotification object];        
    var rect = [view frame];
    //console.log('CPClipView -viewFrameChanged: %f, %f, %f, %f', rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    
    [self _reflectDocumentViewChanged];
}

- (void)_reflectDocumentViewChanged
{
    //console.log('CPClipView -_reflectDocumentViewChanged');
    [[self enclosingScrollView] reflectScrolledClipView:self];
}

- (BOOL)autoscroll:(CPEvent)anEvent 
{
    var bounds = [self bounds],
        eventLocation = [self convertPoint:[anEvent locationInWindow] fromView:nil],
        superview = [self superview],
        deltaX = 0,
        deltaY = 0;

    if (CGRectContainsPoint(bounds, eventLocation))
        return NO;

    if (![superview isKindOfClass:[CPScrollView class]] || [superview hasVerticalScroller])
    {
        if (eventLocation.y < CGRectGetMinY(bounds))
            deltaY = CGRectGetMinY(bounds) - eventLocation.y;
        else if (eventLocation.y > CGRectGetMaxY(bounds))
            deltaY = CGRectGetMaxY(bounds) - eventLocation.y;
        if (deltaY < -bounds.size.height)
            deltaY = -bounds.size.height;
        if (deltaY > bounds.size.height)
            deltaY = bounds.size.height;
    }

    if (![superview isKindOfClass:[CPScrollView class]] || [superview hasHorizontalScroller])
    {
        if (eventLocation.x < CGRectGetMinX(bounds))
            deltaX = CGRectGetMinX(bounds) - eventLocation.x;
        else if (eventLocation.x > CGRectGetMaxX(bounds))
            deltaX = CGRectGetMaxX(bounds) - eventLocation.x;
        if (deltaX < -bounds.size.width)
            deltaX = -bounds.size.width;
        if (deltaX > bounds.size.width)
            deltaX = bounds.size.width;
    }

	return [self scrollToPoint:CGPointMake(bounds.origin.x - deltaX, bounds.origin.y - deltaY)];
}

@end


var CPClipViewDocumentViewKey = @"CPScrollViewDocumentView",
    CPClipViewDrawsBackgroundKey = @"CPClipViewDrawsBackground";

@implementation CPClipView (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [super initWithCoder:aCoder])
    {
        [self setDocumentView:[aCoder decodeObjectForKey:CPClipViewDocumentViewKey]];
        
        _drawsBackground = [aCoder decodeBoolForKey:CPClipViewDrawsBackgroundKey];
    }
    
    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];
    
    [aCoder encodeObject:_documentView forKey:CPClipViewDocumentViewKey];
    [aCoder encodeBool:_drawsBackground forKey:CPClipViewDrawsBackgroundKey];
}

@end
