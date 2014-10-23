
'use strict';
function Menu() {}

/**
 * a basic menu controller
 * input via mouse
 */
Menu.prototype = {
  preload: function() {

  },
  create: function() {
    var style = { font: '16px Arial', fill: '#ffffff'},
      menu = [],
      i,
      x,
      y,
      menutext,
      that = this;

    //
    //  A function that will produce a level-choosing function
    //
    function levelSelector(level) {
      return function () {
        that.game.level = level;
        that.game.state.start('play');
      };
    }

    //
    // Add every level to the menu
    //
    for ( i = 0 ; i < this.game.levelData.length; i++) {
      menu.push({text: 'Level ' + i, action: levelSelector(i)});
    }

    // Other menu points
    menu.push({text: "Goto 'test'-state", action: function () { this.game.state.start('test');}});

    //
    // Render the menu
    //
    x = 100;
    y = 100;
    for(i in menu) {
      // set up menu item
      menutext = this.game.add.text(x, y, menu[i].text, style);
      menutext.anchor.setTo(0.5, 0.5);
      menutext.inputEnabled = true;
      menutext.events.onInputDown.add(menu[i].action, this);

      // layout
      y+= 25;
      if ( y > this.game.world.height - 100) {
        y = 100;
        x += 100;
      }
    }
  },

  update: function() {
    if (this.game.first_start == true) {
        this.game.first_start = false;
        this.game.state.start('test');
    }

    // if (this.game.input.keyboard.isDown(Phaser.Keyboard.ENTER)) {
    //   this.game.state.start('play');
    // }
  }

};

module.exports = Menu;
