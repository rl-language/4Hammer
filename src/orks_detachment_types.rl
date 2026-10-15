import state_types

# Source IDs for all38 ordinary enhancements/upgrades. Prices are deliberately
# absent by user instruction; eligibility and usage are separate game rules.
# https://wahapedia.ru/wh40k11ed/factions/orks/ (ordinary Detachments)
enum OrksEnhancement:
    none
    headwoppas_killchoppa
    da_boss_is_watchin
    kunnin_but_brutal
    follow_me_ladz
    ferocious_show_off
    ardboyz
    wimp_kickaz
    tellyporta_boss
    extra_sneaky
    minefield_detail
    supa_glowy_fing
    targetin_squigs
    kill_kommanda
    throat_slittas
    kaptins_hat
    supa_snazz_dakka
    glory_hog
    it_came_from_da_drops
    mekwaaagh_mastermind
    temperamental_shokka
    enhanced_runt_maw
    cybork_boosta
    dreadherder
    targetin_gizmos
    boss_boomer
    smoky_gubbinz
    competitive_streak
    flyboss
    impulsive_recon
    surly_as_a_squiggoth
    brutal_but_kunnin
    blitzboss
    proper_killy
    morgogs_finkin_cap
    da_gobshot_thunderbuss
    da_krunch
    eadbanger
    warphead

# Source-owned non-characteristic effects share the existing expiry/identity
# machinery (appendix01.02.02). Numeric modifications still use ordered core
# modifiers; these flags describe permissions or target-dependent rules.
enum OrksEffectKind:
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
    invulnerable_four
    lifted
    hit_plus_one
    borrowed_keep_huntin
    borrowed_intimidation
    invulnerable_five
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
    jump_deep_strike
    turbo_engine
    shokk_engine
    pulse_engine
    pulse_defence
    no_action

cls OrksEffectGrant:
    SourceEffectKey source_effect
    OrksEffectKind kind
    FixedStat amount
    EntityIdentity associated_unit

using OrksEnhancements = CheckedVector<OrksEnhancement, 4>
using OrksEffectGrants = CheckedVector<OrksEffectGrant, MAX_ORKS_MODEL_EFFECTS>

# Attack-end reactions retain actual per-target hits/lost wounds, not merely
# declarations. Stable identities survive model/unit bank transitions (p87).
cls OrksAttackRecord:
    EntityIdentity target
    CombatCounter squig_launcha_hits
    CombatCounter successful_hits
    CombatCounter wounds_lost
    Bool destroyed

using OrksAttackRecords = CheckedVector<OrksAttackRecord, 32>

# Source choice domains stay finite; model/unit inputs are separate editor
# decisions, rather than a Cartesian product of every selector and rule.
enum OrksDetachmentAbility:
    da_boss_is_watchin
    dreadherder
    roar_of_mork
    visions_of_violence
    morgogs_finkin_cap
    surly_as_a_squiggoth
    kaptins_hat

# Per-unit psychic level is spent once per ability per phase and per round,
# including offboard transfers (Orks Unstable Energies; appendix22.03.01).
cls OrksPsychicUsage:
    LinearlyDistributedInt<0, MAX_ROUNDS> round_stamp
    FixedStat spent
    PhaseStamp roar_phase
    PhaseStamp visions_phase

# Vindictive Artillerists offers the printed three alternatives.
enum OrksArtilleristMode:
    lethal
    sustained
    both_hazardous
