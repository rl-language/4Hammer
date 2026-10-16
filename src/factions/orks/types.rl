import rule_effect_types
import state_types

# Source: https://wahapedia.ru/wh40k11ed/factions/orks/ (Army Rules).
# Keep these choices in the same controller group as other start-window rules.
enum OrksTimingRule:
    war_cry
    da_boss

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

using OrksEnhancements = CheckedVector<OrksEnhancement, 4>



# Attack-end reactions retain actual per-target hits/lost wounds, not merely
# declarations. Stable identities survive model/unit bank transitions (p87).

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
    RoundResourceBudget budget
    PhaseStamp roar_phase
    PhaseStamp visions_phase

# Vindictive Artillerists offers the printed three alternatives.
enum OrksArtilleristMode:
    lethal
    sustained
    both_hazardous

# The selected engine lasts to next own Command, including offboard time.
# No point/CP expenditure or unstated bonus is introduced.
# https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek (Full Throttle).
enum OrksEngine:
    turbo
    shokk
    pulse

# Free Movement abilities keep independent printed limits and eligibility.
# Target choice is checked BEFORE acceptance to prevent empty mandatory steps.
# Sources: Orks/{Ghazghkull-Thraka,Kommandos,Warbuggies,Weirdboy}.
enum OrksDatasheetMoveAbility:
    makari
    found_em
    drive_by_skorchin
    da_jump

# Rule codes retain per-original-unit token history through attachments and
# revival. Source: Orks/Painboy, Painboss, Big-Mek-In-Mega-Armour, Tankbustas.
const ORKS_SURGERY_RULE = 120

const ORKS_ARMOUR_REPAIR_RULE = 121

const ORKS_PAINBOSS_RULE = 122

const ORKS_MEK_REPAIR_RULE = 123

const ORKS_ORDERLY_RULE = 124

const ORKS_RUNTHERD_RULE = 125

const ORKS_PULSA_RULE = 126

const ORKS_SCAVENGERS_RULE = 127

const ORKS_SHOKK_BOOST_RULE = 128

# Shared rule codes are infrastructure for the printed per-army-round and
# per-unit-battle limits. Beastboss on Squigosaur must reuse110 in its adapter.
# Sources: Orks/Beastboss Keep Huntin'; Orks/Squighog-Boyz Bomb Squig.
const ORKS_KEEP_HUNTIN_RULE = 110

# Standard Warboss card, borrowed by Boss Boomer with its own army-round use.
const ORKS_INTIMIDATING_RULE = 112

const ORKS_BOMB_SQUIG_RULE = 111
