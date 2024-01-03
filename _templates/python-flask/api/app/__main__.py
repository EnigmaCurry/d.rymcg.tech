# main is actually in __init__.py
# but this file exists to make the runpy module happy.
# https://docs.python.org/3/library/runpy.html#module-runpy

from . import main
main()
