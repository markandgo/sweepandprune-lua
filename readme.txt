2D Sweep and prune (SAP) algorithm in Lua

Sweep and prune is a broad phase collision pruning/detection algorithm, 
which reduces the number of object pairs that need to be checked for collision

Based on:

Efficient Large-Scale Sweep and Prune Methods with AABB Insertion and Removal
	by: Tracy, Buss, Woods

I-Collide
	by: Cohen, Lin, Manocha, Ponamgi

Important things to note:

The algorithm outlined hereof removes and adds collision pairs between each update when necessary.
It also remembers the sorted interval lists from previous updates to take advantage of temporal coherence.
	
There are two versions one can use:
- Stand alone SAP
- SAP with spatial subdivision (grid)

If you don't know which one to choose, try the stand alone SAP first.
Otherwise use SAP w/ grid as it works well with objects that move a lot between each update.