function GUI(game, font) {
    this.game = game;
    this.game.gui = this;
    this.font = font;
    this.bmpText;
    this.textpos=0;

    // keep tracks of textparts on the screen
    this.texts=[];

    this.textupdate = this.game.time.now;

    //this.lines=['Test'];
    //this.linecounter = 0;
}

GUI.prototype = {

    create: function () {

    },

    update: function () {
        var t = this.game.time.now,
                txt,
                i, j, p,
                str,
                val,
                that = this;
        if (t - this.textupdate > 200) {
            this.textupdate = t;

            // remove old texts
            this.texts.forEach(function(t) {
                that.game.world.remove(t);
            });
            this.texts = [];

            // add a greeting
/*            this.bmpText = this.game.add.bitmapText(
                this.textpos,
                this.game.camera.view.height - 100,
                'nokia',
                "HALLO", 64);
            this.bmpText.fixedToCamera = true;*/

            for (j=0; j<this.game.players.length; j++) {
                p =  this.game.players[j];
                val = p.blockpower / 200;
                str = '';
                for (i=0;i<val;i++) { str+='|'; } // Power-meter as string
                txt = that.game.add.bitmapText(
                    j*200,
                    0,
                    'nokia',
                    //str,
                    p.playerId + " " + str,
                    32);
                that.texts.push(txt);
            }

            // this.game.players.forEach(function(p) {
            // });

            // score :
            var scoretxt = that.game.add.bitmapText(
                    400,
                    0,
                    'nokia',
                    "Score: " + this.game.score[0] + ":" + this.game.score[1],
                    32);
            that.texts.push(scoretxt);



        }
    }
};

module.exports = GUI;
