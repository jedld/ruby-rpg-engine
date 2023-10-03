require 'sinatra'
require 'sinatra/streaming'
require 'sinatra/contrib'
require 'bundler'

Bundler.require


$LOAD_PATH << "."

require 'active_support/core_ext/hash'
require 'lib/session'
enable :sessions

require 'mini_magick'
require 'json'

require 'logger'

Faye::WebSocket.load_adapter('thin')

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

EventManager.standard_cli

set :sockets, []

set :session_secret, "fe9707b4704da2a96d0fd3cbbb465756e124b8c391c72a27ff32a062110de589"

helpers do
  def logged_in?
    !session[:username].nil?
  end
end

LEVEL = "example/goblin_ambush"


index_file = File.read(File.join(LEVEL, 'index.json'))
index_hash = JSON.parse(index_file)

TITLE = index_hash["title"]
TILE_PX = index_hash["tile_size"].to_i
HEIGHT = index_hash["height"].to_i
WIDTH = index_hash["width"].to_i
BACKGROUND = index_hash["background"]
LOGIN_BACKGROUND = index_hash["login_background"]
BATTLEMAP = index_hash["map"]
SOUNDTRACKS = index_hash["soundtracks"]

# Logins are of the form: 
# [
#   {
#     "name" : "gomerin",
#     "password" : "gomerin",
#     "role" : ["player"]
#   },
#   {
#     "name" : "dm",
#     "password" : "admin",
#     "role" : ["dm"]
#   }
# ]
LOGINS = index_hash["logins"]

game_session = Session.new
battlemap = BattleMap.new(game_session, File.join(LEVEL, BATTLEMAP))
set :map, battlemap
set :battle, nil
set :ai_controller, nil
set :current_soundtrack, nil
set :logins, LOGINS

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
    file_contents = File.read(file_path)
  else
    halt 404
  end
end

get '/path' do
  content_type :json
  source = params[:from]
  destination = params[:to]
  entity = settings.map.entity_at(source['x'].to_i, source['y'].to_i)

  path = AiController::PathCompute.new(nil, settings.map, entity).compute_path(source['x'].to_i, source['y'].to_i, destination['x'].to_i, destination['y'].to_i)
  cost = settings.map.movement_cost(entity, path)
  placeable = settings.map.placeable?(entity, destination['x'].to_i, destination['y'].to_i)
  { path: path, cost: cost, placeable: placeable }.to_json
end

before do
  redirect to('/login') unless logged_in? || request.path_info == '/login' || request.path_info.start_with?('/assets')
end

get '/login' do
  erb :login, locals: { title: TITLE, background: LOGIN_BACKGROUND }
end


post '/login' do
  username = params[:username]
  password = params[:password]

  # Find the login information for the given username
  login_info = settings.logins.find { |login| login["name"].downcase == username.downcase }

  # If the login information is not found or the password is incorrect, redirect to the login page
  if login_info.nil? || login_info["password"] != password
    content_type :json
    return { error: "Invalid Login Credentials" }.to_json
  end

  # If validation is successful, create a session cookie for the user
  session[:username] = username.downcase

  # Redirect to '/'
  return { status: 'ok' }.to_json
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

    haml :index, locals: { tiles: @my_2d_array, tile_size_px: TILE_PX,
                           background_path: "assets/#{BACKGROUND}", background_width: tiles_dimenstion_width,
                           background_height: tiles_dimenstion_height,
                           battle: settings.battle,
                           soundtrack: settings.current_soundtrack,
                           title: TITLE}
end

get '/update' do
  @my_2d_array = [settings.map.render_custom]
  haml :map, locals: { tiles: @my_2d_array, tile_size_px: TILE_PX, is_setup: (params[:is_setup] == 'true')}
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

        if (settings.map.placeable?(entity, data['message']['to']['x'], data['message']['to']['y']))
          settings.map.move_to!(entity, data['message']['to']['x'], data['message']['to']['y'])
          settings.sockets.each do |socket|
            socket.send({type: 'move', message: {from: data['message']['from'], to: data['message']['to']}}.to_json)
          end
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

post "/start" do
  settings.battle = Battle.new(game_session, settings.map)
  content_type :json
  { status: 'ok' }.to_json
end

get "/tracks" do
  tracks = SOUNDTRACKS.each_with_index.collect do |track, index|
    OpenStruct.new({id: index, url: track['file'], name: track['name'] })
  end
  haml :soundtrack, locals: { tracks: tracks, track_id: params[:track_id].to_i }
end

post "/sound" do
  content_type :json
  track_id = params[:track_id].to_i

  if track_id == -1
    settings.current_soundtrack = nil
    settings.sockets.each do |socket|
      socket.send({type: 'stoptrack', message: { }}.to_json)
    end
  else
    url = SOUNDTRACKS[track_id]['file']
    
    settings.current_soundtrack = { url: url, id: track_id }

    settings.sockets.each do |socket|
      socket.send({type: 'track', message: { url: url, id: track_id }}.to_json)
    end
  end
  { status: 'ok' }.to_json
end

post "/volume" do
  content_type :json
  volume = params[:volume].to_i
  settings.sockets.each do |socket|
    socket.send({type: 'volume', message: { volume: volume }}.to_json)
  end
  { status: 'ok' }.to_json
end


# sample request: {"battle_turn_order"=>{"0"=>{"id"=>"f437404e-52f9-40d2-b7d4-d6390d397d30", "group"=>"a"}, "1"=>{"id"=>"afe24663-a079-4390-9fbb-c12218b46f7b", "group"=>"a"}}}::1 - - [02/Oct/2023:19:26:41 +0800] "POST /battle HTTP/1.1" 2
post "/battle" do
  content_type :json
  settings.battle = Battle.new(game_session, settings.map)
  settings.ai_controller =  AiController::Standard.new
  params[:battle_turn_order].values.each do |param_item|
    entity = settings.map.entity_by_uid(param_item['id'])
    settings.ai_controller.register_handlers_on(entity)
    settings.battle.add(entity, param_item['group'].to_sym)
    entity.reset_turn!(settings.battle)
  end
  settings.battle.start
  settings.sockets.each do |socket|
    socket.send({type: 'initiative', message: { }}.to_json)
  end
  settings.battle.start_turn

  action = settings.ai_controller.move_for(settings.battle.current_turn, settings.battle)
  settings.battle.action!(action)
  settings.battle.commit(action)

  { status: 'ok' }.to_json
end

get "/turn_order" do
  haml :battle, locals: { battle: settings.battle }
end

def ai_loop
  entity = settings.battle.current_turn
  cycles = 0
  loop do
    cycles += 1
    action = settings.ai_controller.move_for(entity, settings.battle)

    if action.nil?
      puts "#{entity.name}: End turn."
      break
    end

    settings.battle.action!(action)
    settings.battle.commit(action)
    break if action.nil?
  end
end

post "/next_turn" do
  if settings.battle
    
    settings.battle.end_turn
    settings.battle.next_turn
    settings.battle.start_turn

    if settings.battle.current_turn.concious?
      ai_loop
    else
      settings.battle.next_turn
      settings.battle.start_turn
    end

    settings.sockets.each do |socket|
      socket.send({type: 'initiative', message: { }}.to_json)
      socket.send({type: 'move', message: { }}.to_json)
    end
  end
end

post "/stop" do
  if settings.battle
    settings.battle = nil
    settings.ai_controller = nil

    settings.sockets.each do |socket|
      socket.send({type: 'stop', message: { }}.to_json)
    end
  end
end