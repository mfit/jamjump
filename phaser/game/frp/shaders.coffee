class TestFilter extends PIXI.AbstractFilter
    constructor: (r, g, b) ->
        PIXI.AbstractFilter.call this
        this.uniforms =
            color:
                type: '3f'
                value: {x:r/255.0, y:g/255.0, z:b/255.0}
        @fragmentSrc = [
            'precision mediump float;'
            'uniform vec3 color;'
            'void main () {'
            '   gl_FragColor = vec4(color, 1);'
            '}'
        ] 

class IntensityFilter extends PIXI.AbstractFilter
    constructor: (intensity) ->
        PIXI.AbstractFilter.call this
        this.uniforms =
            intensity:
                type: '1f'
                value: intensity
            relPos:
                type: '2f'
                value: {x:0, y:0}
        @fragmentSrc = [
                'precision mediump float;'
                'varying vec2 vTextureCoord;'
                'varying vec4 vColor;'
                'uniform sampler2D uSampler;'
                'uniform vec2 relPos;'
                'uniform float intensity;'
                'void main(void) {'
                '    float angle = atan(relPos.y, relPos.x);'
                '    vec4 color = texture2D(uSampler, vTextureCoord);' 
                '    float sprAngle = (color.r)*3.14;'
                '    float newIntensity = abs(angle - sprAngle)/3.14;'
                '    gl_FragColor = vec4(1, 1, 0.8, color.a*newIntensity);'
                '}'
            ]

module.exports =
    TestFilter:TestFilter
    IntensityFilter:IntensityFilter
