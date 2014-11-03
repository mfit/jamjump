#frp = require '../frp/behavior.js'
frp = require '../frp/frp.js'
tick = frp.tick
preTick = frp.preTick
postTick = frp.postTick

log = frp.log

player = require '../frp/player_behaviors.js'
StopMoveEvent = player.StopMoveEvent
MoveEvent = player.MoveEvent
Direction = player.Direction

shaders = require '../frp/shaders.js'

# combine events and their effects
manyConstEffects = (initial, effects) ->
    funcs = []
    for effect in effects
        [event, func] = effect
        funcs.push (event.constMap func)
    effects = frp.mergeAll funcs
    return (effects.accum initial, effects)

# returns the event returned by the callback when e triggers or the initial event
onEventDo = (e, initial, callback) ->
   eventEvent = e.map callback # event (event a)
   behaviorEvent = frp.hold initial, eventEvent # behavior (event a)
   event = frp.switchE behaviorEvent # event (a)
   return event

class DefaultBlock
    constructor: ->
        @texture = 'redboxblock'
        @touchEvent = new frp.EventStream
        @gid = 1

class TempBlock
    constructor: () ->
        @touchEvent = (new frp.EventStream()).once() # multiple sends would reset the countdown
        countdownFinishedEvent = onEventDo @touchEvent, frp.never, ((v) -> frp.mkCountdown 500)
        @removeMeEvent = countdownFinishedEvent.once().constMap true
        @texture = 'redboxblock'

class StoneBlock
    constructor: ->
        @texture = 'stoneblock'
        @touchEvent = new frp.EventStream
        @gid = 1

class DeathBlock
    constructor: ->
        @texture = 'deathblock'
        @touchEvent = new frp.EventStream

class WinBlock
    constructor: ->
        @texture = 'winblock'
        @touchEvent = new frp.EventStream

# hack
Phaser.TileSprite.prototype.kill = Phaser.Sprite.prototype.kill

class BlockManager
    constructor: (@game) ->
        @blocks = {}
        @block_group = game.add.group()
        @block_group.enableBody = true;
        @block_group.allowGravity = false;
        @block_group.immovable = true;

        @coll_group = game.add.group()
        @coll_group.enableBody = true;
        @coll_group.allowGravity = false;
        @coll_group.immovable = true;

        #@block_group.add @coll_group

        @blockSize = 50

    toWorldCoords: (x, y) ->
        return {x:x*@blockSize, y:y*@blockSize}

    fromWorldCoords: (x, y) ->
        x = Math.floor(x / @blockSize)
        y = Math.floor(y / @blockSize + 1)
        return {x:x, y:y}

    canAddBlock: (x, y) ->
        return false if @blocks.hasOwnProperty(y) && @blocks[y].hasOwnProperty x
        return true

    addBlock: (x, y, block) ->
        if not @canAddBlock x, y
            return

        if !@blocks.hasOwnProperty y
            @blocks[y] = {}
        @blocks[y][x] = block
        neighbors =
            left: if @blocks[y].hasOwnProperty (x-1) then @blocks[y][x-1] else null
            right: if @blocks[y].hasOwnProperty (x+1) then @blocks[y][x+1] else null
            top: if (@blocks.hasOwnProperty (y-1)) and @blocks[y-1].hasOwnProperty (x) then @blocks[y-1][x] else null
            bottom: if (@blocks.hasOwnProperty (y+1)) and @blocks[y+1].hasOwnProperty x then @blocks[y+1][x] else null

        block.x = x
        block.y = y

        coords = @toWorldCoords x, y

        setIndex = @game.map.tiles[block.gid][2];
        set = @game.map.tilesets[setIndex];

        block.sprite = @game.add.tileSprite (coords.x + set.tileOffset.x),
                (coords.y + set.tileOffset.y), set.tileWidth, set.tileHeight, "test", block.gid

        if neighbors.bottom != null
            if neighbors.bottom.hasOwnProperty 'main'
                neighbors.bottom = neighbors.bottom.main
            block.sprite = @block_group.add block.sprite
        #block.sprite.loadTexture block.texture, 1
            h = neighbors.bottom.sprite.body.height
            offset_y = neighbors.bottom.sprite.body.offset.y
            neighbors.bottom.sprite.body.setSize 50, (h + 50), 24, (offset_y - 50)
            block.main = neighbors.bottom
        else if neighbors.top != null
            if neighbors.top.hasOwnProperty 'main'
                neighbors.top = neighbors.top.main

            block.sprite = @block_group.add block.sprite
        #block.sprite.loadTexture block.texture, 1
            h = neighbors.top.sprite.body.height
            offset_y = neighbors.top.sprite.body.offset.y
            neighbors.top.sprite.body.setSize 50, (h + 50), 24, offset_y
            #neighbors.bottom.dbg.y -= 25
            #neighbors.top.dbg.scale.set 25, (h + 25)
            block.main = neighbors.top
        else
            block.sprite = @coll_group.add block.sprite
            w = 50
            h = 50
            xoff = 24
            yoff = 24
            #@game.physics.enable block.sprite, Phaser.Physics.ARCADE
            block.sprite.body.setSize w, h, xoff, yoff
            block.sprite.body.immovable = true
            block.sprite.block = block

            #dbg_block = @game.add.sprite (block.sprite.body.x + xoff), (block.sprite.body.y + yoff), "pixel"
            #dbg_block.scale.set w, h
            #dbg_block.shader = new shaders.TestFilter 255, 0, 0
            #block.dbg = dbg_block
            #@block_group.add dbg_block

    removeBlock: (x, y) ->
        if @blocks.hasOwnProperty(y) and @blocks[y].hasOwnProperty x
            block = @blocks[y][x]
            block.sprite.kill()
            delete @blocks[y][x]

    copy: (mgr) ->

    @mkBehaviors: (game) ->
        # command events
        addBlock = new frp.EventStream # addBlock {x:x, y:y, block: new Block()}
        removeBlock = new frp.EventStream

        effects = [
           addBlock.map ((blockInfo) -> (bm) ->
                block = blockInfo.block
                bm.addBlock blockInfo.x, blockInfo.y, block # FIXME test if block was added
                if block.removeMeEvent
                    block.removeMeEvent.listen ((v) -> removeBlock.send block)
                return bm
                )
           removeBlock.map ((block) -> (bm) ->
                bm.removeBlock (block.x), (block.y)
                return bm
                )
        ]

        bm = frp.accum (new BlockManager(game)), (frp.mergeAll effects).mkUpdateEvent()
        bm.addBlock = addBlock
        bm.removeBlock = removeBlock
        return bm

class Parallax
    constructor: ->

class Camera
    constructor: (@tick, @game, world) ->
        @game.camera.bounds = null
        
        world.players[0].position.updates().listen ((pos) =>
            distance = @game.camera.x - pos.x + @game.camera.view.width/2.0
            distance_y = @game.camera.y - pos.y + @game.camera.view.height/2.0
            if (Math.abs distance) > 200
                 if (distance > 0)
                    @game.camera.x = @game.camera.x + (-distance + 200)
                 else if distance < 0
                    @game.camera.x = @game.camera.x + (-distance - 200)
            if (Math.abs distance_y) > 200
                if distance_y < 0
                    @game.camera.y += (-distance_y - 200)
                else if distance_y > 0
                    @game.camera.y += (-distance_y + 200)
            )

        @shakeIt()

    shakeIt: ->
        @shakeMe = new frp.EventStream

        reset = new frp.EventStream
        effects = [
            reset.constMap (new frp.Behavior 0)
            @shakeMe.map ((v) =>
                timer = (frp.mkCountdown 300)
                counter = frp.accum 10, (@tick.map ((t) -> (a) -> a - t/10.0))
                rotation = counter.map ((v) -> (Math.sin v) / 16) # frp.hold 0 (@tick.map ((t) -> Math.sin t)) #frp.accum 0 effects
                timer.listen ((_) -> reset.send true)
                return rotation
            )
        ]
        rotating = frp.hold (new frp.Behavior 0), (frp.mergeAll effects)
        rotating = frp.switchBeh rotating
        rotating.updates().listen ((v) => @game.world.rotation = v)

class World
    constructor: (game) ->
        @tick = tick

        @makeFaster = new frp.EventStream()
        @makeSlower = new frp.EventStream()
        @mod = frp.accum 1, (frp.mergeAll [
            @makeFaster.constMap ((m) -> m * 2)
            @makeSlower.constMap ((m) -> m / 2)
            ])
    
        playerTick = @tick.snapshot @mod, ((t, mod) -> t * mod)
        @players = [
            new player.Player game, playerTick, "p1"
        #    new player.Player game, playerTick, "p2"
         #   new player.Player game, "p3"
        ]

        #@players[0].pushBox.addColliders.send (@players[1])
    
        @worldBlocks = BlockManager.mkBehaviors game
        @camera = new Camera tick, game, this
        @particles = new ParticleGroup game

        @trees = game.add.group();
        @tree = game.add.sprite 0, 500, 'trees'
        @tree.shader = new shaders.ColorFilter {x:1, y:1, z:1}
        #@tree.blendMode = PIXI.blendModes.ADD
        @trees_high = game.add.sprite 0, 500, 'trees_high'
        @trees_high.blendMode = PIXI.blendModes.ADD

        @trees_high.shader = new shaders.IntensityFilter 0, {x:1, y:1, z:0.8}

        tick.listen ((t) =>
            width = @trees_high.texture.width
            height = @trees_high.texture.height
            @trees_high.shader.uniforms.relPos.value.x = game.input.x - width/2.0 + game.camera.x;
            @trees_high.shader.uniforms.relPos.value.y = + 500 - game.input.y + height + game.camera.y
            @trees_high.shader.uniforms.color.value.x = 0.8 + 0.2*(game.input.x - width/2.0 + game.camera.x) / width
            @trees_high.shader.uniforms.color.value.y = (0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            @trees_high.shader.uniforms.color.value.z = 0.2*(0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            #@trees_high.shader.uniforms.color.value.y = 0.5 + (game.input.x - width/2.0 + game.camera.x) / width
            @trees_high.shader.dirty = true
            @tree.shader.uniforms.color.value.y = 0.9 + 0.1*(0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            @tree.shader.uniforms.color.value.z = 0.7 + 0.3*(0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            @tree.shader.dirty = true
            )

        @trees.add @tree
        @trees.add @trees_high

        for player in @players
            setting = player.blockSetter.blockSet.snapshotMany [player.position], ((ignore, pos) =>
                gridsize = 50;
                x = Math.floor(pos.x / gridsize)
                y = Math.floor(pos.y / gridsize + 1)
                @worldBlocks.addBlock.send {x:x, y:y, block: new DefaultBlock}
                )
            # side effects
            setting.listen ((v) -> )

            s = preTick.onTickDo @worldBlocks, (((player) => (blockManager) =>
                 game.physics.arcade.collide blockManager.coll_group, player.sprite, (sprite, group_sprite) =>
                    if group_sprite.body.touching.up == true
                        group_sprite.block.touchEvent.send true
                    if sprite.body.touching.down == true
                        player.landedOnBlock.send true

                    if sprite.body.touching.left == true 
                        player.touchedWall.send (-1)
                    if sprite.body.touching.right == true
                        player.touchedWall.send 1
                        
                 ) player)
            # side effects
            s.listen ((v) ->)

    save: ->
    reload: ->

class ParticleGroup
    constructor: (game) ->
        @group = game.add.group();

        for i in [0..50]
            innerGlow = new Phaser.Particle game, i, 200, 'pixel'
            outerGlow = new Phaser.Particle game, i, 200, 'pixel'

            accel = frp.hold {x:0, y:0}, (tick.map ((_) -> {x:200 * (Math.random() - 0.5), y:200*(Math.random() - 0.5)}))
            integrateAccel = tick.snapshot accel, ((t, a) ->
                t = t / 1000.0
                return (oldSpeed) -> {x : oldSpeed.x + a.x * t, y : oldSpeed.y + a.y * t}
                )

            speed = frp.accum {x:(Math.random()-0.5)*200, y:(Math.random()-0.5)*200}, integrateAccel

            integrate = tick.snapshot speed, ((t, v) ->
                t = t / 1000.0
                return (oldPos) -> {x: oldPos.x + v.x * t, y: oldPos.y + v.y * t}
                )

            position = frp.accum {x:200 * Math.random(), y:200*Math.random()}, integrate
            position.updates().listen ((test, test2) -> (pos) ->
                test.x = pos.x
                test.y = pos.y
                test2.x = pos.x - 1
                test2.y = pos.y - 1
                test2.scale.set (2 + (Math.random())*5), (2 + (Math.random())*5)
                ) innerGlow, outerGlow

            innerGlow.scale.set 2, 2
            outerGlow.scale.set 4, 4

            innerGlow.shader = new shaders.TestFilter 77, 233, 57
            outerGlow.shader = new shaders.TestFilter 200, 233, 57
            @group.add outerGlow
            @group.add innerGlow

module.exports.World = World
module.exports.MoveEvent = MoveEvent
module.exports.StopMoveEvent = StopMoveEvent
module.exports.Direction = Direction
module.exports.tick = tick
module.exports.preTick = preTick
module.exports.postTick = postTick

module.exports.DefaultBlock = DefaultBlock
module.exports.WinBlock = WinBlock
module.exports.StoneBlock = StoneBlock
module.exports.DeathBlock = DeathBlock
module.exports.TempBlock = TempBlock
