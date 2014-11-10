'use strict';

global.PIXI = require('../phaser/dist/pixi.js');
global.Phaser = require('../phaser/dist/phaser-arcade-physics.js');

//global variables
window.onload = function () {
  var game = new Phaser.Game(1920, 600, Phaser.AUTO, 'jamjump');

  // Game States
  game.state.add('boot', require('./states/boot'));
  game.state.add('gameover', require('./states/gameover'));
  game.state.add('input', require('./states/input'));
  game.state.add('menu', require('./states/menu'));
  game.state.add('play', require('./states/play'));
  game.state.add('preload', require('./states/preload'));
  game.state.add('status', require('./states/status'));
  game.state.add('test', require('./states/test'));
  game.state.add('title', require('./states/title'));
  

  game.state.start('boot');
};
