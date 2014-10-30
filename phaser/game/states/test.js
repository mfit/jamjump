
'use strict';
var Tiled = require('../model/tiled.js');
var WorldBlocks = require('../model/world');
var frp = require('../frp/behavior.js');
var b = require('../frp/behavior2.js');

function TestState() {}

TestState.prototype = {
  preload: function () {
        this.game.map = this.game.tiled_loader.create(this.game.add);
        this.map = this.game.map;
        Tiled.LoadTiledAtlas(this.game, this.map);
  },
  create: function () {
        //var e = Tiled.MakeObjectLayerSprites(this.game, this.map, 'Object Layer 1');
        //console.log(e);
        this.moveEvent = new frp.EventStream();

        this.frpWorld = new b.World(this.game);
        this.game.world.width = 20000;
        this.game.world.height = 5000;

        this.frpPlayer = this.frpWorld.players[0];

        this.game.physics.startSystem(Phaser.Physics.ARCADE);
        var player = {}
        player.name = "Player";
        this.player = player;
        var playerSprite = this.frpPlayer.sprite;
        this.player.sprite = playerSprite;
        this.game.tiled_loader.runInterpreter(new Tiled.BaseInterpreter(this.frpWorld));

        var background3 = this.game.add.sprite (0, 0, 'background3');
        var background2 = this.game.add.sprite (0, this.game.height - 116 - 100, 'background2');
        var background1 = this.game.add.sprite (0, this.game.height - 70 - 100, 'background1');

        // All in group - draws in that order
        this.game.rootGroup = this.game.add.group();
        this.game.rootGroup.add(background3);
        this.game.rootGroup.add(background2);
        this.game.rootGroup.add(background1);
        this.game.rootGroup.add(this.frpWorld.worldBlocks.current_value.block_group);
        this.game.rootGroup.add(playerSprite);
        this.game.rootGroup.add(this.frpWorld.particles.group);


        // Set 1 color bg
        this.game.stage.backgroundColor = 0x91a477;
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

      if (this.game.input.keyboard.isDown(Phaser.Keyboard.S)) {
          this.frpPlayer.setBlockEvent.send(true);
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

      if (keyboard.isDown(Phaser.Keyboard.F)) {
          this.frpWorld.camera.shakeMe.send(true);
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
