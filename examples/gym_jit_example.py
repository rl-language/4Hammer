from rlc import compile
from ml.env import SingleRLCEnvironment, exit_on_invalid_env
from random import choice

# This example shows how to just in time compile the library rules
# and then stick them into a gym like environment.
def main():
    # compile the rules and load the python wrapper
    program = compile(["./src/rules.rl"]) # equivalent to "import wrapper as program"

    # validate environment
    exit_on_invalid_env(program, forced_one_player=True, needs_score=True)

    # wrap the program into a gym friendly environment
    env = SingleRLCEnvironment(program)
    while not env.is_done_underling():
        action_index = env.random_valid_action_index()
        print(program.to_string(env.actions()[action_index]))
        env.step(action_index)

if __name__ == "__main__":
    main()
