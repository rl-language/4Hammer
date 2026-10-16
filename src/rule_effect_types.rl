import state_types

# Shared finite source-owned permissions and effect parameters (01.02.02).
# Catalog entries may name faction effects; only those adapters interpret them.
enum RuleEffectKind:
    none
    melee_lethal
    ranged_lethal
    ranged_assault
    ranged_sustained
    rapid_fire_increment
    cleave_increment
    reroll_hits_ones
    reroll_hits_all
    reroll_hits_fly
    wound_bonus_non_monster_vehicle
    close_range_ap
    deck_hit_bonus
    fail_hits_one_to_three
    strong_wound_protection
    all_wound_protection
    advance_plus_two
    action_move_permission
    force_desperate_escape
    hunt_escape_hazards
    assault_disembark
    fight_on_death_four
    fight_on_death_dread
    automatic_shock_success
    snotling_leadership_penalty
    fights_first
    mobile
    no_charge
    grot_shield
    unbridled_attacks
    button_attacks
    button_strength
    button_ap
    button_hazard
    shokka_torrent
    shokka_attacks
    shokka_sustained
    shokka_destroy
    ranged_hazardous
    vindictive_all
    armed_to_da_teef
    invulnerable_save
    lifted
    hit_plus_one
    borrowed_keep_huntin
    borrowed_intimidation
    ammo_runts_hit
    boss_ammo_hit
    rokkit_charge
    clever_hit
    pulsa_target
    burna_mark
    found_detection
    wobbled
    grounded
    covered_squigs
    busted
    overwatch_blocked
    beastscent
    psychic_warpath
    weirdboy_warpath
    deep_strike
    turbo_engine
    shokk_engine
    pulse_engine
    pulse_defence
    no_action

cls RuleEffectGrant:
    SourceEffectKey source_effect
    RuleEffectKind kind
    FixedStat amount
    EntityIdentity associated_unit

using RuleEffectGrants = CheckedVector<RuleEffectGrant, MAX_MODEL_RULE_EFFECTS>
