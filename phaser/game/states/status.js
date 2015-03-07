
'use strict';
function GameOver() {}

GameOver.prototype = {
  preload: function () {

  },
  create: function () {
    var style = { font: '65px Arial', fill: '#ffffff', align: 'center'};

    var temp_sprite = this.game.add.sprite(0,0, 'background2');


    var text = this.game.stateWinSuccess ?
      "YOU REACHED \n THE COMET \n WIN!" :
      "FELL INTO LAVA \n - YOU LOST ";

    if (this.game.statePlayerWin > -1 ) {
      // single player win
      text += "\nPLAYER " + this.game.statePlayerWin + " WINS !";
    }


    text +="\n (enter to continue)";

    this.titleText = this.game.add.text(this.game.world.centerX, 300, text, style);


    this.titleText.anchor.setTo(0.5, 0.5);
  },
  update: function () {

     if (this.game.input.keyboard.isDown(Phaser.Keyboard.ENTER))
      {
          this.game.state.start("play");
      }

    if(this.game.input.activePointer.justPressed()) {
      this.game.state.start('play');
    }
  }
};
module.exports = GameOver;
