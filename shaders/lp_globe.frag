#include <flutter/runtime_effect.glsl>

// Uniforms
uniform vec2  uResolution;
uniform float uYaw;        // rotation around Y axis (radians)
uniform float uZoom;       // camera distance
uniform float uPanY;       // vertical camera offset
uniform sampler2D uAtlas;

out vec4 fragColor;

// ── Constants ──────────────────────────────────────────────────────────────────
const float PI       = 3.14159265;
const float TWO_PI   = 6.28318530;
const float DEG2RAD  = PI / 180.0;
const float FOV_DEG  = 50.0;
const float CYL_R    = 1.0;          // cylinder radius
const float CYL_H    = 1.22;         // half-height — correct ratio for 140° lat span
// Atlas covers lat 75°N (V=0) to -65°S (V=1) — 140° range, offset +5° north
const float LAT_TOP  =  75.0;        // degrees
const float LAT_BOT  = -65.0;        // degrees
const float LAT_SPAN = 140.0;        // LAT_TOP - LAT_BOT
const vec3  BG_COLOR = vec3(0.024, 0.024, 0.055); // #06060e
const vec3  SUN_DIR  = normalize(vec3(0.7, 0.3, 0.6));
const vec3  RIM_COL  = vec3(0.12, 0.20, 0.45);

// ── Procedural star hash ───────────────────────────────────────────────────────
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float starField(vec2 uv) {
  vec2 cell = floor(uv * 120.0);
  float h = hash(cell);
  if (h > 0.985) {
    vec2 center = (cell + 0.5) / 120.0;
    float d = length(uv - center) * 120.0;
    float brightness = (h - 0.985) / 0.015;
    return smoothstep(0.6, 0.0, d) * brightness * 0.7;
  }
  return 0.0;
}

// ── Ray-cylinder intersection ──────────────────────────────────────────────────
// Infinite cylinder along Y axis with radius CYL_R, capped at ±CYL_H.
// Returns t (distance) or -1.0 on miss. Also outputs normal via outN.
float rayCylinder(vec3 ro, vec3 rd, out vec3 outN) {
  // Solve ray vs infinite cylinder x²+z²=R² (ignoring Y)
  float a = rd.x * rd.x + rd.z * rd.z;
  float b = 2.0 * (ro.x * rd.x + ro.z * rd.z);
  float c = ro.x * ro.x + ro.z * ro.z - CYL_R * CYL_R;
  float disc = b * b - 4.0 * a * c;

  if (disc < 0.0) return -1.0;

  float sqrtDisc = sqrt(disc);
  float t0 = (-b - sqrtDisc) / (2.0 * a);
  float t1 = (-b + sqrtDisc) / (2.0 * a);

  // Check front intersection
  float t = t0;
  vec3 hit = ro + rd * t;

  if (t > 0.0 && abs(hit.y) <= CYL_H) {
    outN = normalize(vec3(hit.x, 0.0, hit.z));
    return t;
  }

  // Check back intersection (for edges)
  t = t1;
  hit = ro + rd * t;
  if (t > 0.0 && abs(hit.y) <= CYL_H) {
    outN = normalize(vec3(hit.x, 0.0, hit.z));
    return t;
  }

  return -1.0;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = (fragCoord - 0.5 * uResolution) / uResolution.x;

  // Camera
  float fovRad = FOV_DEG * DEG2RAD;
  float focalLen = 1.0 / tan(fovRad * 0.5);
  vec3 ro = vec3(0.0, uPanY, -uZoom);
  vec3 rd = normalize(vec3(uv, focalLen));

  // Ray-cylinder intersection
  vec3 normal;
  float t = rayCylinder(ro, rd, normal);

  if (t < 0.0) {
    // ── Miss: background + stars ──
    float star = starField(uv * 2.0 + 0.5);
    vec3 col = BG_COLOR + vec3(star);
    fragColor = vec4(col, 1.0);
    return;
  }

  // ── Hit: cylinder surface ──
  vec3 hit = ro + rd * t;
  vec3 viewDir = normalize(-rd);

  // Angle around cylinder → longitude, height → latitude
  // Apply yaw rotation to get atlas-local angle (negate to flip east-west)
  float angle = -(atan(hit.x, hit.z) - uYaw);
  float atlasU = angle / TWO_PI + 0.5;
  // Wrap U to [0,1]
  atlasU = fract(atlasU);

  // Height → V: Flutter textures use OpenGL convention (V=0 at bottom)
  // y=+CYL_H (top/north) → V=1.0 (top of image in Flutter)
  // y=-CYL_H (bottom/south) → V=0.0 (bottom of image in Flutter)
  float atlasV = (hit.y + CYL_H) / (2.0 * CYL_H);

  // Sample atlas texture
  vec3 texCol = texture(uAtlas, vec2(atlasU, atlasV)).rgb;

  // ── Dark blue base (ocean/land) ──
  vec3 baseColor = vec3(0.02, 0.04, 0.10);

  // ── Lighting ──
  float diff = max(dot(normal, SUN_DIR), 0.0);
  float shading = 0.5 + diff * 0.5;
  vec3 col = (baseColor + texCol * 2.0) * shading;

  // ── Edge rim glow ──
  float rim = 1.0 - max(dot(normal, viewDir), 0.0);
  rim = pow(rim, 3.0) * 0.35;
  col += RIM_COL * rim;

  // ── Top/bottom fade to background ──
  float edgeFade = smoothstep(CYL_H, CYL_H - 0.15, abs(hit.y));
  col = mix(BG_COLOR, col, edgeFade);

  fragColor = vec4(col, 1.0);
}
