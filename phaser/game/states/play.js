  'use strict';
  var JumpPlayer = require('../model/player');
  var JumpController = require('../model/controller');
  var WorldBlocks = require('../model/world');
  var LevelBuilder = require('../model/levelbuilder.js');

  function Play() {}
  Play.prototype = {
    doFullscreen: function() {
      // Full screen helper
      if (this.game.scale.isFullScreen) {
        this.game.scale.stopFullScreen();
      } else {
        this.game.scale.startFullScreen(false);
      }
    },


    create: function() {
      var i, sp, ctrl,
        that = this,
        cursors,
        gamepad,
        temp_sprite,
        temp_player,
        controller_map;
      var music;
	     this.blocksound = this.game.add.audio('blocksound');

       // this.winmode = 'COOP';
       this.winmode = 'COMP';
       this.game.statePayerWin = -1;

       // Start background music. If is kept somewhere, will not play multiple times
      if (this.game.gameSetup.backgroundMusic) {

        // set background music song:
        //this.game.gameSetup.backgroundMusic = this.game.add.audio('track1');

        if (this.game.gameSetup.playMusic) {
          this.game.gameSetup.backgroundMusic.play('',0,1,true);
        } else {
          this.game.gameSetup.backgroundMusic.stop('',0,1,true);
        }
      }

      // Set fullscreen mode (modes are EXACT_FIT, SHOW_ALL, NO_SCALE
      this.game.scale.fullScreenScaleMode = Phaser.ScaleManager.SHOW_ALL;

      // fullscreen on click
      // this.game.input.onDown.add(this.doFullscreen, this);

      // fullscreen on key
      var key0 = this.game.input.keyboard.addKey(Phaser.Keyboard.ZERO);
      key0.onDown.add(this.doFullscreen, this);

      // next level on key
      var key9 = this.game.input.keyboard.addKey(Phaser.Keyboard.NINE);
      key9.onDown.add(function() {
        this.skipToLevel();
      } , this);

      // switch settertype
      var key8 = this.game.input.keyboard.addKey(Phaser.Keyboard.EIGHT);
      key8.onDown.add(function() {
        this.settertype = this.settertype + 1 % Object.keys(this.wb.blocktypes).length;

        // save level
        this.lbuilder.saveLevel();

      } , this);

      // Mclick
      this.game.input.onDown.add(this.mouseAction, this);

      // Blocktype index we're setting on mouseclick
      this.settertype = 0;


      // this.game.load.tilemap('platformer', 'assets/platformer.json', null, Phaser.Tilemap.TILED_JSON);
      // this.game.load.image('spritesheet', 'assets/spritesheet.png');

      // var map = this.game.add.tilemap('platformer');
      // map.addTilesetImage('spritesheet', 'spritesheet');
      // var layer = map.createLayer('World1');
      // layer.resizeWorld();

      // Enable physics for game
      this.game.physics.startSystem(Phaser.Physics.ARCADE);

      if (typeof this.game.gameSetup === 'undefined') {
        throw "Error : please make sure a game setup is initialised";
      }

      //
      // Set up available controllers
      //
      cursors = this.game.input.keyboard.createCursorKeys();
      gamepad = this.game.input.gamepad;
      gamepad.start();
      gamepad.addCallbacks(this, {
          onConnect: function onConnect(i) {
              console.log("connect");
          },
        });

      // Map to init controllers
      // The constructor of the controller w
      controller_map = {
          'keyb': new JumpController('keyb', this.game.input.keyboard,
              {left:Phaser.Keyboard.A, right: Phaser.Keyboard.D, jump: Phaser.Keyboard.W, block: Phaser.Keyboard.S}
              ),
          'keyb2': new JumpController('keyb', this.game.input.keyboard,
              {left:Phaser.Keyboard.LEFT, right: Phaser.Keyboard.RIGHT, jump: Phaser.Keyboard.UP, block: Phaser.Keyboard.DOWN}
              ),
          'keyb3': new JumpController('keyb', this.game.input.keyboard,
              {left:Phaser.Keyboard.LEFT, right: Phaser.Keyboard.RIGHT, jump: Phaser.Keyboard.SPACE, block: Phaser.Keyboard.UP}
              ),

          'gamepad': new JumpController('gamepad', gamepad.pad1, {type:0}),
          'gamepad2': new JumpController('gamepad', gamepad.pad2, {}),
      };

      // A struct to collect players touching the winstone
      this.game.winMap = {};

      //
      // Set up the players according to gameSetup
      //
      this.game.players = [];
      this.game.myPlayerGroup = this.game.add.group();
      this.game.gameSetup.players.forEach(function(o){
        temp_sprite = that.game.add.sprite(
          Math.random() * that.game.width,
          Math.random() * (that.game.height / 2),
          'runner');

        temp_sprite.animations.add('run', [0,1,2,3,4,5,6,7,8]);
        temp_sprite.animations.add('jump', [9,10,11]);

        temp_player = new JumpPlayer(
          that,
          temp_sprite,
          o.id,
          controller_map[o.controller]
          );
          temp_player.init();
          temp_player.chooseSkin(o.skin);
          that.game.players.push(temp_player);

          // Add sprite to group of players
          that.game.myPlayerGroup.add(temp_sprite);
      });


      //
      // Set up the world / blocks
      //
      this.wb = new WorldBlocks(this.game);


      //
      // Always play level 5
      //
      this.game.level = 6;


      // LEVEL / BLOCKS --------------------------------------
      // TODO : move this to levelLoader component
      //
      // Load the level from the textfile
      //
      var theLevel = this.game.levelData[this.game.level].file.data;

      this.lbuilder = new LevelBuilder(this.game, this.wb, window.localStorage);
      this.lbuilder.loadDefaultLevel(theLevel);

      // ------------------------------------------------------

      // Background
      temp_sprite = this.game.add.sprite(0,0, 'background2');

      // All in group - draws in that order
      this.game.rootGroup = this.game.add.group();
      this.game.rootGroup.add(temp_sprite);
      this.game.rootGroup.add(this.wb.block_group);
      this.game.rootGroup.add(that.game.myPlayerGroup);


      // Set 1 color bg
      this.game.stage.backgroundColor = 0x333333;


    },
    mouseAction: function(ev) {
      var coords = this.wb.fromWorldCoords(ev.x, ev.y);

      console.log("Mouseclick at " + coords);
      console.log(this.wb.hash(coords.x, coords[1]));

      if(this.wb.blocks[this.wb.hash(coords.x, coords[1])]) {
        this.wb.pendingRemoves.push({key:this.wb.blocks[this.wb.hash(coords.x, coords[1])]});
      } else {
        this.wb.addBlock(coords.x, coords.y - 1, Object.keys(this.wb.blocktypes)[this.settertype]);
      }
    },
    skipToLevel: function(n) {
      if (typeof n === "undefined") {
        this.game.level = (this.game.level +1 ) % this.game.levelData.length;
        this.game.state.start('play');
      } else {
        this.game.level = n;
        this.game.state.start('play');
      }
    },
    update: function() {
      var that = this;

      // Update world-blocks
      this.wb.update();

      if (this.game.input.keyboard.isDown(Phaser.Keyboard.ENTER))
      {
          this.game.state.start("play");
      }

      // Update all players
      this.game.players.forEach(function(p) {

        // that.game.debug.body(p.sprite);

        // Physics - check collide
        that.game.physics.arcade.collide(
          that.wb.block_group,
          p.sprite,
          function (sprite, group) {

            if (that.wb.blocktypes[group.model.t].kills) {
              // killed ..
              if ( false ) {
                // with killscreen
                sprite.kill();
                that.game.stateWinSuccess = false;
                that.game.state.start('status');
              } else {
                // just re-spawn
                var pos = p.getSpawnPosition();
                sprite.x = pos[0];
                sprite.y = pos[1];

                // and subtract score
                that.game.score[p.playerId-1] -= 1;
              }
            }

            if (that.wb.blocktypes[group.model.t].win) {

              if (that.winmode == 'COOP') {

                that.game.winMap[p.playerId] = true;

                // Co-op win : both players have touched the win stone
                if (that.game.winMap['1'] && that.game.winMap['2']) {
                  that.game.level = (that.game.level +1 ) % that.game.levelData.length;
                  that.game.stateWinSuccess = true;
                  that.game.state.start('status');
                }
              } else {
                // single player VS-win
                if (p.playerId == that.wb.blocktypes[group.model.t].player) {
                  that.game.stateWinSuccess = true;
                  that.game.state.start('status');
                  that.game.statePlayerWin = p.playerId;
                  that.game.score[p.playerId - 1] += 1;
                }
              }

            }

            p.registerBlockTouch(group);
            that.wb.registerBlockTouch(group);
          });

        // Player updates
        p.update();
      });

      this.game.gui.update();
    },

    addBlock: function(player) {
      var sp, x, y,
          gridsize=this.wb.gridsize;

      var sprite = this.game.players[0].sprite;
      var otherSprite = this.game.players[1].sprite;


      if (player == 1) {
          sprite = this.game.players[0].sprite;
          otherSprite = this.game.players[1].sprite;
      } else if (player == 2) {
          sprite = this.game.players[1].sprite;
          otherSprite = this.game.players[0].sprite;
      }

      x = Math.floor(sprite.body.x / gridsize);
      y = Math.floor((sprite.body.y + (sprite.body.velocity.y / 30)) / gridsize + 1);

      if(this.wb.canAddBlock(x,y)) {
	     this.blocksound.play();
        this.wb.addBlock(x, y);
        // this.wb.removeClosestTo(otherSprite.body.x, otherSprite.body.y);
        this.wb.removeBlock(sprite, otherSprite);
        sprite.lastBlockSet = this.game.time.now;
      }

    },
    render: function() {
        //this.game.debug.quadTree(game.physics.arcade.quadTree);
    }
};

  module.exports = Play;


