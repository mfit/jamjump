class Configs
    constructor: ->
        @shaders = {}
    addShader: (name, shader) ->
        @shaders[name] = shader

configs = new Configs()

initialize = (settings, toolbar) ->
    settings.render = {}
    options = $("body").append('<div class="render_options">')
    for shaderName, shader of configs.shaders
        opt = options.append "<div class=#{shaderName}>"
        opt.append "<label>#{shaderName}</label>"

        fs = shader.fs.join('\n');
        vs = shader.vs.join('\n');
    
        inp_fs = opt.append "<textarea cols=80 rows=10 name='#{shaderName}_fs'>#{fs}</textarea>"
        inp_vs = opt.append "<textarea cols=80 rows=10 name='#{shaderName}_vs'>#{vs}</textarea>"

        cb_fs = (shader, inp) -> ->
            shader.fs = inp.value.split('\n')
            shader.recompile = true
        cb_vs = (shader, inp) -> ->
            shader.vs = inp.value.split('\n')
            shader.recompile = true       
        inp_fs.change (cb_fs shader, (opt.find "textarea[name='#{shaderName}_fs']")[0])
        inp_vs.change (cb_vs shader, (opt.find "textarea[name='#{shaderName}_vs']")[0])

module.exports =
    initialize:initialize
    addShader: (name, shader) -> configs.addShader name, shader
