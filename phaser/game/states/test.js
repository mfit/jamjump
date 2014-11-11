
'use strict';
var Tiled = require('../model/tiled.js');
var WorldBlocks = require('../model/world');
var frp = require('../frp/frp.js');
var player = require('../frp/player_behaviors.js');
var b = require('../frp/world_behaviors.js');
var input = require('../model/input.js');
var io = require('socket.io-client');

var toPhaser = require ('../frp/toPhaser.js');

var ru = require ('../render/RenderUnit.js');
var frpCfg = require ('../frp/frp_settings.js');
var renderSettings = require ('../settings/RenderSettings.js');

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

        // Setup multiplayer
        this._connectMultiplayer();

        this.game.world.width = 10000;
        this.game.world.height = 2500;

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
        this.game.rootGroup.add(new ru.RenderUnit (this.game));
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
            //this.game.rootGroup.add(this.frpWorld.players[i].pushBox.sprite);
        }

        // Set 1 color bg

        var that = this;
        frp.sync(function() {
            that.r = new frpCfg.ConfigBehavior ("bg-red", 51);
            that.g = new frpCfg.ConfigBehavior ("bg-green", 171);
            that.b = new frpCfg.ConfigBehavior ("bg-blue", 249);
        });

        frpCfg.initialize(this.game.gameSettings, this.game.toolbar);

        frp.sync(function() {
            var anyChanged = frp.mergeAll ([
               that.r.values(),
               that.g.updates(),
               that.b.updates(),
               ])
            var change = anyChanged.snapshotMany ([that.r, that.g, that.b], function (_, r, g, b) {
                  return function () {
                    that.game.stage.backgroundColor =
                        Math.floor(r / 16)*Math.pow(16, 5) + (r % 16)*Math.pow(16,4)
                        +Math.floor(g / 16)*Math.pow(16, 3) + (g % 16)*Math.pow(16,2)
                        +Math.floor(b / 16)*Math.pow(16, 1) + (b % 16)*Math.pow(16,0)
                        ;
                  }
                });
            change.listen (function (f) {f()});
            });

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
      this.running = true;
      this.spaceDown = false;
      this.renderSettingsInitialized = 0;

      // HACK HACK
      var old = Phaser.Stage.prototype.visibilityChange
      var that = this;
      this.hasFocus = true;
      Phaser.Stage.prototype.visibilityChange = function (event) {
          old(event);
        console.log(event.type);
          if (event.type == 'focus') {
              if (that.hasFocus) {
                console.log("remove keys");
                that.input.removeKeys();
                that.hasFocus = false;
              } else {
                console.log("mkkeys");
                that.input.mkKeys();
                that.hasFocus = true;
              }
          }
      }
  },
  getId: function() {
      return -1;
  },
  render: function () {
      if (this.renderSettingsInitialized === 0) {
          this.renderSettingsInitialized = 1;
      }
      else if (this.renderSettingsInitialized === 1) {
          this.renderSettingsInitialized = -1;
          renderSettings.initialize(this.game.gameSettings, this.game.toolbar);
      }
      this.game.debug.text(this.game.time.fps || '--', 2, 14, "#00ff00");
      this.game.debug.text(this.frpWorld.mod.value(), 2, 28, "#00ff00");
  },
  update: function () {


      var start = new Date().getTime();
      //this.wb.update();
      var that = this;

      var keyboard = this.game.input.keyboard;

      var playerEvents = []

      if (this.spaceDown == false && keyboard.isDown(Phaser.Keyboard.T)) {
          this.running = !this.running;
          this.spaceDown = true;
        }
      if (this.spaceDown == true && (!keyboard.isDown(Phaser.Keyboard.T))) {
          this.spaceDown = false;
          }

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
                        that.frpWorld.players[i].sprite.x, that.frpWorld.players[i].sprite.y));
            }); }
            x(i);
      }


      if (this.game.input.keyboard.isDown(Phaser.Keyboard.S)) {
          playerEvents.push (function() {
              that.frpPlayer.setBlockEvent.send(true);
              });
      }
      if (this.game.input.keyboard.isDown(Phaser.Keyboard.J)) {
          playerEvents.push ({
              target:'otherFrpPlayer',
              event:'setBlockEvent',
              value:true
          });
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
      if (this.running) {
        frp.sync(function() {b.preTick.send(that.game.time.elapsed)});
      }
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


      if (this.running) {
        frp.sync(function() {b.tick.send(that.game.time.elapsed)});
        frp.sync(function() {b.postTick.send(that.game.time.elapsed)});
      }

      //
      // Test for pause key
      //
      if (this.game.input.keyboard.isDown(Phaser.Keyboard.ESC)) {
          this.game.state.start("menu");
      }
      var end = new Date().getTime();
      if (end - start > 10)
        console.warn ("dt", end - start);
  },
  _connectMultiplayer : function() {
    console.log("Attempt connect to server..");
    var socket = io.connect('http://localhost:1337', {reconnection:false});
    socket.on('gup', function (data) {
      console.log("received an event : ");
      console.log(data);
    });

    // Handle disconnections manually
    socket.on('disconnect', function(){
      console.log("Connection failed / disconneceted..");
      // socket.connect(callback);
    });
  }
};

module.exports = TestState;
