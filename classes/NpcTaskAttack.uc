/**
* Tells the npc to attack where this task is placed.
*/
class NpcTaskAttack extends NpcTask
placeable;

var() byte restrictedAttack;

defaultproperties
{
	restrictedAttack = 255;
}
