
'use strict';
var TiledLoader = require('../model/tiled.js');
function TestState() {}

TestState.prototype = {
  preload: function () {
    this.tiled_loader = new TiledLoader('assets/levels/tiled_level.json', {'spritesheet':'assets/spritesheet.png'}, ['Tile Layer 1']);
    this.tiled_loader.load(this.game.load);

  },
  create: function () {
    var map = this.tiled_loader.create(this.game.add);

    console.log(map);
    this.game.cameras[0].bounds = null;
    this.game.cameras[1].bounds = null;
    // var layer = map.createLayer('Stones'); // This is the default name of the first layer in Tiled
    // layer.resizeWorld(); // Sets the world size to match the size of this layer.
  },
  update: function () {
      this.game.cameras[0].x -= 4;
      this.game.cameras[1].x += 4;

      //
      // Test for pause key
      //
      if (this.game.input.keyboard.isDown(Phaser.Keyboard.ESC)) {
          this.game.state.start("menu");
      }
  }
};
module.exports = TestState;
