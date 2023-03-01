#pragma once

struct CollisionInfo;
struct ItemInfo;

void InitialiseRobotClaw(short itemNumber);
void RobotClawCollision(short itemNumber, ItemInfo* l, CollisionInfo* coll);
void RobotClawControl(short itemNumber);