def init_camera args

    args.state.camera                   ||= {}
    args.state.camera.x                 ||= 640
    args.state.camera.y                 ||= 300
    args.state.camera.show_empty_space  ||= :yes
    args.state.camera.scale             ||= 2.0
    args.state.target_entity            ||= :player
    args.state.switched_at              ||= -30
end

def update_camera args

    target = camera_target_px args
    return if target.nil?

    camera = args.state.camera

    anchor_x = 640
    anchor_y = 300
    target_x = anchor_x - (target[0] * camera.scale)
    target_y = anchor_y - (target[1] * camera.scale)

    elapsed = Kernel.tick_count - args.state.switched_at
    if elapsed < 30
        lerp_percentage = Easing.ease args.state.switched_at,
                          Kernel.tick_count,
                          30,
                          :smooth_stop_quint
        camera.x = camera.x +(target_x - camera.x) * lerp_percentage
        camera.y = camera.y + (target_y - camera.y) * lerp_percentage
    else
        camera.x += (target_x - camera.x) * 0.2
        camera.y += (target_y - camera.y) * 0.2
    end
end

def snap_camera args
    target = camera_target_px args
    return if target.nil?

    camera = args.state.camera
    camera.x = 640 - (target[0] * camera.scale)
    camera.y = 300 - (target[1] * camera.scale)

    args.state.switched_at = -30
end

def camera_switch args
    args.state.switched_at = Kernel.tick_count
end

def camera_target_px args
    t = args.state.target_entity
    current =
        if t == :player
            args.state.player
        else
            args.state.npcs[t]
        end
        return nil if current.nil?
        [(current[:x] + 0.5) * CELL_PX, (current[:y] + 0.5) * CELL_PX]
end

def calc_scene_position args
    
    camera = args.state.camera

    result = {x: camera.x,
              y: camera.y,
              w: (GRID_W * CELL_PX) * camera.scale,
              h: (GRID_H * CELL_PX) * camera.scale,
              scale: camera.scale }

    return result if camera.show_empty_space == :yes


    if result[:w] < args.grid.w
        result[:x] = (args.grid.w - result[:w]).half
    else
        result[:x] = result[:x].clamp(-(result[:w] - args.grid.w), 0)
    end
    if result[:h] < args.grid.h
        result[:y] = (args.grid.h - result[:h]).half
    else
        result[:y] = result[:y].clamp(-(result[:h] - args.grid.h), 0)
    end

    result
end