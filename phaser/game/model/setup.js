function JumpSetup() {

  this.players = [
    { name:"player1",
      skin:1,
      id:1,
      controller:'gamepad'
    },
    { name:"player2",
      skin:2,
      id:2,
      controller:'keyb'
    },
    /*{ name:"player3",
      skin:2,
      id:3,
      controller:'gamepad2'
    },*/
  ];

  this.level = {};
  this.level_skin = 'blub';
  this.sound = 'track2';

  this.backgroundMusic;     // a phaser music asset to be started at level enter
  this.playMusic = false;

}

JumpSetup.prototype = {
}

module.exports = JumpSetup;
