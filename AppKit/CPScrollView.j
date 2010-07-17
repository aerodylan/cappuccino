/*
 * CPScrollView.j
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

@import "CPGraphics.j"
@import "CPView.j"
@import "CPClipView.j"
@import "CPScroller.j"

#include "CoreGraphics/CGGeometry.h"


var CPScrollViewBorderInsetTop    = 0,
    CPScrollViewBorderInsetRight  = 1,
    CPScrollViewBorderInsetBottom = 2,
    CPScrollViewBorderInsetLeft   = 3;


/*!
    @ingroup appkit
    @class CPScrollView

    Used to display views that are too large for the viewing area. the CPScrollView
    places scroll bars on the side of the view to allow the user to scroll and see the entire
    contents of the view.
*/
@implementation CPScrollView : CPView
{
    CPClipView   _contentView;
    CPClipView   _headerClipView;
    CPView       _cornerView;
                 
    BOOL         _hasVerticalScroller;
    BOOL         _hasHorizontalScroller;
    BOOL         _autohidesScrollers;
    BOOL         _wantsVerticalScroller;
    BOOL         _wantsHorizontalScroller;
                 
    CPScroller   _verticalScroller;
    CPScroller   _horizontalScroller;
                 
    float        _verticalLineScroll;
    float        _verticalPageScroll;
    float        _horizontalLineScroll;
    float        _horizontalPageScroll;
    
    CPBorderType _borderType;
    CPArray      _borderInsets;
}

- (id)initWithFrame:(CGRect)aFrame
{
    return [self initWithFrame:aFrame borderType:CPNoBorder];
}

- (id)initWithFrame:(CGRect)aFrame borderType:(CPBorderType)aBorderType
{
    self = [super initWithFrame:aFrame];
    
    if (self)
    {
        _borderType = CPNoBorder;
        
        [self _initBorderInsets];
        
        _verticalLineScroll = 10.0;
        _verticalPageScroll = 10.0;

        _horizontalLineScroll = 10.0;
        _horizontalPageScroll = 10.0;

        _contentView = [[CPClipView alloc] initWithFrame:[self bounds]];

        [self addSubview:_contentView];

        _headerClipView = [[CPClipView alloc] init];

        [self addSubview:_headerClipView];

        [self setHasVerticalScroller:YES];
        [self setHasHorizontalScroller:YES];
        
        [self _init];
    }

    return self;
}

- (void)_init
{
    _wantsVerticalScroller = NO;
    _wantsHorizontalScroller = NO;
}

- (void)_initBorderInsets
{
    switch (_borderType)
    {
        case CPLineBorder:
        case CPBezelBorder:
            _borderInsets = [1.0, 1.0, 1.0, 1.0];
            break;
            
        case CPGrooveBorder:
            _borderInsets = [3.0, 2.0, 2.0, 2.0];
            break;
        
        case CPNoBorder:
        default:
            _borderInsets = [0.0, 0.0, 0.0, 0.0];
            break;
    }
}

// Determining component sizes
/*!
    Returns the size of the scroll view's content view.
*/
- (CGRect)contentSize
{
    return [_contentView frame].size;
}

/*!
    Returns the view that is scrolled for the user.
*/
- (id)documentView
{
    return [_contentView documentView];
}

/*!
    Returns the portion of the document view, in its own coordinate system, 
    visible through the receiver’s content view.
*/
- (CGRect)documentVisibleRect
{
    if (_contentView)
        return [_contentView documentVisibleRect];
    else
        return _CGRectMakeZero();
}

/*!
    Sets the content view that clips the document
    @param aContentView the content view
*/
- (void)setContentView:(CPClipView)aContentView
{
    if (_contentView !== aContentView || !aContentView)
        return;

    var documentView = [aContentView documentView];

    if (documentView)
        [documentView removeFromSuperview];

    [_contentView removeFromSuperview];

    _contentView = aContentView;

    [_contentView setDocumentView:documentView];

    [self addSubview:_contentView];

    [self tile];
}

/*!
    Returns the content view that clips the document.
*/
- (CPClipView)contentView
{
    return _contentView;
}

/*!
    Sets the view that is scrolled for the user.
    @param aView the view that will be scrolled
*/
- (void)setDocumentView:(CPView)aView
{
    [_contentView setDocumentView:aView];

    // FIXME: This should be observed.
    [self _updateCornerAndHeaderView];
}

// Managing Scrollers
/*!
    Sets the scroll view's horizontal scroller.
    @param aScroller the horizontal scroller for the scroll view
*/
- (void)setHorizontalScroller:(CPScroller)aScroller
{
    if (_horizontalScroller === aScroller)
        return;

    [_horizontalScroller removeFromSuperview];
    [_horizontalScroller setTarget:nil];
    [_horizontalScroller setAction:nil];

    _horizontalScroller = aScroller;

    [_horizontalScroller setTarget:self];
    [_horizontalScroller setAction:@selector(_horizontalScrollerDidScroll:)];

    [self addSubview:_horizontalScroller];

    [self tile];
}

/*!
    Returns the scroll view's horizontal scroller
*/
- (CPScroller)horizontalScroller
{
    return _horizontalScroller;
}

/*!
    Specifies whether the scroll view can have a horizontal scroller.
    @param hasHorizontalScroller \c YES lets the scroll view
    allocate a horizontal scroller if necessary.
*/
- (void)setHasHorizontalScroller:(BOOL)shouldHaveHorizontalScroller
{
    if (_hasHorizontalScroller === shouldHaveHorizontalScroller)
        return;

    _hasHorizontalScroller = shouldHaveHorizontalScroller;

    if (_hasHorizontalScroller && !_horizontalScroller)
    {
        [self setHorizontalScroller:[[CPScroller alloc] initWithFrame:_CGRectMake(0.0, 0.0, MAX(_CGRectGetWidth([self bounds]), [CPScroller scrollerWidth]+1), [CPScroller scrollerWidth])]];
        [[self horizontalScroller] setFrameSize:_CGSizeMake(_CGRectGetWidth([self bounds]), [CPScroller scrollerWidth])];
    }

    [self tile];
}

/*!
    Returns \c YES if the scroll view can have a horizontal scroller.
*/
- (BOOL)hasHorizontalScroller
{
    return _hasHorizontalScroller;
}

/*!
    Sets the scroll view's vertical scroller.
    @param aScroller the vertical scroller
*/
- (void)setVerticalScroller:(CPScroller)aScroller
{
    if (_verticalScroller === aScroller)
        return;

    [_verticalScroller removeFromSuperview];
    [_verticalScroller setTarget:nil];
    [_verticalScroller setAction:nil];

    _verticalScroller = aScroller;

    [_verticalScroller setTarget:self];
    [_verticalScroller setAction:@selector(_verticalScrollerDidScroll:)];

    [self addSubview:_verticalScroller];

    [self tile];
}

/*!
    Return's the scroll view's vertical scroller
*/
- (CPScroller)verticalScroller
{
    return _verticalScroller;
}

/*!
    Specifies whether the scroll view has can have
    a vertical scroller. It allocates it if necessary.
    @param hasVerticalScroller \c YES allows
    the scroll view to display a vertical scroller
*/
- (void)setHasVerticalScroller:(BOOL)shouldHaveVerticalScroller
{
    if (_hasVerticalScroller === shouldHaveVerticalScroller)
        return;

    _hasVerticalScroller = shouldHaveVerticalScroller;

    if (_hasVerticalScroller && !_verticalScroller)
    {
        [self setVerticalScroller:[[CPScroller alloc] initWithFrame:_CGRectMake(0.0, 0.0, [CPScroller scrollerWidth], MAX(_CGRectGetHeight([self bounds]), [CPScroller scrollerWidth]+1))]];
        [[self verticalScroller] setFrameSize:_CGSizeMake([CPScroller scrollerWidth], _CGRectGetHeight([self bounds]))];
    }

    [self tile];
}

/*!
    Returns \c YES if the scroll view can have a vertical scroller.
*/
- (BOOL)hasVerticalScroller
{
    return _hasVerticalScroller;
}

/*!
    Sets whether the scroll view hides its scoll bars when not needed.
    @param autohidesScrollers \c YES causes the scroll bars
    to be hidden when not needed.
*/
- (void)setAutohidesScrollers:(BOOL)autohidesScrollers
{
    if (_autohidesScrollers == autohidesScrollers)
        return;

    _autohidesScrollers = autohidesScrollers;

    [self tile];
}

/*!
    Returns \c YES if the scroll view hides its scroll
    bars when not necessary.
*/
- (BOOL)autohidesScrollers
{
    return _autohidesScrollers;
}

/*!
    Sets the type of border to be drawn around the view.
*/
- (void)setBorderType:(CPBorderType)borderType
{
    if (_borderType == borderType)
        return;
        
    _borderType = borderType;
    
    [self tile];
}

/*!
    Returns the border type drawn around the view.
*/
- (CPBorderType)borderType
{
    return _borderType;
}

- (void)setDrawsBackground:(BOOL)drawsBackground
{
    if (!_contentView || (_contentView && ([_contentView drawsBackground] == drawsBackground)))
        return;
        
    [_contentview setDrawsBackground:drawsBackground];
    
    [self setNeedsDisplay:YES];
}

- (BOOL)drawsBackground
{
    return _contentView ? [_contentView drawsBackground] : NO;
}

- (CPColor)backgroundColor
{
    return _contentView ? [_contentView backgroundColor] : [CPColor whiteColor];
}

- (void)_updateCornerAndHeaderView
{
    //console.log('_updateCornerAndHeaderView');
    
    var documentView = [self documentView],
        currentHeaderView = [self _headerView],
        documentHeaderView = [documentView respondsToSelector:@selector(headerView)] ? [documentView headerView] : nil;

    if (currentHeaderView !== documentHeaderView)
    {
        [currentHeaderView removeFromSuperview];
        [_headerClipView setDocumentView:documentHeaderView];
    }

    var documentCornerView = [documentView respondsToSelector:@selector(cornerView)] ? [documentView cornerView] : nil;

    if (_cornerView !== documentCornerView)
    {
        [_cornerView removeFromSuperview];

        _cornerView = documentCornerView;

        if (_cornerView)
            [self addSubview:_cornerView];
    }
    
    [self tile];
}

- (CPView)_headerView
{
    return [_headerClipView documentView];
}

- (CGRect)_cornerViewFrame
{
    var bounds = [self bounds];
    
    if (!_cornerView)
        return _CGRectMake(_CGRectGetMinX(bounds), _CGRectGetMinY(bounds), 0, 0);

    var frame = [_cornerView frame];

    frame.origin.x = _CGRectGetMinX(bounds) + _CGRectGetWidth(bounds) - _CGRectGetWidth(frame);
    frame.origin.y = _CGRectGetMinY(bounds);
    
    return frame;
}

- (CGRect)bounds
{
    // To implement a frame, we inset our bounds, which forces all subviews to inset accordingly.
    // Then we are free to draw in the space between our frame and our bounds.
    
    var rect = [super bounds];
    
    // This method can called during initWithCoder *before* _borderInsets is created,
    // so we have to check for that.
    if (!_borderInsets)
        return rect;
        
    var x = _CGRectGetMinX(rect) + _borderInsets[CPScrollViewBorderInsetLeft],
        y = _CGRectGetMinY(rect) + _borderInsets[CPScrollViewBorderInsetTop],
        width = _CGRectGetWidth(rect) - _borderInsets[CPScrollViewBorderInsetLeft] - _borderInsets[CPScrollViewBorderInsetRight],
        height = _CGRectGetHeight(rect) - _borderInsets[CPScrollViewBorderInsetTop] - _borderInsets[CPScrollViewBorderInsetBottom];
    
    return _CGRectMake(x, y, width, height);
}

- (void)drawRect:(CPRect)aRect
{
    [super drawRect:aRect];
    
    var strokeRect = [super bounds],
        context = [[CPGraphicsContext currentContext] graphicsPort];

    if ([self drawsBackground])
    {
        CGContextSetFillColor(context, [self backgroundColor]);
        CGContextFillRect(context, strokeRect);
    }
    
    if (_borderType == CPNoBorder)
        return;
    
    CGContextSetLineWidth(context, 1);

    switch (_borderType)
    {
        case CPLineBorder:
            CGContextSetStrokeColor(context, [CPColor blackColor]);
            CGContextStrokeRect(context, _CGRectInset(strokeRect, 0.5, 0.5));
            break;

        case CPBezelBorder:
            CPDrawGrayBezel(strokeRect);
            break;
            
        case CPGrooveBorder:
            CPDrawGroove(strokeRect, YES);
            break;

        default:
            break;
    }
}

- (CGRect)_headerClipViewFrame
{
    var headerView = [self _headerView];

    if (!headerView)
        return _CGRectMakeZero();

    var frame = [self bounds];

    frame.size.height = _CGRectGetHeight([headerView frame]);
    
    if (![_cornerView isHidden])
        frame.size.width -= _CGRectGetWidth([self _cornerViewFrame]);

    return frame;
}

/* @ignore */
- (void)_verticalScrollerDidScroll:(CPScroller)aScroller
{
    var value = [aScroller floatValue],
        documentFrame = [[_contentView documentView] frame],
        contentBounds = [_contentView bounds];

    switch ([_verticalScroller hitPart])
    {
        case CPScrollerDecrementLine:   contentBounds.origin.y -= _verticalLineScroll;
                                        break;

        case CPScrollerIncrementLine:   contentBounds.origin.y += _verticalLineScroll;
                                        break;

        case CPScrollerDecrementPage:   contentBounds.origin.y -= _CGRectGetHeight(contentBounds) - _verticalPageScroll;
                                        break;

        case CPScrollerIncrementPage:   contentBounds.origin.y += _CGRectGetHeight(contentBounds) - _verticalPageScroll;
                                        break;

        case CPScrollerKnobSlot:
        case CPScrollerKnob:
                                        // We want integral bounds!
        default:                        contentBounds.origin.y = ROUND(value * (_CGRectGetHeight(documentFrame) - _CGRectGetHeight(contentBounds)));
    }

    [_contentView scrollToPoint:contentBounds.origin];
}

/* @ignore */
- (void)_horizontalScrollerDidScroll:(CPScroller)aScroller
{
   var value = [aScroller floatValue],
       documentFrame = [[self documentView] frame],
       contentBounds = [_contentView bounds];

    switch ([_horizontalScroller hitPart])
    {
        case CPScrollerDecrementLine:   contentBounds.origin.x -= _horizontalLineScroll;
                                        break;

        case CPScrollerIncrementLine:   contentBounds.origin.x += _horizontalLineScroll;
                                        break;

        case CPScrollerDecrementPage:   contentBounds.origin.x -= _CGRectGetWidth(contentBounds) - _horizontalPageScroll;
                                        break;

        case CPScrollerIncrementPage:   contentBounds.origin.x += _CGRectGetWidth(contentBounds) - _horizontalPageScroll;
                                        break;

        case CPScrollerKnobSlot:
        case CPScrollerKnob:
                                        // We want integral bounds!
        default:                        contentBounds.origin.x = ROUND(value * (_CGRectGetWidth(documentFrame) - _CGRectGetWidth(contentBounds)));
    }

    [_contentView scrollToPoint:contentBounds.origin];
    [_headerClipView scrollToPoint:_CGPointMake(_CGRectGetMinX(contentBounds), 0.0)];
}

/*!
    Lays out the scroll view's components.
    
    When the content view is resized, the document view is notified and sizes itself accordingly.
    If its frame changes, the content view is notified and then sends -reflectScrolledClipView to us.
*/
- (void)tile
{
    //console.log('->CPScrollview tile');
    
    var newContentFrame = [self _applyContentViewLayout:NO];
    
    [_contentView setFrame:newContentFrame];
    
    newContentFrame = [_contentView frame];
    //console.log('final content size: %f, %f', newContentFrame.size.width, newContentFrame.size.height);
    
    [self _applyContentViewLayout:YES];
    
    //console.log('<-CPScrollview tile');
}

- (void)_setWantsScrollers
{
    //console.log('_setWantsScrollers');
    rect = [self bounds];
    //console.log('bounds: %f, %f, %f, %f', rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    
    // Cocoa "cheats" by using this internal message, it's the only way to get size-to-fit document views to
    // work correctly without lots of recursion.
    var documentSize = [[self documentView] _minimumFrameSize],
        contentSize = [self bounds].size;
        
    //console.log('contentSize: %f, %f', contentSize.width, contentSize.height);
    //console.log('documentSize: %f, %f', documentSize.width, documentSize.height);
    
    contentSize = _CGSizeMake(contentSize.width, contentSize.height - _CGRectGetHeight([self _headerClipViewFrame]));
    //console.log('contentSize: %f, %f', contentSize.width, contentSize.height);
    
    var sizeDifference = _CGSizeMake(documentSize.width - contentSize.width, documentSize.height - contentSize.height),
        needsVerticalScroller = sizeDifference.height > 0.0,
        needsHorizontalScroller = sizeDifference.width > 0.0,
        scrollerWidth = [CPScroller scrollerWidth];

    //console.log('size diff: %f, %f', sizeDifference.width, sizeDifference.height);
    _wantsVerticalScroller = _hasVerticalScroller && (!_autohidesScrollers || needsVerticalScroller);
    _wantsHorizontalScroller = _hasHorizontalScroller && (!_autohidesScrollers || needsHorizontalScroller);

    // Now we know if the document view's current size will fit in the content frame or not.
    // Adjust the content frame accordingly and check again if the other scroller is needed.
    if (_wantsVerticalScroller)
    {
        sizeDifference.width += scrollerWidth;
        needsHorizontalScroller = sizeDifference.width > 0.0;
        _wantsHorizontalScroller = _hasHorizontalScroller && (!_autohidesScrollers || needsHorizontalScroller);
    }

    if (_wantsHorizontalScroller)
    {
        sizeDifference.height += scrollerWidth;
        needsVerticalScroller = sizeDifference.height > 0.0;
        _wantsVerticalScroller = _hasVerticalScroller && (!_autohidesScrollers || needsVerticalScroller);
    }
}

/*
    Splitting this out from -tile eliminates recursion.
    
    If this is called before clip view reflection, the decision to show scrollers or not 
    has already been made. If this is called after (possible) clip view reflection, scrollers 
    are either visible or not. Then we need to see if their state changed.
*/
- (CGRect)_applyContentViewLayout:(BOOL)shouldSetContentFrame
{
    //console.log('_applyContentViewLayout:%s', beforeClipViewReflects ? 'YES' : 'NO');
    
    var bounds = [self bounds],
        newContentFrame = _CGRectMakeCopy(bounds),
        headerClipViewHeight = _CGRectGetHeight([self _headerClipViewFrame]),
        scrollerWidth = [CPScroller scrollerWidth];
       
    newContentFrame.origin.y += headerClipViewHeight;
    newContentFrame.size.height -= headerClipViewHeight;
    
    [self _setWantsScrollers];
        
    //console.log('show vertical: %s\nshow horizontal: %s', _wantsVerticalScroller ? 'Y' : 'N', _wantsHorizontalScroller ? 'Y' : 'N');
    [_cornerView setHidden:!_wantsVerticalScroller];

    var cornerViewFrame = [self _cornerViewFrame];
    //console.log('cornerView: %s, %f, %f, %f, %f', [_cornerView isHidden] ? 'hidden' : 'visible', cornerViewFrame.origin.x, cornerViewFrame.origin.y, cornerViewFrame.size.width, cornerViewFrame.size.height);

    if (_wantsVerticalScroller)
        newContentFrame.size.width -= scrollerWidth;

    if (_wantsHorizontalScroller)
        newContentFrame.size.height -= scrollerWidth;

    //console.log('newContentFrame: %f, %f, %f, %f', newContentFrame.origin.x, newContentFrame.origin.y, newContentFrame.size.width, newContentFrame.size.height);
    
    if (_hasVerticalScroller)
    {
        var verticalScrollerY = MAX(_CGRectGetMaxY(cornerViewFrame), _CGRectGetMaxY([self _headerClipViewFrame])),
            verticalScrollerHeight = _CGRectGetMaxY(bounds) - verticalScrollerY;

        if (_wantsHorizontalScroller)
            verticalScrollerHeight -= scrollerWidth;

        var rect = _CGRectMake(_CGRectGetMaxX(newContentFrame), 
                               verticalScrollerY, 
                               scrollerWidth, 
                               verticalScrollerHeight);
                               
        [_verticalScroller setFrame:rect];
        //console.log('verticalScroller frame: %f, %f, %f, %f', rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    }

    if (_hasHorizontalScroller)
    {
        var rect = _CGRectMake(_CGRectGetMinX(newContentFrame), 
                               _CGRectGetMaxY(newContentFrame), 
                               _CGRectGetWidth(newContentFrame),
                               scrollerWidth);
                               
        [_horizontalScroller setFrame:rect];
        //console.log('horizontalScroller frame: %f, %f, %f, %f', rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    }
    
    [_cornerView setFrame:[self _cornerViewFrame]];
    [_headerClipView setFrame:[self _headerClipViewFrame]];
    
    if (shouldSetContentFrame)
    {
        //console.log('resizing content view: %f, %f', newContentFrame.size.width, newContentFrame.size.height);
        [_contentView setFrame:newContentFrame];
    }
    
    return newContentFrame;
}

- (void)reflectScrolledClipView:(CPClipView)aClipView
{
    //console.log('->reflect');

    if (_contentView !== aClipView)
        return;
        
    var documentView = [self documentView],
        headerClipRect = [_headerClipView frame];

    if (!documentView)
    {
        [_verticalScroller setEnabled:NO];
        [_verticalScroller setHidden:_autohidesScrollers];
        [_horizontalScroller setEnabled:NO];
        [_horizontalScroller setHidden:_autohidesScrollers];
    }
    else
    {
        var documentRect = [_contentView documentRect],
            contentRect = [_contentView bounds],
            widthDiff = _CGRectGetWidth(documentRect) - _CGRectGetWidth(contentRect),
            heightDiff = _CGRectGetHeight(documentRect) - _CGRectGetHeight(contentRect);

        //console.log('documentRect: %f, %f, %f, %f', documentRect.origin.x, documentRect.origin.y, documentRect.size.width, documentRect.size.height);
        //console.log('contentRect: %f, %f, %f, %f', contentRect.origin.x, contentRect.origin.y, contentRect.size.width, contentRect.size.height);
        //console.log('widthDiff: %f, heightDiff: %f', widthDiff, heightDiff);
        
        if (heightDiff <= 0)
        {
            [_verticalScroller setEnabled:NO];
            [_verticalScroller setHidden:_autohidesScrollers];
            [_verticalScroller setDoubleValue:0.0];
            [_verticalScroller setKnobProportion:1.0];
        }
        else
        {
            var scrollValue = (heightDiff <= 0) ? 0 : (_CGRectGetMinY(contentRect) - _CGRectGetMinY(documentRect)) / heightDiff;

            [_verticalScroller setEnabled:YES];
            [_verticalScroller setHidden:NO];
            [_verticalScroller setDoubleValue:scrollValue];
            [_verticalScroller setKnobProportion:_CGRectGetHeight(contentRect) / _CGRectGetHeight(documentRect)];
        }

        if (widthDiff <= 0)
        {
            [_horizontalScroller setEnabled:NO];
            [_horizontalScroller setHidden:_autohidesScrollers];
            [_horizontalScroller setDoubleValue:0.0];
            [_horizontalScroller setKnobProportion:1.0];
        }
        else
        {
            var scrollValue = (widthDiff <= 0) ? 0 : (_CGRectGetMinX(contentRect) - _CGRectGetMinX(documentRect)) / widthDiff;

            [_horizontalScroller setEnabled:YES];
            [_horizontalScroller setHidden:NO];
            [_horizontalScroller setDoubleValue:scrollValue];
            [_horizontalScroller setKnobProportion:_CGRectGetWidth(contentRect) / _CGRectGetWidth(documentRect)];
        }
    }

    //console.log('<-reflect');
}

/*
    @ignore
*/
-(void)resizeSubviewsWithOldSize:(CGSize)aSize
{
    //console.log('\n***CPScrollView -resize: %f, %f', [self bounds].size.width, [self bounds].size.height);
    [self tile];
}

// Setting Scrolling Behavior
/*!
    Sets how much the document moves when scrolled. Sets the vertical and horizontal scroll.
    @param aLineScroll the amount to move the document when scrolled
*/
- (void)setLineScroll:(float)aLineScroll
{
    [self setHorizonalLineScroll:aLineScroll];
    [self setVerticalLineScroll:aLineScroll];
}

/*!
    Returns how much the document moves when scrolled
*/
- (float)lineScroll
{
    return [self horizontalLineScroll];
}

/*!
    Sets how much the document moves when scrolled horizontally.
    @param aLineScroll the amount to move horizontally when scrolled.
*/
- (void)setHorizontalLineScroll:(float)aLineScroll
{
    _horizontalLineScroll = aLineScroll;
}

/*!
    Returns how much the document moves horizontally when scrolled.
*/
- (float)horizontalLineScroll
{
    return _horizontalLineScroll;
}

/*!
    Sets how much the document moves when scrolled vertically.
    @param aLineScroll the new amount to move vertically when scrolled.
*/
- (void)setVerticalLineScroll:(float)aLineScroll
{
    _verticalLineScroll = aLineScroll;
}

/*!
    Returns how much the document moves vertically when scrolled.
*/
- (float)verticalLineScroll
{
    return _verticalLineScroll;
}

/*!
    Sets the horizontal and vertical page scroll amount.
    @param aPageScroll the new horizontal and vertical page scroll amount
*/
- (void)setPageScroll:(float)aPageScroll
{
    [self setHorizontalPageScroll:aPageScroll];
    [self setVerticalPageScroll:aPageScroll];
}

/*!
    Returns the vertical and horizontal page scroll amount.
*/
- (float)pageScroll
{
    return [self horizontalPageScroll];
}

/*!
    Sets the horizontal page scroll amount.
    @param aPageScroll the new horizontal page scroll amount
*/
- (void)setHorizontalPageScroll:(float)aPageScroll
{
    _horizontalPageScroll = aPageScroll;
}

/*!
    Returns the horizontal page scroll amount.
*/
- (float)horizontalPageScroll
{
    return _horizontalPageScroll;
}

/*!
    Sets the vertical page scroll amount.
    @param aPageScroll the new vertcal page scroll amount
*/
- (void)setVerticalPageScroll:(float)aPageScroll
{
    _verticalPageScroll = aPageScroll;
}

/*!
    Returns the vertical page scroll amount.
*/
- (float)verticalPageScroll
{
    return _verticalPageScroll;
}

/*!
    Handles a scroll wheel event from the user.
    @param anEvent the scroll wheel event
*/
- (void)scrollWheel:(CPEvent)anEvent
{
    [self _respondToScrollWheelEventWithDeltaX:[anEvent deltaX] * _horizontalLineScroll
                                        deltaY:[anEvent deltaY] * _verticalLineScroll];
}

- (void)_respondToScrollWheelEventWithDeltaX:(float)deltaX deltaY:(float)deltaY
{
    var documentRect = [[self documentView] frame],
        contentBounds = [_contentView bounds],
        contentFrame = [_contentView frame],
        enclosingScrollView = [self enclosingScrollView],
        extraX = 0,
        extraY = 0;

    // We want integral bounds!
    contentBounds.origin.x = ROUND(contentBounds.origin.x + deltaX);
    contentBounds.origin.y = ROUND(contentBounds.origin.y + deltaY);

    var constrainedOrigin = [_contentView constrainScrollPoint:_CGPointCreateCopy(contentBounds.origin)];
    extraX = ((contentBounds.origin.x - constrainedOrigin.x) / _horizontalLineScroll) * [enclosingScrollView horizontalLineScroll];
    extraY = ((contentBounds.origin.y - constrainedOrigin.y) / _verticalLineScroll) * [enclosingScrollView verticalLineScroll];

    [_contentView scrollToPoint:constrainedOrigin];
    [_headerClipView scrollToPoint:_CGPointMake(constrainedOrigin.x, 0.0)];

    if (extraX || extraY)
        [enclosingScrollView _respondToScrollWheelEventWithDeltaX:extraX deltaY:extraY];
}

- (void)keyDown:(CPEvent)anEvent
{
    [self interpretKeyEvents:[anEvent]];
}

- (void)pageUp:(id)sender
{
    var contentBounds = [_contentView bounds];
    [self moveByOffset:_CGSizeMake(0.0, -(_CGRectGetHeight(contentBounds) - _verticalPageScroll))];
}

- (void)pageDown:(id)sender
{
    var contentBounds = [_contentView bounds];
    [self moveByOffset:_CGSizeMake(0.0, _CGRectGetHeight(contentBounds) - _verticalPageScroll)];
}

- (void)moveLeft:(id)sender
{
    [self moveByOffset:_CGSizeMake(-_horizontalLineScroll, 0.0)];
}

- (void)moveRight:(id)sender
{
    [self moveByOffset:_CGSizeMake(_horizontalLineScroll, 0.0)];
}

- (void)moveUp:(id)sender
{
    [self moveByOffset:_CGSizeMake(0.0, -_verticalLineScroll)];
}

- (void)moveDown:(id)sender
{
    [self moveByOffset:_CGSizeMake(0.0, _verticalLineScroll)];
}

- (void)moveByOffset:(CGSize)aSize
{
    var documentFrame = [[self documentView] frame],
        contentBounds = [_contentView bounds];

    contentBounds.origin.x += aSize.width;
    contentBounds.origin.y += aSize.height;

    [_contentView scrollToPoint:contentBounds.origin];
    [_headerClipView scrollToPoint:_CGPointMake(contentBounds.origin, 0)];
}

@end

var CPScrollViewContentViewKey       = "CPScrollViewContentView",
    CPScrollViewHeaderClipViewKey    = "CPScrollViewHeaderClipViewKey",
    CPScrollViewVLineScrollKey       = "CPScrollViewVLineScroll",
    CPScrollViewHLineScrollKey       = "CPScrollViewHLineScroll",
    CPScrollViewVPageScrollKey       = "CPScrollViewVPageScroll",
    CPScrollViewHPageScrollKey       = "CPScrollViewHPageScroll",
    CPScrollViewHasVScrollerKey      = "CPScrollViewHasVScroller",
    CPScrollViewHasHScrollerKey      = "CPScrollViewHasHScroller",
    CPScrollViewVScrollerKey         = "CPScrollViewVScroller",
    CPScrollViewHScrollerKey         = "CPScrollViewHScroller",
    CPScrollViewAutohidesScrollerKey = "CPScrollViewAutohidesScroller",
    CPScrollViewCornerViewKey        = "CPScrollViewCornerViewKey",
    CPScrollViewBorderTypeKey        = "CPScrollViewBorderTypeKey";

@implementation CPScrollView (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [super initWithCoder:aCoder])
    {
        _verticalLineScroll     = [aCoder decodeFloatForKey:CPScrollViewVLineScrollKey];
        _verticalPageScroll     = [aCoder decodeFloatForKey:CPScrollViewVPageScrollKey];

        _horizontalLineScroll   = [aCoder decodeFloatForKey:CPScrollViewHLineScrollKey];
        _horizontalPageScroll   = [aCoder decodeFloatForKey:CPScrollViewHPageScrollKey];

        _contentView            = [aCoder decodeObjectForKey:CPScrollViewContentViewKey];
        _headerClipView         = [aCoder decodeObjectForKey:CPScrollViewHeaderClipViewKey];
        
        var haveHeader = _headerClipView != nil;
        
        if (!haveHeader)
        {
            _headerClipView = [[CPClipView alloc] init];
            [self addSubview:_headerClipView];
        }

        _verticalScroller       = [aCoder decodeObjectForKey:CPScrollViewVScrollerKey];
        _horizontalScroller     = [aCoder decodeObjectForKey:CPScrollViewHScrollerKey];

        _hasVerticalScroller    = [aCoder decodeBoolForKey:CPScrollViewHasVScrollerKey];
        _hasHorizontalScroller  = [aCoder decodeBoolForKey:CPScrollViewHasHScrollerKey];
        _autohidesScrollers     = [aCoder decodeBoolForKey:CPScrollViewAutohidesScrollerKey];

        _borderType             = [aCoder decodeIntForKey:CPScrollViewBorderTypeKey];
        
        [self _initBorderInsets];

        _cornerView             = [aCoder decodeObjectForKey:CPScrollViewCornerViewKey];
        
        if (!_cornerView && !_autohidesScrollers && haveHeader)
        {
            var documentView = [self documentView],
                cornerView = [documentView respondsToSelector:@selector(cornerView)] ? [documentView cornerView] : nil;
                
            if (cornerView)
            {
                // When autohide scrollers is off, the y coordinate can be wrong because
                // of coordinate swapping in nib2cib.
                var frame = [cornerView frame];
                frame.origin.y = _CGRectGetMinY([self bounds]);
                
                _cornerView = cornerView;
                [_cornerView setFrame:frame];
            }
        }
        
        [self _init];
    }

    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];

    [aCoder encodeObject:_contentView           forKey:CPScrollViewContentViewKey];
    [aCoder encodeObject:_headerClipView        forKey:CPScrollViewHeaderClipViewKey];

    [aCoder encodeObject:_verticalScroller      forKey:CPScrollViewVScrollerKey];
    [aCoder encodeObject:_horizontalScroller    forKey:CPScrollViewHScrollerKey];

    [aCoder encodeFloat:_verticalLineScroll     forKey:CPScrollViewVLineScrollKey];
    [aCoder encodeFloat:_verticalPageScroll     forKey:CPScrollViewVPageScrollKey];
    [aCoder encodeFloat:_horizontalLineScroll   forKey:CPScrollViewHLineScrollKey];
    [aCoder encodeFloat:_horizontalPageScroll   forKey:CPScrollViewHPageScrollKey];

    [aCoder encodeBool:_hasVerticalScroller     forKey:CPScrollViewHasVScrollerKey];
    [aCoder encodeBool:_hasHorizontalScroller   forKey:CPScrollViewHasHScrollerKey];
    [aCoder encodeBool:_autohidesScrollers      forKey:CPScrollViewAutohidesScrollerKey];

    [aCoder encodeObject:_cornerView            forKey:CPScrollViewCornerViewKey];
    
    [aCoder encodeInt:_borderType               forKey:CPScrollViewBorderTypeKey];
}

@end
