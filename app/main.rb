module Main
  FPS = 60
  HIGH_SCORES_FILE = "high-scores.txt"
  MAX_HIGH_SCORES = 5
  PLAYER_DRAGON = "dragon"
  ENEMY_DRAGON = "dragon-green"
  INTRO_DURATION = 1.2 * FPS
  LABEL_SLIDE = 400
  REVEAL_DURATION = 0.5 * FPS
  REVEAL_STAGGER = 5
  PLAYER_HOME_X = 120
  PLAYER_HOME_Y = 280

  BACKGROUND_PATH = "sprites/background-sky.png"
  BACKGROUND_SPEED = 1.2

  ENEMY_FIREBALL_SPEED = 8
  ENEMY_FIRE_DELAY_MIN = 1.2 * FPS
  ENEMY_FIRE_DELAY_MAX = 3.0 * FPS
  ENEMY_SIZE = 64
  ENEMY_ZONE_LEFT_RATIO = 0.55
  ENEMY_SPEED_MIN = 0.6
  ENEMY_SPEED_MAX = 2.4
  ENEMY_TURN_DELAY_MIN = 0.5 * FPS
  ENEMY_TURN_DELAY_MAX = 1.8 * FPS
  ENEMY_ENTRY_DURATION_MIN = 0.8 * FPS
  ENEMY_ENTRY_DURATION_MAX = 1.4 * FPS
  ENEMY_ENTRY_SWEEP = 220

  ROUND_DURATION = 120 * FPS

  # For increasing difficulty as time progresses by spawning more enemies
  ENEMY_COUNT_START = 3
  ENEMY_COUNT_MAX = 12
  ENEMY_RAMP_INTERVAL = 12 * FPS
  ENEMY_SPAWN_STAGGER = 0.4 * FPS

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

  def fire_input?(args)
    args.inputs.keyboard.key_down.z ||
      args.inputs.keyboard.key_down.j ||
      args.inputs.controller_one.key_down.a
  end

  # Creating a vector to make player speed consistent 
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

  def dragon_sprite_path(start_tick, name)
    index = start_tick.frame_index(count: 6, hold_for: 8, repeat: true)
    "sprites/misc/#{name}-#{index}.png"
  end

  # This is so enemies dont go too far left
  def enemy_zone(args)
    left = args.grid.w * ENEMY_ZONE_LEFT_RATIO
    {
      left: left,
      right: args.grid.w - ENEMY_SIZE,
      bottom: 0,
      top: args.grid.h - ENEMY_SIZE,
    }
  end

  # Controls the switching of direction for targets
  def enemy_turn_delay
    rand(ENEMY_TURN_DELAY_MAX - ENEMY_TURN_DELAY_MIN) + ENEMY_TURN_DELAY_MIN
  end

  def random_enemy_velocity
    speed = rand(ENEMY_SPEED_MAX - ENEMY_SPEED_MIN) + ENEMY_SPEED_MIN
    angle = rand(360)
    [speed * Math.cos(angle * Math::PI / 180), speed * Math.sin(angle * Math::PI / 180)]
  end

  def wander_target(args, target)
    if Kernel.tick_count >= target.next_turn_at
      target.dx, target.dy = random_enemy_velocity
      target.next_turn_at = Kernel.tick_count + enemy_turn_delay
    end

    zone = enemy_zone(args)
    target.x += target.dx
    target.y += target.dy

    if target.x < zone.left || target.x > zone.right
      target.dx = -target.dx
      target.x = target.x.clamp(zone.left, zone.right)
    end

    if target.y < zone.bottom || target.y > zone.top
      target.dy = -target.dy
      target.y = target.y.clamp(zone.bottom, zone.top)
    end
  end

  def ease_out(t)
    1 - ((1 - t) * (1 - t))
  end

  def build_entry_path(args, dest_x, dest_y)
    zone = enemy_zone(args)
    start_y = rand(2) == 0 ? args.grid.h + ENEMY_SIZE : -ENEMY_SIZE
    sweep = rand(2) == 0 ? -ENEMY_ENTRY_SWEEP : ENEMY_ENTRY_SWEEP
    start_x = (dest_x + sweep).clamp(zone.left, zone.right)

    [
      { x: start_x, y: start_y },
      { x: (start_x - sweep).clamp(zone.left, zone.right), y: start_y + (dest_y - start_y) * 0.25 },
      { x: (dest_x + sweep).clamp(zone.left, zone.right), y: dest_y + (start_y - dest_y) * 0.25 },
      { x: dest_x, y: dest_y },
    ]
  end

  def rush_target(args, target)
    elapsed = Kernel.tick_count - target.spawned_at
    t = (elapsed / target.entry_duration).clamp(0, 1)

    path = target.entry_path
    point = args.geometry.cubic_bezier_vec2(path[0], path[1], path[2], path[3], ease_out(t))
    target.x = point.x
    target.y = point.y

    return if t < 1

    target.mode = :wandering
    target.next_turn_at = Kernel.tick_count + enemy_turn_delay
    target.next_fire_at = Kernel.tick_count + enemy_fire_delay
  end

  def enemies_wanted(args)
    elapsed = ROUND_DURATION - args.state.timer
    extra = (elapsed / ENEMY_RAMP_INTERVAL).to_i
    (ENEMY_COUNT_START + extra).clamp(ENEMY_COUNT_START, ENEMY_COUNT_MAX)
  end

  def maintain_enemy_population(args)
    return if args.state.targets.length >= enemies_wanted(args)
    return if Kernel.tick_count < args.state.next_spawn_at

    args.state.targets << spawn_target(args)
    args.state.next_spawn_at = Kernel.tick_count + ENEMY_SPAWN_STAGGER
  end

  def spawn_target(args)
    zone = enemy_zone(args)
    dx, dy = random_enemy_velocity
    dest_x = rand(zone.right - zone.left) + zone.left
    dest_y = rand(zone.top - zone.bottom) + zone.bottom
    entry_path = build_entry_path(args, dest_x, dest_y)

    {
      x: entry_path[0].x,
      y: entry_path[0].y,
      entry_path: entry_path,
      entry_duration: rand(ENEMY_ENTRY_DURATION_MAX - ENEMY_ENTRY_DURATION_MIN) + ENEMY_ENTRY_DURATION_MIN,
      mode: :entering,
      w: ENEMY_SIZE,
      h: ENEMY_SIZE,
      dx: dx,
      dy: dy,
      next_turn_at: Kernel.tick_count + enemy_turn_delay,
      spawned_at: Kernel.tick_count,
      next_fire_at: Kernel.tick_count + enemy_fire_delay,
      path: dragon_sprite_path(Kernel.tick_count, ENEMY_DRAGON),
      flip_horizontally: true
    }
  end

  def enemy_fire_delay
    rand(ENEMY_FIRE_DELAY_MAX - ENEMY_FIRE_DELAY_MIN) + ENEMY_FIRE_DELAY_MIN
  end

  def spawn_enemy_fireball(target)
    {
      x: target.x - 20,
      y: target.y + (target.h / 2) - 16,
      w: 32,
      h: 32,
      path: "sprites/fireball.png",
      flip_horizontally: true,
    }
  end

  def player_hitbox(player)
    {
      x: player.x + 16,
      y: player.y + 12,
      w: player.w - 32,
      h: player.h - 24,
    }
  end

  def end_game(args)
    args.audio[:music].paused = true
    args.outputs.sounds << "sounds/game-over.wav"
    args.state.timer = 0
    args.state.scene = "game_over"
  end

  def render_background(args)
    tile_w = args.grid.w
    scrolled = Kernel.tick_count * BACKGROUND_SPEED
    first_tile = (scrolled / tile_w).floor
    offset = scrolled % tile_w

    2.times do |i|
      args.outputs.sprites << {
        x: (i * tile_w) - offset,
        y: 0,
        w: tile_w,
        h: args.grid.h,
        path: BACKGROUND_PATH,
        flip_horizontally: (first_tile + i).odd?,
      }
    end
  end

  def title_labels(args, drift = 0)
    x = 40 - drift * (args.grid.w + LABEL_SLIDE)

    [
      { x: x, y: args.grid.h - 40, text: "Target Practice", size_px: 34 },
      { x: x, y: args.grid.h - 88, text: "Hit the targets!" },
      { x: x, y: args.grid.h - 120, text: "by Jean-Pascal Gauthier" },
      { x: x, y: 120, text: "Arrows or WASD to move | Z or J to fire | gamepad works too" },
      { x: x, y: 80, text: "Fire to start", size_px: 26 },
    ]
  end

  def hud_labels(args, reveal = 1)
    hidden = (1 - reveal) * LABEL_SLIDE

    [
      {
        x: 40 - hidden,
        y: args.grid.h - 40,
        text: "Score: #{args.state.score}",
        size_px: 30,
      },
      {
        x: args.grid.w - 40 + hidden,
        y: args.grid.h - 40,
        text: "Time Left: #{(args.state.timer / FPS).round}",
        size_px: 26,
        anchor_x: 1,
      },
    ]
  end

  def intro_playing?(args)
    Kernel.tick_count - args.state.intro_started_at < INTRO_DURATION
  end

  def play_intro(args)
    elapsed = Kernel.tick_count - args.state.intro_started_at
    progress = ease_out((elapsed / INTRO_DURATION).clamp(0, 1))

    args.state.player.x = (progress * (PLAYER_HOME_X + args.state.player.w)) - args.state.player.w
    args.outputs.sprites << args.state.player
    args.outputs.labels << title_labels(args, progress)
    args.outputs.labels << hud_labels(args, progress)
  end

  def reveal_progress(started_at, index)
    elapsed = Kernel.tick_count - started_at - (index * REVEAL_STAGGER)
    ease_out((elapsed / REVEAL_DURATION).clamp(0, 1))
  end

  def title_tick args
    render_background(args)

    if fire_input?(args)
      args.outputs.sounds << "sounds/game-over.wav"
      args.state.scene = "gameplay"
      return
    end

    args.outputs.labels << title_labels(args)
  end

  def game_over_labels(args)
    left = []
    left << { y: args.grid.h - 40, text: "Game Over!", size_px: 42 }
    left << { y: args.grid.h - 90, text: "Score: #{args.state.score}", size_px: 30 }
    left << { y: args.grid.h - 132, text: "Fire to restart", size_px: 26 }

    if args.state.new_high_score
      left << { y: args.grid.h - 174, text: "New high-score!", size_px: 28 }
    end

    right = []
    right << { y: args.grid.h - 40, text: "High Scores", size_px: 26 }
    args.state.high_scores.each_with_index do |entry, i|
      right << {
        y: args.grid.h - 76 - (i * 30),
        text: "#{i + 1}. #{entry.score}  #{entry.date}",
        size_px: 22,
      }
    end

    started_at = args.state.game_over_started_at
    labels = []

    left.each_with_index do |label, i|
      hidden = (1 - reveal_progress(started_at, i)) * LABEL_SLIDE
      labels << label.merge(x: 40 - hidden)
    end

    right.each_with_index do |label, i|
      hidden = (1 - reveal_progress(started_at, i)) * LABEL_SLIDE
      labels << label.merge(x: args.grid.w - 40 + hidden, anchor_x: 1)
    end

    labels
  end

  def game_over_tick(args)
    render_background(args)

    args.state.high_scores ||= load_high_scores
    args.state.game_over_started_at ||= Kernel.tick_count
    args.state.timer -= 1

    try_save_high_score(args)

    args.outputs.labels << game_over_labels(args)

    if args.state.timer < -30 && fire_input?(args)
      DR.reset
    end
  end

  def gameplay_tick(args)
    render_background(args)

    args.state.player ||= {
      x: PLAYER_HOME_X,
      y: PLAYER_HOME_Y,
      w: 100,
      h: 80,
      speed: 12,
    }

    args.state.player.path = dragon_sprite_path(0, PLAYER_DRAGON)

    args.state.fireballs ||= []
    args.state.enemy_fireballs ||= []
    args.state.targets ||= []
    args.state.next_spawn_at ||= 0
    args.state.score ||= 0
    args.state.timer ||= ROUND_DURATION
    args.state.intro_started_at ||= Kernel.tick_count

    if intro_playing?(args)
      play_intro(args)
      return
    end

    args.state.timer -= 1

    if args.state.timer <= 0
      end_game(args)
      return
    end

    handle_player_movement(args)
    maintain_enemy_population(args)

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
        next if target.dead

        if args.geometry.intersect_rect?(target, fireball)
          args.outputs.sounds << "sounds/target.wav"
          target.dead = true
          fireball.dead = true
          args.state.score += 1
          break
        end
      end
    end

    args.state.targets.each do |target|
      next if target.dead
      next if target.mode == :entering
      next if Kernel.tick_count < target.next_fire_at
      target.next_fire_at = Kernel.tick_count + enemy_fire_delay
      args.state.enemy_fireballs << spawn_enemy_fireball(target)
    end

    hitbox = player_hitbox(args.state.player)

    args.state.enemy_fireballs.each do |fireball|
      fireball.x -= ENEMY_FIREBALL_SPEED

      if fireball.x + fireball.w < 0
        fireball.dead = true
        next
      end

      if args.geometry.intersect_rect?(hitbox, fireball)
        end_game(args)
        return
      end
    end

    args.state.targets.each do |target|
      next if target.dead

      if target.mode == :entering
        rush_target(args, target)
      else
        wander_target(args, target)
      end

      target.path = dragon_sprite_path(target.spawned_at, ENEMY_DRAGON)
    end

    args.state.targets.reject! { |t| t.dead }
    args.state.fireballs.reject! { |f| f.dead }
    args.state.enemy_fireballs.reject! { |f| f.dead }

    args.outputs.sprites << [
      args.state.player,
      args.state.fireballs,
      args.state.enemy_fireballs,
      args.state.targets,
    ]

    args.outputs.labels << hud_labels(args)
  end

  def tick args
    if Kernel.tick_count == 1
      args.audio[:music] = { input: "sounds/flight.ogg", looping: true }
    end

    args.state.scene ||= "title"

    send("#{args.state.scene}_tick", args)
  end
end

DR.reset