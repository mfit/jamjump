// TiledLoader("tiled_level.json", {'spritesheet': 'assets/spritesheet.png'}, ['Tile Layer 1']);
var b = require('../frp/world_behaviors.js')

function TiledLoader(tiled_json_file, tileset_images, layers) {
    this.filename = tiled_json_file;
    this.tileset_images = tileset_images;
    this.layer_names = layers;
    this.layers = {};
    this.loaded_images = {};
    return this;
}

TiledLoader.prototype.load = function(loader) {
    loader.tilemap('level', this.filename, null, Phaser.Tilemap.TILED_JSON);

    for (var tileset in this.tileset_images) {
        loader.image(tileset, this.tileset_images[tileset]);
        this.loaded_images[tileset] = tileset;
    }
}

TiledLoader.prototype.create = function(adder) {
    var tiled_map = adder.tilemap('level');
    
    for (var tileset in this.loaded_images) {
        tiled_map.addTilesetImage(tileset, tileset);
    }
    
    for (var layer_id in this.layer_names) {
        var layer_name = this.layer_names[layer_id];
        //this.layers[layer_name] = tiled_map.createLayer(layer_name);
    }
    
    this.tiled_map = tiled_map;
    
    return tiled_map;
}

TiledLoader.prototype.runInterpreter = function (interpreter) {
    for (var layerId in this.tiled_map.layers) {
        var layer = this.tiled_map.layers[layerId];
        var layerInterpreter = interpreter.getLayerInterpreter(layer)
        for (var y = 0; y < layer.data.length; y++) {
            for (var x = 0; x < layer.data[y].length; x++) {
                layerInterpreter.makeTile(x, y, layer.data[y][x]);
            }
        }
    }
}

function TiledInterpreter() {
}

TiledInterpreter.prototype.getLayerInterpreter = function (layer) {
}

function LayerInterpreter() {
}

LayerInterpreter.prototype.makeTile = function (x, y, tile) {
}
    
function BaseInterpreter(frpWorld) {
    this.frpWorld = frpWorld;
}

BaseInterpreter.prototype = new TiledInterpreter();
BaseInterpreter.prototype.getLayerInterpreter = function (layer) {
    if (layer.name == "BlockLayer") {
        return new BlockLayerInterpreter(this);
    }
}

function BlockLayerInterpreter(baseInterpreter) {
    this.frpWorld = baseInterpreter.frpWorld;
}
BlockLayerInterpreter.prototype = new LayerInterpreter();
BlockLayerInterpreter.prototype.makeTile = function (x, y, tile) {
    if (tile.properties.hasOwnProperty('type')) {
        var block = null;
        switch (tile.properties['type']) {
            case 'DefaultBlock':
                block = new b.DefaultBlock();
                break;
            case 'vanishing':
                block = new b.TempBlock();
                break;
            case 'stone':
                block = new b.StoneBlock();
                break;
            case 'win':
                block = new b.WinBlock();
                break;
            case 'death':
                block = new b.DeathBlock();
                break;
        }
        block.gid = tile.index;
        this.frpWorld.worldBlocks.addBlock.send({x:x, y:y, block:block});
    }
}

LoadTiledAtlas = function (game, tilemap) {
    for (var setIndex = 0; setIndex < tilemap.tilesets.length; setIndex++) {
        var set = tilemap.tilesets[setIndex];
        var frames = [];
        for (var gid = set.firstgid; gid < set.firstgid + set.total; gid++) {
            var frame = {
                filename: gid.toString(),
                frame: {x: set.drawCoords[gid][0], y:set.drawCoords[gid][1], w:set.tileWidth, h:set.tileHeight},
                rotated:false,
                trimmed:true,
                spriteSourceSize: {x:0, y:0, w:set.tileWidth, h:set.tileHeight},
                sourceSize: {w:set.tileWidth, h:set.tileHeight},
            }
            frames.push(frame);
        }
        game.load.atlas("test", "assets/tileset.png", null, {frames:frames}, Phaser.Loader.TEXTURE_ATLAS_JSON_ARRAY);
    }
}

MakeObjectLayerSprites = function (game, tilemap, layerName) {
    var objectData = tilemap.objects[layerName];
    for (var i = 0; i < objectData.length; i++) {
        var objectGid = objectData[i].gid
        var tilesetIndex = tilemap.tiles[objectGid][2];
        var set = tilemap.tilesets[tilesetIndex];

        var sprite = game.add.tileSprite(objectData[i].x, objectData[i].y, set.tileWidth, set.tileHeight, "test", objectGid);
        return sprite;
    }
}

module.exports.TiledLoader = TiledLoader;
module.exports.LoadTiledAtlas = LoadTiledAtlas;
module.exports.MakeObjectLayerSprites = MakeObjectLayerSprites;
module.exports.BaseInterpreter = BaseInterpreter;

