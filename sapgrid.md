# Sweep And Prune (SAP) + Grid

Using the grid combined with the sap method should theoretically yield faster performance when many objects have low temporal coherence. Each cell in the grid has its own sap instance which manages objects that touches the cell.

Internally, the module only updates the active cells in the grid. This is useful when parts of the grid is mostly idle and constant. The module also cleans up and reuses empty sap instances to reduce table creation.

## Usage

**This module depends on sweepandprune.lua. Just place them in the same folder.**

SAP + grid shares the same methods with the stand alone SAP so see it's readme for documentation and examples.

---
Create a new SAP+grid instance. The `cell_width`,and `cell_height` parameters are optional.

````lua
sapgrid = require'sapgrid'
sapA    = sapgrid([,cell_width [,cell_height]])
````

## Properties

The cell width (default is `100`):

`sapA.width`

---
The cell height (default is `100`:

`sapA.height`

## Functions

Draw the cells in LOVE. Top number is the cell coordinates, and bottom number is the amount of objects/cell:

`sapA:draw()`

## Example:
	
````lua
sapgrid		= require 'sapgrid'
sapgridA	= sapgrid(100,200) -- new instance with cell width (100) along the x-axis and cell height (200) along the y-axis

-- You can change the cell width and height at any time:
sapgridA.width  = 300
sapgridA.height = 300
````