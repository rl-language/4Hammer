# Core timing flags are a typed context instead of a raw array parameter;
# this keeps native/Godot pointer types aligned without changing their meaning.
cls CoreTimingProgress:
    Bool[9] resolved

# Finite extension storage for one controller timing window. The shared
# algorithm treats its contents as adapter-owned; ML/save layout remains explicit.
cls FactionTimingProgress:
    Bool[2] orks_rules

# Explicit pending faction charge effects; their meaning stays in the adapter.
cls FactionChargeProgress:
    Bool mobbed
    Bool impetus

