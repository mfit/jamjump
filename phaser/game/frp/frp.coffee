SkipList = require '../frp/SkipList'
SkipList = SkipList

system = null
dbg = false
debug = (txt) ->
    if dbg == true
        console.log txt

class EventStream
    getName: () -> return "#{@id}:#{@name}"
    @new: (myName, type="unknown")->
        [e, push, node] = EventStream.newEventLinked()
        e = new EventStream e.getListenRaw, e.cacheRef, e.dep
        if typeof myName == undefined
            e.name = "RootEvent"
        else
            e.name = myName
        e.getListen().event = e
        e.push = push
        e.send = push
        e.node = node
        e.type = "Event of #{@type}"
        return e

    constructor: (@_listen, @cacheRef, @dep) ->
        @id = system.mkId()

    @newEventLinked: (dep) ->
        [listen, push, node] = EventStream.newEventImpl()
        ev =
            getListenRaw: -> listen
            cacheRef: null
            dep: dep
        return [ev, push, node]

    @newEventImpl2: () ->
        node = new Node()
        obs = new Observer()
        listen = new Listen null, null, obs, node
        return [listen, obs, node]

    @newEventImpl: ->
        node = new Node()
        obs = new Observer()

        listen = null
        l = (target, suppressEarlierFirings, handle) ->
            listen.listeners += 1
            id = obs.mkId()
            obs.listeners[id] = handle

            unlisten = (id) -> ->
                delete obs.listeners[id]
                listen.listeners -= 1
                if listen['destroy']
                    listen.destroy()
                node.unlink id

            #return (unlisten, id)
            modified = if target != null then node.link id, target else false
            if not suppressEarlierFirings
                for firing in obs.firings
                    handle firing
            return (unlisten id)

        listen = new Listen l
        listen.obs = obs

        push = (a) ->
            if system.syncing == false
                console.warn "event sent outside sync"

            obs.firings.push a
            system.final.push (-> obs.firings = [])
            # system.scheduleLast (->
            #     obs.firings = []
            #     )

            for listenId, listenCallback of obs.listeners
                listenCallback a

        return [listen, push, node]

    push: (a) ->

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
            @cacheRef.event = this
            return l

    listen: (handle) ->
        debug "linking raw to #{@getName()}"
        @listenTrans handle

    filter: (f) -> filter this, f
    filterTrue: () -> filterTrue this
    map: (f) -> mapE this, f
    constMap: (a) -> constMap this, a
    snapshot: (b, f) -> snapshot this, b, f
    snapshotMany: (bs, f) -> snapshotMany this, bs, f
    gate: (b) -> gate this, b
    once: () -> once this
    at: (index) -> mapE this, ((vs) -> vs[index])
    snapshotEffect: (beh, callback) ->
        e = @snapshot beh, callback
        e.listen ((v) ->)
    delay: -> delay this
    execute: -> execute this

    times: (a) -> @map ((v) -> v * a)

    mkUpdateEvent: ->
        # convert value to list
        e1 = mapE this, ((v) -> [v]) 
        # append the lists
        e2 = coalesce e1, ((as, bs) ->
            for b in bs
                as.push b
            return as
            )
        # put every value into its own transaction
        e3 = split e2
        return e3

finalizeListen = (l, unlisten) ->
    l.takeDowns.push unlisten
    return l

finalizeSample = (s, unlisten) ->
    if s.keepAlive != null
        s.takeDowns.push unlisten
    return s

addCleanup_Listen = (unlistener, listen) ->
    finalizeListen listen, (->
        if unlistener.unlisten
            unlistener.unlisten()
        #unlistener.unlisten = null
    )

addCleanup_Sample = (unlistener, s) ->
    finalizeSample s, (->
        if unlistener.unlisten
            unlistener.unlisten()
        #unlistener.unlisten = null
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
        @takeDowns = []
        @references = 0
    destroy: () ->
        if @references <= 0
            #console.log @listeners
            for takeDown in @takeDowns
                takeDown()

class Behavior
    getName: () -> return "#{@id}:#{@name}"
    constructor: (@updates_, @sample) ->
        @id = system.mkId()
    map: (f) -> mapB this, f
    not: () ->
        b = mapB this, ((b) -> not b)
        b.name = [b.name, "not"]
        return b
    updates: () -> updates this
    value: () -> @sample.unSample()
    values: () -> values this
    at: (index) -> mapB this, ((vs) -> vs[index])
    apply: (beh2, f) -> apply this, beh2, f
    value: () -> @sample.unSample()

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
    constructor: (@callb=null, @keepAlive, @obs, @node) ->
        @takeDowns = []
        @listeners = 0
        if @callb != null
            @callback = @callb
            
    callback: (target, suppressEarlierFirings, handle) ->
        @listeners += 1
        id = @obs.mkId()
        @obs.listeners[id] = handle

        #return (unlisten, id)
        modified = if target != null then @node.link id, target else false
        if not suppressEarlierFirings
            for firing in @obs.firings
                handle firing
        return (@unlisten id)

    unlisten: (id) => =>
        delete @obs.listeners[id]
        @listeners -= 1
        if @destroy
            @destroy()
        @node.unlink id           

    destroy: () ->
        if @listeners >= 2
            debug "Many listeners", this
        if @listeners == 0
            for takeDown in @takeDowns
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

    push: (a) ->
        if system.syncing == false
            console.warn "event sent outside sync"

        @firings.push a
        system.final.push (=> @firings = [])

        for listenId, listenCallback of @listeners
            listenCallback a

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

    taskLoop: ->
        # label wont work without this if
        if false then return
        `queue1: //`
        while true
            tasks = []
            for task in @queue1 
                tasks.push task
            @queue1 = []
            for task in tasks
                task()

            if @queue1.length > 0
                `continue queue1`

            while (mTask = @queue2.pop())
                mTask.value()
                if @queue1.length > 0
                    `continue queue1`

            if @final.length != 0
                task = @final[0]
                @final.shift()
                task()
                continue

            if @post.length != 0
                task = @post[0]
                @post.shift()
                task()
                continue

            if @delay.length != 0
                task = @delay[0]
                @delay.shift()
                task()
                # for del in @delay
                #     @queue1.push del
                # @delay = []
                continue
            return
        return

    sync: (f) ->
        @syncing = true

        out = null


        @queue1 = [(-> out = f())]
        @queue2 = new PriorityQueue
        @final = []
        @post = []
        @delay = []

        @taskLoop()
        
        @syncing = false

        return out

    scheduleEarly: (f) -> @queue1.push f
    scheduleLast: (f) -> @final.push f
    schedulePost: (fs) ->
        for f in fs
            @post.push f
    schedulePrioritized: (node, task) ->
        @queue2.push node, task

system = new System()

filterJust = (ea) ->
    e = null
    gl = ->
        [l, obs, node] = EventStream.newEventImpl2()
        unlistener = later (->
            debug "linking filterJust #{e.getName()} to #{ea.getName()}"
            unlisten = ea.linkedListen node, false, ((b) ->
                if isJust b then obs.push (b.value)
            )
            return (->
                debug "unlistening filterJust #{e.getName()} from #{ea.getName()}"
                unlisten()
                )
            )
        addCleanup_Listen unlistener, l
    e = (new EventStream gl, null, ea)
    e.name = "filterJust"
    return e

gate = (ea, b) ->
    e = snapshot ea, b, ((a, b) ->
        if b then new Just a else new Nothing()
        )
    e2 = filterJust e

    d = ->
        if b.hasOwnProperty 'ref'
            return b.ref
        else
            return b
    
    e.name = [e.name, "gate "]
    e2.name = [e2.name, "gate of"]
    return e2

apply = (ba, bb, f) -> applicative (ba.map ((a) -> (b) -> f a, b)), bb
applicative = (bf_, bb_) ->
    e1 = updates bf_
    e2 = updates bb_

    newB = null
    gl = ->
        if bf_.hasOwnProperty 'ref'
            bf_ = bf_.ref
        if bb_.hasOwnProperty 'ref'
            bb_ = bb_.ref
        if (e1.hasOwnProperty 'ref') && typeof e2.ref != 'function'
            e1 = e1.ref
        if (e1.hasOwnProperty 'ref') && typeof e1.ref == 'function'
            e1 = e1.ref
        if (e2.hasOwnProperty 'ref') && typeof e2.ref != 'function'
            e2 = e2.ref
        if (e2.hasOwnProperty 'ref') && typeof e2.ref == 'function'
            e2 = e2.ref()

        fRef = bf_.sample.unSample()
        aRef = bb_.sample.unSample()
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            debug "linking applicative #{newB.getName()} to #{bf_.getName()} and #{bb_.getName()}"
            un1 = e1.linkedListen node, false, ((f) ->
                fRef = f
                push (fRef aRef)
                )
            un2 = e2.linkedListen node, false, ((a) ->
                aRef = a
                push (fRef aRef)
                )
            return (->
                debug "unlistening applicative #{newB.getName()}"
                un1()
                un2()
                )
            )
        addCleanup_Listen unlistener, l

    keepAliveRef = {ref:null}

    if bf_.hasOwnProperty 'ref'
        bf_.sample = bf_
        bf_.dep = bf_

    if bb_.hasOwnProperty 'ref'
        bb_.sample = bb_
        bb_.dep = bb_
    
    s = new Sample (->
        if bf_.hasOwnProperty 'ref'
            bf_ = bf_.ref
        if bb_.hasOwnProperty 'ref'
            bb_ = bb_.ref
        s1 = bf_.sample.unSample
        s2 = bb_.sample.unSample
        keepAliveRef.ref = bb_.sample

        f = s1()
        a = s2()
        return f(a)
        ), ([bf_.sample.dep, bb_.sample.dep]), keepAliveRef
    e = new EventStream gl, null, [e1, e2]
    e.name = "applicativeEvent"
    newB = new Behavior e, s
    newB.name = "applicatve"
    return newB

mapB = (b_, f) ->
    fe = mapE (updates b_), f
    if b_.hasOwnProperty 'ref'
        fs = new Sample (-> f(b_.ref.sample.unSample())), b_, null
    else
        s = b_.sample.unSample
        fs = new Sample (->f(s())), b_.sample.dep, null

    later (->
        if b_.hasOwnProperty 'ref'
            b_.ref.sample.references += 1
        else
            b_.sample.references += 1
        )
   
    newB = new Behavior fe, fs
    newB.name = "mapB with #{fe.getName()}"
    return newB

constMap = (e, a) ->
    newE = mapE e, ((_) -> a)
    newE.name = [newE.name, "constMap"]
    return newE

mapE = (e_, f) ->
    if e_.hasOwnProperty 'ref'
        e = null
    else
        e = e_

    gl = ->
        listen = null
        listen = new Listen ((node, suppress, handle) ->
            listen.listeners += 1
            if e == null
                if typeof e_.ref == 'function'
                    e = e_.ref()
                else e = e_.ref
            unlist = e.linkedListen node, suppress, ((a) ->
                handle(f(a))
                )
            debug "linking mapE #{newE.getName()} to #{e.getName()} #{e.getListen().listeners}"
            return (->
                listen.listeners -= 1
                debug "unlistening mapE #{newE.getName()} from #{e.getName()}"
                unlist()
                )
        )

    newE = (new EventStream gl, null, e)
    newE.name = "mapE"
    return newE

filterTrue = (ea) -> filter ea, ((v) -> v == true)
filter = (ea, pred) ->
    e1 = mapE ea, (v) -> if pred v then new Just v else new Nothing()
    e1.name = [e1.name, "apply pred"]
    e = filterJust e1
    e.name = [e.name, "filter"]
    return e

mergeAll = (esa) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            unlists = []
            for ea in esa
                if ea.hasOwnProperty 'ref'
                    if typeof ea.ref == 'function'
                        ea = ea.ref()
                    else
                        ea = ea.ref
                debug "linking mergeAll #{newE.getName()} to #{ea.getName()}"
                un = ea.linkedListen node, false, ((v) -> push v)
                f = (ea, un) -> (->
                    debug "unlistening mergeAll #{newE.getName()} from #{ea.getName()}"
                    un()
                    )
                unlists.push (f ea, un)
            return (->
                for u in unlists
                    u()
                )
            )
        addCleanup_Listen unlistener, l
    newE = (new EventStream gl, null, esa)
    newE.name = "mergeAll"
    return newE

merge = (ea, eb) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            debug "linking merge #{newE.getName()} to #{ea.getName()} and #{eb.getName()}"
            u1 = ea.linkedListen node, false, push
            #u2 = eb.linkedListen node, false, push
            u2 = eb.linkedListen node, false, ((a) ->
                 system.schedulePrioritized node, (->push a) 
                )
            return (->
                debug "unlistening merge #{newE.getName()}"
                u1()
                u2()
                )
            )
        addCleanup_Listen unlistener, l

    newE = (new EventStream gl, null, [ea, eb])
    newE.name = "merge"
    return newE

eventify = (listen, d) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            unlist = listen node, false, push
            return (->
                debug "unlistening eventify #{newE.getName()}"
                unlist()
                )
            )
        addCleanup_Listen unlistener, l

    newE = new EventStream gl, null, d
    newE.name = "eventify"
    return newE

execute = (ev) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            debug "linking execute #{newE.getName()} to #{ev.getName()}"
            unlist = ev.linkedListen node, false, ((action) ->
                val = action()
                push val
                )
            return (->
                debug "unlistening execute #{newE.getName()}"
                unlist()
                )
            )
        addCleanup_Listen unlistener, l

    newE = new EventStream gl, null, ev
    newE.name = "execute"
    return newE

never = new EventStream (->new Listen (->), null), null, null
never.name = "never"

constantB = (a) ->
    b = new Behavior never, (new Sample (->a))
    b.name = "constant #{a}"
    return b

values = (ba) ->
    sa = ba.sample
    ea = updates ba
    e = eventify ((node, suppress, handle) -> listenValueRaw ba, node, suppress, handle), ([sa, ea])
    e.name = "values of #{ba.getName()}"
    return e

updates = (beh) ->
    if beh.hasOwnProperty 'ref'
        return {ref:->
            e = beh.ref.updates_
            e.name = [beh.ref.name, e.name, "updates of #{beh.ref.getName()}"]
            return e
            }
    else
        e = beh.updates_
        e.name = [beh.name, e.name, "updates of #{beh.getName()}"]
        return e
            
class KeepAlive
    constructor: ->

holdAll = (initA, eas) -> hold initA, (mergeAll eas)
accumAll = (initA, eas) -> accum initA, (mergeAll eas)

hold = (initA, ea) ->
    ea = ea
    bs = new BehaviorState initA, new Nothing()
    b = null

    behUn = null

    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            unlist = ea.linkedListen node, false, ((a) ->
                system.scheduleLast (->
                    push a
                ))
            return (->
               unlist()
               if behUn.unlisten != null
                   behUn.unlisten()
               )
            )
        addCleanup_Listen unlistener, l

    ea2 = new EventStream gl, null, [ea]
    ea2.name = "holdEvent"
    
    behUn = later (->
        debug "linking hold #{b.getName()} to #{ea.getName()}"
        ea2.getListen().listeners -= 1
        unlistener = ea2.linkedListen null, false, ((a) ->
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
        return (->
            debug "unlistening hold #{b.getName()} from #{ea2.getName()}"
            unlistener()
            )
    )
    keepAliveRef = new KeepAlive()
    sample = addCleanup_Sample behUn, (new Sample (-> bs.current), ea, keepAliveRef)
    b = new Behavior ea2, sample
    b.name = "hold #{ea.getName()}"
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
  
            debug "linking snapshotMany #{newE.getName()} to #{ea.getName()}"
            unlist = ea.linkedListen node, false, ((a) ->
                bsValues = [a]
                for s in bs
                    bsValues.push(s.unSample())
                push (f.apply(this, bsValues))
            )
            return (->
                debug "unlistening snapshotMany #{newE.getName()}"
                unlist()
                )
            )
        addCleanup_Listen unlistener, l

    newE = new EventStream gl, null, [ea, bbs]
    newE.name = "snapshotMany"
    return newE

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
                bb = bb.ref

            sample.references += 1

            debug "linking snapshot #{e.getName()} to #{ea.getName()}"
            debug " watching #{bb.getName()} and #{sample}"
            unlist = ea.linkedListen node, false, ((a) ->
                b = sample.unSample()
                push (f a, b) 
                )
            return (->
                debug "unlistening snapshot #{e.getName()} from #{ea.getName()}"
                sample.references -= 1
                debug "references #{sample.references}"
                if (sample.references <= 0)
                    sample.destroy()
                unlist()
                )
            )
        addCleanup_Listen unlistener, l

    e = new EventStream gl, null, [ea, sample]
    e.name = "snapshot"
    return e

listenValueRaw = (ba, node, suppress, handle) ->
        # why only last value?
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

allFirings = (listen, node, suppress, handle) ->
    listen node, suppress, ((a) ->
        system.schedulePrioritized node, (->
            handle a
            )
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
    [ev, push, node] = EventStream.newEventLinked [bba, depRef]
    ev = new EventStream ev.getListenRaw, push, ev.dep
    ev.name = "switchB event"
    unlisten2 = new Nothing()
    doUnlisten2 = ->
        if isNothing unlisten2 then return else unlisten2.value()

    unlisten1 = null

    e = finalizeEvent ev, (->
        unlisten1()
        doUnlisten2()
        )

    newB = hold za, e
    newB.name = "switchB"

    debug "linking switchB #{newB.getName()} to #{bba.getName()}"
    unlisten1 = listenValueRaw bba, node, false, ((ba) ->
        doUnlisten2()
        depRef.ref = ba
        debug "linking switchB #{newB.getName()} to #{ba.getName()} for #{bba.getName()}"
        unlist3 = listenValueRaw ba, node, false, push
        unlist2 = (unlist) -> new Just (->
            debug "unlinking inside switchB #{newB.getName()} to #{ba.getName()}"
            unlist()
            ) 
        unlisten2 = (unlist2 unlist3) 
        )
    return newB

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

            debug "linking switchE #{newEvent.getName()} to #{initEa.getName()} for #{bea.getName()}"
            unlisten2 = new Just (initEa.linkedListen node, false, push)
            debug "linking switchE #{newEvent.getName()} to #{eea.getName()} for #{bea.getName()}"
            unlisten1 = eea.linkedListen node, false, ((ea) ->
                system.scheduleLast (->
                    x = doUnlisten2()
                    y = x()
                    depRef.ref = ea

                    unlisten2_ = ea.linkedListen node, true, push
                    unlisten2 = (un) -> (new Just (->
                        debug "unlistening inside switchE #{newEvent.getName()}"
                        t = un()
                        )) 
                    unlisten2 = unlisten2 unlisten2_

                    )
                debug "linking switchE #{newEvent.getName()}  to #{ea.getName()} for #{bea.getName()}"
                )
            return (->
                debug "unlistening switchE #{newEvent.getName()}"
                unlisten1()
                doUnlisten2()
                )
            )
        addCleanup_Listen unlistener1, l
    newEvent = new EventStream gl, null, [eea, depRef]
    newEvent.name = "switchE"
    if eea.hasOwnProperty 'type'
        newEvent.type = "#{ eea.type }"
    else
        newEvent.type = 'Event'
    return newEvent

split = (esa) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        debug "linking split #{newE.getName()} to #{esa.getName()}"
        unlistener = later (->
            unlistener = esa.linkedListen node, false, ((as) ->
                postUpdates = []
                for a in as
                    f = (x) -> system.post.push (-> push x)
                    f a
                )
            return (->
                debug "unlistening split #{newE.getName()}"
                unlistener()
                )
            )
        addCleanup_Listen unlistener, l
    newE = new EventStream gl, null, esa
    newE.name = "split"
    return newE

coalesce = (e, combine) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        out = new Nothing()
        debug "linking coalesce #{newE.getName()} to #{e.getName()}"
        unlistener = later (->
            unlist = e.linkedListen node, false, ((a) ->
                first = isNothing out
                out = if isJust out then new Just (combine out.value, a) else new Just a
                if first
                    system.schedulePrioritized node, (->
                        push (out.value)
                        out = new Nothing()
                    )
                )
            return (->
                debug "unlistening coalesce #{newE.getName()}"
                unlist()
                )
            )
        addCleanup_Listen unlistener, l
    newE = new EventStream gl, null, e
    newE.name = "coalesce"
    return newE

once = (e) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        alive = true
        unlistener = later (->
            unlisten = null
            unlisted = false
            debug "linking once #{newEvent.getName()} to #{e.getName()}"
            unlist2 = e.linkedListen node, false, ((a) ->
                if alive
                    alive = false
                    system.scheduleLast unlisten
                    push a
                )
            unlist = (unlist1) -> (->
                if not unlisted
                    unlisted = true
                    debug "Unlistening once #{newEvent.getName()} from #{e.getName()}"
                    unlist1()
                )
            unlisten = unlist unlist2
            return unlisten
            )
        undo = addCleanup_Listen unlistener, l
        return undo
    newEvent = new EventStream gl, null, e
    newEvent.name = 'once'
    return newEvent

delay = (e) ->
    gl = ->
        [l, push, node] = EventStream.newEventImpl()
        unlistener = later (->
            e.linkedListen node, false, ((a) ->
                system.delay.push (-> push a)
                )
            )
        addCleanup_Listen unlistener, l
    newEvent = new EventStream gl, null, e
    return newEvent

accum = (z, efa) ->
    efa = efa.mkUpdateEvent()
    s = {ref:null}
    s.ref = hold z, (snapshot efa, s, ((f, v) -> f v))
    s.ref.name = [s.ref.name, "accum"]
    s.ref.isRecursive = true
    return s.ref


never = EventStream.new("Never")

pure = (a) -> constantB a

# creates an event that triggers every 'time' milliseconds
# the base tick determines the increment step
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

inc = (x) -> (x + 1)
dec = (x) -> (x - 1)

tick = EventStream.new("Tick")
# a tick for phaser systems that need to be executed at first (e.g. collision)
preTick = EventStream.new("PreTick")
# after updating speed etc. used for updating phaser
postTick = EventStream.new("PostTick")

test = ->
    dt = mapE tick, ((v) -> v + 1)

    dx = accum 0, (dt.constMap ((old) -> old + 1))

    dy = hold 0, dt

    un1 = dt.listen (log "test1")
    un2 = dt.listen (log "test2")
    console.log "linked two to 8"
    e = updates dx
    un3 = e.listen (log "dx")
    f = updates dy
    un4 = f.listen (log "dy")
    console.log e, un3
    return [un1, un2, un3, e, un4]

# event that represents the value of the behavior on tick
tick.onTick = (beh) => tick.snapshot beh, second
preTick.onTick = (beh) => preTick.snapshot beh, second
tick.onTickDo = (beh, callback) => tick.snapshot beh, ((t, behValue) -> callback behValue)
preTick.onTickDo = (beh, callback) => preTick.snapshot beh, ((t, behValue) -> callback behValue)

# returns an event that triggers once after 'initial' milliseconds
mkCountdown = (initial) ->
    counter = accum initial, (tick.map ((v) -> ((a) -> a - v)))
    finished = counter.updates().filter ((v) -> v < 0)
    return (finished.constMap true).once()

second = (a, b) -> b

# TODO splats for arbitary number of arguments
selector = (initial, choices, arg1, arg2) ->
    setter = EventStream.new("Setter")
    choice = setter.map ((e) -> choices[e](arg1, arg2)) # Event (Behavior)

    # hold initial, choice # Behavior (Behavior)
    selected = switchB (hold initial, choice) # Behavior
    return [setter, selected]


# return a function returning a constant
constant= (x) -> ((a) -> x)

# an tick that ticks for t milliseconds
tickFor = (baseTick, t) ->
    timeTicking = accum [0, 0], (baseTick.map ((t) -> ([a, _]) -> [a + t, t]))
    v = (updates timeTicking).filter (([tick, _]) -> tick < t)
    return v.at 1

tickAfter = (baseTick, t) ->
    t2 = baseTick.map ((t) -> ([a, _]) -> [a + t, t])
    timeTicking = accum [0, 0], t2
    v = (updates timeTicking).filter (([tick, _]) -> tick > t)
    return v.at 1

# create an event that triggers once after time milliseconds
timer = (baseTick, time) -> #(tickEvery baseTick, time).once()
    timeTicking = accum 0, (baseTick.map ((t) -> (a) -> a + t))
    e = (updates timeTicking).filter ((t) -> t > time)
    return e.once()

tickUntilEvent = (baseTick, event) ->
    occurred = happened event
    return baseTick.gate (occurred.not())

tickWhen = (baseTick, beh, pred) ->
    fulfilled = beh.map pred
    return baseTick.gate fulfilled

tickAfterEvent = (baseTick, event) ->
    occurred = happened event
    return baseTick.gate occurred

tickSplitTime = (baseTick, time) ->
    return [(tickFor baseTick, time), (tickAfter baseTick, time)]

# tickEvery = (baseTick, time) ->
#     reset = {ref:null}
#     ticker = accum 0, (mergeAll [
#         (baseTick.map ((t) -> (a) -> a + t))
#         constMap reset, ((a) -> a - time)
#         ])
#     reset.ref = fr

onEventCollectEvent = (e, callback) ->
    v = accum never, (execute (e.map ((v) -> ->
        r = callback v
        return (oldE) -> merge oldE, r
        )))
    return switchE v

# create event on event
# returns an event
onEventMakeEvent = (e, callback) ->
    v = hold never, (execute (e.map ((v) -> -> callback v)))
    return switchE v

# create a behavior on event
# returns a behavior
onEventMakeBehavior = (initial, e, callback) ->
    v = hold (pure initial), execute e.map ((v) -> -> callback v)
    return switchB v

# [Behavior a] -> Behavior [a]
# converts a list of behaviors to a behavior of a list
collectBehs = (behs) ->
    new_behs = []
    for beh in behs
        new_behs.push (beh.map ((a) -> [a]))

    first_b = new_behs[0]
    new_behs.shift()
    for new_beh in new_behs
        first_b = apply first_b, new_beh, ((b1, b2) ->
            bnew = []
            for b1_ in b1
                bnew.push b1_
            for b2_ in b2
                bnew.push b2_
            return bnew
            )
    return first_b

# 
onEventMakeBehaviors = (initials, e, callback) ->
    e2 = execute e.map ((v) -> ->
        behs = callback v
        return collectBehs behs
        )
    v = hold (pure initials), e2
    return switchB v   

# integrate f(t)dt with constant C and f(t) = dx
integrate = (dt, C, dx, add=((x, y) -> x + y), scalar=(t, x) -> t * x) ->
    diff = dt.snapshot dx, ((dt, dx) -> (oldX) -> add oldX, (scalar (dt / 1000.0), dx))
    b = accum C, diff
    b.name = [b.name, "accum, integrate"]
    return b

# integrate f(t)dt with constant C(t) and f(t) = dx
integrateB = (dt, C, dx, add=((x, y) -> x + y), scalar=(t, x) -> t * x) ->
    diff = dt.snapshot dx, ((dt, dx) -> scalar (dt / 1000.0), dx)
    b = diff.snapshot C, ((d, b) -> add d, b)
    return hold 0, b

# a behavior that is true when e triggerd and false otherwise
happened = (e) ->
    h = e.once().constMap true
    h.name = [h.name, "onceHappened"]
    b = hold false, h
    b.name = [b.name, "happened"]
    return b

module.exports = 
    EventStream: (name) -> EventStream.new name
    Behavior: (initA) ->
        e = EventStream.new("Behavior event")
        beh = hold initA, e
        beh.update = e.send
        return beh
    #mergeAll: (es) -> (mergeAll es).mkUpdateEvent()
    merge: merge
    never:never
    mergeAll: mergeAll
    constMap:constMap
    mapE:mapE
    filter:filter
    filterTrue:filterTrue
    delay:delay

    updates:updates
    values:values
    accum:accum
    hold:hold
    apply:apply
    switchBeh:switchB
    switchB:switchB
    switchE:switchE
    #merge: (e1, e2) -> (merge e1, e2).mkUpdateEvent()
    execute:execute
    pure:pure

    sync: (f) ->
        system.sync f

    tick:tick
    preTick:preTick
    postTick:postTick

    selector:selector
    inc:inc
    dec:dec
    constant:constant
    log:log

    mkCountdown:mkCountdown
    tickFor:tickFor
    tickAfter:tickAfter
    tickUntilEvent:tickUntilEvent
    tickAfterEvent:tickAfterEvent
    onEventMakeEvent:onEventMakeEvent
    onEventCollectEvent:onEventCollectEvent
    onEventMakeBehavior:onEventMakeBehavior
    integrate:integrate
    integrateB:integrateB
    onEventMakeBehaviors:onEventMakeBehaviors 
    happened:happened
    second:second
    snapshot:snapshot
    timer:timer
    tickEvery:tickEvery
    mapB:mapB
    tickSplitTime:tickSplitTime
    holdAll:holdAll
    accumAll:accumAll
