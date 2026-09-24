# Sanity checks for the Pathfinding module (see pathfinding.rb).
#
# DragonRuby's built-in test runner picks these up automatically: any class
# ending in "Tests" with methods starting "test_" runs when the file is
# saved while the game is running, or on demand from the console with
# `$tests.start`.
class PathfindingTests
  def test_find_path_straight_line args, assert
    cells = Array.new(GRID_W * GRID_H, WALL)
    y = 5
    0.upto(9) { |x| cells[y * GRID_W + x] = FLOOR }

    start = y * GRID_W
    goal  = y * GRID_W + 9

    path = Pathfinding.find_path cells, start, goal

    assert.true! path, "expected a path to be found"
    assert.equal! path.first, start
    assert.equal! path.last, goal
    assert.equal! path.length, 10
  end

  def test_find_path_returns_nil_when_unreachable args, assert
    cells = Array.new(GRID_W * GRID_H, WALL)
    cells[0] = FLOOR
    cells[GRID_W * GRID_H - 1] = FLOOR

    path = Pathfinding.find_path cells, 0, GRID_W * GRID_H - 1

    assert.nil! path
  end

  def test_reachable_from_stops_at_disconnected_region args, assert
    cells = Array.new(GRID_W * GRID_H, WALL)
    cells[0] = FLOOR
    cells[1] = FLOOR
    cells[GRID_W * GRID_H - 1] = FLOOR # disconnected island, not reachable from 0

    reachable = Pathfinding.reachable_from cells, 0

    assert.equal! reachable.sort, [0, 1]
  end
end
