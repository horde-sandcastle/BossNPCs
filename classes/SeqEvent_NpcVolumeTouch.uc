/**
*
* Kismet event for when volume gets touched.
*/
class SeqEvent_NpcVolumeTouch extends SequenceEvent;

`include(Log)

function SetTouchPawn(BossNPC_PawnBase Pawn) {
	local array<int> ActivateIndices;
	ActivateIndices[0] = 0;
	SeqVar_Object(VariableLinks[0].LinkedVariables[0]).SetObjectValue(Pawn);
	CheckActivate(Originator, None, false, ActivateIndices);
}

DefaultProperties
{
	OutputLinks(0) = (LinkDesc="Touch")

	VariableLinks(0)=(ExpectedType=class'SeqVar_Object',LinkDesc="Output Pawn",PropertyName=TargetPawns,MinVars=1,MaxVars=1,bWriteable=true)

	ObjName = "Boss NPC Volume Touch"
	ObjCategory = "Custom Nodes"
	bPlayerOnly = false
}
