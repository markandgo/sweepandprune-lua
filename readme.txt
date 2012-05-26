Sweep and prune (SAP) algorithm in Lua

Sweep and prune is a broad phase collision pruning/detection algorithm, which reduces the number of object pairs that need to be checked for collision

Based on:

Efficient Large-Scale Sweep and Prune Methods with AABB Insertion and Removal
	by: Tracy, Buss, Woods

I-Collide
	by: Cohen, Lin, Manocha, Ponamgi
	
The SAP implementation outlined hereof provides incremental results and
is persistent.

There are two versions one can use:
- Stand alone SAP
- SAP with the grid

If you don't know which one to choose, use the stand alone SAP. If you feel that it doesn't 
run as fast as you want it to, try SAP w/ grid as it can scale better with faster objects.