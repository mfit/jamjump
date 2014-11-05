frp = require '../frp/frp.js'
shaders = require '../frp/shaders.js'

log = frp.log
preTick = frp.preTick
postTick = frp.postTick

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
        @blockSetter = new BlockSetter @tick, @setBlockEvent

        # position only to test discrepancies between phaser coordinates and behavior coordinates
        @setPosition = new frp.EventStream "SetPosition"

        int = @tick.snapshot @movement, ((t, v) -> t * v.vx / 1000.0)
    
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
        startMove = @player.moveEvent.filter ((e) -> e instanceof MoveEvent)
        stopMove = @player.moveEvent.filter ((e) -> e instanceof StopMoveEvent)

        direction = frp.hold Direction.null(), (startMove.map ((e) -> e.dir))
        @direction = direction
        
        modVelocity1 = frp.onEventMakeEvent startMove, ((direction) =>
            localTick = frp.tickUntilEvent @tick, stopMove.once()
            v = 100 * direction.dir.x
            velocity = frp.hold (new Vector v, 0), (localTick.constMap (new Vector v, 0))
            return velocity.values()
            )

        dirAtStopMove = frp.snapshot stopMove, direction, frp.second
        modVelocity2 = frp.onEventMakeEvent dirAtStopMove, ((direction) =>
            deaccelTime = 50
            [localTick3, lastTick] = frp.tickSplitTime @tick, deaccelTime
            lastTick = lastTick.once()

            velocity2 = frp.integrate localTick3, 1, (frp.pure -33)
            velocity2 = velocity2.map (v) -> new Vector (lowerCap v, 0), 0

            return frp.mergeAll [
                velocity2.values()
                lastTick.constMap Vector.null()
                ]
            )

        modVelocity1 = modVelocity1.map (fv) -> (old) ->
            fv.x
        modVelocity2 = modVelocity2.map (fv) -> (old) ->
            fv.x
        value_x = new Velocity @tick, (frp.merge modVelocity1, modVelocity2), 300, null, (frp.pure 0.9)
        value = frp.hold (Vector.null()), (value_x.updates().map ((v) -> new Vector v, 0))

        sndPress = frp.onEventMakeBehavior false, startMove, ((_) ->
            return frp.hold true, ((frp.tickEvery tick, 100).once().constMap false)
            )
        startDash = startMove.gate sndPress
        dash = Dash.mkBehavior @tick, startDash, (direction.map ((dir) -> dir.x))


        standing = frp.onEventMakeBehavior false, @player.landedOnBlock, ((_) =>
            end = frp.timer preTick, 64
            return frp.hold true, (end.constMap false)
            )

        resetVel = standing.updates().filterTrue().map ((standing) -> return (oldV) -> 0)

        jumping = @player.jumping
        jump = jumping.value.map ((v) -> (old) ->
            old + v)

        wallJump1 = jumping.value2.map ((v) -> (_) ->
            v.x)
        wallJump2 = jumping.value2.map ((v) ->
            (_) -> v.y)

        mods = frp.merge resetVel, jump
    
        gravTick = @tick.gate (dash.dashing.not())
        
        gravity = new Force gravTick, frp.never, 1050, 1050
        gravVel = new Velocity gravTick, mods, 1050, gravity
        fallV = frp.hold (Vector.null()), (gravVel.updates().map ((v) -> new Vector 0, v))

        wallJumpGrav = new Velocity gravTick, (frp.merge wallJump2, resetVel), 1050, gravity
        wallJumpFrac = new Velocity @tick, wallJump1, 1050, null, (frp.pure 0.9)
        wallJump = frp.hold (Vector.null()), (frp.mergeAll [
            wallJumpGrav.updates().map ((v) -> new Vector 0, v)
            wallJumpFrac.updates().map ((v) -> new Vector v, 0)
            ])

        @player.pushVel = {ref:null}
        @player.pullVel = {ref:null}

        @value = frp.accum (Vector.null()), (frp.mergeAll [
            preTick.constMap (frp.constant (Vector.null()))
            value.updates().map ((v) -> (old) -> Vector.add old, v)
            fallV.updates().map ((v) -> (old) -> Vector.add old, v)
            wallJump.updates().map ((v) -> (old) -> Vector.add old, v)
            frp.mapE (frp.updates @player.pushVel), ((v) ->
                (old) -> Vector.add old, v)
            frp.mapE (frp.updates @player.pullVel), ((v) ->
                (old) -> Vector.add old, v)
            dash
            ])
        # FIXME
        @value.direction = @direction
        @value.startMove = startMove
        @value.stopMove = stopMove
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

        @JUMPFORCE = -800
        @MAX_JUMPS = 3

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

        @canJump = @jumpsSinceLand.map ((jumps) => jumps < @MAX_JUMPS)

        @value = (jumpStarters.constMap @JUMPFORCE).gate @canJump
        @value = @value.gate (canWallJump.not())

        wallJumpVel = dir.map ((x) -> new Vector (x*-1200), -800)
        @value2 = jumpStarters.gate @canJump
        @value2 = @value2.gate (@jumpsSinceLand.map ((jumps) -> jumps > 1))
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
                v*(drag*(1 - dt/1000.0))))
        return velocity

pullStrength = 3
class Pull
    constructor: (@tick, @player1, @player2, @startPush) ->
        charge = frp.onEventMakeEvent @startPush, (_) =>
            return (frp.tickEvery @tick, 500).once()

        distanceOnCharge = charge.snapshotMany [@player1.position, @player2.position], (_, p1, p2) ->
            return (Vector.diff p1, p2)

        distance = frp.hold Vector.null(), distanceOnCharge
        #direction = distance.map ((dist) -> dist.dir())

        pushDuration = frp.onEventMakeEvent charge, => frp.tickFor @tick, 500
        pushEnd = frp.onEventMakeEvent charge, => (frp.tickEvery @tick, 500).once()

        pushVel = frp.hold 0, (frp.mergeAll [
            pushDuration.snapshot distance, ((_, dist) -> Vector.scalar (pullStrength*dist.length()), (dist.dir()))
            pushEnd.constMap (Vector.null())
            ])

        distance.updates().listen (log "Distance")
        pushDuration.listen (log "push duration")
        pushEnd.listen (log "Push end")
    
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

        pushVel = frp.hold 0, (frp.mergeAll [
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
