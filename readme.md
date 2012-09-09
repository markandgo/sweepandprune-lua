# Sweep And Prune

2D Sweep and prune (SAP) algorithm in Lua

## About

Sweep and prune is a broad phase collision pruning/detection algorithm, which reduces the number of object pairs that need to be checked for collision.

This implementation of sweep and prune takes advantage of temporal coherence. Collision pairs and the list of intervals for each axis are saved between each update check. Insertion sort is used on each list, and collision pairs are updated when swapping intervals. This reduces the amount of work done for each update when there are many static objects.

There are two versions one can use:

*	Stand alone SAP
*	SAP with spatial subdivision (grid)

Sap w/ grid is an experimental version of the stand alone SAP. It should scale well with objects that change their relative positions a lot between updates.

The theory is this:

The world is divided into "cells", and each cell has its own SAP instance. Objects register with each cell that they touch with their bounding boxes. Less sorting is needed per sap because far away objects do not affect its interval lists.

Check out the LOVE (+0.7.2) demo: [Download] (https://github.com/downloads/markandgo/sweepandprune-lua/sapDemo1.3a.love)

Also check out the main.lua example in the repo.

## Resource

Based on the following papers:

*	Efficient Large-Scale Sweep and Prune Methods with AABB Insertion and Removal  
	by: Tracy, Buss, Woods
*	I-Collide  
	by: Cohen, Lin, Manocha, Ponamgi
*	Box Casting: A Fast Broad Phase for Dynamic Collision Detection
	by: Coumans,Bergen
*	A Fast Voxel Traversal Algorithm for Ray Tracing
	by: Amanatides,Woo