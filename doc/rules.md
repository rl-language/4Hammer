# rules.rl


### Actions 

* act `evaluate_random_stat(frm Stat, frm Int) -> RollStat`


   * act `quantity(Dice dice)`

* act `rerollable_pair_dices_roll(ctx Board, frm Bool, frm Bool, frm Bool, frm Int) -> RerollableDicePair`


   * act `roll_pair(frm Dice result, frm Dice result2)`

   * act `keep_it(Bool do_it)`

   * act `reroll_pair(Dice new_value, Dice new_value2)`

* act `rerollable_dice_roll(ctx Board, frm Bool, frm Bool, frm Bool, frm Int) -> RerollableDice`


   * act `roll(frm Dice result)`

   * act `keep_it(Bool do_it)`

   * act `reroll(Dice new_value)`

* act `single_attack(ctx Board, ctx Unit, ctx Unit) -> SingleAttack`


   * act `allocate_wound(frm ModelID id)`

        ```
 autohit attacks
 sixes trigger a explosive hits
```
* act `on_model_destroyed(ctx Board, ctx Unit, ctx Model) -> OnModelDestroyed`


   * act `skip()`

   * act `use_violent_unbidding()`

   * act `roll(frm Dice dice)`

   * act `roll(frm Dice damage)`

* act `resolve_weapon(ctx Board, frm Int, frm Int, frm Int) -> ResolveWeapon`


* act `resolve_model_attack(ctx Board, frm UnitID, frm UnitID, frm Int, frm Bool) -> ModelAttack`


   * act `select_weapon(BInt<0, MAX_WEAPONS> weapon_id)`

   * act `skip()`

* act `use_attack_stratagems(ctx Board, frm UnitID, frm UnitID, frm Bool) -> UseAttackStratagems`


   * act `no_defensive_stratagem()`

   * act `tough_as_squig_hide()`

   * act `use_gene_wrought_resiliance()`

   * act `use_daemonic_fervour()`

   * act `use_unyielding()`

   * act `no_offensive_stratagem()`

   * act `use_veteran_instincts()`

   * act `use_dark_pact()`

   * act `select_ability(Bool use_letal_hits)`

   * act `use_swift_kill()`

   * act `use_vindictive_strategy()`

   * act `use_sacrificial_dagger()`

   * act `select_model(frm ModelID model)`

   * act `use_dacatarai_stance()`

   * act `use_rendax_stance()`

* act `attack(ctx Board, frm UnitID, frm UnitID, frm Bool, frm Bool) -> Attack`


   * act `select_model(ModelID model)`

   * act `roll(Dice result)`

        ```
 ToDo: handle non character version
```
* act `spawn_unit(ctx Board) -> PickUnit`


   * act `spawn(frm ProfileToUse profile)`

   * act `set_owner(frm Player player)`

   * act `place_in_reserve()`

   * act `place_at(frm BoardPosition position)`

* act `battle_shock_test(ctx Board, ctx Unit) -> BattleShockTest`


   * act `insane_bravery(Bool do_it)`

* act `battle_shock_step(ctx Board) -> BattleShockStep`


* act `shadow_in_the_warp(ctx Board, frm Bool) -> ShadowInTheWarp`


   * act `use_shadow_in_the_warp(Bool do_it)`

* act `neural_disruption(ctx Board) -> NeuralDisruption`


   * act `select_neural_disruption_target(frm UnitID target)`

   * act `skip()`

* act `command_phase(ctx Board) -> CommandPhase`


   * act `select_oath_of_moment_target(frm UnitID unit)`

        ```
 offer to play shadow in the warp to both players
```
   * act `skip()`

   * act `use_duty_and_honour(frm BInt<0, 4> objective)`

   * act `use_pheromone_trail(frm BInt<0, 4> phero_objective)`

   * act `skip()`

* act `overwatch(ctx Board, frm UnitID) -> Overwatch`


   * act `skip()`

   * act `overwatch(frm UnitID source)`

* act `move(ctx Board, ctx UnitID, frm Int) -> Move`


   * act `move_to(BoardPosition position)`

* act `fight_step(ctx Board, frm Bool) -> FightStep`


   * act `end_fight_step()`

   * act `select_target(frm UnitID source, frm UnitID target)`

* act `fight_phase(ctx Board) -> FightPhase`


   * act `use_bestial_bellow(frm UnitID unit, frm UnitID target)`

   * act `skip()`

* act `charge(ctx Board, frm UnitID, frm UnitID, Bool) -> Charge`


* act `charge_phase(ctx Board) -> ChargePhase`


   * act `end_charge()`

   * act `select_target(frm UnitID source, frm UnitID target)`

   * act `skip()`

        ```
 before charge stratagems
```
   * act `use_overawing_magnificence()`

   * act `skip()`

        ```
 after charge stratagem
```
   * act `use_heroic_intervention(frm UnitID interceptor)`

* act `reserve_deployment(ctx Board, frm Bool) -> ReserveDeployment`


   * act `nothing_to_deploy()`

   * act `select_reserve_unit(frm UnitID id)`

   * act `place_at(BoardPosition position)`

   * act `nothing_to_deploy()`

* act `desperate_escape(ctx Board, frm UnitID) -> DesperateEscapeTest`


   * act `use_predators_not_prey(Bool do_it)`

* act `movement(ctx Board, frm UnitID, frm Bool) -> Movement`


   * act `advance(Bool do_it)`

* act `movement_phase(ctx Board) -> MovementPhase`


   * act `end_move()`

   * act `move_unit(frm UnitID id)`

   * act `use_gilded_spear(Bool do_it)`

        ```
 stratagems
```
* act `shooting_phase(ctx Board) -> ShootingPhase`


   * act `end_shooting_phase()`

   * act `select_target(frm UnitID source, frm UnitID target)`

* act `turn(ctx Board, frm Bool) -> Turn`


* act `round(ctx Board) -> Round`


* act `attach_leaders(ctx Board) -> AttachLeaderStep`


   * act `done_attaching()`

   * act `attack_character(frm UnitID unit_id, frm UnitID char_id)`

* act `deploy(ctx Board) -> Deployment`


   * act `done_deploying()`

   * act `select_unit(frm UnitID unit_id)`

   * act `deploy_at(BoardPosition position)`

* act `battle(ctx Board) -> Battle`


* act `attack_sequence(ctx Board, frm Bool, frm Bool) -> AttackSequence`


   * act `select_target(UnitID source, UnitID target)`

* act `pick_army(ctx Board, frm Bool) -> PickFaction`


   * act `pick_strike_force_octavious()`

   * act `pick_insidious_infiltrators()`

   * act `pick_zarkan_deamonkin()`

   * act `pick_morgrim_butcha()`

   * act `pick_tristean_gilded_blade()`

   * act `pick_vengeful_brethren()`

* act `play() -> Game`


* act `play2() -> Game2`


   * act `spawn_unit()`

   * act `skip()`

   * act `only_shoot()`

   * act `only_overwatch()`

   * act `only_melee_attack()`

   * act `fullgame()`


### Free functions

* fun `required_wound_roll(Board board, AttackSequenceInfo info)  -> Int`
* fun `get_hit_roll_bonus(Board board)  -> Int`
* fun `deployment_position_valid(Board board, BoardPosition position, Bool current_player, Bool infiltrates)  -> Bool`
* fun `set_state<T>(T g, String s)  -> Bool`
* fun `main()  -> Int`
* fun `get_num_players()  -> Int`
* fun `max_game_lenght()  -> Int`
* fun `gen_methods() `
* fun `fuzz(Vector<Byte> input) `
* fun `pretty_print(Game game) `
* fun `pretty_string<T>(Board b, T obj)  -> String`
* fun `score(Game g, Int player_id)  -> Float`
* fun `get_current_player(Game g)  -> Int`
* fun `log_alive_models_player1(Game g)  -> Int`
* fun `log_alive_models_player2(Game g)  -> Int`
