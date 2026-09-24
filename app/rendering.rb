# Cached map rendering and HUD.

# Draws every cell into an off-screen target exactly once per generation.
# After this the main loop blits a single sprite, so a 7,000 cell map costs
# one primitive per frame instead of seven thousand.
def render_map args
  cells = args.state.cells
  show  = args.state.show_culled

  args.outputs[:map].set w: GRID_W * CELL_PX,
                         h: GRID_H * CELL_PX,
                         background_color: [16, 18, 26]

  GRID_H.times do |y|
    row = y * GRID_W

    GRID_W.times do |x|
      state = cells[row + x]
      next if state == WALL
      next if state == DISCARDED && !show

      if state == FLOOR
        r, g, b = 232, 222, 196
      else
        r, g, b = 104, 48, 58
      end

      args.outputs[:map] << { x: x * CELL_PX,
                              y: y * CELL_PX,
                              w: CELL_PX,
                              h: CELL_PX,
                              path: :solid,
                              r: r, g: g, b: b }
    end
  end
end

# Blits the cached map sprite and draws the HUD on top.
def render args
  args.outputs.background_color = [10, 11, 16]

  args.outputs.sprites << { x: MAP_X,
                            y: MAP_Y,
                            w: GRID_W * CELL_PX,
                            h: GRID_H * CELL_PX,
                            path: :map }

  render_npcs args
  render_hud args
end

# Draws each NPC as a plain red square, sized to the tile grid. Waypoints
# are private state and only drawn when NPC_DEBUG_WAYPOINTS is on.
def render_npcs args
  args.state.npcs.each do |npc|
    args.outputs.sprites << { x: MAP_X + npc[:x] * CELL_PX,
                             y: MAP_Y + npc[:y] * CELL_PX,
                             w: CELL_PX,
                             h: CELL_PX,
                             path: :solid,
                             r: 220, g: 40, b: 40 }
  end

  return unless NPC_DEBUG_WAYPOINTS

  args.state.npcs.each do |npc|
    wx = npc[:waypoint] % GRID_W
    wy = npc[:waypoint].idiv GRID_W

    args.outputs.sprites << { x: MAP_X + wx * CELL_PX,
                             y: MAP_Y + wy * CELL_PX,
                             w: CELL_PX,
                             h: CELL_PX,
                             path: :solid,
                             r: 60, g: 200, b: 255, a: 140 }
  end
end

# Draws the sidebar of stats and control hints as a stack of labels.
def render_hud args
  total = GRID_W * GRID_H

  lines = [
    ["PROCGEN HARNESS", 200, 200, 210],
    ["", 0, 0, 0],
    ["seed          #{args.state.seed}", 232, 222, 196],
    ["threshold     #{args.state.threshold.round(2)}", 232, 222, 196],
    ["", 0, 0, 0],
    ["open          #{pct args.state.open_count, total}%", 150, 190, 150],
    ["regions       #{args.state.regions}", 150, 190, 150],
    ["largest       #{pct args.state.largest, total}%", 150, 190, 150],
    ["", 0, 0, 0],
    ["[W] warp      #{on_off args.state.warp}", 150, 160, 200],
    ["[I] island    #{on_off args.state.mask}", 150, 160, 200],
    ["[F] cull      #{on_off args.state.cull}", 150, 160, 200],
    ["[TAB] show    #{on_off args.state.show_culled}", 150, 160, 200],
    ["", 0, 0, 0],
    ["[R] reroll seed", 120, 120, 132],
    ["arrows: seed / threshold", 120, 120, 132],
    ["", 0, 0, 0],
    ["red = discarded by flood fill", 120, 120, 132]
  ]

  y = 686
  lines.each do |text, r, g, b|
    unless text.empty?
      args.outputs.labels << { x: HUD_X, y: y, text: text,
                               r: r, g: g, b: b, size_px: 18 }
    end
    y -= 26
  end
end

# n as a percentage of total, rounded to one decimal place.
def pct n, total
  (n.fdiv(total) * 100).round(1)
end

# "on" / "off" label for a boolean flag.
def on_off flag
  flag ? "on" : "off"
end
