/*
 * CPTableHeaderView.j
 * AppKit
 *
 * Created by Ross Boucher.
 * Copyright 2009 280 North, Inc.
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

@import "CPTableColumn.j"
@import "CPTableView.j"
@import "CPView.j"

#include "CoreGraphics/CGGeometry.h"

 
@implementation _CPTableColumnHeaderView : CPView
{
    _CPImageAndTextView     _textField;
}

- (void)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {   
        [self _init];
    }

    return self;
}

- (void)_init
{
    _textField = [[_CPImageAndTextView alloc] initWithFrame:
        _CGRectMake(5.0, 0.0, _CGRectGetWidth([self bounds]) - 10.0, _CGRectGetHeight([self bounds]))];
        
    [_textField setAutoresizingMask:CPViewWidthSizable|CPViewHeightSizable];

    [_textField setLineBreakMode:CPLineBreakByTruncatingTail];
    [_textField setTextColor:[CPColor colorWithRed:51.0 / 255.0 green:51.0 / 255.0 blue:51.0 / 255.0 alpha:1.0]];
    [_textField setFont:[CPFont boldSystemFontOfSize:12.0]];
    [_textField setAlignment:CPLeftTextAlignment];
    [_textField setVerticalAlignment:CPCenterVerticalTextAlignment];
    [_textField setTextShadowColor:[CPColor whiteColor]];
    [_textField setTextShadowOffset:_CGSizeMake(0,1)];

    [self addSubview:_textField];
}

- (void)layoutSubviews
{
    var themeState = [self themeState];

    if (themeState & CPThemeStateSelected && themeState & CPThemeStateHighlighted)
        [self setBackgroundColor:[CPColor colorWithPatternImage:CPAppKitImage("tableview-headerview-highlighted-pressed.png", _CGSizeMake(1.0, 23.0))]];
    else if (themeState & CPThemeStateSelected)
        [self setBackgroundColor:[CPColor colorWithPatternImage:CPAppKitImage("tableview-headerview-highlighted.png", _CGSizeMake(1.0, 23.0))]];
    else if (themeState & CPThemeStateHighlighted)
        [self setBackgroundColor:[CPColor colorWithPatternImage:CPAppKitImage("tableview-headerview-pressed.png", _CGSizeMake(1.0, 23.0))]];
    else 
        [self setBackgroundColor:[CPColor colorWithPatternImage:CPAppKitImage("tableview-headerview.png", _CGSizeMake(1.0, 23.0))]];
}

- (void)setStringValue:(CPString)string
{
    [_textField setText:string];
}

- (CPString)stringValue
{
    return [_textField text];
}

- (void)textField
{
    return _textField;
}

- (void)sizeToFit
{
    [_textField sizeToFit];
}

- (void)setFont:(CPFont)aFont
{
    [_textField setFont:aFont];
}

- (void)setValue:(id)aValue forThemeAttribute:(id)aKey
{
    [_textField setValue:aValue forThemeAttribute:aKey];
}

- (void)_setIndicatorImage:(CPImage)anImage
{
	if (anImage)
	{
		[_textField setImage:anImage];
		[_textField setImagePosition:CPImageRight];
	}
	else
	{
		[_textField setImagePosition:CPNoImage];
	}
}

- (void)drawRect:(CGRect)aRect
{
    var bounds = [self bounds];
    
    if (!CGRectIntersectsRect(aRect, bounds))
        return;
        
    var context = [[CPGraphicsContext currentContext] graphicsPort],
        maxX = _CGRectGetMaxX(bounds) - 0.5;

    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColor(context, [CPColor colorWithWhite:192.0/255.0 alpha:1.0]);
    
    CGContextBeginPath(context);
    
    CGContextMoveToPoint(context, maxX, _CGRectGetMinY(bounds));
    CGContextAddLineToPoint(context, maxX, _CGRectGetMaxY(bounds));
    
    CGContextStrokePath(context);
}

@end

var _CPTableColumnHeaderViewStringValueKey = @"_CPTableColumnHeaderViewStringValueKey",
    _CPTableColumnHeaderViewFontKey = @"_CPTableColumnHeaderViewFontKey",
    _CPTableColumnHeaderViewImageKey = @"_CPTableColumnHeaderViewImageKey";

@implementation _CPTableColumnHeaderView (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [super initWithCoder:aCoder])
    {
        [self _init];
        [self _setIndicatorImage:[aCoder decodeObjectForKey:_CPTableColumnHeaderViewImageKey]];
        [self setStringValue:[aCoder decodeObjectForKey:_CPTableColumnHeaderViewStringValueKey]];
        [self setFont:[aCoder decodeObjectForKey:_CPTableColumnHeaderViewFontKey]];
    }

    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];

    [aCoder encodeObject:[_textField text] forKey:_CPTableColumnHeaderViewStringValueKey];
    [aCoder encodeObject:[_textField image] forKey:_CPTableColumnHeaderViewImageKey];
    [aCoder encodeObject:[_textField font] forKey:_CPTableColumnHeaderViewFontKey];
}

@end

var CPTableHeaderViewResizeZone = 3.0;

@implementation CPTableHeaderView : CPView
{
    CGPoint     _mouseDownLocation;
    CGPoint     _mouseEnterExitLocation;
    CGPoint     _previousTrackingLocation;
    
    int         _activeColumn;
    int         _pressedColumn;
                
    BOOL        _isResizing;
    BOOL        _isDragging;
    BOOL        _isTrackingColumn;
                
    float       _columnOldWidth;
                
    CPTableView _tableView @accessors(property=tableView);
}

- (void)_init
{
    _mouseDownLocation = _CGPointMakeZero();
    _mouseEnterExitLocation = _CGPointMakeZero();
    _previousTrackingLocation = _CGPointMakeZero();
    
    _activeColumn = -1;
    _pressedColumn = -1;

    _isResizing = NO;
    _isDragging = NO;
    _isTrackingColumn = NO;

    _columnOldWidth = 0.0;

    [self setBackgroundColor:[CPColor colorWithPatternImage:CPAppKitImage("tableview-headerview.png", _CGSizeMake(1.0, 23.0))]];
}

- (id)initWithFrame:(CGRect)aFrame
{
    self = [super initWithFrame:aFrame];

    if (self)
        [self _init];

    return self;
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    [[self window] setAcceptsMouseMovedEvents:YES];
}

- (int)columnAtPoint:(CGPoint)aPoint
{
    return [_tableView columnAtPoint:_CGPointMake(aPoint.x, aPoint.y)];
}

- (CGRect)headerRectOfColumn:(int)aColumnIndex
{
    var headerRect = [self bounds],
        columnRect = [_tableView rectOfColumn:aColumnIndex];

    headerRect.origin.x = _CGRectGetMinX(columnRect);
    headerRect.size.width = _CGRectGetWidth(columnRect);

    return headerRect;
}

- (CGRect)_cursorRectForColumn:(int)column
{
    if (column == -1 || !([_tableView._tableColumns[column] resizingMask] & CPTableColumnUserResizingMask))
        return _CGRectMakeZero();

    var rect = [self headerRectOfColumn:column];

    rect.origin.x = (_CGRectGetMaxX(rect) - CPTableHeaderViewResizeZone) - 1.0;
    rect.size.width = (CPTableHeaderViewResizeZone * 2.0) + 1.0;  // + 1 for resize line
    
    return rect;
}

- (void)_setPressedColumn:(CPInteger)column
{
    if (_pressedColumn != -1)
    {
        var headerView = [_tableView._tableColumns[_pressedColumn] headerView];
        [headerView unsetThemeState:CPThemeStateHighlighted];
    }    

    if (column != -1)
    {
        var headerView = [_tableView._tableColumns[column] headerView];
        [headerView setThemeState:CPThemeStateHighlighted];
    }

    _pressedColumn = column;
}

- (void)mouseDown:(CPEvent)theEvent
{
    [self _trackMouse:theEvent];
}

- (void)_trackMouse:(CPEvent)theEvent
{
    var type = [theEvent type],
        currentLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil],
        adjustedLocation = _CGPointMake(MAX(currentLocation.x - CPTableHeaderViewResizeZone, 0.0), currentLocation.y),
        columnIndex = [self columnAtPoint:adjustedLocation],
        shouldResize = [self _shouldResizeTableColumn:columnIndex at:currentLocation];

    if (type === CPLeftMouseUp)
    {
        if (shouldResize)
            [self stopResizingTableColumn:_activeColumn at:currentLocation];
        else if ([self _shouldStopTrackingTableColumn:columnIndex at:currentLocation])
        {
            [_tableView _didClickTableColumn:columnIndex modifierFlags:[theEvent modifierFlags]];
            [self _stopTrackingTableColumn:columnIndex at:currentLocation];
        }

        [self _updateResizeCursor:[CPApp currentEvent]];

        _isTrackingColumn = NO;
        _activeColumn = CPNotFound;
        return;
    }

    if (type === CPLeftMouseDown)
    {
        if (columnIndex === -1)
            return;

        _mouseDownLocation = currentLocation;
        _activeColumn = columnIndex;

        [_tableView _sendDelegateDidMouseDownInHeader:columnIndex];

        if (shouldResize)
            [self _startResizingTableColumn:columnIndex at:currentLocation];
        else
        {
            [self _startTrackingTableColumn:columnIndex at:currentLocation];
            _isTrackingColumn = YES;
        }
    }
    else if (type === CPLeftMouseDragged)
    {
        if (shouldResize)
            [self _continueResizingTableColumn:_activeColumn at:currentLocation];
        else
        {
            if (_activeColumn === columnIndex && _CGRectContainsPoint([self headerRectOfColumn:columnIndex], currentLocation))
            {
                if (_isTrackingColumn && _pressedColumn !== -1)
                {
                    if (![self _continueTrackingTableColumn:columnIndex at:currentLocation])
                        return; // Stop tracking the column, because it's being dragged
                }
                else
                    [self _startTrackingTableColumn:columnIndex at:currentLocation];

            }
            else if (_isTrackingColumn && _pressedColumn !== -1)
                [self _stopTrackingTableColumn:_activeColumn at:currentLocation];
        }
    }

    _previousTrackingLocation = currentLocation;
    [CPApp setTarget:self selector:@selector(_trackMouse:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
}

- (void)_startTrackingTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    [self _setPressedColumn:aColumnIndex];
}

- (BOOL)_continueTrackingTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    if ([self _shouldDragTableColumn:aColumnIndex at:aPoint])
    {
        var columnRect = [self headerRectOfColumn:aColumnIndex],
            offset = _CGPointMakeZero(),
            view = [_tableView _dragViewForColumn:aColumnIndex event:[CPApp currentEvent] offset:offset],
            viewLocation = _CGPointMakeZero();

        viewLocation.x = ( _CGRectGetMinX(columnRect) + offset.x ) + ( aPoint.x - _mouseDownLocation.x );
        viewLocation.y = _CGRectGetMinY(columnRect) + offset.y;

        [self dragView:view at:viewLocation offset:CPSizeMakeZero() event:[CPApp currentEvent] 
            pasteboard:[CPPasteboard pasteboardWithName:CPDragPboard] source:self slideBack:YES];

        return NO;
    }

    return YES;
}

- (BOOL)_shouldStopTrackingTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    return _isTrackingColumn && 
           _activeColumn === aColumnIndex && 
           _CGRectContainsPoint([self headerRectOfColumn:aColumnIndex], aPoint);
}

- (void)_stopTrackingTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    [self _setPressedColumn:CPNotFound];
    [self _updateResizeCursor:[CPApp currentEvent]];
}

- (BOOL)_shouldDragTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    return [_tableView allowsColumnReordering] && ABS(aPoint.x - _mouseDownLocation.x) >= 10.0;
}

- (CGRect)_headerRectOfLastVisibleColumn
{
    var tableColumns = [_tableView tableColumns],
        columnIndex = [tableColumns count];

    while (columnIndex--)
    {
        var tableColumn = [tableColumns objectAtIndex:columnIndex];

        if (![tableColumn isHidden])
            return [self headerRectOfColumn:columnIndex];
    }

    return nil;
}

- (void)_constrainDragView:(CPView)theDragView at:(CGPoint)aPoint
{
    var tableColumns = [_tableView tableColumns],
        lastColumnRect = [self _headerRectOfLastVisibleColumn];
        activeColumnRect = [self headerRectOfColumn:_activeColumn];
        dragWindow = [theDragView window],
        frame = [dragWindow frame];

    // Convert the frame origin from the global coordinate system to the windows' coordinate system
    frame.origin = [[self window] convertGlobalToBase:frame.origin];
    // the from the window to the view
    frame.origin = [self convertPoint:frame.origin fromView:nil];

    // This effectively clamps the value between the minimum and maximum
    frame.origin.x = MAX(0.0, MIN(_CGRectGetMinX(frame), _CGRectGetMaxX(lastColumnRect) - _CGRectGetWidth(activeColumnRect)));

    // Make sure the column cannot move vertically
    frame.origin.y = _CGRectGetMinY(lastColumnRect);

    // Convert the calculated origin back to the window coordinate system
    frame.origin = [self convertPoint:frame.origin toView:nil];
    // Then back to the global coordinate system
    frame.origin = [[self window] convertBaseToGlobal:frame.origin];

    [dragWindow setFrame:frame];
}

- (void)_moveColumn:(int)aFromIndex toColumn:(int)aToIndex
{
    [_tableView moveColumn:aFromIndex toColumn:aToIndex];
    _activeColumn = aToIndex;
    _pressedColumn = _activeColumn;

    [_tableView _setDraggedColumn:_activeColumn];
}

- (void)draggedView:(CPView)aView beganAt:(CGPoint)aPoint
{
    _isDragging = YES;

    [[[[_tableView tableColumns] objectAtIndex:_activeColumn] headerView] setHidden:YES];
    [_tableView _setDraggedColumn:_activeColumn];

    [self setNeedsDisplay:YES];
}

- (void)draggedView:(CPView)aView movedTo:(CGPoint)aPoint
{
    [self _constrainDragView:aView at:aPoint];

    var dragWindow = [aView window],
        dragWindowFrame = [dragWindow frame];

    var hoverPoint = _CGPointCreateCopy(aPoint);

    if (aPoint.x < _previousTrackingLocation.x)
        hoverPoint = _CGPointMake(_CGRectGetMinX(dragWindowFrame), _CGRectGetMinY(dragWindowFrame));
    else if (aPoint.x > _previousTrackingLocation.x)
        hoverPoint = _CGPointMake(_CGRectGetMaxX(dragWindowFrame), _CGRectGetMinY(dragWindowFrame));

    // Convert the hover point from the global coordinate system to windows' coordinate system
    hoverPoint = [[self window] convertGlobalToBase:hoverPoint];
    // then to the view
    hoverPoint = [self convertPoint:hoverPoint fromView:nil];

    var hoveredColumn = [self columnAtPoint:hoverPoint];

    if (hoveredColumn !== -1)
    {
        var columnRect = [self headerRectOfColumn:hoveredColumn],
            columnCenterPoint = [self convertPoint:_CGPointMake(_CGRectGetMidX(columnRect), _CGRectGetMidY(columnRect)) fromView:self];
        if (hoveredColumn < _activeColumn && hoverPoint.x < columnCenterPoint.x)
            [self _moveColumn:_activeColumn toColumn:hoveredColumn];
        else if (hoveredColumn > _activeColumn && hoverPoint.x > columnCenterPoint.x)
            [self _moveColumn:_activeColumn toColumn:hoveredColumn];
    }

    _previousTrackingLocation = aPoint;
}

- (void)draggedView:(CPImage)aView endedAt:(CGPoint)aLocation operation:(CPDragOperation)anOperation
{
    _isDragging = NO;
    _isTrackingColumn = NO; // We need to do this explicitly because the mouse up section of trackMouse is never reached

    [_tableView _setDraggedColumn:-1];
    [[[[_tableView tableColumns] objectAtIndex:_activeColumn] headerView] setHidden:NO];
    [self _stopTrackingTableColumn:_activeColumn at:aLocation];

    [self setNeedsDisplay:YES];
}

- (BOOL)_shouldResizeTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    if (_isResizing)
        return YES;

    if (_isTrackingColumn)
        return NO;

    return [_tableView allowsColumnResizing] && _CGRectContainsPoint([self _cursorRectForColumn:aColumnIndex], aPoint);
}

- (void)_startResizingTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    _isResizing = YES;

    var tableColumn = [[_tableView tableColumns] objectAtIndex:aColumnIndex];

    [tableColumn setDisableResizingPosting:YES];
    [_tableView setDisableAutomaticResizing:YES];
}

- (void)_continueResizingTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    var tableColumn = [[_tableView tableColumns] objectAtIndex:aColumnIndex],
        delta = aPoint.x - _previousTrackingLocation.x,
        spacing = [_tableView intercellSpacing].width,
        newWidth = [tableColumn width] + spacing + delta,
        minWidth = [tableColumn minWidth] + spacing,
        maxWidth = [tableColumn maxWidth] + spacing;
        
    if (newWidth <= minWidth)
        [[CPCursor resizeRightCursor] set];
    else if (newWidth >= maxWidth)
        [[CPCursor resizeLeftCursor] set];
    else
        [[CPCursor resizeLeftRightCursor] set];
        
    var columnRect = [_tableView rectOfColumn:aColumnIndex],
        columnWidth = _CGRectGetWidth(columnRect);
    
    if ((delta > 0 && columnWidth == maxWidth) || (delta < 0 && columnWidth == minWidth))
        return;
        
    var columnMinX = _CGRectGetMinX(columnRect),
        columnMaxX = _CGRectGetMaxX(columnRect);
        
    if ((delta > 0 && aPoint.x > columnMaxX) || (delta < 0 && aPoint.x < columnMaxX))
    {
        _tableView._lastColumnShouldSnap = NO;
        [tableColumn setWidth:newWidth - spacing];

        [self setNeedsLayout];
        [self setNeedsDisplay:YES];
    }
}

- (void)stopResizingTableColumn:(int)aColumnIndex at:(CGPoint)aPoint
{
    var tableColumn = [[_tableView tableColumns] objectAtIndex:aColumnIndex];
    [tableColumn _postDidResizeNotificationWithOldWidth:_columnOldWidth];
    [tableColumn setDisableResizingPosting:NO];
    [_tableView setDisableAutomaticResizing:NO];

    _isResizing = NO;
}

- (void)_updateResizeCursor:(CPEvent)theEvent
{
    // never get stuck in resize cursor mode (FIXME take out when we turn on tracking rects)
    if (![_tableView allowsColumnResizing] || ([theEvent type] === CPLeftMouseUp && ![[self window] acceptsMouseMovedEvents]))
    {
        [[CPCursor arrowCursor] set];
        return;
    }

    var mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil],    
        mouseOverLocation = _CGPointMake(MAX(mouseLocation.x - CPTableHeaderViewResizeZone, 0.0), mouseLocation.y),
        overColumn = [self columnAtPoint:mouseOverLocation];

    if (overColumn >= 0 && _CGRectContainsPoint([self _cursorRectForColumn:overColumn], mouseLocation))
    {
        var tableColumn = [[_tableView tableColumns] objectAtIndex:overColumn],
            spacing = [_tableView intercellSpacing].width,
            width = [tableColumn width] + spacing,

        if (width <= [tableColumn minWidth])
            [[CPCursor resizeRightCursor] set];
        else if (width >= [tableColumn maxWidth])
            [[CPCursor resizeLeftCursor] set];
        else
            [[CPCursor resizeLeftRightCursor] set];
    }
    else
        [[CPCursor arrowCursor] set];
}

- (void)mouseEntered:(CPEvent)theEvent
{
    var location = [theEvent globalLocation];
    
    if (_CGPointEqualToPoint(location, _mouseEnterExitLocation))
        return;
        
    _mouseEnterExitLocation = location;
    
    [self _updateResizeCursor:theEvent];
}

- (void)mouseMoved:(CPEvent)theEvent
{
    [self _updateResizeCursor:theEvent];
}

- (void)mouseExited:(CPEvent)theEvent
{
    var location = [theEvent globalLocation];
    
    if (_CGPointEqualToPoint(location, _mouseEnterExitLocation))
        return;
        
    _mouseEnterExitLocation = location;
    
    // FIXME: we should use CPCursor push/pop (if previous currentCursor != arrow).
    [[CPCursor arrowCursor] set];
}

- (void)layoutSubviews
{
    var tableColumns = [_tableView tableColumns],
        count = [tableColumns count];    

    for (var i = 0; i < count; i++) 
    {
        var column = [tableColumns objectAtIndex:i],
            headerView = [column headerView],
            frame = [self headerRectOfColumn:i];
        
        [headerView setFrame:frame];

        if ([headerView superview] != self)
            [self addSubview:headerView];
    }
}

- (void)drawRect:(CGRect)aRect
{
    if (!_tableView)
        return;

    if (_isDragging)
    {
        var context = [[CPGraphicsContext currentContext] graphicsPort];
        
        CGContextSetFillColor(context, [CPColor grayColor]);
        CGContextFillRect(context, [self headerRectOfColumn:_activeColumn])
    }
}

@end

var CPTableHeaderViewTableViewKey = @"CPTableHeaderViewTableViewKey";

@implementation CPTableHeaderView (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [super initWithCoder:aCoder])
    {
        [self _init];
        _tableView = [aCoder decodeObjectForKey:CPTableHeaderViewTableViewKey];
    }

    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:_tableView forKey:CPTableHeaderViewTableViewKey];
}

@end