'use strict';

function GameSettings(game) {
  this.game = game;
  this.settings = {};
  this.behaviors = {};
}

GameSettings.prototype = {
  setSize: function(x, y) {
    this.game.width = x;
    this.game.height = y;
    this.game.renderer.resize(x, y);
    this.game.camera.view.width = x;
    this.game.camera.view.height = y;
  },
  saveLocal: function() {
    this.settings.width = game.width;
    this.settings.height = game.height;
    sessionStorage.setItem('gamewidth', this.settings.width);
    sessionStorage.setItem('gameheight', this.settings.height);
    for (var behName in this.behaviors) {
      sessionStorage.setItem(behName, this.behaviors[behName].value());
    }
  },
  loadLocal: function() {
    var x,y;
    x = parseInt(sessionStorage.getItem('gamewidth'));
    y = parseInt(sessionStorage.getItem('gameheight'));
    if (x && y) {
      this.settings.width = x;
      this.settings.height = y;
      this.setSize(x, y);
    }
    for (var behName in this.behaviors) {
        if (sessionStorage.getItem(behName) != null)
            this.behaviors[behName].update(parseInt(sessionStorage.getItem(behName))); 
    }
  },
};

module.exports = GameSettings;
