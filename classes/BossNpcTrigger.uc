/**
* Because touch events are ignored for Boss Npc Pawns in other tiggers.
*/

class BossNpcTrigger extends DynamicTriggerVolume
  placeable;

`include(Log)

/** Called when pawn touches the volume
 */
simulated event Touch(Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal){
  super.Touch(Other, OtherComp, HitLocation, HitNormal);
  if (BossNPC_PawnBase(Other) != none) {
    UpdateEvents(BossNPC_PawnBase(Other));
  }
}

function UpdateEvents(BossNPC_PawnBase Pawn) {
  local int i;
  local SeqEvent_NpcVolumeTouch TouchEvent;

  // get all events this volume has
  for(i = 0; i < GeneratedEvents.Length; i++) {
    if (SeqEvent_NpcVolumeTouch(GeneratedEvents[i]) == none)
      continue;
    TouchEvent = SeqEvent_NpcVolumeTouch(GeneratedEvents[i]);
    TouchEvent.SetTouchPawn(Pawn);
  }
}

DefaultProperties
{
  BrushColor = (B=128, G=255, R=128, A=255)
  bColored = true
  bStatic = false

  // Attach our output events
  SupportedEvents(0)=Class'SeqEvent_NpcVolumeTouch'
}
