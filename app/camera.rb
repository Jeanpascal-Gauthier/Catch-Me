def init_camera args

    args.state.camera                   ||= {}
    args.state.camera.x                 ||= 640
    args.state.camera.y                 ||= 300
    args.state.camera.show_empty_space  ||= :no
    args.state.camera.scale             ||= 2.0
    args.state.target_entity            ||= :player
    args.state.switched_at              ||= -CAMERA_SWITCH_TICKS
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
    from    = args.state.switch_from

    # Interpolate from where the camera stood when control switched to where
    # it needs to be. Easing.ease returns progress along that span -- feeding
    # it in as a per-frame lerp factor instead would cover 97% of the gap in
    # the first half of the window and read as a snap.
    if from && elapsed < CAMERA_SWITCH_TICKS
        progress = Easing.ease args.state.switched_at,
                               Kernel.tick_count,
                               CAMERA_SWITCH_TICKS,
                               :smooth_stop_quint
        camera.x = from[:x] + (target_x - from[:x]) * progress
        camera.y = from[:y] + (target_y - from[:y]) * progress
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

    args.state.switched_at = -CAMERA_SWITCH_TICKS
    args.state.switch_from = nil
end

# Records where the camera stood so update_camera has something to ease from.
def camera_switch args
    camera = args.state.camera

    args.state.switched_at = Kernel.tick_count
    args.state.switch_from = { x: camera.x, y: camera.y }
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

# Where to draw the :scene target inside the VIEW_W x VIEW_H play pane.
# camera.x/y put the tracked block at point (640, 300), so shift that to the
# middle of the pane.
def calc_scene_position args

    camera = args.state.camera

    result = {x: camera.x + (VIEW_W.half - 640),
              y: camera.y + (VIEW_H.half - 300),
              w: (GRID_W * CELL_PX) * camera.scale,
              h: (GRID_H * CELL_PX) * camera.scale,
              scale: camera.scale }

    return result if camera.show_empty_space == :yes

    # Hold the map over the whole pane so its edge never comes into view.
    # A map smaller than the pane can't cover it, so center it instead.
    if result[:w] < VIEW_W
        result[:x] = (VIEW_W - result[:w]).half
    else
        result[:x] = result[:x].clamp(-(result[:w] - VIEW_W), 0)
    end
    if result[:h] < VIEW_H
        result[:y] = (VIEW_H - result[:h]).half
    else
        result[:y] = result[:y].clamp(-(result[:h] - VIEW_H), 0)
    end

    result
end