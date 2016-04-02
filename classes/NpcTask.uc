/**
* Subclasses are placed and configured in editor to command the npcs around. 
* Sepcific task events provide feedback in Kismet.
*/
class NpcTask extends Info
abstract;

// this task is ignored when completed
var() bool isCompleted;
// the npc is near enough to start working on the task
var() float npcInReach;
// should the npc sprint towards this task?
var() bool sprint;

// set this name to the Kismet NpcTask remote event
var() string eventName;

// defines when the npc should start doing the task
var() enum ETaskStartingPriority {
	TSP_Always, // do it asap!
	TSP_NoEnemies, // when no enemies are near
	TSP_Near // when the npc happens to be near enough (see vicinityDistance)
} TaskStartingPrio;

// defines when the npc is near enough to complete a task (requires TSP_Near)
var() float taskVicinityDistance;

// defines when the npc should stop doing the task, even though it is not yet completed
var() enum ETaskInterruptPriority { 
	TIP_Never, // do it until completion
	TIP_enemiesNear, // when enemies are near (see enemyVicinityDistance)
	TIP_AttackedMeleeOnly, // when the npc is attacked with a close combat weapon
	TIP_Attacked  // when the npc is attacked with any weapon
} TaskInterruptPrio;

// defines when an enemy is near enough for the npc to interrupt its task (requires TIP_NoNearEnemies)
var() float enemyVicinityDistance;

// overwrite this default props and the method 'setNpcTaskEventVars' for custom events if necessary
var class<SeqEvent_NpcTask> seqEventCls;

/**
* Notify Kismet about the status of the task
* The same event type can be used for different tasks (if not additional vars are required)
* because only events with a specific name are activated. 
*/
function triggerKismetEvent(BossNPC_AIBase npcAi) {
	local array<SequenceObject> AllSeqEvents;
	local Sequence GameSeq;
	local int i;
	local SeqEvent_NpcTask evt;

	GameSeq = WorldInfo.GetGameSequence();
	if (GameSeq != None && len(EventName) > 0) {
		GameSeq.FindSeqObjectsByClass(seqEventCls, true, AllSeqEvents);

		for (i = 0; i < AllSeqEvents.Length; i++) {
			evt = SeqEvent_NpcTask(AllSeqEvents[i]);
			if(string(evt.EventName) == EventName) {
				setNpcTaskEventVars(evt, npcAi);
				evt.CheckActivate(WorldInfo, self);
			}
		}
	}
}

/**
* Fills the variables of the Kismet event
*/
function setNpcTaskEventVars(SeqEvent_NpcTask evt, BossNPC_AIBase npcAi) {
	evt.npc = npcAi; 
}


defaultproperties
{
	TaskStartingPrio = TSP_NoEnemies 
	seqEventCls = class'SeqEvent_NpcTask'
	taskVicinityDistance = 600.f
	npcInReach = 300.f
}
