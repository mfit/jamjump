frp = require '../frp/behavior.js'

inc = (x) -> (x + 1)
dec = (x) -> (x - 1)

tick = new frp.EventStream
mkCountdown = (initial) -> frp.accum initial, (tick.map ((v) -> ((a) -> a - v))) 

class Movement
        
manyEffects = (initial, effects) ->
    funcs = []
    for effect in effects
        [event, func] = effect
        funcs.push (event.constMap func)
    effects = frp.mergeAll funcs
    return (effects.accum initial, effects)

constant = (x) -> ((a) -> x)

log = (t) -> ((v) -> console.log t, v)

class StopMoveEvent
    constructor: ->
        @dir = new Direction 0, 0
class MoveEvent
    constructor: (x, y) ->
        @dir = new Direction x, y

class Player
    constructor: ->
        @moveEvent = new frp.EventStream
        @jumpEvent = new frp.EventStream
        @stopJumpEvent = new frp.EventStream
        @landedOnBlock = new frp.EventStream
        @setBlockEvent = new frp.EventStream

        startMovement = new Movement tick, this

        [@setMovementSystem, @movement] = selector (startMovement.value), {
            'BaseMovement': (tick, _this) ->
                    movement = new Movement tick, _this
                    return movement.value
            'OtherMovement': (tick, _this) ->
                    movement = new Movement2 tick, _this
                    return movement.value
        }, tick, this
        @movement2 = new Movement2 tick, this
        @jumping = new Jumping tick, this
        @blockSetter = new BlockSetter tick, this

# TODO splats for arbitary number of arguments
selector = (initial, choices, arg1, arg2) ->
    setter = new frp.EventStream 
    choice = setter.map ((e) -> choices[e](arg1, arg2))

    selected = frp.switchE (frp.hold initial, choice)
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
tick.onTick = (beh) => @tick.snapshot beh, second

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

        speed = frp.switchBeh (manyEffects (new frp.Behavior 0), effects)
        @speed = speed.map ((speed) -> new Speed speed, 0)
        @value = @tick.onTick (@movingDirection.apply @speed, ((dir, speed) -> dir.times speed)) 
        
class Movement
    constructor: (@tick, @player) ->
        # @BASESPEED = 300
        # @baseSpeed = new frp.Behavior (new Speed @BASESPEED, 0)
        # @totalSpeed = @baseSpeed
        # @movingDirection = frp.hold Direction.null(), (@player.moveEvent.map ((e) ->
        #         e.dir))
        # @value = @tick.onTick (@movingDirection.apply @totalSpeed, ((dir, speed) -> dir.times speed))
        @BASESPEED = new Speed 300, 0
        @movingDirection = frp.hold Direction.null(), (@player.moveEvent.map ((e) ->
            e.dir))
            
        @value = @tick.onTick (@movingDirection.map ((dir) => dir.times @BASESPEED))

lowerCap = (v, cap) -> if v < cap then return cap else v
upperCap = (v, cap) -> if v > cap then return cap else v

class BlockSetter
    constructor: (@tick, @player) ->
        @blockSet = new frp.EventStream

        @MAXPOWER = 1000
        @BLOCKCOST = 300
        @MINPOWER = 0

        effects = [
                @tick.map ((t) => ((v) => upperCap (v + t), @MAXPOWER))
                @blockSet.constMap ((v) => lowerCap (v - @BLOCKCOST), @MINPOWER)
        ]

        @blockpower = frp.accum 0, (frp.mergeAll effects)
        @canSetBlock = @blockpower.map ((v) => v > @BLOCKCOST)

        doSetBlock = @player.setBlockEvent.gate @canSetBlock
        doSetBlock.listen ((v) => @blockSet.send true)

class Jumping
    constructor: (@tick, @player) ->
        jumpResets = frp.mergeAll [
            @player.landedOnBlock
            @player.stopJumpEvent
        ]

        jumpStarters = frp.mergeAll [
            @player.jumpEvent
        ]

        @JUMPFORCE = 300

        @jumpsSinceLand = frp.accum 0, (frp.mergeAll [
                (@player.jumpEvent.constMap inc)
                (@player.landedOnBlock.constMap (constant 0))
        ])
        
        @canJump = @jumpsSinceLand.map ((jumps) -> jumps <= 2)

        @value = (jumpStarters.constMap @JUMPFORCE).gate @canJump

module.exports.Player = Player
module.exports.MoveEvent = MoveEvent
module.exports.StopMoveEvent = StopMoveEvent
module.exports.tick = tick
