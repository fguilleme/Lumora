import Foundation

/// Shared by the depth-derived path and the fallback for invalid MoGe normals.
/// A silhouette jump must not become an illuminated bevel. Taking the median of
/// five adjacent slope estimates rejects that jump without changing a planar
/// surface's slope. Distances use the existing 960 px reference at every quality.
enum DepthLightingGradient {
    static let kernelSource = """
    float medianSlope(float a, float b, float c, float d, float e) {
        float lo = max(min(a,b),min(d,e));
        float hi = min(max(a,b),max(d,e));
        return max(min(lo,c),min(max(lo,c),hi));
    }
    float surfaceSlope(sampler depth, vec2 uv, vec2 step, vec4 bounds, float span) {
        float a = depthAt(depth,uv-step*5.0,bounds);
        float b = depthAt(depth,uv-step*3.0,bounds);
        float c = depthAt(depth,uv-step,bounds);
        float d = depthAt(depth,uv+step,bounds);
        float e = depthAt(depth,uv+step*3.0,bounds);
        float f = depthAt(depth,uv+step*5.0,bounds);
        float s0 = b-a, s1 = c-b, s2 = d-c, s3 = e-d, s4 = f-e;
        float smallest = min(min(s0,s1),min(s2,min(s3,s4)));
        float largest = max(max(s0,s1),max(s2,max(s3,s4)));
        // Retain the exact central derivative on regular surfaces, including
        // quantization noise. Fade into the robust estimate only when adjacent
        // slopes disagree, rather than flattening every curved surface.
        float discontinuity = smoothstep(0.005,0.025,(largest-smallest)/span);
        // Even the median can contain the tail of a blurred subject/background
        // jump. Reject that residual bevel when the neighborhood spans a large
        // depth change; regular slopes still take the original derivative.
        float depthRange = max(max(a,b),max(max(c,d),max(e,f)))
                         - min(min(a,b),min(min(c,d),min(e,f)));
        float surfaceConfidence = 1.0-smoothstep(0.035,0.18,depthRange/span);
        float robust = medianSlope(s0,s1,s2,s3,s4)*surfaceConfidence;
        return mix(s2,robust,discontinuity)/span;
    }
    vec2 surfaceGradient(sampler depth, vec2 uv, vec4 bounds,
                         float span, vec2 referenceSize, float relief) {
        if (relief<=0.0) { return vec2(0.0); }
        vec2 step = 4.0/referenceSize;
        float dx = surfaceSlope(depth,uv,vec2(step.x,0.0),bounds,span);
        float dy = surfaceSlope(depth,uv,vec2(0.0,step.y),bounds,span);
        float edgeWeight = 1.0-smoothstep(0.035,0.18,length(vec2(dx,dy)));
        vec2 gradient = -vec2(dx,dy)*referenceSize/8.0*0.25;
        return clamp(gradient,vec2(-2.5),vec2(2.5))*edgeWeight*relief;
    }
    """
}
