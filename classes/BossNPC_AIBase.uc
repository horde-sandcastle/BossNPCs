class BossNPC_AIBase extends AIController;

enum DIFFICULTY_MODE {
	EDM_NORMAL,
	EDM_HARD
};

var PrivateWrite BossNPC_PawnBase m_Pawn;

var Vector2D m_WanderDelay;
var Vector2D m_WanderDuration;

var float    m_WanderStartDelay;
var float    m_WanderRemainingTime;
var Vector   m_WanderDirection;

var float m_SeeRadius;
var float m_NoticeRadius;

var Pawn  m_CombatTarget;
var float m_CombatTargetSearchDelay;
var float m_CombatTargetResetDelay;

var bool  m_CombatCanAttack;
// if restrictedAttack is always active set to true
// otherwise restrictedAttack is reset to noRestrictedAttack 255 (= -1) after the attack
var bool  isAttackRestricted;
var byte  restrictedAttack;

var float m_CombatChaseEndDistance;
var float m_CombatChaseSprintDistance;

var float m_HitAngle;
var float m_NextHitDelay;

var bool m_Dead;

var NpcTask activeTask;
var array<NpcTask> allTasks;
var float taskCheckInterval;
var float lastTastCheck;
var const byte noRestrictedAttack;
// default: true, denotes if NPC should automatically search for targets and attack
// if false, the cyclops only attacks after being attacked
var() bool autoAggro;
// default: false, if true the nearest enemy pawns is picked as a new target instead of visible pawns
var() bool perfectEnemyKnowledge;
var() DIFFICULTY_MODE difficulty;

`include(Stocks)
`include(Log)
`include(PawnUtils)

event Possess(Pawn inPawn, bool bVehicleTransition) {
	super.Possess(inPawn, bVehicleTransition);
	getAllTasks();
    m_Pawn = BossNPC_PawnBase(inPawn);
    m_Pawn.SetMovementPhysics();
    self.SetTickIsDisabled(false);
	setDifficulty(difficulty);

    GotoState('Idle',, true, false);
}

function setDifficulty(DIFFICULTY_MODE df) {
	difficulty = df;
	m_Pawn.difficulty = df;
}

function RotateTo(Vector Dir) {
    self.SetFocalPoint(m_Pawn.Location + Dir * 1000);
    m_Pawn.SetDesiredRotation(Rotator(Dir));
}

function bool IsValidCombatTarget(Pawn targetPawn, bool noticeOnly) {
	local float dist;

	if (!IsValidTarget(targetPawn, m_pawn))
		return false;

	dist = VSize(targetPawn.Location - m_Pawn.Location);

	if (dist > m_NoticeRadius) {
		if (noticeOnly)
			return false;

		if (dist > m_SeeRadius || !self.CanSee(targetPawn))
			return false;
	}

	//return self.ActorReachable(targetPawn);
	if(!autoAggro) return false;
	return true;
}

function Pawn FindCombatTarget() {
    local WorldInfo world;
    local Pawn targetPawn;
    local array<Pawn> targets;

    world = class'WorldInfo'.static.GetWorldInfo();

	if(perfectEnemyKnowledge) {
		foreach world.AllPawns(class'Pawn', targetPawn) {
	        if (IsValidCombatTarget(targetPawn, false))
	            targets.addItem(targetPawn);
	    }
	    return findClosestPawn(targets);
	}
	else {
		foreach world.VisibleActors(class'Pawn', targetPawn, m_Pawn.SightRadius, m_Pawn.Location) {
	        if (IsValidCombatTarget(targetPawn, false))
	            return targetPawn;
	    }
	}

    return none;
}

function Pawn FindClosestVisibleCombatTarget(bool noticeOnly) {
    local WorldInfo world;
    local array<Pawn> targetPawns;
    local Pawn targetPawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    foreach world.VisibleActors(class'Pawn', targetPawn, m_Pawn.SightRadius, m_Pawn.Location) {
        if (IsValidCombatTarget(targetPawn, noticeOnly))
			targetPawns.addItem(targetPawn);
    }

    return findClosestPawn(targetPawns, 999999999);
}

function Pawn findClosestPawn(array<Pawn> pawns, optional float minDist = -1) {
	local Pawn currentPawn;
	local Pawn closestPawn;
	local float dist;

	foreach pawns(currentPawn) {
        dist = VSizeSq(currentPawn.Location - m_Pawn.Location);
        if (minDist <= 0 || dist < minDist) {
            closestPawn = currentPawn;
            minDist = dist;
        }
    }

    return closestPawn;
}

event Tick(float DeltaTime) {
    if (m_Dead) {
        return;
    }
    super.Tick(DeltaTime);

    if(!isBusyWithTask())
    	manageCombatTarget(DeltaTime);
}


/**
* If there is an NpcTask to complete or in progress returns true
*/
function bool isBusyWithTask() {
	if (activeTask != none) return true;
	else if (!autoAggro) return false;
	else if (StateAllowsSwitchToTask() && worldinfo.TimeSeconds - lastTastCheck > taskCheckInterval) {
		lastTastCheck = worldinfo.TimeSeconds;
		activeTask = checkForTask();
		if( activeTask != none ) {
			GotoState('DoingTask');
			return true;
		}
		return false;
	}
	else return false;
}

function bool StateAllowsSwitchToTask() {
     return true;
}

function NpcTask checkForTask() {
	local NpcTask task;
	foreach allTasks(task) {
		if(task.hasPriority(self))
			return task;
	}

	return none;
}

function getAllTasks() {
	local NpcTask task;
	foreach DynamicActors(class'NpcTask', task) {
		allTasks.addItem(task);
	}
}

// during an attack the countdown is paused
// needs to be fairly small delay, because target might teleport out of range suddenly
const TARGET_RESET_DELAY_MIN = 5;
const TARGET_RESET_DELAY_MAX = 8;

/**
* Executed each tick if not busy
*/
function manageCombatTarget(float DeltaTime) {
	local Pawn otherTarget;

    if (m_NextHitDelay > 0)
        m_NextHitDelay -= DeltaTime;

    if (m_CombatTarget == none || !IsValidCombatTarget(m_CombatTarget, false)) {
        m_CombatTargetSearchDelay -= DeltaTime;

        if (m_CombatTargetSearchDelay <= 0) {
        	m_CombatTargetSearchDelay = 0.5;
            otherTarget = FindCombatTarget();

            if (m_CombatTarget != otherTarget) {
                m_CombatTarget = otherTarget;
                CombatTargetChanged();
            }
        }
    }
    else if (!IsInState('Attacking', true)) {
		m_CombatTargetResetDelay -= DeltaTime;
        if (m_CombatTargetResetDelay <= 0) {
        	m_CombatTargetResetDelay = RandRange(TARGET_RESET_DELAY_MIN, TARGET_RESET_DELAY_MAX);
            otherTarget = self.FindClosestVisibleCombatTarget(true);
            if (otherTarget != none
            	&& otherTarget != m_CombatTarget
            	&& VSize2D(otherTarget.Location - m_Pawn.Location) < VSize2D(m_CombatTarget.Location - m_Pawn.Location)) {
                m_CombatTarget = otherTarget;
                CombatTargetChanged();
            }
        }
    }
}

/**
* Does not interrupt states like attacking or hit
* because gotoState only executes when the state code
* continues execution, i.e. the latent function finished.
*/
function CombatTargetChanged() {
	if (m_CombatTarget == none)
    	GotoState('Idle');
}

function NotifyTakeHit(Controller InstigatedBy, vector HitLocation, int Damage, class<DamageType> damageType, vector Momentum) {
    local Vector dirToTarget;
    local float targetAngle;
    super.NotifyTakeHit(InstigatedBy, HitLocation, Damage, damageType, Momentum);

    if (m_Dead || IsInState('Stunned', true))
        return;

    dirToTarget = Normal(m_Pawn.Location - HitLocation);
    targetAngle = NOZDot(Vector(m_Pawn.Rotation), dirToTarget);

    m_HitAngle = Acos(targetAngle) * (dirToTarget.X < 0 ? -1 : +1) * 57.295776;

    if (m_NextHitDelay <= 0) {
        if (m_pawn.isStrongHit(damage))
            GoToState('Stunned');
        else
        	PushState('Hit');
    }
}

state DoingTask {
	event EndState(Name NextStateName) {m_Pawn.m_IsSprinting = false;}

    function DoTask() {
		if (NpcTaskAttack(activeTask) != none && taskInReach()) {
			activeTask.triggerKismetEvent(self);
			restrictedAttack = NpcTaskAttack(activeTask).restrictedAttack;
		    GotoState('Attacking');
		}
    }

	function bool taskInReach() {
		return (vSizeSq(m_Pawn.location - activeTask.location) < activeTask.npcInReach ** 2);
	}

Begin:
	if (activeTask == none || activeTask.isCompleted) {
		activeTask = none;
		GotoState('Idle');
	}

	RotateTo(activeTask.location - m_Pawn.location);
	// ends the state to do the task when arrived
	DoTask();

    m_Pawn.m_IsSprinting = activeTask.sprint;
	MoveToward(activeTask, , 150);
	sleep(0.5);
goto 'Begin';
}

auto state Idle {
    event BeginState(Name PreviousStateName) {
        m_Pawn.m_IsInCombat = false;
        m_CombatTarget = none;
    }

    event Tick(float DeltaTime) {
        global.Tick(DeltaTime);

        if (m_CombatTarget == none && activeTask == none) {
	            m_WanderStartDelay -= DeltaTime;
	        if (m_WanderStartDelay <= 0)
	            GotoState('Wandering');
        }
    }

	function CombatTargetChanged() {
		if (m_CombatTarget != none)
	    	GotoState('Combating');
    	else
            global.CombatTargetChanged();
	}
}

state Wandering {
	event BeginState(Name PreviousStateName) {
		m_WanderRemainingTime = RandRange(m_WanderDuration.X, m_WanderDuration.Y);
		m_WanderDirection = RandGroundDirection();
	}

	event EndState(Name NextStateName) {
        m_Pawn.Acceleration = Vec3(0, 0, 0);
		m_WanderStartDelay = RandRange(m_WanderDelay.X, m_WanderDelay.Y);
	}

	event Tick(float DeltaTime) {
        global.Tick(DeltaTime);

        if (m_CombatTarget == none && activeTask == none) {
	            m_WanderRemainingTime -= DeltaTime;
		    if (m_WanderRemainingTime <= 0)
		        GotoState('Idle');
        }
	}

    function CombatTargetChanged() {
        if (m_CombatTarget != none)
        	GotoState('Combating');
        else
            global.CombatTargetChanged();
    }

Begin:
    RotateTo(m_WanderDirection);
    MoveTo(m_Pawn.Location + m_WanderDirection * m_Pawn.GetMoveSpeed());

    goto 'Begin';
}

state Combating {
    event BeginState(Name PreviousStateName) {
        m_Pawn.m_IsInCombat = true;
    }

    event EndState(Name NextStateName) {}

    function TurnToTarget(float angle) {
        if (Abs(angle) > 15) {
	        RotateTo(Normal2D(m_CombatTarget.Location - m_Pawn.Location));
        }
    }

    event Tick(float DeltaTime) {
        local float dist;
        local Vector dirToTarget;
        local float targetAngle;
        local bool doAttack;

        global.Tick(DeltaTime);

        if (m_CombatTarget != none) {
            if(Rand(11) < 1 && restrictedAttack == noRestrictedAttack) {
            	doAttack = true; // we may need to check cansee taget here
            }
            else {
                dist = VSize2D(m_CombatTarget.Location - m_Pawn.Location);
                doAttack = dist <= m_CombatChaseEndDistance;
            }

            if (doAttack) {
                dirToTarget = Normal2D(m_CombatTarget.Location - m_Pawn.Location);
		        targetAngle = NOZDot(Vector(m_Pawn.Rotation), dirToTarget);
		        TurnToTarget(Acos(targetAngle) * (dirToTarget.X < 0 ? -1 : +1) * 57.295776);

			    if (m_CombatCanAttack) {
			    	GotoState('Attacking');
			    }
            }
            else
                GotoState('Chasing');
        }
    }
}

state Chasing {
    local float dist;

    event EndState(Name NextStateName) {
        m_Pawn.Acceleration = Vec3(0, 0, 0);

        m_Pawn.m_IsSprinting = false;
    }

Begin:
    while (m_CombatTarget != none) {
	    dist = VSize2D(m_CombatTarget.Location - m_Pawn.Location);

        if (dist > m_CombatChaseSprintDistance) {
            m_Pawn.m_IsSprinting = true;
        }

        RotateTo( Normal2D(m_CombatTarget.Location - m_Pawn.Location));
        MoveToward(m_CombatTarget,, m_CombatChaseEndDistance / 3);

        if (dist <= m_CombatChaseEndDistance) {
            GotoState('Combating');
            break;
        }
    }
}

const HIT_DEALY_MIN = 10;
const HIT_DELAY_MAX = 15;

state Hit {
    function bool BeginHitSequence(float angle){
        return false;
    }

Begin:
	m_pawn.acceleration = vect(0,0,0);
    FinishRotation();

    if (BeginHitSequence(m_HitAngle)) {
        FinishAnim(m_Pawn.m_CustomAnimSequence);
        m_NextHitDelay = RandRange(HIT_DEALY_MIN, HIT_DELAY_MAX);
        autoAggro = true;
        if (difficulty == EDM_NORMAL) {

        }
    }

    PopState();
}

state Stunned {
	local float beginTime;
	local float stunDurationSec;

	function bool BeginStunSequence(out float stunDuration) {
		stunDurationSec = stunDuration;
        return false;
    }

    function playIdleStun(){}
    function EndStunSequence();

Begin:
	beginTime = worldinfo.TimeSeconds;
	m_pawn.acceleration = vect(0,0,0);

    if (BeginStunSequence(stunDurationSec)) {
        FinishAnim(m_Pawn.m_CustomAnimSequence);
        while (worldinfo.TimeSeconds - beginTime < stunDurationSec) {
        	playIdleStun();
        	FinishAnim(m_Pawn.m_CustomAnimSequence);
        }
        EndStunSequence();
        FinishAnim(m_Pawn.m_CustomAnimSequence);
        m_NextHitDelay = RandRange(HIT_DEALY_MIN, HIT_DELAY_MAX);
        autoAggro = true;
    }

    GotoState('Idle');
}

function ResetAttack()
{
	m_CombatCanAttack = true;
}

state Attacking {
    local float returnedCooldown;
    local name currseq;

    event EndState(Name NextStateName) {
        if( !isAttackRestricted )
        	restrictedAttack = noRestrictedAttack;
    }

	/**
	* To be overwritten by subclasses to decide on the boss specific attack
	*/
    function bool DecideAttack(out float Cooldown, out name seq) {
        Cooldown = -1;
        return false;
    }

Begin:
    FinishRotation();

    if (DecideAttack(returnedCooldown, currseq)) {
        m_Pawn.PlayCustomAnim(currseq, true);

        if (returnedCooldown > 0) {
            m_CombatCanAttack = false;
            SetTimer(returnedCooldown, false, 'ResetAttack');
        }

		FinishAnim(m_Pawn.m_CustomAnimSequence);
    }

    if (activeTask != none )
        GotoState('DoingTask');
    else if (m_CombatTarget != none)
        GotoState('Combating');
    else
        GotoState('Idle');
}

function PawnDiedEvent(Controller Killer, class<DamageType> DamageType) {
    m_Dead = true;
    SetTimer(6.0, false, '_Dead');
}

function _Dead() {
    self.Destroy();
}

defaultproperties
{
	difficulty = EDM_NORMAL
	autoAggro = true
	m_WanderDelay = (X=2, Y=6)
	m_WanderDuration = (X=2, Y=6)

    m_SeeRadius = 2000
    m_NoticeRadius = 500

	m_CombatCanAttack = true

	m_CombatChaseEndDistance = 400
	m_CombatChaseSprintDistance = 500

	taskCheckInterval = 2.f
	noRestrictedAttack = 255
	restrictedAttack = 255 // equals -1
}
