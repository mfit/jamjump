
'use strict';
var Tiled = require('../model/tiled.js');
var WorldBlocks = require('../model/world');
var frp = require('../frp/behavior.js');
var b = require('../frp/behavior2.js')

function TestState() {}

TestState.prototype = {
  preload: function () {
    this.tiled_loader = new Tiled.TiledLoader('assets/levels/tiled_level.json', {'spritesheet':'assets/spritesheet.png'}, 
                                         ['Tile Layer 1']);
    this.tiled_loader.load(this.game.load);
  },
  create: function () {
        this.moveEvent = new frp.EventStream();
      
        this.frpWorld = new b.World(this.game);
        this.frpPlayer = this.frpWorld.players[0];

        this.game.physics.startSystem(Phaser.Physics.ARCADE);
        var player = {}
        player.name = "Player";
        this.player = player;
        var playerSprite = this.frpPlayer.sprite;
        this.player.sprite = playerSprite;

        //this.wb = new WorldBlocks(this.game);
        // var that = this;
        // this.frpPlayer.blockSetter.blockSet.listen(function (ignore) { 
        //     var gridsize = 19;
        //     var x = Math.floor(that.player.sprite.body.x / gridsize);
        //     var y = Math.floor(that.player.sprite.body.y / gridsize + 1);
        //     if (that.wb.canAddBlock(x, y)) {
        //         that.wb.addBlock(x, y);
        //     }
        // });
      
        this.map = this.tiled_loader.create(this.game.add);
        //this.tiled_loader.runInterpreter(new Tiled.BaseInterpreter(this.wb));

        //var temp_sprite = this.game.add.sprite(0,0, 'background2');

        // All in group - draws in that order
        this.game.rootGroup = this.game.add.group();
        //this.game.rootGroup.add(temp_sprite);
        //this.game.rootGroup.add(this.wb.block_group);
        this.game.rootGroup.add(playerSprite);


        // Set 1 color bg
        this.game.stage.backgroundColor = 0x333333;
        this.moving = false;
        this.jumpDown = false;
        this.blockSetDown = false;
        this.qDown = false;
        this.eDown = false;
  },
  getId: function() {
      return -1;
  },
  update: function () {
      //this.wb.update();
      var that = this;
      
      // this.game.physics.arcade.collide(
      //     this.wb.block_group,
      //     this.player.sprite,
      //     function (sprite, group_sprite) {
      //         that.frpPlayer.landedOnBlock.send(true);
      //     }
      // );
      this.frpPlayer.setPosition(new b.Direction (this.player.sprite.body.x, this.player.sprite.body.y));
      
      var keyboard = this.game.input.keyboard;
      
      if (keyboard.isDown(Phaser.Keyboard.P)) {
          console.log("Player", this.frpPlayer);
      }

      if (!this.jumpDown && this.game.input.keyboard.isDown(Phaser.Keyboard.W)) {
          this.frpPlayer.jumpEvent.send(true);
          this.jumpDown = true;
      } else if (this.jumpDown && !keyboard.isDown(Phaser.Keyboard.W)) {
          this.jumpDown = false;
      }

      if (this.blockSetDown === false && this.game.input.keyboard.isDown(Phaser.Keyboard.S)) {
          this.frpPlayer.setBlockEvent.send(true);
          this.blockSetDown = true;
      } else if (this.blockSetDown === true && !keyboard.isDown(Phaser.Keyboard.S)) {
          this.blockSetDown = false;
      }
      
      if (this.moving === false && keyboard.isDown(Phaser.Keyboard.A) && !keyboard.isDown(Phaser.Keyboard.D)) {
          this.frpPlayer.moveEvent.send(new b.MoveEvent(-1, 0));
          this.moving = true;
      } 
      if (this.moving === false && !keyboard.isDown(Phaser.Keyboard.A) && keyboard.isDown(Phaser.Keyboard.D)) {
          this.frpPlayer.moveEvent.send(new b.MoveEvent(1, 0));
          this.moving = true;
      } 

      if (!keyboard.isDown(Phaser.Keyboard.A) && !keyboard.isDown(Phaser.Keyboard.D)) {
          this.moving = false;
          this.frpPlayer.moveEvent.send(new b.StopMoveEvent());
      }
      
      if (this.qDown === false && keyboard.isDown(Phaser.Keyboard.Q)) {
          this.frpPlayer.setMovementSystem.send('BaseMovement')
          this.qDown = true;
      } else if (this.qDown === true && !keyboard.isDown(Phaser.Keyboard.Q)) {
          this.qDown = false;
      }
      
      if (this.eDown === false && keyboard.isDown(Phaser.Keyboard.E)) {
          this.frpPlayer.setMovementSystem.send('OtherMovement')
          this.eDown = true;
      } else if (this.qDown === true && !keyboard.isDown(Phaser.Keyboard.E)) {
          this.eDown = false;
      }

      // update stuff
      b.preTick.send(this.game.time.elapsed);
      frp.system.sync();
      b.tick.send(this.game.time.elapsed);
      // update tick
      frp.system.sync();
      
      //
      // Test for pause key
      //
      if (this.game.input.keyboard.isDown(Phaser.Keyboard.ESC)) {
          this.game.state.start("menu");
      }
  }
};

module.exports = TestState;
