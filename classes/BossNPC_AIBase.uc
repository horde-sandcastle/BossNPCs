class BossNPC_AIBase extends AIController;

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

var float m_CombatWithoutAttackInterval;

var float m_HitAngle;
var float m_NextHitDelay;

var int   m_HitLockCount;

var bool  m_Dead;

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

`include(Stocks)
`include(Log)

event Possess(Pawn inPawn, bool bVehicleTransition)
{
	super.Possess(inPawn, bVehicleTransition);
	getAllTasks();
    m_Pawn = BossNPC_PawnBase(inPawn);

    m_Pawn.SetMovementPhysics();

    self.SetTickIsDisabled(false);

    GotoState('Idle',, true, false);
}

function RotateTo(Vector Dir)
{
    self.SetFocalPoint(m_Pawn.Location + Dir * 1000);

    m_Pawn.SetDesiredRotation(Rotator(Dir));
}

function bool IsValidTarget(Pawn targetPawn)
{
    if (targetPawn == m_Pawn)
        return false;

    if(isAgatha(targetPawn))
        return false;

    if (targetPawn.bTearOff || targetPawn.Health <= 0)
        return false;

    if (AOCPawn(targetPawn) != none && AOCPawn(targetPawn).bPawnIsDead)
        return false;

    return true;
}

function bool isAgatha(Actor Victim) {
	if (AOCPawn(Victim) != none && AOCPawn(Victim).PawnInfo.myFamily.FamilyFaction == EFAC_AGATHA )
		return true;

	return false;
}

function bool IsValidCombatTarget(Pawn targetPawn, bool noticeOnly)
{
	local float dist;

	if (!self.IsValidTarget(targetPawn))
		return false;

	dist = VSize(targetPawn.Location - m_Pawn.Location);

	if (dist > m_NoticeRadius)
	{
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

function Pawn FindClosestCombatTarget(bool noticeOnly) {
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

event Tick(float DeltaTime)
{
	super.Tick(DeltaTime);

    if (m_Dead)
        return;

    if(!isBusyWithTask())
    	manageCombatTarget(DeltaTime);
    else
        return;
}

/**
* If there is an NpcTask to complete or in progress returns true
*/
function bool isBusyWithTask() {
	if( activeTask != none ) return true;
	else if( !autoAggro) return false;
	else if (worldinfo.TimeSeconds - lastTastCheck < taskCheckInterval) return false;
	else {
		lastTastCheck = worldinfo.TimeSeconds;
		activeTask = checkForTask();
		if( activeTask != none ) {
			GotoState('DoingTask');
			return true;
		}
		return false;
	}
}

function NpcTask checkForTask() {
	local NpcTask task;
	foreach allTasks(task) {
		// TODO: consider prios here of NpcTask
		if( !task.isCompleted)
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

/**
* Executed each tick if not busy
*/
function manageCombatTarget(float DeltaTime) {
	local Pawn otherTarget;

    if (m_Pawn.m_IsInCombat)
        m_CombatWithoutAttackInterval += DeltaTime;

    if (m_NextHitDelay > 0)
        m_NextHitDelay -= DeltaTime;

    if (m_CombatTarget == none) {
            m_CombatTargetSearchDelay -= DeltaTime;
        if (m_CombatTargetSearchDelay <= 0) {
        	m_CombatTargetSearchDelay = 0.25;
            m_CombatTarget = FindCombatTarget();

            if (m_CombatTarget != none) {
                FoundCombatTarget();
            }
        }
    }
    else if (!IsValidCombatTarget(m_CombatTarget, false)) {
        m_CombatTarget = none;

        LostCombatTarget();
    }
    else {
        if (m_CombatWithoutAttackInterval > 5)
        {   m_CombatWithoutAttackInterval = 0;

	            m_CombatTargetResetDelay -= DeltaTime;
	        if (m_CombatTargetResetDelay <= 0)
	        {   m_CombatTargetResetDelay = RandRange(3, 6);

	            otherTarget = self.FindClosestCombatTarget(true);

	            if (otherTarget != none && otherTarget != m_CombatTarget
	            && VSize2D(otherTarget.Location - m_Pawn.Location) < VSize2D(m_CombatTarget.Location - m_Pawn.Location))
	            {
	                m_CombatTarget = otherTarget;
	            }
	        }
        }
    }
}

function FoundCombatTarget() { }
function LostCombatTarget() { }

function NotifyTakeHit(Controller InstigatedBy, vector HitLocation, int Damage, class<DamageType> damageType, vector Momentum)
{
    local Vector dirToTarget;
    local float targetAngle;
    super.NotifyTakeHit(InstigatedBy, HitLocation, Damage, damageType, Momentum);

    if (m_Dead)
        return;

    if (m_HitLockCount > 0)
        return;

    dirToTarget = Normal(m_Pawn.Location - HitLocation);
    targetAngle = NOZDot(Vector(m_Pawn.Rotation), dirToTarget);

    m_HitAngle = Acos(targetAngle) * (dirToTarget.X < 0 ? -1 : +1) * 57.295776;

    if (m_NextHitDelay <= 0) {
        PushState('Hit');
    }
}

state DoingTask
{
	event BeginState(Name PreviousStateName) {}

	event EndState(Name NextStateName) {m_Pawn.m_IsSprinting = false;}

    function DoTask() {
		if( NpcTaskAttack(activeTask) != none && taskInReach()) {
			activeTask.triggerKismetEvent(self);
			restrictedAttack = NpcTaskAttack(activeTask).restrictedAttack;
		    GotoState('Attacking');
		}
    }

	function bool taskInReach() {
		return (vSizeSq(m_Pawn.location - activeTask.location) < activeTask.npcInReach ** 2);
	}

Begin:
	if( activeTask == none || activeTask.isCompleted ) {
		activeTask = none;
		GotoState('Idle');
	}

	// ends the state to do the task when arrived
	DoTask();

    m_Pawn.m_IsSprinting = activeTask.sprint;
	RotateTo(activeTask.location - m_Pawn.location);
	MoveToward(activeTask, , activeTask.npcInReach - 150);
	sleep(0.5);
goto 'Begin';
}

state Idle
{
    event BeginState(Name PreviousStateName)
    {
        m_Pawn.m_IsInCombat = false;
    }

    event EndState(Name NextStateName)
    {
    }

    event Tick(float DeltaTime)
    {
        super.Tick(DeltaTime);

        if (m_CombatTarget == none && activeTask == none)
        {
	            m_WanderStartDelay -= DeltaTime;
	        if (m_WanderStartDelay <= 0)
	            GotoState('Wandering');
        }
    }

	function FoundCombatTarget()
	{
	    GotoState('Combating');
	}
}

state Wandering
{
	event BeginState(Name PreviousStateName)
	{
		m_WanderRemainingTime = RandRange(m_WanderDuration.X, m_WanderDuration.Y);
		m_WanderDirection = RandGroundDirection();
	}

	event EndState(Name NextStateName)
	{
        m_Pawn.Acceleration = Vec3(0, 0, 0);

		m_WanderStartDelay = RandRange(m_WanderDelay.X, m_WanderDelay.Y);
	}

	event Tick(float DeltaTime)
	{
        super.Tick(DeltaTime);

        if (m_CombatTarget == none && activeTask == none)
        {
	            m_WanderRemainingTime -= DeltaTime;
		    if (m_WanderRemainingTime <= 0)
		        GotoState('Idle');
        }
	}

    function FoundCombatTarget()
    {
        GotoState('Combating');
    }

Begin:
    RotateTo(
        m_WanderDirection);

    MoveTo(
        m_Pawn.Location + m_WanderDirection * m_Pawn.GetMoveSpeed());

    goto 'Begin';
}

state Combating
{
    event BeginState(Name PreviousStateName)
    {
        m_Pawn.m_IsInCombat = true;
    }

    event EndState(Name NextStateName)
    {
    }

    function TurnToTarget(float angle)
    {
        if (Abs(angle) > 15)
        {
	        RotateTo(
	            Normal2D(m_CombatTarget.Location - m_Pawn.Location));
        }
    }

    event Tick(float DeltaTime) {
        local float dist;
        local Vector dirToTarget;
        local float targetAngle;
        local bool doAttack;

        super.Tick(DeltaTime);

        if (m_CombatTarget != none) {
            if(Rand(11) < 4 && restrictedAttack == noRestrictedAttack) {
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

    function LostCombatTarget()
    {
        GotoState('Idle');
    }
}

state Chasing
{
    local float dist;

    event BeginState(Name PreviousStateName) { }

    event EndState(Name NextStateName)
    {
        m_Pawn.Acceleration = Vec3(0, 0, 0);

        m_Pawn.m_IsSprinting = false;
    }

    function LostCombatTarget()
    {
        GotoState('Idle');
    }

Begin:
    while (m_CombatTarget != none)
    {
	    dist = VSize2D(m_CombatTarget.Location - m_Pawn.Location);

        if (dist > m_CombatChaseSprintDistance)
        {
            m_Pawn.m_IsSprinting = true;
        }

        RotateTo(
            Normal2D(m_CombatTarget.Location - m_Pawn.Location));

        MoveToward(m_CombatTarget,, m_CombatChaseEndDistance / 2);

        if (dist <= m_CombatChaseEndDistance)
        {
            GotoState('Combating');
            break;
        }
    }
}

state Hit
{
    function bool BeginHitSequence(float angle)
    {
        return false;
    }

    event PushedState()
    {
    }

    event PoppedState()
    {

    }

    function FoundCombatTarget() { }

    function LostCombatTarget() { }

Begin:
	m_pawn.acceleration = vect(0,0,0);
    FinishRotation();

    if (BeginHitSequence(m_HitAngle))
    {
        FinishAnim(m_Pawn.m_CustomAnimSequence);

        m_NextHitDelay = RandRange(8, 10);
        autoAggro = true;
    }

    PopState();
}

function ResetAttack()
{
	m_CombatCanAttack = true;
}

state Attacking
{
    local float returnedCooldown;

    event BeginState(Name PreviousStateName)
    {
        m_HitLockCount++;
    }

    event EndState(Name NextStateName)
    {
        m_HitLockCount--;
        if( !isAttackRestricted )
        	restrictedAttack = noRestrictedAttack;
    }

    function bool BeginAttack(out float Cooldown)
    {
        Cooldown = -1;

        return false;
    }

Begin:
    FinishRotation();

    if (BeginAttack(returnedCooldown))
    {
        m_CombatWithoutAttackInterval = 0;

        if (returnedCooldown > 0)
        {
            m_CombatCanAttack = false;

            SetTimer(returnedCooldown, false, 'ResetAttack');
        }
    }

    if (activeTask != none )
        GotoState('DoingTask');
    else if (m_CombatTarget != none)
        GotoState('Combating');
    else
        GotoState('Idle');
}

function _Dead()
{
	m_Pawn.Destroy();

    self.Destroy();
}

function PawnDiedEvent(Controller Killer, class<DamageType> DamageType)
{
    GotoState('Dying',, false, false);
}

state Dying
{
    event BeginState(Name PreviousStateName)
    {
        m_Dead = true;

        SetTimer(10.0, false, '_Dead');
    }

    event EndState(Name NextStateName)
    {
    }

    function PawnDiedEvent(Controller Killer, class<DamageType> DamageType) { }

    function bool BeginDeathSequence()
    {
        return false;
    }

Begin:
    if (BeginDeathSequence())
    {
        FinishAnim(m_Pawn.m_CustomAnimSequence);
    }

    m_Pawn.MakeRagdoll();
}

defaultproperties
{
	autoAggro = true
	m_WanderDelay = (X=2, Y=6)
	m_WanderDuration = (X=2, Y=6)

    m_SeeRadius = 2000
    m_NoticeRadius = 500

	m_CombatCanAttack = true

	m_CombatChaseEndDistance = 60
	m_CombatChaseSprintDistance = 500

	taskCheckInterval = 2.f
	noRestrictedAttack = 255
	restrictedAttack = 255 // equals -1
}
