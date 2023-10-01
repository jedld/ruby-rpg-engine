$(document).ready(function() {

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
    }
  };

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
  canvas.width = document.documentElement.clientWidth;
  canvas.height = document.documentElement.clientHeight;
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
          console.log('Path request successful:', data);
          $('.highlighted').removeClass('highlighted'); 
          // Highlight the squares returned by data


          ctx.clearRect(0, 0, canvas.width, canvas.height);
          ctx.beginPath();
          ctx.strokeStyle = 'red';
          ctx.lineWidth = 5;
          data.forEach(function(coords, index) {
            var x = coords[0];
            var y = coords[1];
            var tile = $('.tile[data-coords-x="' + x + '"][data-coords-y="' + y + '"]');
            var rect = tile[0].getBoundingClientRect();
            var centerX = rect.left + rect.width / 2;
            var centerY = rect.top + rect.height / 2;
            if (index === 0) {
              ctx.moveTo(centerX, centerY);
            } else {
              ctx.lineTo(centerX, centerY);
            }
            if (index === data.length - 1) {
              var arrowSize = 10;
              var angle = Math.atan2(centerY - prevY, centerX - prevX);
              ctx.moveTo(centerX - arrowSize * Math.cos(angle - Math.PI / 6), centerY - arrowSize * Math.sin(angle - Math.PI / 6));
              ctx.lineTo(centerX, centerY);
              ctx.lineTo(centerX - arrowSize * Math.cos(angle + Math.PI / 6), centerY - arrowSize * Math.sin(angle + Math.PI / 6));
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

});

