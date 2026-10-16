import state_types

# Optional per-weapon hit provenance. The shared ledger treats tags uniformly;
# catalog entries may identify a faction rule (core hit/destruction pp18/87).
enum AttackHitTag:
    squig_launcha

# Per-activation facts, keyed by stable targets, reusable by every faction.
cls AttackResultRecord:
    EntityIdentity target
    CombatCounter[1] tagged_hits
    CombatCounter successful_hits
    CombatCounter wounds_lost
    Bool destroyed

using AttackResultRecords = CheckedVector<AttackResultRecord, 32>

# A faction requests an attack; core owns execution and shared-frame lifetime.
cls ReactionAttackRequest:
    Bool available
    UnitID source
    UnitID target
    Bool melee
    Bool overwatch
    Bool restrict_target
