#frp = require '../frp/behavior.js'
frp = require '../frp/frp.js'
frpCfg = require '../frp/frp_settings.js'
tick = frp.tick
preTick = frp.preTick
postTick = frp.postTick

log = frp.log

player = require '../frp/player_behaviors.js'
StopMoveEvent = player.StopMoveEvent
MoveEvent = player.MoveEvent
Direction = player.Direction

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

class BlockManager
    constructor: () ->
        @blocks = {}
        @blockSize = 50

        # String to class mapping
        @createmap =
            default: DefaultBlock

    toWorldCoords: (x, y) ->
        return {x:x*@blockSize, y:y*@blockSize}

    fromWorldCoords: (x, y) ->
        x = Math.floor(x / @blockSize)
        # y = Math.floor(y / @blockSize + 1)
        y = Math.floor(y / @blockSize)
        return {x:x, y:y}

    canAddBlock: (x, y) ->
        return false if @blocks.hasOwnProperty(y) && @blocks[y].hasOwnProperty x
        return true

    blockFactory: (btype) ->
        block = new @createmap[btype]

    addBlock: (x, y, block) ->
        if not @canAddBlock x, y
            return

        if !@blocks.hasOwnProperty y
            @blocks[y] = {}
        @blocks[y][x] = block

        block.x = x
        block.y = y

    removeBlock: (x, y) ->
        if @blocks.hasOwnProperty(y) and @blocks[y].hasOwnProperty x
            block = @blocks[y][x]
            block.sprite.kill()
            delete @blocks[y][x]

    copy: (mgr) ->

    @mkBehaviors: () ->
        # command events
        addBlock = new frp.EventStream # addBlock {x:x, y:y, block: new Block()}
        removeBlock = new frp.EventStream

        addedBlock = new frp.EventStream
        removedBlock = new frp.EventStream

        effects = [
           addBlock.map ((blockInfo) -> (bm) ->
                block = blockInfo.block
                if bm.canAddBlock blockInfo.x, blockInfo.y
                    bm.addBlock blockInfo.x, blockInfo.y, block # FIXME test if block was added
                    if block.removeMeEvent
                        block.removeMeEvent.listen ((v) -> removeBlock.send block)
                    addedBlock.send blockInfo
                return bm
                )
           removeBlock.map ((block) -> (bm) ->
                bm.removeBlock (block.x), (block.y)
                removedBlock.send {x:block.x, y:block.y}
                return bm
                )
        ]

        bm = frp.accum (new BlockManager()), (frp.mergeAll effects).mkUpdateEvent()
        bm.addBlock = addBlock
        bm.addedBlock = addedBlock
        bm.removeBlock = removeBlock
        return bm

class Parallax
    constructor: ->

class Camera
    constructor: (@tick, world) ->
        # find me in frp/toPhaser.coffee

        @shakeIt()

    shakeIt: ->
        @amplitude = new frpCfg.ConfigBehavior "Amplitude", 0.05
        @shakeMe = new frp.EventStream
        @rotating = frp.onEventMakeBehavior 0, @shakeMe, (_) =>
            [t, end] = frp.tickSplitTime @tick, 100
            end = end.once()
            totalTime = frp.accumAll 0, [
                (t.map (t) -> (oldT) -> oldT + t)
                end.constMap (oldT) -> 0
                ]
            return totalTime.apply @amplitude, ((t, a) -> a*(100 - t) - Math.sin t)

class World
    constructor: () ->
        @tick = tick

        # FIXME doesnt work :/
        # e = frp.onEventCollectEvent @tick, ((dt) ->
        #     return frp.tickEvery tick, 40
        #     )
        # e.listen (log "SHOULD FIRE")

        @makeFaster = new frp.EventStream()
        @makeSlower = new frp.EventStream()
        @mod = frp.accum 1, (frp.mergeAll [
            @makeFaster.constMap ((m) -> m * 2)
            @makeSlower.constMap ((m) -> m / 2)
            ])

        playerTick = @tick.snapshot @mod, ((t, mod) -> t * mod)
        @players = [
            new player.Player playerTick, "p1", 'runner1'
            new player.Player playerTick, "p2", 'runner2'
         #   new player.Player game, "p3"
        ]

        # TODO move this inside the player
        #console.log @players[0]
        @players[0].pushVel.ref = frp.pure (player.Vector.null())
        #@players[0].pushVel.ref = frp.pure (player.Vector.null());
        @players[1].pushVel.ref = new player.Push @tick, @players[0], @players[1], @players[0].setBlockEvent

        @players[0].pullVel.ref = new player.Pull @tick, @players[1], @players[0], @players[1].setBlockEvent
        @players[1].pullVel.ref = frp.pure (player.Vector.null());
        #@players[0].pullVel.ref = frp.pure (player.Vector.null());

        #@players[0].pushBox.addColliders.send (@players[1])

        @worldBlocks = BlockManager.mkBehaviors()
        @camera = new Camera tick, this

        # for player in @players
        #     setting = player.blockSetter.blockSet.snapshotMany [player.position], ((ignore, pos) =>
        #         gridsize = 50;
        #         x = Math.floor(pos.x / gridsize)
        #         y = Math.floor(pos.y / gridsize + 1)
        #         @worldBlocks.addBlock.send {x:x, y:y, block: new DefaultBlock}
        #         )
        #     # side effects
        #     setting.listen ((v) -> )

    save: ->
    reload: ->

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
