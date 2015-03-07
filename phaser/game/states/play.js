  'use strict';
  var JumpPlayer = require('../model/player');
  var JumpController = require('../model/controller');
  var WorldBlocks = require('../model/world');
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
      this.game.input.onDown.add(this.doFullscreen, this);


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
          //onDown: function onDown(b, i, s) {
          //    console.log("down");
          //}
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
      this.game.level = 5;


      // LEVEL / BLOCKS --------------------------------------
      // TODO : move this to levelLoader component
      //
      // Load the level from the textfile
      //
      var theLevel = this.game.levelData[this.game.level].file.data;

      //console.log(this.game.level);
      //console.log(theLevel);

      var x = -1, y = 0;
      for (var ch in theLevel) {
        if (theLevel[ch] == "\n") {
          y++;
          x = -1;
        }

        if (theLevel[ch] === "1") {
          this.wb.addBlock(x, y);
        } else if (theLevel[ch] === "2") {
          this.wb.addBlock(x, y, 'stone');
        } else if (theLevel[ch] === "3") {
          this.wb.addBlock(x, y, 'death');
        } else if (theLevel[ch] === "x") {
          this.game.players[0].sprite.x = x*19;
          this.game.players[0].sprite.y = y*19;
        } else if (theLevel[ch] === "y") {
          this.game.players[1].sprite.x = x*19;
          this.game.players[1].sprite.y = y*19;
        } else if (theLevel[ch] === "9") {
          this.wb.addBlock(x, y, 'win');
        }

        x++;
      }

      // New jump mechanics nees a floor of blocks :
      //for (i=0; i<50; i++) {
      //  this.wb.addBlock(i, 30, 'stone');
      //}

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

              sprite.kill();

              //that.game.level = (that.game.level +1 ) % that.game.levelData.length;
              that.game.stateWinSuccess = false;
              that.game.state.start('status');


            }
            if (that.wb.blocktypes[group.model.t].win) {

              that.game.winMap[p.playerId] = true;

              if (that.game.winMap['1'] && that.game.winMap['2']) {
                that.game.level = (that.game.level +1 ) % that.game.levelData.length;
                that.game.stateWinSuccess = true;
                that.game.state.start('status');
              }

            }

            p.registerBlockTouch(group);
          });

        // Player updates
        p.update();
      });

      this.game.gui.update();
    },

    addBlock: function(player) {
      var sp, x, y,
          gridsize=19;

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
      y = Math.floor(sprite.body.y / gridsize + 1);

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


