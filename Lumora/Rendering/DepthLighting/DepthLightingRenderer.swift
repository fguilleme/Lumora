import CoreImage

/// The DepthLighting prototype formula, evaluated lazily by Core Image to avoid
/// full-native source/depth/output float texture allocations during export.
/// Normal derivatives retain the prototype's 960-pixel reference scale at all qualities.
enum DepthLightingRenderer {
    private static let kernel = CIKernel(source: """
    float depthAt(sampler depth, vec2 uv, vec4 bounds) {
        vec2 p = bounds.xy + vec2(uv.x, 1.0-uv.y)*bounds.zw;
        p = clamp(p, bounds.xy+vec2(0.5), bounds.xy+bounds.zw-vec2(0.5));
        return sample(depth, samplerTransform(depth, p)).r;
    }
    kernel vec4 lighting(sampler source, sampler depth, vec4 bounds, vec4 depthBounds,
                        vec4 light, vec4 colorRelief, vec4 range, vec2 referenceSize,
                        float relativeDistance) {
        vec4 original = sample(source, samplerCoord(source));
        vec2 q = (destCoord()-bounds.xy)/bounds.zw;
        vec2 uv = vec2(q.x, 1.0-q.y);
        float span = max(range.y-range.x, 0.000001);
        float d = clamp((depthAt(depth,uv,depthBounds)-range.x)/span,0.0,1.0);

        // The depth derivatives form a view-space normal map. Keeping the step
        // tied to the 960 px reference makes preview and export agree.
        vec2 step = 4.0/referenceSize;
        float dx = (depthAt(depth,uv+vec2(step.x,0.0),depthBounds)-depthAt(depth,uv-vec2(step.x,0.0),depthBounds))/span;
        float dy = (depthAt(depth,uv+vec2(0.0,step.y),depthBounds)-depthAt(depth,uv-vec2(0.0,step.y),depthBounds))/span;
        float edgeWeight = 1.0-smoothstep(0.035,0.18,length(vec2(dx,dy)));
        vec2 gradient = -vec2(dx,dy)*referenceSize/8.0*0.25;
        gradient = clamp(gradient,vec2(-2.5),vec2(2.5))*edgeWeight*colorRelief.w;
        vec3 normal = normalize(vec3(gradient,-1.0));

        vec2 aspect = bounds.zw/max(bounds.z,bounds.w);
        float anchor = clamp((depthAt(depth,range.zw,depthBounds)-range.x)/span,0.0,1.0);
        float z = 0.4/(0.08+0.92*d);
        float anchorZ = 0.4/(0.08+0.92*anchor);
        vec3 subjectPosition = vec3(range.zw*aspect,anchorZ);
        vec3 position = vec3(uv*aspect,z);
        float azimuth = light.x;
        float elevation = light.y;
        vec3 direction = vec3(sin(azimuth)*cos(elevation),
                              sin(elevation),
                              -cos(azimuth)*cos(elevation));
        // A restrained point-light travel keeps the sculpting that made the
        // prototype useful while avoiding the earlier face-to-neck jump.
        float orbit = mix(0.18,0.62,relativeDistance);
        vec3 lightPosition = subjectPosition+direction*orbit;
        vec3 toLight = lightPosition-position;
        float sourceDistance = length(toLight);
        float diffuse = max(dot(normal,normalize(toLight)),0.0);

        float radius = mix(0.12,0.95,light.w)*mix(0.72,1.28,relativeDistance);
        float planarDistance = length((uv-range.zw)*aspect);
        float spatialReach = exp(-2.0*planarDistance*planarDistance/(radius*radius));
        float depthReach = 1.0-smoothstep(0.55+radius*0.25,1.15+radius*0.45,abs(z-anchorZ));
        float attenuation = (0.34+orbit*orbit*0.10)/(sourceDistance*sourceDistance+0.16);
        float falloff = spatialReach*depthReach*attenuation;
        float gain = pow(2.0,3.8*light.z*falloff*(0.18+0.82*diffuse))-1.0;

        vec3 tint = max(colorRelief.rgb,vec3(0.0));
        vec3 addition = max(original.rgb,vec3(0.0))*gain*tint;
        float peak = max(original.r,max(original.g,original.b));
        float room = max(0.0,0.995-peak)*0.999;
        float delta = max(addition.r,max(addition.g,addition.b));
        float scale = room>0.0 ? room/(room+delta) : 0.0;
        return vec4(original.rgb+addition*scale,original.a);
    }
    """)

    /// Depth is raw DA2 output already smoothed by two model pixels, as in the prototype.
    static func apply(_ image: CIImage, depth: CIImage, low: Float, high: Float,
                      settings: DepthLightingSettings) throws -> CIImage {
        let s = settings.validated
        guard s.isActive else { return image }
        let extent = image.extent, depthExtent = depth.extent
        let factor = 960 / max(extent.width, extent.height)
        guard let output = kernel?.apply(extent: extent, roiCallback: { index, rect in
            index == 0 ? rect : depthExtent
        }, arguments: [image, depth, CIVector(cgRect: extent), CIVector(cgRect: depthExtent),
            CIVector(x: s.azimuth * .pi / 180, y: s.elevation * .pi / 180,
                     z: s.intensity/100, w: s.softness/100),
            CIVector(x: s.red, y: s.green, z: s.blue, w: s.relief/100),
            CIVector(x: CGFloat(low), y: CGFloat(high), z: s.targetX, w: s.targetY),
            CIVector(x: extent.width*factor, y: extent.height*factor),
            s.distance/40]) else { throw PhotoError.renderFailed }
        return output
    }
}
