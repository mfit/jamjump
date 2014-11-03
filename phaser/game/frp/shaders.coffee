class TestFilter extends PIXI.AbstractFilter
    constructor: (r, g, b, a=1) ->
        PIXI.AbstractFilter.call this
        this.uniforms =
            color:
                type: '4f'
                value: {x:r/255.0, y:g/255.0, z:b/255.0, w:a}
        @fragmentSrc = [
            'precision mediump float;'
            'uniform vec4 color;'
            'void main () {'
            '   gl_FragColor = color;'
            '}'
        ] 

class ColorFilter extends PIXI.AbstractFilter
    constructor: (color) ->
        PIXI.AbstractFilter.call this
        this.uniforms =
            color:
                type: '3f'
                value: color
        @fragmentSrc = [
                'precision mediump float;'
                'varying vec2 vTextureCoord;'
                'varying vec4 vColor;'
                'uniform sampler2D uSampler;'
                'uniform vec3 color;'
                'void main(void) {'
                '    vec4 texColor = texture2D(uSampler, vTextureCoord);' 
                '    texColor.r *= color.r;'
                '    texColor.g *= color.g;'
                '    texColor.b *= color.b;'
                '    gl_FragColor = vec4(texColor);'
                '}'
            ]


class IntensityFilter extends PIXI.AbstractFilter
    constructor: (intensity, color) ->
        PIXI.AbstractFilter.call this
        this.uniforms =
            intensity:
                type: '1f'
                value: intensity
            relPos:
                type: '2f'
                value: {x:0, y:0}
            color:
                type: '3f'
                value: color
        @fragmentSrc = [
                'precision mediump float;'
                'varying vec2 vTextureCoord;'
                'varying vec4 vColor;'
                'uniform sampler2D uSampler;'
                'uniform vec2 relPos;'
                'uniform float intensity;'
                'uniform vec3 color;'
                'void main(void) {'
                '    float angle = atan(relPos.y, relPos.x);'
                '    vec4 texColor = texture2D(uSampler, vTextureCoord);' 
                '    float sprAngle = (texColor.r)*3.14;'
                '    float newIntensity = abs(angle - sprAngle)/3.14;'
                '    gl_FragColor = vec4(color, texColor.a*newIntensity);'
                '}'
            ]

module.exports =
    TestFilter:TestFilter
    IntensityFilter:IntensityFilter
    ColorFilter:ColorFilter
