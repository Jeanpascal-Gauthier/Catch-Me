# ./mygame/app/main.rb
#
# Procgen harness: fBm noise -> threshold -> flood fill -> cached render target.
#
#   R        reroll seed
#   LEFT     seed - 1          RIGHT  seed + 1
#   DOWN     threshold - 0.01  UP     threshold + 0.01
#   W        toggle domain warp
#   I        toggle island mask
#   F        toggle flood fill (keep largest region only)
#   TAB      toggle highlight of discarded regions
#
# IMPORTANT: Geometry.perlin_* requires x, y, z in [-1, 1]. Pass anything
# outside that and the engine raises. Since perlin_fbm_noise has no seed
# parameter, this file seeds by slicing the 3D noise field along a randomly
# oriented plane: each seed picks an orthonormal basis (u, v) and an origin,
# and the map's x/y walk that plane. Rotating the slice decorrelates the
# result, so you get unlimited distinct maps without leaving the unit cube.
#
# Seed and threshold live in globals, so they survive hot reload. Edit a
# constant below, hit save, and you are looking at the same map with the new
# parameters. That is the whole point of this file.

GRID_W  = 84
GRID_H  = 84
CELL_PX = 8
MAP_X   = 24
MAP_Y   = 24
HUD_X   = 724

# --- tune these, save, compare -----------------------------------------
SPAN       = 0.9   # width of the sampled window in noise units. keep < 2.0
LACUNARITY = 4.0   # frequency multiplier per octave
GAIN       = 0.45  # amplitude multiplier per octave
OCTAVES    = 4     # how many layers of detail
WARP       = 0.12  # domain warp strength
WARP_OCT   = 2     # octaves used for the warp fields
WARP_SHIFT = 0.15  # how far along the plane normal the warp fields are read
MASK_GAIN  = 1.5   # island falloff strength
MASK_POWER = 2.2   # island falloff curve
# -----------------------------------------------------------------------

WALL      = 0
FLOOR     = 1
DISCARDED = 2

$seed      ||= 1
$threshold ||= 0.02

def boot args
  args.state = {}
end

def tick args
  init args
  handle_input args
  regenerate args
  render args
end

def init args
  return if args.state.ready

  args.state.ready       = true
  args.state.seed        = $seed
  args.state.threshold   = $threshold
  args.state.warp        = true
  args.state.mask        = false
  args.state.cull        = true
  args.state.show_culled = true
  args.state.field_dirty = true
  args.state.map_dirty   = true
  args.state.regions     = 0
  args.state.largest     = 0
  args.state.open_count  = 0
end

# ---------------------------------------------------------------- input

def handle_input args
  k = args.inputs.keyboard
  t = args.state.tick_count

  set_seed args, Numeric.rand(100_000) if k.key_down.r

  set_seed args, args.state.seed + 1 if repeating?(k.key_down.right, k.key_held.right, t)
  set_seed args, args.state.seed - 1 if repeating?(k.key_down.left, k.key_held.left, t)

  if repeating?(k.key_down.up, k.key_held.up, t)
    set_threshold args, args.state.threshold + 0.01
  end

  if repeating?(k.key_down.down, k.key_held.down, t)
    set_threshold args, args.state.threshold - 0.01
  end

  if k.key_down.w
    args.state.warp = !args.state.warp
    args.state.field_dirty = true
  end

  if k.key_down.i
    args.state.mask = !args.state.mask
    args.state.field_dirty = true
  end

  if k.key_down.f
    args.state.cull = !args.state.cull
    args.state.map_dirty = true
  end

  if k.key_down.tab
    args.state.show_culled = !args.state.show_culled
    args.state.map_dirty = true
  end
end

# tap for one step, hold to repeat
def repeating? down, held, tick
  down || (held && tick % 4 == 0)
end

def set_seed args, value
  args.state.seed = value
  $seed = value
  args.state.field_dirty = true
end

def set_threshold args, value
  value = value.clamp(-2.0, 2.0)
  args.state.threshold = value
  $threshold = value
  args.state.map_dirty = true
end

# ------------------------------------------------------------ seed -> plane

# Small self-contained LCG. Deliberately not DR's RNG, so a given seed always
# produces the same plane no matter what else has touched the global RNG.
class Lcg
  def initialize seed
    @s = ((seed.abs + 1) * 747_796_405 + 2_891_336_453) & 0xFFFFFFFF
    @s = 1 if @s == 0
    4.times { unit_float }
  end

  def unit_float
    @s = (@s * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
    @s.fdiv(0xFFFFFFFF)
  end

  def signed_float
    unit_float * 2.0 - 1.0
  end
end

def random_direction rng
  20.times do
    x = rng.signed_float
    y = rng.signed_float
    z = rng.signed_float
    len = Math.sqrt(x * x + y * y + z * z)
    next if len < 0.25
    return [x / len, y / len, z / len]
  end

  [1.0, 0.0, 0.0]
end

def dot a, b
  a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
end

def cross a, b
  [a[1] * b[2] - a[2] * b[1],
   a[2] * b[0] - a[0] * b[2],
   a[0] * b[1] - a[1] * b[0]]
end

# Orthonormal basis (u, v), their normal, and an origin, all derived from seed.
def build_plane seed
  rng = Lcg.new seed
  u   = random_direction rng
  v   = nil

  20.times do
    w  = random_direction rng
    d  = dot u, w
    vx = w[0] - d * u[0]
    vy = w[1] - d * u[1]
    vz = w[2] - d * u[2]
    len = Math.sqrt(vx * vx + vy * vy + vz * vz)
    next if len < 0.25

    v = [vx / len, vy / len, vz / len]
    break
  end

  v ||= cross(u, [0.0, 0.0, 1.0])

  # How far the origin can wander and still keep every sample in the unit cube.
  reach = (SPAN * 0.5 * 1.415) + WARP + WARP_SHIFT
  room  = 1.0 - reach
  room  = 0.0 if room < 0.0

  origin = [rng.signed_float * room,
            rng.signed_float * room,
            rng.signed_float * room]

  { u: u, v: v, n: cross(u, v), origin: origin }
end

# ----------------------------------------------------------- generation

def regenerate args
  if args.state.field_dirty
    build_field args
    args.state.field_dirty = false
    args.state.map_dirty   = true
  end

  return unless args.state.map_dirty

  build_map args
  render_map args
  args.state.map_dirty = false
end

# The engine rejects anything outside [-1, 1]. Clamping here means a bad
# constant gives you an ugly map instead of a crash mid-iteration.
def unit n
  return -1.0 if n < -1.0
  return 1.0 if n > 1.0

  n
end

def fbm x, y, z, octaves
  Geometry.perlin_fbm_noise unit(x), unit(y), unit(z), LACUNARITY, GAIN, octaves
end

# Samples the noise once per cell and caches the raw floats.
def build_field args
  plane  = build_plane args.state.seed
  u      = plane[:u]
  v      = plane[:v]
  n      = plane[:n]
  ox, oy, oz = plane[:origin]
  warp   = args.state.warp
  mask   = args.state.mask

  field = Array.new(GRID_W * GRID_H, 0.0)

  GRID_H.times do |y|
    b   = (y.fdiv(GRID_H - 1) - 0.5) * SPAN
    row = y * GRID_W

    GRID_W.times do |x|
      a = (x.fdiv(GRID_W - 1) - 0.5) * SPAN

      sx = ox + u[0] * a + v[0] * b
      sy = oy + u[1] * a + v[1] * b
      sz = oz + u[2] * a + v[2] * b

      if warp
        # Two warp fields read from parallel slices either side of the plane.
        wa = fbm sx + n[0] * WARP_SHIFT, sy + n[1] * WARP_SHIFT, sz + n[2] * WARP_SHIFT, WARP_OCT
        wb = fbm sx - n[0] * WARP_SHIFT, sy - n[1] * WARP_SHIFT, sz - n[2] * WARP_SHIFT, WARP_OCT

        sx += WARP * (u[0] * wa + v[0] * wb)
        sy += WARP * (u[1] * wa + v[1] * wb)
        sz += WARP * (u[2] * wa + v[2] * wb)
      end

      val = fbm sx, sy, sz, OCTAVES

      if mask
        dx = (x.fdiv(GRID_W - 1) - 0.5) * 2.0
        dy = (y.fdiv(GRID_H - 1) - 0.5) * 2.0
        d  = Math.sqrt(dx * dx + dy * dy)
        d  = 1.0 if d > 1.0
        val -= MASK_GAIN * (d**MASK_POWER)
      end

      field[row + x] = val
    end
  end

  args.state.field = field
end

# Thresholds the cached field, then labels connected regions and keeps only
# the largest. Everything else is marked DISCARDED rather than deleted, so
# you can see what the flood fill threw away.
def build_map args
  field = args.state.field
  t     = args.state.threshold
  cells = Array.new(GRID_W * GRID_H, WALL)

  1.upto(GRID_H - 2) do |y|
    row = y * GRID_W
    1.upto(GRID_W - 2) do |x|
      cells[row + x] = FLOOR if field[row + x] > t
    end
  end

  regions    = find_regions cells
  open_count = 0
  regions.each { |r| open_count += r.length }

  largest_i = nil
  regions.each_with_index do |r, i|
    largest_i = i if largest_i.nil? || r.length > regions[largest_i].length
  end

  if args.state.cull && largest_i
    regions.each_with_index do |r, i|
      next if i == largest_i

      r.each { |idx| cells[idx] = DISCARDED }
    end
  end

  args.state.cells      = cells
  args.state.regions    = regions.length
  args.state.largest    = largest_i ? regions[largest_i].length : 0
  args.state.open_count = open_count
end

# Iterative 4-connected flood fill. Explicit stack, not recursion, because
# mRuby will blow up on deep call chains.
def find_regions cells
  seen    = Array.new(GRID_W * GRID_H, false)
  regions = []

  GRID_H.times do |y|
    row = y * GRID_W

    GRID_W.times do |x|
      start = row + x
      next if seen[start]
      next if cells[start] == WALL

      region = []
      stack  = [start]
      seen[start] = true

      until stack.empty?
        i = stack.pop
        region << i

        cx = i % GRID_W
        cy = i.idiv(GRID_W)

        push_open stack, seen, cells, i - 1,      cx > 0
        push_open stack, seen, cells, i + 1,      cx < GRID_W - 1
        push_open stack, seen, cells, i - GRID_W, cy > 0
        push_open stack, seen, cells, i + GRID_W, cy < GRID_H - 1
      end

      regions << region
    end
  end

  regions
end

def push_open stack, seen, cells, i, in_bounds
  return unless in_bounds
  return if seen[i]
  return if cells[i] == WALL

  seen[i] = true
  stack << i
end

# ------------------------------------------------------------- rendering

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

def render args
  args.outputs.background_color = [10, 11, 16]

  args.outputs.sprites << { x: MAP_X,
                            y: MAP_Y,
                            w: GRID_W * CELL_PX,
                            h: GRID_H * CELL_PX,
                            path: :map }

  render_hud args
end

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

def pct n, total
  (n.fdiv(total) * 100).round(1)
end

def on_off flag
  flag ? "on" : "off"
end

def reset args
  args.state = {}
end

DR.reset