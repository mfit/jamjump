frp = require '../frp/frp.js'

ConfigBehavior = (name, initial, type="number") ->
    beh = new frp.Behavior initial
    beh.settings =
        type:type

    if configs.behaviors.hasOwnProperty name
        console.warn "Two config behaviors with the same name (#{name})"
    configs.behaviors[name] = beh
    return beh

class Configs
    constructor: ->
        @behaviors = {}

configs = new Configs()

initialize = (settings, toolbar) ->
    settings.behaviors = {}
    options = $("body").append('<div class="options">')
    for behaviorName, beh of configs.behaviors
        settings.behaviors[behaviorName] = beh

    frp.sync -> settings.loadLocal()

    for behaviorName, beh of configs.behaviors
        opt = options.append "<div class=#{behaviorName}>"
        opt.append "<label>#{behaviorName}</label>"
        inp = opt.append "<input type=#{beh.settings.type} name='#{behaviorName}' value=#{beh.value()}>"

        cb = (beh, inp) -> ->
            if beh.settings.type == 'number'
                console.log (parseFloat inp.value)
                frp.sync -> beh.update parseFloat inp.value
                settings.saveLocal()
        inp.on 'input', (cb beh, (opt.find "input[name='#{behaviorName}']")[0])


module.exports =
    ConfigBehavior : ConfigBehavior
    initialize : initialize
