# Keyboard input and state changes.

def handle_input args
  k = args.inputs.keyboard
  t = args.state.tick_count

  set_seed args, Numeric.rand(100_000) if k.key_down.r

  set_seed args, args.state.seed + 1 if repeating?(k.key_down.right, k.key_held.right, t)
  set_seed args, args.state.seed - 1 if repeating?(k.key_down.left, k.key_held.left, t)

  if repeating?(k.key_down.up, k.key_held.up, t)
    set_threshold args, args.state.threshold + 0.01
  end

  if repeating?(k.key_down.down, k.key_held.down, t)
    set_threshold args, args.state.threshold - 0.01
  end

  # Not W: that moves the player.
  if k.key_down.o
    args.state.warp = !args.state.warp
    args.state.field_dirty = true
  end

  if k.key_down.i
    args.state.mask = !args.state.mask
    args.state.field_dirty = true
  end

  if k.key_down.f
    args.state.cull = !args.state.cull
    args.state.map_dirty = true
  end

  if k.key_down.tab
    args.state.show_culled = !args.state.show_culled
    args.state.map_dirty = true
  end
end

# Tap for one step, hold to repeat.
def repeating? down, held, tick
  down || (held && tick % 4 == 0)
end

# Updates the seed in state and the hot-reload-surviving global, then
# flags the noise field for regeneration.
def set_seed args, value
  args.state.seed = value
  $seed = value
  args.state.field_dirty = true
end

# Updates the threshold in state and the hot-reload-surviving global, then
# flags the map for regeneration (the field itself does not need redoing).
def set_threshold args, value
  value = value.clamp(-2.0, 2.0)
  args.state.threshold = value
  $threshold = value
  args.state.map_dirty = true
end
