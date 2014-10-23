// TiledLoader("tiled_level.json", {'spritesheet': 'assets/spritesheet.png'}, ['Tile Layer 1']);
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
        console.log(tileset);
    }
    
    for (var layer_id in this.layer_names) {
        var layer_name = this.layer_names[layer_id];
        this.layers[layer_name] = tiled_map.createLayer(layer_name);
        console.log(this.layers[layer_name]);
    }
    
    return tiled_map;
}

module.exports = TiledLoader;

