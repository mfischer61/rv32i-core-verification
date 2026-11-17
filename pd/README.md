# slack_rank.py: rank the worst timing paths

From the Physical Design onboarding. A full `report_timing` dump is thousands of lines; this
script parses every path and answers the two questions I actually had: which paths are worst,
and where do the violations cluster. Built with Claude Code as my coding agent.

**How it works**
1. Splits the report into path blocks (Innovus `Path N: VIOLATED Setup Check ...` headers, or
   Synopsys/OpenSTA `Startpoint:` blocks).
2. Pulls out startpoint, endpoint, check type (setup, hold, clock-gating setup), and slack.
3. Sorts each check type by slack, worst first, and prints WNS, TNS, and the top N paths.
4. Groups violating endpoints by register (drops the bit index) to show clustering, e.g. all
   bits of `registers_reg_21` failing together on one high-fanout net.

**Generating the input in Innovus**
```tcl
report_timing -max_paths 2000 -nworst 1 > setup.rpt
report_timing -early -max_paths 2000 -nworst 1 > hold.rpt
```

**Running it**
```bash
python3 slack_rank.py setup.rpt hold.rpt              # top 10 setup + top 10 hold
python3 slack_rank.py setup.rpt hold.rpt -n 20 --csv worst.csv
python3 slack_rank.py examples/sample_setup.rpt examples/sample_hold.rpt   # demo
```
`examples/` holds small sample reports in both formats for trying the parser.
