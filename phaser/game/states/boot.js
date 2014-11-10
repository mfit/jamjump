'use strict';

var GameSettings = require('../settings/gamesettings.js');

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

    // Set settings object
    this.game.gameSettings = new GameSettings(this.game);
    this.game.gameSettings.loadLocal();
  },
};

module.exports = Boot;
