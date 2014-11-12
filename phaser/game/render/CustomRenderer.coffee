settings = require '../settings/RenderSettings.js'
frpCfg = require '../frp/frp_settings.js'
frp = require '../frp/frp.js'
tick = frp.tick
log = frp.log
    
dbg = true

debug = (txt) ->
    if dbg
        console.log txt
    
class TextureManager
    constructor: (@gl) ->
        @active = gl.TEXTURE0
        @max_active_units = gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS)

        @free_active = {}
        for i in [0..31]
            @free_active[gl.TEXTURE0 + i] = true

        @textureStats = {}
        @imageUnitStats = {}

    freeUnitExists: ->
        for unit of @free_active
            if @free_active.hasOwnProperty unit
                return true
        return false

    markUnitUsed: (unit) ->
        delete @free_active[unit]
    markUnitUnused: (unit) ->
        @free_active[unit] = true

    getFreeUnit: ->
        if not @freeUnitExists
            return -1

        selected = null
        for unit of @free_active
            if @free_active.hasOwnProperty unit
                selected = unit
                break
        if selected == null
            debug "No unit found but one exists"
            return -1

        delete @free_active[selected]

        @imageUnitStats[unit] = {
            created: new Date().getTime()
            texture: null
            size: 0
        }
    
        return selected
    
    createGLTexture: (texture) ->
        gl = @gl
        textureId = gl.createTexture()
        texture._glTextures[gl.id] = textureId

        @textureStats[textureId] = 
            created: new Date().getTime()
            # we may need to update state
            backRef: texture
            # currently bound?
            uploaded: false

    uploadTexture: (texture) ->
        gl = @gl
    
        oldState =
            activeTexture: gl.getParameter(gl.ACTIVE_TEXTURE)

        if not @freeUnitExists
            for imageUnit, stats of @imageUnitStats
                # TODO implement algorithm to choose an unit
                # e.g. that is as small as possible
                #      that wasn't used in the last x ms
                tex = @imageUnitStats[imageUnit].texture
                @textureStats[tex].uploaded = false
                break
        else
            imageUnit = @getFreeUnit()

        if (not texture.hasLoaded)
            debug "Requested texture upload for unloaded texture"
            return
        if (not texture._glTextures[gl.id])
            debug "Texture not created"
            return

        debug "Set active image unit: #{imageUnit}, TEXTURE0: #{gl.TEXTURE0}"
        gl.activeTexture imageUnit
        texId = texture._glTextures[gl.id]
        @imageUnitStats[imageUnit].texture = texId
        # TODO calculate bytes
        @imageUnitStats[imageUnit].size = texture.width * texture.height
        @textureStats[texId].uploaded = imageUnit

        gl.bindTexture gl.TEXTURE_2D, texture._glTextures[gl.id]
        gl.pixelStorei gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, texture.premultipliedAlpha
        scaleMode =
            if texture.scaleMode == PIXI.scaleModes.LINEAR
                gl.LINEAR
            else
                gl.NEAREST
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, scaleMode

        if (not texture._powerOf2)
            gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE
            gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE
        else
            gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT 
            gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT 

        # texture._dirty[gl.id] = false

        debug "Set active image unit: #{oldState.activeTexture}, TEXTURE0: #{gl.TEXTURE0}"
        gl.bindTexture gl.TEXTURE_2D, null
        gl.activeTexture oldState.activeTexture
        return

    printDebug: ->
        console.log "Max active texture image units: #{@max_active_units}"
        activeUnits = []
        for unit of @free_active
            activeUnits.push ("TEXTURE" + (unit - @gl.TEXTURE0).toString())
        console.log "Free texture units: #{activeUnits}"
        console.log "Texture stats:", @textureStats
        console.log "Image unit stats:", @imageUnitStats

class BlockVertexDynamic
    constructor: (tilingSprite) ->
        @pos = {x:0, y:0}

class BlockVertexStatic
    constructor: (tilingSprite) ->
        texture = tilingSprite.tilingTexture.baseTexture
        off_x = tilingSprite.tilePosition.x / texture.width
        off_y = tilingSprite.tilePosition.y / texture.height
        x = tilingSprite.width / texture.width
        y = tilingSprite.height / texture.height

        pos =
            x0: -0.5
            y0: -0.5
            x1: 0.5
            y1: -0.5
            x2: 0.5
            y2: 0.5
            x3: -0.5
            y3: 0.5

        uvs =
            x0: off_x
            y0: off_y
            x1: x
            y1: off_y
            x2: x
            y2: y
            x3: off_z
            y3: y

    getVertices: ->
        return []

class Shader
    constructor: (gl) ->
        @program = PIXI.compileProgram gl, [
            'attribute vec2 vertexPosition;'
            'void main(void) {'
            '    gl_Position = vec4(vertexPosition, 0, 1);'
            '}'
            ], [
            'void main(void) {'
            '    gl_FragColor = vec4(1, 0, 0, 1);'
            '}'
            ] 

class BufferManager
    constructor: (@gl) ->
        gl = @gl
        @vertexBuffer = gl.createBuffer()
        @indexBuffer = gl.createBuffer()
        # gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        # gl.bufferData gl.ELEMENT_ARRAY_BUFFER, [], gl.STATIC_DRAW

        # gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
        # gl.bufferData gl.ARRAY_BUFFER, [], gl.DYNAMIC_DRAW

        @shader = new Shader @gl

    upload: ->
        gl = @gl
        elementData = [0, 1, 2, 0, 2, 3]
        @vertexData = [-0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5]

        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bufferData gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(elementData), gl.STATIC_DRAW

        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
        gl.bufferData gl.ARRAY_BUFFER, new Float32Array(@vertexData), gl.DYNAMIC_DRAW

        # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)

        gl.useProgram @shader.program
        vertexPos = gl.getAttribLocation @shader.program, 'vertexPosition'
        gl.vertexAttribPointer vertexPos, 2, gl.FLOAT, false, 8, 0
        gl.enableVertexAttribArray vertexPos

        # restore state
        gl.useProgram oldProg

    render: ->
        gl = @gl
        gl.viewport 0, 0, @width, @height
        gl.disable gl.BLEND
        gl.disable gl.DEPTH_TEST
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer

        # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)
        gl.useProgram @shader.program
        vertexPos = gl.getAttribLocation @shader.program, 'vertexPosition'
        gl.vertexAttribPointer vertexPos, 2, gl.FLOAT, false, 8, 0
        gl.enableVertexAttribArray vertexPos

        gl.drawElements gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, 0


        gl.enable gl.BLEND
        #gl.enable gl.DEPTH_TEST

        # restore state
        gl.useProgram oldProg

render = (gl) ->
    return

class LineShader
    constructor: (@gl) ->
        settings.addShader "Rain", this

        @vs = [
            'attribute vec2 vertexPosition;'
            'attribute float speed;'
            'uniform float angle;'
            'uniform float time;'

            'void main(void) {'
            '    float y = sin(angle)*vertexPosition.y; '
                'float newX = 0.0;'
                'float offset = 0.0;'
                'offset = mod (-time*speed, -2.0)+1.1;'
                'newX += sin(angle)*(offset + vertexPosition.y);'
            '    gl_Position = vec4(newX + vertexPosition.x, offset + vertexPosition.y, 0, 1);'
            '}'
            ]
        @fs = [
            'void main(void) {'
            '    gl_FragColor = vec4(0.0, 0.0, 0.0, 0.6);'
            #'    gl_FragColor = vec4(6.0/255.0, 84.0/255.0, 133.0/255.0, 1);'
            '}'
            ] 
        @doRecompile()

    doRecompile: ->
        @program = PIXI.compileProgram @gl, @vs, @fs

class LineRenderer
    constructor: (@gl) ->
        gl = @gl
        @vertexBuffer = gl.createBuffer()
        @indexBuffer = gl.createBuffer()
        @shader = new LineShader @gl

    upload: ->
        gl = @gl

        @num = 2000
        elementData = [0..@num*2]
        @vertexData = []
        for i in [0..(@num)]
            x = ((2 * (Math.random()-0.5)))
            y = ((2 * Math.random()-0.5))
            speed = (Math.random() + 5)*20 - 85
            @vertexData.push x
            @vertexData.push 0
            @vertexData.push speed
            @vertexData.push x
            @vertexData.push -((Math.random() + 0.5)/10.0)
            @vertexData.push speed
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bufferData gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(elementData), gl.STATIC_DRAW
        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
        gl.bufferData gl.ARRAY_BUFFER, new Float32Array(@vertexData), gl.STATIC_DRAW

        @updateAttribsAndUniforms()

        @angle = 0
        @localTime = 0
        @pos = [0, 0.3, 0.5]

    updateAttribsAndUniforms: ->
        gl = @gl
         # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)

        gl.useProgram @shader.program
        @vertexPos = gl.getAttribLocation @shader.program, 'vertexPosition'
        @speed = gl.getAttribLocation @shader.program, 'speed'
        @angleUniform = gl.getUniformLocation @shader.program, 'angle'
        @time = gl.getUniformLocation @shader.program, 'time'

        # restore state
        gl.useProgram oldProg

    render: ->
        gl = @gl
        gl.enable gl.BLEND
        gl.disable gl.DEPTH_TEST
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer

        if @shader.recompile
            @shader.doRecompile()
            @updateAttribsAndUniforms()
        
        # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)
        gl.useProgram @shader.program
        gl.vertexAttribPointer @vertexPos, 2, gl.FLOAT, false, 12, 0
        gl.vertexAttribPointer @speed, 1, gl.FLOAT, false, 12, 8
        gl.enableVertexAttribArray @vertexPos

        @localTime += 0.0016*1
        @angle = Math.sin(@localTime) / 10.0

        for i in [0..3]
            @pos[i] -= (0.016*i)
            if @pos[i] < -3
                @pos[i] = 3


        gl.uniform1f @angleUniform, @angle
        gl.uniform1f @time, @localTime

        gl.lineWidth 1
        gl.drawElements gl.LINES, @num, gl.UNSIGNED_SHORT, 0

        gl.enable gl.BLEND
        #gl.enable gl.DEPTH_TEST

        # restore state
        gl.useProgram oldProg

class BackgroundShader
    constructor: (@gl) ->
        @fs = [
            'precision highp float;'
            'uniform float time;'
            'uniform sampler2D sunwalk;'
            'void main(void) {'
            '    gl_FragColor = texture2D(sunwalk, vec2(time*15.0/39.0, 0.0));'
            '}'
            ]

        @vs = [
            'attribute vec2 vertexPosition;'
            'void main(void) {'
            '    gl_Position = vec4(vertexPosition, 0.0, 1.0);'
            '}'
            ]

        @doRecompile()
    doRecompile: ->
        gl = @gl
        @program = gl.createProgram()
        fsSrc = @fs.join("\n")
        fsShader = gl.createShader gl.FRAGMENT_SHADER
        gl.shaderSource fsShader, fsSrc
        gl.compileShader fsShader

        gl.getShaderInfoLog fsShader

        vsSrc = @vs.join("\n")
        vsShader = gl.createShader gl.VERTEX_SHADER
        gl.shaderSource vsShader, vsSrc
        gl.compileShader vsShader

        gl.getShaderInfoLog vsShader
        
        @program = PIXI.compileProgram @gl, @vs, @fs
        @recompile = false

class BackgroundRenderer
    constructor: (@gl, @width, @height) ->
        gl = @gl
        @vertexBuffer = gl.createBuffer()
        @indexBuffer = gl.createBuffer()
        @shader = new BackgroundShader @gl

    upload: ->
        gl = @gl

        elementData = [0, 1, 2, 2, 3, 0]
        @vertexData = [-1, -1, 1, -1, 1, 1, -1, 1]
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bufferData gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(elementData), gl.STATIC_DRAW
        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
        gl.bufferData gl.ARRAY_BUFFER, new Float32Array(@vertexData), gl.STATIC_DRAW

        @updateAttribsAndUniforms()

        @localTime = 0

    updateAttribsAndUniforms: ->
        gl = @gl
         # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)

        gl.useProgram @shader.program
        @vertexPos = gl.getAttribLocation @shader.program, 'vertexPosition'
        @time = gl.getUniformLocation @shader.program, 'time'
        @sunwalk = gl.getUniformLocation @shader.program, 'sunwalk'

        # restore state
        gl.useProgram oldProg

    render: (camera, baseTexture) ->
        gl = @gl
        gl.disable gl.BLEND
        gl.disable gl.DEPTH_TEST
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer

        # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)
        if @shader.recompile
            @shader.doRecompile()
            @updateAttribsAndUniforms()
        gl.useProgram @shader.program
        gl.vertexAttribPointer @vertexPos, 2, gl.FLOAT, false, 8, 0
        gl.enableVertexAttribArray @vertexPos

        gl.activeTexture gl.TEXTURE1
        gl.bindTexture gl.TEXTURE_2D, baseTexture._glTextures[gl.id]

        gl.uniform1i @sunwalk, 1

        @localTime += 0.0016
        gl.uniform1f @time, @localTime

        gl.drawElements gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, 0

        gl.bindTexture gl.TEXTURE_2D, null
        gl.activeTexture gl.TEXTURE0
        gl.enable gl.BLEND
        #gl.enable gl.DEPTH_TEST

        # restore state
        gl.useProgram oldProg

class PointShader
    constructor: (@gl) ->
        settings.addShader "Sun", this
        colors = [
            [0, 0.2, 255, 251, 221]
            [1, 0.5, 255, 238, 10]
            [2, 99.1, 250, 176, 3]
            ]

        @fs = [
            'precision highp float;'
            'uniform float time;'
            'uniform mat4 model;'
            'varying vec2 vPos;'
            'uniform sampler2D sunwalk;'
            'void main(void) {'
            '    float l = length(vPos);'
                'vec4 color;'
                'float colTime = 0.0;'
                'colTime = 1.0 - exp((-200.0-model[3][1])/400.0);'
            ]
        for color in colors
            [i, d, r, g, b] = color
            @fs.push "if (l < #{d}) {"
            @fs.push "    float t = time*15.0;"
            @fs.push "    float time0 = floor(t);"
            @fs.push "    float time1 = floor(t) + 1.0;"
            @fs.push "    vec4 color_t0 = texture2D(sunwalk, vec2(time0/39.0, 1.0 - 0.22*(#{i}.0)));"
            @fs.push "    vec4 color_t1 = texture2D(sunwalk, vec2((time1)/39.0, 1.0 - 0.22*(#{i}.0)));"
            @fs.push "    float diff0 = 1.0 - (t - time0);"
            @fs.push "    float diff1 = 1.0 - (time1 - t);"
            @fs.push "    vec4 color_t = vec4(color_t1.r*diff1 + color_t0.r*diff0, color_t1.g*diff1 + color_t0.g*diff0, color_t1.b*diff1 + color_t0.b*diff0, 1);"
            @fs.push "    gl_FragColor = color_t;"
            @fs.push "    return;}"
        @fs.push '}'

        @vs = [
            'attribute vec2 vertexPosition;'

            'uniform float time;'

            'varying vec2 vPos;'
            'uniform mat4 view;'
            'uniform mat4 model;'

            'void main(void) {'
            '    float l = length(vertexPosition);'
            '    vec2 offset = vec2(0.0, 0.0);'
                'if (l > 0.5) { offset.x = 0.1;}'
            '    float inita = atan(vertexPosition.y, vertexPosition.x + offset.x);'
            '    float dt = inita + time*15.0*(l*l*2.5);'
            '    vec2 pos = vec2(cos(dt)*l, sin(dt)*l);'
            '    gl_Position = view*model*vec4(pos, 0, 1);'
            '    gl_PointSize = 10.0;'
            '    vPos = pos;'
            '}'
        ]
        @doRecompile()
    doRecompile: ->
        @program = PIXI.compileProgram @gl, @vs, @fs
        console.log (@gl.getProgramInfoLog @program)
        @recompile = false

randomRange = (a, b) ->
    Math.random()*(b - a) + a

class PointRenderer
    constructor: (@gl, @width, @height) ->
        gl = @gl
        @vertexBuffer = gl.createBuffer()
        @indexBuffer = gl.createBuffer()
        @shader = new PointShader @gl

        frp.sync =>
            timeFull = 20000
            @x = frp.accum (-500), (tick.map (dt) -> (x) -> x + dt*1000/timeFull)
            time = frp.accum 0, (tick.map (dt) -> (t) -> dt + t)
            @y = frp.accum 300, (tick.snapshot time, (dt, t) -> (oldY) ->
                if oldY > 200
                    y = 300 - Math.exp(t/timeFull*5.2983)
                else
                    y = oldY - 200*dt/4000
                ) #frp.accum (-400), (tick.map (dt) -> (y) -> y + dt)

    upload: ->
        gl = @gl

        @num = 1000
        elementData = [0..@num]
        @vertexData = []
        for i in [0..(@num)]
            x = randomRange -0.6, 0.6
            y = randomRange -0.6, 0.6
            @vertexData.push x
            @vertexData.push y
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bufferData gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(elementData), gl.STATIC_DRAW
        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
        gl.bufferData gl.ARRAY_BUFFER, new Float32Array(@vertexData), gl.STATIC_DRAW

        @updateAttribsAndUniforms()

        @localTime = 0

    updateAttribsAndUniforms: ->
        gl = @gl
         # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)

        gl.useProgram @shader.program
        @vertexPos = gl.getAttribLocation @shader.program, 'vertexPosition'
        @time = gl.getUniformLocation @shader.program, 'time'
        @view = gl.getUniformLocation @shader.program, 'view'
        @model = gl.getUniformLocation @shader.program, 'model'
        @sunwalk = gl.getUniformLocation @shader.program, 'sunwalk'

        # restore state
        gl.useProgram oldProg

    render: (camera, baseTexture) ->
        gl = @gl
        gl.disable gl.BLEND
        gl.disable gl.DEPTH_TEST
        gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
        gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer

        # save state
        oldProg = gl.getParameter(gl.CURRENT_PROGRAM)
        if @shader.recompile
            @shader.doRecompile()
            @updateAttribsAndUniforms()
        gl.useProgram @shader.program
        gl.vertexAttribPointer @vertexPos, 2, gl.FLOAT, false, 8, 0
        gl.enableVertexAttribArray @vertexPos

        gl.activeTexture gl.TEXTURE1
        gl.bindTexture gl.TEXTURE_2D, baseTexture._glTextures[gl.id]

        gl.uniform1i @sunwalk, 1

        @localTime += 0.0016
        gl.uniform1f @time, @localTime
        ratio = camera.height/camera.width
        viewMat = new Float32Array [
            1/camera.width, 0, 0, 0
            0, 1/camera.height, 0, 0
            0, 0, 1, 0
            0, 0, 0, 1
            ]
        modelMat = new Float32Array [
            300, 0, 0, 0
            0, 300, 0, 0
            0, 0, 1, 0
            @x.value(), @y.value(), 0, 1
            ]
        gl.uniformMatrix4fv @view, false, viewMat
        gl.uniformMatrix4fv @model, false, modelMat

        gl.drawElements gl.POINTS, @num, gl.UNSIGNED_SHORT, 0

        gl.bindTexture gl.TEXTURE_2D, null
        gl.activeTexture gl.TEXTURE0
        gl.enable gl.BLEND
        #gl.enable gl.DEPTH_TEST

        # restore state
        gl.useProgram oldProg

class SunVertex
    constructor: (data) ->
        @data = data
        @attribs =
            vertexPosition: [2, gl.FLOAT, false, 8, 0]

    upload: ->
        data = []

        for key, attrib of attribs
            break
    
        for elem in data
            break
        #new Float32Array

class RenderManager
    constructor: (@gl) ->

init = (gl) ->
    Phaser.TextureManager = new TextureManager gl
    Phaser.TextureManager.markUnitUsed gl.TEXTURE0

module.exports =
    init:init
    TextureManager:TextureManager
    BufferManager:BufferManager
    LineRenderer:LineRenderer
    PointRenderer:PointRenderer
    BackgroundRenderer:BackgroundRenderer
    
