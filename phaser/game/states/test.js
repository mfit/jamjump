
'use strict';
var Tiled = require('../model/tiled.js');
var WorldBlocks = require('../model/world');
var frp = require('../frp/frp.js');
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

        var that = this;
        this.frpWorld = frp.sync(function () {return new b.World(that.game); });
        this.game.world.width = 20000;
        this.game.world.height = 5000;

        this.frpPlayer = this.frpWorld.players[0];

        this.game.physics.startSystem(Phaser.Physics.ARCADE);
        frp.sync(function () {that.game.tiled_loader.runInterpreter(new Tiled.BaseInterpreter(that.frpWorld));});

        var background3 = this.game.add.sprite (0, 0, 'background3');
        var background2 = this.game.add.sprite (0, this.game.height - 116 - 100, 'background2');
        var background1 = this.game.add.sprite (0, this.game.height - 70 - 100, 'background1');

        // All in group - draws in that order
        this.game.rootGroup = this.game.add.group();
        this.game.rootGroup.add(background3);
        this.game.rootGroup.add(background2);
        this.game.rootGroup.add(background1);
        console.log ("World", this.frpWorld.worldBlocks.value())
        this.game.rootGroup.add(this.frpWorld.worldBlocks.value().block_group);
        for (var i = 0; i < this.frpWorld.players.length; i++) {
            this.game.rootGroup.add(this.frpWorld.players[i].sprite);
        }
        this.game.rootGroup.add(this.frpWorld.particles.group);
        this.game.rootGroup.add(this.frpWorld.trees);


        // Set 1 color bg
        this.game.stage.backgroundColor = 0x91a477;
        this.moving = 0;
        this.jumpDown = false;
        this.blockSetDown = false;
        this.qDown = false;
        this.eDown = false;
        this.currentPlayer = 0;
        this.jDown = false;
  },
  getId: function() {
      return -1;
  },
  render: function () {
  },
  update: function () {
      //this.wb.update();
      console.log ("TICK")
      var that = this;

      var keyboard = this.game.input.keyboard;
      
      var playerEvents = []

      if (this.jDown === false && keyboard.isDown(Phaser.Keyboard.J)) {
          this.jDown = true;
          this.currentPlayer += 1;
          this.frpPlayer = this.frpWorld.players[this.currentPlayer % this.frpWorld.players.length];
      }
      if (this.jDown === true && !keyboard.isDown(Phaser.Keyboard.J)) {
          this.jDown = false;
      }
     
      for (var i = 0; i < this.frpWorld.players.length; i++) {
            var x = function (i) { 
                playerEvents.push (function() {
                    that.frpWorld.players[i].setPosition(new b.Direction (
                    that.frpWorld.players[i].sprite.body.x, that.frpWorld.players[i].sprite.body.y));
            }); }
            x(i);
      }


      if (keyboard.isDown(Phaser.Keyboard.P)) {
          console.log("Player", this.frpPlayer);
      }

      if (!this.jumpDown && this.game.input.keyboard.isDown(Phaser.Keyboard.W)) {
          playerEvents.push (function() {
              that.frpPlayer.jumpEvent.send(true);
              });
          this.jumpDown = true;
      } else if (this.jumpDown && !keyboard.isDown(Phaser.Keyboard.W)) {
          this.jumpDown = false;
      }

      if (this.game.input.keyboard.isDown(Phaser.Keyboard.S)) {
          playerEvents.push (function() {
              that.frpPlayer.setBlockEvent.send(true);
              });
      }

      if (this.moving !== -1 && keyboard.isDown(Phaser.Keyboard.A) && !keyboard.isDown(Phaser.Keyboard.D)) {
          playerEvents.push (function() {
              that.frpPlayer.moveEvent.send(new b.MoveEvent(-1, 0));
              });
              this.moving = -1;
      }
      if (this.moving !== 1 && !keyboard.isDown(Phaser.Keyboard.A) && keyboard.isDown(Phaser.Keyboard.D)) {
          playerEvents.push (function() {
            that.frpPlayer.moveEvent.send(new b.MoveEvent(1, 0));
            });
          this.moving = 1;
      }

      if (this.moving !== 0 && !(keyboard.isDown(Phaser.Keyboard.A) || keyboard.isDown(Phaser.Keyboard.D))) {
          this.moving = 0;
          playerEvents.push (function() {
              console.log ("Send stop move")
              that.frpPlayer.moveEvent.send(new b.StopMoveEvent());
              });
      }

      if (this.qDown === false && keyboard.isDown(Phaser.Keyboard.Q)) {
          playerEvents.push (function() {
              that.frpPlayer.setMovementSystem.send('BaseMovement')
              });
          this.qDown = true;
      } else if (this.qDown === true && !keyboard.isDown(Phaser.Keyboard.Q)) {
          this.qDown = false;
      }

      if (this.eDown === false && keyboard.isDown(Phaser.Keyboard.E)) {
          playerEvents.push (function() {
              that.frpPlayer.setMovementSystem.send('OtherMovement')
              });
          this.eDown = true;
      } else if (this.qDown === true && !keyboard.isDown(Phaser.Keyboard.E)) {
          this.eDown = false;
      }

      if (keyboard.isDown(Phaser.Keyboard.F)) {
          playerEvents.push (function() {
              that.frpWorld.camera.shakeMe.send(true);
              });
      }

      // update stuff
      var that = this;
      frp.sync(function() {b.preTick.send(that.game.time.elapsed)});
      // update tick
      for (var index in playerEvents) {
          frp.sync(playerEvents[index]);
      }
      playerEvents = []

      frp.sync(function() {b.tick.send(that.game.time.elapsed)});

      //
      // Test for pause key
      //
      if (this.game.input.keyboard.isDown(Phaser.Keyboard.ESC)) {
          this.game.state.start("menu");
      }
  }
};

module.exports = TestState;
