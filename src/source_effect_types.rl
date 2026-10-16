import rule_effect_types
import modifiers
import weapons

# Event kinds describe actual core boundaries; source cards install their own
# eligibility/payload rather than synthesizing abilities (pp.28–38/87;17.E).
enum SourceEventKind:
    timing_window
    move_start
    move_end
    attack_selection
    attack_targeted
    attack_end
    shock_start
    shock_end
    model_destroyed
    unit_destroyed

enum SourceSubject:
    own_unit
    friendly_unit
    enemy_unit
    any_unit
    target_unit

enum SourceUseScope:
    army
    unit
    model

enum SourceDuration:
    phase
    turn
    round
    next_own_turn
    battle
    end_next_turn
    # Mek repair persists through Command, ending at the next own Movement start.
    next_own_movement
    next_own_command

enum SourceTarget:
    source_unit
    event_unit
    target_unit
    source_model

enum SourceBank:
    battlefield
    reserves
    embarked

using SourceInstanceID = BInt<0, MAX_SOURCE_INSTANCES>
using SourceEventID = BInt<0, MAX_SOURCE_INSTANCES>
using SourceRuleCode = LinearlyDistributedInt<0, 513>
cls SourceWeaponGrant:
    WeaponRule rule
    LinearlyDistributedInt<0, MAX_WEAPON_SCOPES> weapon_scope
    WeaponCode weapon_name
    WeaponCode profile_name
    Bool physical_scope

using SourceGrant = CharacteristicModifier | IncomingAttackModifier | SourceWeaponGrant | AttackModifierPermission | RuleEffectGrant

cls SourceUseLimits:
    # Zero is unlimited for this interval; combine all four printed limits.
    FixedStat phase
    FixedStat turn
    FixedStat round
    FixedStat battle

# Presentation identity only: source registration stores no owning text.
# UI labels are derived on demand; rule codes/scopes still govern gameplay.
enum SourceLabel:
    none
    war_cry
    permanent_riled_up
    orks_detachment_modifier
    temperamental_shokka
    boss_ammo_runt
    clever_know_wotz
    permanent_orks_option
    keep_huntin
    intimidating_motivation
    bomb_squig
    crude_surgery
    fix_dat_armour_up
    push_dat_bit_back_in
    thievin_scavengers
    shokk_boosta_hazards
    boom_bomb
    burna_bomb
    kunnin_infiltrator
    aerial_manoover
    deff_from_the_shadows
    full_throttle
    get_back_in_da_race
    orks_cargo_enhancement

cls SourceInstance:
    # A recycled source slot cannot satisfy an older pending event.
    SourceEffectKey generation
    EntityIdentity required_embarked_model
    EntityIdentity required_carrier_model
    SourceRuleCode rule
    Hidden<SourceLabel> label
    EntityIdentity source_unit
    EntityIdentity source_model
    Bool owner
    SourceEventKind trigger
    TimingWindow window
    BattlePhase phase
    Bool own_turn_only
    Bool opposing_turn_only
    Bool requires_unengaged
    Bool restrict_movement
    MovementKind movement
    SourceSubject subject
    SourceUseScope use_scope
    SourceUseLimits limits
    Bool disabled
    Bool aura
    # Source-bound own-unit passive, including reserves/passengers (01.02.04).
    Bool own_unit_passive
    # P67: while-leading is retained after bodyguard death; single-model rule
    # activation remains distinct from a conferred unit ability.
    Bool requires_leading
    Bool model_specific_rule
    KeywordPredicate recipient_condition
    Bool optional
    Bool allow_retained_source
    Bool offboard_allowed
    FixedStat trigger_range
    SourceGrant grant
    SourceTarget recipient
    SourceDuration duration
    Bool requires_live_source

cls SourceEvent:
    MovementKind movement
    SourceEventKind kind
    TimingWindow window
    EntityIdentity unit
    EntityIdentity target
    EntityIdentity model

cls SourceUseRecord:
    SourceRuleCode rule
    Bool owner
    SourceUseScope scope
    EntityIdentity subject
    LinearlyDistributedInt<0, MAX_PHASE_STAMP> phase_stamp
    LinearlyDistributedInt<0, MAX_TURN_STAMP> turn_stamp
    LinearlyDistributedInt<0, MAX_ROUNDS> round_stamp
    FixedStat phase_uses
    FixedStat turn_uses
    FixedStat round_uses
    FixedStat battle_uses

cls PendingSourceEvent:
    SourceEffectKey generation
    LinearlyDistributedInt<0, MAX_SOURCE_INSTANCES> source
    SourceEvent event
    Bool resolved

cls SourceEffect:
    SourceEffectKey identity
    LinearlyDistributedInt<0, MAX_SOURCE_INSTANCES> source
    EntityIdentity target_unit
    Bool unit_scope
    CheckedVector<EntityIdentity, MAX_UNIT_MODELS> recipients
    SourceDuration duration
    Bool requires_live_source
    Bool owner
    LinearlyDistributedInt<0, MAX_PHASE_STAMP> phase_stamp
    LinearlyDistributedInt<0, MAX_TURN_STAMP> turn_stamp
    LinearlyDistributedInt<0, MAX_ROUNDS> round_stamp

using SourceInstances = CheckedVector<SourceInstance, MAX_SOURCE_INSTANCES>
using SourceUseRecords = CheckedVector<SourceUseRecord, MAX_SOURCE_INSTANCES>
using PendingSourceEvents = CheckedVector<PendingSourceEvent, MAX_SOURCE_INSTANCES>
using SourceEffects = CheckedVector<SourceEffect, MAX_SOURCE_INSTANCES>

cls SourceLocation:
    Bool found
    SourceBank bank
    LinearlyDistributedInt<0, MAX_UNIT_COUNT> unit

# Source-owned effects may share an operation deadline without sharing keys
# or expiry ownership (appendix01.02.02; core pp16-19).
using ScopedEffectKeys = CheckedVector<SourceEffectKey, MAX_SOURCE_INSTANCES>
