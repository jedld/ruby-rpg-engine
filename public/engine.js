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
        debugger;
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
        ws.send(JSON.stringify({type: 'message', user: 'username', message: {action: "move", from: source, to: {x: coordsx, y: coordsy} }}));
      }
    } else {
      $('.tiles-container .popover-menu').hide();
      $(this).find('.popover-menu').toggle();
    }
  });

  $('.tiles-container').on('mouseover', '.tile', function() {
    var coordsx = $(this).data('coords-x');
    var coordsy = $(this).data('coords-y');
    $('#coords-box').html('<p>X: ' + coordsx + '</p><p>Y: ' + coordsy + '</p>');
  });

  var moveMode = false;
  var source = null;

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

