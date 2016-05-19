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

var bool           m_SmashAttackEnabled;
var ECyclopeAttack m_CurrentAttack;
var Vehicle tookHitFromSW;

`include(Stocks)
`include(Log)
`include(PawnUtils)

event PreBeginPlay() {
	super.PreBeginPlay();
	combatZone.addArea(-8400);
}

state Combating {
    function TurnToTarget(float Angle) {
        local name TurnSeq;
    	super.TurnToTarget(Angle);

        if (Angle < -15) {
            if (Angle <= -60) {
            	if (Angle < -120) {
                   TurnSeq = 'Turn_180_Left';
            	}
            	else {
                   TurnSeq = 'Turn_90_Left';
            	}
            }
            else
                TurnSeq = 'Turn_45_Left';
        }
        else if (Angle > 15) {
            if (Angle >= 60) {
               if (Angle > 120) {
                   TurnSeq = 'Turn_180_Right';
               }
               else{
                   TurnSeq = 'Turn_90_Right';
               }
            }
            else
            	TurnSeq = 'Turn_45_Right';
        }

        m_Pawn.PlayCustomAnim(TurnSeq);
    }
}

state Hit {

    function bool BeginHitSequence(float angle) {
        if (angle < -45) {
            m_Pawn.PlayCustomAnim('Hit_Left');
        }
        else if (angle > +45) {
            m_Pawn.PlayCustomAnim('Hit_Right');
        }
        else if (Abs(angle) > 120) {
            m_Pawn.PlayCustomAnim('Hit_Back');
        }
        else {
            m_Pawn.PlayCustomAnim('Hit_Front');
        }

        return true;
    }

Begin:
    m_pawn.acceleration = vect(0,0,0);
    FinishRotation();

    BeginHitSequence(m_HitAngle);
    FinishAnim(m_Pawn.m_CustomAnimSequence);
    m_NextHitDelay = RandRange(HIT_DEALY_MIN, HIT_DELAY_MAX);
    autoAggro = true;

    if (tookHitFromSW != none && difficulty == EDM_HARD) { //  got hit by a ballista -> destroy it! In normal mode we would do this after stun.
    	RotateTo(tookHitFromSW.location - m_Pawn.location);
		FinishRotation();
		m_Pawn.PlayCustomAnim(GetAttackSequenceName(CYCLOPE_ATTACK_THROW_GROUND), true);
		FinishAnim(m_Pawn.m_CustomAnimSequence);
		tookHitFromSW = none;
	}

    PopState();
}

state Stunned {

	function bool BeginStunSequence() {
		m_Pawn.PlayCustomAnim('Knelling_in', true);
        return true;
    }

    function playIdleStun() {
        m_Pawn.PlayCustomAnim('Knelling_idle', true);
    }

    function EndStunSequence() {
        if (stun_receivedHit)
            m_Pawn.PlayCustomAnim('Die_impaled', true);
        else
			m_Pawn.PlayCustomAnim('Knelling_out', true);
    }

Finished:
    if (tookHitFromSW != none) { // got stunned by a ballista -> destroy it!
    	RotateTo(tookHitFromSW.location - m_Pawn.location);
		FinishRotation();
		m_Pawn.PlayCustomAnim(GetAttackSequenceName(CYCLOPE_ATTACK_THROW_GROUND), true);
		FinishAnim(m_Pawn.m_CustomAnimSequence);
		tookHitFromSW = none;
	}
	GotoState('Idle');
}

static private function name GetAttackSequenceName(ECyclopeAttack attackID) {
    switch (attackID) {
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
    function bool DecideAttack(out float Cooldown, out name seq) {
        local Vector dirToTarget;
        local float dist;
        local float targetAngle;
        local ECyclopeAttack attack;

        Cooldown = 0.8;

        GetPawnRelations(m_pawn, activeTask != none ? activeTask : m_CombatTarget, targetAngle, dirToTarget, dist);

        if (dist > m_CombatChaseEndDistance) {
			attack = CYCLOPE_ATTACK_THROW_GROUND;
        }
        else if (restrictedAttack != noRestrictedAttack) {
         	attack = ECyclopeAttack(restrictedAttack);
        }
        else {
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

        m_CurrentAttack = attack;

        seq = GetAttackSequenceName(m_CurrentAttack);
        return true;
    }

    function ECyclopeAttack getSideAttack(float targetAngle) {
        local ECyclopeAttack attack;

        if (Abs(targetAngle) <= 45) {
         	return -1; // target is infront
        }

        if (targetAngle < -45) {
            if (targetAngle < -60) {
                attack = CYCLOPE_ATTACK_SIDE_LEFT;
            }
            else {
                attack = CYCLOPE_ATTACK_LEFT;
            }
        }
        else if (targetAngle > +45) {
            if (targetAngle > +60) {
                attack = CYCLOPE_ATTACK_SIDE_RIGHT;
            }
            else {
                attack = CYCLOPE_ATTACK_RIGHT;
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

function ResetAttackDual() {
	m_SmashAttackEnabled = true;
}

defaultproperties
{
	m_SeeRadius = 50000000
	m_NoticeRadius = 10000000

    m_CombatChaseEndDistance = 600
    m_CombatChaseSprintDistance = 1000

    m_SmashAttackEnabled = true
}
