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
                        y: idx.idiv(GRID_W).to_f,
                        color: ENTITY_COLORS[NPC_COUNT % ENTITY_COLORS.length] }

  args.state.tagged_at    = -TAG_COOLDOWN
  args.state.immune_index = nil

  snap_camera args
end

def update_player args
  player = args.state.player
  return if player.nil?

  dir = player_direction args
  return if dir.nil?

  cells = args.state.cells
  step  = PLAYER_SPEED * TICK_SECONDS * time_scale(args)

  # Each axis is resolved separately so walking into a wall at an angle
  # slides along it rather than stopping dead.
  nx = player[:x] + dir[0] * step
  player[:x] = nx if player_fits? cells, nx, player[:y]

  ny = player[:y] + dir[1] * step
  player[:y] = ny if player_fits? cells, player[:x], ny
end

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

# Everything crawls for a few ticks after a tag, giving you a beat to register
# that control moved before play resumes. Ramps back to full speed rather than
# popping, so the handoff reads as one motion.
def time_scale args
  elapsed = Kernel.tick_count - args.state.tagged_at
  return 1.0 if elapsed >= TAG_SLOWMO_TICKS

  TAG_SLOWMO_FACTOR +
    (1.0 - TAG_SLOWMO_FACTOR) * elapsed.fdiv(TAG_SLOWMO_TICKS)
end

# Touching an NPC hands control to it. Fires no matter who closed the gap, so
# an NPC wandering into you tags you just as well as you walking into it.
def check_tag args
  player = args.state.player
  return if player.nil?

  release_immunity args, player
  return if Kernel.tick_count - args.state.tagged_at < TAG_COOLDOWN

  args.state.npcs.each_with_index do |npc, i|
    next if i == args.state.immune_index
    next unless touching? player, npc

    tag_swap args, i
    return
  end
end

# A swap leaves you standing on the block you just left, so it stays
# untaggable until the two of you have moved apart -- otherwise control
# would ping-pong between the pair whenever they're boxed in together.
def release_immunity args, player
  i = args.state.immune_index
  return if i.nil?

  args.state.immune_index = nil unless touching? player, args.state.npcs[i]
end

def touching? a, b
  dx = a[:x] - b[:x]
  dy = a[:y] - b[:y]

  Math.sqrt(dx * dx + dy * dy) < TAG_RADIUS
end

def tag_swap args, index
  npc      = args.state.npcs[index]
  player   = args.state.player
  vacated  = { x: player[:x],
               y: player[:y],
               color: player[:color],
               path: nil,
               path_index: 0,
               waypoint: 0 }

  args.state.player = { x: npc[:x], y: npc[:y], color: npc[:color] }

  assign_waypoint vacated, args.state.cells
  args.state.npcs[index] = vacated

  args.state.tagged_at    = Kernel.tick_count
  args.state.immune_index = index

  camera_switch args
end
