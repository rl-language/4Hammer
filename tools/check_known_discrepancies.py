"""Report expected defects without building a separate native test library."""
from ctest_rules import main

if __name__ == '__main__':
    import sys
    raise SystemExit(main(['all', '--suite', 'discrepancies', *sys.argv[1:]]))
