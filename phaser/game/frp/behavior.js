function Behavior(value) {
    this.current_value = value;
    this.pending_value = null;
    
    this.listeners = [];
    this.id = system.mkId();
}

Behavior.prototype.switchE = function () {
    return switchE(this);
}

Behavior.prototype.switchBeh = function () {
    return switchBeh(this);
}

Behavior.prototype.snapshot = function (event, callback) {
    return snapshot(event, this, callback);
}

Behavior.prototype.map = function (callback) {
    return call(this, callback);
}

Behavior.prototype.apply = function (beh, callback) {
    return apply(this, beh, callback);
}

Behavior.prototype.updates = function () {
    return updates(this);
}

// Dont use this
Behavior.prototype.update = function(value) {
    this.pending_value = value;
    system.pendingUpdates[this.id] = this;//.push(this);
}

Behavior.prototype._unregisterListener = function(listener) {
    for (var i = 0; i < this.listeners.length; i++) {
        if (this.listeners[i] === listener) {
            this.listeners.splice(i, 1);
            return;
        }
    }
    
    console.error("listener does not exist");
}

function EventStream() {
    this.value = null;
    
    this.listeners = [];
    this.id = system.mkId();
}

function Listener(listener, callback) {
    this.listener = listener;
    this.callback = callback;
}

function EventInstance(event_stream, event_value) {
    this.stream = event_stream;
    this.value = event_value;
}

EventStream.prototype._unregisterListener = function(listener) {
    for (var i = 0; i < this.listeners.length; i++) {
        if (this.listeners[i] === listener) {
            this.listeners.splice(i, 1);
            return;
        }
    }
    
    console.error("listener does not exist");
}

EventStream.prototype.send = function(value) {
    system.addPendingEvent(this, value);
}

EventStream.prototype.once = function() {
    var e = new EventStream();
    var sent = false;
    e._send = e.send;
    e.send = function (value) {
        if (!sent) {
            e._send(value);
            sent = true;
        }
    }
    unlisten = this.listen(function (v) { 
        e.send(v);
    });
    return e;
}

EventStream.prototype.merge = function (eventStream) {
    return merge(this, eventStream);
}

EventStream.prototype.snapshot = function (beh, callback) {
    return snapshot(this, beh, callback);
}

// untested
EventStream.prototype.snapshotMany = function (behs, callback) {
    last = behs[0].map(function (val) { return [val]; });
    for (var i = 1; i < behs.length; i++) {
        last = last.apply(behs[i], function (args, arg2) { return args.push(arg2); });
    }
    return this.snapshot(last, function (evt, args) {
        var argsFinal = [evt]
        for (var j = 0; j < args.length; j++) {
            argsFinal.push(args[j]);
        }
        callback.apply(this, argsFinal);
    });
}

EventStream.prototype.hold = function (initial) {
    return hold(initial, this);
}

EventStream.prototype.map = function (callback) {
    return map(this, callback);
}

EventStream.prototype.filter = function (callback) {
    return filter(this, callback);
}

EventStream.prototype.gate = function (behavior) {
    return gate(this, behavior);
}

EventStream.prototype.listen = function (callback) {
    return listen(this, callback);
}

EventStream.prototype.constMap = function (value) {
    return constMap(this, value);
}

EventStream.prototype.accum = function (initial) {
    return accum(initial, this);
}

EventStream.prototype._registerListener = function (listener, callback) {
    this.listeners.push(new Listener(listener, callback));
}

function System() {
    this.next_id = 1;
    this.pendingEvents = [];
    this.pendingUpdates = {};
    this.futureValues = {};
    this.delayedListeners = [];
    this.delayedSends = [];
}

System.prototype.mkId = function() {
    var id = this.next_id;
    this.next_id += 1;
    return id;
}

System.prototype.addPendingEvent = function(event, value) {
    this.pendingEvents.push(new EventInstance(event, value));
}

System.prototype.sendDelayed = function (event, value) {
    this.delayedSends.push({event:event, value:value});
}

System.prototype.registerListener = function(source, listener) {
    this.delayedListeners.push({source:source, listener:listener});
}

System.prototype.sync = function () {
    var i;
    
    var oldListeners = this.delayedListeners.slice(0);
    this.delayedListeners = [];
    for (i = 0; i < oldListeners.length; i++) {
        oldListeners[i].source.listeners.push(oldListeners[i].listener);
    }
    
    var oldSends = this.delayedSends.slice(0);
    this.delayedSends = [];
    for (i = 0; i < oldSends.length; i++) {
        oldSends[i].event.send(oldSends[i].value);
    }

    var oldPending = this.pendingEvents.slice(0);
    this.pendingEvents = [];
    for (i = 0; i < oldPending.length; i++) {
        this.handleTransaction(oldPending[i]);
    }
    
    if (this.pendingEvents.length != 0) {
        this.sync();
    }
}

System.prototype.handleTransaction = function (eventInstance) {
    eventInstance.stream.value = eventInstance.value;
    var i; 
    for (i = 0; i < eventInstance.stream.listeners.length; i++) {
        var listener = eventInstance.stream.listeners[i].listener;
        var callback = eventInstance.stream.listeners[i].callback;
        callback(eventInstance.value);
    }
   
    this.updateBehaviors();
}

function isEmpty(obj) {
    for (var prop in obj) {
        if (obj.hasOwnProperty(prop))
            return false;
    }
    return true;
}

System.prototype.updateBehaviors = function() {
    var copy = {};
    for (var behId in this.pendingUpdates) {
        copy[behId] = this.pendingUpdates[behId];
    }
    this.pendingUpdates = {};

    for (behId in copy) {
        // FIXME
        if (!copy.hasOwnProperty(behId))
            continue;

        // the callbacks may need the old transaction state
        for (var j = 0; j < copy[behId].listeners.length; j++) {
            var listener = copy[behId].listeners[j].listener;
            var callback = copy[behId].listeners[j].callback;
            callback(copy[behId].pending_value);
        }

        // update transaction state
        //copy[behId].current_value = copy[behId].pending_value;
        this.futureValues[behId] = copy[behId];
        //copy[behId].pending_value = null;
    }
    
    // TODO: Do not update behaviors before all incoming event slots are processed
   
    if (isEmpty(this.pendingUpdates)) {
        for (var behId in this.futureValues) {
            this.futureValues[behId].current_value = this.futureValues[behId].pending_value;
            this.futureValues[behId].pending_value = null;
        }
        this.futureValues = {};
    } else {
        this.updateBehaviors();
    }
}

// (Event, Event) -> Event
function merge(event_stream_a, event_stream_b) {
    var e = new EventStream();
    event_stream_a._registerListener(e, function (v) { e.send(v); });
    event_stream_b._registerListener(e, function (v) { e.send(v); });
    return e;
}

// [Event] -> Event
function mergeAll(eventStreams) {
    var head = eventStreams[0];
    var merged = head;
    for (var i = 1; i < eventStreams.length; i++) {
        merged = merge(merged, eventStreams[i]);
    }
    return merged;
}

function switchE(behavior_with_event) {
    var e = new EventStream();
    
    var listener = new Listener(e, function (val) { e.send(val); });
    behavior_with_event.current_value.listeners.push(listener);
    
    behavior_with_event.listeners.push(new Listener({}, function (event) { 
        behavior_with_event.current_value._unregisterListener(listener);
        event.listeners.push(listener);
        }));
    return e;
}

function switchBeh(behavior_with_behavior) {
    var b = new Behavior(behavior_with_behavior.current_value.current_value);
    var listener = new Listener({}, function (val) {b.update(val); });

    behavior_with_behavior.current_value.listeners.push(listener);

    behavior_with_behavior.listeners.push(new Listener({}, function (beh) {
        behavior_with_behavior.current_value._unregisterListener(listener);
        b.update(beh.current_value);
        //listener = new Listener({}, function (val) {b.update(val); });
        beh.listeners.push(listener);
    }));

    return b;
}

// snapshot :: Event -> Behavior -> Event
function snapshot(event_stream, beh, callback) {
    var e = new EventStream();
    event_stream._registerListener(e, function (val) { e.send(callback(val, beh.current_value)); });
    return e;
}

// hold :: Value -> Event -> Behavior
// holds latest value of event
function hold(initial, event_stream) {
    var b = new Behavior(initial);
    event_stream._registerListener(b, function (value) {b.update(value)});
    return b;
}

function call(behavior, callback) {
    var b = new Behavior(callback(behavior.current_value));
    behavior.listeners.push(new Listener(b, function (v) { 
        b.update(callback(v)); }));
    return b;
}

function apply(beh_a, beh_b, callback) {
    var b = new Behavior(callback(beh_a.current_value, beh_b.current_value));
    beh_a.listeners.push(new Listener(b, function (val_a) { b.update(callback(val_a, beh_b.current_value)); }));
    beh_b.listeners.push(new Listener(b, function (val_b) { b.update(callback(beh_a.current_value, val_b)); }));
    return b;
}

function map(event, callback) {
    var e = new EventStream();
    //event._registerListener(e, );
    system.registerListener(event, new Listener(e, function (val) { e.send(callback(val)); }));
    return e;
}

function filter(event_stream, test_func) {
    var e = new EventStream();
    event_stream._registerListener(e, function (value) { 
        if (test_func(value)) {
            e.send(value);
        }
    });
    return e;
}

function gate2(event, behavior, callback) {
    var b2 = behavior.map (callback);
    return gate(event, b2);
}

function gate(event, behavior) {
    var e = new EventStream();
    event._registerListener(e, function (value) {
        if (behavior.current_value == true) {
            e.send(value);
        }
    });
    return e;
}

function updates(behavior) {
    if (behavior.hasOwnProperty('_updatesCache')) {
        return behavior._updatesCache;
    }
    var e = new EventStream();
    system.registerListener(behavior, new Listener(behavior, function (value) { e.send(value); }));//system.sendDelayed(e, value); }));
    behavior._updatesCache = e;
    return e;
}

function listen(event_stream, callback) {
    event_stream._registerListener({}, callback);
}

function Step(milliseconds) {
    this.milliseconds = milliseconds;
    this.seconds = milliseconds/1000.0;
    return this;
}

function accum(initial, event) {
    var b = new Behavior(initial);
    event._registerListener(b, function (func) { b.update(func(b.current_value)); });
    return b;
}

function constMap(event, f) { return map(event, function (v) { return f; }); }

var system = new System();
never = new EventStream();

function updateSpeed(speed) {
    return {x:speed.x + 10, y:speed.y};
}

function capSpeed(speed) {
    return {x:Math.min(140, speed.x), y:speed.y};
}

function JumpPlayer() {
    var collisionEvent = new EventStream();
    var moveEvent = new EventStream();
    var jumpEvent = new EventStream();
    var blockPlaceEvent = new EventStream();
    
    var moving = isMoving(moveEvent);
    
    var speed = null; 
    
    var cap = map(updates(new Delay(function() { return speed; })), function (v) { return capSpeed; });
    var equals = snapshot(cap, delayBehavior(new Delay(function() { return speed; })), function (capSpeed, oldSpeed) {
        if (capSpeed.x == oldSpeed.x && capSpeed.y == oldSpeed.y) {
            return true;
        }});
    
    listen(equals, function (v) { console.log(v); });
    
    var increase = map(moveEvent, function (v) { return updateSpeed; });
    
    var t = merge(cap, increase);
    
    console.log(t);
    
    speed = accum({x:100, y:200}, t); //new Behavior({x:100, y:200});
    
    listen(updates(speed), function (v) { console.log(v); });

    moveEvent.send({x:0.5, y:0.3});
    system.sync();
    moveEvent.send({x:0.1, y:0.05});
    system.sync();
    moveEvent.send({x:0.1, y:0.05});
    system.sync();
    moveEvent.send({x:0.1, y:0.05});
    system.sync();
    moveEvent.send({x:0.1, y:0.05});
    system.sync();
    moveEvent.send({x:0.1, y:0.05});
    system.sync();
    console.log("end");
}

function isMoving(moveEvent) {
    var downEvent = map(moveEvent, function (dir) { if (Math.abs(dir.x) < 0.2 && Math.abs(dir.y) < 0.2) { return false; } else { return true; }});
    var down = hold(false, downEvent);
    return down;
}

function test() {
    var eventSource = new EventStream();
    var eventSource2 = new EventStream();
    
    var eventEvent = new EventStream();

    var latest = hold(0, eventSource);
    var addOne = call(latest, function (v) { return v + 1; });
    
    var addEvents = updates(addOne);
    var high = filter(addEvents, function (v) { return (v > 5); });
    
    var latest2 = hold(1, eventSource2);
    
    var addTwo = apply(latest, latest2, function (a, b) { return a + b; });
    
    var behOfEvents = hold(never, eventEvent);
    
    var behOfBeh = new Behavior(hold(0, eventSource));
    var beh_ = switchBeh(behOfBeh);
    
    listen(updates(beh_), function (val) { console.log(val); });
    
    eventSource.send(1);
    system.sync();
    eventSource.send(2);
    system.sync();
    behOfBeh.update(hold(3, eventSource2));
    system.sync();
    eventSource.send(2);
    system.sync();
    console.log("send 3");
    eventSource2.send(3);
    system.sync();


    listen(switchE(behOfEvents), function (val) { console.log(val); });
    listen(updates(addTwo), function (val) { console.log(val); });
    
    console.log(latest);
    eventSource.send(2);
    system.sync();
    console.log(addOne);
    console.log(high);
    eventSource.send(5);
    eventSource2.send(2);
    system.sync();
    console.log(addOne);
    console.log(addEvents);
    console.log(high);

    console.log(addTwo);
    
    var stream = new EventStream();
    eventEvent.send(stream);
    system.sync();
    stream.send('This is the end');
    system.sync();
}

module.exports.listen = listen;
module.exports.hold = hold;
module.exports.apply = apply;
module.exports.system = system;
module.exports.never = never;
module.exports.merge = merge;
module.exports.mergeAll = mergeAll;
module.exports.snapshot = snapshot;
module.exports.call = call;
module.exports.switchE = switchE;
module.exports.map = map;
module.exports.filter = filter;
module.exports.gate = gate;
module.exports.updates = updates;
module.exports.accum = accum;
module.exports.constMap = constMap;
module.exports.switchBeh = switchBeh;
module.exports.EventStream = EventStream;
module.exports.Behavior = Behavior;

// maybe we can delete events and behaviors that are not listened to (recursively)
