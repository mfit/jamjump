'use strict';
function LevelBuilder(game, world, storage) {
    this.levels = [];
    this.wb = world;
    this.game = game;

    this.storage = storage;

    this.xlimit = 42;
    this.ylimit = 31;

    this.typemap = {
      'default':'1',
      'stone':'2',
      'death':'3',
      'win2':'8',
      'win':'9',
    }
}

LevelBuilder.prototype = {
    load: function(levelstring) {
      var x = -1,
        y = 0,
        levelAsString = levelstring;
      for (var ch in levelAsString) {
        if (levelAsString[ch] == "\n") {
          y++;
          x = -1;
        }

        if (levelAsString[ch] === "1") {
          this.wb.addBlock(x, y);
        } else if (levelAsString[ch] === "2") {
          this.wb.addBlock(x, y, 'stone');
        } else if (levelAsString[ch] === "3") {
          this.wb.addBlock(x, y, 'death');
        } else if (levelAsString[ch] === "x") {
          this.game.players[0].sprite.x = x*this.wb.gridsize;
          this.game.players[0].sprite.y = y*this.wb.gridsize;
          this.game.players[0].startPos = [x*this.wb.gridsize,y*this.wb.gridsize];
        } else if (levelAsString[ch] === "y") {
          this.game.players[1].sprite.x = x*this.wb.gridsize;
          this.game.players[1].sprite.y = y*this.wb.gridsize;
          this.game.players[1].startPos = [x*this.wb.gridsize,y*this.wb.gridsize];
        } else if (levelAsString[ch] === "8") {
          this.wb.addBlock(x, y, 'win2');
        } else if (levelAsString[ch] === "9") {
          this.wb.addBlock(x, y, 'win');
        }

        x++;
      }
    },
    saveLevel: function() {
      this.storage.level =  this.serializeLevel();
    },
    serializeLevel: function() {
      var i,j, type, code, str="";

      for (i=0; i<this.ylimit; i++) {
        for (j=0; j<this.xlimit; j++) {
          code = false;
          if (this.wb.blocks[this.wb.hash(j, i)]) {
            type = this.wb.blocks[this.wb.hash(j, i)].k.t;
            if (type in this.typemap) {
              code = this.typemap[type];
            }
          }
          str+= code ? code : "0";
        }
        str+="\n";
      }
      return str;
    },
    loadDefaultLevel: function(contents) {
      if (this.storage.level) {

        this.load(this.storage.level);

      } else {

        this.load(contents);

      }
    }
}


module.exports = LevelBuilder;
