frp = require '../frp/frp.js'
player = require '../frp/player_behaviors.js'
world = require '../frp/world_behaviors.js'
tick = frp.tick
    
describe "Player behaviors", ->
    it "tests basic block setting properties", ->
        setBlockEvent = new frp.EventStream()
        blockSet = false

        blockSetter = frp.sync (-> new player.BlockSetter tick, setBlockEvent)
        blockSetter.blockSet.listen (_) -> blockSet = true

        (expect blockSetter.blockpower.value()).toBe 0

        for i in [0..20]
            frp.sync (-> tick.send 16)
        (expect blockSetter.blockpower.value()).toBe (21*16)

        frp.sync (-> setBlockEvent.send true)
        #frp.sync (-> tick.send 16)
        (expect blockSet).toBe true
        (expect blockSetter.blockpower.value()).toBe (21*16 - blockSetter.BLOCKCOST)

        frp.sync (-> tick.send 1000)
        (expect blockSetter.blockpower.value()).toBe blockSetter.MAXPOWER

    it "test server world", ->
        w = new world.World
        
