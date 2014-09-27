
'use strict';
var GameSetup = require('../model/setup');
function Preload() {
  this.asset = null;
  this.ready = false;
}

Preload.prototype = {
  preload: function() {
    this.asset = this.add.sprite(this.width/2,this.height/2, 'preloader');
    this.asset.anchor.setTo(0.5, 0.5);

    this.load.onLoadComplete.addOnce(this.onLoadComplete, this);
    this.load.setPreloadSprite(this.asset);


    this.load.spritesheet('allblocks', 'assets/spritesheet_alpha.png',
        19,  // width
        19,  // height
        -1, // max sprites
        4,  // margin
        4  // spacing
        );

    // Create a game setup object
    this.game.gameSetup = new GameSetup();

  },
  create: function() {

    this.asset.cropEnabled = false;
  },
  update: function() {
    if(!!this.ready) {
      // this.game.state.start('menu');
      this.game.state.start('play');
    }
  },
  onLoadComplete: function() {
    this.ready = true;
  }
};

module.exports = Preload;
