# Procgen configuration and shared cell states.
GRID_W  = 84
GRID_H  = 84
CELL_PX = 8

MAP_X   = 16
MAP_Y   = 16
VIEW_W  = 1072             # play pane, anchored at MAP_X, MAP_Y
VIEW_H  = 688
HUD_X   = 1104             # narrow strip between the pane and the screen edge

# -----------------------------------------------------------------------
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

TICK_SECONDS = 1.0.fdiv 60

ENTITY_COLORS = [[214, 64, 64],    # red
                 [86, 190, 96],    # green
                 [76, 132, 235],   # blue
                 [232, 198, 66]]   # yellow

NPC_COUNT           = 3     
NPC_SPEED           = 16   
NPC_DEBUG_WAYPOINTS = false

PLAYER_SPEED = 20

TAG_COOLDOWN = 60
TAG_RADIUS = 0.75

# How a tag hands over, tuned so the swap reads rather than just happening.
CAMERA_SWITCH_TICKS = 30   # camera eases to the new block over this long
TAG_SLOWMO_TICKS    = 10   # everything crawls this long after a tag
TAG_SLOWMO_FACTOR   = 0.2  # speed multiplier at the instant of the tag

$seed      ||= 1
$threshold ||= 0.02
