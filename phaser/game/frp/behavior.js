function Behavior(value) {
    this.current_value = value;
    this.pending_value = null;
    
    this.listeners = {};
    this.id = system.mkId();
}

Behavior.prototype.listen = function (f) {
    return this.updates().listen(f);
}

Behavior.prototype.not = function() {
    b = this.map(function (val) { return !val; });
    return b
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

Behavior.prototype.values = function () {
    return values(this);
}

// Dont use this
Behavior.prototype.update = function(value) {
    this.pending_value = value;
    system.pendingUpdates[this.id] = this;//.push(this);
}

Behavior.prototype._unregisterListener = function(listener) {
    delete this.listeners[listener.id]
}

function EventStream() {
    this.value = null;
    
    this.listeners = {};
    this.id = system.mkId();
}

function Listener(listener, callback) {
    this.id = system.mkId();
    this.listener = listener;
    this.callback = callback;
}

function EventInstance(event_stream, event_value) {
    this.stream = event_stream;
    this.value = event_value;
}

EventStream.prototype._unregisterListener = function(listener) {
    delete this.listeners[listener.id]
}

EventStream.prototype.send = function(value) {
    system.addPendingEvent(this, value);
}

EventStream.prototype.onTrue = function (callback) {
    this.map(function (value) {
        if (value === true) {
            callback();
        }
    });
}

EventStream.prototype.once = function() {
    var e = new EventStream();
    var sent = false;
    e._send = e.send;
    e.send = function (value) {
        if (!sent) {
            e._send(value);
            sent = true;
            e.unlisten();
        }
    }
    e.unlisten = this.listen(function (v) { 
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
    var listener = new Listener(listener, callback);
    console.log ("list", listener)
    this.listeners[listener.id] = listener;
    var that = this;
    return function() {
        delete that.listeners[listener.id]
    }
}

function System() {
    this.next_id = 1;
    this.pendingEvents = [];
    this.pendingUpdates = {};
    this.futureValues = {};
}

System.prototype.mkId = function() {
    var id = this.next_id;
    this.next_id += 1;
    return id;
}

System.prototype.addPendingEvent = function(event, value) {
    this.pendingEvents.push(new EventInstance(event, value));
}

System.prototype.sync = function () {
    console.log (this.pendingEvents)
    this.syncMain();
}

System.prototype.syncMain = function () {
    var i;
    
    var oldPending = this.pendingEvents.slice(0);
    this.pendingEvents = [];
    for (i = 0; i < oldPending.length; i++) {
        this.handleTransaction(oldPending[i]);
    }
    
    if (this.pendingEvents.length != 0) {
        this.syncMain();
    }
}

System.prototype.handleTransaction = function (eventInstance) {
    eventInstance.stream.value = eventInstance.value;
    var i; 
    for (var id in eventInstance.stream.listeners) {
        var listener = eventInstance.stream.listeners[id].listener;
        var callback = eventInstance.stream.listeners[id].callback;
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
        for (var id in copy[behId].listeners) { // j = 0; j < copy[behId].listeners.length; j++) {
            var listener = copy[behId].listeners[id].listener;
            var callback = copy[behId].listeners[id].callback;
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
    behavior_with_event.current_value.listeners[listener.id] = listener;
    
    var listener2 = new Listener({}, function (event) { 
        behavior_with_event.current_value._unregisterListener(listener);
        event.listeners[listener.id] = listener;
        });
    behavior_with_event.listeners[listener2.id] = listener2;
    return e;
}

function switchBeh(behavior_with_behavior) {
    var b = new Behavior(behavior_with_behavior.current_value.current_value);
    var listener = new Listener({}, function (val) {b.update(val); });

    behavior_with_behavior.current_value.listeners[listener.id] = listener;

    var listener2 = new Listener({}, function (beh) {
        behavior_with_behavior.current_value._unregisterListener(listener);
        b.update(beh.current_value);
        //listener = new Listener({}, function (val) {b.update(val); });
        beh.listeners[listener.id] = listener;
    });
    behavior_with_behavior.listeners[listener2.id] = listener2;

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
    var listener = new Listener(b, function (v) { 
        b.update(callback(v)); });

    behavior.listeners[listener.id] = listener;
    return b;
}

function apply(beh_a, beh_b, callback) {
    var b = new Behavior(callback(beh_a.current_value, beh_b.current_value));
    var list_a = new Listener(b, function (val_a) { b.update(callback(val_a, beh_b.current_value)); });
    var list_b = new Listener(b, function (val_b) { b.update(callback(beh_a.current_value, val_b)); });
    beh_a.listeners[list_a.id] = list_a;
    beh_b.listeners[list_b.id] = list_b;
    return b;
}

function map(event, callback) {
    var e = new EventStream();
    //event._registerListener(e, );
    event._registerListener(e, function (val) { e.send(callback(val)); });
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

function values(behavior) {
    if (behavior.hasOwnProperty('_updatesCache')) {
        return behavior._updatesCache;
    }
    var e = new EventStream();
    var listener = new Listener(behavior, function (value) { e.send(value); });
    behavior.listeners[listener.id] = listener;
    behavior._updatesCache = e;
    e.send(behavior.current_value);
    return e;

}

function updates(behavior) {
    if (behavior.hasOwnProperty('_updatesCache')) {
        return behavior._updatesCache;
    }
    var e = new EventStream();
    var listener = new Listener(behavior, function (value) { e.send(value); });
    behavior.listeners[listener.id] = listener;
    behavior._updatesCache = e;
    return e;
}

function listen(event_stream, callback) {
    return event_stream._registerListener({}, callback);
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
