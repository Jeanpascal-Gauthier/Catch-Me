# Procgen harness entry point.

require_relative "config"
require_relative "input"
require_relative "generation"
require_relative "pathfinding"
require_relative "npc"
require_relative "camera"
require_relative "rendering"
require_relative "tests"

# DragonRuby calls this once on launch.
def boot args
  args.state = {}
end

# DragonRuby calls this every frame.
def tick args
  init args
  handle_input args

  rebuilding_map = args.state.field_dirty || args.state.map_dirty
  regenerate args
  spawn_npcs args if args.state.npcs.nil? || rebuilding_map

  update_npcs args
  update_camera args
  render args

end

# One-time setup of args.state, run on the first tick (and after a reset).
def init args
  return if args.state.ready

  args.state.ready       = true
  args.state.seed        = $seed
  args.state.threshold   = $threshold
  args.state.warp        = true
  args.state.mask        = false
  args.state.cull        = true
  args.state.show_culled = true
  args.state.field_dirty = true
  args.state.map_dirty   = true
  args.state.regions     = 0
  args.state.largest     = 0
  args.state.open_count  = 0

  init_camera args
end

# Clears state so the next tick's init rebuilds everything from scratch.
def reset args
  args.state = {}
end

DR.reset
