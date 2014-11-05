renderer = require ('../render/CustomRenderer.js')
class BlockShader extends PIXI.PixiFastShader
    constructor: (gl) ->
        @_UID = PIXI._UID++
        @gl = gl
        @program = null

        @fragmentSrc = [
            'precision lowp float;',
            'varying vec2 vTextureCoord;',
            'varying float vColor;',
            'uniform sampler2D uSampler;',
            'void main(void) {',
            '   gl_FragColor = texture2D(uSampler, vTextureCoord) * vColor ;',
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

class BlockSpriteBatch
    constructor: (game, @color, parent=game.world, name='group', addToStage=false) ->

        PIXI.SpriteBatch.call this
        Phaser.Group.call this, game, parent, name, addToStage
        @type = Phaser.SPRITEBATCH

BlockSpriteBatch:: = Phaser.Utils.extend true, BlockSpriteBatch::, Phaser.Group::, PIXI.SpriteBatch::
BlockSpriteBatch::_renderWebGL = (renderSession) ->
        if (not @visible) or (@alpha <= 0) or (not @children.length)
            return
        if (not @ready)
            @initWebGL renderSession.gl
        #renderSession.shaderManager.setShader(@shader)
        #@fastSpriteBatch.begin(this, renderSession)
        #@fastSpriteBatch.render(this)

        ids = {}

        renderSession.spriteBatch.stop()       

        @bm.render()
        # for child in @children
        #     if (not child.tilingTexture) or (child.refreshTexture)
        #         child.generateTilingTexture true

        #         if (child.tilingTexture) and (child.tilingTexture.needsUpdate)
        #             PIXI.updateWebGLTexture child.tilingTexture.baseTexture, renderSession.gl
        #             child.tilingTexture.needsUpdate = false

        #         if @tm_texture_hack == false
        #             @tm.createGLTexture child.tilingTexture.baseTexture
        #             @tm.uploadTexture child.tilingTexture.baseTexture
        #             @tm.printDebug()
        #             @tm_texture_hack = true
        #     else
        #         renderSession.spriteBatch.renderTilingSprite child


BlockSpriteBatch::initWebGL = (gl) ->
    @tm = new renderer.TextureManager gl
    @tm.markUnitUsed gl.TEXTURE0
    @tm_texture_hack = false
    currentProg = gl.getParameter gl.CURRENT_PROGRAM
    shader = new BlockShader gl
    gl.useProgram currentProg

    @bm = new renderer.BufferManager gl
    @bm.upload()

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
        if @shader.colorAttribute != -1 
            @gl.vertexAttribPointer @shader.colorAttribute, 1, gl.FLOAT, false, stride, 9 * 4

    @shader = shader
    @ready = true

module.exports =
    BlockSpriteBatch: BlockSpriteBatch

