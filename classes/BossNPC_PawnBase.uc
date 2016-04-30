class BossNPC_PawnBase extends GamePawn implements (IBossNpcPawn);

var struct BossNpcAttackInfo {
	var byte 				ID;
	var float				BaseDamage;
	var float				DamageRadius;
	var class<DamageType>	DamageType;
	var float				Momentum;
	var bool				bFullDamage;
	var float      			DamageFalloffExponent;
	var bool				playTumble;
} BossNpcAttackInfoTmp;

var array<BossNpcAttackInfo> BossNpcAttackInfos;

var PrivateWrite DynamicLightEnvironmentComponent m_MeshLighEnv;

var PrivateWrite AnimNodeBlend    m_CustomAnimBlend;
var PrivateWrite AnimNodeSequence m_CustomAnimSequence;

var private name m_CustomAnimSeqName;
var private bool m_CustomAnimReset;
var private repnotify int m_CustomAnimID;

var float m_Speed;

var bool  m_IsSprinting;
var float m_SprintSpeed;

var bool  m_IsInCombat;
var float m_CombatSpeed;

var float    m_FootStepStartDist;
var SoundCue m_FootStepSounds;

var float    m_FarFootStepStartDist;
var float    m_FarFootStepEndDist;
var SoundCue m_FarFootStepSounds;

var private int m_FootStep;
var private int m_FarFootStep;

var repnotify int hitNormalRepCount;
var repnotify int hitStrongRepCount;

var repnotify bool m_dying;
var bool m_rotateToGround;
var ParticleSystemComponent deathDust;

var(NPC) SkeletalMeshComponent NPCMesh;
var(NPC) class<AIController> NPCController;
// set by controller
var DIFFICULTY_MODE difficulty;

`include(Stocks)
`include(Log)
`include(PawnUtils)
`include(bossNpcAttacks)

simulated function postBeginPlay() {
	if (NPCController !=none)
		self.ControllerClass = NPCController;

	SpawnDefaultController();
	super.postBeginPlay();
	initBossNpcAttackInfos();
	DisableAnimationLodding();
}

replication {
	if (bNetDirty && Role == ROLE_Authority)
		difficulty, hitNormalRepCount, hitStrongRepCount, m_Speed, m_IsSprinting, m_SprintSpeed, m_IsInCombat, m_dying, m_CustomAnimSeqName, m_CustomAnimReset, m_CustomAnimID;
}

simulated event ReplicatedEvent(name VarName) {
	if (VarName == 'm_CustomAnimID')
		PlayCustomAnim_CL();
	else if (VarName == 'm_dying') {
		GotoState('Dying');
	}
	else if (VarName == 'hitNormalRepCount') {
		displayHitEffects(false);
    }
    else if (VarName == 'hitStrongRepCount') {
		displayHitEffects(true);
    }


    super.ReplicatedEvent(VarName);
}

simulated event PostInitAnimTree(SkeletalMeshComponent SkelComp) {
    super.PostInitAnimTree(SkelComp);
	if (SkelComp == Mesh) {
	    m_CustomAnimBlend = AnimNodeBlend(Mesh.FindAnimNode('CustomAnim_Blend'));
	    m_CustomAnimSequence = AnimNodeSequence(Mesh.FindAnimNode('CustomAnim_Sequence'));
	    m_CustomAnimSequence.bCauseActorAnimEnd = true;

		m_CustomAnimBlend.bSkipBlendWhenNotRendered = false;
	}

	self.DisableAnimationLodding();
}

simulated function float GetMoveSpeed() {
	return m_IsSprinting ? m_SprintSpeed : (m_IsInCombat ? m_CombatSpeed : m_Speed);
}

simulated event Tick(float DeltaTime) {
	local float speed;
	local Rotator newRotation;

	if(m_rotateToGround) {
		self.AirSpeed    = 0;
    	self.GroundSpeed = 0;
    	velocity = vec3(0,0,0);
		newRotation = Rotation;
		newRotation.Pitch -= 3000 * DeltaTime;
		SetRotation( newRotation );

 		return;
	}

	speed = self.GetMoveSpeed();
    self.AirSpeed    = speed;
    self.GroundSpeed = speed;

    super.Tick(DeltaTime);
}


simulated function PlayCustomAnim(name SeqName, optional bool forceReset = false)
{
    if (self.Role == ROLE_Authority)
    {
		if (SeqName == m_CustomAnimSeqName && !forceReset)
			return;
    }

	m_CustomAnimSeqName = seqName;
	m_CustomAnimReset = forceReset;

	m_CustomAnimBlend.SetBlendTarget(1.0, 0.5);
    m_CustomAnimSequence.SetAnim(SeqName);
    m_CustomAnimSequence.PlayAnim();

    if (self.Role == ROLE_Authority)
        m_CustomAnimID++;
}

simulated function PlayCustomAnim_CL() { self.PlayCustomAnim(m_CustomAnimSeqName, m_CustomAnimReset); }

simulated event OnAnimEnd(AnimNodeSequence SeqNode, float PlayedTime, float ExcessTime)
{
    super.OnAnimEnd(SeqNode, PlayedTime, ExcessTime);

    if (SeqNode == m_CustomAnimSequence) {
        m_CustomAnimBlend.SetBlendTarget(0, 0.2);
    }

}

simulated event PlayFootStepSound(int FootDown)
{
	local PlayerController PC;
	local float dist;

	super.PlayFootStepSound(FootDown);

    foreach class'WorldInfo'.static.GetWorldInfo().LocalPlayerControllers(class'PlayerController', PC)
    {
        dist = VSize2D(PC.Pawn.Location - self.Location);

        if (dist >= m_FarFootStepStartDist)
        {
            if (dist > m_FarFootStepEndDist)
                continue;

        	PC.PlaySound(m_FarFootStepSounds, true,,, self.Location);
        }
        else
        {
        	PC.PlaySound(m_FootStepSounds, true,,, self.Location);
        }
    }
}

simulated function playHitSound(AocPawn InstigatedBy, bool strongHit) {
	local SoundCue ImpactSound;
	local AOCMeleeWeapon MeleeOwnerWeapon;

	if (strongHit) {
		MeleeOwnerWeapon = AOCMeleeWeapon(InstigatedBy.Weapon);
		ImpactSound = MeleeOwnerWeapon.ImpactSounds[AocWeapon(InstigatedBy.Weapon).AOCWepAttachment.LastSwingType].Light;
	}
	else {
		ImpactSound = SoundCue'A_Impacts_Missile.Dagger_Light';
	}

	if (ImpactSound != none) {
		InstigatedBy.StopWeaponSounds();
		InstigatedBy.PlayServerSoundWeapon( ImpactSound );
	}
}

/**
* server only
*/
event TakeDamage(
    int Damage,
    Controller InstigatedBy,
    vector HitLocation,
    vector Momentum,
    class<DamageType> DamageType,
    optional TraceHitInfo myHitInfo,
    optional Actor DamageCauser) {

	local bool StrongHit;
    local SandcastlePawn attacker;
    attacker = SandcastlePawn(Vehicle(InstigatedBy.pawn) != none ? vehicle(InstigatedBy.pawn).driver : Vehicle(InstigatedBy.pawn));

	if(isMason(attacker)) {
		StrongHit = isStrongHit(damage, attacker);
		if (StrongHit)
			BossNPC_CyclopeAI(controller).receivedCriticalHit();
		playHitSound(attacker, StrongHit);
		displayHitEffects(StrongHit);
		super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType, myHitInfo, DamageCauser);
	}
}

/**
*  decides which effects to play (sounds + blood) and if the npc gets stunned by the hit.
*/
function bool isStrongHit(int damage, SandcastlePawn attacker) {
	return damage >= 80;
}

simulated function displayHitEffects(bool strongHit) {
	local rotator BloodMomentum;
	local vector frontDir;

	// to let the client know
	if (strongHit)
		hitStrongRepCount++;
	else
		hitNormalRepCount++;

	if (self.Role == ROLE_Authority && !self.IsLocallyControlled()) return;

	frontDir = normal(Vector(Rotation));
	BloodMomentum = Rotator(500 * frontDir);
	BloodMomentum.Roll = 0;

	displayBlood(Location + frontDir * 50, BloodMomentum, strongHit ? 3 : 1);
}

simulated function displayBlood(vector origin, rotator momentum, float scale) {
	local ParticleSystem BloodTemplate;
	local UTEmit_HitEffect HitEffect;

	BloodTemplate = class'AOCWeapon'.default.ImpactBloodTemplates[0];
	if (BloodTemplate != None) {
		HitEffect = Spawn(class'UTGame.UTEmit_BloodSpray', self,, , momentum);
		HitEffect.SetTemplate(BloodTemplate, true);
		HitEffect.particleSystemComponent.setscale(scale);
		HitEffect.particleSystemComponent.activateSystem();
		HitEffect.ForceNetRelevant();
	}
}

function gibbedBy(actor Other) { }

simulated function bool Died(Controller Killer, class<DamageType> DamageType, vector HitLocation) {
	BossNPC_AIBase(self.Controller).PawnDiedEvent(Killer, DamageType);
	GotoState('Dying');

	return true;
}

simulated function _Dead() {
	deathDust.deactivateSystem();
    self.Destroy();
}

simulated state Dying {

	simulated function pawnFadeOut() {
	    local Vector BoneLoc;

		BoneLoc = self.Mesh.GetBoneLocation('joint7');
	    deathDust = WorldInfo.MyEmitterPool.SpawnEmitter(ParticleSystem'CHV_PartiPack.Particles.P_smokepot',BoneLoc - vec3(0,0,250));
	    deathDust.setscale( 2 );
	}

Begin:
	m_dying = true;
	SetTimer(6.0, false, '_Dead');
	pawnFadeOut();
    PlayCustomAnim('Die', true);
	FinishAnim(m_CustomAnimSequence);
	m_rotateToGround = true;
    m_CustomAnimSequence.stopAnim();
    AnimTree(mesh.Animations).SetUseSavedPose(TRUE);
	Mesh.PhysicsWeight = 999.0;
	SetPhysics(PHYS_None);

    //InitRagdoll(); <-- not working too well, makes cyclops deflate like a baloon
}


function String GetNotifyKilledHudMarkupText() {
	return "<font color=\"#B27500\">Boss NPC</font>";
}

function NotifyHitByBallista(AOCProj_ModBallistaBolt bolt) {
	TakeDamage(80, bolt.InstigatorController, location + vec3(1,1,1), vec3(0,0,0), bolt.MyDamageType,, bolt);
}

simulated function DisableAnimationLodding() {
	local int i;

	for(i = 0; i < ArrayCount(Mesh.AnimationLODDistanceFactors); ++i) {
		Mesh.AnimationLODDistanceFactors[i] = 0;
	}
	Mesh.DedicatedServerUpdateFrameRate = 0;
}

defaultproperties
{
    ControllerClass = class'BossNPC_AIBase'

    bBounce               = false
    bReplicateHealthToAll = true
    bCanBeBaseForPawns    = false
    bCanStepUpOn          = false
	bAlwaysRelevant       = true;

    begin object name=MeshLightEnvironment class=DynamicLightEnvironmentComponent
        bSynthesizeSHLight              = true
        bIsCharacterLightEnvironment    = true
        bUseBooleanEnvironmentShadowing = false

        InvisibleUpdateTime       = 1
        MinTimeBetweenFullUpdates = .2
    end object
    Components.Add(MeshLightEnvironment)
    m_MeshLighEnv = MeshLightEnvironment


	Begin Object Class=SkeletalMeshComponent Name=WPawnSkeletalMeshComponent
		bIgnoreControllersWhenNotRendered=false
		bTickAnimNodesWhenNotRendered=TRUE
		bAutoFreezeClothWhenNotRendered=TRUE
		bUpdateKinematicBonesFromAnimation=TRUE
		bSyncActorLocationToRootRigidBody=TRUE

		CollideActors=true
		BlockZeroExtent=true
		BlockNonZeroExtent=false
		BlockRigidBody=TRUE

		LightEnvironment = MeshLightEnvironment

		AlwaysLoadOnClient=TRUE
		AlwaysLoadOnServer=TRUE
		bUpdateSkelWhenNotRendered=TRUE

		DedicatedServerUpdateFrameRate = 0
		AnimationLODFrameRates[0]=0
		AnimationLODFrameRates[1]=0
		AnimationLODFrameRates[2]=0
		AnimationLODFrameRates[3]=0

	End Object
	NPCMesh = WPawnSkeletalMeshComponent
	mesh = WPawnSkeletalMeshComponent
	components.add(WPawnSkeletalMeshComponent)

    WalkingPhysics = PHYS_Walking

    m_FootStepStartDist = 0
    m_FarFootStepStartDist = 300
    m_FarFootStepEndDist = 600

}
