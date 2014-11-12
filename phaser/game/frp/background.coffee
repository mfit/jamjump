frp = require('../frp/frp.js')
log = frp.log

class Background
    constructor: ->
        tick = frp.tick;
        time = frp.accum 0, (tick.map (dt) -> (t) -> dt + t)
        @r = time.map (t) -> Math.round(51 + t/30000*(208 - 51))
        @g = time.map (t) -> Math.round(171 - t/30000*(171 - 100))
        @b = time.map (t) -> Math.round(249 - t/30000*(249 - 14))

module.exports =
    Background:Background
