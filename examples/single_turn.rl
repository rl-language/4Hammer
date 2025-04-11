import rules
import game_utils

# a whole game, including army selection
@classes
act play() -> Game:
    frm board : Board
    subaction*(board) p1 = pick_army(board, false)
    subaction*(board) p2 = pick_army(board, true)
    subaction*(board) attach_leaders = attach_leaders(board)
    subaction*(board) deploy = deploy(board)
    subaction*(board) round = round(board)

# maximize the number of your models vs those of the opponent
fun score(Game g, Int player_id) -> Float:
    return float(g.board.count_models(1 - player_id) - g.board.count_models(1 - player_id)) / 40.0

fun get_current_player(Game g) -> Int:
    return default_get_current_player(g)

fun log_alive_models_player1(Game g) -> Int:
    return g.board.count_models(0)

fun log_alive_models_player2(Game g) -> Int:
    return g.board.count_models(1)

fun get_num_players() -> Int:
    return 2

fun max_game_lenght() -> Int:
    return 5000

fun pretty_print(Game game):
    print_indented(game)

