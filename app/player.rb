# The player-controlled entity. Like an NPC it is a plain Hash with :x, :y
# in tile space, but it has no path: it moves from keyboard input instead.

# Places the player on a random FLOOR tile, avoiding tiles the NPCs already
# occupy. Runs at boot and again on every map rebuild, since the old position
# may be inside a wall once the map changes.
def spawn_player args
  cells      = args.state.cells
  accessible = []
  cells.each_with_index { |c, i| accessible << i if c == FLOOR }

  if accessible.empty?
    args.state.player = nil
    return
  end

  taken = args.state.npcs.map { |npc| npc[:y].round * GRID_W + npc[:x].round }
  idx   = pick_unused_tile accessible, taken

  args.state.player = { x: (idx % GRID_W).to_f,
                        y: idx.idiv(GRID_W).to_f }

  snap_camera args
end

def update_player args
  player = args.state.player
  return if player.nil?

  dir = player_direction args
  return if dir.nil?

  cells = args.state.cells
  step  = PLAYER_SPEED * TICK_SECONDS

  # Each axis is resolved separately so walking into a wall at an angle
  # slides along it rather than stopping dead.
  nx = player[:x] + dir[0] * step
  player[:x] = nx if player_fits? cells, nx, player[:y]

  ny = player[:y] + dir[1] * step
  player[:y] = ny if player_fits? cells, player[:x], ny
end

# WASD as a unit vector, so diagonals aren't faster than the cardinals.
# Arrow keys are deliberately left alone -- they tune seed and threshold.
def player_direction args
  k  = args.inputs.keyboard
  dx = 0.0
  dy = 0.0

  dx -= 1.0 if k.key_held.a
  dx += 1.0 if k.key_held.d
  dy -= 1.0 if k.key_held.s
  dy += 1.0 if k.key_held.w

  return nil if dx == 0.0 && dy == 0.0

  length = Math.sqrt(dx * dx + dy * dy)
  [dx / length, dy / length]
end

# The player fills one tile, so a position between tiles overlaps up to four
# of them. All four corners have to be clear for the move to be allowed.
def player_fits? cells, x, y
  inset = 0.02

  floor_at?(cells, x + inset,     y + inset) &&
    floor_at?(cells, x + 1 - inset, y + inset) &&
    floor_at?(cells, x + inset,     y + 1 - inset) &&
    floor_at?(cells, x + 1 - inset, y + 1 - inset)
end

def floor_at? cells, x, y
  cx = x.floor
  cy = y.floor
  return false if cx < 0 || cy < 0 || cx >= GRID_W || cy >= GRID_H

  cells[cy * GRID_W + cx] == FLOOR
end
