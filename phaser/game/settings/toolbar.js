'use strict';

function Toolbar(game) {
  this.game = game;
  this.showstate; // keep track of show / hide

  // Initial showstate - start with options expanded or hidden ?
  this.showstate = true;
}

Toolbar.prototype = {
  draw: function() {
    var that = this;
    // Draw a debug / settings toolbar using jquery
    $("document").ready(function() {
      var tb, showhide, focus;
      showhide = $('<button class="showsettings">...</button>');
      $("body").append(showhide);

      tb = $('<div class="toolbar">');
      $("body").append(tb);
      tb.append('<button data-func="setsize" data-x="1920" data-y="600">Large</button>');
      tb.append('<button data-func="setsize" data-x="800" data-y="600">Med</button>');
      tb.append('<button data-func="setsize" data-x="640" data-y="400">Small</button>');

      // set clickhandler for view/game size buttons
      tb.find("button[data-func='setsize']").click( function() {
        var x,y;
        x = parseInt($(this).data('x'));
        y = parseInt($(this).data('y'));
        that.game.gameSettings.setSize(x, y);
        that.game.gameSettings.saveLocal();
      });

      // Menu/options visibility button handler
      showhide.click( function() {
        if(that.showstate) {
          showSettings(false);
        } else {
          showSettings(true);
        }
      });

      showSettings(this.showstate);
    });

    // Function to togle menu/options visibility
    function showSettings(state) {
      if (state) {
        $("div.toolbar").show();
        $("div.options").show();
        $("div.render_options").show();
      } else {
        $("div.toolbar").hide();
        $("div.options").hide();
        $("div.render_options").hide();
      }
      that.showstate = state;
    }
  }
};

module.exports = Toolbar;
