module MovementHelper
  def compute_actual_moves(entity, current_moves, map, battle, movement_budget)
    actual_moves = []
    current_moves.each_with_index do |m, index|
      if index.positive?
        movement_budget -= if map.difficult_terrain?(entity, *m, battle)
                             2
                           else
                             1
                           end
      end

      break if movement_budget.negative?

      actual_moves << m
    end
    last_move = actual_moves.last

    return [] if actual_moves.empty?
    actual_moves.pop unless map.placeable?(entity, last_move[0], last_move[1], battle)

    actual_moves
  end
end