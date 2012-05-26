How to use:

-- Load the SAP + Grid library
sapgrid = require 'sapgrid'

-- Create a new instance with the given cell width and height
-- Recommended cell size to be at least as big as the average size of objects
sapgridA = sapgrid(cell_width,cell_height)

-- Add a new axis aligned bounding box (AABB) with the given ID where x0 <= x1 and y0 <= y1 and returns the ID,
id = sapgridA:add(id,x0,y0,x1,y1)

-- Update the position of the AABB in the SAP instance
-- Due to limitations, only call this method once before each update
sapgridA:move(id,x0,y0,x1,y1)

-- Delete the AABB for the given ID. This method has priority over add and move for each update
sapgridA:delete(id)

-- Update all SAP instances in every active cell. Note that the other methods are 'buffered' until update is called.
sapgridA:update()

-- Query and returns a list of all AABB's that intersect for the given ID
list = sapgridA:query(id)

for otherID,otherID in pairs(list) do
	exampleFunc(otherID,id)
end