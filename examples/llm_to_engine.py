from engine_driver import GodotClient
from time import sleep
from rlc import run_game, make_llm, GeminiStateless
from command_line import make_rlc_argparse, load_program_from_args, get_included_conents_from_args

def main():
    parser = make_rlc_argparse("llm_to_engine", "run a llm and sends action to engine")
    args = parser.parse_args()
    with load_program_from_args(args) as program:
        client = GodotClient(program)
        llm = GeminiStateless(program,model="gemini-2.0-flash")
        rules = get_included_conents_from_args(args)
        for (action, thought) in run_game(llm=llm, program=program, rules=rules):
            client.send_action(action)
            if len(thought) == 0:
                continue
            client.send_text_to_display(thought)
            sleep(1)


if __name__ == "__main__":
    main()
