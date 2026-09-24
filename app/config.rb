# Procgen configuration and shared cell states.

GRID_W  = 84
GRID_H  = 84
CELL_PX = 8
MAP_X   = 24
MAP_Y   = 24
HUD_X   = 724

# --- tune these, save, compare -----------------------------------------
SPAN       = 0.9   # width of the sampled window in noise units. keep < 2.0
LACUNARITY = 4.0   # frequency multiplier per octave
GAIN       = 0.45  # amplitude multiplier per octave
OCTAVES    = 4     # how many layers of detail
WARP       = 0.12  # domain warp strength
WARP_OCT   = 2     # octaves used for the warp fields
WARP_SHIFT = 0.15  # how far along the plane normal the warp fields are read
MASK_GAIN  = 1.5   # island falloff strength
MASK_POWER = 2.2   # island falloff curve
# -----------------------------------------------------------------------

WALL      = 0
FLOOR     = 1
DISCARDED = 2

# DragonRuby ticks at a fixed rate rather than handing game code a variable
# frame delta, so TICK_SECONDS stands in for dt: moving some tiles/second
# speed times TICK_SECONDS every tick is the fixed-timestep equivalent of
# scaling by delta time -- it keeps speed independent of frame rate even
# though it isn't reacting to a per-frame value, since DR doesn't expose one.
TICK_SECONDS = 1.0.fdiv 60

NPC_COUNT           = 3     # number of wandering NPCs to spawn
NPC_SPEED           = 4.0   # tiles per second
NPC_DEBUG_WAYPOINTS = false # draw each NPC's private waypoint (dev only)

$seed      ||= 1
$threshold ||= 0.02
