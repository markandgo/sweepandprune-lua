How to use:

-- Load the SAP library
sap = require 'sweepandprune'

-- Create a new SAP instance
sapA = sap()

-- Add a new axis aligned bounding box (AABB) with the given ID where x0 <= x1 and y0 <= y1 and returns the ID,
id = sapA:add(id,x0,y0,x1,y1)

-- Update the position of the AABB in the SAP instance
sapA:move(id,x0,y0,x1,y1)

-- Delete the AABB for the given ID. This method has priority over add and move for each update
sapA:delete(id)

-- Perform the "sweep and prune" aka update the SAP instance. Note that the other methods are 'buffered' until update is called.
sapA:update()

-- Query and returns a list of all AABB's that intersect for the given ID
list = sapA:query(id)

for otherID,otherID in pairs(list) do
	exampleFunc(otherID,id)
end