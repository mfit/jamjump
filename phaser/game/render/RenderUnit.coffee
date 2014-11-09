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
    @bm.render()

RenderUnit::initWebGL = (gl) ->
    @bm = new renderer.LineRenderer gl
    @bm.upload()
    @ready = true
    
module.exports =
    RenderUnit:RenderUnit
