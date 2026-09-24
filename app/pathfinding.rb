# Grid pathfinding over the walkable (FLOOR) tiles produced by proc-gen.
#
# Kept independent of both generation.rb and rendering.rb: anything that
# owns a `cells` array (NPCs today, the player later) can use this without
# pulling in map-building or drawing code. Movement is 4-directional to
# match the connectivity the generator itself uses when flood-filling
# regions (see find_regions in generation.rb) -- allowing diagonal steps
# here would let something cut across a wall corner that the generator
# never actually treated as connected.

# Simple binary min-heap of [score, node] pairs, used as the A* open set.
class MinHeap
  def initialize
    @data = []
  end

  def empty?
    @data.empty?
  end

  def push node, score
    @data << [score, node]
    sift_up @data.length - 1
  end

  # Removes and returns the node with the lowest score.
  def pop
    return nil if @data.empty?

    top  = @data[0]
    last = @data.pop
    unless @data.empty?
      @data[0] = last
      sift_down 0
    end

    top[1]
  end

  def sift_up i
    while i > 0
      parent = (i - 1).idiv 2
      break if @data[parent][0] <= @data[i][0]

      @data[parent], @data[i] = @data[i], @data[parent]
      i = parent
    end
  end

  def sift_down i
    size = @data.length

    loop do
      left     = i * 2 + 1
      right    = i * 2 + 2
      smallest = i
      smallest = left  if left  < size && @data[left][0]  < @data[smallest][0]
      smallest = right if right < size && @data[right][0] < @data[smallest][0]
      break if smallest == i

      @data[smallest], @data[i] = @data[i], @data[smallest]
      i = smallest
    end
  end
end

module Pathfinding
  # In-bounds, walkable (FLOOR) 4-directional neighbors of cell index i.
  def self.neighbors_of i, cells
    x = i % GRID_W
    y = i.idiv GRID_W
    result = []

    result << (i - 1)      if x > 0            && cells[i - 1]      == FLOOR
    result << (i + 1)      if x < GRID_W - 1    && cells[i + 1]      == FLOOR
    result << (i - GRID_W) if y > 0             && cells[i - GRID_W] == FLOOR
    result << (i + GRID_W) if y < GRID_H - 1    && cells[i + GRID_W] == FLOOR

    result
  end

  # Every FLOOR tile reachable from `start` by 4-connected walking,
  # including `start` itself. Returns [] if `start` isn't walkable.
  # This is a plain BFS, run fresh each time -- it's how callers should
  # check reachability rather than assuming the whole map is one region.
  def self.reachable_from cells, start
    return [] if cells[start] != FLOOR

    seen = Array.new(GRID_W * GRID_H, false)
    seen[start] = true
    queue = [start]
    head  = 0

    until head == queue.length
      i = queue[head]
      head += 1

      neighbors_of(i, cells).each do |n|
        next if seen[n]

        seen[n] = true
        queue << n
      end
    end

    queue
  end

  # Manhattan distance, admissible for 4-directional movement at uniform cost.
  def self.heuristic a, b
    ax = a % GRID_W
    ay = a.idiv GRID_W
    bx = b % GRID_W
    by = b.idiv GRID_W

    (ax - bx).abs + (ay - by).abs
  end

  # A* search from `start` to `goal` over `cells`. Returns an array of cell
  # indices from start to goal inclusive, or nil if no path exists (either
  # cell is a wall, or goal is in a disconnected region).
  def self.find_path cells, start, goal
    return [start] if start == goal
    return nil if cells[start] != FLOOR || cells[goal] != FLOOR

    g_score   = { start => 0 }
    came_from = {}
    closed    = {}
    open      = MinHeap.new
    open.push start, heuristic(start, goal)

    until open.empty?
      current = open.pop
      next if closed[current]

      closed[current] = true
      return reconstruct_path(came_from, current) if current == goal

      neighbors_of(current, cells).each do |n|
        next if closed[n]

        tentative_g = g_score[current] + 1
        if g_score[n].nil? || tentative_g < g_score[n]
          g_score[n]   = tentative_g
          came_from[n] = current
          open.push n, tentative_g + heuristic(n, goal)
        end
      end
    end

    nil
  end

  def self.reconstruct_path came_from, current
    path = [current]
    while came_from.key? current
      current = came_from[current]
      path << current
    end
    path.reverse
  end
end
