/**
* Cyclops pawn containing the cyclops specific actions.
* The 'ApplyAttack_' functions are called from the animationSet.
*/
class BossNPC_Cyclope extends BossNPC_PawnBase
    implements(HUD_OverheadExtIFace);

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
var SoundCue m_Cues_Crushed;
var SoundCue m_Cues_Foot_Kicked_Small;
var SoundCue m_Cues_Foot_Kicked_Big;
var SoundCue m_Cues_Hit_Enemy;

var bool  m_BreathEnabled;
var float m_BreathDelay;

var Dict  m_AttackedPawns;
var bool appliedKick;

var StaticMeshComponent ballProjComp; // dirtball attached to right hand

var int lastHitNormalCount; // remember amount of normal hits which caused us to get stunned

`include(Stocks)
`include(Log)
`include(PawnUtils)

simulated function float HUD_Overhead_GetHealthBarSizeScale() { return 1.5; }
simulated function float HUD_Overhead_GetHealthBarAdditionalZOffset() { return 180; }

simulated event PostBeginPlay() {
	super.PostBeginPlay();

	self.Mesh.SetScale(2.15);

	m_AttackedPawns = new class'Dict';
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

simulated function ApplyAttack_Start() {
	m_AttackedPawns.Clear();
}

simulated function bool AttackPawn(Pawn target, byte attackType, vector damageSourcePos) {
	if (!IsValidTarget(target, self) || m_AttackedPawns.ContainsKey(target))
		return false;

    m_AttackedPawns.Add(target, target);

	AOCPawn(target).ReplicatedHitInfo.DamageString = "&";
	applyAttackDmg(target, attackType, damageSourcePos);

	if(BossNpcAttackInfos[attackType].playTumble)
		SandcastlePawn(target).playTumble();

	return true;
}

const SOUND_DMG_THRESHOLD = 70;

function applyAttackDmg(Pawn target, byte attack, vector HurtOrigin) {
	local BossNpcAttackInfo attc;
	local int index;
	local int hpOld;

	// even though this func is not simulated it is still executed with lesser authority!!
	if (role < role_authority)  return;

	index = BossNpcAttackInfos.Find('ID', attack);
	if(index < 0) {
		logerror("Boss npc attack with id "$attack$" is unknown! Add it to the include file.");
		return;
	}

	attc = BossNpcAttackInfos[index];
	hpOld = target.health;
	target.TakeRadiusDamage(
        Controller,
        attc.BaseDamage,
        attc.DamageRadius,
        attc.DamageType,
        attc.Momentum,
        HurtOrigin,
        attc.bFullDamage,
        self,
        attc.DamageFalloffExponent);

     if (attack == CYCLOPE_ATTACK_FOOT_CRUSH && target.health <= 0) {
         playSound_Crushed(target);
     }
     else if (attack > CYCLOPE_ATTACK_FORWARD && (hpOld - target.health > SOUND_DMG_THRESHOLD))
         PlaySound_Hit_Enemy(target);
}

simulated function ApplyAttack_Smash_Impact() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation('Smash_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_SMASH].DamageRadius) {
		AttackPawn(pawn, CYCLOPE_ATTACK_SMASH, damageSourcePos);
    }
}

simulated function ApplyAttack_FootCrush() {
	local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation('FootCrush_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_FOOT_CRUSH].DamageRadius) {
        AttackPawn(pawn, CYCLOPE_ATTACK_FOOT_CRUSH, damageSourcePos);
    }
}

const SMALL_KICK_FORCE = 1000;

simulated function ApplyAttack_FootKick() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Vector footDir;
    local Vector forceDir;
    local Pawn pawn;
    local int pawnHP;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation('FootKick_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_FOOT_KICK].DamageRadius) {
        pawnHP = pawn.health;
		if(!AttackPawn(pawn, CYCLOPE_ATTACK_FOOT_KICK,  damageSourcePos)) continue;

		if (pawnHP < BossNpcAttackInfos[CYCLOPE_ATTACK_FOOT_KICK].BaseDamage + 20) {
			cyclopsKickPawn(AOCPawn(pawn));
			self.PlaySound_Foot_Kicked_Big();
		}
		else {
			footDir = Vector(damageSourceRot);
			forceDir = Normal(Normal2D(footDir) + Vec3(0, 0, 0.5));
			pawn.SetLocation(Location + forceDir * Vec3(0, 0, 15));
		   	pawn.SetPhysics(PHYS_Falling);
		    pawn.AddVelocity(forceDir * SMALL_KICK_FORCE, damageSourcePos, class'AOCDmgType_Generic');
		    self.PlaySound_Foot_Kicked_Small();
		}
    }
}

simulated function cyclopsKickPawn(AocPawn p) {
	local Vector forceDir;
	local vector bossNpcMomentum;
	local vector bossNpcForceLoc;

	forceDir =  normal(location - p.location);
	bossNpcForceLoc = forceDir * 50 + (p.location - vect(0,0,-100));
	bossNpcMomentum = forceDir * -9999;
	bossNpcMomentum.Z = 5000;
	p.ReplicatedHitInfo.HitLocation = p.Location;
	p.ReplicatedHitInfo.DamageType = class'AOCDmgType_Generic';
	p.ReplicatedHitInfo.BoneName = 'b_spine_C';
	p.ReplicatedHitInfo.DamageString = "I";
	p.LastTakeHitInfo.Momentum = bossNpcMomentum;
	p.LastTakeHitInfo.HitLocation = bossNpcForceLoc;
	p.Mass = 1;
	p.Velocity.Z = 700;
	p.SetPhysics(PHYS_Falling);
	p.Mesh.AddImpulse(bossNpcMomentum, bossNpcForceLoc);
}

simulated function ApplyAttack_Forward() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation('Right_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_FORWARD].DamageRadius) {
		AttackPawn(pawn, CYCLOPE_ATTACK_FORWARD, damageSourcePos);
    }
}

simulated function ApplyAttack_Forward2() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation('Left_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_FORWARD_2].DamageRadius) {
        AttackPawn(pawn, CYCLOPE_ATTACK_FORWARD_2, damageSourcePos);
    }
}

simulated function ApplyAttack_Left() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation('Left_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_LEFT].DamageRadius) {
        AttackPawn(pawn, CYCLOPE_ATTACK_LEFT, damageSourcePos);
    }
}

simulated function ApplyAttack_Right() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation('Right_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_RIGHT].DamageRadius) {
         AttackPawn(pawn, CYCLOPE_ATTACK_RIGHT, damageSourcePos);
    }
}

simulated function ApplyAttack_Side_Left() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation( 'Left_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_SIDE_LEFT].DamageRadius) {
         AttackPawn(pawn, CYCLOPE_ATTACK_SIDE_LEFT, damageSourcePos);
    }
}

simulated function ApplyAttack_Side_Right() {
    local WorldInfo world;
    local Vector damageSourcePos;
    local Rotator damageSourceRot;
    local Pawn pawn;

    world = class'WorldInfo'.static.GetWorldInfo();

    self.Mesh.GetSocketWorldLocationAndRotation( 'Right_Socket', damageSourcePos, damageSourceRot);

    foreach world.AllPawns(class'Pawn', pawn, damageSourcePos, BossNpcAttackInfos[CYCLOPE_ATTACK_SIDE_RIGHT].DamageRadius) {
        AttackPawn(pawn, CYCLOPE_ATTACK_SIDE_RIGHT, damageSourcePos);
    }
}

/*
* Spawn a dirtball in the right hand because the cyclops currently grabs the ground
* Called from the animation.
*/
simulated function Grabbed() {
    local Vector ballPos;
    local Rotator ballRot;

    self.Mesh.GetSocketWorldLocationAndRotation('Right_Socket', ballPos, ballRot);

    ballProjComp = new(self) class'StaticMeshComponent';
    ballProjComp.SetStaticMesh(StaticMesh'CHV_Weapons-siege.Bastilla.Catapult_Rock');
    ballProjComp.bacceptsDynamicDominantLightShadows = false;
    ballProjComp.bCastDynamicShadow = false;
    ballProjComp.castShadow = false;
    ballProjComp.lightmassSettings.bUseEmissiveForStaticLighting  = true;
    ballProjComp.lightmassSettings.EmissiveBoost = 10;
    ballProjComp.settranslation( vec3(-10, -10, 0) );
    ballProjComp.SetLightEnvironment(mesh.LightEnvironment);

	mesh.AttachComponentToSocket(ballProjComp, 'Right_Socket');
}

/*
* Spawn a dirtball-projectile at the right hand to throw
* Called from the animation.
*/
simulated function Released() {
    local Vector ballPos;
    local Rotator ballRot;
    local vector targetLoc;

	ballProjComp.detachFromAny();
	ballProjComp = none;

	if(Role == Role_Authority) {
		self.Mesh.GetSocketWorldLocationAndRotation('Right_Socket', ballPos, ballRot);
		targetLoc = BossNPC_CyclopeAI(controller).tookHitFromSW != none ? BossNPC_CyclopeAI(controller).tookHitFromSW.location : BossNPC_CyclopeAI(controller).m_CombatTarget.location;
	    SpawnProjectile(ballPos, targetLoc);
	}
}

const PROJ_SPEED = 1550.0;

function SpawnProjectile( Vector startLoc, vector targetLoc ) {
	local Projectile SpawnedProjectile;
	local Rotator aim;

	aim = Rotator(targetLoc - vec3(0,0,34) - startLoc);
	SpawnedProjectile = Spawn(class'Proj_Rock',self,, startLoc, aim);

	if ( SpawnedProjectile != None ) {
		AOCProjectile(SpawnedProjectile).Drag = 0;
		AOCProjectile(SpawnedProjectile).Damage = BossNpcAttackInfos[CYCLOPE_ATTACK_SIDE_RIGHT].BaseDamage;
		Proj_Rock(SpawnedProjectile).Mesh.setScale( 1.1 );
		AOCProjectile(SpawnedProjectile).Speed = PROJ_SPEED;
		AOCProjectile(SpawnedProjectile).MaxSpeed = PROJ_SPEED;
		AOCProjectile(SpawnedProjectile).PrevLocation = startLoc;
		AOCProjectile(SpawnedProjectile).DamageRadius = BossNpcAttackInfos[CYCLOPE_ATTACK_SIDE_RIGHT].DamageRadius;
		AOCProjectile(SpawnedProjectile).AOCInit(Aim);
	}
}

const critDmg = 70;
const maxDmg = 50;
const minDmg = 5;

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

    local name BestBone;
    local vector BestHitLocation;
    local bool smallHit;

    Momentum = vec3(0,0,0);

	switch (difficulty) {
		case EDM_NORMAL:
			smallHit = AOCRangeWeapon(InstigatedBy.pawn.Weapon) != none;
			if (!smallHit) {
				FindNearestBone(self, HitLocation, BestBone, BestHitLocation);
				if (BestBone != 'SK_Head') {
					smallHit = true;
				}
			}
			smallHit = smallHit ? Vehicle(DamageCauser) != none : smallHit;

			Damage = smallHit ? minDmg : maxDmg;
			super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType, myHitInfo, DamageCauser);
		break;
		case EDM_HARD:
			if(AOCRangeWeapon(InstigatedBy.pawn.Weapon) == none) {
				FindNearestBone(self, HitLocation, BestBone, BestHitLocation);
				if (BestBone == 'SK_Head') {
					Damage = damage > maxDmg ? maxDmg : damage;
					super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType, myHitInfo, DamageCauser);
				}
			}
			break;
	}
}

const HitsUntilStun = 35;

function bool isStrongHit(int damage, SandcastlePawn attacker) {
	local bool enoughHits;
	local bool hardDmg;

	enoughHits = (hitNormalRepCount - lastHitNormalCount) > 0 && hitNormalRepCount % HitsUntilStun == 0;
	if (enoughHits)
		lastHitNormalCount = hitNormalRepCount;
	hardDmg = damage > class'BossNPC_Cyclope'.const.minDmg;

	return (hardDmg || enoughHits || attacker.PawnState == ESTATE_SIEGEWEAPON) && difficulty < EDM_HARD;
}

simulated function displayHitEffects(bool StrongHit) {
	local rotator BloodMomentum;
	local Vector headPos;
	local vector frontDir;

	// to let the client know
	if (strongHit)
		hitStrongRepCount++;
	else
		hitNormalRepCount++;

	if (self.Role == ROLE_Authority && !self.IsLocallyControlled()) return;

	if (StrongHit) {
		headPos = Mesh.GetBoneLocation('SK_Head');
		frontDir = normal(Vector(Rotation));
		BloodMomentum = Rotator(500 * frontDir);
		BloodMomentum.Roll = 0;

		displayBlood(headPos + frontDir * 50, BloodMomentum, 5);
		displayBlood(headPos + frontDir * -20, BloodMomentum * -1, 4);
		displayBlood(headPos + frontDir * -20, BloodMomentum * -1, 2);
	}
}

simulated function String GetNotifyKilledHudMarkupText() {
	return "<font color=\"#800000\">Cyclops</font>";
}

function NotifyHitByBallista(AOCProj_ModBallistaBolt bolt) {
	BossNPC_CyclopeAI(controller).tookHitFromSW = bolt.InstigatorBaseVehicle;
	TakeDamage(class'BossNPC_Cyclope'.const.maxDmg, bolt.InstigatorController, location + vec3(1,1,1), vec3(0,0,0), bolt.MyDamageType,, bolt);
}

simulated function PlaySound_Breathing() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Breathing, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_DieImpaled() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_DieImpaled, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Dying() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Dying, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_GrabPlayerIn() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_GrabPlayerIn, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_GrabPlayerTaunt() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_GrabPlayerTaunt, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Grunt() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Grunt, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_GuardMode() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_GuardMode, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Hail() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Hail, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Impaled() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Impaled, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Misc() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Misc, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Ouch() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Ouch, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_OuchStrong() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_OuchStrong, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Smash() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(m_Cues_Smash, true,,, self.Location);
    }
}

simulated function PlayEffect_RFootImpact() {
	local Vector impactPos;

    Mesh.GetSocketWorldLocationAndRotation('FootCrush_Socket', impactPos);
    PlayEffect_Impact(impactPos);
}

simulated function PlayEffect_RHandImpact() {
	local Vector impactPos;

	Mesh.GetSocketWorldLocationAndRotation('Smash_Socket', impactPos);
	PlayEffect_Impact(impactPos);
}

simulated function PlayEffect_Impact(vector impactPos) {
    if (Role != ROLE_Authority || IsLocallyControlled()) {
        PlaySound(m_Cues_Smash, true,,, Location);
        WorldInfo.MyEmitterPool.SpawnEmitter(ParticleSystem'Cove.particalsystems.P_Impact',impactPos).setscale(2);
    }
}

simulated function PlaySound_Striking() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Striking, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Threat() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Threat, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Victory() {
    if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(
           m_Cues_Victory, true,,, self.Location + Vec3(0, 0, self.EyeHeight));
    }
}

simulated function PlaySound_Whoosh() {
	if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(m_Cues_Whoosh, true,,, self.Location);
    }
}

simulated function PlaySound_Foot_Kicked_Small() {
	if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(m_Cues_Foot_Kicked_Small, true,,, self.Location);
    }
}

simulated function PlaySound_Foot_Kicked_Big() {
	if (self.Role != ROLE_Authority || self.IsLocallyControlled()) {
        self.PlaySound(m_Cues_Foot_Kicked_Big, true,,, self.Location);
    }
}

/**
* triggered by server dmg function. Requires replication.
*/
function PlaySound_Crushed(pawn victim) {
   self.PlaySound(m_Cues_Crushed, false,,, victim.Location);
}

function PlaySound_Hit_Enemy(pawn victim) {
   self.PlaySound(m_Cues_Hit_Enemy, false,,, victim.Location);
}

defaultproperties
{
    NPCController = class'BossNPC_CyclopeAI'

    SightRadius = 999999.f

    begin object name=WPawnSkeletalMeshComponent
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
    m_Cues_Crushed = SoundCue'A_Impacts_Melee.Giant_stomped'
    m_Cues_Foot_Kicked_Small = SoundCue'A_Phys_Mat_Impacts.Buckler_Blocking'
    m_Cues_Foot_Kicked_Big = SoundCue'A_Impacts_Melee.head_explodie'
    m_Cues_Hit_Enemy = SoundCue'A_Impacts_Missile.Axe_Heavy'
}
