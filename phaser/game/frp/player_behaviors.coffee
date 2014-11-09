frp = require '../frp/frp.js'
shaders = require '../frp/shaders.js'

log = frp.log
preTick = frp.preTick
postTick = frp.postTick

BLOCKWIDTH = 50
BLOCKHEIGHT = 50

class Player
    constructor: (@tick, @name="p", @spriteKey="runner1") ->
        @moveEvent = new frp.EventStream "MoveEvent"
        @jumpEvent = new frp.EventStream "JumpEvent"
        @setBlockEvent = new frp.EventStream "SetBlockEvent"

        # from phaser
        @landedOnBlock = new frp.EventStream "LandedOnBlock"
        @touchedWall = new frp.EventStream "TouchedWall"

        @jumping = new Jumping @tick, this
        #startMovement = new Movement @tick, this

        @setMovementSystem = new frp.EventStream
        @movement = new Movement @tick, this
        # [@setMovementSystem, @movement] = frp.selector (startMovement.value), {
        #     'BaseMovement': (tick, _this) ->
        #             movement = new Movement tick, _this
        #             return movement.value
        # }, @tick, this
        #@blockSetter = new BlockSetter @tick, @setBlockEvent

        # position only to test discrepancies between phaser coordinates and behavior coordinates
        @setPosition = new frp.EventStream "SetPosition"

        int = @tick.snapshot @movement, ((t, v) -> t * v.x / 1000.0)
    
        effects = [
            @setPosition.map ((pos) -> (oldPos) -> pos)
            int.map ((dPos) -> (pos) ->
                    new Direction (pos.x + dPos), (pos.y))
        ]

        @position = frp.accum (new Direction 0, 0), (frp.mergeAll effects)


        last = {ref:null}
        last.ref = frp.hold false, (@jumpEvent.snapshot last, ((_, old) -> not old))

        @pushBox = new CollisionBox @tick, (last.ref.updates())
        follow this, @pushBox

        preTick.snapshotEffect @position, (_, pos) =>
            @pushBox.setPos.send [pos.x, pos.y]

class CollisionBox
    constructor: (@tick, 
            @setActive=new frp.EventStream("SetActive"),
            @addColliders=new frp.EventStream ("addColliders")) ->
        @setPos = new frp.EventStream "SetCollisionBoxPos"
        @startPush = new frp.EventStream "StartPush"

        # canStart blocks the @startPush event until the created behavior is done
        canStart = {ref:null}
        reallyStartPush = @startPush.gate canStart
        reallyStartPush = reallyStartPush.constMap @tick

        # the callback returns a behavior with a list of values
        pushs = frp.onEventMakeBehaviors [0, true], reallyStartPush, ((tick) ->
            [timeA, timeB] = frp.tickSplitTime tick, 1000
            [timeB, end] = frp.tickSplitTime timeB, 1000
            end = end.once()

            goRight = frp.integrate (timeA.times 2), 0, (frp.pure 100)
            goLeft = frp.integrate (timeB.times 2), 200, (frp.pure (-100))

            # three behaviors:
                # we start to move right
                # when timeB triggers we move left
                # reset on end
            final = frp.holdAll goRight, [
                timeB.once().constMap goLeft
                end.constMap (frp.pure 0)
                ]
            final = frp.switchB final
            return [
                final
                # when this behavior is finished we accept a new one
                frp.hold false, (end.constMap true)
                ]
            )

        # get the snd and fst element of the behavior
        canStart.ref = pushs.at 1 # Behavior [a] -> Behavior a
        @offset = pushs.at 0
        #@offset.updates().listen (log "Offset")

        @active = frp.hold false, @setActive
        @collidesWith = frp.accum [], (@addColliders.map ((c) -> (cs) ->
            cs.push c
            return cs
            ))

numObjects = (o) ->
    sum = 0
    for x of o
        sum += 1
    return sum

class Dash
    @mkBehavior: (tick, startDash, lookingDirection) ->
        endDash = frp.onEventMakeEvent startDash, (_) -> (frp.timer tick, 200)
        dashing = frp.holdAll false, [
            startDash.constMap true
            endDash.constMap false
            ]

        dashMod = (tick.gate dashing).snapshot lookingDirection,
            (dt, dir) -> (v) -> Vector.add v, (new Vector (dir*1500), 0)
        dashMod.dashing = dashing
        return dashMod

# TODO refactor
class Movement
    constructor: (@tick, @player) ->
        wantsMoveEvent = @player.moveEvent.filter ((e) -> e instanceof MoveEvent)
        wantsStopMoveEvent = @player.moveEvent.filter ((e) -> e instanceof StopMoveEvent)

        direction_Wanted = frp.hold Direction.null(), (wantsMoveEvent.map ((e) -> e))
        directionWanted = frp.hold Direction.null(), (wantsMoveEvent.map ((e) -> e.dir))
        @direction = directionWanted

        onGround = frp.onEventMakeBehavior false, player.landedOnBlock, (_) =>
            tick = frp.timer @tick, 20
            return frp.hold true, (tick.constMap false)

        inAir = onGround.not()

        wantsMove = frp.holdAll false, [
            wantsMoveEvent.constMap true
            wantsStopMoveEvent.constMap false
            ]

        moveAfterJump = (player.landedOnBlock.gate wantsMove).snapshot direction_Wanted, (_, dir) -> dir

        startMove = frp.merge wantsMoveEvent, moveAfterJump

        jumping = frp.holdAll false, [
            @player.jumpEvent.constMap true
            @player.landedOnBlock.constMap false
            inAir.updates()
        ]

        canStartMove = startMove.gate (jumping.not())
        currentDir = frp.hold Direction.null(), (canStartMove.map (e) -> e.dir)

        @speed = 300

        running = frp.holdAll false, [
            canStartMove.constMap true
            wantsStopMoveEvent.constMap false
            ]

        moving = frp.apply running, jumping, (bMov, bJump) ->
            bMov and (not bJump)
        
        playerJumping = @player.jumping
        velXmods = frp.mergeAll [
            canStartMove.map (dir) ->
                (oldV) -> dir.dir.x * 300
            playerJumping.value2.map ((v) -> (old) -> old + v.x)
            ]

        runForce = null #new Force @tick, frp.never, 0, 0

        modDrag = frp.hold ((dt) -> (v) -> v), (startMove.delay().snapshot currentDir, (wantsDir, curDir) -> 
            (dt) -> (v) ->
                if wantsDir.dir.x == curDir.x
                    return lowerCap (v - dt/1000.0), 0.1
                else if wantsDir.x == 0
                    return v
                else
                    upperCap (v + 5*dt/1000.0), 5
            )
        modDrag = @tick.snapshot modDrag, (dt, f) -> f dt

        dragMod = frp.accumAll 0.5, [
            @player.landedOnBlock.constMap (v) -> 0.5
            modDrag.map (f) -> (v) -> f v
            ]

        drag2 = frp.apply dragMod, jumping, ((mod, bJump) -> [bJump, mod])
        drag = frp.apply moving, drag2, (bMov, [bJump, jumpDrag]) ->
            if bMov
                0
            else if bJump
                jumpDrag
            else
                16
    
        vel = new Velocity @tick, velXmods, 1000, runForce, drag
        value = vel.map ((v) -> new Vector v, 0)

        resetVel = @player.landedOnBlock.map (v) ->
            (oldV) -> v

        jump = playerJumping.value.map ((v) -> (old) ->
            v)

        mods = frp.mergeAll [
            resetVel
            jump
            playerJumping.value2.map ((v) -> (old) -> v.y)
            ]
    
        gravTick = @tick #@tick.gate (dash.dashing.not())
        
        gravity = new Force gravTick, frp.never, 1050, 1050
        gravVel = new Velocity gravTick, mods, 2000, gravity
        fallV = frp.hold (Vector.null()), (gravVel.updates().map ((v) -> new Vector 0, v))


        @player.pushVel = {ref:null}
        @player.pullVel = {ref:null}

        @value = frp.apply value, fallV, (x, y) -> Vector.add x, y
        @value = frp.apply @value, @player.pushVel, (x, y) -> Vector.add x, y
        @value = frp.apply @value, @player.pullVel, (x, y) -> Vector.add x, y
        # FIXME
        @value.direction = @direction
        @value.startMove = startMove
        @value.stopMove = wantsStopMoveEvent
        return @value

lowerCap = (v, cap) -> if v < cap then return cap else v
upperCap = (v, cap) -> if v > cap then return cap else v

class BlockSetter
    constructor: (@tick, @setBlockEvent) ->
        blockSet = {ref:null} #new frp.EventStream
        
        blockpower = {ref:null}

        @MAXPOWER = 1000
        @BLOCKCOST = 200
        @MINPOWER = 0

        # we dont refill if we are full
        full = frp.mapB blockpower, (power) => power >= @MAXPOWER
        tick = @tick.gate (full.not())
        refill = tick.map ((t) => ((v) => upperCap (v + t), @MAXPOWER))

        # refill or remove power when setting
        blockpower.ref = frp.accumAll 0, [
            refill
            frp.constMap blockSet, ((v) => lowerCap (v - @BLOCKCOST), @MINPOWER)
        ]
        @blockpower = blockpower.ref

        @canSetBlock = @blockpower.map ((v) => v > @BLOCKCOST)
        doSetBlock = @setBlockEvent.gate @canSetBlock

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

        t = 1
        @JUMPFORCE = (-200/t + -1050 * t / 2)
        @MAX_JUMPS = 1

        @jumpsSinceLand = frp.accum 0, (frp.mergeAll [
                (@player.jumpEvent.constMap frp.inc)
                (@player.landedOnBlock.constMap (frp.constant 0))
        ])

        wallJumpStarters = frp.mergeAll [
            @player.touchedWall
        ]

        dir = frp.hold 0, wallJumpStarters

        canWallJump = frp.onEventMakeBehavior false, wallJumpStarters, ((_) =>
            end = frp.timer @tick, 64
            return frp.hold true, (end.constMap false)
            )

        @canJump = @jumpsSinceLand.map ((jumps) => jumps <= @MAX_JUMPS)
        canWallJump2 = @jumpsSinceLand.map ((jumps) => jumps <= (@MAX_JUMPS + 1))

        @value = (jumpStarters.delay().constMap @JUMPFORCE).gate @canJump
        @value = @value.gate (canWallJump.not())

        wallJumpVel = dir.map ((x) => new Vector (x*-400), @JUMPFORCE)
        @value2 = jumpStarters.delay().gate canWallJump2
        @value2 = @value2.gate (@jumpsSinceLand.map ((jumps) -> jumps >= 1))
        @value2 = @value2.gate canWallJump
        @value2 = @value2.snapshot wallJumpVel, frp.second

class Vector
    constructor: (@x, @y) ->
    @null: () -> new Vector 0, 0
    length: () -> Math.sqrt (@x*@x + @y*@y)
    @add = (v1, v2) -> new Vector (v1.x + v2.x), (v1.y + v2.y)
    @diff = (v1, v2) -> new Vector (v1.x - v2.x), (v1.y - v2.y)
    @scalar = (t, v) -> new Vector (t*v.x), (t*v.y)
    dir: -> return Vector.scalar (1/@length()), this

class Force
    constructor: (@tick, modForce, initial, accelCap, x=0) ->
        intForce = {ref:null}
        forceChangers = (frp.mergeAll [
            modForce
            frp.mapE (frp.updates intForce), ((v) -> (_) -> v)
            ])
        forceChangers = forceChangers.map ((f) -> (a) ->
            a = f(a)
            if a < -accelCap then return -accelCap
            if a > accelCap then return accelCap
            return a
            )
        accel = frp.accum initial, forceChangers
        if x == 0
            intForce.ref = frp.pure 0
        else
            intForce.ref = frp.integrateB @tick, accel, frp.pure x
        return accel

class Velocity
    constructor: (@tick, modVelocity, velocityCap, accel=null, drag=null) ->
        intForce = {ref:null}
        forceChangers = (frp.mergeAll [
            modVelocity
            frp.mapE (frp.updates intForce), ((v) -> (_) -> v)
            ])
        forceChangers = forceChangers.map ((f) -> (a) ->
                a = f(a)
                if a < -velocityCap then return -velocityCap
                if a > velocityCap then return velocityCap
                return a
            )
        velocity = frp.accum 0, forceChangers
        if accel == null
            intForce.ref = frp.hold 0, (frp.updates velocity)
        else
            intForce.ref = frp.integrateB @tick, velocity, accel

        if drag != null
            intForce.ref = frp.snapshot @tick, intForce.ref, ((dt, v) -> [v, dt])
            intForce.ref = frp.hold 0, (frp.snapshot intForce.ref, drag, (([v, dt], drag) ->
                v*(1 - drag*dt/1000.0)))
        return velocity

pullStrength = 3
class Pull
    constructor: (@tick, @player1, @player2, @startPush) ->
        charge = frp.onEventMakeEvent @startPush, (_) =>
            return (frp.tickEvery @tick, 500).once()

        distanceOnCharge = charge.snapshotMany [@player1.position, @player2.position], (_, p1, p2) ->
            console.log p1, p2
            return (Vector.diff p1, p2)

        distance = frp.hold Vector.null(), distanceOnCharge
        #direction = distance.map ((dist) -> dist.dir())

        pushDuration = frp.onEventMakeEvent charge, => frp.tickFor @tick, 500
        pushEnd = frp.onEventMakeEvent charge, => (frp.tickEvery @tick, 500).once()

        pushVel = frp.hold (Vector.null()), (frp.mergeAll [
            pushDuration.snapshot distance, ((_, dist) ->
                Vector.scalar (pullStrength*dist.length()), (dist.dir()))
            pushEnd.constMap (Vector.null())
            ])

        pushVel.updates().listen (log ("PUSH"))

        return pushVel

class Push
    constructor: (@tick, @player1, @player2, @startPush) ->
        charge = frp.onEventMakeEvent @startPush, (_) =>
            return (frp.tickEvery @tick, 500).once()

        distanceOnCharge = charge.snapshotMany [@player1.position, @player2.position], (_, p1, p2) ->
            return (Vector.diff p1, p2)

        distance = frp.hold Vector.null(), distanceOnCharge
        #direction = distance.map ((dist) -> dist.dir())

        pushDuration = frp.onEventMakeEvent charge, => frp.tickFor @tick, 500
        pushEnd = frp.onEventMakeEvent charge, => (frp.tickEvery @tick, 500).once()

        pushVel = frp.hold (Vector.null()), (frp.mergeAll [
            pushDuration.snapshot distance, ((_, dist) -> Vector.scalar (-pullStrength*dist.length()), (dist.dir()))
            pushEnd.constMap (Vector.null())
            ])

        return pushVel

follow = (@base, @follower) ->
    @follower.movement = @base.movement

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

    scalar: (k) -> new Vector (@x*k), (@y*k)

    times: (vector) ->
        c = @copy()
        c.x *= vector.x
        c.y *= vector.y
        return new Vector c.x, c.y

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
    Push: Push
    Pull: Pull
    Vector: Vector
    BlockSetter:BlockSetter
