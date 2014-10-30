
'use strict';
var GameSetup = require('../model/setup');
var GUI = require('../model/gui');
var Tiled = require('../model/tiled');
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
    this.load.audio('bla', 'assets/sound/pingsong.ogg');
    this.load.audio('jumpsound','assets/sound/plop.ogg');
    this.load.audio('blocksound', 'assets/sound/plopplop2.ogg');

    this.load.spritesheet('allblocks', 'assets/spritesheet_alpha.png',
        19,  // width
        19,  // height
        -1, // max sprites
        4,  // margin
        4  // spacing
        );

    this.load.text('level0', 'assets/levels/level0.txt');
    this.load.text('level1', 'assets/levels/level1.txt');
    this.load.text('level2', 'assets/levels/level2.txt');
    this.load.text('level3', 'assets/levels/level3.txt');
    this.load.text('level4', 'assets/levels/level4.txt');
    this.game.level = 0;

    this.game.levelData = [];
    this.game.levelData[0] = this.load.getAsset('text', 'level0');
    this.game.levelData[1] = this.load.getAsset('text', 'level1');
    this.game.levelData[2] = this.load.getAsset('text', 'level2');
    this.game.levelData[3] = this.load.getAsset('text', 'level3');
    this.game.levelData[4] = this.load.getAsset('text', 'level4');

    this.load.spritesheet('runner', 'assets/m1.png', 14, 28, -1, 0, 0);
    this.load.spritesheet('runner2', 'assets/m2.png', 14, 28, -1, 0, 0);
    this.load.image('titlecharacter', 'assets/komischgucker_alpha.png');

    this.load.image('redboxblock', 'assets/Block1.png');
    this.load.image('stoneblock', 'assets/BlockStoneSmall19.png');
    this.load.image('winblock', 'assets/BlockDanger.png');
    this.load.image('deathblock', 'assets/lavastein1.png');

    this.load.image('background1', 'assets/bg1_lo.png');
    this.load.image('background2', 'assets/bg2_lo.png');
    this.load.image('background3', 'assets/bg3_lo.png');

    // Create a game setup object
    this.game.gameSetup = new GameSetup();

    this.game.gameSetup.backgroundMusic = this.game.add.audio('bla');

    var font = this.game.load.bitmapFont('nokia',
            'assets/fonts/nokia.png',
            'assets/fonts/nokia.xml');

    // text
    this.game.gui = new GUI(this.game, font);


    //
    // Test tiled maps:
    //
    this.load.image('tileset', 'assets/blocks_tiles.png'); // loading the tileset image
    this.load.tilemap('map', 'assets/test.json', null, Phaser.Tilemap.TILED_JSON); // loading the tilemap
    this.game.tiled_loader = new Tiled.TiledLoader('assets/levels/tiled_level.json', {'tileset':'assets/tileset.png'}, 
                                         ['BlockLayer']);
    this.game.tiled_loader.load(this.game.load);

  },
  create: function() {
    this.asset.cropEnabled = false;
  },
  update: function() {
    if(!!this.ready) {
      this.game.state.start('menu');
    }
  },
  onLoadComplete: function() {
    this.ready = true;
  }
};

module.exports = Preload;
