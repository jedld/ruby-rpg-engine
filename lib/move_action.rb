class MoveAction < Action
  attr_accessor :move_path

  def resolve(session, opts = {})
    raise "no path specified" if move_path.nil? || move_path.empty?
  end
end