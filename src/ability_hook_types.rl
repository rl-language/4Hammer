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
