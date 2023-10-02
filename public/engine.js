function command(command) {
  ws.send(JSON.stringify({type: 'command', user: 'username', message: {action: "command", command: command }}));
}

function playSound(url) {
  const audio = new Audio(url);
  audio.play();
}

$(document).ready(function() {
  var active_background_sound = null;
  var active_track_id = -1;

  var ws = new WebSocket('ws://' + window.location.host + '/event');
  function keepAlive(timeout = 5000) { 
      if (ws.readyState == ws.OPEN) {  
          ws.send(JSON.stringify({type: 'ping', message: "ping"} ));  
      }  
      setTimeout(keepAlive, timeout);  
  }
  

  function refreshTileSet() {
    $.ajax({
      url: '/update',
      type: 'GET',
      success: function(data) {
        $('.tiles-container').html(data);
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.error('Error refreshing tiles container:', textStatus, errorThrown);
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
        if (active_background_sound) {
          active_background_sound.pause();
          active_background_sound = null;
        }

        active_background_sound = new Audio('/assets/' + url);
        active_background_sound.loop = true;
        active_track_id = data.message.id;
        active_background_sound.play();
        $('.volume-slider').val(active_background_sound.volume * 100);
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
    }
  };

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
    $.ajax({
      url: '/start',
      type: 'GET',
      success: function(data) {
        console.log('Start request successful:', data);
        $('#start-battle').toggle()
        $('#modal-1').modal('show');
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.error('Error requesting start:', textStatus, errorThrown);
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

});

