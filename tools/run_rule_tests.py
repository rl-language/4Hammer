"""Execute every Python assertion using the existing Godot Rulebook library."""
from ctest_rules import main

if __name__ == '__main__':
    import sys
    raise SystemExit(main(['all', *sys.argv[1:]]))
