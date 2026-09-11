module Main
  FPS = 60
  HIGH_SCORES_FILE = "high-scores.txt"
  MAX_HIGH_SCORES = 5

  def load_high_scores
    contents = DR.read_file(HIGH_SCORES_FILE)
    return [] if contents.nil? || contents.strip.empty?

    contents.strip.split("\n").map do |line|
      score_str, date_str = line.split(",", 2)
      { score: score_str.to_i, date: date_str }
    end
  end

  def format_timestamp(time)
    format("%04d-%02d-%02d %02d:%02d", time.year, time.month, time.day, time.hour, time.min)
  end

  def save_high_scores(scores)
    contents = scores.map { |entry| "#{entry.score},#{entry.date}" }.join("\n")
    DR.write_file(HIGH_SCORES_FILE, contents)
  end

  def try_save_high_score(args)
    return if args.state.saved_high_score
    args.state.saved_high_score = true

    previous_best = args.state.high_scores.map { |entry| entry.score }.max || 0
    args.state.new_high_score = args.state.score > 0 && args.state.score > previous_best

    args.state.high_scores << {
      score: args.state.score,
      date: format_timestamp(Time.now),
    }
    args.state.high_scores = args.state.high_scores.sort_by { |entry| -entry.score }
    args.state.high_scores = args.state.high_scores.first(MAX_HIGH_SCORES)

    save_high_scores(args.state.high_scores)
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

  def fire_input?(args)
    args.inputs.keyboard.key_down.z ||
      args.inputs.keyboard.key_down.j ||
      args.inputs.controller_one.key_down.a
  end

  def handle_player_movement(args)
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

    args.state.player.x = args.state.player.x.clamp(0, args.grid.w - args.state.player.w)
    args.state.player.y = args.state.player.y.clamp(0, args.grid.h - args.state.player.h)
  end

  def game_over_tick(args)
    args.state.high_scores ||= load_high_scores
    args.state.timer -= 1

    try_save_high_score(args)

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

    if args.state.new_high_score
      labels << {
        x: 40,
        y: args.grid.h - 174,
        text: "New high-score!",
        size_px: 28,
      }
    end

    labels << {
      x: args.grid.w - 40,
      y: args.grid.h - 40,
      text: "High Scores",
      size_px: 26,
      anchor_x: 1,
    }
    args.state.high_scores.each_with_index do |entry, i|
      labels << {
        x: args.grid.w - 40,
        y: args.grid.h - 76 - (i * 30),
        text: "#{i + 1}. #{entry.score}  #{entry.date}",
        size_px: 22,
        anchor_x: 1,
      }
    end

    args.outputs.labels << labels

    if args.state.timer < -30 && fire_input?(args)
      DR.reset
    end
  end

  def gameplay_tick(args)
    args.outputs.sprites << {
      x: 0,
      y: 0,
      w: args.grid.w,
      h: args.grid.h,
      path: :solid,
      r: 92,
      g: 120,
      b: 230,
    }

    args.state.player ||= {
      x: 120,
      y: 280,
      w: 100,
      h: 80,
      speed: 12,
    }

    player_sprite_index = 0.frame_index(count: 6, hold_for: 8, repeat: true)
    args.state.player.path = "sprites/misc/dragon-#{player_sprite_index}.png"

    args.state.fireballs ||= []
    args.state.targets ||= [
      spawn_target(args), spawn_target(args), spawn_target(args)
    ]
    args.state.score ||= 0
    args.state.timer ||= 30 * FPS

    args.state.timer -= 1

    if args.state.timer == 0
      args.audio[:music].paused = true
      args.outputs.sounds << "sounds/game-over.wav"
      args.state.scene = "game_over"
      return
    end

    handle_player_movement(args)

    if fire_input?(args)
      args.outputs.sounds << "sounds/fireball.wav"
      args.state.fireballs << {
        x: args.state.player.x + args.state.player.w - 12,
        y: args.state.player.y + 10,
        w: 32,
        h: 32,
        path: 'sprites/fireball.png',
      }
    end

    args.state.fireballs.each do |fireball|
      fireball.x += args.state.player.speed + 2

      if fireball.x > args.grid.w
        fireball.dead = true
        next
      end

      args.state.targets.each do |target|
        if args.geometry.intersect_rect?(target, fireball)
          args.outputs.sounds << "sounds/target.wav"
          target.dead = true
          fireball.dead = true
          args.state.score += 1
          args.state.targets << spawn_target(args)
        end
      end
    end

    args.state.targets.reject! { |t| t.dead }
    args.state.fireballs.reject! { |f| f.dead }

    args.outputs.sprites << [args.state.player, args.state.fireballs, args.state.targets]

    labels = []
    labels << {
      x: 40,
      y: args.grid.h - 40,
      text: "Score: #{args.state.score}",
      size_px: 30,
    }
    labels << {
      x: args.grid.w - 40,
      y: args.grid.h - 40,
      text: "Time Left: #{(args.state.timer / FPS).round}",
      size_px: 26,
      anchor_x: 1,
    }
    args.outputs.labels << labels
  end

  def tick args
    if Kernel.tick_count == 1
      args.audio[:music] = { input: "sounds/flight.ogg", looping: true }
    end

    args.state.scene ||= "gameplay"

    send("#{args.state.scene}_tick", args)
  end
end

DR.reset