try {
    if (!PIXI) return;
} 
catch(_) {
    PIXI = {
        AbstractFilter:{}
        }
}


module.exports = PIXI
