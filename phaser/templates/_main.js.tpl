'use strict';

global.PIXI = require('../phaser/dist/pixi.js');
global.Phaser = require('../phaser/dist/phaser-arcade-physics.js');

//global variables
window.onload = function () {
  var game = new Phaser.Game(<%= gameWidth %>, <%= gameHeight %>, Phaser.AUTO, '<%= _.slugify(projectName) %>');

  // Game States
  <% _.forEach(gameStates, function(gameState) {  %>game.state.add('<%= gameState.shortName %>', require('./states/<%= gameState.shortName %>'));
  <% }); %>

  game.state.start('boot');
};
