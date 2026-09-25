def current_player args
    return nil if args.state.player_index.nil?

    args.state.npcs[args.state.player_index]
end

def new_player idx
    { x: (idx % GRID_W).to_f,
      y: idx.idiv(GRID_W).to_f,
      path: nil,
      path_index: 0,
      waypoint: idx,
      move_target: idx }
end

def spawn_player args
    cells = args.state.cells
    accessible = []
    cells.each_with_index { |c, i| accessible << i if c == FLOOR }

    if accessible.empty?
        args.state.player_index = nil
        return
    end

    chosen = args.state.npcs.map { |npc| npc[:y].round * GRID_W + npc[:x].round }
    idx = pick_unused_tile accessible, chosen

    args.state.npcs << new_player(idx)
    args.state.player_index =   args.state.npcs.length - 1
    args.state.tagged_at =      -TAG_COOLDOWN_TICKS
    args.state.immune_index =   nil

    snap_camera args
end

def move_priority_direction args
    return [0, 1] if args.inputs.keyboard.key_held.up
    return [0, -1] if args.inputs.keyboard.key_held.down
    return [-1, 0] if args.inputs.keyboard.key_held.left
    return [1, 0] if args.inputs.keyboard.key_held.right

    nil
end

def update_player args
    p = current_player args
    return if p.nil?

    player_mvmt p, args.state.cells, move_priority_direction(args)
end

def player_cell_xy idx
    [idx % GRID_W, idx.idiv(GRID_W)]
end

def player_distance x1, y1, x2, y2
    dx = x2 - x1
    dy = y2 - y1
    Math.sqrt(dx * dx + dy * dy)
end

def player_mvmt p, cells, dir
    remaining = PLAYER_SPEED * TICK_SECONDS

    end
end

def check_tag
end

def swap
end
