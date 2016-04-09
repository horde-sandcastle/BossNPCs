class BossNPC_CyclopeAI extends BossNPC_AIBase;

enum ECyclopeAttack
{
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

var name m_CurrentTurnSeqName;

var bool           m_SmashAttackEnabled;
var ECyclopeAttack m_CurrentAttack;

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
        local int rr;

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
        else if( restrictedAttack != noRestrictedAttack ) {
         	attack = ECyclopeAttack(restrictedAttack);
        }
        else {
	        if (m_SmashAttackEnabled && targetAngle > 0.7  && dist >= 260) {
	            attack = CYCLOPE_ATTACK_SMASH;
	        }
	        else {
	            targetAngle = Acos(targetAngle) * (dirToTarget.X < 0 ? -1 : +1) * 57.295776;

	            if (Abs(targetAngle) <= 45)
	            {
	                rr = Rand(11);

	                if (rr < 3)
	                {
	                    attack = CYCLOPE_ATTACK_FOOT_CRUSH;
	                }
	                else
	                if (rr < 5)
	                {
	                    attack = CYCLOPE_ATTACK_FOOT_KICK;
	                }
	                else
	                if (rr < 7)
	                {
	                    attack = CYCLOPE_ATTACK_FORWARD;
	                }
	                else
	                {
	                    attack = CYCLOPE_ATTACK_FORWARD_2;
	                }
	            }
	            else
	            {
			        if (targetAngle < -45)
			        {
		                if (targetAngle < -75)
		                {
	                        attack = CYCLOPE_ATTACK_LEFT;
		                }
		                else
		                {
	                        attack = CYCLOPE_ATTACK_SIDE_LEFT;
		                }
			        }
			        else
			        if (targetAngle > +45)
			        {
	                    if (targetAngle > +75)
	                    {
	                        attack = CYCLOPE_ATTACK_RIGHT;
	                    }
	                    else
	                    {
	                        attack = CYCLOPE_ATTACK_SIDE_RIGHT;
	                    }
			        }
	            }
	        }
        }

        if (attack == CYCLOPE_ATTACK_SMASH) {
     	    Cooldown = 0.6;
     	    m_SmashAttackEnabled = false;
        	SetTimer(15.0, false, nameof(ResetAttackDual));
     	}
     	else {
     	    Cooldown = 0.8;
     	}

        m_CurrentAttack = attack;
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

    m_CombatChaseEndDistance = 410
    m_CombatChaseSprintDistance = 1000

    m_SmashAttackEnabled = true
}
