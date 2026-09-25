# Wandering NPC entities: spawning and movement toward private waypoints.
# Each NPC is a plain Hash with keys :x, :y (tile-space position, floats),
# :path (array of cell indices, or nil), :path_index, and :waypoint.

# Builds NPC_COUNT entities on distinct random accessible (FLOOR) tiles and
# gives each an initial waypoint + path. Called once at boot and again
# whenever the map is regenerated (old positions/paths would otherwise point
# at cells that no longer exist or are no longer walkable).
def spawn_npcs args
  cells      = args.state.cells
  accessible = []
  cells.each_with_index { |c, i| accessible << i if c == FLOOR }

  chosen = []
  npcs = Array.new(NPC_COUNT) do |i|
    idx = pick_unused_tile accessible, chosen
    chosen << idx
    { x: (idx % GRID_W).to_f,
      y: idx.idiv(GRID_W).to_f,
      color: ENTITY_COLORS[i % ENTITY_COLORS.length],
      path: nil,
      path_index: 0,
      waypoint: idx }
  end

  args.state.npcs = npcs
  npcs.each { |npc| assign_waypoint npc, cells }
end

# A random tile from `accessible` not already in `chosen`. Falls back to
# allowing a repeat if the map doesn't have enough distinct accessible
# tiles for NPC_COUNT entities.
def pick_unused_tile accessible, chosen
  (accessible.length * 4).times do
    idx = accessible[Numeric.rand(accessible.length)]
    return idx unless chosen.include? idx
  end

  accessible[Numeric.rand(accessible.length)]
end

# Advances every NPC along its precomputed path, re-waypointing on arrival.
def update_npcs args
  cells = args.state.cells
  args.state.npcs.each { |npc| update_npc npc, cells }
end

def update_npc npc, cells
  remaining = NPC_SPEED * TICK_SECONDS

  while remaining > 0 && npc[:path] && npc[:path_index] < npc[:path].length
    target = npc[:path][npc[:path_index]]
    tx = (target % GRID_W).to_f
    ty = target.idiv(GRID_W).to_f

    dx   = tx - npc[:x]
    dy   = ty - npc[:y]
    dist = Math.sqrt(dx * dx + dy * dy)

    if dist <= remaining
      npc[:x] = tx
      npc[:y] = ty
      npc[:path_index] += 1
      remaining -= dist
    else
      npc[:x] += dx / dist * remaining
      npc[:y] += dy / dist * remaining
      remaining = 0
    end
  end

  assign_waypoint npc, cells if npc[:path].nil? || npc[:path_index] >= npc[:path].length
end

# Picks a new random waypoint reachable from the NPC's current tile (its own
# private target -- never rendered, see NPC_DEBUG_WAYPOINTS) and pathfinds
# to it once, up front, rather than every frame.
def assign_waypoint npc, cells
  current = npc[:y].round * GRID_W + npc[:x].round

  reachable  = Pathfinding.reachable_from cells, current
  others     = reachable.reject { |i| i == current }
  candidates = others.empty? ? reachable : others

  npc[:waypoint]   = candidates[Numeric.rand(candidates.length)]
  npc[:path]       = Pathfinding.find_path cells, current, npc[:waypoint]
  npc[:path_index] = 1
end
