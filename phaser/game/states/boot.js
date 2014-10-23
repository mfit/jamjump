
'use strict';

function Boot() {
}

Boot.prototype = {
  preload: function() {
    this.load.image('preloader', 'assets/preloader.gif');
    this.game.scale.fullScreenScaleMode = Phaser.ScaleManager.SHOW_ALL;
  },
  create: function() {
    this.game.input.maxPointers = 1;
    this.game.first_start = true;
    this.game.scale.startFullScreen(true);
    this.game.state.start('preload');
      
  }
};

module.exports = Boot;
