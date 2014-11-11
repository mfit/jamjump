'use strict';

function Toolbar(game) {
  this.game = game;
}

Toolbar.prototype = {
  draw: function() {
    var that = this;
    // Draw a debug / settings toolbar using jquery
    $("document").ready(function() {
      var tb;
      tb = $("body").append('<div class="toolbar">');
      tb.append('<button data-func="setsize" data-x="1920" data-y="600">Large</button>');
      tb.append('<button data-func="setsize" data-x="1024" data-y="768">Med</button>');
      tb.append('<button data-func="setsize" data-x="640" data-y="400">Small</button>');
        
      tb.find("button[data-func='setsize']").click( function() {
        var x,y;
        x = parseInt($(this).data('x'));
        y = parseInt($(this).data('y'));
        that.game.gameSettings.setSize(x, y);
        that.game.gameSettings.saveLocal();
      });
    });
  }
};

module.exports = Toolbar;
