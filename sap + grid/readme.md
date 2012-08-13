# Sweep And Prune (SAP) + Grid

## Usage

**This module depends on sweepandprune.lua. Just place them in the same folder.**

SAP + grid shares the same methods with the stand alone SAP so see it's readme for documentation and examples. However, there is one small difference.

1. The default cell size is 100 by 100 when creating a new instance. You can choose your own cell size by giving the cell width and height as arguments. Each cell should be at least as large as the area of the average object. You can get away with a large cell size (2 to 4 times the size of your average object is a good place to start). You're free to determine the optimum cell size for your use.

	Example:
	
	````lua
	sapgrid		= require 'sapgrid'
	sapgridA	= sapgrid(100,200) -- new instance with cell width (100) along the x-axis and cell height (200) along the y-axis
	
	-- You can change the cell width and height at any time:
	sapgridA.width = 300
	sapgridA.height = 300
	````