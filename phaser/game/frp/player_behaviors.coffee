frp = require '../frp/frp.js'
shaders = require '../frp/shaders.js'

log = frp.log
tick = frp.tick

class Player
    constructor: (game, @name="p") ->
        @moveEvent = new frp.EventStream
        @jumpEvent = new frp.EventStream
        @setBlockEvent = new frp.EventStream

        # from phaser
        @landedOnBlock = new frp.EventStream

        startMovement = new Movement tick, this

        [@setMovementSystem, @movement] = frp.selector (startMovement.value), {
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

        int = tick.snapshot @movement, ((t, v) -> t * v.vx / 1000.0)
    
        effects = [
            setPosition.map ((pos) -> (oldPos) -> pos)
            int.map ((dPos) -> (pos) ->
                    new Direction (pos.x + dPos), (pos.y))
        ]

        @position = frp.accum (new Direction 0, 0), (frp.mergeAll effects)
        @setPosition = (x, y) -> setPosition.send x, y

        @sprite = game.add.sprite 100, 200, 'runner'
        #@sprite.shader = new TestFilter 200, 0, 0
        game.physics.enable @sprite, Phaser.Physics.ARCADE
        @sprite.body.collideWorldBounds = true
        @sprite.body.setSize 7, 28, 3, 0
        @sprite.body.gravity.y = 1050
        @sprite.allowGravity = true

        last = {ref:null}
        last.ref = frp.hold false, (@jumpEvent.snapshot last, ((_, old) -> not old))
        last.ref.updates().listen (log "reF")

        @pushBox = new CollisionBox game, this, (last.ref.updates())
        follow this, @pushBox

        @jumping.value.listen ((vy) =>
            @sprite.body.velocity.y -= vy)

        t = tick.snapshotMany [@movement, @pushBox.position], ((t, speed, boxSpeed) =>
            @sprite.body.velocity.x = speed.vx
            @pushBox.sprite.body.x = boxSpeed.x
            @pushBox.sprite.body.y = boxSpeed.y
            )
        t.listen ((v) ->)

class CollisionBox
    constructor: (game, @owner, @setActive) ->
        @sprite = game.add.sprite 100, 200, 'pixel'
        @sprite.scale.set 10, 10
        @sprite.shader = new shaders.TestFilter 0, 0, 0
        game.physics.enable @sprite, Phaser.Physics.ARCADE
        @sprite.body.collideWorldBounds = false

        @active = frp.hold false, @setActive
        @active.updates().listen ((active) => @sprite.shader.uniforms.color.value.x = active)

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

        # speed = frp.switchBeh (manyConstEffects (new frp.Behavior 0), effects)
        # @speed = speed.map ((speed) -> new Speed speed, 0)
        # @value = (@movingDirection.apply @speed, ((dir, speed) -> dir.times speed))
        @value = pure (new Speed 0, 0)

class Movement
    constructor: (@tick, @player) ->
        @MAXSPEED = new Speed 300, 0
        @BASESPEED = new Speed 300, 0

        startMove = @player.moveEvent.filter ((e) -> e instanceof MoveEvent)

        @setVelocity = new frp.EventStream()
        modVelocity = {ref:null}
    
        velEffects = frp.mergeAll [
            @setVelocity
            frp.mapE modVelocity, ((v) -> (a) -> v)
        ]

        baseVelocity = frp.accum 0, velEffects
        velocity = baseVelocity.map ((v) -> upperCap v, 300)
        @direction = frp.hold Direction.null(), (startMove.map ((e) -> e.dir))

        modVelocity.ref = frp.execute (startMove.constMap ((_) =>
            stopMove = @player.moveEvent.filter ((e) ->
               return e instanceof StopMoveEvent)
            stopMoveOccured = frp.hold false, (stopMove.constMap true).once()
            timer = (frp.mkCountdown 200).gate (stopMoveOccured.not())

            localTick = tick.gate (stopMoveOccured.not())

            initialAccel = frp.accum 200, (localTick.map ((t) -> (a) -> lowerCap (a - t), 0))
            accel = initialAccel.values().map ((a) -> (old) -> a + old)
            accel = accel.gate (stopMoveOccured.not())

            effects = [
                accel
                stopMove.constMap ((a) -> 0)
            ]
        
            velocity = frp.updates (frp.accum 0, (frp.mergeAll effects))
    
            return velocity
            ))
        modVelocity.ref = frp.switchE (frp.hold frp.never, modVelocity.ref)

        v2 = velocity.map ((x) -> return (new Speed x, 0))
        v2 = frp.apply v2, @direction, ((v, dir) -> dir.times v)
        @value = v2 #(@movingDirection.map ((dir) => dir.times @BASESPEED))

lowerCap = (v, cap) -> if v < cap then return cap else v
upperCap = (v, cap) -> if v > cap then return cap else v

class BlockSetter
    constructor: (@tick, @player) ->
        blockSet = {ref:null} #new frp.EventStream

        @MAXPOWER = 1000
        @BLOCKCOST = 200
        @MINPOWER = 0

        refill = @tick.map ((t) => ((v) => upperCap (v + t), @MAXPOWER))

        effects = [
                refill
                frp.constMap blockSet, ((v) => lowerCap (v - @BLOCKCOST), @MINPOWER)
        ]

        @blockpower = frp.accum 0, (frp.mergeAll effects)
        @canSetBlock = @blockpower.map ((v) => v > @BLOCKCOST)
        #full.ref = @blockpower.map ((v) => v >= @MAXPOWER)

        doSetBlock = @player.setBlockEvent.gate @canSetBlock

        blockSet.ref = doSetBlock.constMap true
        @blockSet = blockSet.ref

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
                (@player.jumpEvent.constMap frp.inc)
                (@player.landedOnBlock.constMap (frp.constantFunc 0))
        ])


        @canJump = @jumpsSinceLand.map ((jumps) => jumps < @MAX_JUMPS)

        @value = (jumpStarters.constMap @JUMPFORCE).gate @canJump

follow = (@base, @follower) ->
    @follower.position = @base.position

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

class StopMoveEvent
    constructor: ->
        @dir = new Direction 0, 0
class MoveEvent
    constructor: (x, y) ->
        @dir = new Direction x, y

module.exports =
    Player : Player
    Direction:Direction
    StopMoveEvent:StopMoveEvent
    MoveEvent:MoveEvent
