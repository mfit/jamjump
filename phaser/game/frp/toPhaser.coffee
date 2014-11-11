render = require '../render/render.js'
frp = require '../frp/frp.js'
cfgFrp = require '../frp/frp_settings.js'
log = frp.log
tick = frp.tick
preTick = frp.preTick
postTick = frp.postTick

shaders = require '../frp/shaders.js'
render = require '../render/render.js'

# hack
Phaser.TileSprite.prototype.kill = Phaser.Sprite.prototype.kill

setup = (@game, world) ->
    setupCamera @game, world, world.camera
    setupTrees @game, world
    world.particles = new ParticleGroup game
    setupBlockManager game, world

    for player in world.players
        setupPlayer player, @game, world
        s = (player) =>
            preTick.onTickDo world.worldBlocks, (((blockManager) =>
                game.physics.arcade.collide blockManager.coll_group, player.sprite, (sprite, group_sprite) =>
                    if group_sprite.body.touching.up == true
                        group_sprite.block.touchEvent.send true
                    if sprite.body.touching.down == true
                        player.landedOnBlock.send (sprite.body.velocity.y - sprite.body.newVelocity.y)

                    if sprite.body.touching.left == true
                        player.touchedWall.send (-1)
                    if sprite.body.touching.right == true
                        player.touchedWall.send 1
                ) )
        # side effects
        #(s player).listen ((v) ->)

setupCamera = (@game, world, camera) ->
    @game.camera.bounds = null

    zoneX = 200
    zoneY = 100

    @camPos = {x:@game.camera.x, y:@game.camera.y}

    world.players[0].position.updates().listen ((pos) =>
        distance = @camPos.x - pos.x + @game.camera.view.width/2.0
        distance_y = @camPos.y - pos.y + @game.camera.view.height/2.0
        if (Math.abs distance) > zoneX
             if (distance > 0)
                @camPos.x = @camPos.x + (-distance + zoneX)
             else if distance < 0
                @camPos.x = @camPos.x + (-distance - zoneX)
        if (Math.abs distance_y) > zoneY
            if distance_y < 0
                @camPos.y += (-distance_y - zoneY)
            else if distance_y > 0
                @camPos.y += (-distance_y + zoneY)

        @game.camera.x = @camPos.x + @offset
        @game.camera.y = @camPos.y + @offset
        )

    @offset = 0
    # SHAKIN
    camera.rotating.updates().listen (v) =>
        @offset = v
        @game.camera.x = @camPos.x + @offset

setupTrees = (game, world) ->
    # background
    world.bgimage = game.add.sprite 0, 500, 'trees'
    world.bgimage.scale.x = 20
    world.bgimage.scale.y = 20
    world.bgimage.x = 0
    world.bgimage.y = 0
    world.bgimage.alpha = 0.5

    world.trees = game.add.group();
    world.tree = game.add.sprite 0, 500, 'trees'

    world.tree.shader = new shaders.ColorFilter {x:1, y:1, z:1}
    #world.tree.blendMode = PIXI.blendModes.ADD
    world.trees_high = game.add.sprite 0, 500, 'trees_high'
    world.trees_high.blendMode = PIXI.blendModes.ADD

    world.trees_high.shader = new shaders.IntensityFilter 0, {x:1, y:1, z:0.8}

    world.goaltree = game.add.sprite 0, 0, 'treelarge1'


    world.trees.add world.tree
    world.trees.add world.trees_high
    world.trees.add world.goaltree

    x = new cfgFrp.ConfigBehavior "tree_x", 9000
    y = new cfgFrp.ConfigBehavior "tree_y", 2250

    x.updates().listen (x) ->
        world.goaltree.x = x
    y.updates().listen (y) ->
        world.goaltree.y = y

    world.tick.listen ((t) =>
            width = world.trees_high.texture.width
            height = world.trees_high.texture.height
            world.trees_high.shader.uniforms.relPos.value.x = game.input.x - width/2.0 + game.camera.x;
            world.trees_high.shader.uniforms.relPos.value.y = + 500 - game.input.y + height + game.camera.y
            world.trees_high.shader.uniforms.color.value.x = 0.8 + 0.2*(game.input.x - width/2.0 + game.camera.x) / width
            world.trees_high.shader.uniforms.color.value.y = (0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            world.trees_high.shader.uniforms.color.value.z = 0.2*(0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            #@trees_high.shader.uniforms.color.value.y = 0.5 + (game.input.x - width/2.0 + game.camera.x) / width
            world.trees_high.shader.dirty = true
            world.tree.shader.uniforms.color.value.y = 0.9 + 0.1*(0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            world.tree.shader.uniforms.color.value.z = 0.7 + 0.3*(0.5 + (game.input.x - width/2.0 + game.camera.x) / width)
            world.tree.shader.dirty = true
            )

setupBlockManager = (game, world) ->
    # a hack. but we use references so this works :/
    bm = world.worldBlocks.value()

    bm.coll_group = game.add.group()
    bm.coll_group.enableBody = true;
    bm.coll_group.allowGravity = false;
    bm.coll_group.immovable = true;
    bm.coll_group.invisible = true;

    bm.block_group = game.add.group()#new render.BlockSpriteBatch @game

    world.worldBlocks.addedBlock.listen (blockInfo) ->
        x = blockInfo.x
        y = blockInfo.y
        block = blockInfo.block

        coords = bm.toWorldCoords x, y

        neighbors =
           left: if bm.blocks[y].hasOwnProperty (x-1) then bm.blocks[y][x-1] else null
           right: if bm.blocks[y].hasOwnProperty (x+1) then bm.blocks[y][x+1] else null
           top: if (bm.blocks.hasOwnProperty (y-1)) and bm.blocks[y-1].hasOwnProperty (x) then bm.blocks[y-1][x] else null
           bottom: if (bm.blocks.hasOwnProperty (y+1)) and bm.blocks[y+1].hasOwnProperty x then bm.blocks[y+1][x] else null

        setIndex = game.map.tiles[block.gid][2];
        set = game.map.tilesets[setIndex];

        gid = (Math.floor (Math.random()*3))

        block.sprite = game.add.tileSprite (coords.x + set.tileOffset.x),
                (coords.y + set.tileOffset.y), set.tileWidth, set.tileHeight, "test", gid
        bm.block_group.addChild block.sprite

        if neighbors.bottom != null
            if neighbors.bottom.hasOwnProperty 'main'
                neighbors.bottom = neighbors.bottom.main

            h = neighbors.bottom.sprite2.body.height
            offset_y = neighbors.bottom.sprite2.body.offset.y
            neighbors.bottom.sprite2.body.setSize 50, (h + 50), 24, (offset_y - 50)
            block.main = neighbors.bottom
        else if neighbors.top != null
            if neighbors.top.hasOwnProperty 'main'
                neighbors.top = neighbors.top.main

            h = neighbors.top.sprite2.body.height
            offset_y = neighbors.top.sprite2.body.offset.y
            neighbors.top.sprite2.body.setSize 50, (h + 50), 24, offset_y
            block.main = neighbors.top
        else
            block.sprite2 = game.add.sprite (coords.x + set.tileOffset.x), (coords.y + set.tileOffset.y)
            bm.coll_group.add block.sprite2
            w = 50
            h = 50
            xoff = 24
            yoff = 24

            block.sprite2.body.setSize w, h, xoff, yoff
            block.sprite2.body.immovable = true
            block.sprite.block = block
            block.sprite2.block = block


class ParticleGroup
    constructor: (game) ->
        @group = game.add.group();
        @group1 = new render.ColorSpriteBatch game,
            {r:210/255.0, g:105/255.0, b:30/255.0, a:1}
        @group2 = new render.ColorSpriteBatch game,
            {r:205/255.0, g:133/255.0, b:63/255.0, a:1}

        @group.add @group1
        @group.add @group2
        # gl = @group1.fastSpriteBatch.gl

        inners = []
        outers = []
        for i in [0..1]
            innerGlow = new Phaser.Particle game, i, 200, 'pixel'
            outerGlow = new Phaser.Particle game, i, 200, 'pixel'
            inners.push innerGlow
            outers.push outerGlow

            innerGlow.scale.set 2, 2
            outerGlow.scale.set 4, 4

            inners[i].speed = {x:(Math.random()-0.5)*200, y:(Math.random()-0.5)*200}
            inners[i].pos = {x:(Math.random()-0.5)*200, y:(Math.random()-0.5)*200}
            outers[i].s = Math.random() * 3.14
            outers[i].s2 = Math.random() * 3.14

            @group1.addChild outerGlow
            @group2.addChild innerGlow
        @inners = inners
        @outers = outers

        tick.listen ((dt_) ->
            dt = dt_/1000.0
            for _, i in inners
                a = {x:200 * (Math.random() - 0.5), y:200 * (Math.random() - 0.5)}
                integrateSpeed = (oldSpeed) -> {x: oldSpeed.x + a.x*dt, y: oldSpeed.y + a.y*dt}
                inners[i].speed = integrateSpeed inners[i].speed
                v = inners[i].speed
                integratePos = (oldPos) -> {x: oldPos.x + v.x * dt, y: oldPos.y + v.y*dt}
                inners[i].pos = integratePos inners[i].pos

                inners[i].x = inners[i].pos.x
                inners[i].y = inners[i].pos.y
                outers[i].x = inners[i].pos.x - 1
                outers[i].y = inners[i].pos.y - 2
                outers[i].s += dt*10
                outers[i].s2 += dt*8
                outers[i].scale.set (2 + (Math.sin(outers[i].s))*5), (2 + (Math.sin(outers[i].s2))*5)
            )

playerBodyRight1 = (player) ->#[14, 78, 23, 2])
        player.sprite.body.setSize 14, 78, -25, 2
playerBodyLeft1 = (player) ->#[14, 78, 58-23-14, 2]
        player.sprite.body.setSize 14, 78, 23, 2

playerBodyRight2 = (player) ->#[14, 78, 23, 2])
        player.sprite.body.setSize 14, 56, -25, 10
playerBodyLeft2 = (player) ->#[14, 78, 58-23-14, 2]
        player.sprite.body.setSize 14, 56, 23, 10

setupPlayer = (player, game, world) ->
    player.sprite = game.add.sprite 100, 200, player.spriteKey
    #player.sprite.shader = new shaders.TestFilter 1, 0, 0, 0.5
    player.sprite.animations.add 'walk'
    player.sprite.behavior = this
    player.sprite.scale.set (-1), 1
    player.oldDir = -1
    #player.sprite.shader = new TestFilter 200, 0, 0
    game.physics.enable player.sprite, Phaser.Physics.ARCADE, true
    player.sprite.body.collideWorldBounds = true
    if player.spriteKey == 'runner1'
        playerBodyRight1 player
    else
        playerBodyRight2 player

    #setupCollisionBox (player.pushBox)

    setupMovement player, player.movement

    t = postTick.snapshotMany [player.movement, world.worldBlocks], (t, speed, blockManager) =>
        player.sprite.body.velocity.x = speed.x
        player.sprite.body.velocity.y = speed.y

        game.time.physicsElapsed = t/1000.0
        player.sprite.body.preUpdate()

        game.physics.arcade.collide blockManager.coll_group, player.sprite, (sprite, group_sprite) =>
            if group_sprite.body.touching.up == true
                group_sprite.block.touchEvent.send true
            if sprite.body.touching.down == true
                player.landedOnBlock.send (sprite.body.velocity.y - sprite.body.newVelocity.y)

            if sprite.body.touching.left == true
                player.touchedWall.send (-1)
            if sprite.body.touching.right == true
                player.touchedWall.send 1

        player.sprite.body.postUpdate()

    t2 = postTick.delay().snapshotMany [player.movement, player.pushBox.movement], (t, speed, boxSpeed) =>
        player.sprite.body.velocity.x = 0
        player.sprite.body.velocity.y = 0
    t.listen ((v) ->)
    t2.listen ((v) ->)

setupMovement = (player, movement) ->
    movement.walkAnim = WalkAnimation.mkBehavior player, tick,
        movement.startMove, movement.stopMove
        player.jumpEvent, movement.turningPoint, movement.landedOnBlockOnce
    movement.direction.updates().listen ((dir) =>
        player.sprite.scale.set (-dir.x), 1
        if ((-dir.x) == 1) and ((-dir.x) != player.oldDir)
            player.oldDir = (-dir.x)
            if player.spriteKey == 'runner1'
                player.sprite.x -= 58
                playerBodyLeft1 player
            else
                player.sprite.x -= 58
                playerBodyLeft2 player
        else if ((-dir.x) == -1) and ((-dir.x) != player.oldDir)
            player.oldDir = (-dir.x)
            if player.spriteKey == 'runner1'
                player.sprite.x += 58
                playerBodyRight1 player
            else
                player.sprite.x += 58
                playerBodyRight2 player
        )

setupCollisionBox = (box) ->
    # ENDPOINT
    box.setPos.snapshotEffect box.offset, (([x, y], offset) =>
        box.sprite.body.x = x + offset
        box.sprite.body.y = y
    )

    box.sprite = game.add.sprite 100, 200, 'pixel'
    box.sprite.scale.set 20, 20
    box.sprite.shader = new shaders.TestFilter 1, 1, 0, 0.9
    game.physics.enable box.sprite, Phaser.Physics.ARCADE
    box.sprite.body.collideWorldBounds = false
    #box.sprite.body.setSize 7, 28, 3, 0
    box.sprite.body.gravity.y = 1050
    box.sprite.allowGravity = false#true

    box.active.updates().listen ((active) =>
        box.sprite.shader.uniforms.color.value.x = 1
        )

    doCollision = preTick.gate box.active
    doCollision.snapshotEffect box.collidesWith, ((_, colliders) =>
        for collider in colliders
            game.physics.arcade.collide collider.sprite, box.sprite, (otherSprite, sprite) =>
                if otherSprite.hasOwnProperty 'touchEvent'
                    otherSprite.touchEvent.send sprite
        )

class WalkAnimation
    constructor: (@player) ->
        frames = @player.sprite.animations.totalFrames
        @player.sprite.animations.loop = true
        @running = false
        @advance = false
        @jumpingUp = false
        @falling = false

        @msPerFrame = 80
        @leftover = 0

    tick: (dt) ->
        # FIXME remove me when animations for 2nd player exist
        run_startfrm = 0
        run_frmslen = 12

        if @leftover + dt > @msPerFrame
            if (@advance == false) and (@player.sprite.animations.currentFrame.index == 4)
                @player.sprite.animations.frame = 12
                @running = false
                console.log this
                @leftover = 0
                return

            if (@advance == false) and (@player.sprite.animations.currentFrame.index == 10)
                @player.sprite.animations.frame = 12
                @running = false
                @leftover = 0
                return

            if @running
                @player.sprite.animations.frame = run_startfrm + ((@player.sprite.animations.currentFrame.index - run_startfrm + 1) % run_frmslen)

            if @jumpingUp == true
                console.log "jumping", @player.sprite.animations.currentFrame.index
                if @player.sprite.animations.currentFrame.index == 13
                    @player.sprite.animations.frame = 14
                else
                    @player.sprite.animations.frame = 13
            else if @falling == true
                console.log "falling", @player.sprite.animations.currentFrame.index
                if @player.sprite.animations.currentFrame.index == 15
                    @player.sprite.animations.frame = 16
                else
                    @player.sprite.animations.frame = 15
            @leftover = @leftover - @msPerFrame

        @leftover += dt

    startRun: () ->
        @player.sprite.animations.frame = 9
        @advance = true
        @running = true

    startJump: () ->
        @player.sprite.animations.frame = 13
        @jumpingUp = true
        @running = false
        @advance = false

    fall: () ->
        @player.sprite.animations.frame = 15
        @jumpingUp = false
        @falling = true

    land: () ->
        @player.sprite.animations.frame = 12
        @falling = false
        @jumpingUp = false

    stopRun: () ->
        @advance = false

    isRunning: -> @running
    doAnim: -> @running || @falling || @jumpingUp

    @mkBehavior: (player, tick, startMove, stopMove, startJump, reachedTurningPoint, landed) ->
        # we only need to step the animation when it is running
        anim = {ref:null}
        isRunning = frp.mapB anim, ((anim) -> anim.isRunning())
        doAnim = frp.mapB anim, ((anim) -> anim.doAnim())
        tickWhenRunning = tick.gate doAnim

        startMove = startMove.gate (isRunning.not())

        anim.ref = frp.accumAll (new WalkAnimation player), [
            startMove.constMap (anim) ->
                anim.startRun()
                return anim
            stopMove.constMap (anim) ->
                anim.stopRun()
                return anim
            startJump.constMap (anim) ->
                anim.startJump()
                return anim
            reachedTurningPoint.constMap (anim) ->
                anim.fall()
                return anim
            landed.constMap (anim) ->
                anim.land()
                return anim
            tickWhenRunning.map (dt) -> (anim) ->
                anim.tick dt
                return anim
            ]
        return anim.ref


module.exports =
    setup:setup
