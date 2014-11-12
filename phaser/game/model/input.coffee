frp = require '../frp/frp.js'
player = require '../frp/player_behaviors.js'

class Input
    constructor: (@game) ->
        @keyboard = @game.input.keyboard
        @keyboard.addKeyCapture Phaser.Keyboard.SPACE

        @keyDownEvent = {}
        @keyUpEvent = {}

        keys = 'ABCDEFGHIKJLMNOPQRSTUVWXYZ'
        for key in keys
            @keyUpEvent[key] = new frp.EventStream
            @keyDownEvent[key] = new frp.EventStream
        @mkKeys()

    mkKeys: ->
        @keys = {}
        @keys['A'] = @keyboard.addKey Phaser.Keyboard.A
        @keys['B'] = @keyboard.addKey Phaser.Keyboard.B
        @keys['C'] = @keyboard.addKey Phaser.Keyboard.C
        @keys['D'] = @keyboard.addKey Phaser.Keyboard.D
        @keys['E'] = @keyboard.addKey Phaser.Keyboard.E
        @keys['F'] = @keyboard.addKey Phaser.Keyboard.F
        @keys['G'] = @keyboard.addKey Phaser.Keyboard.G
        @keys['H'] = @keyboard.addKey Phaser.Keyboard.H
        @keys['I'] = @keyboard.addKey Phaser.Keyboard.I
        @keys['J'] = @keyboard.addKey Phaser.Keyboard.J
        @keys['K'] = @keyboard.addKey Phaser.Keyboard.K
        @keys['L'] = @keyboard.addKey Phaser.Keyboard.L
        @keys['M'] = @keyboard.addKey Phaser.Keyboard.M
        @keys['N'] = @keyboard.addKey Phaser.Keyboard.N
        @keys['O'] = @keyboard.addKey Phaser.Keyboard.O
        @keys['P'] = @keyboard.addKey Phaser.Keyboard.P
        @keys['Q'] = @keyboard.addKey Phaser.Keyboard.Q
        @keys['R'] = @keyboard.addKey Phaser.Keyboard.R
        @keys['S'] = @keyboard.addKey Phaser.Keyboard.S
        @keys['T'] = @keyboard.addKey Phaser.Keyboard.T
        @keys['U'] = @keyboard.addKey Phaser.Keyboard.U
        @keys['V'] = @keyboard.addKey Phaser.Keyboard.V
        @keys['W'] = @keyboard.addKey Phaser.Keyboard.W
        @keys['X'] = @keyboard.addKey Phaser.Keyboard.X
        @keys['Y'] = @keyboard.addKey Phaser.Keyboard.Y
        @keys['Z'] = @keyboard.addKey Phaser.Keyboard.Z
        @keys['SPACE'] = @keyboard.addKey Phaser.Keyboard.SPACE

        for key of @keys
            @keys[key].onDown.add ((k) => =>
                d = new Date()
                frp.sync (=> @keyDownEvent[k].send d)
                ) key
            @keys[key].onUp.add ((k) => =>
                d = new Date()
                frp.sync (=> @keyUpEvent[k].send d)
                ) key

    removeKeys: ->
        @keys['A'] = @keyboard.removeKey Phaser.Keyboard.A
        @keys['B'] = @keyboard.removeKey Phaser.Keyboard.B
        @keys['C'] = @keyboard.removeKey Phaser.Keyboard.C
        @keys['D'] = @keyboard.removeKey Phaser.Keyboard.D
        @keys['E'] = @keyboard.removeKey Phaser.Keyboard.E
        @keys['F'] = @keyboard.removeKey Phaser.Keyboard.F
        @keys['G'] = @keyboard.removeKey Phaser.Keyboard.G
        @keys['H'] = @keyboard.removeKey Phaser.Keyboard.H
        @keys['I'] = @keyboard.removeKey Phaser.Keyboard.I
        @keys['J'] = @keyboard.removeKey Phaser.Keyboard.J
        @keys['K'] = @keyboard.removeKey Phaser.Keyboard.K
        @keys['L'] = @keyboard.removeKey Phaser.Keyboard.L
        @keys['M'] = @keyboard.removeKey Phaser.Keyboard.M
        @keys['N'] = @keyboard.removeKey Phaser.Keyboard.N
        @keys['O'] = @keyboard.removeKey Phaser.Keyboard.O
        @keys['P'] = @keyboard.removeKey Phaser.Keyboard.P
        @keys['Q'] = @keyboard.removeKey Phaser.Keyboard.Q
        @keys['R'] = @keyboard.removeKey Phaser.Keyboard.R
        @keys['S'] = @keyboard.removeKey Phaser.Keyboard.S
        @keys['T'] = @keyboard.removeKey Phaser.Keyboard.T
        @keys['U'] = @keyboard.removeKey Phaser.Keyboard.U
        @keys['V'] = @keyboard.removeKey Phaser.Keyboard.V
        @keys['W'] = @keyboard.removeKey Phaser.Keyboard.W
        @keys['X'] = @keyboard.removeKey Phaser.Keyboard.X
        @keys['Y'] = @keyboard.removeKey Phaser.Keyboard.Y
        @keys['Z'] = @keyboard.removeKey Phaser.Keyboard.Z

# differs from ControllerInput in the way the events fire
class KeyboardInput
    constructor: (@inputConfig, @worldConfig) ->
        @unlisten = null
        @commands = []

    executeCommands: ->
        for command in @commands
            frp.sync command
        @commands = []

    mkBehaviors: ->
        if @unlisten
            @unlisten()

        unlistenMove = @mkMovement()
        unlistenJump = @mkJumping()
        unlistenAbility = @mkAbility()

        @unlisten = ->
            unlistenMove()
            unlistenJump()
            unlistenAbility()

    mkAbility: ->
        abilityDown = @inputConfig.abilityDown
        abilityUp = @inputConfig.abilityUp
        [abDown, abUp] = KeyboardInput.mkSimple abilityDown, abilityUp
        unlistenAbility = abilityDown.listen (_) =>
            @commands.push (=>@worldConfig.ability.send true)
        return unlistenAbility

    mkJumping: ->
        jumpDown = @inputConfig.jumpDown
        jumpUp = @inputConfig.jumpUp
        [jumpDown, jumpUp] = KeyboardInput.mkSimple jumpDown, jumpUp

        unlistenJump = jumpDown.listen (_) => @commands.push (=>@worldConfig.jump.send (true))
        return unlistenJump

    mkMovement: ->
        moveLeftDown = @inputConfig.moveLeftDown
        moveLeftUp = @inputConfig.moveLeftUp
        moveRightDown = @inputConfig.moveRightDown
        moveRightUp = @inputConfig.moveRightUp

        [moveLeftDown, moveLeftUp] = KeyboardInput.mkSimple moveLeftDown, moveLeftUp
        [moveRightDown, moveRightUp] = KeyboardInput.mkSimple moveRightDown, moveRightUp

        @movingX = frp.accumAll 0, [
            moveLeftDown.constMap (a) -> a - 1
            moveRightDown.constMap (a) -> a + 1

            moveLeftUp.constMap (a) -> a + 1
            moveRightUp.constMap (a) -> a - 1
            ]

        @lastDir = frp.hold 0, @movingX.updates() # is delayed!
        @updateMoveEvent = frp.snapshot (@movingX.updates()), @lastDir, ((x, oldX) -> x != oldX)
        @updateMove = frp.hold false, @updateMoveEvent

        unlistenMove = (@movingX.updates().delay().gate @updateMove).listen (x) =>
            @commands.push (=>
                if x == 0
                    @worldConfig.move.send (new player.StopMoveEvent)
                else
                    @worldConfig.move.send (new player.MoveEvent x, 0)
            )

        return unlistenMove

    @mkSimple: (keyEventDown, keyEventUp) ->
        keyEventDown = keyEventDown.mkUpdateEvent()
        keyEventUp = keyEventUp.mkUpdateEvent()

        pressed = frp.holdAll false, [(keyEventDown.constMap true), (keyEventUp.constMap false)]
        keyDown = keyEventDown.gate (pressed.not())
        keyUp = keyEventUp.gate pressed

        return [keyDown, keyUp]

class ControllerInput
    constructor: ->

module.exports =
    KeyboardInput:KeyboardInput
    Input:Input
