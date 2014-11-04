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

        delete @free_active[unit]

        @imageUnitStats[unit] = {
            created: new Date().getTime()
            texture: null
            size: 0
        }
    
        return unit
    
    createGLTexture: (texture) ->
        gl = @gl
        textureId = gl.createTexture()
        #texture._glTextures[gl.id] = textureId

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

class BufferManager
    constructor: ->

module.exports =
    TextureManager:TextureManager
    
