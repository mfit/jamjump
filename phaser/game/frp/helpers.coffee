#
# Helpers, misc.
#
frp = require './behavior.js'

# Create an eventStream that fires at changing random intervals
# The interval is between min and max msecs
randomInvervalEmmiter = (tick, min, max) ->
    getnextintv = -> min + Math.random() * (max - min)

    reset = new frp.EventStream
    nextInterStream = new frp.EventStream
    nextInterval = frp.hold getnextintv(), nextInterStream

    effects = [
            tick.map ((v) -> ((a) -> a + v))
            reset.constMap ((a) -> 0)
    ]
    counter = frp.accum 0, (frp.mergeAll effects)

    intvticker = counter.updates().snapshot nextInterval, ((v, ctr) -> v > ctr)
    intvticker = intvticker.filter((v) -> v == true)
    intvticker.listen ((ignore) ->
         reset.send true
         nextInterStream.send getnextintv())

    intvticker.nextInterval = nextInterval

    return intvticker

module.exports.randomInvervalEmmiter = randomInvervalEmmiter

