# Sweep And Prune (SAP) + Grid

Using the grid combined with the sap method should theoretically yield faster performance when many objects have low temporal coherence. Each cell in the grid has its own sap instance which manages objects that touches the cell.

Internally, the module only updates the active cells in the grid. This is useful when parts of the grid is mostly idle and constant. The module also cleans up and reuses empty sap instances to reduce table creation.

## Usage

**This module depends on sap.lua. Just place them in the same folder.**

SAP + grid shares the same methods with the stand alone SAP so see it's readme for documentation and examples.

---
Create a new SAP+grid instance. The `cell_width`,and `cell_height` parameters are optional. The cell width and height should be big enough to fit the average object for optimal performance.

````lua
sapgrid = require'sapgrid'
sapA    = sapgrid(cell_width,cell_height)
````

## Properties

The cell width:

`sapA.width`

---
The cell height:

`sapA.height`

## Internal Settings

The following properties are changeable in sapgrid.lua. Don't change them unless you know what you are doing!

---
`DEFAULT_CELL_WIDTH` is the default cell width for a new sapgrid instance.

---
`DEFAULT_CELL_HEIGHT` is the default cell height for a new sapgrid instance.

---
`MAX_POOL_SIZE` controls the max number of sap instances in the pool. Empty sap instances are placed in the pool instead of garbage collection. When a new grid cell is initialized, the cell reuses a sap in the pool instead of a new one. All sapgrid instances share the same pool.

## Functions

Draw the cells in LOVE. Top number is the cell coordinates, and bottom number is the amount of objects/cell:

`sapA:draw()`

---
Clear the pool. Call this function to clear it and allow garbage collection.

`sapA.clearPool()`

## Example:
	
````lua
sapgrid		= require 'sapgrid'
sapgridA	= sapgrid(100,200) -- new instance with cell width (100) along the x-axis and cell height (200) along the y-axis

-- You can change the cell width and height at any time:
sapgridA.width  = 300
sapgridA.height = 300
````