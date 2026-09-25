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

  args.outputs[:scene].set w: GRID_W * CELL_PX,
                           h: GRID_H * CELL_PX,
                           background_color: [10, 11, 16]

  args.outputs[:scene].sprites << { x: 0,
                                    y: 0,
                                    w: GRID_W * CELL_PX,
                                    h: GRID_H * CELL_PX,
                                    path: :map }

  render_npcs args
  render_player args
  render_hud args
  render_camera args
end

# Drawn after the NPCs so the player is never hidden behind one. The white
# ring marks whichever block you are driving -- without it a tag leaves you
# guessing which one you just became.
def render_player args
  player = args.state.player
  return if player.nil?

  r, g, b = tag_flash_color args, player[:color]

  # Snapped to whole scene pixels, and two pixels thick rather than one. The
  # scene is zoomed by camera.scale and again by the display's DPI, so a
  # one-pixel ring lands on a fraction of a device pixel and resolves thicker
  # on one side than the other. Two pixels survive that rounding evenly.
  x = (player[:x] * CELL_PX).round
  y = (player[:y] * CELL_PX).round

  args.outputs[:scene].sprites << { x: x - 2,
                                    y: y - 2,
                                    w: CELL_PX + 4,
                                    h: CELL_PX + 4,
                                    path: :solid,
                                    r: 255, g: 255, b: 255 }

  args.outputs[:scene].sprites << { x: x,
                                    y: y,
                                    w: CELL_PX,
                                    h: CELL_PX,
                                    path: :solid,
                                    r: r, g: g, b: b }
end

# Blows the block out to white at the instant of a tag and fades it back to
# its own color as the cooldown runs down, so the handoff is unmissable and
# you can see when you're free to tag again.
def tag_flash_color args, color
  elapsed = Kernel.tick_count - args.state.tagged_at
  return color if elapsed >= TAG_COOLDOWN

  blend = 1.0 - elapsed.fdiv(TAG_COOLDOWN)
  color.map { |c| (c + (255 - c) * blend).to_i }
end

# Blits the :scene target into a VIEW_W x VIEW_H :viewport target, which
# clips it, then draws that pane at MAP_X, MAP_Y so the game stays left of
# the HUD. calc_scene_position works in pane coordinates already.
def render_camera args
  scene = calc_scene_position args

  args.outputs[:viewport].set w: VIEW_W,
                              h: VIEW_H,
                              background_color: [10, 11, 16]

  args.outputs[:viewport].sprites << { x: scene[:x],
                                       y: scene[:y],
                                       w: scene[:w],
                                       h: scene[:h],
                                       path: :scene }

  args.outputs.sprites << { x: MAP_X,
                            y: MAP_Y,
                            w: VIEW_W,
                            h: VIEW_H,
                            path: :viewport }
end

# Draws each NPC as a plain red square, sized to the tile grid. Waypoints
# are private state and only drawn when NPC_DEBUG_WAYPOINTS is on.
def render_npcs args
  args.state.npcs.each do |npc|
    r, g, b = npc[:color]

    args.outputs[:scene].sprites << { x: npc[:x] * CELL_PX,
                                      y: npc[:y] * CELL_PX,
                                      w: CELL_PX,
                                      h: CELL_PX,
                                      path: :solid,
                                      r: r, g: g, b: b }
  end

  return unless NPC_DEBUG_WAYPOINTS

  args.state.npcs.each do |npc|
    wx = npc[:waypoint] % GRID_W
    wy = npc[:waypoint].idiv GRID_W

    args.outputs[:scene].sprites << { x: wx * CELL_PX,
                                      y: wy * CELL_PX,
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
    ["PROCGEN", 200, 200, 210],
    ["", 0, 0, 0],
    ["seed    #{args.state.seed}", 232, 222, 196],
    ["thresh  #{args.state.threshold.round(2)}", 232, 222, 196],
    ["", 0, 0, 0],
    ["open    #{pct args.state.open_count, total}%", 150, 190, 150],
    ["regions #{args.state.regions}", 150, 190, 150],
    ["largest #{pct args.state.largest, total}%", 150, 190, 150],
    ["", 0, 0, 0],
    ["[O] warp   #{on_off args.state.warp}", 150, 160, 200],
    ["[I] island #{on_off args.state.mask}", 150, 160, 200],
    ["[F] cull   #{on_off args.state.cull}", 150, 160, 200],
    ["[TAB] show #{on_off args.state.show_culled}", 150, 160, 200],
    ["", 0, 0, 0],
    ["[R] reroll", 120, 120, 132],
    ["wasd move", 120, 120, 132],
    ["arrows tune", 120, 120, 132],
    ["", 0, 0, 0],
    ["dark red = culled", 120, 120, 132]
  ]

  y = 690
  lines.each do |text, r, g, b|
    unless text.empty?
      args.outputs.labels << { x: HUD_X, y: y, text: text,
                               r: r, g: g, b: b, size_px: 20 }
    end
    y -= 28
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
