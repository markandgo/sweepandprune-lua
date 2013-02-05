# Sweep And Prune (SAP)

## Usage

Load the SAP library.

`sap = require 'sap'`

---
Create a new SAP instance. Your SAP instance is your "world" where you place your axis aligned bounding boxes (AABB).

`sapA = sap()`

## Functions

Add a new AABB with the given ID where `x0`,`y0` is the top left corner and `x1`,`y1` is the bottom right corner and return the ID. The ID can be any Lua value (except `nil`).

`id = sapA:add(id,x0,y0,x1,y1)`

---
Update the position of the AABB for the given ID.

`sapA:move(id,x0,y0,x1,y1)`

---
Mark the AABB for deletion on the next update. Calling `add` for the same ID overrides deletion.

`sapA:delete(id)`

---
Update overlapping pairs in the SAP instance from `add`,`move`, or `delete` calls.

`sapA:update()`

---
Query and return a list of all AABB's overlaping with the given ID.

````lua 
list = sapA:query(id)

for otherID,otherID in pairs(list) do
	...
end
````

## Example:

**See main.lua for more examples...**

````lua
sap 	= require 'sweepandprune'
sapA 	= sap()

-- add two objects and their AABB's to our instance
obj1	= sapA:add({},0,0,2,2)
obj2	= sapA:add({},0,0,3,3)

-- update object 2's AABB
sapA:move(obj2,1,1,3,3)
sapA:update() -- update our instance

-- return the list of intersected objects for object 1
intersects = sapA:query(obj1)

-- we have an intersection!
print(intersects[obj2]) --> obj2

-- delete object 2 from our instance
sapA:delete(obj2)
sapA:update()

-- check object 1 again
intersects = sapA:query(obj1)

-- object 1 is no longer intersecting object 2
print(intersects[obj2]) --> nil
````