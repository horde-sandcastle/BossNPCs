class BossNPC_CyclopeAI extends BossNPC_AIBase;

enum ECyclopeAttack {
	CYCLOPE_ATTACK_SMASH,

	CYCLOPE_ATTACK_FOOT_CRUSH,
	CYCLOPE_ATTACK_FOOT_KICK,

	CYCLOPE_ATTACK_FORWARD,
	CYCLOPE_ATTACK_FORWARD_2,

	CYCLOPE_ATTACK_LEFT,
	CYCLOPE_ATTACK_RIGHT,

    CYCLOPE_ATTACK_SIDE_LEFT,
    CYCLOPE_ATTACK_SIDE_RIGHT,

    CYCLOPE_ATTACK_THROW_GROUND
};

struct AttackToDist {
	var ECyclopeAttack Attack;
	var float Dist;
};

var name m_CurrentTurnSeqName;

var bool           m_SmashAttackEnabled;
var ECyclopeAttack m_CurrentAttack;

var bool debug;

`include(Stocks)
`include(Log)

function ResetAttackDual()
{
	m_SmashAttackEnabled = true;
}

state Turn
{
    event PushedState()
    {
        m_HitLockCount++;

        m_Pawn.PlayCustomAnim(m_CurrentTurnSeqName);
    }

    event PoppedState()
    {
        m_HitLockCount--;
    }

    function FoundCombatTarget() { }

    function LostCombatTarget() { }

Begin:
    FinishAnim(m_Pawn.m_CustomAnimSequence);

    PopState();
}

state Combating
{
    function TurnToTarget(float Angle)
    {
        super.TurnToTarget(Angle);

        if (Abs(angle) > 15)
        {
	        if (Angle < 0)
	        {
	            if (Angle <= -60)
	            {
	            	if (Angle < -120)
	            	{
                       m_CurrentTurnSeqName = 'Turn_180_Left';
	            	}
	            	else
	            	{
	                   m_CurrentTurnSeqName = 'Turn_90_Left';
	            	}
	            }
	            else
	                m_CurrentTurnSeqName = 'Turn_45_Left';
	        }
	        else
	        {
	            if (Angle >= 60)
	            {
	               if (Angle > 120)
	               {
                       m_CurrentTurnSeqName = 'Turn_180_Right';
	               }
	               else
	               {
	                   m_CurrentTurnSeqName = 'Turn_90_Right';
	               }
	            }
	            else
	            	m_CurrentTurnSeqName = 'Turn_45_Right';
	        }

	        PushState('Turn');
        }
    }
}

state Hit
{
    function bool BeginHitSequence(float angle)
    {
        if (angle < -45)
        {
            m_Pawn.PlayCustomAnim('Hit_Left');
        }
        else
        if (angle > +45)
        {
            m_Pawn.PlayCustomAnim('Hit_Right');
        }
        else
        if (Abs(angle) > 120)
        {
            m_Pawn.PlayCustomAnim('Hit_Back');
        }
        else
        {
            m_Pawn.PlayCustomAnim('Hit_Front');
        }

        return true;
    }
}

static private function name GetAttackSequenceName(ECyclopeAttack attackID)
{
    switch (attackID)
    {
    case CYCLOPE_ATTACK_SMASH:
        return 'Attack_Dual';

    case CYCLOPE_ATTACK_FOOT_CRUSH:
        return 'Attack_Foot_Crush';

    case CYCLOPE_ATTACK_FOOT_KICK:
        return 'Attack_Foot_Shoot';

    case CYCLOPE_ATTACK_FORWARD:
        return 'Attack_Forward';

    case CYCLOPE_ATTACK_FORWARD_2:
        return 'Attack_Forward_Left';

    case CYCLOPE_ATTACK_LEFT:
        return 'Attack_Left';

    case CYCLOPE_ATTACK_RIGHT:
        return 'Attack_Right';

    case CYCLOPE_ATTACK_SIDE_LEFT:
        return 'Attack_Side_Left';

    case CYCLOPE_ATTACK_SIDE_RIGHT:
        return 'Attack_Side_Right';

    case CYCLOPE_ATTACK_THROW_GROUND:
        return 'Grab_Human_Right';
    }
}

state Attacking {
    function DecideAttack(out float Cooldown) {
        local Vector dirToTarget;
        local Vector targetLoc;
        local float dist;
        local float targetAngle;
        local ECyclopeAttack attack;

        Cooldown = 0.8;

        if( activeTask != none )
            targetLoc = activeTask.location;
        else
            targetLoc = m_CombatTarget.location;

        dirToTarget = Normal2D(targetLoc - m_Pawn.Location);
        dist = VSize2D(targetLoc - m_Pawn.Location);
        targetAngle = NOZDot(Vector(m_Pawn.Rotation), dirToTarget);

        if (dist > m_CombatChaseEndDistance) {
			attack = CYCLOPE_ATTACK_THROW_GROUND;
        }
        else if (restrictedAttack != noRestrictedAttack) {
         	attack = ECyclopeAttack(restrictedAttack);
        }
        else {
            targetAngle = Acos(targetAngle) * (dirToTarget.X < 0 ? -1 : +1) * 57.295776;
            if(debug) Lognotify("Attack Dist: "$dist$", angle: "$targetAngle);
            attack = getSideAttack(targetAngle);
            if (attack == -1) {
                attack = getAttackForDist(dist);
                if (attack == CYCLOPE_ATTACK_SMASH) {
		     	    Cooldown = 0.6;
		     	    m_SmashAttackEnabled = false;
		        	SetTimer(15.0, false, nameof(ResetAttackDual));
		     	}
            }
        }

        m_CurrentAttack = CYCLOPE_ATTACK_FORWARD_2; //attack;
    }

    function ECyclopeAttack getSideAttack(float targetAngle) {
        local ECyclopeAttack attack;

        if (Abs(targetAngle) <= 45) {
         	return -1; // target is infront
        }

        if (targetAngle < -45) {
            if (targetAngle < -75) {
                attack = CYCLOPE_ATTACK_LEFT;
            }
            else {
                attack = CYCLOPE_ATTACK_SIDE_LEFT;
            }
        }
        else if (targetAngle > +45) {
            if (targetAngle > +75) {
                attack = CYCLOPE_ATTACK_RIGHT;
            }
            else {
                attack = CYCLOPE_ATTACK_SIDE_RIGHT;
            }
        }

        return attack;
    }


	// minimal attack distances, if the target is farther away the attack is filtered
	// if the min distances are equal for several attacks, they are used interchangeably based on randomness
    const FOOT_CRUSH_MIN_DIST = 0;
    const FOOT_KICK_MIN_DIST = 0;
    const FORWARD_MIN_DIST = 290; // most lethal at 420
    const FORWARD_2_MIN_DIST = 290; // most lethal at 470
    const SMASH_MIN_DIST = 390; // most lethal at 400 to 500

    /**
    * Returns all forward attacks filtered by the target-distance.
    */
    function ECyclopeAttack getAttackForDist(float dist) {
        local array<AttackToDist> filteredAttacks;
        local array<ECyclopeAttack> attacks;

		filteredAttacks = getFilteredAttackInfos(dist);
		attacks = getLongestRangeAttcksOfEqualDist(filteredAttacks);

        return attacks[Rand(attacks.length)];
    }

    function array<AttackToDist> getFilteredAttackInfos(float dist) {
        local array<AttackToDist> filteredAttacks;
        local AttackToDist attack;

     	attack.Dist = FOOT_CRUSH_MIN_DIST;
		attack.Attack = CYCLOPE_ATTACK_FOOT_CRUSH;
		if (attack.Dist < dist) filteredAttacks.AddItem(attack);
        attack.Dist = FOOT_KICK_MIN_DIST;
		attack.Attack = CYCLOPE_ATTACK_FOOT_KICK;
        if (attack.Dist < dist) filteredAttacks.AddItem(attack);
        attack.Dist = FORWARD_MIN_DIST;
		attack.Attack = CYCLOPE_ATTACK_FORWARD;
        if (attack.Dist < dist) filteredAttacks.AddItem(attack);
        attack.Dist = FORWARD_2_MIN_DIST;
		attack.Attack = CYCLOPE_ATTACK_FORWARD_2;
        if (attack.Dist < dist) filteredAttacks.AddItem(attack);
        attack.Dist = SMASH_MIN_DIST;
		attack.Attack = CYCLOPE_ATTACK_SMASH;
        if (attack.Dist < dist) filteredAttacks.AddItem(attack);

        return filteredAttacks;
    }

    function array<ECyclopeAttack> getLongestRangeAttcksOfEqualDist(array<AttackToDist> filteredAttacks) {
        local array<ECyclopeAttack> attacks;
        local AttackToDist attack;
        local float lastDist;

		foreach filteredAttacks(attack) {
			if(lastDist < attack.Dist) {
				attacks.length = 0;
				lastDist = attack.Dist;
			}
			attacks.addItem(attack.Attack);
        }

        return attacks;
    }
}

state PerformingAttack {
    function PlayAttackAnimation() {
        m_Pawn.PlayCustomAnim(GetAttackSequenceName(m_CurrentAttack));
    }
}

state Dying {
    function bool BeginDeathSequence() {
        m_Pawn.PlayCustomAnim('Die');
        return true;
    }
}

defaultproperties
{
	m_SeeRadius = 50000000
	m_NoticeRadius = 10000000

    m_CombatChaseEndDistance = 600
    m_CombatChaseSprintDistance = 1000

    m_SmashAttackEnabled = true

    debug = false
}
