def spawn_target x, y
  {
    x: x,
    y: y,
    w: 64,
    h: 64,
    path: 'sprites/target.png',
  }
end

def spawn_target(args)
  size = 64
  {
    x: rand(args.grid.w * 0.4) + args.grid.w * 0.6,
    y: rand(args.grid.h - size * 2) + size,
    w: size,
    h: size,
    path: 'sprites/target.png',
  }
end

def tick args
  args.state.player ||= {
    x: 120,
    y: 280,
    w: 100,
    h: 80,
    speed: 12,
    path: 'sprites/misc/dragon-0.png',
  }
  args.state.fireballs ||= []
  args.state.targets ||= [
    spawn_target(args), spawn_target(args), spawn_target(args)
  ]
  args.state.score ||= 0

  args.state.timer ||= 30 * 60
  args.state.timer -= 1

  # Timer logic
  if args.state.timer < 0
    labels = []
    labels << {
      x: 40,
      y: args.grid.h - 40,
      text: "Game Over!",
      size_px: 42,
    }
    labels << {
      x: 40,
      y: args.grid.h - 90,
      text: "Score: #{args.state.score}",
      size_px: 30,
    }
    labels << {
      x: 40,
      y: args.grid.h - 132,
      text: "Fire to restart",
      size_px: 26,
    }
    args.outputs.labels << labels

    if args.inputs.keyboard.key_down.z ||
        args.inputs.keyboard.key_down.j ||
        args.inputs.controller_one.key_down.a
      DR.reset
    end

    return
  end

  # Movement logic
  dx = 0
  dy = 0

  if args.inputs.left
    dx -= 1
  elsif args.inputs.right
    dx += 1
  end

  if args.inputs.up
    dy += 1
  elsif args.inputs.down
    dy -= 1
  end

  if dx != 0 || dy != 0
    magnitude = Math.sqrt(dx * dx + dy * dy)
    args.state.player.x += (dx / magnitude) * args.state.player.speed
    args.state.player.y += (dy / magnitude) * args.state.player.speed
  end

  # Boundaries logic
  args.state.player.x = args.state.player.x.clamp(0, args.grid.w - args.state.player.w)
  args.state.player.y = args.state.player.y.clamp(0, args.grid.h - args.state.player.h)

  if args.inputs.keyboard.key_down.z ||
      args.inputs.keyboard.key_down.j ||
      args.inputs.controller_one.key_down.a
    args.state.fireballs << {
      x: args.state.player.x,
      y: args.state.player.y,
      w: 30,
      h: 30,
      path: 'sprites/fireball.png',
    }
  end

  # Fireball movement logic
  args.state.fireballs.each do |fireball|
    fireball.x += args.state.player.speed + 2

    if fireball.x > args.grid.w
      fireball.dead = true
      next
    end

    args.state.targets.each do |target|
      if args.geometry.intersect_rect?(target, fireball)
        target.dead = true
        fireball.dead = true
        args.state.score += 1
        args.state.targets << spawn_target(args)
      end
    end
  end

  args.state.targets.reject! { |t| t.dead }
  args.state.fireballs.reject! { |f| f.dead }

  # Displays stuff on screen
  args.outputs.sprites << [args.state.player, args.state.fireballs, args.state.targets]
  labels = []
  labels << {
    x: 40,
    y: args.grid.h - 40,
    text: "Score: #{args.state.score}",
    size_px: 30
  }
  labels << {
    x: args.grid.w - 40,
    y: args.grid.h - 40,
    text: "Time Left: #{(args.state.timer / 60).round}",
    size_px: 26,
    anchor_x: 1,
  }
  args.outputs.labels << labels
end