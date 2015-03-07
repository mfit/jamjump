function JumpPlayer(state, sprite, playerId, controller) {
    // Initialise with reference to game and sprite
    this.gamestate = state;
    this.game = state.game;
    this.sprite = sprite;
    this.controller = controller;
    this.playerId = playerId;

    this.lastUpdate = this.game.time.now;

    // Physic/Behavioral Constants
    this.JUMPFORCE = 300;
    this.BLOCKFART = 50;
    this.BLOCKCOST = 300;
    this.MAXBLOCKPOWER = 1000;
    this.NOREPEAT = 100;
    if (this.game.level === 3) {
        this.NOREPEAT = 200;
    }
    this.DOUBLEJUMP_TRIGGER_VELOCITY = 15;  // max y-velocity to trigger double jump

    this.YDIFF_TO_STAND = 10;   // what y-diff signals "stand-on-block"
                                // HINT : depends on the sprite's bodies / anchor points

    // Player state
    this.blockpower = this.MAXBLOCKPOWER;
    this.jumpStarted = false;
    this.canDoubleJump = false;

    this.actionTimers = {};

	this.jumpsound = this.game.add.audio('jumpsound');
}

JumpPlayer.prototype = {
  setPosition: function (x, y) {
    this.sprite.body.x = x;
    this.sprite.body.y = y;
  },

  attemptAction: function(actionName) {
    // Pass in an action name,
    // this method will check if the action can be performed,
    // or if it is still blocked (timing constraints)
    // (in case it is possible, it will automatically reset the timer)
    var t = this.game.time.now;

    if ( this.actionTimers[actionName] === undefined ||
        t - this.actionTimers[actionName] > this.NOREPEAT) {
        this.actionTimers[actionName] = t;
        return true;
    } else {
        return false;
    }
  },

  chooseSkin: function (skin_n) {
    if (skin_n < 2) {
        this.sprite.animations.play('jump', 15, true);
    } else {
        this.sprite.animations.play('run', 15, true);
    }

  },

  init: function() {
    // First thing is to enable physics
    this.game.physics.enable(this.sprite, Phaser.Physics.ARCADE);

    // Set parameters of physics
    this.sprite.body.collideWorldBounds = true;
    this.sprite.body.setSize(
        14,  // width
        14,  // height
        2,   // offset-x
        10    // offset-y
        );
    this.sprite.body.gravity.y = 1050;
    console.log(this.sprite.body);
    this.sprite.allowGravity = true;
    this.fullSpeedTreshold = false; // to turn on , set value e.g. 300;
    this.fullSpeedCounter = 0;
    this.didDoubleJump = false;

    // Default skin-1
    this.chooseSkin(this.playerId);

    this.sprite.anchor.set(0.5, 0);
  },

  registerBlockTouch: function(block) {
    // called from phyics collision testing ...
    // console.log("touched");
    // console.log(block);
    var dir = block.body.y - this.sprite.body.y;
    if (dir >= this.YDIFF_TO_STAND) {
        this.jumpStarted = false;
        this.canDoubleJump = false;
        this.didDoubleJump = false;
    };
  },

  update: function() {
    var v = this.sprite.body.velocity,
        time_passed;

    time_passed = this.game.time.now - this.lastUpdate;
    this.lastUpdate = this.game.time.now;

    // Fill up blockpower
    this.blockpower += time_passed;
    if (this.blockpower > this.MAXBLOCKPOWER) {
        this.blockpower = this.MAXBLOCKPOWER;
    }

    // Direct mapping of controller-x to player velocity
    this.sprite.body.velocity.x = this.controller.getDirection().x*140;
    if (Math.abs(this.sprite.body.velocity.x) > 100 && this.jumpStarted == false) {
        this.fullSpeedCounter += time_passed;
    } else if (this.jumpStarted == false) {
        this.fullSpeedCounter = 0;
    }

    // Mirror sprite (look left or right)
    if (this.controller.getDirection().x > 0) {
        this.sprite.scale.setTo(1 , 1);
    } else if (this.controller.getDirection().x < 0) {
        this.sprite.scale.setTo(-1 , 1);
    }


    // When enabled, double speed (running) after some time
    if (this.fullSpeedTreshold && this.fullSpeedCounter > this.fullSpeedTreshold) {
        this.sprite.body.velocity.x *= 2.0;
    }


    if (this.controller.getButtonBUp() && this.didDoubleJump == false) {
        this.canDoubleJump = true;
    }

    if (this.controller.getButtonB()) {
        // funny double jump mechanic
        if ( Math.abs(v.y) < 1 && !this.jumpStarted) {
          v.y -= this.JUMPFORCE; // jump force
		  this.jumpsound.play();
          this.jumpStarted = true;
        }

        if ( this.canDoubleJump) {
            // double jump !

            this.didDoubleJump = true;
            this.canDoubleJump = false;
			this.jumpsound.play();
            if (v.y > 0) {
                v.y -= this.JUMPFORCE*1.5;
            }
            else {
                v.y -= this.JUMPFORCE; // jump force
            }
        }

    }

    if (this.controller.getButtonA()) {
        // Set a block !

        // Is blockforce high enough =
        if(this.blockpower > 0 && this.attemptAction('setblock')) {
          this.gamestate.addBlock(this.playerId);
          this.lastBlockSet = this.game.time.now;
          v.y -= this.BLOCKFART;

          this.blockpower -= this.BLOCKCOST;
        }

    }

    // When doing physics / "velocity based" slide x controlls:
    // var max_x_vel = 300;
    //if (this.cursors.right.isDown) {
    //      v.x += 30;
    // }
    // v.x *= 0.98;
  },

};


module.exports = JumpPlayer;
