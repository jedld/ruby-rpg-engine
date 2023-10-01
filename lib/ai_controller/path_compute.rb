# This module provides a PathCompute class that computes the shortest path between two points on a map.
# It uses the A* algorithm to find the path and caches the adjacent nodes to improve performance.
# The class takes a battle, map, and entity as input and returns a path as an array of coordinates.
# If no path is found, it returns nil.
require 'pqueue'
module AiController
  MAX_DISTANCE = 4_000_000

  class PathCompute
    # Initializes the PathCompute object with the given battle, map, and entity.
    # The max_x and max_y values are set to the size of the map.
    # The adjacent_cache is initialized as an empty hash.
    def initialize(battle, map, entity)
      @entity = entity
      @map = map
      @battle = battle
      @max_x, @max_y = @map.size
      @adjacent_cache = {}
    end

    # Computes the shortest path between the source and destination coordinates on the map.
    # It uses the A* algorithm to find the path and caches the adjacent nodes to improve performance.
    # Returns the path as an array of coordinates.
    # If no path is found, it returns nil.
    def compute_path(source_x, source_y, destination_x, destination_y)
      pq = PQueue.new([]) { |a, b| a[1] < b[1] }
      visited_nodes = Set.new

      g_scores = Array.new(@max_x) { Array.new(@max_y, MAX_DISTANCE) }
      f_scores = Array.new(@max_x) { Array.new(@max_y, MAX_DISTANCE) }

      g_scores[source_x][source_y] = 0
      f_scores[source_x][source_y] = heuristic(source_x, source_y, destination_x, destination_y)

      pq << [[source_x, source_y], f_scores[source_x][source_y]]

      until pq.empty?
        current_node, _ = pq.pop

        return reconstruct_path(current_node, source_x, source_y, g_scores) if current_node == [destination_x, destination_y]

        visited_nodes.add(current_node)

        get_adjacent_from(*current_node).each do |neighbor|
          next if visited_nodes.include?(neighbor)

          tentative_g_score = g_scores[current_node[0]][current_node[1]] + heuristic(neighbor[0], neighbor[1], current_node[0], current_node[1])

          if tentative_g_score < g_scores[neighbor[0]][neighbor[1]]
            g_scores[neighbor[0]][neighbor[1]] = tentative_g_score
            f_scores[neighbor[0]][neighbor[1]] = tentative_g_score + heuristic(neighbor[0], neighbor[1], destination_x, destination_y)
            pq << [neighbor, f_scores[neighbor[0]][neighbor[1]]]
          end
        end
      end

      return nil # No path found
    end

    # Computes the heuristic distance between two points on the map.
    # It uses the Euclidean distance formula to calculate the distance.
    def heuristic(x1, y1, x2, y2)
      Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
    end

    # Reconstructs the path from the destination to the source using the g_scores array.
    # Returns the path as an array of coordinates.
    def reconstruct_path(current, start_x, start_y, g_scores)
      path = [current]
      while current != [start_x, start_y]
        min_score = Float::INFINITY
        next_node = nil

        get_adjacent_from(*current).each do |neighbor|
          if g_scores[neighbor[0]][neighbor[1]] < min_score
            min_score = g_scores[neighbor[0]][neighbor[1]]
            next_node = neighbor
          end
        end

        break unless next_node

        path << next_node
        current = next_node
      end

      path.reverse
    end

    # Returns the adjacent nodes to the given position on the map.
    # It caches the adjacent nodes to improve performance.
    def get_adjacent_from(pos_x, pos_y)
      return @adjacent_cache[[pos_x, pos_y]] if @adjacent_cache.key?([pos_x, pos_y])

      valid_paths = Set.new
      [-1, 0, 1].each do |x_op|
        [-1, 0, 1].each do |y_op|
          cur_x = pos_x + x_op
          cur_y = pos_y + y_op

          next if cur_x < 0 || cur_y < 0 || cur_x >= @max_x || cur_y >= @max_y
          next if x_op.zero? && y_op.zero?
          next if !@map.passable?(@entity, cur_x, cur_y, @battle)

          valid_paths.add([cur_x, cur_y])
        end
      end

      @adjacent_cache[[pos_x, pos_y]] = valid_paths
      valid_paths
    end
  end
end