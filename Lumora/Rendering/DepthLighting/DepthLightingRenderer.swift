import CoreImage

/// Lazy lighting graph shared by preview and export. Defaults retain the legacy
/// depth-derivative response. Optional surface normals, portrait response and
/// screen-space depth shadows affect only the explicitly enabled new controls.
enum DepthLightingRenderer {
    private static let kernel = CIKernel(source: """
    float depthAt(sampler depth, vec2 uv, vec4 bounds) {
        vec2 p = bounds.xy + vec2(uv.x, 1.0-uv.y)*bounds.zw;
        p = clamp(p, bounds.xy+vec2(0.5), bounds.xy+bounds.zw-vec2(0.5));
        return sample(depth, samplerTransform(depth, p)).r;
    }
    vec4 mapAt(sampler map, vec2 uv, vec4 bounds) {
        vec2 p = bounds.xy + vec2(uv.x,1.0-uv.y)*bounds.zw;
        p = clamp(p,bounds.xy+vec2(0.5),bounds.xy+bounds.zw-vec2(0.5));
        return sample(map,samplerTransform(map,p));
    }
    float blocker(sampler depth, vec2 uv, vec2 lightUV, vec4 bounds,
                  vec2 range, float z, float lightZ, float t, float softness) {
        vec2 testUV = mix(uv,lightUV,t);
        if (testUV.x<0.0 || testUV.x>1.0 || testUV.y<0.0 || testUV.y>1.0) { return 0.0; }
        float d = clamp((depthAt(depth,testUV,bounds)-range.x)/max(range.y-range.x,0.000001),0.0,1.0);
        float surfaceZ = 0.4/(0.08+0.92*d);
        float rayZ = mix(z,lightZ,t);
        // Bias avoids self-shadowing; a wide transition gives a soft penumbra.
        float bias = 0.025+z*0.015;
        return smoothstep(bias,bias+mix(0.015,0.16,softness),rayZ-surfaceZ);
    }
    \(DepthLightingGradient.kernelSource)
    kernel vec4 lighting(sampler source, sampler depth, vec4 bounds, vec4 depthBounds,
                        vec4 light, vec4 colorRelief, vec4 range, vec2 referenceSize,
                        float relativeDistance, float originalLighting,
                        sampler normals, vec4 normalBounds, sampler skin, vec4 skinBounds,
                        sampler eyes, vec4 eyeBounds, vec3 enhancements) {
        vec4 original = sample(source, samplerCoord(source));
        vec2 q = (destCoord()-bounds.xy)/bounds.zw;
        vec2 uv = vec2(q.x, 1.0-q.y);
        float span = max(range.y-range.x, 0.000001);
        float d = clamp((depthAt(depth,uv,depthBounds)-range.x)/span,0.0,1.0);

        vec2 gradient = surfaceGradient(depth,uv,depthBounds,span,referenceSize,colorRelief.w);
        vec3 normal = normalize(vec3(gradient,-1.0));
        if (enhancements.x>0.5) {
            vec4 estimated = mapAt(normals,uv,normalBounds);
            if (estimated.a>0.9) {
                vec3 oriented = estimated.rgb/estimated.a*2.0-1.0;
                if (dot(oriented,oriented)>0.01) {
                    normal = normalize(mix(vec3(0.0,0.0,-1.0),normalize(oriented),colorRelief.w));
                }
            }
        }

        vec2 aspect = bounds.zw/max(bounds.z,bounds.w);
        float anchor = clamp((depthAt(depth,range.zw,depthBounds)-range.x)/span,0.0,1.0);
        float z = 0.4/(0.08+0.92*d);
        float anchorZ = 0.4/(0.08+0.92*anchor);
        vec3 subjectPosition = vec3(range.zw*aspect,anchorZ);
        vec3 position = vec3(uv*aspect,z);
        float azimuth = light.x;
        float elevation = light.y;
        vec3 direction = vec3(sin(azimuth)*cos(elevation),
                              enhancements.x>0.5 ? -sin(elevation) : sin(elevation),
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
        float visibility = 1.0;
        if (enhancements.z>0.0 && length(toLight.xy)>0.001) {
            vec2 lightUV = lightPosition.xy/aspect;
            float occlusion = 0.0;
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.10,light.w));
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.20,light.w));
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.30,light.w));
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.40,light.w));
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.50,light.w));
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.60,light.w));
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.70,light.w));
            occlusion = max(occlusion,blocker(depth,uv,lightUV,depthBounds,range.xy,z,lightPosition.z,0.80,light.w));
            visibility = 1.0-enhancements.z*occlusion;
        }
        float falloff = spatialReach*depthReach*attenuation*visibility;
        float materialGain = 1.0;
        if (enhancements.y>0.0) {
            float skinWeight = clamp(mapAt(skin,uv,skinBounds).r,0.0,1.0)*enhancements.y;
            float eyeWeight = clamp(mapAt(eyes,uv,eyeBounds).r,0.0,1.0)*enhancements.y;
            vec3 halfwayVector = toLight/max(sourceDistance,0.000001)+vec3(0.0,0.0,-1.0);
            vec3 halfway = halfwayVector/max(length(halfwayVector),0.000001);
            float specular = pow(max(dot(normal,halfway),0.0),mix(48.0,10.0,light.w));
            // Restrained, texture-preserving skin response; no synthetic eye glints.
            diffuse = mix(diffuse,0.16+0.84*diffuse,skinWeight*0.35);
            materialGain += skinWeight*0.12*specular;
            materialGain *= 1.0-eyeWeight*0.35;
        }
        float gain = pow(2.0,3.8*light.z*falloff*(0.18+0.82*diffuse))-1.0;

        vec3 base = original.rgb*clamp(originalLighting,0.0,1.0);
        vec3 tint = max(colorRelief.rgb,vec3(0.0));
        vec3 addition = max(original.rgb,vec3(0.0))*gain*tint*materialGain;
        float peak = max(base.r,max(base.g,base.b));
        float room = max(0.0,0.995-peak)*0.999;
        float delta = max(addition.r,max(addition.g,addition.b));
        float scale = room>0.0 ? room/(room+delta) : 0.0;
        return vec4(base+addition*scale,original.a);
    }
    """)

    /// Depth is raw DA2 output already smoothed by two model pixels, as in the prototype.
    static func apply(_ image: CIImage, depth: CIImage, low: Float, high: Float,
                      settings: DepthLightingSettings, normals: CIImage? = nil,
                      materials: DepthLightingMaterials? = nil) throws -> CIImage {
        let s = settings.validated
        guard s.isActive else { return image }
        if s.originalLighting == 100 && !s.surfaceNormals && s.portraitShading == 0 && s.shadowStrength == 0 {
            return try DepthLightingLegacyRenderer.apply(image,depth:depth,low:low,high:high,settings:s)
        }
        let extent = image.extent, depthExtent = depth.extent
        let factor = 960 / max(extent.width, extent.height)
        let black = CIImage(color: .black).cropped(to: CGRect(x:0,y:0,width:1,height:1))
        let normalMap = normals ?? black, skin = materials?.skin ?? black, eyes = materials?.eyes ?? black
        let mapExtents = [extent, depthExtent, normalMap.extent, skin.extent, eyes.extent]
        guard let output = kernel?.apply(extent: extent, roiCallback: { index, rect in
            index == 0 ? rect : mapExtents[Int(index)]
        }, arguments: [image, depth, CIVector(cgRect: extent), CIVector(cgRect: depthExtent),
            CIVector(x: s.azimuth * .pi / 180, y: s.elevation * .pi / 180,
                     z: s.intensity/100, w: s.softness/100),
            CIVector(x: s.red, y: s.green, z: s.blue, w: s.relief/100),
            CIVector(x: CGFloat(low), y: CGFloat(high), z: s.targetX, w: s.targetY),
            CIVector(x: extent.width*factor, y: extent.height*factor),
            s.distance/40, s.originalLighting/100,
            normalMap, CIVector(cgRect:normalMap.extent), skin, CIVector(cgRect:skin.extent),
            eyes, CIVector(cgRect:eyes.extent),
            CIVector(x:s.surfaceNormals && normals != nil ? 1:0, y:s.portraitShading/100,z:s.shadowStrength/100)]) else { throw PhotoError.renderFailed }
        return output
    }
}
