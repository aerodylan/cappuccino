/*
 * CPTableView.j
 * AppKit
 *
 * Created by Francisco Tolmasky.
 * Copyright 2009, 280 North, Inc.
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

@import <Foundation/CPArray.j>
@import <AppKit/CGGradient.j>

@import "CPControl.j"
@import "_CPTableRowData.j"
@import "CPTableColumn.j"
@import "_CPCornerView.j"
@import "CPScroller.j"

#include "CoreGraphics/CGGeometry.h"

CPTableViewColumnDidMoveNotification        = @"CPTableViewColumnDidMoveNotification";
CPTableViewColumnDidResizeNotification      = @"CPTableViewColumnDidResizeNotification";
CPTableViewSelectionDidChangeNotification   = @"CPTableViewSelectionDidChangeNotification";
CPTableViewSelectionIsChangingNotification  = @"CPTableViewSelectionIsChangingNotification";

var CPTableViewDataSource_numberOfRowsInTableView_                                                      = 1 << 0,
    CPTableViewDataSource_tableView_objectValueForTableColumn_row_                                      = 1 << 1,
    CPTableViewDataSource_tableView_setObjectValue_forTableColumn_row_                                  = 1 << 2,
    CPTableViewDataSource_tableView_acceptDrop_row_dropOperation_                                       = 1 << 3,
    CPTableViewDataSource_tableView_namesOfPromisedFilesDroppedAtDestination_forDraggedRowsWithIndexes_ = 1 << 4,
    CPTableViewDataSource_tableView_validateDrop_proposedRow_proposedDropOperation_                     = 1 << 5,
    CPTableViewDataSource_tableView_writeRowsWithIndexes_toPasteboard_                                  = 1 << 6,

    CPTableViewDataSource_tableView_sortDescriptorsDidChange_                                           = 1 << 7;

var CPTableViewDelegate_selectionShouldChangeInTableView_                                               = 1 << 0,
    CPTableViewDelegate_tableView_dataViewForTableColumn_row_                                           = 1 << 1,
    CPTableViewDelegate_tableView_didClickTableColumn_                                                  = 1 << 2,
    CPTableViewDelegate_tableView_didDragTableColumn_                                                   = 1 << 3,
    CPTableViewDelegate_tableView_heightOfRow_                                                          = 1 << 4,
    CPTableViewDelegate_tableView_isGroupRow_                                                           = 1 << 5,
    CPTableViewDelegate_tableView_mouseDownInHeaderOfTableColumn_                                       = 1 << 6,
    CPTableViewDelegate_tableView_nextTypeSelectMatchFromRow_toRow_forString_                           = 1 << 7,
    CPTableViewDelegate_tableView_selectionIndexesForProposedSelection_                                 = 1 << 8,
    CPTableViewDelegate_tableView_shouldEditTableColumn_row_                                            = 1 << 9,
    CPTableViewDelegate_tableView_shouldSelectRow_                                                      = 1 << 10,
    CPTableViewDelegate_tableView_shouldSelectTableColumn_                                              = 1 << 11,
    CPTableViewDelegate_tableView_shouldShowViewExpansionForTableColumn_row_                            = 1 << 12,
    CPTableViewDelegate_tableView_shouldTrackView_forTableColumn_row_                                   = 1 << 13,
    CPTableViewDelegate_tableView_shouldTypeSelectForEvent_withCurrentSearchString_                     = 1 << 14,
    CPTableViewDelegate_tableView_toolTipForView_rect_tableColumn_row_mouseLocation_                    = 1 << 15,
    CPTableViewDelegate_tableView_typeSelectStringForTableColumn_row_                                   = 1 << 16,
    CPTableViewDelegate_tableView_willDisplayView_forTableColumn_row_                                   = 1 << 17,
    CPTableViewDelegate_tableViewSelectionDidChange_                                                    = 1 << 18,
    CPTableViewDelegate_tableViewSelectionIsChanging_                                                   = 1 << 19;

var CPTableViewResizeFirstColumn = 1,
    CPTableViewResizeLastColumn = 2,
    CPTableViewResizeLastVisibleColumn = 3,
    CPTableViewResizeFirstAvailableColumn = 4,
    CPTableViewResizeLastAvailableColumn = 5;
    
//CPTableViewDraggingDestinationFeedbackStyles
CPTableViewDraggingDestinationFeedbackStyleNone = -1;
CPTableViewDraggingDestinationFeedbackStyleRegular = 0;
CPTableViewDraggingDestinationFeedbackStyleSourceList = 1;

//CPTableViewDropOperations
CPTableViewDropOn = 0;
CPTableViewDropAbove = 1;

CPSourceListGradient = "CPSourceListGradient";
CPSourceListTopLineColor = "CPSourceListTopLineColor";
CPSourceListBottomLineColor = "CPSourceListBottomLineColor";

// TODO: add docs

CPTableViewSelectionHighlightStyleNone = -1;
CPTableViewSelectionHighlightStyleRegular = 0;
CPTableViewSelectionHighlightStyleSourceList = 1;

CPTableViewGridNone                    = 0;
CPTableViewSolidVerticalGridLineMask   = 1 << 0;
CPTableViewSolidHorizontalGridLineMask = 1 << 1;

CPTableViewNoColumnAutoresizing = 0;
CPTableViewUniformColumnAutoresizingStyle = 1;
CPTableViewSequentialColumnAutoresizingStyle = 2;
CPTableViewReverseSequentialColumnAutoresizingStyle = 3;
CPTableViewLastColumnOnlyAutoresizingStyle = 4;
CPTableViewFirstColumnOnlyAutoresizingStyle = 5;


#define NUMBER_OF_COLUMNS() (_tableColumns.length)
#define UPDATE_COLUMN_RANGES_IF_NECESSARY() if (_recalcColumnRangeStartingIndex !== -1) [self _recalculateTableColumnRanges];

/*!
    @ingroup appkit
    @class CPTableView

    CPTableView object displays record-oriented data in a table and
    allows the user to edit values and resize and rearrange columns.
    A CPTableView requires you to set a dataSource which implements numberOfRowsInTableView:
    and tableView:objectValueForTableColumn:row:
*/

var CPTableViewDefaultRowHeight = 23.0,
    CPTableViewDragSlop = 3;
    CLICK_SPACE_DELTA = 5.0; // Stolen from AppKit/Platform/DOM/CPPlatformWindow+DOM.j
;

@implementation CPTableView : CPControl
{
    id          _dataSource;
    CPInteger   _implementedDataSourceMethods;

    unsigned    _numberOfRows;

    id          _delegate;
    CPInteger   _implementedDelegateMethods;

    CPArray     _tableColumns;
    CPArray     _tableColumnRanges;
    CPInteger   _recalcColumnRangeStartingIndex;
    CPInteger   _numberOfHiddenColumns;
    
    _CPTableRowData  _rowData;
    
    // Configuring Behavior
    BOOL        _allowsColumnReordering;
    BOOL        _allowsColumnResizing;
    BOOL        _allowsColumnSelection;
    BOOL        _allowsMultipleSelection;
    BOOL        _allowsEmptySelection;

    CPArray     _sortDescriptors;
    
    // Setting Display Attributes
    CGSize      _intercellSpacing;
    float       _rowHeight;

    BOOL        _usesAlternatingRowBackgroundColors;
    CPArray     _alternatingRowBackgroundColors;

    unsigned        _selectionHighlightStyle;
    CPTableColumn   _currentHighlightedTableColumn;
    CPColor         _selectionHighlightColor;
    unsigned        _gridStyleMask;
    CPColor         _gridColor;
    unsigned        _columnAutoResizingStyle;


    CPTableHeaderView _headerView;
    _CPCornerView     _cornerView;

    CPIndexSet  _selectedColumnIndexes;
    CPIndexSet  _selectedRowIndexes;
    CPInteger   _selectionAnchorRow;
    CPInteger   _lastSelectedRow;
    CPIndexSet  _previouslySelectedRowIndexes;
    CGPoint     _startTrackingPoint;
    CPDate      _startTrackingTimestamp;
    BOOL        _trackingPointMovedOutOfClickSlop;
    CGPoint     _editingCellIndex;

    SEL         _doubleAction;
    
    CPInteger   _clickedRow;
    CPInteger   _clickedColumn;

    int         _lastTrackedRowIndex;
    CGPoint     _originalMouseDownPoint;
    BOOL        _verticalMotionCanDrag;
    unsigned    _destinationDragStyle;
    BOOL        _isSelectingSession;
    CPIndexSet  _draggedRowIndexes;

    _CPDropOperationDrawingView _dropOperationFeedbackView;
    CPDragOperation             _dragOperationDefaultMask;
    int                         _retargetedDropRow;
    CPDragOperation             _retargetedDropOperation;

    BOOL        _disableAutomaticResizing @accessors(property=disableAutomaticResizing);

    CPGradient  _sourceListActiveGradient;
    CPColor     _sourceListActiveTopLineColor;
    CPColor     _sourceListActiveBottomLineColor;

    int         _draggedColumnIndex;
    BOOL        _draggedColumnIsSelected;
    CPArray     _deferedColumnDataToRemove;

/*
    CPGradient  _sourceListInactiveGradient;
    CPColor     _sourceListInactiveTopLineColor;
    CPColor     _sourceListInactiveBottomLineColor;
*/
}

- (id)initWithFrame:(CGRect)aFrame
{
    self = [super initWithFrame:aFrame];

    if (self)
    {
        // Configuring Behavior
        _allowsColumnReordering = YES;
        _allowsColumnResizing = YES;
        _allowsMultipleSelection = NO;
        _allowsEmptySelection = YES;
        _allowsColumnSelection = NO;
        _disableAutomaticResizing = NO;

        // Setting Display Attributes
        _selectionHighlightStyle = CPTableViewSelectionHighlightStyleRegular;
        _columnAutoResizingStyle = CPTableViewLastColumnOnlyAutoresizingStyle;

        [self setUsesAlternatingRowBackgroundColors:NO];
        _alternatingRowBackgroundColors = nil;

        _tableColumns = [];

        _intercellSpacing = _CGSizeMake(3.0, 2.0);
        _rowHeight = CPTableViewDefaultRowHeight;

        [self setGridColor:[CPColor colorWithHexString:@"c0c0c0"]];
        [self setGridStyleMask:CPTableViewGridNone];

        _cornerView = nil;

        _lastSelectedRow = -1;
        _currentHighlightedTableColumn = nil;

        _sortDescriptors = [CPArray array];

        _draggedRowIndexes = [CPIndexSet indexSet];
        _verticalMotionCanDrag = YES;
        _isSelectingSession = NO;
        _retargetedDropRow = nil;
        _retargetedDropOperation = nil;
        _dragOperationDefaultMask = nil;
        _destinationDragStyle = CPTableViewDraggingDestinationFeedbackStyleRegular;

        [self setBackgroundColor:[CPColor whiteColor]];
        [self _init];
    }

    return self;
}

- (void)_init
{
    _disableAutomaticResizing = NO;
    _tableViewFlags = 0;

    _selectedColumnIndexes = [CPIndexSet indexSet];
    _selectedRowIndexes = [CPIndexSet indexSet];

    if (!_alternatingRowBackgroundColors)
        _alternatingRowBackgroundColors = [[CPColor whiteColor], [CPColor colorWithHexString:@"e4e7ff"]];

    _selectionHighlightColor = [CPColor colorWithHexString:@"5990e3"];

    _tableColumnRanges = [];
    _recalcColumnRangeStartingIndex = 0;
    _numberOfHiddenColumns = 0;
    _numberOfRows = 0;
    
    [self _recalculateTableColumnRanges];
    
    _rowData = [[_CPTableRowData alloc] initWithTableView:self];

    if (!_headerView)
        _headerView = [[CPTableHeaderView alloc] initWithFrame:_CGRectMake(0, 0, [self bounds].size.width, _rowHeight)];

    [_headerView setTableView:self];

    if (!_cornerView)
        _cornerView = [[_CPCornerView alloc] initWithFrame:_CGRectMake(0, 0, [CPScroller scrollerWidth], _CGRectGetHeight(_headerViewFrame))];
    
    [self _makeDropOperationFeedbackView];
    
    _draggedColumnIndex = -1;
    _draggedColumnIsSelected = NO;

    // Gradients for the source list
    _sourceListActiveGradient = CGGradientCreateWithColorComponents(CGColorSpaceCreateDeviceRGB(), [116.0/255.0, 163.0/255.0, 220.0/255.0,1.0, 48.0/255.0, 100.0/255.0, 183.0/255.0,1.0], [0,1], 2);
    _sourceListActiveTopLineColor = [CPColor colorWithCalibratedRed:(95.0/255.0) green:(145.0/255.0) blue:(209.0/255.0) alpha:1.0];
    _sourceListActiveBottomLineColor = [CPColor colorWithCalibratedRed:(206.0/255.0) green:(215.0/255.0) blue:(229.0/255.0) alpha:1.0];

    // Gradients for the source list when CPTableView is NOT first responder or the window is NOT key.
    // FIX ME: we need to actually implement this.
    _sourceListInactiveGradient = CGGradientCreateWithColorComponents(CGColorSpaceCreateDeviceRGB(), [168.0/255.0,183.0/255.0,205.0/255.0,1.0,157.0/255.0,174.0/255.0,199.0/255.0,1.0], [0,1], 2);
    _sourceListInactiveTopLineColor = [CPColor colorWithCalibratedRed:(173.0/255.0) green:(187.0/255.0) blue:(209.0/255.0) alpha:1.0];
    _sourceListInactiveBottomLineColor = [CPColor colorWithCalibratedRed:(150.0/255.0) green:(161.0/255.0) blue:(183.0/255.0) alpha:1.0];

    var count = NUMBER_OF_COLUMNS();
    
    if (count > 0)
    {
        var descriptors = [CPArray array];
    
        for (var i = 0; i < count; ++i)
            [descriptors addObject:[[_tableColumns objectAtIndex:i] sortDescriptorPrototype]];
        
        [self setSortDescriptors:descriptors];
    }        
}

- (void)_makeDropOperationFeedbackView
{
    _dropOperationFeedbackView = [[_CPDropOperationDrawingView alloc] initWithFrame:_CGRectMakeZero()];
    
    [_dropOperationFeedbackView setTableView:self];
    [_dropOperationFeedbackView setHidden:YES];
    [_dropOperationFeedbackView setDropOperation:-1];
    [_dropOperationFeedbackView setCurrentRow:-1];
    
    [self addSubview:_dropOperationFeedbackView];
}

// Setting the Data Source
/*!
    Sets the receiver's data source to a given object.
    @param anObject The data source for the receiver. The object must implement the appropriate methods.
*/
- (void)setDataSource:(id)aDataSource
{
    if (_dataSource === aDataSource)
        return;

    _dataSource = aDataSource;
    _implementedDataSourceMethods = 0;

    if (!_dataSource)
        return;

    var hasContentBinding = !![self infoForBinding:@"content"];

    if ([_dataSource respondsToSelector:@selector(numberOfRowsInTableView:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_numberOfRowsInTableView_;
    else if (!hasContentBinding)
        [CPException raise:CPInternalInconsistencyException
                reason:[aDataSource description] + " does not implement numberOfRowsInTableView:."];

    if ([_dataSource respondsToSelector:@selector(tableView:objectValueForTableColumn:row:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_tableView_objectValueForTableColumn_row_;
    else if (!hasContentBinding)
        [CPException raise:CPInternalInconsistencyException
                reason:[aDataSource description] + " does not implement tableView:objectValueForTableColumn:row:"];

    if ([_dataSource respondsToSelector:@selector(tableView:setObjectValue:forTableColumn:row:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_tableView_setObjectValue_forTableColumn_row_;

    if ([_dataSource respondsToSelector:@selector(tableView:acceptDrop:row:dropOperation:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_tableView_acceptDrop_row_dropOperation_;

    if ([_dataSource respondsToSelector:@selector(tableView:namesOfPromisedFilesDroppedAtDestination:forDraggedRowsWithIndexes:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_tableView_namesOfPromisedFilesDroppedAtDestination_forDraggedRowsWithIndexes_;

    if ([_dataSource respondsToSelector:@selector(tableView:validateDrop:proposedRow:proposedDropOperation:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_tableView_validateDrop_proposedRow_proposedDropOperation_;

    if ([_dataSource respondsToSelector:@selector(tableView:writeRowsWithIndexes:toPasteboard:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_tableView_writeRowsWithIndexes_toPasteboard_;

    if ([_dataSource respondsToSelector:@selector(tableView:sortDescriptorsDidChange:)])
        _implementedDataSourceMethods |= CPTableViewDataSource_tableView_sortDescriptorsDidChange_;

    [self reloadData];
}

/*!
    Returns the object that provides the data displayed by the receiver.
*/
- (id)dataSource
{
    return _dataSource;
}

// Loading Data

/*!
    Reloads the data for all rows and columns.

*/
- (void)reloadData
{
    //console.log('reloadData');
    
    [self _queryNumberOfRows];
    
    [self tile];
}

/*!
    Reloads the data for only the specified rows and columns.
    @param rowIndexes The indexes of the rows to update.
    @param columnIndexes The indexes of the columns to update.
*/
- (void)reloadDataForRowIndexes:(CPIndexSet)rowIndexes columnIndexes:(CPIndexSet)columnIndexes
{
    [_rowData flushRowIndexes:rowIndexes columnIndexes:columnIndexes];
    
    var visibleRect = [self visibleRect],
        visibleRows = [self rowsInRect:visibleRect],
        visibleColumns = [self columnIndexesInRect:visibleRect];
        
    for (var row = [rowIndexes firstIndex]; row != CPNotFound; row = [rowIndexes indexGreaterThanIndex:row])
    {
        if (!CPLocationInRange(row, visibleRows))
            continue;
            
        for (var column = [columnIndexes firstIndex]; column != CPNotFound; column = [columnIndexes indexGreaterThanIndex:column])
        {
            if ([visibleColumns containsIndex:column])
            {
                var frame = [self frameOfDataViewAtColumn:column row:row];
                [self _drawCellAtRow:row column:column withFrame:frame];
            }
        }
    }
}

// Target-action Behavior
/*!
    Sets the message sent to the target when the user double-clicks an
    uneditable cell or a column header to a given selector.
    @param aSelector The message the receiver sends to its target when the user
    double-clicks an uneditable cell or a column header.
*/
- (void)setDoubleAction:(SEL)anAction
{
    _doubleAction = anAction;
}

- (SEL)doubleAction
{
    return _doubleAction;
}

/*
    Returns the index of the the column the user clicked to trigger an action, or -1 if no column was clicked.
*/
- (CPInteger)clickedColumn
{
    return _clickedColumn;
}

/*!
    Returns the index of the the row the user clicked to trigger an action, or -1 if no row was clicked.
*/
- (CPInteger)clickedRow
{
    return _clickedRow;
}

// Configuring Behavior

- (void)setAllowsColumnReordering:(BOOL)flag
{
    _allowsColumnReordering = !!flag;
}

- (BOOL)allowsColumnReordering
{
    return _allowsColumnReordering;
}

- (void)setAllowsColumnResizing:(BOOL)flag
{
    _allowsColumnResizing = !!flag;
}

- (BOOL)allowsColumnResizing
{
    return _allowsColumnResizing;
}

/*!
    Controls whether the user can select more than one row or column at a time.
    @param flag YES to allow the user to select multiple rows or columns, otherwise NO.
*/
- (void)setAllowsMultipleSelection:(BOOL)flag
{
    _allowsMultipleSelection = !!flag;
}

- (BOOL)allowsMultipleSelection
{
    return _allowsMultipleSelection;
}

/*!
    Controls whether the receiver allows zero rows or columns to be selected.
    @param flag YES if an empty selection is allowed, otherwise NO.
*/
- (void)setAllowsEmptySelection:(BOOL)flag
{
    _allowsEmptySelection = !!flag;
}

- (BOOL)allowsEmptySelection
{
    return _allowsEmptySelection;
}

/*!
    Controls whether the user can select an entire column by clicking its header.
    @param flag YES to allow the user to select columns, otherwise NO.
*/

- (void)setAllowsColumnSelection:(BOOL)flag
{
    _allowsColumnSelection = !!flag;
}

- (BOOL)allowsColumnSelection
{
    return _allowsColumnSelection;
}

// Setting Display Attributes

- (void)setIntercellSpacing:(CGSize)aSize
{
    if (_CGSizeEqualToSize(_intercellSpacing, aSize))
        return;

    _intercellSpacing = _CGSizeMakeCopy(aSize);
    
    [self _setNeedsRecalcColumnRangesStartingAtIndex:0];
    [self _recalculateTableColumnRanges];
    
    [self tile];
}

- (CGSize)intercellSpacing
{
    return _CGSizeMakeCopy(_intercellSpacing);
}

- (void)setRowHeight:(float)rowHeight
{
    if (_rowHeight === rowHeight)
        return;

    _rowHeight = MAX(0.0, rowHeight);

    [self tile];
}

- (float)rowHeight
{
    return _rowHeight;
}

/*!
    Sets whether the receiver uses the standard alternating row colors for its background.
    @param aFlag YES to specify standard alternating row colors for the background, NO to specify a solid color.
*/
- (void)setUsesAlternatingRowBackgroundColors:(BOOL)useAlternatingRowBackgroundColors
{
    _usesAlternatingRowBackgroundColors = !!useAlternatingRowBackgroundColors;
}

- (BOOL)usesAlternatingRowBackgroundColors
{
    return _usesAlternatingRowBackgroundColors;
}

/*!
    Sets the colors for the rows as they alternate. The number of colors can be arbitrary. 
    By deafult these colors are white and light blue.
    @param anArray an array of CPColors
*/

- (void)setAlternatingRowBackgroundColors:(CPArray)colors
{
    if ([_alternatingRowBackgroundColors isEqual:colors])
        return;

    _alternatingRowBackgroundColors = colors;

    [self setNeedsDisplay:YES];
}

- (CPArray)alternatingRowBackgroundColors
{
    return _alternatingRowBackgroundColors;
}

- (unsigned)selectionHighlightStyle
{
    return _selectionHighlightStyle;
}

- (void)setSelectionHighlightStyle:(CPTableViewSelectionHighlightStyle)selectionHighlightStyle
{
    if (_selectionHighlightStyle === selectionHighlightStyle)
        return;

    _selectionHighlightStyle = selectionHighlightStyle;

    if (aSelectionHighlightStyle === CPTableViewSelectionHighlightStyleSourceList)
        _destinationDragStyle = CPTableViewDraggingDestinationFeedbackStyleSourceList;
    else
        _destinationDragStyle = CPTableViewDraggingDestinationFeedbackStyleRegular;
        
    [self setNeedsDisplay:YES];
}

/*!
    Sets the highlight color for a row or column selection.
    @param aColor a CPColor
*/
- (void)setSelectionHighlightColor:(CPColor)aColor
{
    if (_selectionHighlightColor === aColor)
        return;

    _selectionHighlightColor = aColor;
    
    [self setNeedsDisplay:YES];
}

/*!
    Returns the highlight color for a row or column selection.
*/
- (CPColor)selectionHighlightColor
{
    return _selectionHighlightColor;
}

/*!
    Sets the highlight gradient for a row or column selection.
    @param aDictionary a CPDictionary expects three keys to be set:
        CPSourceListGradient which is a CGGradient
        CPSourceListTopLineColor which is a CPColor
        CPSourceListBottomLineColor which is a CPColor
*/
- (void)setSelectionGradientColors:(CPDictionary)colors
{
    if ([colors valueForKey:"CPSourceListGradient"] === _sourceListActiveGradient && [colors valueForKey:"CPSourceListTopLineColor"] === _sourceListActiveTopLineColor && [colors valueForKey:"CPSourceListBottomLineColor"] === _sourceListActiveBottomLineColor)
        return;

    _sourceListActiveGradient        = [colors valueForKey:CPSourceListGradient];
    _sourceListActiveTopLineColor    = [colors valueForKey:CPSourceListTopLineColor];
    _sourceListActiveBottomLineColor = [colors valueForKey:CPSourceListBottomLineColor];
    
    [self setNeedsDisplay:YES];
}

/*!
    Returns a dictionary of containing the keys:
    CPSourceListGradient
    CPSourceListTopLineColor
    CPSourceListBottomLineColor
*/
- (CPDictionary)selectionGradientColors
{
    return [CPDictionary dictionaryWithObjects:[_sourceListActiveGradient, _sourceListActiveTopLineColor, _sourceListActiveBottomLineColor] forKeys:[CPSourceListGradient, CPSourceListTopLineColor, CPSourceListBottomLineColor]];
}

/*!
    Sets the grid color in the non highlighted state.
    @param aColor a CPColor
*/
- (void)setGridColor:(CPColor)aColor
{
    if (_gridColor === aColor)
        return;

    _gridColor = aColor;

    [self setNeedsDisplay:YES];
}

- (CPColor)gridColor
{
    return _gridColor;
}

/*!
    Sets the grid style mask to specify if no grid lines, vertical grid lines, or horizontal grid lines should be displayed.
    @param gridType The grid style mask. CPTableViewGridNone, CPTableViewSolidVerticalGridLineMask, CPTableViewSolidHorizontalGridLineMask
*/

- (void)setGridStyleMask:(unsigned)grideStyleMask
{
    if (_gridStyleMask === grideStyleMask)
        return;

    _gridStyleMask = grideStyleMask;

    [self setNeedsDisplay:YES];
}

- (unsigned)gridStyleMask
{
    return _gridStyleMask;
}

- (void)indicatorImageInTableColumn:(CPTableColumn)aTableColumn
{
    return [[aTableColumn headerView] _indicatorImage];
}

- (void)setIndicatorImage:(CPImage)anImage inTableColumn:(CPTableColumn)aTableColumn
{
    if (aTableColumn)
        [[aTableColumn headerView] _setIndicatorImage:anImage];
}

// Column Management

/*!
    Adds a given column as the last column of the receiver.
    @param aColumn The column to add to the receiver.
*/
- (void)addTableColumn:(CPTableColumn)aTableColumn
{
    [_tableColumns addObject:aTableColumn];
    [aTableColumn setTableView:self];
    
    [self _setNeedsRecalcColumnRangesStartingAtIndex:NUMBER_OF_COLUMNS() - 1];

    [self _autoresizeToFit];
}

/*!
    Removes a given column from the receiver.
    @param aTableColumn The column to remove from the receiver.
*/
- (void)removeTableColumn:(CPTableColumn)aTableColumn
{
    if ([aTableColumn tableView] !== self)
        return;

    var index = [_tableColumns indexOfObjectIdenticalTo:aTableColumn];

    if (index === CPNotFound)
        return;

    // We defer the actual removal until the end of the runloop in order to keep a reference to the column.
    //[_deferedColumnDataToRemove addObject:{"column":aTableColumn, "shouldBeHidden": [aTableColumn isHidden]}];
    
    [_rowData flushColumn:index];    
    
    [_tableColumns removeObjectAtIndex:index];
    [aTableColumn setHidden:YES];
    [aTableColumn setTableView:nil];
    
    [self _setNeedsRecalcColumnRangesStartingAtIndex:index];

    [self _autoresizeToFit];
}

- (void)_setDraggedColumn:(CPInteger)columnIndex
{
    if (_draggedColumnIndex === columnIndex)
        return;

    // If ending a column drag, reselect the column if it was selected before the drag
    if (columnIndex === -1 && _draggedColumnIsSelected)
        [_selectedColumnIndexes addIndex:_draggedColumnIndex];
    
    _draggedColumnIndex = columnIndex;

    [self setNeedsDisplayInRect:[self rectOfColumn:columnIndex]];
}

/*!
    Moves the column and heading at a given index to a new given index.
    @param columnIndex The current index of the column to move.
    @param newIndex The new index for the moved column.
*/
- (void)moveColumn:(unsigned)fromIndex toColumn:(unsigned)toIndex
{
    if (fromIndex === toIndex)
        return;
        
    [self _setNeedsRecalcColumnRangesStartingAtIndex:MIN(fromIndex, toIndex)];

    var tableColumn = _tableColumns[fromIndex];

    [_tableColumns removeObjectAtIndex:fromIndex];
    [_tableColumns insertObject:tableColumn atIndex:toIndex];
    
    var columnIsSelected = [_selectedColumnIndexes containsIndex:fromIndex];
    
    [_selectedColumnIndexes shiftIndexesStartingAtIndex:fromIndex + 1 by:-1];
    [_selectedColumnIndexes shiftIndexesStartingAtIndex:toIndex by:1];
        
    if (columnIsSelected)
        [_selectedColumnIndexes addIndex:toIndex];

    // Calculate the minimum visible rectangle that covers the left edge of the table
    // to the right of the from and to columns
    var dirtyRect = [self visibleRect],
        columnRect = [self rectOfColumn:MAX(fromIndex, toIndex)];
        
    dirtyRect.size = _CGSizeMakeZero();
    dirtyRect = CGRectUnion(dirtyRect, columnRect);
    
    [self setNeedsDisplayInRect:dirtyRect];
    [_headerView setNeedsLayout];
    [_headerView setNeedsDisplay:YES];
    
    var info = [CPDictionary dictionaryWithJSObject:{CPOldColumn:fromIndex, CPNewColumn:toIndex}];
    
    [[CPNotificationCenter defaultCenter] postNotificationName:CPTableViewColumnDidMoveNotification
                                                        object:self
                                                      userInfo:info];
}

/*!
    @ignore
*/
- (void)_tableColumnVisibilityDidChange:(CPTableColumn)aColumn
{
    var columnIndex = [[self tableColumns] indexOfObjectIdenticalTo:aColumn];
    
    [self _setNeedsRecalcColumnRangesStartingAtIndex:columnIndex];

    var rowIndexes = [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(0, _numberOfRows)];
    
    [self reloadDataForRowIndexes:rowIndexes columnIndexes:[CPIndexSet indexSetWithIndex:columnIndex]];

    [_headerView setNeedsLayout];
    [_headerView setNeedsDisplay:YES];
}

- (CPArray)tableColumns
{
    return _tableColumns;
}

- (CPInteger)columnWithIdentifier:(CPString)anIdentifier
{
    var count = NUMBER_OF_COLUMNS();

    for (var index = 0; index < count; ++index)
        if ([_tableColumns[index] identifier] === anIdentifier)
            return index;

    return -1;
}

- (CPTableColumn)tableColumnWithIdentifier:(CPString)anIdentifier
{
    var index = [self columnWithIdentifier:anIdentifier];

    return index === -1 ? nil : _tableColumns[index];
}

// Selecting Columns and Rows

/*!
    Sets the column selection using indexes.
    @param columnIndexes a CPIndexSet of columns to select
    @param aFlag should extend the selection thereby retaining the previous selection
*/
- (void)selectColumnIndexes:(CPIndexSet)indexes byExtendingSelection:(BOOL)extend
{
    // If we're out of range, just return
    if (([indexes firstIndex] != CPNotFound && [indexes firstIndex] < 0) || [indexes lastIndex] >= [self numberOfColumns])
        return;

    // We deselect all rows when selecting columns.
    if ([_selectedRowIndexes count] > 0)
        _selectedRowIndexes = [CPIndexSet indexSet];

    var previousSelectedIndexes = [_selectedColumnIndexes copy];

    if (extend)
        [_selectedColumnIndexes addIndexes:indexes];
    else
        _selectedColumnIndexes = [indexes copy];
        
    if (_headerView)
    {
        for (var columnIndex = 0; columnIndex < [_tableColumns count]; ++columnIndex) 
        {
            var headerView = [_tableColumns[columnIndex] headerView];
            
            if ([_selectedColumnIndexes containsIndex:columnIndex])
                [headerView setThemeState:CPThemeStateSelected];
            else
                [headerView unsetThemeState:CPThemeStateSelected];
        }
    }

    [self setNeedsDisplay:YES];
    [_headerView setNeedsDisplay:YES];

    [self _notifySelectionDidChange];
}

- (void)_setSelectedRowIndexes:(CPIndexSet)indexes
{
    var previousSelectedIndexes = [_selectedRowIndexes copy];

    _lastSelectedRow = ([indexes count] > 0) ? [indexes lastIndex] : -1;
    _selectedRowIndexes = [indexes copy];

    [self setNeedsDisplay:YES];

    [[CPKeyValueBinding getBinding:@"selectionIndexes" forObject:self] reverseSetValueFor:@"selectedRowIndexes"];

    [self _notifySelectionDidChange];
}

/*!
    Sets the row selection using indexes.
    @param rowIndexes a CPIndexSet of rows to select
    @param aFlag should extend the selection thereby retaining the previous selection
*/
- (void)selectRowIndexes:(CPIndexSet)indexes byExtendingSelection:(BOOL)extend
{
    if ([indexes isEqualToIndexSet:_selectedRowIndexes] ||
        (([indexes firstIndex] != CPNotFound && [indexes firstIndex] < 0) || [indexes lastIndex] >= _numberOfRows))
    {
        return;
    }

    // We deselect all columns when selecting rows.
    if ([_selectedColumnIndexes count] > 0)
        [self selectColumnIndexes:[CPIndexSet indexSet] byExtendingSelection:NO];

    var newSelectedIndexes;
    
    if (extend)
    {
        newSelectedIndexes = [_selectedRowIndexes copy];
        [newSelectedIndexes addIndexes:indexes];
    }
    else
        newSelectedIndexes = [indexes copy];

    [self _setSelectedRowIndexes:newSelectedIndexes];
}

- (CPInteger)selectedColumn
{
    [_selectedColumnIndexes lastIndex];
}

- (CPIndexSet)selectedColumnIndexes
{
    return _selectedColumnIndexes;
}

- (CPInteger)selectedRow
{
    return _lastSelectedRow;
}

- (CPIndexSet)selectedRowIndexes
{
    return [_selectedRowIndexes copy];
}

- (void)deselectColumn:(CPInteger)columnIndex
{
    var selectedColumnIndexes = [_selectedColumnIndexes copy];
    [selectedColumnIndexes removeIndex:columnIndex];
    [self selectColumnIndexes:selectedColumnIndexes byExtendingSelection:NO];
    [self _notifySelectionDidChange];
}

- (void)deselectRow:(CPInteger)rowIndex
{
    var selectedRowIndexes = [_selectedRowIndexes copy];
    [selectedRowIndexes removeIndex:rowIndex];
    [self selectRowIndexes:selectedRowIndexes byExtendingSelection:NO];
    [self _notifySelectionDidChange];
}

- (CPInteger)numberOfSelectedColumns
{
    return [_selectedColumnIndexes count];
}

- (CPInteger)numberOfSelectedRows
{
    return [_selectedRowIndexes count];
}

- (BOOL)isColumnSelected:(CPInteger)columnIndex
{
    return [_selectedColumnIndexes containsIndex:columnIndex];
}

- (BOOL)isRowSelected:(CPInteger)rowIndex
{
    return [_selectedRowIndexes containsIndex:rowIndex];
}

/*
    * - allowsTypeSelect
    * - setAllowsTypeSelect:
*/

/*!
    Selects all rows
*/
- (void)selectAll:(id)sender
{
    if (!_allowsMultipleSelection)
        return;
    
    if ((_implementedDelegateMethods & CPTableViewDelegate_selectionShouldChangeInTableView_) &&
        ![_delegate selectionShouldChangeInTableView:self])
    {
        return;
    }
    
    // Cocoa docs say that if columns were most recently selected, select all columns.
    // Otherwise select all rows.
    var rowIndexes, columnIndexes;
    
    if ([_selectedColumnIndexes count])
    {
        rowIndexes = [CPIndexSet indexSet];
        columnIndexes = [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(0, NUMBER_OF_COLUMNS())];
    }
    else
    {
        rowIndexes = [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(0, _numberOfRows)];
        columnIndexes = [CPIndexSet indexSet];
    }
        
    [self selectRowIndexes:rowIndexes byExtendingSelection:NO];
    [self selectColumnIndexes:columnIndexes byExtendingSelection:NO];
}

/*!
    Deselects all rows
*/
- (void)deselectAll:(id)sender
{
    if ((_implementedDelegateMethods & CPTableViewDelegate_selectionShouldChangeInTableView_) &&
        ![_delegate selectionShouldChangeInTableView:self])
    {
        return;
    }
        
    [self selectRowIndexes:[CPIndexSet indexSet] byExtendingSelection:NO];
    [self selectColumnIndexes:[CPIndexSet indexSet] byExtendingSelection:NO];
}

- (void)_notifySelectionIsChanging
{
    [[CPNotificationCenter defaultCenter]
        postNotificationName:CPTableViewSelectionIsChangingNotification
                      object:self
                    userInfo:nil];
}

- (void)_notifySelectionDidChange
{
    [[CPNotificationCenter defaultCenter]
        postNotificationName:CPTableViewSelectionDidChangeNotification
                      object:self
                    userInfo:nil];
}

// Table Dimensions

- (CPInteger)numberOfColumns
{
    return NUMBER_OF_COLUMNS();
}

/*
    Returns the number of rows in the receiver.
*/
- (CPInteger)numberOfRows
{
    return _numberOfRows;
}

- (void)_queryNumberOfRows
{
    var contentBindingInfo = [self infoForBinding:@"content"];

    if (contentBindingInfo)
    {
        var destination = [contentBindingInfo objectForKey:CPObservedObjectKey],
            keyPath = [contentBindingInfo objectForKey:CPObservedKeyPathKey];

        _numberOfRows = [[destination valueForKeyPath:keyPath] count];
    }
    else if (_dataSource)
    {
        _numberOfRows = [_dataSource numberOfRowsInTableView:self];
    }
    else
    {
        _numberOfRows = 0;
    }
}

// Displaying Cell

- (CPView)preparedDataViewAtColumn:(CPInteger)columnIndex row:(CPInteger)rowIndex
{
    var tableColumn = _tableColumns[columnIndex];
    
    if ((_implementedDelegateMethods & CPTableViewDelegate_tableView_dataViewForTableColumn_row_))
    {
        var delegateDataView = [_delegate tableView:self dataViewForTableColumn:tableColumn row:rowIndex];
        [tableColumn setDataView:delegateDataView];
    }
    
    var dataView = [tableColumn _newDataViewForRow:rowIndex];
    
    // tableView:objectValueForTableColumn:row: is optional if content bindings are in place.
    if (_implementedDataSourceMethods & CPTableViewDataSource_tableView_objectValueForTableColumn_row_)
    {
        var objectValue = [_dataSource tableView:self objectValueForTableColumn:tableColumn row:rowIndex];
        [dataView setObjectValue:objectValue];
    }

    // If the column uses content bindings, allow them to override the objectValueForTableColumn.
    [tableColumn prepareDataView:dataView forRow:rowIndex];
        
    if ([_selectedColumnIndexes containsIndex:columnIndex] || [self isRowSelected:rowIndex])
        [dataView setThemeState:CPThemeStateSelectedDataView];
    else
        [dataView unsetThemeState:CPThemeStateSelectedDataView];

    var isButton = [dataView isKindOfClass:[CPButton class]],
        isTextField = [dataView isKindOfClass:[CPTextField class]];

    if (isButton || (_editingCellIndex && _editingCellIndex.x === columnIndex && _editingCellIndex.y === rowIndex))
    {
        if (!isButton)
            _editingCellIndex = undefined;

        if (isTextField)
        {
            [dataView setEditable:YES];
            [dataView setSendsActionOnEndEditing:YES];
            [dataView setSelectable:YES];
            [dataView selectText:nil]; // Doesn't seem to actually work (yet?).
        }

        [dataView setTarget:self];
        [dataView setAction:@selector(_commitDataViewObjectValue:)];
        dataView.tableViewEditedColumnObj = tableColumn;
        dataView.tableViewEditedRowIndex = rowIndex;
    }
    else if (isTextField)
    {
        [dataView setEditable:NO];
        [dataView setSelectable:NO];
    }

    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_willDisplayView_forTableColumn_row_)
        [_delegate tableView:self willDisplayView:dataView forTableColumn:tableColumn row:rowIndex];

    return dataView;
}

- (id)_objectValueForTableColumn:(CPTableColumn)aTableColumn row:(CPInteger)rowIndex
{
    // tableView:objectValueForTableColumn:row: is optional if content bindings are in place.
    if (_implementedDataSourceMethods & CPTableViewDataSource_tableView_objectValueForTableColumn_row_)
        return [_dataSource tableView:self objectValueForTableColumn:aTableColumn row:rowIndex];
    
    return @"";
}

// Editing Cells

/*!
    Edits the indicated cell.
*/
- (void)editColumn:(CPInteger)columnIndex row:(CPInteger)rowIndex withEvent:(CPEvent)theEvent select:(BOOL)flag
{
    if (![self isRowSelected:rowIndex])
        [[CPException exceptionWithName:@"Error" reason:@"Attempt to edit row="+rowIndex+" when not selected." userInfo:nil] raise];

    // TODO Do something with flag.

    _editingCellIndex = CGPointMake(columnIndex, rowIndex);
    
    [self reloadDataForRowIndexes:[CPIndexSet indexSetWithIndex:rowIndex]
                    columnIndexes:[CPIndexSet indexSetWithIndex:columnIndex]];
}

/*!
    Returns the column of the currently edited cell, or -1 if none.
*/
- (CPInteger)editedColumn
{
    if (!_editingCellIndex)
        return -1;
    
    return _editingCellIndex.x;
}

/*!
    Returns the row of the currently edited cell, or -1 if none.
*/
- (CPInteger)editedRow
{
    if (!_editingCellIndex)
        return -1;
    
    return _editingCellIndex.x;
}

// Setting Auxiliary Views

- (CPView)cornerView
{
    return _cornerView;
}

- (void)setCornerView:(CPView)aView
{
    if (_cornerView === aView)
        return;

    _cornerView = aView;

    var scrollView = [[self superview] superview];

    if ([scrollView isKindOfClass:[CPScrollView class]] && [scrollView documentView] === self)
        [scrollView _updateCornerAndHeaderView];
}

- (CPView)headerView
{
    return _headerView;
}

- (void)setHeaderView:(CPView)aHeaderView
{
    if (_headerView === aHeaderView)
        return;

    [_headerView setTableView:nil];

    _headerView = aHeaderView;

    if (_headerView)
    {
        [_headerView setTableView:self];
        [_headerView setFrameSize:_CGSizeMake(_CGRectGetWidth([self frame]), _CGRectGetHeight([_headerView frame]))];
    }

    var scrollView = [[self superview] superview];

    if ([scrollView isKindOfClass:[CPScrollView class]] && [scrollView documentView] === self)
        [scrollView _updateCornerAndHeaderView];
}

// Layout Support

// Complexity:
// O(1)
- (CGRect)rectOfColumn:(CPInteger)columnIndex
{
    if (columnIndex < 0 || columnIndex >= NUMBER_OF_COLUMNS())
        return _CGRectMakeZero();
        
    var column = _tableColumns[columnIndex];
    
    if ([column isHidden])
        return _CGRectMakeZero();

    UPDATE_COLUMN_RANGES_IF_NECESSARY();

    var range = _tableColumnRanges[columnIndex];

    return _CGRectMake(range.location, 0.0, range.length, _CGRectGetHeight([self bounds]));
}

- (CGRect)rectOfRow:(CPInteger)rowIndex
{
    var height = _rowHeight + _intercellSpacing.height;
    
    return _CGRectMake(0.0, rowIndex * height, _CGRectGetWidth([self bounds]), height);
}

// Complexity:
// O(1)
/*!
    Returns a range of indices for the rows that lie wholly or partially within the vertical boundaries of a given rectangle.
    @param aRect A rectangle in the coordinate system of the receiver.
*/

- (CPRange)rowsInRect:(CGRect)aRect
{
    // If we have no rows, then we won't intersect anything.
    if (_numberOfRows <= 0)
        return CPMakeRange(0, 0);

    // No rows if the rect doesn't even intersect us.
    if (!CGRectIntersectsRect(aRect, [self bounds]))
        return CPMakeRange(0, 0);

    var firstRow = [self rowAtPoint:aRect.origin];

    // Pin the intersection to the first row
    if (firstRow < 0)
        firstRow = 0;

    var lastRow = [self rowAtPoint:_CGPointMake(0.0, _CGRectGetMaxY(aRect))];

    // Pin the intersection to the last row
    if (lastRow < 0)
        lastRow = _numberOfRows - 1;

    return CPMakeRange(firstRow, lastRow - firstRow + 1);
}

// Complexity:
// O(lg Columns) if table view contains no hidden columns
// O(Columns) if table view contains hidden columns

/*!
    Returns the indexes of the receiver's columns that intersect the specified rectangle.
    @param aRect A rectangle in the coordinate system of the receiver.
*/
- (CPIndexSet)columnIndexesInRect:(CGRect)aRect
{        
    // No columns if the rect doesn't even intersect us.
    if (!CGRectIntersectsRect(aRect, [self bounds]))
        return CPMakeRange(0, 0);
        
    var firstColumn = MAX(0, [self columnAtPoint:_CGPointMake(aRect.origin.x, 0.0)]),
        lastColumn = [self columnAtPoint:_CGPointMake(_CGRectGetMaxX(aRect), 0.0)];

    // Pin the intersection to the last column
    if (lastColumn < 0)
        lastColumn = NUMBER_OF_COLUMNS() - 1;

    // Don't bother doing the expensive removal of hidden indexes if we have no hidden columns.
    if (_numberOfHiddenColumns <= 0)
        return [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(firstColumn, lastColumn - firstColumn + 1)];

    var indexes = [CPIndexSet indexSet];

    for (var column = firstColumn; column <= lastColumn; ++column)
    {
        var tableColumn = _tableColumns[column];

        if (![tableColumn isHidden])
            [indexes addIndex:column];
    }

    return indexes;
}

// Complexity:
// O(lg Columns) if table view contains no hidden columns
// O(Columns) if table view contains hidden columns
- (CPInteger)columnAtPoint:(CGPoint)aPoint
{
    if (!_CGRectContainsPoint([self bounds], aPoint))
        return -1;

    UPDATE_COLUMN_RANGES_IF_NECESSARY();

    var x = aPoint.x,
        low = 0,
        high = _tableColumnRanges.length - 1;

    while (low <= high)
    {
        var middle = FLOOR(low + (high - low) / 2),
            range = _tableColumnRanges[middle];

        if (x < range.location)
        {
            high = middle - 1;
        }
        else if (x >= CPMaxRange(range))
        {
            low = middle + 1;
        }
        else
        {
            var numberOfColumns = _tableColumnRanges.length;

            while (middle < numberOfColumns && [_tableColumns[middle] isHidden])
                ++middle;

            if (middle < numberOfColumns)
                return middle;

            return -1;
        }
   }

   return -1;
}

- (CPInteger)rowAtPoint:(CGPoint)aPoint
{
    var row = FLOOR(aPoint.y / (_rowHeight + _intercellSpacing.height));

    return row < _numberOfRows ? row : -1;
}

- (CGRect)frameOfDataViewAtColumn:(CPInteger)columnIndex row:(CPInteger)rowIndex
{
    UPDATE_COLUMN_RANGES_IF_NECESSARY();

    var tableColumnRange = _tableColumnRanges[columnIndex],
        rectOfRow = [self rectOfRow:rowIndex],
        leftInset = FLOOR(_intercellSpacing.width / 2.0),
        topInset = FLOOR(_intercellSpacing.height / 2.0);
    
    return _CGRectMake(tableColumnRange.location + leftInset, 
                       _CGRectGetMinY(rectOfRow) + topInset, 
                       tableColumnRange.length - _intercellSpacing.width, 
                       _CGRectGetHeight(rectOfRow) - _intercellSpacing.height);
}

- (void)_setNeedsRecalcColumnRangesStartingAtIndex:(CPInteger)index
{
    if (_recalcColumnRangeStartingIndex < 0)
        _recalcColumnRangeStartingIndex = index;
    else
        _recalcColumnRangeStartingIndex = MIN(_recalcColumnRangeStartingIndex, index);
}

// Complexity:
// O(Columns)
- (void)_recalculateTableColumnRanges
{
    if (_recalcColumnRangeStartingIndex < 0)
        return;

    _numberOfHiddenColumns = 0;

    var index = _recalcColumnRangeStartingIndex,
        count = NUMBER_OF_COLUMNS(),
        columnMinX = (index === 0 || count === 0) ? 0.0 : CPMaxRange(_tableColumnRanges[index - 1]);

    for (; index < count; ++index)
    {
        var tableColumn = _tableColumns[index];

        if ([tableColumn isHidden])
        {
            ++_numberOfHiddenColumns;
            _tableColumnRanges[index] = CPMakeRange(columnMinX, 0.0);
        }
        else
        {
            var width = [tableColumn width] + _intercellSpacing.width;
            
            _tableColumnRanges[index] = CPMakeRange(columnMinX, width);
            columnMinX += width;
        }
    }
    
    _tableColumnRanges.length = count;
    _recalcColumnRangeStartingIndex = -1;
}

- (CGSize)_minimumFrameSize
{
    return _CGSizeMake([self _totalWidthOfTableView], [self _totalHeightOfTableView]);
}

- (void)_autoresizeToFit
{
    if (!_disableAutomaticResizing)
    {
        
    if (false)
    {
        var mask = _columnAutoResizingStyle;
    
        switch (mask)
        {
            case CPTableViewUniformColumnAutoresizingStyle:
                [self _autoresizeAllColumnsUniformlyWithOldSize];
                break;
            
            case CPTableViewSequentialColumnAutoresizingStyle:
                [self _autoresizeColumnsSequentiallyWithOldSize];
                break;
            
            case CPTableViewReverseSequentialColumnAutoresizingStyle:
                [self _autoresizeColumnsReverseSequentiallyWithOldSize];
                break;        
            
            case CPTableViewLastColumnOnlyAutoresizingStyle:
                [self _autoresizeColumn:CPTableViewResizeLastColumn];
                break;
            
            case CPTableViewFirstColumnOnlyAutoresizingStyle:
                [self _autoresizeColumn:CPTableViewResizeFirstColumn];
                break;
        }
    }
    }
    
    [self tile];
}

- (CPInteger)_indexOfLastVisibleColumn
{
    for (var index = NUMBER_OF_COLUMNS() - 1; index >= 0; --index)
    {
        if (![_tableColumns[index] isHidden])
            return index;
    }
        
    return -1;
}

- (BOOL)_shouldAutoresize:(CGSize)oldSize
{
    /*
        Autoresizing only occurs if:
        
        - The width is increasing and for the last visible column:
            - Its old right edge was on or to the right of the clip view's old right edge
            - Its current right edge is to the left of the clip view's current right edge
          OR
        - The width is decreasing and for the last visible column:
            - Its old right edge was on or to the left of the clip view's old right edge
            - Its current right edge is to the right of the clip view's current right edge
    */
        
    var clipBounds = [[self superview] bounds],
        delta = _CGRectGetWidth(clipBounds) - oldSize.width;
        
    if (delta === 0)
        return YES;
        
    var lastColumnIndex = [self _indexOfLastVisibleColumn];
    
    if (lastColumnIndex < 0)
        return NO;
        
    UPDATE_COLUMN_RANGES_IF_NECESSARY();
    
    var clipRightEdge = _CGRectGetMaxX(clipBounds),
        columnRightEdge = _CGRectGetMaxX([self rectOfColumn:lastColumnIndex]);
    
    if (delta > 0)
    {
        return ((columnRightEdge >= clipRightEdge - delta)   &&
                (columnRightEdge < clipRightEdge));
    }
    else // delta < 0
    {
        return ((columnRightEdge <= clipRightEdge - delta)   &&
                (columnRightEdge > clipRightEdge));
    }
}

- (CPInteger)_indexOfResizableColumnInDirection:(CPInteger)direction
{
    var first, last, increment;
    
    if (direction > 0)
    {
        first = 0;
        last = NUMBER_OF_COLUMNS();
        increment = 1;
    }
    else
    {
        first = NUMBER_OF_COLUMNS() - 1;
        last = -1;
        increment = -1;
    }
    
    for (var index = first; index != last; index += increment)
    {
        var column = _tableColumns[index];
        
        if (![column isHidden] && ([column resizingMask] & CPTableColumnAutoresizingMask))
            return index;
    }
    
    return -1;
}

- (CPInteger)_indexOfFirstResizableColumn
{
    return [self _indexOfResizableColumnInDirection:1];
}

- (CPInteger)_indexOfLastResizableColumn
{
    return [self _indexOfResizableColumnInDirection:-1];
}

- (CPInteger)_indexOfResizableColumnWithProposedDelta:(float)proposedDelta inDirection:(CPInteger)direction
{
    var first, last, increment;
    
    if (direction > 0)
    {
        first = 0;
        last = NUMBER_OF_COLUMNS();
        increment = 1;
    }
    else
    {
        first = NUMBER_OF_COLUMNS() - 1;
        last = -1;
        increment = -1;
    }
    
    for (var index = first; index != last; index += increment)
    {
        var column = _tableColumns[index];
        
        if (![column isHidden] && ([column resizingMask] & CPTableColumnAutoresizingMask))
        {
            if (proposedDelta > 0)
            {
                if ([column width] < [column maxWidth])
                    return index;
            }
            else
            {
                if ([column width] > [column minWidth])
                    return index;
            }
        }
    }
    
    return -1;
}

- (CPInteger)_indexOfFirstResizableColumnWithProposedDelta:(float)proposedDelta
{
    return [self _indexOfResizableColumnWithProposedDelta:proposedDelta inDirection:1];
}

- (CPInteger)_indexOfLastResizableColumnWithProposedDelta:(float)proposedDelta
{
    return [self _indexOfResizableColumnWithProposedDelta:proposedDelta inDirection:-1];
}

- (float)_totalWidthOfTableView
{
    return [_tableColumnRanges count] ? CPMaxRange([_tableColumnRanges lastObject]) : 0.0;
}

- (float)_totalHeightOfTableView
{
    return _numberOfRows * (_rowHeight + _intercellSpacing.height);
}

- (float)_constrainedWidthForTableColumn:(CPTableColumn)aColumn delta:(float)delta
{
    var width = [aColumn width] + delta;
    width = MAX(width, [aColumn minWidth]);
    width = MIN(width, [aColumn maxWidth]);
    
    return FLOOR(width);
}

- (float)_visibleColumnDeltaToSuperview
{
    var superviewWidth = _CGRectGetWidth([[self superview] bounds]),
        totalWidth = [self _totalWidthOfTableColumns];
    
    return superviewWidth - totalWidth;
}

- (void)_autoresizeAllColumnsUniformlyWithOldSize:(CGSize)oldSize
{
    if (![self _shouldAutoresize:oldSize])
        return;

    /*
        After careful analysis, the algorithm Cocoa uses is:
        
        1. Calculate the width delta between the current total visible column width and the new superview width.
           Note that we *cannot* rely on the delta from oldSize.width, because that delta does not guarantee
           that the columns will fit the new width.
        
        2. Get all of the columns that are autoresizable and whose width > minWidth if delta < 0 or whose
           width < maxWidth if delta > 0.
                   
        3. Iterate over the columns to resize, left to right if delta > 0, right to left if delta < 0.
        
        4. Divide the remaining delta by the number of columns left to resize and ceiling towards +/- infinity.
        
        5. Resize the current column, constraining to minWidth/maxWidth. Subtract the actual change in width
           from the delta.
           
        6. Go to step 4 and repeat with the next column in the iteration.
    */
    
    var delta = [self _visibleColumnDeltaToSuperview],
        count = NUMBER_OF_COLUMNS(),
        columnsToResize = [CPArray array],
        i;
        
    for (i = 0; i < count; ++i)
    {
        var tableColumn = _tableColumns[i];
    
        if (![tableColumn isHidden] && ([tableColumn resizingMask] & CPTableColumnAutoresizingMask))
        {
            if ((delta > 0 && [tableColumn width] < [tableColumn maxWidth]) ||
                (delta < 0 && [tableColumn width] > [tableColumn minWidth]))
            {
                [columnsToResize addObject:tableColumn];
            }
        }
    }
    
    count = [columnsToResize count];
    
    if (count === 0)
        return;
        
    var first = delta > 0 ? 0 : count - 1,
        last = delta > 0 ? count : -1,
        increment = delta > 0 ? 1 : -1;
        
    for (i = first; i !== last; i += increment, --count)
    {
        var tableColumn = columnsToResize[i],
            columnDelta = delta / count,
            columnDelta = delta > 0 ? Math.ceil(columnDelta) : Math.floor(columnDelta);
            
        if (columnDelta == 0)
            break;
            
        var newWidth = [self _constrainedWidthForTableColumn:tableColumn delta:columnDelta];
            
        delta -= newWidth - [tableColumn width];
        
        [tableColumn setWidth:newWidth];
    }
    
    [self setNeedsLayout];
}

- (void)_autoresizeColumnsSequentiallyWithOldSize:(CGSize)oldSize
{
    var delta = _CGRectGetWidth([[self superview] bounds]) - oldSize.width;
    
    if (delta > 0)
        [self _autoresizeColumn:CPTableViewResizeFirstAvailableColumn oldSize:oldSize];
    else
        [self _autoresizeColumn:CPTableViewResizeLastAvailableColumn oldSize:oldSize];
}

- (void)_autoresizeColumnsReverseSequentiallyWithOldSize:(CGSize)oldSize
{
    var delta = _CGRectGetWidth([[self superview] bounds]) - oldSize.width;
    
    if (delta < 0)
        [self _autoresizeColumn:CPTableViewResizeFirstAvailableColumn oldSize:oldSize];
    else
        [self _autoresizeColumn:CPTableViewResizeLastAvailableColumn oldSize:oldSize];
}

- (void)_autoresizeColumn:(CPTableViewResizeType)whichColumn oldSize:(CGSize)oldSize
{
    if (oldSize && ![self _shouldAutoresize:oldSize])
        return;
        
    var indexOfColumnToResize,
        delta = [self _visibleColumnDeltaToSuperview];
    
    switch (whichColumn)
    {
        case CPTableViewResizeFirstColumn:
            indexOfColumnToResize = [self _indexOfFirstResizableColumn];
            break;
            
        case CPTableViewResizeLastColumn:
            indexOfColumnToResize = [self _indexOfLastResizableColumn];
            break;
            
        case CPTableViewResizeLastVisibleColumn:
            indexOfColumnToResize = [self _indexOfLastVisibleColumn];
            break;
            
        case CPTableViewResizeFirstAvailableColumn:
            indexOfColumnToResize = [self _indexOfFirstResizableColumnWithProposedDelta:delta];
            break;
            
        case CPTableViewResizeLastAvailableColumn:
            indexOfColumnToResize = [self _indexOfLastResizableColumnWithProposedDelta:delta];
            break;
    }
        
    if (indexOfColumnToResize === -1)
        return;
    
    var column = _tableColumns[indexOfColumnToResize],
        newWidth = [self _constrainedWidthForTableColumn:column delta:delta];
        
    [column setWidth:newWidth];

    [self setNeedsLayout];
}

/*!
    Sets the column autoresizing style of the receiver to a given style.
    @param aStyle The column autoresizing style for the receiver.
    CPTableViewNoColumnAutoresizing, CPTableViewUniformColumnAutoresizingStyle,
    CPTableViewLastColumnOnlyAutoresizingStyle, CPTableViewFirstColumnOnlyAutoresizingStyle
*/
- (void)setColumnAutoresizingStyle:(CPTableViewColumnAutoresizingStyle)style
{
    _columnAutoResizingStyle = style;
}

- (CPTableViewColumnAutoresizingStyle)columnAutoresizingStyle
{
    return _columnAutoResizingStyle;
}

/*!
   Resizes the last column if there's room so the receiver fits exactly within its enclosing clip view.
*/
- (void)sizeLastColumnToFit
{
    [self _autoresizeColumn:CPTableViewResizeLastVisibleColumn oldSize:nil];
}

- (void)noteNumberOfRowsChanged
{
    var oldNumberOfRows = _numberOfRows;

    [self _queryNumberOfRows];

    // Remove row indexes from the selection if they no longer exist
    var orphanedSelections = oldNumberOfRows - _numberOfRows;

    if (orphanedSelections > 0)
    {
        [_selectedRowIndexes removeIndexesInRange:CPMakeRange(_numberOfRows, orphanedSelections)];
        [self _notifySelectionDidChange];
    }
    
    var size = [self frameSize];
    
    if ([_tableColumns count] > 0)
        size.height = _CGRectGetHeight([self rectOfColumn:0]);
        
    [self setFrameSize:size];
}

- (void)tile
{
    //console.log('table tile');
    
    UPDATE_COLUMN_RANGES_IF_NECESSARY();

    // Expand our frame to fit a containing clip view
    var width = [self _totalWidthOfTableView],
        height = [self _totalHeightOfTableView],
        superview = [self superview];
    
    if ([superview isKindOfClass:[CPClipView class]])
    {
        var superviewSize = [superview bounds].size;

        width = MAX(superviewSize.width, width);
        height = MAX(superviewSize.height, height);
    }
    
    var newSize = _CGSizeMake(width, height);

    [self setFrameSize:newSize];
    
    // Cocoa docs say this should happen
    [[self enclosingScrollView] setVerticalLineScroll:_rowHeight + _intercellSpacing.height];
    
    [self setNeedsDisplay:YES];
    [_headerView setNeedsDisplay:YES];
}

/*
    * - sizeToFit
    * - noteHeightOfRowsWithIndexesChanged:
*/

// Drawing

- (void)drawRect:(CGRect)dirtyRect
{
    var context = [[CPGraphicsContext currentContext] graphicsPort];
    
    // Intersect the dirty rect with the visible rect
    var visibleRect = [self visibleRect];
    //console.log('visibleRect: %f, %f, %f, %f', visibleRect.origin.x, visibleRect.origin.y, visibleRect.size.width, visibleRect.size.height);
    
    dirtyRect = CGRectIntersection(dirtyRect, visibleRect);
    //console.log('dirtyRect: %f, %f, %f, %f', dirtyRect.origin.x, dirtyRect.origin.y, dirtyRect.size.width, dirtyRect.size.height);
    
    //[_rowData flushDirtyRect:dirtyRect];
    
    [self drawBackgroundInClipRect:dirtyRect];
    [self highlightSelectionInClipRect:dirtyRect];
    
    var dirtyRows = [self rowsInRect:dirtyRect],
        lastRow = CPMaxRange(dirtyRows) - 1,
        visibleColumnIndexes = [self columnIndexesInRect:dirtyRect];
    
    for (var row = dirtyRows.location; row <= lastRow; ++row)
        [self _drawRow:row columnIndexes:visibleColumnIndexes];
        
    // -drawRow calls -_drawCellAtRow, which calls -display, which calls -unlockFocus, 
    // which clobbers the graphics context, so we are required to call -lockFocus.
    if (lastRow >= 0)
        [self lockFocus];
    
    if ((_gridStyleMask & CPTableViewSolidHorizontalGridLineMask) ||
        (_gridStyleMask & CPTableViewSolidVerticalGridLineMask))
        [self drawGridInClipRect:dirtyRect];
}

- (void)drawRow:(CPInteger)rowIndex clipRect:(CGRect)clipRect
{
    //console.log('drawRow:%d', rowIndex);
    var visibleColumnIndexes = [self columnIndexesInRect:clipRect];
    
    [self _drawRow:rowIndex columnIndexes:visibleColumnIndexes];
}

- (void)_drawRow:(CPInteger)rowIndex columnIndexes:(CPIndexSet)columnIndexes
{
    var indexes = [];
    
    [columnIndexes getIndexes:indexes maxCount:-1 inIndexRange:nil];
    
    for (var i = 0, count = [indexes count]; i < count; ++i) 
    {
        var columnIndex = indexes[i],
            tableColumn = _tableColumns[columnIndex];

        if ([tableColumn isHidden] || columnIndex === _draggedColumnIndex)
            continue;
        
        var frame = [self frameOfDataViewAtColumn:columnIndex row:rowIndex];
        
        [self _drawCellAtRow:rowIndex column:columnIndex withFrame:frame];
    }
}

/*
    NOTE: This method assumes the row/column indexes are valid and visible.
*/
- (void)_drawCellAtRow:rowIndex column:columnIndex withFrame:(CGRect)aFrame
{
    //console.log('_drawCellAtRow:%d column:%d withFrame:%f, %f, %f, %f', rowIndex, columnIndex,
    //            aFrame.origin.x, aFrame.origin.y, aFrame.size.width, aFrame.size.height);
                
    var dataView = [_rowData dataViewForRow:rowIndex column:columnIndex];
    
    if (!dataView)
    {
        dataView = [self preparedDataViewAtColumn:columnIndex row:rowIndex];
        [_rowData setDataView:dataView forRow:rowIndex column:columnIndex];
        [self addSubview:dataView];
    }
    
    [dataView setFrame:aFrame];
    console.log('subview count: %d', [_subviews count]);
    
    [dataView display];
}

- (void)drawBackgroundInClipRect:(CGRect)clipRect
{
    var context = [[CPGraphicsContext currentContext] graphicsPort];
    
    if (!_usesAlternatingRowBackgroundColors)
    {
        CGContextSetFillColor(context, [self backgroundColor]);
        CGContextFillRect(context, clipRect);
        
        return;
    }

    var rowColors = [self alternatingRowBackgroundColors],
        colorCount = [rowColors count];

    if (colorCount === 0)
        return;

    if (colorCount === 1)
    {
        CGContextSetFillColor(context, rowColors[0]);
        CGContextFillRect(context, clipRect);

        return;
    }
    
    // console.profile("row-paint");
    
    var visibleRows = [self rowsInRect:clipRect],
        firstRow = visibleRows.location,
        lastRow = CPMaxRange(visibleRows) - 1,
        colorIndex = MIN(visibleRows.length, colorCount),
        heightFilled = 0.0;

    while (colorIndex--)
    {
        var row = firstRow - firstRow % colorCount + colorIndex,
            fillRect = nil;

        CGContextBeginPath(context);

        for (; row <= lastRow; row += colorCount)
            if (row >= firstRow)
                CGContextAddRect(context, CGRectIntersection(clipRect, fillRect = [self rectOfRow:row]));

        if (row - colorCount === lastRow)
            heightFilled = _CGRectGetMaxY(fillRect);

        CGContextClosePath(context);

        CGContextSetFillColor(context, rowColors[colorIndex]);
        CGContextFillPath(context);
    }
    
    // console.profileEnd("row-paint");

    var totalHeight = _CGRectGetMaxY(clipRect);

    if (heightFilled >= totalHeight || _rowHeight <= 0.0)
        return;

    var rowHeight = _rowHeight + _intercellSpacing.height,
        fillRect = _CGRectMake(_CGRectGetMinX(clipRect), _CGRectGetMinY(clipRect) + heightFilled, _CGRectGetWidth(clipRect), rowHeight);

    for (row = lastRow + 1; heightFilled < totalHeight; ++row)
    {
        CGContextSetFillColor(context, rowColors[row % colorCount]);
        CGContextFillRect(context, fillRect);

        heightFilled += rowHeight;
        fillRect.origin.y += rowHeight;
    }
}

- (void)drawGridInClipRect:(CGRect)clipRect
{
    [self _drawHorizontalGridInClipRect:clipRect];
    [self _drawVerticalGridInClipRect:clipRect];
}

- (void)_drawHorizontalGridInClipRect:(CGRect)clipRect
{
    if (!(_gridStyleMask & CPTableViewSolidHorizontalGridLineMask))
        return;
        
    var context = [[CPGraphicsContext currentContext] graphicsPort],
        visibleRows = [self rowsInRect:clipRect],
        row = visibleRows.location,
        lastRow = CPMaxRange(visibleRows) - 1,
        rowY = -0.5,
        minX = _CGRectGetMinX(clipRect),
        maxX = _CGRectGetMaxX(clipRect);

    CGContextBeginPath(context);
    
    for (; row <= lastRow; ++row)
    {
        var rowRect = [self rectOfRow:row];
        
        rowY = _CGRectGetMaxY(rowRect) - 0.5;
        CGContextMoveToPoint(context, minX, rowY);
        CGContextAddLineToPoint(context, maxX, rowY);
    }

    if (_rowHeight > 0.0)
    {
        var rowHeight = _rowHeight + _intercellSpacing.height,
            totalHeight = _CGRectGetMaxY(clipRect);

        while (rowY < totalHeight)
        {
            rowY += rowHeight;
            CGContextMoveToPoint(context, minX, rowY);
            CGContextAddLineToPoint(context, maxX, rowY);
        }
    }

    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColor(context, _gridColor);
    CGContextStrokePath(context);
}

- (void)_drawVerticalGridInClipRect:(CGRect)clipRect
{
    if (!(_gridStyleMask & CPTableViewSolidVerticalGridLineMask))
        return;
        
    var visibleColumnIndexes = [self columnIndexesInRect:clipRect],
        columnsArray = [];

    [visibleColumnIndexes getIndexes:columnsArray maxCount:-1 inIndexRange:nil];

    var context = [[CPGraphicsContext currentContext] graphicsPort],
        columnArrayIndex = 0,
        columnArrayCount = columnsArray.length,
        minY = _CGRectGetMinY(clipRect),
        maxY = _CGRectGetMaxY(clipRect);
        
    CGContextBeginPath(context);
    
    for (; columnArrayIndex < columnArrayCount; ++columnArrayIndex)
    {
        var columnRect = [self rectOfColumn:columnsArray[columnArrayIndex]],
            columnX = _CGRectGetMaxX(columnRect) - 0.5;

        CGContextMoveToPoint(context, columnX, minY);
        CGContextAddLineToPoint(context, columnX, maxY);
    }

    CGContextSetStrokeColor(context, _gridColor);
    CGContextStrokePath(context);
}

- (void)highlightSelectionInClipRect:(CGRect)clipRect
{
    if (_selectionHighlightStyle === CPTableViewSelectionHighlightStyleNone)
        return;
        
    var context = [[CPGraphicsContext currentContext] graphicsPort],
        indexes = [],
        rectSelector = @selector(rectOfRow:),
        highlightingColumns = NO;

    if ([_selectedRowIndexes count] >= 1)
    {
        var visibleRows = [CPIndexSet indexSetWithIndexesInRange:[self rowsInRect:clipRect]];

        [_selectedRowIndexes getIndexes:indexes maxCount:-1 inIndexRange:nil];
    }
    else if ([_selectedColumnIndexes count] >= 1)
    {
        highlightingColumns = YES;
        rectSelector = @selector(rectOfColumn:);

        var visibleColumns = [self columnIndexesInRect:clipRect];

        [_selectedColumnIndexes getIndexes:indexes maxCount:-1 inIndexRange:nil];
    }

    var count = [indexes count];

    if (!count)
        return;

    var drawGradient = (_selectionHighlightStyle === CPTableViewSelectionHighlightStyleSourceList && [_selectedRowIndexes count] >= 1),
        hasHorizontalGrid = _gridStyleMask & CPTableViewSolidHorizontalGridLineMask,
        hasHorizontalSpacing = _intercellSpacing.width > 0,
        lastColumnIndex = [self numberOfColumns] - 1;

    CGContextSetFillColor(context, _selectionHighlightColor);
    CGContextBeginPath(context);
    
    for (var i = 0; i < count; i++)
    {
        var index = indexes[i],
            rect = [self performSelector:rectSelector withObject:index];
        
        if (highlightingColumns)
        {
            if (hasHorizontalSpacing && index != lastColumnIndex)
                --rect.size.width;
        }
        else
        {
            if (!drawGradient || hasHorizontalGrid)
                --rect.size.height;
        }
        
        rect = CGRectIntersection(rect, clipRect);
        CGContextAddRect(context, rect);

        if (drawGradient)
        {
            var minX = _CGRectGetMinX(rect),
                minY = _CGRectGetMinY(rect),
                maxX = _CGRectGetMaxX(rect),
                maxY = _CGRectGetMaxY(rect);

            CGContextDrawLinearGradient(context, _sourceListActiveGradient, rect.origin, CGPointMake(minX, maxY), 0);
            CGContextBeginPath(context);
            
            // If the row above is selected, use the "bottom" line color for the top line
            var topColor;
            
            if (index > 0 && 
                i > 0 && 
                (indexes[i - 1] == index - 1))
            {
                topColor = _sourceListActiveBottomLineColor;
            }
            else
                topColor = _sourceListActiveTopLineColor;
            
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, minX, minY + 0.5);
            CGContextAddLineToPoint(context, maxX, minY + 0.5);
            CGContextSetStrokeColor(context, topColor);
            CGContextStrokePath(context);
        }
    }
    
    if (!drawGradient)
        CGContextFillPath(context);
}

// Scrolling

/*!
    Scrolls the receiver vertically in an enclosing NSClipView so the row specified by rowIndex is visible.
    @param rowIndex the index of the row to scroll to.
*/
- (void)scrollRowToVisible:(CPInteger)rowIndex
{
    [self scrollRectToVisible:[self rectOfRow:rowIndex]];
}

/*!
    Scrolls the receiver and header view horizontally in an enclosing NSClipView so the column specified by columnIndex is visible.
    @param columnIndex the index of the column to scroll to.
*/
- (void)scrollColumnToVisible:(CPInteger)columnIndex
{
    [self scrollRectToVisible:[self rectOfColumn:columnIndex]];
    /*FIX ME: tableview header isn't rendered until you click the horizontal scroller (or scroll)*/
}

// Persistence
/*
    * - autosaveName
    * - autosaveTableColumns
    * - setAutosaveName:
    * - setAutosaveTableColumns:
*/

// Setting the Delegate

- (void)setDelegate:(id)aDelegate
{
    if (_delegate === aDelegate)
        return;

    var defaultCenter = [CPNotificationCenter defaultCenter];

    if (_delegate)
    {
        if ([_delegate respondsToSelector:@selector(tableViewColumnDidMove:)])
            [defaultCenter
                removeObserver:_delegate
                          name:CPTableViewColumnDidMoveNotification
                        object:self];

        if ([_delegate respondsToSelector:@selector(tableViewColumnDidResize:)])
            [defaultCenter
                removeObserver:_delegate
                          name:CPTableViewColumnDidResizeNotification
                        object:self];

        if ([_delegate respondsToSelector:@selector(tableViewSelectionDidChange:)])
            [defaultCenter
                removeObserver:_delegate
                          name:CPTableViewSelectionDidChangeNotification
                        object:self];

        if ([_delegate respondsToSelector:@selector(tableViewSelectionIsChanging:)])
            [defaultCenter
                removeObserver:_delegate
                          name:CPTableViewSelectionIsChangingNotification
                        object:self];
    }

    _delegate = aDelegate;
    _implementedDelegateMethods = 0;

    if ([_delegate respondsToSelector:@selector(selectionShouldChangeInTableView:)])
        _implementedDelegateMethods |= CPTableViewDelegate_selectionShouldChangeInTableView_;

    if ([_delegate respondsToSelector:@selector(tableView:dataViewForTableColumn:row:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_dataViewForTableColumn_row_;

    if ([_delegate respondsToSelector:@selector(tableView:didClickTableColumn:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_didClickTableColumn_;

    if ([_delegate respondsToSelector:@selector(tableView:didDragTableColumn:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_didDragTableColumn_;

    if ([_delegate respondsToSelector:@selector(tableView:heightOfRow:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_heightOfRow_;

    if ([_delegate respondsToSelector:@selector(tableView:isGroupRow:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_isGroupRow_;

    if ([_delegate respondsToSelector:@selector(tableView:mouseDownInHeaderOfTableColumn:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_mouseDownInHeaderOfTableColumn_;

    if ([_delegate respondsToSelector:@selector(tableView:nextTypeSelectMatchFromRow:toRow:forString:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_nextTypeSelectMatchFromRow_toRow_forString_;

    if ([_delegate respondsToSelector:@selector(tableView:selectionIndexesForProposedSelection:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_selectionIndexesForProposedSelection_;

    if ([_delegate respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_shouldEditTableColumn_row_;

    if ([_delegate respondsToSelector:@selector(tableView:shouldSelectRow:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_shouldSelectRow_;

    if ([_delegate respondsToSelector:@selector(tableView:shouldSelectTableColumn:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_shouldSelectTableColumn_;

    if ([_delegate respondsToSelector:@selector(tableView:shouldShowViewExpansionForTableColumn:row:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_shouldShowViewExpansionForTableColumn_row_;

    if ([_delegate respondsToSelector:@selector(tableView:shouldTrackView:forTableColumn:row:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_shouldTrackView_forTableColumn_row_;

    if ([_delegate respondsToSelector:@selector(tableView:shouldTypeSelectForEvent:withCurrentSearchString:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_shouldTypeSelectForEvent_withCurrentSearchString_;

    if ([_delegate respondsToSelector:@selector(tableView:toolTipForView:rect:tableColumn:row:mouseLocation:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_toolTipForView_rect_tableColumn_row_mouseLocation_;

    if ([_delegate respondsToSelector:@selector(tableView:typeSelectStringForTableColumn:row:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_typeSelectStringForTableColumn_row_;

    if ([_delegate respondsToSelector:@selector(tableView:willDisplayView:forTableColumn:row:)])
        _implementedDelegateMethods |= CPTableViewDelegate_tableView_willDisplayView_forTableColumn_row_;

    if ([_delegate respondsToSelector:@selector(tableViewColumnDidMove:)])
        [defaultCenter
            addObserver:_delegate
            selector:@selector(tableViewColumnDidMove:)
            name:CPTableViewColumnDidMoveNotification
            object:self];

    if ([_delegate respondsToSelector:@selector(tableViewColumnDidResize:)])
        [defaultCenter
            addObserver:_delegate
            selector:@selector(tableViewColumnDidResize:)
            name:CPTableViewColumnDidResizeNotification
            object:self];

    if ([_delegate respondsToSelector:@selector(tableViewSelectionDidChange:)])
        [defaultCenter
            addObserver:_delegate
            selector:@selector(tableViewSelectionDidChange:)
            name:CPTableViewSelectionDidChangeNotification
            object:self];

    if ([_delegate respondsToSelector:@selector(tableViewSelectionIsChanging:)])
        [defaultCenter
            addObserver:_delegate
            selector:@selector(tableViewSelectionIsChanging:)
            name:CPTableViewSelectionIsChangingNotification
            object:self];
}

- (id)delegate
{
    return _delegate;
}

- (void)_sendDelegateDidClickColumn:(CPInteger)column
{
    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_didClickTableColumn_)
            [_delegate tableView:self didClickTableColumn:_tableColumns[column]];
}

- (void)_sendDelegateDidDragColumn:(CPInteger)column
{
    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_didDragTableColumn_)
            [_delegate tableView:self didDragTableColumn:_tableColumns[column]];
}

- (void)_sendDelegateDidMouseDownInHeader:(CPInteger)column
{
    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_mouseDownInHeaderOfTableColumn_)
            [_delegate tableView:self mouseDownInHeaderOfTableColumn:_tableColumns[column]];
}

- (void)_sendDataSourceSortDescriptorsDidChange:(CPArray)oldDescriptors
{
    if (_implementedDataSourceMethods & CPTableViewDataSource_tableView_sortDescriptorsDidChange_)
            [_dataSource tableView:self sortDescriptorsDidChange:oldDescriptors];
}

// Highlightable Column Headers

- (CPTableColumn)highlightedTableColumn
{
    return _currentHighlightedTableColumn;
}

- (void)setHighlightedTableColumn:(CPTableColumn)aTableColumn
{
    if (_currentHighlightedTableColumn == aTableColumn)
        return;

    if (_headerView)
    {
        if (_currentHighlightedTableColumn != nil)
            [[_currentHighlightedTableColumn headerView] unsetThemeState:CPThemeStateSelected];

        if (aTableColumn != nil)
            [[aTableColumn headerView] setThemeState:CPThemeStateSelected];
    }

    _currentHighlightedTableColumn = aTableColumn;
}

// Dragging

- (CPImage)dragImageForRowsWithIndexes:(CPIndexSet)dragRows tableColumns:(CPArray)tableColumns event:(CPEvent)dragEvent offset:(CGPoint)dragImageOffset
{
    return [[CPImage alloc] initWithContentsOfFile:@"Frameworks/AppKit/Resources/GenericFile.png" size:_CGSizeMake(32,32)];
}

- (CPView)dragViewForRowsWithIndexes:(CPIndexSet)theDraggedRows tableColumns:(CPArray)tableColumns event:(CPEvent)theDragEvent offset:(CGPoint)dragViewOffset
{
    var bounds = [self bounds],
        view = [[CPView alloc] initWithFrame:bounds];

    [view setAlphaValue:0.6];

    // We have to fetch all the data views for the selected rows and columns.
    // After that we can copy these add them to a transparent drag view and use that drag view
    // to make it appear we are dragging images of those rows (as you would do in regular Cocoa).
    var columnIndex = [tableColumns count];
    
    while (columnIndex--)
    {
        var tableColumn = [tableColumns objectAtIndex:columnIndex];

        for (var row = [theDraggedRows firstIndex]; row !== CPNotFound; row = [theDraggedRows indexGreaterThanIndex:row])
        {
            var dataView = [self preparedDataViewAtColumn:columnIndex row:row];

            [view addSubview:dataView];
            [dataView setFrame:[self frameOfDataViewAtColumn:columnIndex row:row]];
        }
    }

    var dragPoint = [self convertPoint:[theDragEvent locationInWindow] fromView:nil];
    dragViewOffset.x = _CGRectGetMidX(bounds) - dragPoint.x;
    dragViewOffset.y = _CGRectGetMidY(bounds) - dragPoint.y;

    return view;
}

/*!
    @ignore
    
    Fetches all the data views (from the datasource) for the column and it's visible rows.
    Copy the dataviews and add them to a transparent drag view and use that drag view
    to make it appear we are dragging images of those rows (as you would do in regular Cocoa).
*/
- (CPView)_dragViewForColumn:(CPInteger)columnIndex
{
    var headerFrame = [_headerView frame],
        visibleRect = [self visibleRect],
        visibleRows = [self rowsInRect:visibleRect],
        columnRect = [self rectOfColumn:columnIndex],
        tableColumn = [[self tableColumns] objectAtIndex:columnIndex],
        columnHeaderView = [tableColumn headerView],
        columnHeaderFrame = [columnHeaderView frame],
        frame = _CGRectMake(MAX(_CGRectGetMinX(columnRect) - _CGRectGetMinX(visibleRect), 0.0), 
                            0.0, 
                            _CGRectGetWidth(columnHeaderFrame),
                            _CGRectGetHeight(visibleRect) + _CGRectGetHeight(headerFrame));

    // We need a wrapper view around the header and column, this is what will be dragged
    var dragView = [[_CPColumnDragDrawingView alloc] initWithFrame:frame];
    
    [dragView setTableView:self];
    [dragView setColumnIndex:columnIndex];
    [dragView setBackgroundColor:[CPColor clearColor]];
    [dragView setAlphaValue:0.6];
    
    // Now a view that clips the column data views, which itself is clipped to the content view
    var columnVisRect = CGRectIntersection(columnRect, visibleRect);
    
    frame = _CGRectMake(0.0, _CGRectGetHeight(headerFrame), _CGRectGetWidth(columnVisRect), _CGRectGetHeight(columnVisRect));
    
    var columnClipView = [[CPView alloc] initWithFrame:frame];
    
    [dragView addSubview:columnClipView];
    [dragView setColumnClipView:columnClipView];
    _draggedColumnIsSelected = [self isColumnSelected:columnIndex];
    
    var lastRow = CPMaxRange(visibleRows) - 1,
        columnLeft = _CGRectGetMinX(columnRect);
    
    for (var row = visibleRows.location; row <= lastRow; ++row)
    {
        var dataView = [self preparedDataViewAtColumn:columnIndex row:row],
            dataViewFrame = [self frameOfDataViewAtColumn:columnIndex row:row];

        dataViewFrame.origin.x -= columnLeft;

        // Offset by table header height - scroll position
        dataViewFrame.origin.y -= _CGRectGetMinY(visibleRect);
        [dataView setFrame:dataViewFrame];

        if (_draggedColumnIsSelected || [self isRowSelected:row])
            [dataView setThemeState:CPThemeStateSelectedDataView];
        else
            [dataView unsetThemeState:CPThemeStateSelectedDataView];
            
        [columnClipView addSubview:dataView];
    }

    // Add the column header view
    columnHeaderFrame.origin = _CGPointMakeZero();
        
    var dragColumnHeaderView = [[_CPTableColumnHeaderView alloc] initWithFrame:columnHeaderFrame],
        sortDescriptor = [_sortDescriptors objectAtIndex:columnIndex],
        image = [columnHeaderView _indicatorImage];
            
    [dragColumnHeaderView setStringValue:[columnHeaderView stringValue]];
    [dragColumnHeaderView setThemeState:[columnHeaderView themeState]];
    [dragColumnHeaderView _setIndicatorImage:image];
    
    // Give it a tag so it can be found later
    [dragColumnHeaderView setTag:CPTableHeaderViewDragColumnHeaderTag];
    
    [dragView addSubview:dragColumnHeaderView];
    
    // While dragging, the column is deselected in the table view
    [_selectedColumnIndexes removeIndex:columnIndex];
    
    return dragView;
}

/*!
    Returns whether the receiver allows dragging the rows at rowIndexes with a drag initiated at mousedDownPoint.
    @param rowIndexes an index set of rows to be dragged
    @param mouseDownPoint the point at which the mouse was clicked.
*/
- (BOOL)canDragRowsWithIndexes:(CPIndexSet)rowIndexes atPoint:(CGPoint)mouseDownPoint
{
    return YES;
}

- (void)setDraggingSourceOperationMask:(CPDragOperation)mask forLocal:(BOOL)isLocal
{
    // ignore local for the time being since only one capp app can run at a time...
    _dragOperationDefaultMask = mask;
}

/*!
    Sets whether vertical motion is treated as a drag or selection change to flag.
    @param aFlag If flag is NO then vertical motion will not start a drag. The default is YES.
*/
- (void)setVerticalMotionCanBeginDrag:(BOOL)aFlag
{
    _verticalMotionCanDrag = aFlag;
}

- (BOOL)verticalMotionCanBeginDrag
{
    return _verticalMotionCanDrag;
}

/*!
    Sets the feedback style for when the table is the destination of a drag operation.
    Can be:
    None
    Regular
    Source List
*/
- (void)setDraggingDestinationFeedbackStyle:(CPTableViewDraggingDestinationFeedbackStyle)aStyle
{
    // FIX ME: this should vary up the highlight color, currently nothing is being done with it
    _destinationDragStyle = aStyle;
}

- (CPTableViewDraggingDestinationFeedbackStyle)draggingDestinationFeedbackStyle
{
    return _destinationDragStyle;
}

/*!
    This should be called inside tableView:validateDrop:... method.
    Either drop on or above, specify the row as -1 to select the whole table for drop on
*/
- (void)setDropRow:(CPInteger)rowIndex dropOperation:(CPTableViewDropOperation)operation
{
    if (row > _numberOfRows && operation === CPTableViewDropOn)
    {
        var reason = @"Attempt to set dropRow=" + row +
                     " dropOperation=CPTableViewDropOn when [-1 - " + (_numberOfRows - 1) + "] is valid range of rows.";

        [[CPException exceptionWithName:@"Error" reason:reason userInfo:nil] raise];
    }

    _retargetedDropRow = row;
    _retargetedDropOperation = operation;
}

// Sorting

- (void)setSortDescriptors:(CPArray)sortDescriptors
{
    var oldSortDescriptors = [self sortDescriptors],
        newSortDescriptors = nil;

    if (sortDescriptors == nil)
        newSortDescriptors = [CPArray array];
    else
        newSortDescriptors = [CPArray arrayWithArray:sortDescriptors];

    if ([newSortDescriptors isEqual:oldSortDescriptors])
        return;

    _sortDescriptors = newSortDescriptors;

  	[self _sendDataSourceSortDescriptorsDidChange:oldSortDescriptors];
}

- (CPArray)sortDescriptors
{
    return _sortDescriptors;
}

- (void)_didClickTableColumn:(CPInteger)clickedColumn modifierFlags:(unsigned)modifierFlags
{
    [self _sendDelegateDidClickColumn:clickedColumn];

    if (_allowsColumnSelection)
    {
        [self _notifySelectionIsChanging];
        
        if (modifierFlags & CPCommandKeyMask)
        {
            if ([self isColumnSelected:clickedColumn])
                [self deselectColumn:clickedColumn];
            else if ([self allowsMultipleSelection] == YES)
                [self selectColumnIndexes:[CPIndexSet indexSetWithIndex:clickedColumn] byExtendingSelection:YES];

            return;
        }
        else if (modifierFlags & CPShiftKeyMask)
        {
            var startColumn = MIN(clickedColumn, [_selectedColumnIndexes lastIndex]),
                endColumn = MAX(clickedColumn, [_selectedColumnIndexes firstIndex])
                indexes = [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(startColumn, endColumn - startColumn + 1)];

            [self selectColumnIndexes:indexes byExtendingSelection:YES];

            return;
        }
        else
            [self selectColumnIndexes:[CPIndexSet indexSetWithIndex:clickedColumn] byExtendingSelection:NO];
    }

    [self _changeSortDescriptorsForClickOnColumn:clickedColumn];
}

// From GNUSTEP
- (void)_changeSortDescriptorsForClickOnColumn:(CPInteger)column
{
    var tableColumn = [_tableColumns objectAtIndex:column],
        newMainSortDescriptor = [tableColumn sortDescriptorPrototype];

    if (!newMainSortDescriptor)
       return;

    var oldMainSortDescriptor = nil,
        oldSortDescriptors = [self sortDescriptors],
        newSortDescriptors = [CPArray arrayWithArray:oldSortDescriptors],
        enumerator = [newSortDescriptors objectEnumerator],
        descriptor = nil,
        outdatedDescriptors = [CPArray array];

    if ([_sortDescriptors count] > 0)
        oldMainSortDescriptor = [[self sortDescriptors] objectAtIndex: 0];

    // Remove every main descriptor equivalent (normally only one)
    while ((descriptor = [enumerator nextObject]) != nil)
    {
        if ([[descriptor key] isEqual:[newMainSortDescriptor key]])
            [outdatedDescriptors addObject:descriptor];
    }

    // Invert the sort direction when the same column header is clicked twice
    if ([[newMainSortDescriptor key] isEqual:[oldMainSortDescriptor key]])
        newMainSortDescriptor = [oldMainSortDescriptor reversedSortDescriptor];

    [newSortDescriptors removeObjectsInArray:outdatedDescriptors];
    [newSortDescriptors insertObject:newMainSortDescriptor atIndex:0];

    // Update indicator image & highlighted column before
   	var image = [newMainSortDescriptor ascending] ? [CPTableView _defaultTableHeaderSortImage] : [CPTableView _defaultTableHeaderReverseSortImage];

    [self setIndicatorImage:nil inTableColumn:_currentHighlightedTableColumn];
	[self setIndicatorImage:image inTableColumn:tableColumn];

    [self setSortDescriptors:newSortDescriptors];
}

+ (CPImage)_defaultTableHeaderSortImage
{
    return CPAppKitImage("tableview-headerview-ascending.png", CGSizeMake(9.0, 8.0));
}

+ (CPImage)_defaultTableHeaderReverseSortImage
{
    return CPAppKitImage("tableview-headerview-descending.png", CGSizeMake(9.0, 8.0));
}

// Text Delegate Methods
/*
    * - textShouldBeginEditing:
    * - textDidBeginEditing:
    * - textDidChange:
    * - textShouldEndEditing:
    * - textDidEndEditing:
*/

// CPView Overrides

- (void)setFrameSize:(CGSize)aSize
{
    [super setFrameSize:aSize];

    if (_headerView)
        [_headerView setFrameSize:_CGSizeMake(_CGRectGetWidth([self frame]), _CGRectGetHeight([_headerView frame]))];
}

- (void)viewWillMoveToSuperview:(CPView)aView
{
    var superview = [self superview],
        defaultCenter = [CPNotificationCenter defaultCenter];

    if (superview)
    {
        [defaultCenter
            removeObserver:self
                      name:CPViewFrameDidChangeNotification
                    object:superview];
    }

    if (aView)
    {
        [aView setPostsFrameChangedNotifications:YES];

        [defaultCenter
            addObserver:self
               selector:@selector(superviewFrameChanged:)
                   name:CPViewFrameDidChangeNotification
                 object:aView];
    }
}

- (void)superviewFrameChanged:(CPNotification)aNotification
{
    [self _autoresizeToFit];
}

// CPControl Overrides

/*
    @ignore
*/
- (BOOL)tracksMouseOutsideOfFrame
{
    return YES;
}

/*
    @ignore
*/
- (BOOL)startTrackingAt:(CGPoint)aPoint
{
    var row = [self rowAtPoint:aPoint];

    //if the user clicks outside a row then deselect everything
    if (row < 0 && _allowsEmptySelection)
        [self selectRowIndexes:[CPIndexSet indexSet] byExtendingSelection:NO];

    [self _notifySelectionIsChanging];

    if ([self mouseDownFlags] & CPShiftKeyMask)
        _selectionAnchorRow = (ABS([_selectedRowIndexes firstIndex] - row) < ABS([_selectedRowIndexes lastIndex] - row)) ?
            [_selectedRowIndexes firstIndex] : [_selectedRowIndexes lastIndex];
    else
        _selectionAnchorRow = row;


    // set ivars for startTrackingPoint and time...
    _startTrackingPoint = aPoint;
    _startTrackingTimestamp = new Date();

    if (_implementedDataSourceMethods & CPTableViewDataSource_tableView_setObjectValue_forTableColumn_row_)
        _trackingPointMovedOutOfClickSlop = NO;

    // if the table has drag support then we use mouseUp to select a single row.
    // otherwise it uses mouse down.
    if (row >=0 && !(_implementedDataSourceMethods & CPTableViewDataSource_tableView_writeRowsWithIndexes_toPasteboard_))
        [self _updateSelectionWithMouseAtRow:row];

    [[self window] makeFirstResponder:self];
    return YES;
}

/*
    @ignore
*/
- (void)trackMouse:(CPEvent)anEvent
{
    // Prevent CPControl from eating the mouse events when we are in a drag session
    if (![_draggedRowIndexes count])
    {
        [self autoscroll:anEvent];
        [super trackMouse:anEvent];
    }
    else
        [CPApp sendEvent:anEvent];
}

/*
    @ignore
*/
- (BOOL)continueTracking:(CGPoint)lastPoint at:(CGPoint)aPoint
{
    var row = [self rowAtPoint:aPoint];

    // begin the drag if the datasource lets us, we've moved at least outside the slop vertically or horizontally,
    // or we're dragging from selected rows and we haven't begun a drag session
    if (!_isSelectingSession && _implementedDataSourceMethods & CPTableViewDataSource_tableView_writeRowsWithIndexes_toPasteboard_)
    {
        if (row >= 0 && (ABS(_startTrackingPoint.x - aPoint.x) > CPTableViewDragSlop || (_verticalMotionCanDrag && ABS(_startTrackingPoint.y - aPoint.y) > CPTableViewDrapSlop)) ||
            ([_selectedRowIndexes containsIndex:row]))
        {
            if ([_selectedRowIndexes containsIndex:row])
                _draggedRowIndexes = [[CPIndexSet alloc] initWithIndexSet:_selectedRowIndexes];
            else
                _draggedRowIndexes = [CPIndexSet indexSetWithIndex:row];

            // ask the datasource for the data
            var pboard = [CPPasteboard pasteboardWithName:CPDragPboard];

            if ([self canDragRowsWithIndexes:_draggedRowIndexes atPoint:aPoint] && [_dataSource tableView:self writeRowsWithIndexes:_draggedRowIndexes toPasteboard:pboard])
            {
                var currentEvent = [CPApp currentEvent],
                    offset = _CGPointMakeZero(),
                    tableColumns = [_tableColumns objectsAtIndexes:[_rowData visibleColumns]];

                // We deviate from the default Cocoa implementation here by asking for a view instead of an image.
                // We support both, but the view prefered over the image because we can mimic the rows we are dragging
                // by re-creating the data views for the dragged rows.
                var view = [self dragViewForRowsWithIndexes:_draggedRowIndexes
                                               tableColumns:tableColumns
                                                      event:currentEvent
                                                     offset:offset];

                if (!view)
                {
                    var image = [self dragImageForRowsWithIndexes:_draggedRowIndexes
                                                     tableColumns:tableColumns
                                                            event:currentEvent
                                                           offset:offset];
                                                           
                    view = [[CPImageView alloc] initWithFrame:CPMakeRect(0, 0, [image size].width, [image size].height)];
                    [view setImage:image];
                }

                var bounds = [view bounds],
                    viewLocation = _CGPointMake(aPoint.x - _CGRectGetMidX(bounds) + offset.x, aPoint.y - _CGRectGetMidY(bounds) + offset.y);
                
                [self dragView:view at:viewLocation offset:_CGPointMakeZero() event:[CPApp currentEvent] pasteboard:pboard source:self slideBack:YES];
                _startTrackingPoint = nil;

                return NO;
            }

            // The delegate disallowed the drag so clear the dragged row indexes
            _draggedRowIndexes = [CPIndexSet indexSet];
        }
        else if (ABS(_startTrackingPoint.x - aPoint.x) < CLICK_SPACE_DELTA && ABS(_startTrackingPoint.y - aPoint.y) < CLICK_SPACE_DELTA)
            return YES;
    }

    _isSelectingSession = YES;
    
    if (row >= 0 && row !== _lastTrackedRowIndex)
    {
        _lastTrackedRowIndex = row;
        [self _updateSelectionWithMouseAtRow:row];
    }

    if ((_implementedDataSourceMethods & CPTableViewDataSource_tableView_setObjectValue_forTableColumn_row_)
        && !_trackingPointMovedOutOfClickSlop)
    {        
        if (ABS(aPoint.x - _startTrackingPoint.x) > CLICK_SPACE_DELTA
            || ABS(aPoint.y - _startTrackingPoint.y) > CLICK_SPACE_DELTA)
        {
            _trackingPointMovedOutOfClickSlop = YES;
        }
    }

    return YES;
}

/*!
    @ignore
*/
- (void)stopTracking:(CGPoint)lastPoint at:(CGPoint)aPoint mouseIsUp:(BOOL)mouseIsUp
{
    _isSelectingSession = NO;

    var CLICK_TIME_DELTA = 1000,
        columnIndex,
        column,
        rowIndex,
        shouldEdit = YES;

    if (_implementedDataSourceMethods & CPTableViewDataSource_tableView_writeRowsWithIndexes_toPasteboard_)
    {
        rowIndex = [self rowAtPoint:aPoint];
        
        if (rowIndex !== -1)
        {
            if ([_draggedRowIndexes count] > 0)
            {
                _draggedRowIndexes = [CPIndexSet indexSet];
                return;
            }
            // if the table has drag support then we use mouseUp to select a single row.
             _previouslySelectedRowIndexes = [_selectedRowIndexes copy];
            [self _updateSelectionWithMouseAtRow:rowIndex];
        }
    }

    if (mouseIsUp
        && (_implementedDataSourceMethods & CPTableViewDataSource_tableView_setObjectValue_forTableColumn_row_)
        && !_trackingPointMovedOutOfClickSlop
        && ([[CPApp currentEvent] clickCount] > 1))
    {
        columnIndex = [self columnAtPoint:lastPoint];
        
        if (columnIndex !== -1)
        {
            column = _tableColumns[columnIndex];
            
            if ([column isEditable])
            {
                rowIndex = [self rowAtPoint:aPoint];
                
                if (rowIndex !== -1)
                {
                    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_shouldEditTableColumn_row_)
                        shouldEdit = [_delegate tableView:self shouldEditTableColumn:column row:rowIndex];
                    
                    if (shouldEdit)
                    {
                        [self editColumn:columnIndex row:rowIndex withEvent:nil select:YES];
                        return;
                    }
                }
            }
        }

    } // end of editing conditional

    var clickCount = [[CPApp currentEvent] clickCount];
    
    if ((clickCount === 1 && [self action]) || (clickCount === 2 && _doubleAction))
    {
        _clickedRow = [self rowAtPoint:aPoint];
        _clickedColumn = [self columnAtPoint:aPoint];
        
        if (clickCount === 1)
            [self sendAction:[self action] to:_target];
        else
            [self sendAction:_doubleAction to:_target];
    }
}

- (void)_updateSelectionWithMouseAtRow:(CPInteger)rowIndex
{
    // Check to make sure the row exists
    if (rowIndex < 0)
        return;

    var newSelection,
        shouldExtendSelection = NO;
        
    // If cmd/ctrl was held down XOR the old selection with the proposed selection
    if ([self mouseDownFlags] & (CPCommandKeyMask | CPControlKeyMask | CPAlternateKeyMask))
    {
        if ([_selectedRowIndexes containsIndex:rowIndex])
        {
            newSelection = [_selectedRowIndexes copy];

            [newSelection removeIndex:rowIndex];
        }
        else if (_allowsMultipleSelection)
        {
            newSelection = [_selectedRowIndexes copy];

            [newSelection addIndex:rowIndex];
        }
        else
            newSelection = [CPIndexSet indexSetWithIndex:rowIndex];
    }
    else if (_allowsMultipleSelection)
    {
        newSelection = [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(MIN(rowIndex, _selectionAnchorRow), ABS(rowIndex - _selectionAnchorRow) + 1)];
        shouldExtendSelection = [self mouseDownFlags] & CPShiftKeyMask &&
                                ((_lastSelectedRow == [_selectedRowIndexes lastIndex] && rowIndex > _lastSelectedRow) ||
                                (_lastSelectedRow == [_selectedRowIndexes firstIndex] && rowIndex < _lastSelectedRow));
    }
    else if (rowIndex >= 0 && rowIndex < _numberOfRows)
        newSelection = [CPIndexSet indexSetWithIndex:rowIndex];
    else
        newSelection = [CPIndexSet indexSet];

    if ([newSelection isEqualToIndexSet:_selectedRowIndexes])
        return;

    if (_implementedDelegateMethods & CPTableViewDelegate_selectionShouldChangeInTableView_ &&
        ![_delegate selectionShouldChangeInTableView:self])
        return;

    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_selectionIndexesForProposedSelection_)
        newSelection = [_delegate tableView:self selectionIndexesForProposedSelection:newSelection];

    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_shouldSelectRow_)
    {
        var indexArray = [];

        [newSelection getIndexes:indexArray maxCount:-1 inIndexRange:nil];

        var indexCount = indexArray.length;

        while (indexCount--)
        {
            var index = indexArray[indexCount];

            if (![_delegate tableView:self shouldSelectRow:index])
                [newSelection removeIndex:index];
        }
    }

    // if empty selection is not allowed and the new selection has nothing selected, abort
    if (!_allowsEmptySelection && [newSelection count] === 0)
        return;

    if ([newSelection isEqualToIndexSet:_selectedRowIndexes])
        return;

    [self selectRowIndexes:newSelection byExtendingSelection:shouldExtendSelection];
}

// CPResponder Overrides

- (BOOL)becomeFirstResponder
{
    return YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(CPEvent)anEvent
{
    [self interpretKeyEvents:[anEvent]];
}

- (void)moveDown:(id)sender
{
    if (_implementedDelegateMethods & CPTableViewDelegate_selectionShouldChangeInTableView_ &&
        ![_delegate selectionShouldChangeInTableView:self])
        return;

    var anEvent = [CPApp currentEvent];
    
    if ([[self selectedRowIndexes] count] > 0)
    {
        var extend = NO;

        if (([anEvent modifierFlags] & CPShiftKeyMask) && _allowsMultipleSelection)
            extend = YES;

        var i = [[self selectedRowIndexes] lastIndex];
        
        if (i < _numberOfRows - 1)
            i++; //set index to the next row after the last row selected
    }
    else
    {
        var extend = NO;
        
        //no rows are currently selected
        if (_numberOfRows > 0)
            var i = 0; //select the first row
    }


    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_shouldSelectRow_)
    {
        while ((![_delegate tableView:self shouldSelectRow:i]) && i < _numberOfRows)
        {
            //check to see if the row can be selected if it can't be then see if the next row can be selected
            i++;
        }

        //if the index still can be selected after the loop then just return
        if (![_delegate tableView:self shouldSelectRow:i])
             return;
    }

    [self selectRowIndexes:[CPIndexSet indexSetWithIndex:i] byExtendingSelection:extend];

    if (i >= 0)
        [self scrollRowToVisible:i];
}

- (void)moveDownAndModifySelection:(id)sender
{
    [self moveDown:sender];
}

- (void)moveUp:(id)sender
{
    if (_implementedDelegateMethods & CPTableViewDelegate_selectionShouldChangeInTableView_ &&
        ![_delegate selectionShouldChangeInTableView:self])
        return;

    var anEvent = [CPApp currentEvent],
        i = -1;
    
    if ([[self selectedRowIndexes] count] > 0)
    {
        var extend = NO;

        if (([anEvent modifierFlags] & CPShiftKeyMask) && _allowsMultipleSelection)
            extend = YES;

        i = [[self selectedRowIndexes] firstIndex];

        if (i > 0)
            i--; // set index to the prev row before the first row selected
    }
    else
    {
        var extend = NO;

        // no rows are currently selected
        if (_numberOfRows > 0)
            i = _numberOfRows - 1; // select the first row
    }


    if (_implementedDelegateMethods & CPTableViewDelegate_tableView_shouldSelectRow_)
    {
        while ((![_delegate tableView:self shouldSelectRow:i]) && i > 0)
        {
            // check to see if the row can be selected if it can't be then see if the prev row can be selected
            i--;
        }

        // if the index still can be selected after the loop then just return
        if (![_delegate tableView:self shouldSelectRow:i])
            return;
    }

    [self selectRowIndexes:[CPIndexSet indexSetWithIndex:i] byExtendingSelection:extend];

    if (i >= 0)
        [self scrollRowToVisible:i];
}

- (void)moveUpAndModifySelection:(id)sender
{
    [self moveUp:sender];
}

- (void)deleteBackward:(id)sender
{
    if ([_delegate respondsToSelector: @selector(tableViewDeleteKeyPressed:)])
        [_delegate tableViewDeleteKeyPressed:self];
}

@end // CPTableView

@implementation CPTableView (CPDraggingDestination)

/*
    @ignore
*/
- (CPDragOperation)draggingEntered:(id)sender
{
    var location = [self convertPoint:[sender draggingLocation] fromView:nil],
        dropInfo = [self _proposedDropInfoAtPoint:location],
        row = [dropInfo objectForKey:@"row"];

    if (_retargetedDropRow !== nil)
        row = _retargetedDropRow;

    var draggedTypes = [self registeredDraggedTypes],
        count = [draggedTypes count],
        i = 0;

    for (; i < count; i++)
    {
        if ([[[sender draggingPasteboard] types] containsObject:[draggedTypes objectAtIndex: i]])
            return [self _validateDrop:sender proposedRow:row proposedDropOperation:[dropInfo objectForKey:@"operation"]];
    }

    return CPDragOperationNone;
}

/*
    @ignore
*/
- (void)draggingExited:(id)sender
{
    [_dropOperationFeedbackView setHidden:YES];
}

/*
    @ignore
*/
- (void)draggingEnded:(id)sender
{
    [self _draggingEnded];
}

- (void)_draggingEnded
{
    _retargetedDropOperation = nil;
    _retargetedDropRow = nil;
    _draggedRowIndexes = [CPIndexSet indexSet];
    [_dropOperationFeedbackView setHidden:YES];
}
/*
    @ignore
*/
- (BOOL)wantsPeriodicDraggingUpdates
{
    return YES;
}

/*
    @ignore
*/
- (CPDictionary)_proposedDropInfoAtPoint:(CGPoint)theDragPoint
{
	// We don't use rowAtPoint here because the drag indicator can appear below the last row
	// and rowAtPoint doesn't return rows that are larger than numberOfRows.
    // FIX ME: this is going to break when we implement variable row heights... 
    var info = [CPDictionary dictionary],
        row = MIN(FLOOR(theDragPoint.y / (_rowHeight + _intercellSpacing.height)), _numberOfRows),
		rect = [self rectOfRow:row],
		quarterHeight = ROUND(_CGRectGetHeight(rect) * 0.25),
        topLimit = ROUND(_CGRectGetMinY(rect) + quarterHeight),
        bottomLimit = ROUND(_CGRectGetMaxY(rect) - quarterHeight);

    [info setObject:row forKey:@"row"];
    
    if (_retargetedDropOperation !== nil)
    {
        [info setObject:_retargetedDropOperation forKey:@"operation"];
    }
    else if (row == _numberOfRows)
    {
        [info setObject:CPTableViewDropAbove forKey:@"operation"];
    }
    else if (theDragPoint.y < topLimit)
    {
        if (row == 0 && [_draggedRowIndexes firstIndex] == 0)
            [info setObject:CPTableViewDropOn forKey:@"operation"];
        else
            [info setObject:CPTableViewDropAbove forKey:@"operation"];
    }
    else if (theDragPoint.y > bottomLimit)
    {
        [info setObject:row + 1 forKey:@"row"];
        [info setObject:CPTableViewDropAbove forKey:@"operation"];
    }
    else
    {
        [info setObject:CPTableViewDropOn forKey:@"operation"];
    }
    
    return info;
}

/*
    @ignore
*/
- (void)_validateDrop:(id)info proposedRow:(CPInteger)row proposedDropOperation:(CPTableViewDropOperation)dropOperation
{
    if (_implementedDataSourceMethods & CPTableViewDataSource_tableView_validateDrop_proposedRow_proposedDropOperation_)
        return [_dataSource tableView:self validateDrop:info proposedRow:row proposedDropOperation:dropOperation];

    return CPDragOperationNone;
}

- (CGRect)_rectForDropHighlightViewOnRow:(CPInteger)theRowIndex
{
    if (theRowIndex >= _numberOfRows)
        theRowIndex = _numberOfRows - 1;

    return [self rectOfRow:theRowIndex];
}

- (CGRect)_rectForDropHighlightViewBetweenUpperRow:(CPInteger)theUpperRowIndex andLowerRow:(CPInteger)theLowerRowIndex offset:(CGPoint)theOffset
{
    if (theLowerRowIndex > _numberOfRows)
        theLowerRowIndex = _numberOfRows;

	return [self rectOfRow:theLowerRowIndex];
}

- (CPDragOperation)draggingUpdated:(id)sender
{    
    var location = [self convertPoint:[sender draggingLocation] fromView:nil],
        dropInfo = [self _proposedDropInfoAtPoint:location],
        row = [dropInfo objectForKey:@"row"],
        dropOperation = [dropInfo objectForKey:@"operation"],
        numberOfRows = _numberOfRows,
        dragOperation = [self _validateDrop:sender proposedRow:row proposedDropOperation:dropOperation],
        visibleRect = [self visibleRect];

    [_dropOperationFeedbackView setHidden:(dragOperation == CPDragOperationNone)];
    
    if (_retargetedDropRow !== nil)
        row = _retargetedDropRow;
        
    if (row == [_dropOperationFeedbackView currentRow] && dropOperation == [_dropOperationFeedbackView dropOperation])        
        return dragOperation;

    var rect = _CGRectMakeZero();

    if (row === -1)
        rect = visibleRect;
    else if (dropOperation === CPTableViewDropAbove)
        rect = [self _rectForDropHighlightViewBetweenUpperRow:row - 1 andLowerRow:row offset:location];
    else
        rect = [self _rectForDropHighlightViewOnRow:row];

    [_dropOperationFeedbackView setDropOperation:row !== -1 ? dropOperation : CPDragOperationNone];
    [_dropOperationFeedbackView setFrame:rect];
    [_dropOperationFeedbackView setCurrentRow:row];
    [_dropOperationFeedbackView setNeedsDisplay:YES];

    return dragOperation;
}

/*
    @ignore
*/
- (BOOL)prepareForDragOperation:(id)sender
{
    // FIX ME: is there anything else that needs to happen here?
    // Actual validation is called in draggingUpdated:
    [_dropOperationFeedbackView setHidden:YES];
    
    return (_implementedDataSourceMethods & CPTableViewDataSource_tableView_validateDrop_proposedRow_proposedDropOperation_);
}

/*
    @ignore
*/
- (BOOL)performDragOperation:(id)sender
{
    var location = [self convertPoint:[sender draggingLocation] fromView:nil],
        info = [self _proposedDropInfoAtPoint:location],
        row = _retargetedDropRow;

    if (row === nil)
        row = [info objectForKey:@"row"];

    return [_dataSource tableView:self acceptDrop:sender row:row dropOperation:[info objectForKey:@"operation"]];
}

/*
    @ignore
*/
- (void)concludeDragOperation:(id)sender
{
    [self reloadData];
}

@end // CPTableView (CPDraggingDestination)

@implementation CPTableView (CPDraggingSource)

/*
    //this method is sent to the data source for conviences...
*/
- (void)draggedImage:(CPImage)anImage endedAt:(CGPoint)aLocation operation:(CPDragOperation)operation
{
    if ([_dataSource respondsToSelector:@selector(tableView:didEndDraggedImage:atPosition:operation:)])
        [_dataSource tableView:self didEndDraggedImage:anImage atPosition:aLocation operation:operation];
}

/*
    @ignore
    we're using this because we drag views instead of images so we can get the rows themselves to actually drag
*/
- (void)draggedView:(CPImage)aView endedAt:(CGPoint)aLocation operation:(CPDragOperation)operation
{
    [self _draggingEnded];
    [self draggedImage:aView endedAt:aLocation operation:operation];
}

@end // CPTableView (CPDraggingSource)

@implementation CPTableView (Bindings)

- (CPString)_replacementKeyPathForBinding:(CPString)aBinding
{
    if (aBinding === @"selectionIndexes")
        return @"selectedRowIndexes";

    return [super _replacementKeyPathForBinding:aBinding];
}

- (void)_establishBindingsIfUnbound:(id)destination
{
    if ([[self infoForBinding:@"content"] objectForKey:CPObservedObjectKey] !== destination)
        [self bind:@"content" toObject:destination withKeyPath:@"arrangedObjects" options:nil];

    if ([[self infoForBinding:@"selectionIndexes"] objectForKey:CPObservedObjectKey] !== destination)
        [self bind:@"selectionIndexes" toObject:destination withKeyPath:@"selectionIndexes" options:nil];

    //[self bind:@"sortDescriptors" toObject:destination withKeyPath:@"sortDescriptors" options:nil];
}

- (void)setContent:(CPArray)content
{
    [self reloadData];
}

@end

var CPTableViewDataSourceKey                = @"CPTableViewDataSourceKey",
    CPTableViewDelegateKey                  = @"CPTableViewDelegateKey",
    CPTableViewHeaderViewKey                = @"CPTableViewHeaderViewKey",
    CPTableViewTableColumnsKey              = @"CPTableViewTableColumnsKey",
    CPTableViewRowHeightKey                 = @"CPTableViewRowHeightKey",
    CPTableViewIntercellSpacingKey          = @"CPTableViewIntercellSpacingKey",
    CPTableViewSelectionHighlightStyleKey   = @"CPTableViewSelectionHighlightStyleKey",
    CPTableViewMultipleSelectionKey         = @"CPTableViewMultipleSelectionKey",
    CPTableViewEmptySelectionKey            = @"CPTableViewEmptySelectionKey",
    CPTableViewColumnReorderingKey          = @"CPTableViewColumnReorderingKey",
    CPTableViewColumnResizingKey            = @"CPTableViewColumnResizingKey",
    CPTableViewColumnSelectionKey           = @"CPTableViewColumnSelectionKey",
    CPTableViewColumnAutoresizingStyleKey   = @"CPTableViewColumnAutoresizingStyleKey",
    CPTableViewGridColorKey                 = @"CPTableViewGridColorKey",
    CPTableViewGridStyleMaskKey             = @"CPTableViewGridStyleMaskKey",
    CPTableViewUsesAlternatingBackgroundKey = @"CPTableViewUsesAlternatingBackgroundKey",
    CPTableViewAlternatingRowColorsKey      = @"CPTableViewAlternatingRowColorsKey",
    CPTableViewHeaderViewKey                = @"CPTableViewHeaderViewKey",
    CPTableViewCornerViewKey                = @"CPTableViewCornerViewKey";

@implementation CPTableView (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    self = [super initWithCoder:aCoder];

    if (self)
    {
        // Configuring Behavior
        _allowsColumnReordering = [aCoder decodeBoolForKey:CPTableViewColumnReorderingKey];
        _allowsColumnResizing = [aCoder decodeBoolForKey:CPTableViewColumnResizingKey];
        _allowsMultipleSelection = [aCoder decodeBoolForKey:CPTableViewMultipleSelectionKey];
        _allowsEmptySelection = [aCoder decodeBoolForKey:CPTableViewEmptySelectionKey];
        _allowsColumnSelection = [aCoder decodeBoolForKey:CPTableViewColumnSelectionKey];
        
        _disableAutomaticResizing = NO;

        // Setting Display Attributes
        _selectionHighlightStyle = [aCoder decodeIntForKey:CPTableViewSelectionHighlightStyleKey];
        _columnAutoResizingStyle = [aCoder decodeIntForKey:CPTableViewColumnAutoresizingStyleKey];

        _tableColumns = [aCoder decodeObjectForKey:CPTableViewTableColumnsKey] || [];
        [_tableColumns makeObjectsPerformSelector:@selector(setTableView:) withObject:self];

        if ([aCoder containsValueForKey:CPTableViewRowHeightKey])
            _rowHeight = [aCoder decodeFloatForKey:CPTableViewRowHeightKey];
        else
            _rowHeight = CPTableViewDefaultRowHeight;
            
        _intercellSpacing = [aCoder decodeSizeForKey:CPTableViewIntercellSpacingKey] || _CGSizeMake(3.0, 2.0);

        _gridColor = [aCoder decodeObjectForKey:CPTableViewGridColorKey] || [CPColor colorWithHexString:@"c0c0c0"];
        _gridStyleMask = [aCoder decodeIntForKey:CPTableViewGridStyleMaskKey] || CPTableViewGridNone;

        _usesAlternatingRowBackgroundColors = [aCoder decodeObjectForKey:CPTableViewUsesAlternatingBackgroundKey];
        _alternatingRowBackgroundColors =
            [[CPColor whiteColor], [CPColor colorWithHexString:@"edf3fe"]];

        _headerView = [aCoder decodeObjectForKey:CPTableViewHeaderViewKey];
        _cornerView = [aCoder decodeObjectForKey:CPTableViewCornerViewKey];
        
        // It is possible for the _cornerView to have its origin wrong because of coordinate space swapping
        // in nib2cib, so we fix it here.
        if (_cornerView)
        {
            var frame = [_cornerView frame];
            
            if (_CGRectGetMinY(frame) != 0)
                [_cornerView setFrameOrigin:_CGPointMake(_CGRectGetMinX(frame), 0.0)];
        }

        _dataSource = [aCoder decodeObjectForKey:CPTableViewDataSourceKey];
        _delegate = [aCoder decodeObjectForKey:CPTableViewDelegateKey];

        [self _init];

        [self viewWillMoveToSuperview:[self superview]];
    }

    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];

    [aCoder encodeObject:_dataSource forKey:CPTableViewDataSourceKey];
    [aCoder encodeObject:_delegate forKey:CPTableViewDelegateKey];

    [aCoder encodeFloat:_rowHeight forKey:CPTableViewRowHeightKey];
    [aCoder encodeSize:_intercellSpacing forKey:CPTableViewIntercellSpacingKey];
    
    [aCoder encodeInt:_selectionHighlightStyle forKey:CPTableViewSelectionHighlightStyleKey];
    [aCoder encodeInt:_columnAutoResizingStyle forKey:CPTableViewColumnAutoresizingStyleKey];
    
    [aCoder encodeBool:_allowsMultipleSelection forKey:CPTableViewMultipleSelectionKey];
    [aCoder encodeBool:_allowsEmptySelection forKey:CPTableViewEmptySelectionKey];
    [aCoder encodeBool:_allowsColumnReordering forKey:CPTableViewColumnReorderingKey];
    [aCoder encodeBool:_allowsColumnResizing forKey:CPTableViewColumnResizingKey];
    [aCoder encodeBool:_allowsColumnSelection forKey:CPTableViewColumnSelectionKey];

    [aCoder encodeObject:_tableColumns forKey:CPTableViewTableColumnsKey];

    [aCoder encodeObject:_gridColor forKey:CPTableViewGridColorKey];
    [aCoder encodeInt:_gridStyleMask forKey:CPTableViewGridStyleMaskKey];

    [aCoder encodeBool:_usesAlternatingRowBackgroundColors forKey:CPTableViewUsesAlternatingBackgroundKey];
    [aCoder encodeObject:_alternatingRowBackgroundColors forKey:CPTableViewAlternatingRowColorsKey]

    [aCoder encodeObject:_cornerView forKey:CPTableViewCornerViewKey];
    [aCoder encodeObject:_headerView forKey:CPTableViewHeaderViewKey];
}

@end

@implementation CPIndexSet (tableview)

- (void)removeMatches:otherSet
{
    var firstindex = [self firstIndex];
    var index = MIN(firstindex, [otherSet firstIndex]);
    var switchFlag = (index == firstindex);
    
    while (index != CPNotFound)
    {
        var indexSet = (switchFlag) ? otherSet : self,
            otherIndex = [indexSet indexGreaterThanOrEqualToIndex:index];
        
        if (otherIndex == index)
        {
            [self removeIndex:index];
            [otherSet removeIndex:index];
        }
        
        index = otherIndex;
        switchFlag = !switchFlag;
    }
}

@end


@implementation _CPColumnDragDrawingView : CPView
{
    CPTableView tableView       @accessors;
    int         columnIndex     @accessors;
    CPView      columnClipView  @accessors;
}

- (void)drawRect:(CGRect)dirtyRect
{
    var context = [[CPGraphicsContext currentContext] graphicsPort],
        columnRect = [tableView rectOfColumn:columnIndex],
        headerHeight = _CGRectGetHeight([[tableView headerView] frame]),
        bounds = [columnClipView bounds],
        visibleRect = [tableView visibleRect],
        xScroll = _CGRectGetMinX(visibleRect),
        yScroll = _CGRectGetMinY(visibleRect);
    
    // Because we are sharing drawing code with regular table drawing,
    // we have to play a few tricks to fool the drawing code into thinking
    // our drag column is in the same place as the real column.
    
    // Shift the bounds origin to align with the column rect, and extend it vertically to ensure
    // it reaches the bottom of the tableView when scrolled.
    bounds.origin.x = _CGRectGetMinX(columnRect) - xScroll;
    bounds.size.height += yScroll;
    
    // Fix up the CTM to account for the header and scroll
    CGContextTranslateCTM(context, -bounds.origin.x, headerHeight - yScroll);
    
    [tableView drawBackgroundInClipRect:bounds];
    
    if (tableView._draggedColumnIsSelected)
    {
        CGContextSetFillColor(context, tableView._selectionHighlightColor);
        CGContextFillRect(context, bounds);
    }
    else
        [tableView highlightSelectionInClipRect:bounds];
    
    [tableView _drawHorizontalGridInClipRect:bounds];
    
    var minX = _CGRectGetMinX(bounds) + 0.5,
        maxX = _CGRectGetMaxX(bounds) - 0.5;
    
    CGContextSetLineWidth(context, 1.0);
    CGContextSetAlpha(context, 1.0);
    CGContextSetStrokeColor(context, tableView._gridColor);
    
    CGContextBeginPath(context);
    
    CGContextMoveToPoint(context, minX, _CGRectGetMinY(bounds));
    CGContextAddLineToPoint(context, minX, _CGRectGetMaxY(bounds));
    
    CGContextMoveToPoint(context, maxX, _CGRectGetMinY(bounds));
    CGContextAddLineToPoint(context, maxX, _CGRectGetMaxY(bounds));
    
    CGContextStrokePath(context);
}

@end


var CPDropOperationIndicatorHeight = 8;

@implementation _CPDropOperationDrawingView : CPView
{
    unsigned    dropOperation   @accessors;
    CPTableView tableView       @accessors;
    int         currentRow      @accessors;
    BOOL        isBlinking      @accessors;
}

- (void)_drawDropAboveIndicatorWithContext:(CGContext)context rect:(CGRect)aRect color:(CPColor)aColor width:(CPInteger)aWidth
{
    CGContextSetStrokeColor(context, aColor);
    CGContextSetLineWidth(context, aWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    
    // draw the circle thing
    var inset = CPDropOperationIndicatorHeight / 2,
        rect = _CGRectMake(aRect.origin.x + inset, 
                           aRect.origin.y + inset, 
                           CPDropOperationIndicatorHeight, 
                           CPDropOperationIndicatorHeight);
                           
    CGContextStrokeEllipseInRect(context, rect);
    
    // then draw the line
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, _CGRectGetMaxX(rect), _CGRectGetMidY(rect));
    CGContextAddLineToPoint(context, _CGRectGetMaxX(aRect) - inset, _CGRectGetMidY(rect));
    CGContextStrokePath(context);
}

- (void)drawRect:(CGRect)dirtyRect
{
    if (tableView._destinationDragStyle === CPTableViewDraggingDestinationFeedbackStyleNone || 
        [[tableView headerView] isDragging] ||
        isBlinking)
    {
        return;
    }

    var context = [[CPGraphicsContext currentContext] graphicsPort];

    CGContextSetStrokeColor(context, [CPColor colorWithHexString:@"4886ca"]);
    CGContextSetLineWidth(context, 3);

    if (currentRow === -1)
    {
        CGContextStrokeRect(context, [self bounds]);
    }
    else if (dropOperation === CPTableViewDropOn)
    {
        // if row is selected don't fill and stroke white
        var selectedRows = [tableView selectedRowIndexes],
            newRect = _CGRectInset(dirtyRect, 2.0, 2.0);
            
        --newRect.size.height;

        if ([selectedRows containsIndex:currentRow])
        {
            CGContextSetLineWidth(context, 2);
            CGContextSetStrokeColor(context, [CPColor whiteColor]);
        }
        else
        {
            CGContextSetFillColor(context, [CPColor colorWithRed:72/255.0 green:134/255.0 blue:202/255.0 alpha:0.25]);
            CGContextFillRoundedRectangleInRect(context, newRect, 8, YES, YES, YES, YES);
        }
        
        CGContextStrokeRoundedRectangleInRect(context, newRect, 8, YES, YES, YES, YES);
    }
    else if (dropOperation === CPTableViewDropAbove)
    {
        // reposition the view up a tad so indicator can draw above the row rect
        [self setFrameOrigin:CGPointMake(_frame.origin.x, _frame.origin.y - CPDropOperationIndicatorHeight)];
        
        var selectedRows = [tableView selectedRowIndexes];

        if ([selectedRows containsIndex:currentRow - 1] || [selectedRows containsIndex:currentRow])
            [self _drawDropAboveIndicatorWithContext:context rect:dirtyRect color:[CPColor whiteColor] width:4];
            
        [self _drawDropAboveIndicatorWithContext:context rect:dirtyRect color:[CPColor colorWithHexString:@"4886ca"] width:3];
    }
}

- (void)blink
{
    if (dropOperation !== CPTableViewDropOn)
        return;

    isBlinking = YES;

    var showCallback = function() {
        [self performSelector:CPSelectorFromString(@"setHidden:") withObject:NO];
        isBlinking = NO;
    }

    var hideCallback = function() {
        [self performSelector:CPSelectorFromString(@"setHidden:") withObject:YES];
        isBlinking = YES;
    }

    [self performSelector:CPSelectorFromString(@"setHidden:") withObject:YES];
    [CPTimer scheduledTimerWithTimeInterval:0.1 callback:showCallback repeats:NO];
    [CPTimer scheduledTimerWithTimeInterval:0.19 callback:hideCallback repeats:NO];
    [CPTimer scheduledTimerWithTimeInterval:0.27 callback:showCallback repeats:NO];
}

@end
