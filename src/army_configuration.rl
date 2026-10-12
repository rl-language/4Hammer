import state_types

# Army identity is independent of a legacy roster and selected detachments
# (Orks source: https://wahapedia.ru/wh40k11ed/factions/orks/).
enum ArmyFaction:
    unspecified
    space_marines
    tyranids
    chaos_space_marines
    orks
    adeptus_custodes

    fun equal(ArmyFaction other) -> Bool:
        return self.value == other.value

    fun not_equal(ArmyFaction other) -> Bool:
        return self.value != other.value

# All ordinary Orks packages, without the older Boarding Actions variants.
# The user's three-package limit replaces DP accounting; none is not a pick.
enum OrksDetachment:
    none
    war_horde
    madcap_meks
    wurrband
    runt_swarm
    wreckas
    brute_bosses
    bully_boyz
    da_big_hunt
    dread_mob
    shoota_boyz
    flyboyz
    kult_of_speed
    blitz_brigade
    green_tide
    taktikal_brigade

    fun equal(OrksDetachment other) -> Bool:
        return self.value == other.value

    fun not_equal(OrksDetachment other) -> Bool:
        return self.value != other.value

# Default preserves explicitly configured p.68 fixtures; public play selects
# the user's point-free mode, without introducing a substitute percentage.
enum ReserveBudgetMode:
    points_required
    point_free

    fun equal(ReserveBudgetMode other) -> Bool:
        return self.value == other.value

    fun not_equal(ReserveBudgetMode other) -> Bool:
        return self.value != other.value

# Bounded enum collection gives the inferred ML layout exactly three slots.
# No cost fields or custom lifecycle hooks: the user excludes points/DP.
cls ArmyConfiguration:
    ArmyFaction faction
    CheckedVector<OrksDetachment, 3> detachments
    ReserveBudgetMode reserve_budget

    # Gate a package by actual selection, not roster name or an implicit DP
    # budget (Orks detachment sections at the URL above).
    fun has_detachment(OrksDetachment detachment) -> Bool:
        let found = false
        for selected in range(self.detachments.size()):
            found = found or self.detachments[selected] == detachment
        return found

    # Enum's none value and duplicates cannot consume selection slots;
    # non-Orks cannot select an Orks package (user limit; faction source).
    fun detachment_selection_valid(OrksDetachment detachment) -> Bool:
        return self.faction == ArmyFaction::orks and detachment.value > 0 and detachment.value <= OrksDetachment::taktikal_brigade.value and self.detachments.has_capacity() and !self.has_detachment(detachment)

    # Invalid picks are atomic and do not erase an earlier legal selection.
    # This is configuration infrastructure for the user's maximum of three.
    fun record_detachment(OrksDetachment detachment) -> Bool:
        if !self.detachment_selection_valid(detachment):
            return false
        self.detachments.append(detachment)
        return true

# Saved configuration must not bypass faction, enum, duplicate or capacity
# checks; infrastructure for stable policies/saves (source above; core p.8).
fun army_configuration_valid(ArmyConfiguration army) -> Bool:
    if army.faction.value < 0 or army.faction.value > ArmyFaction::adeptus_custodes.value or army.reserve_budget.value < 0 or army.reserve_budget.value > ReserveBudgetMode::point_free.value:
        return false
    if army.faction != ArmyFaction::orks and !army.detachments.empty():
        return false
    for entry in range(army.detachments.size()):
        if army.detachments[entry].value <= 0 or army.detachments[entry].value > OrksDetachment::taktikal_brigade.value:
            return false
        for earlier in range(entry):
            if army.detachments[earlier] == army.detachments[entry]:
                return false
    return true
