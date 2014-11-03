frp = require '../frp/frp.js'
shaders = require '../frp/shaders.js'

log = frp.log
preTick = frp.preTick
postTick = frp.postTick

class Player
    constructor: (game, @tick, @name="p", spriteKey="runner1") ->
        @sprite = game.add.sprite 100, 200, spriteKey
        @sprite.animations.add 'walk'
        @sprite.behavior = this
        @sprite.scale.set -1, 1
        #@sprite.shader = new TestFilter 200, 0, 0
        game.physics.enable @sprite, Phaser.Physics.ARCADE, true
        @sprite.body.collideWorldBounds = true
        if spriteKey == 'runner1'
            @sprite.body.setSize 14, 78, 23, 2
        else
            @sprite.body.setSize 14, 56, 23, 10

        @dbg = game.add.sprite (100 + 10), (200 + 10), 'pixel'
        @dbg.scale.set 14, 56
        @dbg.shader = new shaders.TestFilter 1, 0, 0

        
        @moveEvent = new frp.EventStream "MoveEvent"
        @jumpEvent = new frp.EventStream "JumpEvent"
        @setBlockEvent = new frp.EventStream "SetBlockEvent"

        # from phaser
        @landedOnBlock = new frp.EventStream "LandedOnBlock"
        @touchedWall = new frp.EventStream "TouchedWall"

        @jumping = new Jumping @tick, this
        startMovement = new Movement @tick, this

        [@setMovementSystem, @movement] = frp.selector (startMovement.value), {
            'BaseMovement': (tick, _this) ->
                    movement = new Movement tick, _this
                    return movement.value
        }, @tick, this
        @blockSetter = new BlockSetter @tick, this

        # position only to test discrepancies between phaser coordinates and behavior coordinates
        setPosition = new frp.EventStream "SetPosition"

        int = @tick.snapshot @movement, ((t, v) -> t * v.vx / 1000.0)
    
        effects = [
            setPosition.map ((pos) -> (oldPos) -> pos)
            int.map ((dPos) -> (pos) ->
                    new Direction (pos.x + dPos), (pos.y))
        ]

        @position = frp.accum (new Direction 0, 0), (frp.mergeAll effects)
        @setPosition = (x, y) -> setPosition.send x, y


        @position.updates().listen ((pos) =>
            @dbg.x = pos.x
            @dbg.y = pos.y
            )
        #@sprite.body.gravity.y = 1050
        #@sprite.allowGravity = true

        last = {ref:null}
        last.ref = frp.hold false, (@jumpEvent.snapshot last, ((_, old) -> not old))

        @pushBox = new CollisionBox game, @tick, this, (last.ref.updates())
        follow this, @pushBox

        preTick.snapshotEffect @movement, ((_, m) =>
            @pushBox.setPos.send [@sprite.body.x, @sprite.body.y]
            )
        # @jumping.value2.listen ((speed) =>
        #     console.log "walljump", speed
        #     @sprite.body.velocity.x += speed.x
        #     @sprite.body.velocity.y += speed.y
        #     )

        # @jumping.value.listen ((vy) =>
        #     @sprite.body.velocity.y -= vy
        #     #@pushBox.sprite.body.velocity.y -= vy0ebb
        #     )

        t = postTick.snapshotMany [@movement, @pushBox.movement], ((t, speed, boxSpeed) =>
            @sprite.body.velocity.x = speed.x
            @sprite.body.velocity.y = speed.y
            #@pushBox.sprite.body.velocity.x = speed.vx
            )
        t.listen ((v) ->)

class CollisionBox
    constructor: (game, @tick, @owner,
            @setActive=new frp.EventStream("SetActive"),
            @addColliders=new frp.EventStream ("addColliders")) ->
        @setPos = new frp.EventStream "SetCollisionBoxPos"

        @startPush = new frp.EventStream "StartPush"

        # on start push event fires for 1000ms
        canStart = {ref:null}
        reallyStartPush = @startPush.gate canStart
        reallyStartPush = reallyStartPush.constMap @tick

        pushs = frp.onEventMakeBehaviors [0, true], reallyStartPush, ((tick) ->
            time = frp.tickFor tick, 1000
            time2 = frp.tickAfter tick, 1000
            time2 = frp.tickFor time2, 1000
            end = (frp.tickAfter tick, 2000).once()

            b = frp.hold false, (end.constMap true)

            goRight = frp.integrate (time.times 2), 0, (frp.pure 100)
            goLeft = frp.integrate (time2.times 2), 200, (frp.pure (-100))

            effects = [
                time2.once().constMap goLeft
                end.constMap (frp.pure 0)
            ]
            final = frp.hold goRight, (frp.mergeAll effects)
            final = frp.switchB final
            return [
                final
                b
                ]
            )
        canStart.ref = pushs.at 1
        @offset = pushs.at 0
        #@offset.updates().listen (log "Offset")

        @setPos.snapshotEffect @offset, (([x, y], offset) =>
            @sprite.body.x = x + offset

            @sprite.body.y = y
        )

        @sprite = game.add.sprite 100, 200, 'pixel'
        @sprite.scale.set 20, 20
        @sprite.shader = new shaders.TestFilter 0, 0, 0, 0.2
        game.physics.enable @sprite, Phaser.Physics.ARCADE
        @sprite.body.collideWorldBounds = false
        #@sprite.body.setSize 7, 28, 3, 0
        @sprite.body.gravity.y = 1050
        @sprite.allowGravity = false#true

        @active = frp.hold false, @setActive
        @active.updates().listen ((active) =>
            @sprite.shader.uniforms.color.value.x = active
            )

        @collidesWith = frp.accum [], (@addColliders.map ((c) -> (cs) ->
            cs.push c
            return cs
            ))

        doCollision = preTick.gate @active
        doCollision.snapshotEffect @collidesWith, ((_, colliders) =>
            for collider in colliders
                game.physics.arcade.collide collider.sprite, @sprite, (otherSprite, sprite) =>
                    if otherSprite.hasOwnProperty 'touchEvent'
                        otherSprite.touchEvent.send sprite
            )

numObjects = (o) ->
    sum = 0
    for x of o
        sum += 1
    return sum

class WalkAnimation
    constructor: (@player) ->
        frames = @player.sprite.animations.totalFrames
        @player.sprite.animations.loop = true
        @running = false
        @advance = false

        @msPerFrame = 50
        @leftover = 0

    tick: (dt) ->
        if @leftover + dt > @msPerFrame
            if (@advance == false) and (@player.sprite.animations.currentFrame.index == 3)
                @player.sprite.animations.frame = 4
                @running = false
                @leftover = 0
                return

            if (@advance == false) and (@player.sprite.animations.currentFrame.index == 7)
                @player.sprite.animations.frame = 0
                @running = false
                @leftover = 0
                return

            if @player.sprite.animations.currentFrame.index == 7
                @player.sprite.animations.frame = 0
            else
                @player.sprite.animations.frame = @player.sprite.animations.currentFrame.index + 1
            @leftover = @leftover - @msPerFrame

        @leftover += dt

    startRun: () ->
        @advance = true
        @running = true

    stopRun: () ->
        @advance = false

    isRunning: -> @running

    @mkBehavior: (player, tick, startMove, stopMove) ->
        anim = {ref:null}
        r = frp.mapB anim, ((anim) -> anim.isRunning())
        tickWhenRunning = tick.gate r
        tickWhenRunning.listen (log "tickwalk")
        effects = [
            startMove.constMap ((anim) ->
                anim.startRun()
                return anim
                )
            stopMove.constMap ((anim) ->
                anim.stopRun()
                return anim
                )
            tickWhenRunning.map ((dt) -> (anim) ->
                console.log dt, anim
                anim.tick dt
                return anim
                )
        ]
        anim.ref = frp.accum (new WalkAnimation player), (frp.mergeAll effects)
        return anim.ref

class Dash
    @mkBehavior: (tick, startDash, lookingDirection) ->
        endDash = frp.onEventMakeEvent startDash, ((_) ->
            return (frp.tickEvery tick, 200).once()
            )

        dashing = frp.hold false, (frp.mergeAll [
            startDash.constMap true
            endDash.constMap false
            ])

        dashMod = (tick.gate dashing).snapshot lookingDirection, ((dt, dir) -> (v) -> Vector.add v, (new Vector (dir*1500), 0))
        dashMod.dashing = dashing
        return dashMod

class Movement
    constructor: (@tick, @player) ->
        @MAXSPEED = new Speed 300, 0
        @BASESPEED = new Speed 300, 0

        startMove = @player.moveEvent.filter ((e) -> e instanceof MoveEvent)
        stopMove = @player.moveEvent.filter ((e) -> e instanceof StopMoveEvent)

        direction = frp.hold Direction.null(), (startMove.map ((e) -> e.dir))
        direction.updates().listen ((dir) =>
            @player.sprite.scale.set (-dir.x), 1
            )

        walkAnim = WalkAnimation.mkBehavior @player, @tick, startMove, stopMove
        walkAnim.updates().listen (log "test")

        modVelocity1 = frp.onEventMakeEvent startMove, ((direction) =>
            localTick = frp.tickUntilEvent @tick, stopMove.once()
            # accel = frp.integrate localTick, 100, (frp.pure (5000))
            # accel = accel.map ((a) -> lowerCap a, 0)
            # accel = accel.map ((a) -> new Vector (direction.dir.x*a), 0)
            #velocity = frp.integrate localTick, (new Vector (direction.dir.x*0), 0), accel, Vector.add, Vector.scalar
            #velocity = velocity.map ((a) -> (old) -> Vector.add old, a)

            v = 100 * direction.dir.x
            velocity = frp.hold ((old) -> Vector.add old, (new Vector v, 0)),
                localTick.constMap ((old) -> Vector.add old, (new Vector v, 0))
            return velocity.updates()
            )

        dirAtStopMove = frp.snapshot stopMove, direction, frp.second
        modVelocity2 = frp.onEventMakeEvent dirAtStopMove, ((direction) =>
            deaccelTime = 50
            localTick3 = frp.tickFor @tick, deaccelTime
            velocity2 = frp.integrate localTick3, 1, (frp.pure -33)
            velocity2 = velocity2.map ((v) -> (old) ->
                return Vector.scalar (lowerCap v, 0), old
                )

            lastTick = (frp.tickAfter @tick, deaccelTime).once()

            effects = [
                velocity2.updates()
                lastTick.constMap (frp.constant Vector.null())
            ]
            return frp.mergeAll effects
            )
        bc = new BaseComponents @tick, 300, null, (frp.merge modVelocity1, modVelocity2)
        value = bc.velocity


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
        @value = frp.accum (Vector.null()), (frp.mergeAll [
            preTick.constMap (frp.constant (Vector.null()))
            value.updates().map ((v) -> (old) -> Vector.add old, v)
            fallV.updates().map ((v) -> (old) -> Vector.add old, v)
            wallJump.updates().map ((v) -> (old) -> Vector.add old, v)
            dash
            ])

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
        @value2 = @value2.gate canWallJump
        @value2 = @value2.snapshot wallJumpVel, frp.second

class Vector
    constructor: (@x, @y) ->
    @null: () -> new Vector 0, 0
    length: () -> Math.sqrt (@x*@x + @y*@y)
    @add = (v1, v2) -> new Vector (v1.x + v2.x), (v1.y + v2.y)
    @scalar = (t, v) -> new Vector (t*v.x), (t*v.y)

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

class BaseComponents
    constructor: (@tick
                 , velocityCap = 300
                 , @modAccel = new frp.EventStream()
                 , @modVelocity = new frp.EventStream()
                 , @modPosition = new frp.EventStream()) ->
        accel = frp.accum (Vector.null()), @modAccel
        accelExists = accel.map ((a) -> (a.length()) > 0.005)
        accelTick = @tick.gate accelExists

        intVelocity = {ref:null}
        velocity = {ref:null}
        capVelocity = {ref:null}

        velChangers = (frp.mergeAll [
            @modVelocity
            frp.mapE (frp.updates intVelocity), ((v) -> (_) -> v)
            ])
        velChangers = velChangers.map ((f) -> (v) ->
            v = f(v)
            if v.x < -velocityCap
                return new Vector (-velocityCap), 0
            if v.x > velocityCap
                return new Vector velocityCap, 0
            return v
            )
    
        velocity.ref = frp.accum (Vector.null()), velChangers

        intVelocity.ref = frp.integrateB accelTick, velocity, accel, Vector.add, Vector.scalar
        velocityExists = velocity.ref.map ((v) -> (v.length()) > 0.005)
        velocityTick = @tick.gate velocityExists

        intPosition = {ref:null}
        position = frp.accum (Vector.null()), (frp.mergeAll [
            @modPosition
            frp.mapE (frp.updates intPosition), ((v) -> (_) -> v)
            ])
        intPosition.ref = frp.integrateB velocityTick, position, velocity, Vector.add, Vector.scalar

        @velocity = velocity.ref


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
