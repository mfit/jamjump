
'use strict';
var Tiled = require('../model/tiled.js');
var WorldBlocks = require('../model/world');
var frp = require('../frp/frp.js');
var player = require('../frp/player_behaviors.js');
var b = require('../frp/world_behaviors.js');

var tick = frp.tick

function TestState() {}

TestState.prototype = {
  preload: function () {
        this.game.map = this.game.tiled_loader.create(this.game.add);
        this.map = this.game.map;
        Tiled.LoadTiledAtlas(this.game, this.map);
        this.game.time.advancedTiming = true
  },
  create: function () {
        //var e = Tiled.MakeObjectLayerSprites(this.game, this.map, 'Object Layer 1');
        //console.log(e);
        this.moveEvent = new frp.EventStream();
        this.game.world.scale.set (1, 1)
        this.game.scale.fullScreenScaleMode = Phaser.ScaleManager.NO_SCALE;
        this.game.scale.startFullScreen(false);
        // this.game.input.onDown.add(function () {
        //     if (this.game.scale.isFullScreen)
        //         this.game.scale.stopFullScreen();
        //     else
        //         this.game.scale.startFullScreen(false);
        //     }, this);

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
        this.game.rootGroup.add(this.frpWorld.trees);
        console.log ("World", this.frpWorld.worldBlocks.value())
        this.game.rootGroup.add(this.frpWorld.worldBlocks.value().coll_group);
        this.game.rootGroup.add(this.frpWorld.worldBlocks.value().block_group);
        for (var i = 0; i < this.frpWorld.players.length; i++) {
            this.game.rootGroup.add(this.frpWorld.players[i].sprite);
            this.game.rootGroup.add(this.frpWorld.players[i].dbg);
        }
        this.game.rootGroup.add(this.frpWorld.particles.group);
        for (var i = 0; i < this.frpWorld.players.length; i++) {
            this.game.rootGroup.add(this.frpWorld.players[i].pushBox.sprite);
        }


        // Set 1 color bg
        this.game.stage.backgroundColor = 0x91a477;
        this.moving = 0;
        this.jumpDown = false;
        this.blockSetDown = false;
        this.qDown = false;
        this.eDown = false;
        this.currentPlayer = 0;
        this.jDown = false;
      
      
        var keyboard = this.game.input.keyboard;
        var x = keyboard.addKey(Phaser.Keyboard.X)
        var y = keyboard.addKey(Phaser.Keyboard.Y)
        x.onDown.add (function () {         
            var that = this;
            this.playerEvents.push (function () {
                that.frpWorld.makeFaster.send(true)
            })}, this);
        y.onDown.add (function () {         
            var that = this;
            this.playerEvents.push (function () {
                that.frpWorld.makeSlower.send(true)
            })}, this);
     
      this.playerEvents = [];
  },
  getId: function() {
      return -1;
  },
  render: function () {
      this.game.debug.text(this.game.time.fps || '--', 2, 14, "#00ff00");
      this.game.debug.text(this.frpWorld.mod.value(), 2, 28, "#00ff00");
  },
  update: function () {
      var start = new Date().getTime();
      //this.wb.update();
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
          if (this.moving !== 0) {
            playerEvents.push (function() {
                console.log ("Send stop move")
                that.frpPlayer.moveEvent.send(new b.StopMoveEvent());
                });
          }
          playerEvents.push (function() {
              that.frpPlayer.moveEvent.send(new b.MoveEvent(-1, 0));
              });

              this.moving = -1;
      }
      if (this.moving !== 1 && !keyboard.isDown(Phaser.Keyboard.A) && keyboard.isDown(Phaser.Keyboard.D)) {
          if (this.moving !== 0) {
            playerEvents.push (function() {
                console.log ("Send stop move")
                that.frpPlayer.moveEvent.send(new b.StopMoveEvent());
                });
          }
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
              that.frpWorld.camera.shakeMe.send (true)
              });
      }

      if (keyboard.isDown(Phaser.Keyboard.G)) {
          playerEvents.push (function() {
              that.frpPlayer.pushBox.startPush.send (true)
              });
      }

      // update stuff
      var that = this;
      frp.sync(function() {b.preTick.send(that.game.time.elapsed)});
      // update tick
      for (var index in playerEvents) {
          frp.sync(playerEvents[index]);
      }
      for (var index in this.playerEvents) {
          frp.sync(this.playerEvents[index]);
      }
      playerEvents = []
      this.playerEvents = []

      frp.sync(function() {b.tick.send(that.game.time.elapsed)});

      frp.sync(function() {b.postTick.send(that.game.time.elapsed)});

      //
      // Test for pause key
      //
      if (this.game.input.keyboard.isDown(Phaser.Keyboard.ESC)) {
          this.game.state.start("menu");
      }
      var end = new Date().getTime();
      if (end - start > 10)
        console.warn ("dt", end - start);
  }
};

module.exports = TestState;
