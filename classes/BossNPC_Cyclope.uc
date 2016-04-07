/**
* Cyclops pawn containing the cyclops specific actions.
* The 'ApplyAttack_' functions are called from the animationSet.
*/
class BossNPC_Cyclope extends BossNPC_PawnBase
    implements(HUD_OverheadExtIFace)
    dependson(ICyclopsAttackable);

var SoundCue m_Cues_Breathing;
var SoundCue m_Cues_DieImpaled;
var SoundCue m_Cues_Dying;
var SoundCue m_Cues_GrabPlayerIn;
var SoundCue m_Cues_GrabPlayerTaunt;
var SoundCue m_Cues_Grunt;
var SoundCue m_Cues_GuardMode;
var SoundCue m_Cues_Hail;
var SoundCue m_Cues_Impaled;
var SoundCue m_Cues_Misc;
var SoundCue m_Cues_Ouch;
var SoundCue m_Cues_OuchStrong;
var SoundCue m_Cues_Smash;
var SoundCue m_Cues_Striking;
var SoundCue m_Cues_Threat;
var SoundCue m_Cues_Victory;
var SoundCue m_Cues_Whoosh;

var bool  m_BreathEnabled;
var float m_BreathDelay;

var Dict  m_AttackedPawns;
var bool appliedKick;

var class<DamageType> defaultDmgCls;

var StaticMeshComponent ballProjComp; // dirtball attached to right hand

`include(Stocks)
`include(Log)

simulated function float HUD_Overhead_GetHealthBarSizeScale() { return 1.5; }
simulated function float HUD_Overhead_GetHealthBarAdditionalZOffset() { return 180; }

simulated event PostBeginPlay() {
	super.PostBeginPlay();

	if (controller == none && (Health > 0) && !bDontPossess ) {
		SpawnDefaultController();
	}

	m_AttackedPawns = new class'Dict';

	m_BodyMesh.SetScale(2.15);
}

simulated event Tick(float DeltaTime) {
    super.Tick(DeltaTime);

    if (m_BreathEnabled) {
            m_BreathDelay -= DeltaTime;
        if (m_BreathDelay <= 0)
        {   m_BreathDelay += 4;

            self.PlaySound_Breathing();
        }
    }
}

function ApplyAttack_Start() {
	m_AttackedPawns.Clear();
}

/**
* Called by most attacks to apply the damage during the interation through possible targets.
* Returns if the damage got applied.
*/
function bool ApplyAttackDamage(Pawn target, optional float baseDamage = 500, optional float radius = 500, optional vector damageSourcePos = vec3(0,0,0), optional float dmgFallOff = 4.0) {
	if (!BossNPC_AIBase(self.Controller).IsValidTarget(target) || m_AttackedPawns.ContainsKey(target))
        return false;

    m_AttackedPawns.Add(target, target);

	AOCPawn(target).ReplicatedHitInfo.DamageString = "&";
    target.TakeRadiusDamage(
        self.Controller,
        baseDamage,
        radius,
        defaultDmgCls,
        0,
        damageSourcePos,
        false,
        self,
        dmgFallOff);
}


const SMASH_DMG        = 120.0;
const SMASH_DMG_RADIUS = 250.0;
const SMASH_DMG_FORCE  = 400.0;

function ApplyAttack_Smash_Impact() {
    local WorldInfo world;

    local Vector damageSourcePos;
    local Rotator damageSourceRot;

    local Vector forceDir;

    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation(
        'Smash_Socket',
        damageSourcePos,
        damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, SMASH_DMG_RADIUS) {
		if(!ApplyAttackDamage(pawn, SMASH_DMG, SMASH_DMG_RADIUS, damageSourcePos)) continue;

        forceDir = Normal(Normal2D(pawn.Location - damageSourcePos) + Vec3(0, 0, 3));

        pawn.SetLocation(pawn.Location + forceDir * Vec3(0, 0, 30));

        pawn.AddVelocity(
            forceDir * (SMASH_DMG_FORCE * Clamp(1 - VSize(pawn.Location - damageSourcePos) / SMASH_DMG_RADIUS, 0.3, 1.0)),
            damageSourcePos,
            defaultDmgCls);
    }
}

const FOOT_CRUSH_DMG        = 500.0;
const FOOT_CRUSH_DMG_RADIUS = 500.0;

function ApplyAttack_FootCrush() {
	local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation('FootCrush_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, FOOT_CRUSH_DMG_RADIUS) {
        if(!ApplyAttackDamage(pawn, FOOT_CRUSH_DMG, FOOT_CRUSH_DMG_RADIUS, damageSourcePos)) continue;

        SandcastlePawn(pawn).playTumble();
    }
}

const FOOT_KICK_DMG        = 40.0;
const FOOT_KICK_DMG_RADIUS = 400.0;
const FOOT_KICK_DMG_FORCE  = 400.0;

/**
* TODO: the actual effect (damage and physics) are implemented in the SandcastlePC via ICyclopsAttackable (due to function replication).
* So part of the following logic is to be replaced by it.
*
*/
function ApplyAttack_FootKick() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Vector footDir;
    local Vector forceDir;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation(
        'FootKick_Socket',
        damageSourcePos,
        damageSourceRot);

    footDir = Vector(damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, FOOT_KICK_DMG_RADIUS)
    {

        if (!BossNPC_AIBase(self.Controller).IsValidTarget(pawn))
            continue;

        if (m_AttackedPawns.ContainsKey(pawn))
            continue;

        m_AttackedPawns.Add(pawn, pawn);

		AOCPawn(pawn).ReplicatedHitInfo.DamageString = "&";
        pawn.TakeRadiusDamage(
            self.Controller,
            FOOT_KICK_DMG,
            FOOT_KICK_DMG_RADIUS,
            defaultDmgCls,
            0,
            damageSourcePos,
            true,
            self);

        forceDir = Normal(Normal2D(footDir) + Vec3(0, 0, 3));

        pawn.SetLocation(pawn.Location + forceDir * Vec3(0, 0, 30));

        pawn.AddVelocity(
            forceDir * FOOT_KICK_DMG_FORCE,
            damageSourcePos,
            defaultDmgCls);
    }
}


const FORWARD_DMG        = 50.0;
const FORWARD_DMG_RADIUS = 150.0;

function ApplyAttack_Forward() {
    local WorldInfo world;

    local Vector damageSourcePos;
    local Rotator damageSourceRot;

    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation('Right_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, FORWARD_DMG_RADIUS) {
       ApplyAttackDamage(pawn, FORWARD_DMG, FORWARD_DMG_RADIUS, damageSourcePos);
    }
}

const FORWARD2_DMG        = 50.0;
const FORWARD2_DMG_RADIUS = 150.0;

function ApplyAttack_Forward2() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation('Left_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, FORWARD2_DMG_RADIUS) {
        ApplyAttackDamage(pawn, FORWARD2_DMG, FORWARD2_DMG_RADIUS, damageSourcePos);
    }
}

const LEFT_RIGHT_DMG        = 50.0;
const LEFT_RIGHT_DMG_RADIUS = 250.0;

function ApplyAttack_Left() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation('Left_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, LEFT_RIGHT_DMG_RADIUS) {
        ApplyAttackDamage(pawn, LEFT_RIGHT_DMG, LEFT_RIGHT_DMG_RADIUS, damageSourcePos);
    }
}

function ApplyAttack_Right() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation('Right_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, LEFT_RIGHT_DMG_RADIUS) {
         ApplyAttackDamage(pawn, LEFT_RIGHT_DMG, LEFT_RIGHT_DMG_RADIUS, damageSourcePos);
    }
}

const SIDE_LEFT_RIGHT_DMG        = 30.0;
const SIDE_LEFT_RIGHT_DMG_RADIUS = 250.0;

function ApplyAttack_Side_Left() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation( 'Left_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, SIDE_LEFT_RIGHT_DMG_RADIUS) {
         ApplyAttackDamage(pawn, SIDE_LEFT_RIGHT_DMG, SIDE_LEFT_RIGHT_DMG_RADIUS, damageSourcePos);
    }
}

function ApplyAttack_Side_Right() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    m_BodyMesh.GetSocketWorldLocationAndRotation( 'Right_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, SIDE_LEFT_RIGHT_DMG_RADIUS) {
        ApplyAttackDamage(pawn, SIDE_LEFT_RIGHT_DMG, SIDE_LEFT_RIGHT_DMG_RADIUS, damageSourcePos);
    }
}

/*
* Spawn a dirtball in the right hand because the cyclops currently grabs the ground
* Called from the animation.
*/
function Grabbed() {
    local Vector ballPos;
    local Rotator ballRot;

    m_BodyMesh.GetSocketWorldLocationAndRotation('Right_Socket', ballPos, ballRot);

    ballProjComp = new(self) class'StaticMeshComponent';
    ballProjComp.SetStaticMesh(StaticMesh'CHV_Weapons-siege.Bastilla.Catapult_Rock');
    ballProjComp.bacceptsDynamicDominantLightShadows = false;
    ballProjComp.bCastDynamicShadow = false;
    ballProjComp.castShadow = false;
    ballProjComp.lightmassSettings.bUseEmissiveForStaticLighting  = true;
    ballProjComp.lightmassSettings.EmissiveBoost = 10;
    ballProjComp.settranslation( vec3(-10, -10, 0) );

	mesh.AttachComponentToSocket(ballProjComp, 'Right_Socket');
}

/*
* Spawn a dirtball-projectile at the right hand to throw
* Called from the animation.
*/
function Released() {
    local Vector ballPos;
    local Rotator ballRot;
    local vector targetLoc;

    m_BodyMesh.GetSocketWorldLocationAndRotation('Right_Socket', ballPos, ballRot);

	ballProjComp.detachFromAny();
	ballProjComp = none;

	targetLoc = BossNPC_CyclopeAI(controller).m_CombatTarget.location;
    SpawnProjectile(ballPos, targetLoc);
}

const PROJ_DMG = 400.0;
const PROJ_SPEED = 1550.0;

simulated function SpawnProjectile( Vector startLoc, vector targetLoc ) {
	local Projectile SpawnedProjectile;
	local Rotator aim;

	aim = Rotator(targetLoc - startLoc);
	SpawnedProjectile = Spawn(class'Proj_Rock',self,, startLoc, aim);

	if ( SpawnedProjectile != None ) {
		AOCProjectile(SpawnedProjectile).Drag = 0;
		AOCProjectile(SpawnedProjectile).Damage = PROJ_DMG;
		Proj_Rock(SpawnedProjectile).Mesh.setScale( 1.1 );
		AOCProjectile(SpawnedProjectile).Speed = PROJ_SPEED;
		AOCProjectile(SpawnedProjectile).MaxSpeed = PROJ_SPEED;
		AOCProjectile(SpawnedProjectile).PrevLocation = startLoc;
		AOCProjectile(SpawnedProjectile).AOCInit(Aim);
	}
}

simulated function PlayDying(class<DamageType> DamageType, vector HitLoc) {
    GotoState('Dying');
    bReplicateMovement = false;
    bTearOff = true;
    Velocity += TearOffMomentum;
    //SetDyingPhysics();
    bPlayedDeath = true;

    KismetDeathDelayTime = default.KismetDeathDelayTime + WorldInfo.TimeSeconds;
}

event TakeDamage(
    int Damage,
    Controller InstigatedBy,
    vector HitLocation,
    vector Momentum,
    class<DamageType> DamageType,
    optional TraceHitInfo myHitInfo,
    optional Actor DamageCauser) {

    local name BestBone;
    local vector BestHitLocation;
    local SandcastlePawn attacker;

    attacker = SandcastlePawn(InstigatedBy.pawn);

    FindNearestBone(HitLocation, BestBone, BestHitLocation);
	if( BestBone == 'SK_Head' && AOCRangeWeapon(attacker.Weapon) == none) {
		playHitSound(attacker);
		displayHitEffects(Momentum, HitLocation);
		super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType, myHitInfo, DamageCauser);
	}
}

simulated function displayHitEffects(vector Momentum, vector HitLocation) {
	local ParticleSystem BloodTemplate;
	local UTEmit_HitEffect HitEffect;
	local rotator BloodMomentum;

	if(Momentum.X == 0) {
		Momentum.X = 1;
	}
	if(Momentum.Y == 0) {
		Momentum.Y = 1;
	}

	BloodTemplate = class'AOCWeapon'.default.ImpactBloodTemplates[0];
	if (BloodTemplate != None) {
		BloodMomentum = Rotator( 95500 * Momentum );
		BloodMomentum.Roll = 0;
		HitEffect = Spawn(class'UTGame.UTEmit_BloodSpray', self,, HitLocation, BloodMomentum);
		HitEffect.SetTemplate(BloodTemplate, true);
		HitEffect.AttachTo(self, 'SK_Head');
	}
}

function String GetNotifyKilledHudMarkupText() {
	return "<font color=\"#B27500\">Cyclops</font>";
}

simulated function PlaySound_Breathing()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Breathing, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_DieImpaled()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_DieImpaled, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Dying()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Dying, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_GrabPlayerIn()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_GrabPlayerIn, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_GrabPlayerTaunt()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_GrabPlayerTaunt, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Grunt()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Grunt, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_GuardMode()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_GuardMode, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Hail()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Hail, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Impaled()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Impaled, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Misc()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Misc, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Ouch()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Ouch, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_OuchStrong()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_OuchStrong, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Smash()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Smash, true,,, self.Location);
    }
}

simulated function PlaySound_Striking()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Striking, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Threat()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Threat, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Victory()
{
    if (self.Role != ROLE_Authority || self.IsLocallyControlled())
    {
        self.PlaySound(
           m_Cues_Victory, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Whoosh()
{
	if (self.Role != ROLE_Authority || self.IsLocallyControlled())
	{
        self.PlaySound(m_Cues_Whoosh, true,,, self.Location);
    }
}

defaultproperties
{
    ControllerClass = class'BossNPC_CyclopeAI'
    defaultDmgCls = class'AOCDmgType_Generic' //class'AOCDmgType_Blunt'

    SightRadius = 999999.f

    begin object name=BodyMesh
	    SkeletalMesh     = SkeletalMesh'BossNPCs_Content.Cyclope.Cyclope_Mesh'
	    PhysicsAsset     = PhysicsAsset'BossNPCs_Content.Cyclope.Cyclope_Mesh_Physics'
	    AnimSets(0)      = AnimSet'BossNPCs_Content.Cyclope.Cyclope_AnimSet'
        AnimTreeTemplate = AnimTree'BossNPCs_Content.Cyclope.Cyclope_AnimTree'
    end object

    begin object name=CollisionCylinder
        CollisionHeight = 180
        CollisionRadius = 130
    end object

    m_Speed       = 200
    m_CombatSpeed = 260
    m_SprintSpeed = 340

    HealthMax = 1000
    Health    = 1000

    BaseEyeHeight = 180

    m_FootStepStartDist = 0
    m_FootStepSounds = SoundCue'BossNPCs_Content.Cyclope.Sounds.Cyclope_FootStep_Cue'

    m_FarFootStepStartDist = 1500
    m_FarFootStepEndDist = 2500
    m_FarFootStepSounds = SoundCue'BossNPCs_Content.Cyclope.Sounds.Cyclope_FarFootStep_Cue'

    m_Cues_Breathing = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_breathing_Cue'
    m_Cues_DieImpaled = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_die_impaled_Cue'
    m_Cues_Dying = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_dying_Cue'
    m_Cues_GrabPlayerIn = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_grabplayerin_Cue'
    m_Cues_GrabPlayerTaunt = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_grabplayertaunt_Cue'
    m_Cues_Grunt = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_grunt_Cue'
    m_Cues_GuardMode = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_guardmode_Cue'
    m_Cues_Hail = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_hail_Cue'
    m_Cues_Impaled = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_impaled_Cue'
    m_Cues_Misc = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_misc_Cue'
    m_Cues_Ouch = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_ouch_Cue'
    m_Cues_OuchStrong = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_ouch_strong_Cue'
    m_Cues_Smash = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_smash_Cue'
    m_Cues_Striking = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_striking_Cue'
    m_Cues_Threat = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_threat_Cue'
    m_Cues_Victory = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_victory_Cue'
    m_Cues_Whoosh = SoundCue'BossNPCs_Content.Cyclope.Sounds.cyclope_whoosh_Cue'
}
