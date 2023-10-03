function command(command) {
  ws.send(JSON.stringify({type: 'command', user: 'username', message: {action: "command", command: command }}));
}



$(document).ready(function() {
  var active_background_sound = null;
  var mediaElementSource = null;
  var active_track_id = -1;

  function playSound(url, track_id) {
    if (active_background_sound) {
      active_background_sound.pause();
      active_background_sound = null;
    }
  
    active_background_sound = new Audio('/assets/' + url);
    active_background_sound.loop = true;
    active_track_id = track_id;
    active_background_sound.play();
    $('.volume-slider').val(active_background_sound.volume * 100);
  }

  var ws = new WebSocket('ws://' + window.location.host + '/event');
  function keepAlive(timeout = 5000) { 
      if (ws.readyState == ws.OPEN) {  
          ws.send(JSON.stringify({type: 'ping', message: "ping"} ));  
      }  
      setTimeout(keepAlive, timeout);  
  }
  

  function refreshTileSet(is_setup) {
    $.ajax({
      url: '/update',
      type: 'GET',
      data: { is_setup: is_setup },
      success: function(data) {
        $('.tiles-container').html(data);
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.error('Error refreshing tiles container:', textStatus, errorThrown);
      }
    });
  }

  function refreshTurnOrder() {
    $.ajax({
      url: '/turn_order',
      type: 'GET',
      success: function(data) {
        $('#turn-order').html(data);
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.error('Error refreshing turn order:', textStatus, errorThrown);
      }
    });
  }

  keepAlive()
  refreshTileSet()

  ws.onmessage = function(event) {
    var data = JSON.parse(event.data);

    switch (data.type) {
      case 'move':
        refreshTileSet();
        break;
      case 'message':
        console.log(data.message); // log the message on the console
        break;
      case 'info':
        break;
      case 'error':
        console.error(data.message);
        break;
      case 'track':
        url = data.message.url;
        track_id = data.message.track_id;
        playSound(url, track_id);
        break;
      case 'stoptrack':
          if (active_background_sound) {
            const audioCtx = new AudioContext();
            const source = audioCtx.createMediaElementSource(active_background_sound);
            const gainNode = audioCtx.createGain();
            source.connect(gainNode);
            gainNode.connect(audioCtx.destination);
            gainNode.gain.setValueAtTime(1, audioCtx.currentTime);
            gainNode.gain.linearRampToValueAtTime(0, audioCtx.currentTime + 2);
            gainNode.addEventListener('ended', function() {
              active_background_sound.pause();
              active_background_sound = null;
              active_track_id = -1;
            });
          }
        break;
      case 'volume':
        console.log('volume ' + data.message.volume);
        if (active_background_sound) {
          active_background_sound.volume = data.message.volume / 100;
          $('.volume-slider').val(data.message.volume, true);
        }
        break;
      case 'initiative':
        console.log('initiative ' + data.message);
        refreshTurnOrder();
        
        $('#start-initiative').hide();
        $('#start-battle').hide();
        $('#end-battle').show();
        break;
      case 'stop':
        $('#battle-turn-order').fadeOut()
        $('#start-battle').show();
        $('#end-battle').hide();
        break;
    }
  };

  // recover startup state
  var currentSoundtrack = $('body').data('soundtrack-url')

  $('body').on('click', function(event) {
    if (currentSoundtrack) {
      var track_id = $('body').data('soundtrack-id')
      playSound(currentSoundtrack, track_id);
      currentSoundtrack = null;
    }
  });

  // Listen for changes on the volume slider
  $('.modal-content').on('input', '.volume-slider', function() {
    if (active_background_sound) {
      $.ajax({
        url: '/volume',
        type: 'POST',
        data: { volume: $(this).val() },
        success: function(data) {
          console.log('Volume updated successfully');
        },
        error: function(jqXHR, textStatus, errorThrown) {
          console.error('Error updating volume:', textStatus, errorThrown);
        }
      });
    }
  });
  
  // Use event delegation to handle popover menu clicks
  $('.tiles-container').on('click', '.tile', function() {


    if (moveMode) {
      // retrieve data attributes from the parent .tile element
      var coordsx = $(this).data('coords-x');
      var coordsy = $(this).data('coords-y');
      if (coordsx != source.x || coordsy != source.y) {
        moveMode = false
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ws.send(JSON.stringify({type: 'message', user: 'username', message: {action: "move", from: source, to: {x: coordsx, y: coordsy} }}));
      }
    } else {
      $('.tiles-container .popover-menu').hide();
      $(this).find('.popover-menu').toggle();
    }
  });

  var moveMode = false;
  var source = null;
  var battle_setup = false;
  var battle_entity_list = [];

  var canvas = document.createElement('canvas');
  canvas.width = $('.tiles-container').data('width');
  canvas.height = $('.tiles-container').data('height');
  canvas.style.top = '0px';
  canvas.style.position = "absolute";
  canvas.style.zIndex = 999;
  canvas.style.pointerEvents = "none"; // Add this line
  const body = document.getElementsByTagName("body")[0];
  body.appendChild(canvas);
  var ctx = canvas.getContext('2d');

  $('.tiles-container').on('mouseover', '.tile', function() {
    var coordsx = $(this).data('coords-x');
    var coordsy = $(this).data('coords-y');
    $('#coords-box').html('<p>X: ' + coordsx + '</p><p>Y: ' + coordsy + '</p>');
    if (moveMode) {
      $.ajax({
        url: '/path',
        type: 'GET',
        data: {from: source, to: {x: coordsx, y: coordsy}},
        success: function(data) {
          // data is of the form [[0,0],[1,1],[2,2]]
          console.log('Path request successful:', data.path);
          $('.highlighted').removeClass('highlighted'); 
          // Highlight the squares returned by data
          var cost = data.cost
          var placeable = data.placeable
          var rect = canvas.getBoundingClientRect();
          var scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;
          var scrollTop = window.pageYOffset || document.documentElement.scrollTop;

          ctx.clearRect(0, 0, canvas.width, canvas.height);
          ctx.beginPath();
          ctx.strokeStyle = 'red';
          ctx.lineWidth = 5;
          data.path.forEach(function(coords, index) {
            var x = coords[0];
            var y = coords[1];
            var tile = $('.tile[data-coords-x="' + x + '"][data-coords-y="' + y + '"]');
            var tileRect = tile[0].getBoundingClientRect();
            var centerX = tileRect.left + tileRect.width / 2 + scrollLeft;
            var centerY = tileRect.top + tileRect.height / 2 + scrollTop;

            if (index === 0) {
              ctx.moveTo(centerX, centerY);
            } else {
              ctx.lineTo(centerX, centerY);
            }
            if (index === data.path.length - 1) {
              var arrowSize = 10;
              var angle = Math.atan2(centerY - prevY, centerX - prevX);
              if (placeable) {
                ctx.moveTo(centerX - arrowSize * Math.cos(angle - Math.PI / 6), centerY - arrowSize * Math.sin(angle - Math.PI / 6));
                ctx.lineTo(centerX, centerY);
                ctx.lineTo(centerX - arrowSize * Math.cos(angle + Math.PI / 6), centerY - arrowSize * Math.sin(angle + Math.PI / 6));
              } else {
                ctx.moveTo(centerX - arrowSize, centerY - arrowSize);
                ctx.lineTo(centerX + arrowSize, centerY + arrowSize);
                ctx.moveTo(centerX + arrowSize, centerY - arrowSize);
                ctx.lineTo(centerX - arrowSize, centerY + arrowSize);
              }
              ctx.font = "20px Arial";
              ctx.fillStyle = "red";
              ctx.fillText(cost + "ft", centerX, centerY  +  tileRect.height / 2);
            }
            
            prevX = centerX;
            prevY = centerY;
          });
          ctx.stroke();
          
        },
        error: function(jqXHR, textStatus, errorThrown) {
          console.error('Error requesting path:', textStatus, errorThrown);
        }
      });
    }
  });


  $('.tiles-container').on('click', '.popover-menu li', function() {
    // retrieve data attributes from the parent .tile element
    var coordsx = $(this).closest('.tile').data('coords-x');
    var coordsy = $(this).closest('.tile').data('coords-y');
    var item = $(this).data('item');
    if (item === 'move') {
      console.log('Menu item ' + item + ' clicked at X: ' + coordsx + ', Y: ' + coordsy);
      moveMode = true
      source = {x: coordsx, y: coordsy}
      $('.tiles-container .popover-menu').hide();
    }
  });

  //floating menu interaction
  $('#expand-menu').click(function() {
    $('#menu').toggle()
  })

  $('#start-battle').click(function() {
    $('#battle-turn-order').fadeIn()
    battle_setup = true
    refreshTileSet(true)
  });

  $('#start-initiative').click(function() {
    // Get the list of items in the battle turn order
    const $turnOrderItems = $('.turn-order-item');
    const battle_turn_order = $turnOrderItems.map(function() {
      const id = $(this).data('id');
      const group = $(this).find('.group-select').val();
      return { id, group };
    }).get();

    // Call the POST /battle endpoint with the list of items in the battle turn order
    $.ajax({
      url: '/battle',
      type: 'POST',
      data: { battle_turn_order },
      success: function(data) {
        $('.add-to-turn-order').hide();
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.error('Error requesting battle:', textStatus, errorThrown);
      }
    });
  })

  $('#end-battle').click(function() {
      $.ajax({
        url: '/stop',
        type: 'POST',
        success: function(data) {
          console.log('Battle stopped successfully');
        },
        error: function(jqXHR, textStatus, errorThrown) {
          console.error('Error stopping battle:', textStatus, errorThrown);
        }
      });
    });
  
    $('.tiles-container').on('click', '.add-to-turn-order', function(event) {
    const $this = $(this);
    const { id, name } = $this.data();

    const index = battle_entity_list.findIndex(entity => entity.id === id);

    if (index === -1) {
      battle_entity_list.push({ id, group: 'a', name });
      $this.find('i.glyphicon').removeClass('glyphicon-plus').addClass('glyphicon-minus');
      $this.css('background-color', 'red');
      
      // Add name to turn order list
      const $turnOrder = $('#turn-order');
      const $newItem = $('<div data-id="'+ id +'">').addClass('turn-order-item').text(name);
      const $removeButton = $('<button>').addClass('remove-turn-order-item').text('Remove');
      const $groupSelect = $('<select>').addClass('group-select').append(
        $('<option>').val('a').text('Group A'),
        $('<option>').val('b').text('Group B'),
        $('<option>').val('c').text('Group C')
      );
      const $turnOrderItem = $('<div>').addClass('turn-order-item').append(
        $('<span>').addClass('name').text(name),
        $groupSelect,
        $removeButton
      );
      $newItem.append($groupSelect);
      $newItem.append($removeButton);
      $turnOrder.append($newItem);
      
    } else {
      battle_entity_list.splice(index, 1);
      $this.find('i.glyphicon').removeClass('glyphicon-minus').addClass('glyphicon-plus');
      $this.css('background-color', 'green');
      
      // Remove name from turn order list
      const $turnOrderItem = $('.turn-order-item').filter(function() {
        return $(this).text() === name;
      });
      $turnOrderItem.remove();
    }

    event.stopPropagation();
    });
    
    // Remove turn order item on button click
    $('#turn-order').on('click', '.remove-turn-order-item', function() {
      $(this).parent().remove();
    });

    $('#turn-order').on('click', '#next-turn', function() {
      $.ajax({
        url: '/next_turn',
        type: 'POST',
        success: function(data) {
          console.log('Next turn request successful:', data);
        },
        error: function(jqXHR, textStatus, errorThrown) {
          console.error('Error requesting next turn:', textStatus, errorThrown);
        }
      });
    });
    

  $('#select-soundtrack').click(function() {
    $.get('/tracks', { track_id: active_track_id }, function(data) {
      $('.modal-content').html(data);
      $('#modal-1').modal('show');
    });
  });

  $('.modal-content').on('click', '.play', function() {
    var trackId = $('input[name="track_id"]:checked').val();
    $.ajax({
      url: '/sound',
      type: 'POST',
      data: {track_id: trackId },
      success: function(data) {
        console.log('Sound request successful:', data);
        $('#modal-1').modal('hide');
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.error('Error requesting sound:', textStatus, errorThrown);
      }
    });
  });


$(function() {
  var isDragging = false;
  var lastX, lastY;

  $('#battle-turn-order .header').mousedown(function(e) {
    isDragging = true;
    lastX = e.clientX;
    lastY = e.clientY;
  });

  $(document).mousemove(function(e) {
    if (isDragging) {
      var deltaX = e.clientX - lastX;
      var deltaY = e.clientY - lastY;
      var offset = $('#battle-turn-order').offset();
      $('#battle-turn-order').offset({
        top: offset.top + deltaY,
        left: offset.left + deltaX
      });
      lastX = e.clientX;
      lastY = e.clientY;
    }
  }).mouseup(function() {
    isDragging = false;
  });
});

});

