import modifiers

# Shared calculation outputs, not faction state. The core roll pipeline applies
# these terms after rerolls and before the supplied appendix02.02.01 caps.
cls ChargeRollEffects:
    RuleModifiers modifiers
    Bool reroll

cls AdvanceRollEffects:
    RuleModifiers modifiers
    Bool reroll

# These are independent exceptions, captured at the actual move selection
# (core pp32-33/36/58). Granting one never waives another legality check.
cls SelectedMovePermissions:
    Bool charge
    Bool shoot
    Bool start_action

# Objective-specific additional control is a computed result, bounded only for
# native/ML representation. Core p52 keeps it separate from mission scoring.
cls ObjectiveControlEffects:
    LinearlyDistributedInt<0, 65537> additional_control

# InSv is a base permission, not an additive replacement modifier (core p19).
# The caller seeds its printed/common target; contributors may improve it.
cls InvulnerableSavePermission:
    LinearlyDistributedInt<0, MAX_CHARACTERISTIC> target

# Rolled-hit effects may need a window before critical hits turn into automatic
# wounds. Generated hits are a different batch (core pp18/82; ability timing).
cls HitResolutionPolicy:
    Bool before_critical_conversion

# Test success and roll arithmetic are distinct Battle-shock permissions.
# Core still determines test/recovery eligibility (core p30).
cls BattleShockRollEffects:
    Bool automatic_success
    RuleModifiers modifiers

# Additional Hazardous checks count physical uses; they are not damage (p81).
cls HazardousRollEffects:
    FixedStat additional_uses

# Escape's ordinary and additional batches may have different arithmetic.
# An exception waives hazards only; it never permits shooting (core p33).
cls EscapeRollEffects:
    Bool ignore_rolls
    FixedStat additional_rolls
    RuleModifiers ordinary_modifiers
    RuleModifiers additional_modifiers
