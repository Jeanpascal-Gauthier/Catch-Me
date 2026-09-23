# Noise-field sampling and connected-region generation.

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

# Rejection-samples a random unit vector from the LCG.
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

# 3D dot product.
def dot a, b
  a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
end

# 3D cross product.
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

# Rebuilds the noise field and/or the map only when their dirty flags are
# set, then re-renders the cached map sprite if the map changed.
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

# Clamped fBm noise sample at (x, y, z) with the given octave count.
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
  args.state.largest     = largest_i ? regions[largest_i].length : 0
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

# Pushes neighbor cell i onto the flood-fill stack if it's in bounds,
# unvisited, and not a wall.
def push_open stack, seen, cells, i, in_bounds
  return unless in_bounds
  return if seen[i]
  return if cells[i] == WALL

  seen[i] = true
  stack << i
end
