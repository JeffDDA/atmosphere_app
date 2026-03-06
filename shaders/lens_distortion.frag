#include <flutter/runtime_effect.glsl>

// Uniforms
uniform vec2 uResolution;    // viewport size in pixels
uniform vec2 uLensCenter;    // lens center in pixels
uniform float uLensRadius;   // lens radius in pixels
uniform float uStrength;     // 0.0 = no distortion, 1.0 = full
uniform float uFocalDepth;   // inner fraction with no distortion (0.75)
uniform float uChromatic;    // 0.0 = off, 1.0 = on

// Grid texture
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // Vector from lens center to this fragment (in pixels)
    vec2 delta = fragCoord - uLensCenter;
    float dist = length(delta);

    // Normalized distance within lens (0 = center, 1 = edge)
    float normDist = dist / uLensRadius;

    if (normDist >= 1.0 || uStrength <= 0.0) {
        // Outside lens or lens inactive — sample directly
        fragColor = texture(uTexture, uv);
        return;
    }

    // Inner focal zone (0..focalDepth) = no distortion
    // Outer ring (focalDepth..1.0) = cubic barrel ramp
    float distortionAmount = 0.0;
    if (normDist > uFocalDepth) {
        float t = (normDist - uFocalDepth) / (1.0 - uFocalDepth); // 0..1 in outer ring
        distortionAmount = t * t * t; // cubic ramp
    }

    // Barrel distortion: push pixels outward from center
    float barrel = 1.0 + distortionAmount * uStrength * 0.4;
    vec2 distortedUV = uLensCenter / uResolution + (delta / uResolution) * barrel;

    if (uChromatic > 0.5) {
        // Chromatic aberration: offset red and blue channels slightly
        float chromOffset = distortionAmount * uStrength * 0.003;
        vec2 redUV = uLensCenter / uResolution + (delta / uResolution) * (barrel + chromOffset);
        vec2 blueUV = uLensCenter / uResolution + (delta / uResolution) * (barrel - chromOffset);
        float r = texture(uTexture, redUV).r;
        float g = texture(uTexture, distortedUV).g;
        float b = texture(uTexture, blueUV).b;
        float a = texture(uTexture, distortedUV).a;
        fragColor = vec4(r, g, b, a);
    } else {
        fragColor = texture(uTexture, distortedUV);
    }
}
