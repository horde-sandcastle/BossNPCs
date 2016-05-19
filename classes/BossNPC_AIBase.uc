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

var Area combatZone; // only targets inside this area are considered

//// local state vars,  ATTENTION: NEVER EVER USE STATE SCOPED VARIABLES!!!! (crashes game)
// used for task state
var float moveOffset;

var vector tmpDest;
var float lastStuckCheck;
var vector lastStuckLoc;

var float comb_dist;
var Vector comb_dirToTarget;
var float comb_targetAngle;
var bool comb_doAttack;

var float returnedCooldown;
var name currseq;

var float stun_beginTime;
var bool stun_receivedHit;

//// state vars send

// default: true, denotes if NPC should automatically search for targets and attack
// if false, the cyclops only attacks after being attacked
var() bool autoAggro;
// default: false, if true the nearest enemy pawns is picked as a new target instead of visible pawns
var() bool perfectEnemyKnowledge;
var() DIFFICULTY_MODE difficulty;

`include(Stocks)
`include(Log)
`include(PawnUtils)

event PreBeginPlay() {
	super.PreBeginPlay();
	combatZone = new class'Area';
	// overwrite to set possible area coordinates
}

event Possess(Pawn inPawn, bool bVehicleTransition) {
	super.Possess(inPawn, bVehicleTransition);
	getAllTasks();
    m_Pawn = BossNPC_PawnBase(inPawn);
    m_Pawn.SetMovementPhysics();
    self.SetTickIsDisabled(false);

	setDifficulty(SandcastleGame(worldinfo.Game).difficultyLvl == LVL_HARD ? EDM_HARD : EDM_NORMAL);

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

	if (!combatZone.isInside(targetPawn.location))
		return false;

	dist = VSize(targetPawn.Location - m_Pawn.Location);

	if (dist > m_NoticeRadius) {
		if (noticeOnly)
			return false;

		if (dist > m_SeeRadius || !self.CanSee(targetPawn))
			return false;
	}

	//return self.ActorReachable(targetPawn);
	return autoAggro;
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

    if (isBusyWithTask()) {
		if (isInState('idle')) // task was interrupted
			GotoState('DoingTask');
    }
    else
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
        if (m_pawn.isStrongHit(damage, SandcastlePawn(InstigatedBy.pawn)))
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
	FinishRotation();
	// ends the state to do the task when arrived
	DoTask();

	moveOffset = activeTask.npcInReach > 200.f ? activeTask.npcInReach - 200.f : 20.f;
    m_Pawn.m_IsSprinting = activeTask.sprint;
	MoveToward(activeTask, ,moveOffset);
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
    FinishRotation();
    MoveTo(m_Pawn.Location + m_WanderDirection * m_Pawn.GetMoveSpeed());

    goto 'Begin';
}

const STUCK_CHECK_DELAY = 3;
const STUCK_MOVE_THRESHOLD = 2500.0; // 50*50 because we check the squared distance

state Chasing {

    event EndState(Name NextStateName) {
        m_Pawn.Acceleration = Vec3(0, 0, 0);
        m_Pawn.m_IsSprinting = false;
    }

	// straight path or navmesh fail -> false, true if navmesh path is found
    function bool useNavmesh() {
        local float dist;
        local bool foundPath;

        dist = VSize2D(m_CombatTarget.Location - m_Pawn.Location);
		if (dist > m_CombatChaseSprintDistance) {
            m_Pawn.m_IsSprinting = true;
        }

        if (m_CombatTarget != none && dist > m_CombatChaseEndDistance && !NavigationHandle.ActorReachable(m_CombatTarget)) {
			if (!FindNavMeshPath()) {
				 m_CombatTarget = none;
				 gotostate('Idle');
			}
			else if (!m_Pawn.ReachedDestination(m_CombatTarget))
				foundPath = true;
        }

        return foundPath;
    }

    // Function to grab the appropriate A* path to travese to get to the goal.
	function bool FindNavMeshPath() {
		NavigationHandle.ClearConstraints();
		// Set New Constraints
		class'NavMeshPath_Toward'.static.TowardGoal(NavigationHandle, m_CombatTarget);
		class'NavMeshGoal_At'.static.AtActor(NavigationHandle, m_CombatTarget, 100, true);

		return NavigationHandle.FindPath();
	}

	// we got close enough to directly move towards the target, so continue to check if this still holds
	function bool approachDirectly() {
		local float dist;
		local bool isStuck;

		if (worldinfo.timeSeconds - lastStuckCheck > STUCK_CHECK_DELAY) {
			lastStuckCheck = worldinfo.timeSeconds;
			isStuck = VSizeSq(lastStuckLoc - m_pawn.location) < STUCK_MOVE_THRESHOLD;
			lastStuckLoc = m_pawn.location;
		}

		SetFocalPoint(m_CombatTarget.Location + Vect(0,0,1) * (m_Pawn.BaseEyeHeight));
		dist = VSize2D(m_CombatTarget.Location - m_Pawn.Location);

		return dist > m_CombatChaseEndDistance / 1.2 && !isStuck;
    }

Begin:
    if (m_CombatTarget != none) {
        RotateTo (Normal2D(m_CombatTarget.Location - m_Pawn.Location));
        FinishRotation();

        NavigationHandle.SetFinalDestination(m_CombatTarget.Location);

        while (useNavmesh() && NavigationHandle.GetNextMoveLocation(tmpDest, m_Pawn.GetCollisionRadius())) {
            SetFocalPoint(tmpDest + Vect(0,0,1) * (m_Pawn.BaseEyeHeight));
			if (!NavigationHandle.SuggestMovePreparation(tmpDest,self)) {
				MoveTo(tmpDest);
			}
			else
				sleep(0.2);
        }

        // move the last bit directly towards target
        lastStuckLoc = vec3(0,0,0);
        while (approachDirectly())
	    	MoveToward(m_CombatTarget, m_CombatTarget, m_CombatChaseEndDistance / 3);

		if (m_CombatTarget != none)
        	GotoState('Combating');
        else
            GotoState('Idle');
    }
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

Begin:
    if (m_CombatTarget != none) {
        GetPawnRelations(m_pawn, m_CombatTarget, comb_targetAngle, comb_dirToTarget, comb_dist);

        if (Rand(11) < 1 && restrictedAttack == noRestrictedAttack) {
        	comb_doAttack = true; // we may need to check cansee taget here
        }
        else {
            comb_doAttack = comb_dist <= m_CombatChaseEndDistance;
        }

        if (comb_doAttack) {
	        TurnToTarget(comb_targetAngle);
	        FinishRotation();
		    if (m_CombatCanAttack) {
		    	GotoState('Attacking');
		    }
        }
        else
            GotoState('Chasing');
    }

	sleep(0.1);
goto 'Begin';
}

state Attacking {

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

function ResetAttack() {
	m_CombatCanAttack = true;
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
    }

    PopState();
}

const DEFAULT_STUN_DURATION = 10;

state Stunned {

	function bool ContinueStun() {
        return worldinfo.TimeSeconds - stun_beginTime < DEFAULT_STUN_DURATION && !stun_receivedHit;
    }

	function bool BeginStunSequence() { return false;}
    function playIdleStun();
    function EndStunSequence();
    function receivedCriticalHit() {
        stun_receivedHit = true;
    }

Begin:
	stun_beginTime = worldinfo.TimeSeconds;
	m_pawn.acceleration = vect(0,0,0);

	if (BeginStunSequence()) {
	    FinishAnim(m_Pawn.m_CustomAnimSequence);
	    while (ContinueStun()) {
	    	playIdleStun();
	    	FinishAnim(m_Pawn.m_CustomAnimSequence);
	    }
	    EndStunSequence();
	    FinishAnim(m_Pawn.m_CustomAnimSequence);
	    m_NextHitDelay = RandRange(HIT_DEALY_MIN, HIT_DELAY_MAX);
	    autoAggro = true;
	}

goto('Finished');

Finished:
    GotoState('Idle');
}

function receivedCriticalHit() {}

function PawnDiedEvent(Controller Killer, class<DamageType> DamageType) {
	PlaySound(SoundCue'BossNPCs_Content.cyclops_death_Cue');
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
