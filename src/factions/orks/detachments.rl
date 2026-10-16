import board
import source_effects

# Shared selectors for the literal ordinary package rules; never identify a
# faction by the historical roster name. Source: Orks Detachments at
# https://wahapedia.ru/wh40k11ed/factions/orks/
fun orks_package(Board board, Unit unit, OrksDetachment package) -> Bool:
    ref army = board.armies[int(unit.owned_by_player1)]
    return army.faction == ArmyFaction::orks and army.has_detachment(package)

# Named datasheets and explicit keywords describe the same source unit type;
# attached units retain their actual constituent datasheet membership (01.02.07).
fun orks_type(Unit unit, OrksDatasheet tag) -> Bool:
    return unit_matches_datasheet(unit, tag)

# Literal unit groups shared by source clauses; ALL infantry restrictions are
# checked separately from these ANY named alternatives (appendix02.05.01).
fun orks_taktikal_unit(Unit unit) -> Bool:
    return orks_type(unit, OrksDatasheet::boyz) or orks_type(unit, OrksDatasheet::kommandos) or orks_type(unit, OrksDatasheet::stormboyz)

# Wreckas' loot-hunter group excludes unrelated infantry despite army identity.
fun orks_wrecka_unit(Unit unit) -> Bool:
    return orks_type(unit, OrksDatasheet::breaka_boyz) or orks_type(unit, OrksDatasheet::flash_gitz) or orks_type(unit, OrksDatasheet::tankbustas)

# Nazdreg/Nazdreg's Know-wotz gives the whole attached unit Deep Strike.
# Tellyporta Boss is a unit grant excluding Vehicle units, whereas Kill
# Kommanda grants only its attached bearer Infiltrators/Stealth (source cards).
fun orks_unit_grants_ability(Unit unit, AbilityKind kind) -> Bool:
    if kind == AbilityKind::deep_strike:
        for member_index in range(unit.models.size()):
            if model_confers_attached_abilities(unit[member_index]) and unit[member_index].has_ability(AbilityKind::nazdregs_know_wotz):
                return true
        return !unit.has_keyword(Keyword::vehicle) and unit_has_orks_enhancement(unit, OrksEnhancement::tellyporta_boss)
    return false

# Flyin' Headbutt needs the destroyed Aircraft retained until its decision;
# pre-setup casualties with no actual source location cannot use that card.
fun orks_aircraft_death_source(Board board, Model model) -> Bool:
    if !model.has_keyword(Keyword::aircraft):
        return false
    let location = locate_source(board, invalid_entity_identity(), model.identity)
    return location.found and orks_package(board, source_bank_unit(board, location.bank, location.unit.value), OrksDetachment::flyboyz)
