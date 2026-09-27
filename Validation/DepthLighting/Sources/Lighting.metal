#include <metal_stdlib>
using namespace metal;
struct Parameters { float4 light; float4 style; float4 range; };
kernel void relight(texture2d<float,access::read> source [[texture(0)]],
                    texture2d<float,access::sample> depth [[texture(1)]],
                    texture2d<float,access::write> output [[texture(2)]],
                    constant Parameters &p [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x>=source.get_width() || id.y>=source.get_height()) return;
    float4 original=source.read(id);
    if (p.light.z==0 && p.style.z==0) { output.write(original,id); return; }
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    float2 size=float2(source.get_width(),source.get_height());
    float2 uv=(float2(id)+0.5)/size;
    float span=max(p.range.y-p.range.x,1e-6f);
    float d=clamp((depth.sample(s,uv).r-p.range.x)/span,0.0f,1.0f);
    if (p.style.z>0) { output.write(float4(float3(d),original.a),id);return; }
    // DA2 gives relative inverse depth, not calibrated geometry. This shallow
    // relief is deliberately bounded; steep depth jumps must not turn into rims.
    float2 step=5.0f/size;
    float dx=(depth.sample(s,uv+float2(step.x,0)).r-depth.sample(s,uv-float2(step.x,0)).r)/span;
    float dy=(depth.sample(s,uv+float2(0,step.y)).r-depth.sample(s,uv-float2(0,step.y)).r)/span;
    float edgeWeight=1.0f-smoothstep(0.025f,0.12f,length(float2(dx,dy)));
    float2 gradient=-float2(dx,dy)*size/max(size.x,size.y)/10.0f*max(size.x,size.y)*0.22f;
    gradient=clamp(gradient,float2(-2),float2(2))*edgeWeight*p.style.y;
    float3 normal=normalize(float3(gradient,-1));
    float2 aspect=size/max(size.x,size.y);
    // Anchor the lamp to the depth of the touched surface. Relative inverse
    // depth must not be treated as a shallow linear slab: that illuminated sky.
    float anchor=clamp((depth.sample(s,p.range.zw).r-p.range.x)/span,0.0f,1.0f);
    float z=0.4f/(0.08f+0.92f*d);
    float anchorZ=0.4f/(0.08f+0.92f*anchor);
    float3 position=float3(uv*aspect,z);
    float3 lightPosition=float3(p.light.xy*aspect,anchorZ-p.style.w);
    float3 direction=normalize(lightPosition-position);
    float diffuse=max(dot(normal,direction),0.0f);
    float distance=length(float3((uv-p.light.xy)*aspect,z-anchorZ));
    // Finite, smoothly vanishing local reach. Distant sky/background outside
    // the lamp's volume is copied exactly, independent of its screen position.
    float reach=1.0f-smoothstep(2.0f*p.light.w,3.0f*p.light.w,distance);
    float depthReach=1.0f-smoothstep(0.7f,1.3f,abs(z-anchorZ));
    float sourceDistance=length(lightPosition-position);
    float attenuation=(0.48f*0.48f+0.1f)/(sourceDistance*sourceDistance+0.1f);
    float falloff=exp(-2.0f*distance*distance/(p.light.w*p.light.w))*reach*depthReach*attenuation;
    // Multiplicative light retains source texture and exact black. A soft local
    // shoulder limits ONLY the added contribution, leaving HDR and source cores.
    float gain=exp2(2.3f*p.light.z*falloff*(0.18f+0.82f*diffuse))-1.0f;
    float3 tint=float3(1.0f+0.22f*p.style.x,1.0f,1.0f-0.28f*p.style.x);
    float3 addition=max(original.rgb,0.0f)*gain*tint;
    float peak=max(original.r,max(original.g,original.b));
    // Leave a small margin below the 8-bit sRGB white quantization boundary.
    float room=max(0.0f,0.99f-peak)*0.999f;
    float delta=max(addition.r,max(addition.g,addition.b));
    float scale=room>0 ? room/(room+delta) : 0.0f;
    output.write(float4(original.rgb+addition*scale,original.a),id);
}
