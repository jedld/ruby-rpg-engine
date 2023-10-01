require 'sinatra'
require 'sinatra/streaming'
require 'bundler'

Bundler.require


$LOAD_PATH << "."

require 'active_support/core_ext/hash'
require 'lib/session'

require 'mini_magick'
require 'json'

require 'logger'

Faye::WebSocket.load_adapter('thin')

logger = Logger.new(STDOUT)
logger.level = Logger::INFO


set :sockets, []

LEVEL = "example/goblin_ambush"


index_file = File.read(File.join(LEVEL, 'index.json'))
index_hash = JSON.parse(index_file)

TILE_PX = index_hash["tile_size"].to_i
HEIGHT = index_hash["height"].to_i
WIDTH = index_hash["width"].to_i
BACKGROUND = index_hash["background"]
BATTLEMAP = index_hash["map"]

session = Session.new
battlemap = BattleMap.new(session, File.join(LEVEL, BATTLEMAP))
set :map, battlemap

# @battle = Battle.new(session, @map)
# @fighter = PlayerCharacter.load(File.join('fixtures', 'high_elf_fighter.yml'))
# @npc = Npc.new(:goblin, name: 'a')
# @npc2 = Npc.new(:goblin, name: 'b')
# @npc3 = Npc.new(:ogre, name: 'c')
# @battle.add(@fighter, :a, position: :spawn_point_1, token: 'G')
# @battle.add(@npc, :b, position: :spawn_point_2, token: 'g')
# @battle.add(@npc2, :b, position: :spawn_point_3, token: 'O')
# @fighter.reset_turn!(@battle)
# @npc.reset_turn!(@battle)
# @npc2.reset_turn!(@battle)
def create_2d_array(n, m)
  Array.new(n) { Array.new(m) { rand(1..4) } }
end

get '/assets/:asset_name' do
  asset_name = params[:asset_name]
  file_path = File.join(LEVEL, "assets", asset_name)

  if File.exist?(file_path)
    send_file file_path
  else
    status 404
    "File not found: #{asset_name}"
  end
end

get '/path' do
  content_type :json
  source = params[:from]
  destination = params[:to]
  entity = settings.map.entity_at(source['x'].to_i, source['y'].to_i)
  path = AiController::PathCompute.new(nil, settings.map, entity).compute_path(source['x'].to_i, source['y'].to_i, destination['x'].to_i, destination['y'].to_i)
  cost = settings.map.movement_cost(entity, path)
  { path: path, cost: cost }.to_json
end

get '/' do
    file_path = File.join(LEVEL, "assets", BACKGROUND)
    image = MiniMagick::Image.open(file_path)
    width = image.width
    height = image.height

    @my_2d_array = [settings.map.render_custom]
    logger.info @my_2d_array

    tiles_dimenstion_height = HEIGHT * TILE_PX
    tiles_dimenstion_width = WIDTH * TILE_PX

    haml :index, locals: { tiles: @my_2d_array, tile_size_px: TILE_PX, background_path: "assets/#{BACKGROUND}", background_width: tiles_dimenstion_width, background_height: tiles_dimenstion_height }
end

get '/update' do
  @my_2d_array = [settings.map.render_custom]
  haml :map, locals: { tiles: @my_2d_array, tile_size_px: TILE_PX}
end

get '/event' do
  if Faye::WebSocket.websocket?(request.env)
    ws = Faye::WebSocket.new(request.env)

    ws.on :open do |event|
      logger.info("open #{ws}")
      settings.sockets << ws
      ws.send({type: 'info', message: ''}.to_json)
    end

    ws.on :message do |event|
      data = JSON.parse(event.data)
      case data['type']
      when 'ping'
        ws.send({type: 'ping', message: 'pong'}.to_json)
      when 'message'
       logger.info("message #{data['message']}")
       if (data['message']['action'] == 'move')
        entity = settings.map.entity_at(data['message']['from']['x'], data['message']['from']['y'])
        settings.map.move_to!(entity, data['message']['to']['x'], data['message']['to']['y'])
        settings.sockets.each do |socket|
          socket.send({type: 'move', message: {from: data['message']['from'], to: data['message']['to']}}.to_json)
        end
       end
      else
        ws.send({type: 'error', message: 'Unknown command!'}.to_json)
      end
    end

    ws.on :close do |event|
      logger.info("close #{ws}")
      settings.sockets.delete(ws)
    end

    ws.rack_response
  else
    status 400
    "Websocket connection required"
  end
end