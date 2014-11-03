'use strict';

//global variables
window.onload = function () {
  var game = new Phaser.Game(1024, 768, Phaser.AUTO, 'jamjump');

  // Game States
  game.state.add('boot', require('./states/boot'));
  game.state.add('gameover', require('./states/gameover'));
  game.state.add('menu', require('./states/menu'));
  game.state.add('play', require('./states/play'));
  game.state.add('preload', require('./states/preload'));
  game.state.add('status', require('./states/status'));
  game.state.add('test', require('./states/test'));
  game.state.add('title', require('./states/title'));
  

  game.state.start('boot');
};