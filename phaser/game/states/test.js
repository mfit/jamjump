
'use strict';
var Tiled = require('../model/tiled.js');
var WorldBlocks = require('../model/world');
var frp = require('../frp/frp.js');
var player = require('../frp/player_behaviors.js');
var b = require('../frp/world_behaviors.js');
var input = require('../model/input.js');

var toPhaser = require ('../frp/toPhaser.js');

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
        frp.sync(function() {toPhaser.setup(that.game, that.frpWorld);});
      
        this.input = new input.Input(this.game);
        
        this.game.world.width = 20000;
        this.game.world.height = 5000;

        this.frpPlayer = this.frpWorld.players[0];
        this.otherFrpPlayer = this.frpWorld.players[1];

        this.keyboardInputP1 = new input.KeyboardInput({
            moveLeftDown:this.input.keyDownEvent['A'],
            moveLeftUp:this.input.keyUpEvent['A'],
            moveRightDown:this.input.keyDownEvent['D'],
            moveRightUp:this.input.keyUpEvent['D'],
            jumpDown:this.input.keyDownEvent['W'],
            jumpUp:this.input.keyUpEvent['W'],
            }, {
            move: this.frpPlayer.moveEvent,
            jump: this.frpPlayer.jumpEvent,
            });

         this.keyboardInputP2 = new input.KeyboardInput({
            moveLeftDown:this.input.keyDownEvent['H'],
            moveLeftUp:this.input.keyUpEvent['H'],
            moveRightDown:this.input.keyDownEvent['L'],
            moveRightUp:this.input.keyUpEvent['L'],
            jumpDown:this.input.keyDownEvent['K'],
            jumpUp:this.input.keyUpEvent['K'],
            }, {
            move: this.otherFrpPlayer.moveEvent,
            jump: this.otherFrpPlayer.jumpEvent,
            });
      
        frp.sync(function() {that.keyboardInputP1.mkBehaviors();});
        frp.sync(function() {that.keyboardInputP2.mkBehaviors();});


        this.game.physics.startSystem(Phaser.Physics.ARCADE);
        frp.sync(function () {that.game.tiled_loader.runInterpreter(new Tiled.BaseInterpreter(that.frpWorld));});

        // All in group - draws in that order
        this.game.rootGroup = this.game.add.group();
        // this.game.rootGroup.add(background3);
        // this.game.rootGroup.add(background2);
        // this.game.rootGroup.add(background1);
        this.game.rootGroup.add(this.frpWorld.trees);
        //this.game.rootGroup.add(this.frpWorld.worldBlocks.value().coll_group);
        this.game.rootGroup.add(this.frpWorld.worldBlocks.value().block_group);
        for (var i = 0; i < this.frpWorld.players.length; i++) {
            this.game.rootGroup.add(this.frpWorld.players[i].sprite);
        }
        this.game.rootGroup.add(this.frpWorld.particles.group);
        for (var i = 0; i < this.frpWorld.players.length; i++) {
            this.game.rootGroup.add(this.frpWorld.players[i].pushBox.sprite);
        }


        // Set 1 color bg
      
        this.r = 250;
        this.g = 250;
        this.b = 250;
      
        this.game.stage.backgroundColor = 0;
        this.moving = 0;
        this.moving2 = 0;

        this.jumpDown = false;
        this.jumpDown2 = false;

        this.blockSetDown = false;
        this.qDown = false;
        this.eDown = false;
        this.currentPlayer = 0;
        this.otherCurrentPlayer = 1;
        this.jDown = false;
      
      
        var keyboard = this.game.input.keyboard;
        var k1 = keyboard.addKey(Phaser.Keyboard.ONE)
        var k3 = keyboard.addKey(Phaser.Keyboard.TWO)
        var k5 = keyboard.addKey(Phaser.Keyboard.THREE)
        var k2 = keyboard.addKey(Phaser.Keyboard.FOUR)
        var k4 = keyboard.addKey(Phaser.Keyboard.FIVE)
        var k6 = keyboard.addKey(Phaser.Keyboard.SIX)
        var step = 5;
        k1.onDown.add (function() {
            this.r += step;
        }, this);
        k2.onDown.add (function() {
            this.r -= step;
        }, this);
        k3.onDown.add (function() {
            this.g += step;
        }, this);
        k4.onDown.add (function() {
            this.g -= step;
        }, this);
        k5.onDown.add (function() {
            this.b += step;
        }, this);
        k6.onDown.add (function() {
            this.b -= step;
        }, this);

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
      // this.game.debug.text(this.game.time.fps || '--', 2, 14, "#00ff00");
      // this.game.debug.text(this.frpWorld.mod.value(), 2, 28, "#00ff00");
      // this.game.debug.text(this.r.toString() + "/" + this.g.toString() + "/" + this.b.toString(), 2, 42, "#00ff00");
  },
  update: function () {
        this.game.stage.backgroundColor = 
            Math.floor(this.r / 16)*Math.pow(16, 5) + (this.r % 16)*Math.pow(16,4)
            +Math.floor(this.g / 16)*Math.pow(16, 3) + (this.g % 16)*Math.pow(16,2)
            +Math.floor(this.b / 16)*Math.pow(16, 1) + (this.b % 16)*Math.pow(16,0)
            ;
      var start = new Date().getTime();
      //this.wb.update();
      var that = this;

      var keyboard = this.game.input.keyboard;
      
      var playerEvents = []

      if (this.jDown === false && keyboard.isDown(Phaser.Keyboard.N)) {
          this.jDown = true;
          this.currentPlayer += 1;
          this.otherCurrentPlayer += 1;
          this.frpPlayer = this.frpWorld.players[this.currentPlayer % this.frpWorld.players.length];
          this.otherFrpPlayer = this.frpWorld.players[this.otherCurrentPlayer % this.frpWorld.players.length];

             var that = this;
             playerEvents.push (function() {
                that.frpPlayer.moveEvent.send(new b.StopMoveEvent());
                });         
             playerEvents.push (function() {
                that.otherFrpPlayer.moveEvent.send(new b.StopMoveEvent());
                 that.moving = false;
                 that.moving2 = false;
                 that.jumpDown = false;
                 that.jumpDown2 = false;
                });         

      }
      if (this.jDown === true && !keyboard.isDown(Phaser.Keyboard.J)) {
          this.jDown = false;
      }
     
      for (var i = 0; i < this.frpWorld.players.length; i++) {
            var x = function (i) { 
                playerEvents.push (function() {
                    that.frpWorld.players[i].setPosition.send(new b.Direction (
                        that.frpWorld.players[i].sprite.body.x, that.frpWorld.players[i].sprite.body.y));
            }); }
            x(i);
      }


      if (this.game.input.keyboard.isDown(Phaser.Keyboard.S)) {
          playerEvents.push (function() {
              that.frpPlayer.setBlockEvent.send(true);
              });
      }
      if (this.game.input.keyboard.isDown(Phaser.Keyboard.J)) {
          playerEvents.push (function() {
              that.otherFrpPlayer.setBlockEvent.send(true);
              });
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
      this.keyboardInputP1.executeCommands()
      this.keyboardInputP2.executeCommands()
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
