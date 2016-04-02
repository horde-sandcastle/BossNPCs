/**
* Custom Remote Event activated through NPC through NpcTask. 
* It's meaning depends on which subclass of NpcTask activates it.
* Custom events for special tasks need to extend from this. 
* Identified by name, which is set in the placed NpcTask. 
* Hence, this name must be equal to the name set to this event in Kismet.  
*/
class SeqEvent_NpcTask extends SeqEvent_RemoteEvent;

var BossNPC_AIBase npc;


event Activated()
{
	PopulateLinkedVariableValues();
}


defaultproperties
{
	ObjName="NpcTask Remote Event"
	VariableLinks(0)=(ExpectedType=class'SeqVar_Object',LinkDesc="npc",PropertyName=npc,bWriteable=true,MaxVars=1)
	
	ObjCategory="Custom Nodes"
	bAutoActivateOutputLinks=true
}