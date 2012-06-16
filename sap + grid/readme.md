# Sweep And Prune (SAP) + Grid

## Usage

SAP + grid shares the same methods with the stand alone SAP so see it's readme for documentation and examples. However, there are some small differences.

1. When creating a new instance, you have to specify your cell size. Each cell should be at least as large as the area of the average object. You can get away with a large cell size (2 to 4 times the size of your average object is a good place to start). You're free to determine the optimum cell size for your use.

	Example:
	
	````lua
	sapgrid		= require 'sapgrid'
	sapgridA	= sapgrid(100,200) -- new instance with cell width (100) along the x-axis and cell height (200) along the y-axis
	````

2. The last difference is that the move method should only be called once per ID before each update. This is due to how SAP is handled in each cell. Say that you move an object to another cell, the old cell would be scheduled to delete the object from its SAP instance in the next update. If you try to move the object back to the old cell before updating, you'll get an error because the object is pending deletion in the old cell.