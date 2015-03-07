function hash(x, y) {
    return (x + ',' + y);
}

function RemoveBlockStrategy(world) {
    this.world = world;
    this.strategies = {};
    this.strategy = 'closest';
    // this.strategy = 'random';
    this.strategy = 'round';

    function removeRandom(world) {

        // Get all removables
        // TODO : keep that list prepared / indexed in WorldBlocks
        var non_perm_blocks = [];
        for (bk in world.blocks) {
            if( ! world.blocktypes[world.blocks[bk].k.t].perma ) {
                non_perm_blocks.push(world.blocks[bk]);
            }
        }

        var index = Math.round(Math.random() * non_perm_blocks.length);
        world.pendingRemoves.push({key:non_perm_blocks[index]});
    }

    function removeClosest(world, currentSprite, otherSprite) {
        world.removeClosestTo(otherSprite.x, otherSprite.y);
    }

    function removeRoundRobin(world, currentSprite, otherSprite) {
        if ( world.block_history && world.block_history.length ) {
            world.pendingRemoves.push({key:world.blocks[world.block_history[0]]});
        }
    }

    this.strategies['random'] = removeRandom;
    this.strategies['closest'] = removeClosest;
    this.strategies['round'] = removeRoundRobin;

    this.remove = function(currentSprite, otherSprite) {
        this.strategies[this.strategy](this.world, currentSprite, otherSprite);
    }
}

function WorldBlocks (game) {
    this.game = game;
    this.blocks = {};
    this.pendingRemoves = [];
    this.pendingAdds = [];
    this.block_group = this.game.add.group();
    this.block_group.enableBody = true;
    this.block_group.allowGravity = false;
    this.block_group.immovable = true;
    this.gridsize=19;
    this.block_history = [];

    this.blockremove = new RemoveBlockStrategy(this);

    this.blocktypes = {
        'default': {
            perma:false,
            texture:['redboxblock', 1],
            kills:false,
        },
        'stone': {
            perma:true,
            texture:['stoneblock', 1],
            kills:false,
        },
        'death': {
            perma:true,
            texture:['deathblock', 1],
            kills:true,
        },
        'win': {
            perma:true,
            texture:['winblock', 1],
            kills:false,
            win:true,
            player:1,
        },
        'win2': {
            perma:true,
            texture:['winblock2', 1],
            kills:false,
            win:true,
            player:2,
        },

    };
}

WorldBlocks.prototype = {
    canAddBlock: function(x,y) {
	    var that = this;
	    if(that.blocks[hash(x, y)])
		{
		    return 0;
		}
        return 1;

	},
    hash: hash,
    addBlock: function(x, y, t) {
        var t = t || 'default';
        this.pendingAdds.push({x:x, y:y, t:t});
    },
    toWorldCoords: function(x, y) {
        return {x:x*this.gridsize, y:y*this.gridsize};
    },
    fromWorldCoords: function (x, y) {
        x = Math.floor(x / this.gridsize);
        y = Math.floor(y / this.gridsize + 1);
        return {x:x, y:y};
    },
    removeBlock: function(currentSprite, otherSprite) {
        this.blockremove.remove(currentSprite, otherSprite);
    },
    removeClosestTo: function (x, y) {
        var blockCoords2 = this.fromWorldCoords(x, y);
        var blockCoords = {x:blockCoords2.x+1, y:blockCoords2.y};
        var that = this;
        var nearCoords = [];
        var keys = Object.keys(this.blocks);

        var coords = [
            [blockCoords.x, blockCoords.y],
            [blockCoords.x, blockCoords.y - 1],
            [blockCoords.x - 1, blockCoords.y - 1],
            [blockCoords.x + 1, blockCoords.y - 1],
            [blockCoords.x, blockCoords.y + 1],
            [blockCoords.x-1, blockCoords.y],
            [blockCoords.x+1, blockCoords.y],
            [blockCoords.x-1, blockCoords.y+1],
            [blockCoords.x, blockCoords.y+1],
            [blockCoords.x+1, blockCoords.y+1],

            [blockCoords.x-2, blockCoords.y-2],
            [blockCoords.x-1, blockCoords.y-2],
            [blockCoords.x, blockCoords.y-2],
            [blockCoords.x+1, blockCoords.y-2],
            [blockCoords.x+2, blockCoords.y-2],

            [blockCoords.x-2, blockCoords.y+2],
            [blockCoords.x-1, blockCoords.y+2],
            [blockCoords.x, blockCoords.y+2],
            [blockCoords.x+1, blockCoords.y+2],
            [blockCoords.x+2, blockCoords.y+2],

            [blockCoords.x-2, blockCoords.y-1],
            [blockCoords.x+2, blockCoords.y-1],
            [blockCoords.x-2, blockCoords.y],
            [blockCoords.x+2, blockCoords.y],
            [blockCoords.x-2, blockCoords.y+1],
            [blockCoords.x+2, blockCoords.y+1],

            [blockCoords.x-3, blockCoords.y-3],
            [blockCoords.x-2, blockCoords.y-3],
            [blockCoords.x-1, blockCoords.y-3],
            [blockCoords.x, blockCoords.y-3],
            [blockCoords.x+1, blockCoords.y-3],
            [blockCoords.x+2, blockCoords.y-3],
            [blockCoords.x+3, blockCoords.y-3],

            [blockCoords.x-3, blockCoords.y+3],
            [blockCoords.x-2, blockCoords.y+3],
            [blockCoords.x-1, blockCoords.y+3],
            [blockCoords.x, blockCoords.y+3],
            [blockCoords.x+1, blockCoords.y+3],
            [blockCoords.x+2, blockCoords.y+3],
            [blockCoords.x+3, blockCoords.y+3],

            [blockCoords.x-3, blockCoords.y+2],
            [blockCoords.x+3, blockCoords.y+2],
            [blockCoords.x-3, blockCoords.y+1],
            [blockCoords.x+3, blockCoords.y+1],
            [blockCoords.x-3, blockCoords.y],
            [blockCoords.x+3, blockCoords.y],
            [blockCoords.x-3, blockCoords.y-1],
            [blockCoords.x+3, blockCoords.y-1],
            [blockCoords.x-3, blockCoords.y-2],
            [blockCoords.x+3, blockCoords.y-2],

            [blockCoords.x-4, blockCoords.y+4],
            [blockCoords.x-3, blockCoords.y+4],
            [blockCoords.x-2, blockCoords.y+4],
            [blockCoords.x-1, blockCoords.y+4],
            [blockCoords.x, blockCoords.y+4],
            [blockCoords.x+1, blockCoords.y+4],
            [blockCoords.x+2, blockCoords.y+4],
            [blockCoords.x+3, blockCoords.y+4],
            [blockCoords.x+4, blockCoords.y+4],


            [blockCoords.x-4, blockCoords.y-4],
            [blockCoords.x-3, blockCoords.y-4],
            [blockCoords.x-2, blockCoords.y-4],
            [blockCoords.x-1, blockCoords.y-4],
            [blockCoords.x, blockCoords.y-4],
            [blockCoords.x+1, blockCoords.y-4],
            [blockCoords.x+2, blockCoords.y-4],
            [blockCoords.x+3, blockCoords.y-4],
            [blockCoords.x+4, blockCoords.y-4],

            [blockCoords.x-4, blockCoords.y+3],
            [blockCoords.x+4, blockCoords.y+3],
            [blockCoords.x-4, blockCoords.y+2],
            [blockCoords.x+4, blockCoords.y+2],
            [blockCoords.x-4, blockCoords.y+1],
            [blockCoords.x+4, blockCoords.y+1],
            [blockCoords.x-4, blockCoords.y],
            [blockCoords.x+4, blockCoords.y],
            [blockCoords.x-4, blockCoords.y-1],
            [blockCoords.x+4, blockCoords.y-1],
            [blockCoords.x-4, blockCoords.y-2],
            [blockCoords.x+4, blockCoords.y-2],
            [blockCoords.x-4, blockCoords.y-3],
            [blockCoords.x+4, blockCoords.y-3],

            [blockCoords.x-5, blockCoords.y+4],
            [blockCoords.x+5, blockCoords.y+4],
            [blockCoords.x-5, blockCoords.y+3],
            [blockCoords.x+5, blockCoords.y+3],
            [blockCoords.x-5, blockCoords.y+2],
            [blockCoords.x+5, blockCoords.y+2],
            [blockCoords.x-5, blockCoords.y+1],
            [blockCoords.x+5, blockCoords.y+1],
            [blockCoords.x-5, blockCoords.y],
            [blockCoords.x+5, blockCoords.y],
            [blockCoords.x-5, blockCoords.y-1],
            [blockCoords.x+5, blockCoords.y-1],
            [blockCoords.x-5, blockCoords.y-2],
            [blockCoords.x+5, blockCoords.y-2],
            [blockCoords.x-5, blockCoords.y-3],
            [blockCoords.x+5, blockCoords.y-3],
            [blockCoords.x-5, blockCoords.y-4],
            [blockCoords.x+5, blockCoords.y-4],

            [blockCoords.x-4, blockCoords.y-5],
            [blockCoords.x-3, blockCoords.y-5],
            [blockCoords.x-2, blockCoords.y-5],
            [blockCoords.x-1, blockCoords.y-5],
            [blockCoords.x, blockCoords.y-5],
            [blockCoords.x+1, blockCoords.y-5],
            [blockCoords.x+2, blockCoords.y-5],
            [blockCoords.x+3, blockCoords.y-5],
            [blockCoords.x+4, blockCoords.y-5],
            [blockCoords.x+5, blockCoords.y-5],

            [blockCoords.x-4, blockCoords.y+5],
            [blockCoords.x-3, blockCoords.y+5],
            [blockCoords.x-2, blockCoords.y+5],
            [blockCoords.x-1, blockCoords.y+5],
            [blockCoords.x, blockCoords.y+5],
            [blockCoords.x+1, blockCoords.y+5],
            [blockCoords.x+2, blockCoords.y+5],
            [blockCoords.x+3, blockCoords.y+5],
            [blockCoords.x+4, blockCoords.y+5],
            [blockCoords.x+5, blockCoords.y+5],
        ];


        var foundNothing = coords.every(function (v, k) {
            if (that.blocks[hash(v[0], v[1])]) {
                var b = that.blocks[hash(v[0], v[1])];
                if (!that.blocktypes[b.k.t].perma)
                {
                    that.pendingRemoves.push({key:that.blocks[hash(v[0], v[1])]})
                    return false;
                }
            }
            return true;
            });

        if (foundNothing == false) {
            return;
            }
        //console.log(blockCoords);
        //console.log(that.pendingRemoves);

        keys.forEach(function (v, k) {

            // Consider only blocks that do not have perma-flag
            if ( ! that.blocktypes[that.blocks[v].k.t].perma ) {
                nearCoords.push(that.blocks[v]);
            }
        });

        nearCoords.sort(function (a, b) {
            if ((a.x - blockCoords.x)^2 + (a.y - blockCoords.y)^2 >
                (b.x - blockCoords.x)^2 + (b.y - blockCoords.y)^2)
                {
                    return 1;
                } else if ((a.x - blockCoords.x)^2 + (a.y - blockCoords.y)^2 == (b.x - blockCoords.x)^2 + (b.y - blockCoords.y)^2)
                {
                    return 0;
                } else  {
                    return -1;
                }
            });

        var v = nearCoords[0];
        that.pendingRemoves.push(
            {key:v
            });
        return;
    },
    registerBlockTouch: function(block) {
        block.model;
        // this.pendingRemoves.push({key:hash(block.model.x, block.model.y));
    },
    update: function() {
        var that = this;
        this.pendingAdds.forEach(function (v, i) {
            var coords = that.toWorldCoords(v.x, v.y);

            sp = that.block_group.create(coords.x, coords.y);
            sp.loadTexture(that.blocktypes[v.t].texture[0], that.blocktypes[v.t].texture[1]);
            sp.body.immovable = true;
            sp.body.setSize(20, 20, 2, 2);
            sp.model = v;
            that.blocks[hash(v.x, v.y)] = {k:v, v:sp};

            if ( ! that.blocktypes[sp.model.t].perma ) {
                // if non perma, add to history
                that.block_history.push(hash(v.x, v.y));
            }

            });
        this.pendingAdds = [];

        this.pendingRemoves.forEach(function (v, i) {
            if (v.key) {
                v.key.v.kill();
                delete that.blocks[hash(v.key.k.x, v.key.k.y)]

                var i = that.block_history.indexOf(hash(v.key.k.x, v.key.k.y));
                if (i > -1) {
                    that.block_history =
                        that.block_history.slice(0, i)
                            .concat(that.block_history.slice(i+1, that.block_history.length));
                }
            }
        });
        this.pendingRemoves = [];
    }
};

module.exports = WorldBlocks
