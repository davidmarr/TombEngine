#pragma once

// This file is used for documentation of LevelVars.

/// A table with level-specific data which will be saved and loaded.
// @specialtable LevelVars
// This is for level-specific information that you want to store in saved games.
// For example, you may have a level with a custom puzzle where Lara has to kill exactly seven enemies to open a door to a secret. You could use the following line each time an enemy is killed:
// 	LevelVars.enemiesKilled = LevelVars.enemiesKilled + 1
// If the player saves the level after killing three, saves, and then reloads the save
// some time later, the values `3` will be put back into `LevelVars.enemiesKilled.`
// 
// In LevelVars, you can only save certain types of variables:
// 
// - number (integers and floats)
// - boolean (true and false)
// - @{string} (text)
// - @{table} (tables containing any of these types, including nested tables)
// - @{Vec2} (2D vectors)
// - @{Vec3} (3D vectors)
// - @{Rotation} (rotation values)
// - @{Time} (time values)
// - @{Color} (color values)
//
// If you try to save a variable of an unsupported type (like a function or userdata), an error will be raised when you attempt to save the game.
// 
// __This table is emptied when a level is finished.__ If the player needs to be able
// to return to the level (like in the Karnak and Alexandria levels in *The Last Revelation*),
// you will need to use the @{GameVars} table, below.
//
// __*LevelVars.Engine*__ is a reserved table used internally by TombEngine's libs. __Do not modify, overwrite, or add to it.__
//