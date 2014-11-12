renderer = require ('../render/CustomRenderer.js')

class RenderUnit
    constructor: (game, parent=game.world, name='group', addToStage=false) ->
        PIXI.SpriteBatch.call this
        Phaser.Group.call this, game, parent, name, addToStage
        @type = Phaser.SPRITEBATCH

RenderUnit:: = Phaser.Utils.extend true, RenderUnit::, Phaser.Group::, PIXI.SpriteBatch::
RenderUnit::_renderWebGL = (renderSession) ->
    if (not @visible) or (@alpha <= 0)
        return
    if (not @ready)
        @initWebGL renderSession.gl
    renderSession.spriteBatch.stop()       
    @bm3.render @game.camera, @img.texture.baseTexture
    @bm.render()
    @bm2.render @game.camera, @img.texture.baseTexture

RenderUnit::initWebGL = (gl) ->
    renderer.init gl
    @bm = new renderer.LineRenderer gl
    @bm2 = new renderer.PointRenderer gl, @game.camera.view.width, @game.camera.view.height
    @bm3 = new renderer.BackgroundRenderer gl, @game.camera.view.width, @game.camera.view.height

    @img = @game.add.sprite 0, 0, 'sunwalk'
    console.log @img.texture
    Phaser.TextureManager.createGLTexture @img.texture.baseTexture
    Phaser.TextureManager.uploadTexture @img.texture.baseTexture

    
    @bm.upload()
    @bm2.upload()
    @bm3.upload()
    @ready = true
    
module.exports =
    RenderUnit:RenderUnit
