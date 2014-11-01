SkipList = require '../frp/SkipList'
SkipList = SkipList


class EventStream
    @new: (@type="unknown")->
        [e, push, node] = EventStream.newEventLinked()
        e = new EventStream e.getListenRaw, e.cacheRef, e.dep
        e.push = push
        e.send = push
        e.node = node
        e.type = "Event of #{@type}"
        return e

    constructor: (@_listen, @cacheRef, @dep) ->

    @newEventLinked: (dep) ->
        [listen, push, node] = EventStream.newEventImpl()
        ev =
            getListenRaw: -> listen
            cacheRef: null
            dep: dep
        return [ev, push, node]

    @newEventImpl: ->
        node = new Node()
        obs = new Observer()

        listen = null
        l = (target, suppressEarlierFirings, handle) ->
            id = obs.mkId()
            obs.listeners[id] = handle
            unlisten = ->
                delete obs.listeners[id]
                if listen['destroy']
                    listen.destroy()
                node.unlink id

            #return (unlisten, id)
            modified = if target != null then node.link id, target else false
            if not suppressEarlierFirings
                for firing in obs.firings
                    handle firing
            return unlisten
        listen = new Listen l
        listen.obs = obs

        push = (a) ->
            if system.syncing == false
                console.warn "event sent outside sync"

            obs.firings.push a
            system.scheduleLast (->
                obs.firings = []
                )

            for listenId, listenCallback of obs.listeners
                listenCallback a
        return [listen, push, node]

    linkedListen: (mNode, suppressEarlierFirings, handle) ->
        l = @getListen()
        unlisten = l.callback mNode, suppressEarlierFirings, handle
        return unlisten

    listenTrans: (handle) ->
        return @linkedListen null, false, handle

    getListen: ->
        if @cacheRef != null
            return @cacheRef
        else
            l = @_listen()
            @cacheRef = l
            return l

    listen: (handle) ->
        @listenTrans handle

    filter: (f) -> filter this, f
    map: (f) -> mapE this, f
    constMap: (a) -> constMap this, a
    snapshot: (b, f) -> snapshot this, b, f
    snapshotMany: (bs, f) -> snapshotMany this, bs, f
    gate: (b) -> gate this, b
    once: () -> once this
    at: (index) -> mapE this, ((vs) -> vs[index])

    mkUpdateEvent: ->
        e1 = mapE this, ((v) -> [v]) 
        e2 = coalesce e1, ((as, bs) ->
            for b in bs
                as.push b
            return as
            )
        e3 = split e2
        return e3

finalizeListen = (l, unlisten) ->
    l.takeDowns.push unlisten
    return l

finalizeSample = (s, unlisten) ->
    #s.takeDowns.push unlisten
    return s

addCleanup_Listen = (unlistener, listen) ->
    finalizeListen listen, (->
        unlistener.unlisten()
        unlistener.unlisten = null
    )

addCleanup_Sample = (unlistener, s) ->
    finalizeSample s, (->
        unlistener.value = null
    )

later = (doListen) ->
    if system.syncing == false
        console.warn "library called outside sync"
    unlistener = new Unlistener(->)
    system.scheduleEarly (->
        if unlistener.unlisten != null
            unlisten = doListen()
            unlistener.unlisten = unlisten
    )
    return unlistener
        
class Sample
    constructor: (@unSample, @dep, @keepAlive) ->

class Behavior
    constructor: (@updates_, @sample) ->
    map: (f) -> mapB this, f
    not: () -> mapB this, ((b) -> not b)
    updates: () -> updates this
    value: () -> @sample.unSample()
    values: () -> values this

class Just
    constructor: (@value) ->

class Nothing
isJust = (m) -> m instanceof Just
isNothing = (m) -> m instanceof Nothing
   
class BehaviorState
    constructor: (@current, @update) ->

class Unlistener
    constructor: (@unlisten) ->

class Listen
    constructor: (@callback) ->
        @takeDowns = []
    destroy: () ->
        for takeDown in @takeDowns
            #console.log "Takedown", takeDown
            takeDown()

class Observer
    constructor: ->
        @next_id = 0
        @listeners = {} # listeners are callbacks
        @firings = []

    mkId: ->
        id = @next_id
        @next_id += 1
        return id

class Node
    constructor: ->
        @id = system.mkId()
        @rank = 0
        @listeners = {} # listeners are nodes

    link: (id, target) ->
        modified = ensureBiggerThan {}, target, (@rank)
        @listeners[id] = target
        return modified

    unlink: (id) ->
        delete @listeners[id] 

Object.defineProperty Node.prototype, 'priority', 
    'get': ->
        return @rank

ensureBiggerThan = (visited, node, limit) ->
    if node.rank > limit || visited.hasOwnProperty(node.id)
        return false
    else
        newSerial = limit + 1
        node.rank = newSerial
        for nodeId, target of node.listeners
            ensureBiggerThan (visited[node.id] = true), target, newSerial
        return true

class PriorityQueue
    constructor: ->
        @nextSeq = 0
        @dirty = false
        @queue = new SkipList(([p1, s1], [p2, s2]) ->
            if p1 < p2
                return 1
            else if p1 > p2
                return -1
            else
                if s1 < s2
                    return 1
                else if s1 > s2
                    return -1
                else
                    return 0
            )
        @data = {}

    push: (k, v) ->
        seq = @nextSeq
        @nextSeq += 1
        @queue.put [k.priority, seq], v
        @data[seq] = [k, v]

    pop: ->
        @maybeRegen()
        low = @queue.firstEntrySet()
        if low == null
            return null
        @queue.delete low.key
        delete @data[low.key[1]]
        return low

    maybeRegen: ->
        if @dirty
            @dirty = false
            @queue = {}
            for seq, [k, v] of @queue
                @queue.put [k.priority, seq], v

    setDirty: -> @dirty = true

class System
    constructor: ->
        @next_id = 1
        @syncing = false

        @queue1 = [] # callbacks
        @queue2 = new PriorityQueue
        @final = []
        @post = []

    mkId: ->
        id = @next_id
        @next_id += 1
        return id

    sync: (f) ->
        @syncing = true

        taskLoop = null
        taskLoop = =>
            if @queue1.length != 0
                task = @queue1[0]
                @queue1.shift()
                task()
                taskLoop()
            else
                mTask = @queue2.pop()
                if mTask != null
                    mTask.value()
                    taskLoop()
                else
                    if @final.length != 0
                        task = @final[0]
                        @final.shift()
                        task()
                        taskLoop()

            if @post.length != 0
                task = @post[0]
                @post.shift()
                task()
                taskLoop()

        out = null


        @queue1 = [(-> out = f())]
        @queue2 = new PriorityQueue
        @final = []
        @post = []

        taskLoop()
        
        @syncing = false

        return out

    scheduleEarly: (f) -> @queue1.push f
    scheduleLast: (f) -> @final.push f
    schedulePost: (fs) ->
        for f in fs
            @post.push f
    schedulePrioritized: (node, task) ->
        @queue2.push node, task

filterJust = (ea) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            ea.linkedListen node, false, ((b) ->
                if isJust b then push (b.value)
            ))
        addCleanup_Listen unlistener, l
    return (new EventStream gl, null, ea)

gate = (ea, b) ->
    e = snapshot ea, b, ((a, b) -> if b then new Just a else new Nothing())
    return filterJust e

apply = (ba, bb, f) -> applicative (ba.map ((a) -> (b) -> f a, b)), bb
applicative = (bf_, bb_) ->
    e1 = updates bf_
    e2 = updates bb_

    gl = ->
        fRef = bf_.sample.unSample()
        aRef = bb_.sample.unSample()
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            un1 = e1.linkedListen node, false, ((f) ->
                fRef = f
                push (fRef aRef)
                )
            un2 = e2.linkedListen node, false, ((a) ->
                aRef = a
                push (fRef aRef)
                )
            return (->
                un1()
                un2()
                )
            )
        addCleanup_Listen unlistener, l

    s = new Sample (->
        if bf_.hasOwnProperty 'ref'
            bf_ = bf_.ref
        if bb_.hasOwnProperty 'ref'
            bb_ = bb_.ref
        s1 = bf_.sample.unSample
        s2 = bb_.sample.unSample

        f = s1()
        a = s2()
        return f(a)
        ), ([bf_.sample.dep, bb_.sample.dep]), null
    e = new EventStream gl, null, [e1, e2]
    return new Behavior e, s

mapB = (b_, f) ->
    fe = mapE (updates b_), f
    if b_.hasOwnProperty 'ref'
        fs = new Sample (-> f(b_.ref.sample.unSample())), b_.ref.sample.dep, null
    else
        s = b_.sample.unSample
        fs = new Sample (-> f(s())), b_.sample.dep, null
    return new Behavior fe, fs

constMap = (e, a) -> mapE e, ((_) -> a)

mapE = (e_, f) ->
    if e_.hasOwnProperty 'ref'
        e = null
    else
        e = e_

    gl = -> new Listen ((node, suppress, handle) ->
        if e == null
            if typeof e_.ref == 'function'
                e = e_.ref()
            else e = e_.ref
        e.linkedListen node, suppress, ((a) ->
            handle(f(a)))
        )
    return (new EventStream gl, null, e)

filter = (ea, pred) -> filterJust (mapE ea, (v) ->
    if pred v then new Just v else new Nothing())

mergeAll = (esa) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlists = []
        unlistener = later (->
            for ea in esa
                if ea.hasOwnProperty 'ref'
                    ea = ea.ref
                unlists.push (ea.linkedListen node, false, ((v) ->
                    push v))
            return (->
                for u in unlists
                    u()
                )
            )
        return (addCleanup_Listen unlistener, l)
    return (new EventStream gl, null, esa)
       

merge = (ea, eb) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            u1 = ea.linkedListen node, false, push
            #u2 = eb.linkedListen node, false, push
            u2 = eb.linkedListen node, false, ((a) ->
                 system.schedulePrioritized node, (->push a) 
                )
            return (->
                u1()
                u2()
                )
            )
        return (addCleanup_Listen unlistener, l)
    return (new EventStream gl, null, [ea, eb])

eventify = (listen, d) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (-> listen node, false, push)
        addCleanup_Listen unlistener, l
    return new EventStream gl, null, d

execute = (ev) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            ev.linkedListen node, false, ((action) ->
                val = action()
                push val
                )
            )
        addCleanup_Listen unlistener, l
    return new EventStream gl, null, ev

never = new EventStream (->new Listen (->), null), null, null
constant = (a) -> new Behavior never, (new Sample (->a))
values = (ba) ->
    sa = ba.sample
    ea = updates ba
    return eventify ((node, suppress, handle) -> listenValueRaw ba, node, suppress, handle), ([sa, ea])

updates = (beh) ->
    if beh.hasOwnProperty 'ref'
        return {ref:->
            beh.ref.updates_}
    else
        return beh.updates_

hold = (initA, ea) ->
    bs = new BehaviorState initA, new Nothing()
    unlistener = later (->
        ea.linkedListen null, false, ((a) ->
            if isNothing bs.update
                system.scheduleLast (->
                    newCurrent = bs.update.value
                    bs.current = newCurrent
                    bs.update = new Nothing()
                    )
            else
                console.warn ("Behavior updated twice")
            bs.update = new Just a
            )
    )
    sample = addCleanup_Sample unlistener, (new Sample (-> bs.current), ea, null)

    b = new Behavior ea, sample
    if initA.hasOwnProperty 'type'
        b.type = "Behavior of #{initA.type}"
    else
        ty = typeof initA
        b.type = "Behavior of #{ty}"
    return b

snapshotMany = (ea, bbs, f) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            bs = []
            for bb in bbs
                if bb.hasOwnProperty 'ref'
                    bs.push bb.ref.sample
                else
                    bs.push bb.sample

            return ea.linkedListen node, false, ((a) ->
                bsValues = [a]
                for s in bs
                    bsValues.push(s.unSample())
                push (f.apply(this, bsValues))
            )
        )
        addCleanup_Listen unlistener, l
    return new EventStream gl, null, [ea, bbs]

snapshot = (ea, bb, f) ->
    if not bb.hasOwnProperty 'ref'
        sample = bb.sample;
    else
        sample = bb;
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            if bb.hasOwnProperty 'ref'
                sample = bb.ref.sample 

            return ea.linkedListen node, false, ((a) ->
                b = sample.unSample()
                push (f a, b) 
            )
        )
        addCleanup_Listen unlistener, l
    return new EventStream gl, null, [ea, sample]

listenValueRaw = (ba, node, suppress, handle) ->
        lastFiringOnly ((node, suppress, handle) ->
            a = ba.sample.unSample()
            handle a
            (updates ba).linkedListen node, suppress, handle
            ), node, suppress, handle

lastFiringOnly = (listen, node, suppress, handle) ->
    aRef = new Nothing()
    listen node, suppress, ((a) ->
        if isNothing aRef
            system.schedulePrioritized node, (->
                handle aRef.value
                aRef = new Nothing()
                )
        aRef = new Just a
        )

# note: we are changing ea here
finalizeEvent = (ea, unlisten) ->
    x = ea._listen
    gl = ->
        l = x()
        return finalizeListen l, unlisten
    ea.cacheRef = null
    ea._listen = gl
    return ea


switchB = (bba) ->
    ba = bba.sample.unSample()
    depRef = {ref:ba}
    za = ba.sample.unSample()
    eba = updates bba
    [ev, push, node] = EventStream.newEventLinked [bba, depRef]
    ev = new EventStream ev.getListenRaw, ev.push, ev.dep
    unlisten2 = new Nothing()
    doUnlisten2 = ->
        if isNothing unlisten2 then return else unlisten2.value()
    unlisten1 = listenValueRaw bba, node, false, ((ba) ->
        doUnlisten2()
        depRef.ref = ba
        unlisten2 = new Just (listenValueRaw ba, node, false, push)
        )

    e = finalizeEvent ev, (->
        unlisten1()
        doUnlisten2()
        )

    return hold za, e

switchE = (bea) ->
    eea = updates bea
    depRef = {ref:null}
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlisten2 = new Nothing()
        doUnlisten2 = ->
           if isNothing unlisten2 then return (->) else return unlisten2.value
        unlistener1 = later (->
            initEa = bea.sample.unSample()
            unlisten2 = new Just (initEa.linkedListen node, false, push)
            unlisten1 = eea.linkedListen node, false, ((ea) ->
                system.scheduleLast (->
                    doUnlisten2()
                    depRef.ref = ea
                    )
                unlisten2 = new Just (ea.linkedListen node, true, push) 
                )
            return (->
                unlisten1()
                doUnlisten2()
                )
            )
        addCleanup_Listen unlistener1, l
    newEvent = new EventStream gl, null, [eea, depRef]
    if eea.hasOwnProperty 'type'
        newEvent.type = "#{ eea.type }"
    else
        newEvent.type = 'Event'
    return newEvent

split = (esa) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (-> esa.linkedListen node, false, ((as) ->
            postUpdates = []
            for a in as
                ((x) -> postUpdates.push (->
                    push x)) a
            system.schedulePost postUpdates
            )
        )
        addCleanup_Listen unlistener, l
    return new EventStream gl, null, esa

coalesce = (e, combine) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        out = new Nothing()
        unlistener = later (-> e.linkedListen node, false, ((a) ->
            first = isNothing out
            out = if isJust out then new Just (combine out.value, a) else new Just a
            if first
                system.schedulePrioritized node, (->
                    push (out.value)
                    out = new Nothing()
                )
            )
        )
        addCleanup_Listen unlistener, l
    return new EventStream gl, null, e

once = (e) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        alive = true
        unlistener = later (->
            unlisten = null
            unlisten = e.linkedListen node, false, ((a) ->
                if alive
                    alive = false
                    system.scheduleLast unlisten
                    push a
                )
            return unlisten
            )
        undo = addCleanup_Listen unlistener, l
        return undo
    return new EventStream gl, null, e

accum = (z, efa) ->
    s = {ref:null}
    s.ref = hold z, (snapshot efa, s, ((f, v) -> f v))
    return s.ref

system = new System()

e = EventStream.new()
e2 = EventStream.new()

e3 = EventStream.new()

eventSender = EventStream.new()
behaviorSender = EventStream.new()
never = EventStream.new()

pure = (a) -> constant a

tick = EventStream.new()
sendBeh = EventStream.new()

tickEvery = (base_tick, time) ->
    counter = {ref:null}

    tickEvent = filter (updates counter), ((v) -> v > time) # tick every time milliseconds

    effects = mergeAll [
        # reset on tick
        # there is always an overflow (e.g. tick = 16, time = 100 -> a will be 112
        # we dont reset to 0 because the every tick would be 12ms to long
        #  instead the 12ms will be added to the second tick
        tickEvent.constMap ((a) -> a - time)
        # increase time
        base_tick.map ((t) -> (a) -> a + t)
    ]

    counter.ref = accum 0, effects

    return tickEvent

log = (name) -> ((v) -> console.log name, v)
    
testTickEvery = ->
    ticker = system.sync (->
        t = tickEvery tick, 100
        t.listen (log "Ticker")
        return t
    )
    for i in [0..20]
        system.sync (->
            tick.send 16
        )
    return null

module.exports = 
    EventStream:-> EventStream.new()
    Behavior: (initA) ->
        e = EventStream.new()
        beh = hold initA, e
        beh.update = e.send
        return beh
    mergeAll: (es) -> (mergeAll es).mkUpdateEvent()
    accum:accum
    hold:hold
    apply:apply
    switchBeh:switchB
    updates:updates
    values:values
    switchE:switchE
    merge: (e1, e2) -> (merge e1, e2).mkUpdateEvent()
    never:never
    execute:execute
    pure:pure
    constMap:constMap
    sync: (f) ->
        system.sync f
