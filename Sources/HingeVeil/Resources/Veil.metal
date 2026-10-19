#include <metal_stdlib>
using namespace metal;

struct VeilParameters {
    float4 projection; // amount, top aperture inset, side aperture inset, radius
    float4 appearance; // feather, shade, source width, source height
    float4 counterProjection; // bounded compression, bounded depth, reserved
};
struct ScreenVertex { float4 position [[position]]; float2 uv; };

vertex ScreenVertex veilTriangle(uint index [[vertex_id]]) {
    float2 points[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    ScreenVertex result;
    result.position = float4(points[index], 0, 1);
    result.uv = float2((points[index].x + 1) * 0.5, (1 - points[index].y) * 0.5);
    return result;
}

// A separable Gaussian costs nine texture reads per pass. The blur is computed
// in source coordinates so that it remains continuous through the edge fade.
kernel void veilGaussian(texture2d<float, access::sample> input [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         constant float2 &axis [[buffer(0)]],
                         uint2 pixel [[thread_position_in_grid]]) {
    if (pixel.x >= output.get_width() || pixel.y >= output.get_height()) return;
    constexpr sampler linearFilter(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 dimensions(input.get_width(), input.get_height());
    float2 uv = (float2(pixel) + 0.5) / float2(output.get_width(), output.get_height());
    const float weights[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    float4 color = input.sample(linearFilter, uv) * weights[0];
    for (uint i = 1; i < 5; ++i) {
        float2 offset = axis * float(i) / dimensions;
        color += (input.sample(linearFilter, uv + offset) + input.sample(linearFilter, uv - offset)) * weights[i];
    }
    output.write(color, pixel);
}

fragment float4 veilComposite(ScreenVertex in [[stage_in]],
                              texture2d<float> original [[texture(0)]],
                              texture2d<float> softened [[texture(1)]],
                              constant VeilParameters &p [[buffer(0)]]) {
    constexpr sampler linearFilter(coord::normalized, address::clamp_to_edge, filter::linear);
    float amount = p.projection.x;
    float hingeDistance = 1 - in.uv.y;
    float motion = amount * amount * (3 - 2 * amount);
    float inset = p.projection.z * hingeDistance / (1 - p.projection.y);
    // Sample the original plane behind the panel, with bounded compensation.
    // Never fit the cropped picture back into the panel or clamp its UVs.
    float denominator = 1 - p.counterProjection.y * hingeDistance;
    float2 uv = float2(0.5 + (in.uv.x - 0.5) / denominator,
                      1 - (1 - p.counterProjection.x) * hingeDistance / denominator);
    float edgeDistance = min(in.uv.x - inset, 1 - inset - in.uv.x);
    float sideWeight = 1 - smoothstep(0.025, 0.32, max(0.0, edgeDistance));
    float edgeMix = 1 - pow(1 - amount, 3.0);
    // Keep the established focus front in panel coordinates, independent of
    // content compensation and the user's four Gaussian-radius choices.
    float frontWeight = 1 - smoothstep(0.9 * motion - 0.12, 0.9 * motion + 0.12, in.uv.y);
    // Preserve central haze and the outer edge blend. The four levels still
    // control Gaussian radius, not geometry.
    float middleMix = edgeMix * (0.45 + 0.35 * motion + 0.12 * frontWeight);
    float blurMix = mix(middleMix, edgeMix, sideWeight);
    float3 sharp = original.sample(linearFilter, uv).rgb;
    float3 soft = softened.sample(linearFilter, uv).rgb;
    float shade = p.appearance.y * (0.5 + 0.9 * hingeDistance);
    float3 color = mix(sharp, soft, blurMix) * (1 - shade);
    // Feather the actual silhouette too, not just the pixels inside it.
    // Outward softness avoids the sharp black border of a clipped rectangle.
    // The bottom hinge stays anchored instead of acquiring a dark soft border.
    float feather = max(0.000001, p.appearance.x * hingeDistance);
    float coverage = amount < 0.0001 || hingeDistance < 0.0001
        ? 1 : smoothstep(-feather, feather, edgeDistance);
    // Feather the top opening as well. Width/height converts the normalized
    // horizontal softness into the same pixel softness along the vertical.
    float topFeather = max(0.000001, p.appearance.x * p.appearance.z / p.appearance.w);
    float topCoverage = amount < 0.0001 ? 1
        : smoothstep(-topFeather, topFeather, in.uv.y - p.projection.y);
    coverage *= topCoverage;
    // Texture clamp-to-edge is only a safe sampling mode, never visible edge
    // extension. Fade valid source edges inward; outside pixels are black.
    // Do not fade the bottom: the source and panel hinge remain coincident.
    if (amount >= 0.0001) {
        float sourceSide = min(uv.x, 1 - uv.x);
        coverage *= smoothstep(0.0, max(feather, 1 / p.appearance.z), sourceSide);
        coverage *= smoothstep(0.0, max(topFeather, 1 / p.appearance.w), uv.y);
    }
    return float4(color * coverage, 1);
}
