function JumpController(controllerType, controllerHandler, settings) {
    if (controllerType == 'keyb') {
      return new JumpKeyboardController(controllerHandler, settings);
    } else if (controllerType == 'gamepad') {
      return new JumpGamepadController(controllerHandler, settings);
    } else if (controllerType == 'gamepad2') {
      return new JumpGamepadController(controllerHandler, settings);
    } else if (controllerType == 'keyb2') {
      return new JumpGamepadController(controllerHandler, settings);
    } else {
      throw "Unknown controller-type ! Use 'keyb', 'keyb2' or 'gamepad/2'";
    }
}


function JumpKeyboardController(controllerHandler, settings) {
  // setting keys according to settings parameter
  this.keys = {
    'left': controllerHandler.addKey(settings.left),
    'right': controllerHandler.addKey(settings.right),
    'jump': controllerHandler.addKey(settings.jump),
    'block': controllerHandler.addKey(settings.block),
  }
}

JumpKeyboardController.prototype = {
  getDirection: function() {
    var x=0, y=0;

    if (this.keys.right.isDown) {
      x+=1.0;
    }
    if (this.keys.left.isDown) {
      x-=1.0;
    }
    // if (this.handler.isDown(Phaser.Keyboard.KEY_W) {
    //   y-=1.0;
    // }
    // if (this.handler.down.isDown) {
    //   y+=1.0;
    // }
    return {x:x, y:y};
  },

  getButtonA: function() {
    return this.keys.block.isDown;
  },

  getButtonBUp: function() {
    return this.keys.jump.isUp;
  },

  getButtonB: function() {
    return this.keys.jump.isDown;
  },
};


function JumpGamepadController(controllerHandler, settings) {
    this.handler = controllerHandler;
    this.settings = settings;
    this.type = settings.type || 1;

    this.type = true;
    this.abutton = this.type ? Phaser.Gamepad.XBOX360_X : Phaser.Gamepad.XBOX360_Y;
    this.bbutton = this.type ? Phaser.Gamepad.XBOX360_A : Phaser.Gamepad.XBOX360_B;
}

JumpGamepadController.prototype = {

  getDirection: function() {
      var x = this.handler.axis(Phaser.Gamepad.XBOX360_STICK_LEFT_X);
      var y = this.handler.axis(Phaser.Gamepad.XBOX360_STICK_LEFT_Y);
      return {x:x, y:y};
  },

  getButtonA: function() {
    return this.handler.isDown(this.abutton);
  },

  getButtonB: function() {
    return this.handler.isDown(this.bbutton);
  },

  getButtonBUp: function() {
    return this.handler.isUp(this.bbutton);
  },

};


function JumpKeyboardControllerAlternativ(controllerHandler) {
  this.handler = controllerHandler;
}

JumpKeyboardControllerAlternativ.prototype = {
  getDirection: function() {
    var x=0, y=0;

    if (this.handler.right.isDown) {
      x+=1.0;
    }
    if (this.handler.left.isDown) {
      x-=1.0;
    }
    if (this.handler.up.isDown) {
      y-=1.0;
    }
    if (this.handler.down.isDown) {
      y+=1.0;
    }
    return {x:x, y:y};
  },

  getButtonA: function() {
    return this.handler.down.isDown;
  },

  getButtonBUp: function() {
    return this.handler.up.isUp;
  },

  getButtonB: function() {
    return this.handler.up.isDown;
  },
};

// -----------------------------------------------------------

module.exports = JumpController;
