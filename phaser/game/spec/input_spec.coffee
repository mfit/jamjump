frp = require '../frp/frp.js'
player = require '../frp/player_behaviors.js'
input = require '../model/input.js'

moveEventEqual = (lhs, rhs) ->
    if lhs == null && rhs == null
        return true
    else if lhs == null 
        return false
    else if rhs == null
        return false

    if (lhs.constructor == player.MoveEvent) && (rhs.constructor == player.MoveEvent)
        return (lhs.dir.x == rhs.dir.x)  and (lhs.dir.y == rhs.dir.y)
    if (lhs.constructor == player.StopMoveEvent) && (rhs.constructor = player.StopMoveEvent)
        return (lhs.dir.x == rhs.dir.x)  and (lhs.dir.y == rhs.dir.y)
 
    return lhs == rhs   

leftDown = new frp.EventStream()
leftUp = new frp.EventStream()
rightDown = new frp.EventStream()
rightUp = new frp.EventStream()

inputConfig =
    moveLeftDown: leftDown
    moveLeftUp: leftUp
    moveRightDown: rightDown
    moveRightUp: rightUp

worldConfig =
    move: new frp.EventStream()

describe "User input", ->
    beforeEach (-> jasmine.addCustomEqualityTester moveEventEqual)
    it "test move states", ->
        lastMove = null
        worldConfig.move.listen ((m) -> lastMove = m)

        inp = new input.KeyboardInput inputConfig, worldConfig
        frp.sync (-> inp.mkBehaviors())

        frp.sync (-> leftDown.send true)
        (expect inp.movingX.value()).toEqual -1
        (expect inp.lastDir.value()).toEqual -1
        (expect inp.updateMove.value()).toEqual true 
        (expect lastMove).toEqual (new player.MoveEvent -1, 0) 
        lastMove = null

        frp.sync (-> leftUp.send true)
        (expect inp.movingX.value()).toEqual 0
        (expect inp.lastDir.value()).toEqual 0
        (expect inp.updateMove.value()).toEqual true
        (expect lastMove).toEqual (new player.StopMoveEvent)
        lastMove = null

        frp.sync (->
            leftDown.send true
            leftDown.send true
            )
        (expect inp.movingX.value()).toEqual -1
        (expect inp.lastDir.value()).toEqual -1
        (expect inp.updateMove.value()).toEqual true 
        (expect lastMove).toEqual (new player.MoveEvent -1, 0) 
        lastMove = null
