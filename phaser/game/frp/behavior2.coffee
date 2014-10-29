frp = require '../frp/behavior.js'

inc = (x) -> (x + 1)
dec = (x) -> (x - 1)

tick = new frp.EventStream
# a tick for phaser systems that need to be executed at first (e.g. collision)
preTick = new frp.EventStream

mkCountdown = (initial) ->
    counter = frp.accum initial, (tick.map ((v) -> ((a) -> a - v))) 
    finished = counter.updates().filter ((v) -> v < 0)
    return finished.constMap true

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

onEventDo = (e, callback) ->
   eventEvent = e.map callback
   behaviorEvent = frp.hold frp.never, eventEvent
   event = frp.switchE behaviorEvent
   return event

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

class TempBlock
    constructor: (touchEvent) ->
        countdownFinishedEvent = onEventDo touchEvent, ((v) -> mkCountdown 1000)
        @removeMeEvent = countdownFinishedEvent.once().constMap true

class StoneBlock
    constructor: ->

class DeathBlock
    constructor: (touchEvent) ->

class BlockManager
    constructor: (game) ->
        @blocks = {}
        @block_group = game.add.group()
        @block_group.enableBody = true;
        @block_group.allowGravity = false;
        @block_group.immovable = true;

        @blockSize = 19

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
        block.sprite = @block_group.create coords.x, coords.y
        block.sprite.loadTexture 'redboxblock', 1
        block.sprite.body.immovable = true
        block.sprite.body.setSize 20, 20, 2, 2

    removeBlock: (x, y) ->
        if @blocks.hasOwnProperty(y) and @blocks[y].hasOwnProperty x
            @blocks[y][x].sprite.kill()
            delete @blocks[y][x]
        
    copy: (mgr) ->

    @mkBehaviors: (game) ->
        # command events
        addBlock = new frp.EventStream
        removeBlock = new frp.EventStream

        # command executed events
        addedBlock = new frp.EventStream
        removedBlock = new frp.EventStream

        effects = [
           addBlock.map ((blockInfo) -> (bm) ->
                block = blockInfo.block
                bm.addBlock blockInfo.x, blockInfo.y, block
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

        bm.addedBlock = addBlock
        return bm

class World
    constructor: (game) ->
        @players = [new Player game] #, new Player game]
        @worldBlocks = BlockManager.mkBehaviors game

        for y in [20..20]
            for x in [0..20]
                @worldBlocks.addBlock.send
                    x:x
                    y:y
                    block:new TempBlock frp.never

        console.log "tick", tick
        preTick.onTickDo @worldBlocks, ((blockManager) =>
            game.physics.arcade.collide blockManager.block_group, @players[0].sprite, (sprite, group_sprite) =>
                @players[0].landedOnBlock.send true
                console.log "Collision"
            )

class Player
    constructor: (game) ->
        @moveEvent = new frp.EventStream
        @jumpEvent = new frp.EventStream
        @stopJumpEvent = new frp.EventStream
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
        game.physics.enable @sprite, Phaser.Physics.ARCADE
        @sprite.body.collideWorldBounds = true
        @sprite.body.setSize 14, 14, 2, 10
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
        # @BASESPEED = 300
        # @baseSpeed = new frp.Behavior (new Speed @BASESPEED, 0)
        # @totalSpeed = @baseSpeed
        # @movingDirection = frp.hold Direction.null(), (@player.moveEvent.map ((e) ->
        #         e.dir))
        # @value = @tick.onTick (@movingDirection.apply @totalSpeed, ((dir, speed) -> dir.times speed))
        @BASESPEED = new Speed 300, 0
        @movingDirection = frp.hold Direction.null(), (@player.moveEvent.map ((e) ->
            e.dir))
            
        @value = (@movingDirection.map ((dir) => dir.times @BASESPEED))

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

        @JUMPFORCE = 200
        @MAX_JUMPS = 3

        @jumpsSinceLand = frp.accum 0, (frp.mergeAll [
                (@player.jumpEvent.constMap inc)
                (@player.landedOnBlock.constMap (constant 0))
        ])
        
        @canJump = @jumpsSinceLand.map ((jumps) => jumps < @MAX_JUMPS)

        @value = (jumpStarters.constMap @JUMPFORCE).gate @canJump

b = new frp.Behavior 0

event = new frp.EventStream
        
behavior = frp.accum 0, event
behavior2 = behavior.map ((v) -> v - 1)
event.send ((v) -> v + 1)
event.send ((v) -> v + 2)
console.log (behavior.current_value)
console.log (behavior2.current_value)

behavior2.updates().listen (log "Behavior2 updated with")
frp.system.sync()

module.exports.World = World
module.exports.MoveEvent = MoveEvent
module.exports.StopMoveEvent = StopMoveEvent
module.exports.Direction = Direction
module.exports.tick = tick
module.exports.preTick = preTick
