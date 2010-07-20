/*
 * _CPTableViewCache.j
 * AppKit
 *
 * Created by Francisco Tolmasky.
 * Copyright 2010, 280 North, Inc.
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
@import <Foundation/CPDictionary.j>


@implementation _CPTableRowData : CPObject
{
    CPTableView     _tableView
    
    // Each item in the dictionary is keyed on the row index and holds
    // an array of data views, one for each column.
    CPDictionary    _dataViews;
    
    // Each item in the dictionary is keyed on the row index and holds
    // an array of object values, one for each column.
    CPDictionary    _objectValues;

    CPInteger       _flushCount;
    
    BOOL            _usesDataViewCache;
    CPInteger       _dataViewCacheLimit;
    
    BOOL            _usesObjectValueCache;
    CPInteger       _objectValueCacheLimit;
    
    CPIndexSet      _visibleRows        @accessors(readonly, getter=visibleRows);
    CPIndexSet      _visibleColumns     @accessors(readonly, getter=visibleColumns);
}

- (id)initWithTableView:(CPTableView)aTableView
{
    var self = [super init];
    
    if (self)
    {
        _tableView = aTableView;
        
        _dataViews = [CPDictionary dictionary];
        _objectValues = [CPDictionary dictionary];
        
        _flushCount = 0;
        
        _usesDataViewCache = YES;
        _dataViewCacheLimit = 50;
        
        _usesObjectValueCache = YES;
        _objectValueCacheLimit = 50;
        
        _visibleRows = [CPIndexSet indexSet];
        _visibleColumns = [CPIndexSet indexSet];
    }
    
    return self;
}

- (void)_beginFlush
{
    ++_flushCount;
}

- (void)_endFlush
{
    _flushCount = MAX(_flushCount - 1, 0);
}

/*
    This indicates whether we are within a _beginFlush/_endFlush pair.
*/
- (BOOL)_isFlushing
{
    return _flushCount > 0;
}

- (void)setUsesCache:(BOOL)flag
{
    _usesCache = !!flag;
}

- (BOOL)usesCache
{
    return _usesCache;
}

- (void)setCacheExtraSize:(CPInteger)size
{
    _cacheExtraSize = MAX(size, 0);
}

- (CPInteger)cacheExtraSize
{
    return _cacheExtraSize;
}

- (void)setDataView:(CPView)aView forRow:(CPInteger)row column:(CPInteger)column
{
    var rowData = [self _dataViewArrayForRow:row],
        oldDataView = rowData[column];
    
    if (oldDataView)
        [oldDataView removeFromSuperview];
        
    rowData[column] = aView;
}

- (void)dataViewForRow:(CPInteger)row column:(CPInteger)column
{
    var rowData = [self _dataViewArrayForRow:row],
        dataView = rowData[column];
    
    return dataView;
}

- (void)setObjectValue:(id)aValue forRow:(CPInteger)row column:(CPInteger)column
{
    var rowData = [self _objectValueArrayForRow:row];        
    rowData[column] = aView;
}

- (void)objectValueForRow:(CPInteger)row column:(CPInteger)column
{
    var rowData = [self _objectValueArrayForRow:row];
    return rowData[column];
}

- (void)flushDirtyRect:(CGRect)dirtyRect
{
    if ([self _isFlushing])
        return;
        
    [self _beginFlush];
        
    var visibleRect = [_tableView visibleRect],
        visibleRows = [CPIndexSet indexSetWithIndexesInRange:[_tableView rowsInRect:visibleRect]],
        visibleColumns = [_tableView columnIndexesInRect:visibleRect],
        obscuredRows = [_visibleRows copy],
        obscuredColumns = [_visibleColumns copy];

    [obscuredRows removeIndexes:visibleRows];
    [obscuredColumns removeIndexes:visibleColumns];

    var dirtyRowRange = [_tableView rowsInRect:dirtyRect],
        dirtyRows = [CPIndexSet indexSetWithIndexesInRange:dirtyRowRange],
        dirtyColumns = [_tableView columnIndexesInRect:dirtyRect];

    [dirtyRows removeIndexes:_visibleRows];
    [dirtyColumns removeIndexes:_visibleColumns];

    // Flush complete obscured rows
    //console.log('obscuredRows: %s', [obscuredRows description]);
    [self _flushRowIndexes:obscuredRows];
    
    // Now flush complete obscured columns
    var unflushedRows = [_visibleRows copy];
    
    [unflushedRows removeIndexes:obscuredRows];
    //console.log('unflushedRows: %s', [unflushedRows description]);
    //console.log('obscuredColumns: %s', [obscuredColumns description]);
    [self _flushRowIndexes:unflushedRows columnIndexes:obscuredColumns];
    
    // Flush complete dirty rows
    //console.log('dirtyRows: %s', [dirtyRows description]);
    [self _flushRowIndexes:dirtyRows];
    
    // Now flush complete dirty columns
    unflushedRows = [visibleRows copy];
    [unflushedRows removeIndexes:dirtyRows];
    //console.log('unflushedRows: %s', [unflushedRows description]);
    //console.log('dirtyColumns: %s', [dirtyColumns description]);
    [self _flushRowIndexes:unflushedRows columnIndexes:dirtyColumns];
    
    //console.log('# subviews: %d', [[_tableView subviews] count]);
    [self _resetVisibleRowsAndColumns];
    [self _endFlush];
}

- (void)flushAll
{
    if ([self _isFlushing])
        return;
        
    [self _beginFlush];
    
    var keys = [_dataViews allKeys],
        count = [keys count];
        
    for (var row = 0; row < count; ++row)
        [self _flushRow:row];
        
    _dataViews = [CPDictionary dictionary];
    
    [self _resetVisibleRowsAndColumns];
    [self _endFlush];
}

- (void)flushRow:(CPInteger)row
{
    if ([self _isFlushing])
        return;
        
    [self _beginFlush];
    [self _flushRow:row];
    [self _endFlush];
}

- (void)_flushRow:(CPInteger)row
{
    //console.log('flushRow:%d', row);
        
    var rowData = [self _dataViewArrayForRow:row],
        count = [rowData count];
    
    for (var column = 0; column < count; ++column)
        [self _flushDataViewInRowData:rowData column:column];
    
    [_dataViews removeObjectForKey:row];
}

- (void)flushRow:(CPInteger)row columnIndexes:(CPIndexSet)columnIndexes
{
    if ([self _isFlushing])
        return;
        
    [self _beginFlush];
    [self _flushRow:row columnIndexes:columnIndexes];
    [self _endFlush];
}        

- (void)_flushRow:(CPInteger)row columnIndexes:(CPIndexSet)columnIndexes
{
    if ([columnIndexes count] === 0)
        return;
        
    var rowData = [self _dataViewArrayForRow:row],
        count = [rowData count];
        
    if (count)
    {
        for (var column = [columnIndexes firstIndex]; column != CPNotFound; column = [columnIndexes indexGreaterThanIndex:column])
            [self _flushDataViewInRowData:rowData column:column];
    }
}

- (void)flushRowIndexes:(CPIndexSet)rowIndexes
{
    if ([self _isFlushing])
        return;

    [self _beginFlush];
    [self _flushRowIndexes:rowIndexes];
    [self _endFlush];
}

- (void)_flushRowIndexes:(CPIndexSet)rowIndexes
{        
    for (var row = [rowIndexes firstIndex]; row != CPNotFound; row = [rowIndexes indexGreaterThanIndex:row])
        [self _flushRow:row];
}

- (void)flushRowIndexes:(CPIndexSet)rowIndexes columnIndexes:(CPIndexSet)columnIndexes
{
    if ([self _isFlushing])
        return;

    [self _beginFlush];
    [self _flushRowIndexes:rowIndexes columnIndexes:columnIndexes];
    [self _endFlush];
} 

- (void)_flushRowIndexes:(CPIndexSet)rowIndexes columnIndexes:(CPIndexSet)columnIndexes
{
    if ([columnIndexes count] === 0)
        return;
        
    for (var row = [rowIndexes firstIndex]; row != CPNotFound; row = [rowIndexes indexGreaterThanIndex:row])
        [self _flushRow:row columnIndexes:columnIndexes];
}

- (void)_flushDataViewInRowData:(CPArray)rowData column:(CPInteger)column
{
    var dataView = rowData[column];
    
    if (dataView)
    {
        [dataView removeFromSuperview];
        rowData[column] = nil;
    }
}

- (CPArray)_dataViewArrayForRow:(CPInteger)row
{
    var rowData = [_dataViews objectForKey:row];
    
    if (rowData == nil)
    {
        rowData = [CPArray arrayWithCapacity:[_tableView numberOfColumns]];
        [_dataViews setObject:rowData forKey:row];
    }
        
    return rowData;
}

- (CPArray)_objectValueArrayForRow:(CPInteger)row
{
    var rowData = [_objectValues objectForKey:row];
    
    if (rowData == nil)
    {
        rowData = [CPArray arrayWithCapacity:[_tableView numberOfColumns]];
        [_objectValues setObject:rowData forKey:row];
    }
        
    return rowData;
}

- (void)_resetVisibleRowsAndColumns
{
    var visibleRect = [_tableView visibleRect];
    
    _visibleRows = [CPIndexSet indexSetWithIndexesInRange:[_tableView rowsInRect:visibleRect]];
    _visibleColumns = [_tableView columnIndexesInRect:visibleRect];
}

@end
