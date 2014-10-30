frp = require '../frp/behavior.js'

inc = (x) -> (x + 1)
dec = (x) -> (x - 1)

tick = new frp.EventStream
# a tick for phaser systems that need to be executed at first (e.g. collision)
preTick = new frp.EventStream

# returns an event that triggers once after 'initial' milliseconds
mkCountdown = (initial) ->
    counter = frp.accum initial, (tick.map ((v) -> ((a) -> a - v)))
    finished = counter.updates().filter ((v) -> v < 0)
    return (finished.constMap true).once()

class Movement

# combine events and their effects
manyConstEffects = (initial, effects) ->
    funcs = []
    for effect in effects
        [event, func] = effect
        funcs.push (event.constMap func)
    effects = frp.mergeAll funcs
    return (effects.accum initial, effects)

manyEffects = (initial, effects) ->
    funcs = []
    for effect in effects
        [event, func] = effect
        funcs.push (event.map func)
    effects = frp.mergeAll funcs
    return (effects.accum initial, effects)

# returns the event returned by the callback when e triggers or the initial event
onEventDo = (e, initial, callback) ->
   eventEvent = e.map callback # event (event a)
   behaviorEvent = frp.hold initial, eventEvent # behavior (event a)
   event = frp.switchE behaviorEvent # event (a)
   return event

# return a function returning a constant
constant = (x) -> ((a) -> x)

log = (t) -> ((v) -> console.log t, v)

class StopMoveEvent
    constructor: ->
        @dir = new Direction 0, 0
class MoveEvent
    constructor: (x, y) ->
        @dir = new Direction x, y

class DefaultBlock
    constructor: ->
        @texture = 'redboxblock'
        @touchEvent = new frp.EventStream
        @gid = 1

class TempBlock
    constructor: () ->
        @touchEvent = (new frp.EventStream()).once() # multiple sends would reset the countdown
        countdownFinishedEvent = onEventDo @touchEvent, frp.never, ((v) -> mkCountdown 500)
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

        @blockSize = 25

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
        block.x = x
        block.y = y

        coords = @toWorldCoords x, y

        setIndex = @game.map.tiles[block.gid][2];
        set = @game.map.tilesets[setIndex];

        block.sprite = @game.add.tileSprite (coords.x + set.tileOffset.x),
                (coords.y + set.tileOffset.y), set.tileWidth, set.tileHeight, "test", block.gid
        block.sprite = @block_group.add block.sprite
        #block.sprite.loadTexture block.texture, 1
        block.sprite.body.immovable = true
        block.sprite.body.setSize 25, 25, 12, 12
        block.sprite.block = block

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

        bm = frp.accum (new BlockManager(game)), frp.mergeAll effects
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
                if distance > 0
                    @game.camera.y += (-distance_y - 200)
                else if distance < 0
                    @game.camera.y += (-distance_y + 200)
            )

        @shakeIt()

    shakeIt: ->
        @shakeMe = new frp.EventStream

        # effects = [
        #     @tick.map ((t) -> (a) ->
        # ]


        reset = new frp.EventStream
        effects = [
            reset.constMap (new frp.Behavior 0)
            @shakeMe.map ((v) =>
                timer = (mkCountdown 300)
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
        @players = [
            new Player game, "p1"
            new Player game, "p2"
            new Player game, "p3"
        ]
        @worldBlocks = BlockManager.mkBehaviors game
        @camera = new Camera tick, game, this
        @particles = new ParticleGroup game

        @trees = game.add.group();
        trees = game.add.sprite 0, 500, 'trees'
        @trees_high = game.add.sprite 0, 500, 'trees_high'
        @trees_high.blendMode = PIXI.blendModes.ADD

        @trees_high.shader = new IntensityFilter 0

        tick.listen ((t) =>
            width = @trees_high.texture.width
            height = @trees_high.texture.height
            @trees_high.shader.uniforms.relPos.value.x = game.input.x - width/2.0 + game.camera.x;
            @trees_high.shader.uniforms.relPos.value.y = + 500 - game.input.y + height + game.camera.y
            @trees_high.shader.dirty = true
            )

        @trees.add trees
        @trees.add @trees_high

        for player in @players
           player.blockSetter.blockSet.snapshotMany [player.position], ((ignore, pos) =>
                gridsize = 25;
                x = Math.floor(pos.x / gridsize)
                y = Math.floor(pos.y / gridsize + 1)
                @worldBlocks.addBlock.send {x:x, y:y, block: new DefaultBlock}
                )

           preTick.onTickDo @worldBlocks, (((player) => (blockManager) =>
                game.physics.arcade.collide blockManager.block_group, player.sprite, (sprite, group_sprite) =>
                    group_sprite.block.touchEvent.send true
                    player.landedOnBlock.send true
                ) player)

    save: ->
    reload: ->

class TestFilter extends PIXI.AbstractFilter
    constructor: (r, g, b) ->
        PIXI.AbstractFilter.call this
        this.uniforms =
            color:
                type: '3f'
                value: {x:r/255.0, y:g/255.0, z:b/255.0}
        @fragmentSrc = [
            'precision mediump float;'
            'uniform vec3 color;'
            'void main () {'
            '   gl_FragColor = vec4(color, 1);'
            '}'
        ] 

class IntensityFilter extends PIXI.AbstractFilter
    constructor: (intensity) ->
        PIXI.AbstractFilter.call this
        this.uniforms =
            intensity:
                type: '1f'
                value: intensity
            relPos:
                type: '2f'
                value: {x:0, y:0}
        @fragmentSrc = [
                'precision mediump float;'
                'varying vec2 vTextureCoord;'
                'varying vec4 vColor;'
                'uniform sampler2D uSampler;'
                'uniform vec2 relPos;'
                'uniform float intensity;'
                'void main(void) {'
                '    float angle = atan(relPos.y, relPos.x);'
                '    vec4 color = texture2D(uSampler, vTextureCoord);' 
                '    float sprAngle = (color.r)*3.14;'
                '    float newIntensity = abs(angle - sprAngle)/3.14;'
                '    gl_FragColor = vec4(1, 1, 0.8, color.a*newIntensity);'
                '}'
            ]

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

            innerGlow.shader = new TestFilter 77, 233, 57
            outerGlow.shader = new TestFilter 200, 233, 57
            @group.add outerGlow
            @group.add innerGlow

class Player
    constructor: (game, @name="p") ->
        @moveEvent = new frp.EventStream
        @jumpEvent = new frp.EventStream
        @setBlockEvent = new frp.EventStream

        # from phaser
        @landedOnBlock = new frp.EventStream

        startMovement = new Movement tick, this

        [@setMovementSystem, @movement] = selector (startMovement.value), {
            'BaseMovement': (tick, _this) ->
                    movement = new Movement tick, _this
                    return movement.value
            'OtherMovement': (tick, _this) ->
                    movement = new Movement2 tick, _this
                    return movement.value
        }, tick, this
        @jumping = new Jumping tick, this
        @blockSetter = new BlockSetter tick, this

        # position only to test discrepancies between phaser coordinates and behavior coordinates
        setPosition = new frp.EventStream
        effects = [
            [setPosition, (pos) -> (oldPos) -> pos]
            [(tick.snapshot @movement, ((t, v) -> t * v.vx / 1000.0)), (dPos) -> (pos) ->
                    new Direction (pos.x + dPos), (pos.y)]
        ]

        @position = manyEffects (new Direction 0, 0), effects
        @setPosition = (x, y) -> setPosition.send x, y

        @sprite = game.add.sprite 100, 200, 'runner'
        #@sprite.shader = new TestFilter 200, 0, 0
        game.physics.enable @sprite, Phaser.Physics.ARCADE
        @sprite.body.collideWorldBounds = true
        @sprite.body.setSize 7, 28, 3, 0
        @sprite.body.gravity.y = 1050
        @sprite.allowGravity = true

        @jumping.value.listen ((vy) => @sprite.body.velocity.y -= vy)

        t = tick.onTickDo (@movement), ((speed) => @sprite.body.velocity.x = speed.vx)

# TODO splats for arbitary number of arguments
selector = (initial, choices, arg1, arg2) ->
    setter = new frp.EventStream
    choice = setter.map ((e) -> choices[e](arg1, arg2)) # Event (Behavior)

    # frp.hold initial, choice # Behavior (Behavior)
    selected = frp.switchBeh (frp.hold initial, choice) # Behavior
    return [setter, selected]

class Speed
    constructor: (@vx, @vy) ->

    copy: () =>
        new Speed(@vx, @vy)

    @null: -> new Speed 0, 0

class Direction
    constructor: (x, y) ->
        ## TODO: normalize
        @x = x
        @y = y

    copy: () =>
        new Direction(@x, @y)

    times: (vector) ->
        c = @copy()
        c.x *= vector.vx
        c.y *= vector.vy
        return new Speed c.x, c.y

    @null: -> new Direction 0, 0

second = (a, b) -> b

# event that represents the value of the behavior on tick
tick.onTick = (beh) => tick.snapshot beh, second
preTick.onTick = (beh) => preTick.snapshot beh, second
tick.onTickDo = (beh, callback) => tick.snapshot beh, ((t, behValue) -> callback behValue)
preTick.onTickDo = (beh, callback) => preTick.snapshot beh, ((t, behValue) -> callback behValue)

class Movement2
    constructor: (@tick, @player) ->
        @MAXSPEED = 1000
        @BASESPEED = 200

        @isMoving = frp.hold false, (@player.moveEvent.map ((e) ->
                if e instanceof StopMoveEvent then false else true))
        @movingDirection = frp.hold Direction.null(), (@player.moveEvent.map ((e) -> e.dir))

        startedMoving = @isMoving.updates().filter ((v) -> v == true)
        stoppedMoving = @isMoving.updates().filter ((v) -> v == false)

        effects = [
            [startedMoving, (oldBehavior) =>
                    frp.accum @BASESPEED, @tick.map ((t) => ((speed) => upperCap (t/4.0 + speed), @MAXSPEED))]
        ]

        speed = frp.switchBeh (manyConstEffects (new frp.Behavior 0), effects)
        @speed = speed.map ((speed) -> new Speed speed, 0)
        @value = (@movingDirection.apply @speed, ((dir, speed) -> dir.times speed))

class Movement
    constructor: (@tick, @player) ->
        @MAXSPEED = new Speed 300, 0
        @BASESPEED = new Speed 300, 0

        stopMove = @player.moveEvent.filter ((e) -> e instanceof StopMoveEvent)
        startMove = @player.moveEvent.filter ((e) -> e instanceof MoveEvent)

        setAccel = new frp.EventStream
        setFriction = new frp.EventStream
        modFriction = new frp.EventStream
        setVelocity = new frp.EventStream
        setPosition = new frp.EventStream

        frictionEffects = frp.mergeAll [
            setFriction.map ((newF) -> (oldF) -> newF)
            modFriction
        ]
        
        friction = frp.accum 0.1, frictionEffects

        aEffects = frp.mergeAll [
           setAccel.map ((newA) -> (oldA) -> newA)
        ]

        accel = frp.accum 0, aEffects

        velEffects = frp.mergeAll [
            @tick.snapshot accel, ((t, a) -> (v) -> v + a * t / 1000.0)
            @tick.snapshot friction, ((t, friction) -> (oldV) -> oldV - oldV * friction)
            setVelocity.map ((newV) -> (oldV) -> newV)
        ]

        baseVelocity = frp.accum 0, velEffects
        velocity = baseVelocity.map ((v) -> upperCap v, 100)

        posEffects = frp.mergeAll [
            @tick.snapshot velocity, ((t, v) -> (s) -> s + v * t / 1000.0)
            setPosition.map ((newPos) -> (oldPos) -> newPos)
        ]
        x = frp.accum 0, posEffects
        x.updates().listen (log "X")
        velocity.listen (log "vel")

        @direction = frp.hold Direction.null(), (startMove.map ((e) -> e.dir))

        startMove.listen ((_) =>
            stopMoveOccured = frp.hold false, (stopMove.constMap true)
                
            timer = (mkCountdown 200).gate (stopMoveOccured.not())

            accelEnds = frp.mergeAll [
                timer.constMap 0
                stopMove.constMap 0
            ]
            accel = frp.hold (1000), accelEnds

            frictionEnd = onEventDo stopMove, never, ((e) ->
                startMoveOccured = frp.hold false, (startMove.constMap true)
                return (mkCountdown 300).gate (startMoveOccured.not())
                )

            frictionEffects = frp.mergeAll [
                timer.constMap ((v) -> 0)
                stopMove.constMap ((v) -> 0.01)
                frictionEnd.constMap ((v) -> 0.1)
            ]
            frictionEnd.listen (log "Friction end")

            friction = frp.hold ((v) -> (v)), frictionEffects
            accel.values().listen ((v) -> setAccel.send v)
            friction.updates().listen ((f) -> modFriction.send f)
            )
        stopMove.listen (log "Stopmove")
        startMove.listen (log "Startmove")
        friction.listen (log "Friction")

        v2 = velocity.map ((x) -> return (new Speed x, 0))
        v2 = frp.apply v2, @direction, ((v, dir) -> dir.times v)
        @value = v2 #(@movingDirection.map ((dir) => dir.times @BASESPEED))

lowerCap = (v, cap) -> if v < cap then return cap else v
upperCap = (v, cap) -> if v > cap then return cap else v

class BlockSetter
    constructor: (@tick, @player) ->
        @blockSet = new frp.EventStream

        @MAXPOWER = 1000
        @BLOCKCOST = 50
        @MINPOWER = 0


        setFull = new frp.EventStream
        full = frp.hold false, setFull

        refill = @tick.gate (full.not())
        refill = refill.map ((t) => ((v) => upperCap (v + t), @MAXPOWER))

        effects = [
                refill
                @blockSet.constMap ((v) => lowerCap (v - @BLOCKCOST), @MINPOWER)
        ]

        @blockpower = frp.accum 0, (frp.mergeAll effects)
        @canSetBlock = @blockpower.map ((v) => v > @BLOCKCOST)
        isFull = @blockpower.map ((v) => v >= @MAXPOWER)
        isFull.updates().onTrue(->setFull.send true)
        @blockSet.onTrue(->setFull.send false)

        doSetBlock = @player.setBlockEvent.gate @canSetBlock
        doSetBlock.listen ((v) => @blockSet.send true)

class Jumping
    constructor: (@tick, @player) ->
        jumpResets = frp.mergeAll [
            @player.landedOnBlock
        ]

        jumpStarters = frp.mergeAll [
            @player.jumpEvent
        ]

        @JUMPFORCE = 300
        @MAX_JUMPS = 3


        @jumpsSinceLand = frp.accum 0, (frp.mergeAll [
                (@player.jumpEvent.constMap inc)
                (@player.landedOnBlock.constMap (constant 0))
        ])

        @canJump = @jumpsSinceLand.map ((jumps) => jumps < @MAX_JUMPS - 1)

        @value = (jumpStarters.constMap @JUMPFORCE).gate @canJump

b = new frp.Behavior 0

event = new frp.EventStream

behavior = frp.accum 0, event
behavior2 = behavior.map ((v) -> v - 1)
event.send ((v) -> v + 1)
event.send ((v) -> v + 2)

behavior2.updates().listen (log "Behavior2 updated with")
frp.system.sync()

module.exports.World = World
module.exports.MoveEvent = MoveEvent
module.exports.StopMoveEvent = StopMoveEvent
module.exports.Direction = Direction
module.exports.tick = tick
module.exports.preTick = preTick

module.exports.DefaultBlock = DefaultBlock
module.exports.WinBlock = WinBlock
module.exports.StoneBlock = StoneBlock
module.exports.DeathBlock = DeathBlock
module.exports.TempBlock = TempBlock
