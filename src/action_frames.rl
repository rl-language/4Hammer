# Frame storage infrastructure: game subactions are fully delegated, and the
# constructor call graph has no recursive action path. A context owns one slot
# for each duplicated frame type; completed result fields are copied by callers
# when they must outlive reuse. Core sequence pp28-30; this is representation,
# not a tabletop rule. See doc/action-frame-lifetimes.json and the design guide.
cls SharedActionFrames:
    AttackDiceBatch collect_attack_dice
    BattleShockTest battle_shock_test
    Charge charge
    ChooseAttackModifiers choose_attack_modifiers
    ChooseWeaponAbilities choose_weapon_abilities
    CrushingImpact resolve_crushing_impact
    DamageResolution resolve_damage_jobs
    DesperateEscapeTest desperate_escape
    HazardRolls resolve_hazards
    MeleeMove melee_move
    MeleeMoveStep melee_move_step
    MortalWounds resolve_mortal_wounds
    Move move
    Movement movement
    MovementSourceResolution resolve_movement_sources
    NeuralDisruption neural_disruption
    OnModelDestroyed on_model_destroyed
    OrksMobbed resolve_orks_mobbed
    PickFaction pick_army
    PostMoveEmbark post_move_embark
    RegainCoherency regain_coherency
    RevalidateAttackTargets revalidate_attack_targets
    RollStat evaluate_random_stat
    SelectOrksDetachments select_orks_detachments
    SelectOrksWarlord select_orks_warlord
    SelectedFight selected_fight
    SelectedShooting selected_shooting
    ShadowInTheWarp shadow_in_the_warp
    SourceEventResolution resolve_source_event
    Surge surge
    TimingHeroicIntervention timing_heroic_intervention
    TimingOathOfMoment timing_oath_of_moment
    TimingObjectiveStratagem timing_objective_stratagem
    TimingOverwatch timing_overwatch
    TimingRapidIngress timing_rapid_ingress
    TimingSmokescreen timing_smokescreen
    TimingWindowResolution resolve_timing_window
    WeaponStatRoll evaluate_weapon_characteristic
    WoundPrevention prevent_wound_loss
