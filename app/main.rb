# Procgen harness entry point.

require_relative "config"
require_relative "input"
require_relative "generation"
require_relative "rendering"

# DragonRuby calls this once on launch.
def boot args
  args.state = {}
end

# DragonRuby calls this every frame.
def tick args
  init args
  handle_input args
  regenerate args
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
end

# Clears state so the next tick's init rebuilds everything from scratch.
def reset args
  args.state = {}
end

DR.reset
