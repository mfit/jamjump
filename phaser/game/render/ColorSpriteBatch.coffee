class ColorShader extends PIXI.PixiFastShader
    constructor: (gl, color) ->
        @_UID = PIXI._UID++
        @gl = gl
        @program = null

        @fragmentSrc = [
            'precision mediump float;',
            #'varying vec2 vTextureCoord;',
            #'varying float vColor;',
            'uniform sampler2D uSampler;',
            'uniform vec4 color;'
            'void main(void) {',
            '   gl_FragColor = color; //texture2D(uSampler, vTextureCoord) * vColor ;',
            '}'
        ];

        @vertexSrc = [
            'attribute vec2 aVertexPosition;',
            'attribute vec2 aPositionCoord;',
            'attribute vec2 aScale;',
            'attribute float aRotation;',
            'attribute vec2 aTextureCoord;',
            'attribute float aColor;',

            'uniform vec2 projectionVector;',
            'uniform vec2 offsetVector;',
            'uniform mat3 uMatrix;',

            'varying vec2 vTextureCoord;',
            'varying float vColor;',

            'const vec2 center = vec2(-1.0, 1.0);',

            'void main(void) {',
            '   vec2 v;',
            '   vec2 sv = aVertexPosition * aScale;',
            '   v.x = (sv.x) * cos(aRotation) - (sv.y) * sin(aRotation);',
            '   v.y = (sv.x) * sin(aRotation) + (sv.y) * cos(aRotation);',
            '   v = ( uMatrix * vec3(v + aPositionCoord , 1.0) ).xy ;',
            '   gl_Position = vec4( ( v / projectionVector) + center , 0.0, 1.0);',
            '   vTextureCoord = aTextureCoord;',
            '   vColor = aColor;',
            '}'
        ];
    
        @init()
        @color = @gl.getUniformLocation @program, 'color' 
        @gl.uniform4f @color, color.r, color.g, color.b, color.a

class ColorSpriteBatch
    constructor: (game, @color, parent=game.world, name='group', addToStage=false) ->

        PIXI.SpriteBatch.call this
        Phaser.Group.call this, game, parent, name, addToStage
        @type = Phaser.SPRITEBATCH

ColorSpriteBatch:: = Phaser.Utils.extend true, ColorSpriteBatch::, Phaser.Group::, PIXI.SpriteBatch::
ColorSpriteBatch::_renderWebGL = (renderSession) ->
        if (not @visible) or (@alpha <= 0) or (not @children.length)
            return
        if (not @ready)
            @initWebGL renderSession.gl
        renderSession.spriteBatch.stop()
        renderSession.shaderManager.setShader(@shader)
        @fastSpriteBatch.begin(this, renderSession)
        @fastSpriteBatch.render(this)
        renderSession.spriteBatch.start()       

ColorSpriteBatch::initWebGL = (gl) ->
        shader = new ColorShader gl, @color
        @fastSpriteBatch = new PIXI.WebGLFastSpriteBatch gl
        @fastSpriteBatch.begin = (spriteBatch, @renderSession) ->
            @shader = shader
            @matrix = spriteBatch.worldTransform.toArray true
            @start()
        @fastSpriteBatch.start = ->
            @gl.activeTexture @gl.TEXTURE0
            @gl.bindBuffer @gl.ARRAY_BUFFER, @vertexBuffer
            @gl.bindBuffer @gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
            projection = @renderSession.projection
            @gl.uniform2f @shader.projectionVector, projection.x, projection.y
            @gl.uniformMatrix3fv @shader.uMatrix, false, @matrix
            stride = this.vertSize * 4
            @gl.vertexAttribPointer @shader.aVertexPosition, 2, gl.FLOAT, false, stride, 0
            @gl.vertexAttribPointer @shader.aPositionCoord, 2, gl.FLOAT, false, stride, 2 * 4
            @gl.vertexAttribPointer @shader.aScale, 2, gl.FLOAT, false, stride, 4 * 4
            @gl.vertexAttribPointer @shader.aRotation, 1, gl.FLOAT, false, stride, 6 * 4
            if @shader.aTextureCoord != -1
                @gl.vertexAttribPointer @shader.aTextureCoord, 2, gl.FLOAT, false, stride, 7*4
            # if @shader.colorAttribute != -1 
            #     @gl.vertexAttribPointer @shader.colorAttribute, 1, gl.FLOAT, false, stride, 9 * 4

        @shader = shader
        @ready = true


module.exports =
    ColorSpriteBatch: ColorSpriteBatch
