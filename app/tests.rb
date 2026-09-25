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

# Tagging swaps control between the player and an NPC (see player.rb). These
# build their own throwaway args rather than touching the live game state.
class TagTests
  # An open room in the corner of an otherwise solid map, plus the tag
  # bookkeeping check_tag expects to find already initialized.
  def world player, npcs
    cells = Array.new(GRID_W * GRID_H, WALL)
    2.upto(20) do |y|
      2.upto(20) { |x| cells[y * GRID_W + x] = FLOOR }
    end

    { state: { cells: cells,
               player: player,
               npcs: npcs,
               tagged_at: -TAG_COOLDOWN,
               immune_index: nil,
               switched_at: -30 } }
  end

  def npc x, y, color = [1, 2, 3]
    { x: x, y: y, color: color, path: nil, path_index: 0, waypoint: 0 }
  end

  def test_touching_an_npc_swaps_control args, assert
    w = world({ x: 5.0, y: 5.0, color: [9, 9, 9] }, [npc(5.2, 5.0)])

    check_tag w

    assert.equal! w.state.player[:x], 5.2, "player should take over the NPC's block"
    assert.equal! w.state.npcs[0][:x], 5.0, "vacated block should stay where the player was"
    assert.equal! w.state.immune_index, 0, "the block just left should be immune"
  end

  # Color belongs to the block, so taking one over means taking its color.
  def test_swapping_carries_each_block_color args, assert
    w = world({ x: 5.0, y: 5.0, color: [9, 9, 9] }, [npc(5.2, 5.0, [1, 2, 3])])

    check_tag w

    assert.equal! w.state.player[:color], [1, 2, 3], "player takes the tagged block's color"
    assert.equal! w.state.npcs[0][:color], [9, 9, 9], "vacated block keeps the color it had"
  end

  def test_no_swap_when_out_of_range args, assert
    w = world({ x: 5.0, y: 5.0 }, [npc(9.0, 5.0)])

    check_tag w

    assert.equal! w.state.player[:x], 5.0, "player should not move with nothing in range"
    assert.nil! w.state.immune_index
  end

  def test_immunity_stops_control_bouncing_back args, assert
    w = world({ x: 5.0, y: 5.0 }, [npc(5.2, 5.0)])

    check_tag w
    landed = w.state.player[:x]

    # cooldown expired, but the two are still standing on each other
    w.state.tagged_at = -TAG_COOLDOWN
    check_tag w

    assert.equal! w.state.player[:x], landed, "control should not bounce straight back"
    assert.equal! w.state.immune_index, 0
  end

  def test_immunity_clears_once_the_pair_separate args, assert
    w = world({ x: 5.0, y: 5.0 }, [npc(5.2, 5.0)])

    check_tag w
    w.state.npcs[0][:x] = 12.0
    w.state.tagged_at = -TAG_COOLDOWN
    check_tag w

    assert.nil! w.state.immune_index, "immunity should lift once they move apart"
  end
end
