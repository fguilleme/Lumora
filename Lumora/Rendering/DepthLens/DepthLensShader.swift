enum DepthLensShader { static let source = #"""
#include <metal_stdlib>
using namespace metal;
constant bool scalarOnly [[function_constant(0)]];
constant uint fixedBlades [[function_constant(1)]];
constant uint fixedDebug [[function_constant(2)]];
struct Params { float4 lens; float4 depth; float4 options; uint4 flags; };
constexpr sampler linearSampler(coord::pixel, address::clamp_to_edge, filter::linear);
float normalizedDepth(float d, constant Params& p) {
    if (!isfinite(d)) return 0;
    float v = saturate((d-p.options.x)/max(1e-6f,p.options.y-p.options.x));
    return p.options.z > .5f ? 1-v : v;
}
kernel void normalizeDepth(texture2d<float,access::read> raw [[texture(0)]],
                           texture2d<float,access::write> out [[texture(1)]],
                           constant Params& p [[buffer(0)]], device const float4* strokes [[buffer(1)]],
                           uint2 q [[thread_position_in_grid]]) {
    if (q.x>=out.get_width() || q.y>=out.get_height()) return;
    float original=normalizedDepth(raw.read(q).r,p), d=original;
    float2 uv=(float2(q)+.5f)/float2(out.get_width(),out.get_height());
    float aspect=float(out.get_height())/out.get_width();
    for(uint i=0;i<p.flags.w;i++) {
        float4 s=strokes[i];
        float r=length((uv-s.xy)*float2(1,aspect));
        float weight=1-smoothstep(s.z*.5f,s.z,r);
        d=s.w>1 ? mix(d,original,weight) : saturate(d+s.w*weight);
    }
    out.write(float4(d),q);
}
// Signed radius: positive foreground, negative background. Thin-lens diameter / 2.
float coc(float d, constant Params& p, float width) {
    float z=1/mix(1/p.depth.y,1/p.depth.x,d);
    float s=1/mix(1/p.depth.y,1/p.depth.x,p.lens.z);
    float f=p.lens.x*.001f;
    float c=f*f/(p.lens.y*max(.001f,s-f))*(s-z)/z;
    float t=smoothstep(p.depth.z, max(p.depth.z*2, .0001f), abs(d-p.lens.z));
    return clamp(c*width/.036f*.5f,-p.lens.w,p.lens.w)*t;
}
float polygonBoundary(float angle, uint blades) {
    if(blades<3) return 1;
    float sector=2*M_PI_F/float(blades);
    return cos(M_PI_F/float(blades))/cos(fmod(angle+4*M_PI_F+sector*.5f,sector)-sector*.5f);
}
float apertureDistance(float2 v,uint blades) {
    return length(v)/polygonBoundary(atan2(v.y,v.x),blades);
}
float apertureArea(uint blades) {
    return blades<3 ? M_PI_F : .5f*float(blades)*sin(2*M_PI_F/float(blades));
}
float2 sampleDisk(uint i,uint count,uint blades) {
    float angle=float(i)*2.399963229728653f;
    float radius=sqrt((float(i)+.5f)/float(count));
    // Circular proposal, polygon rejection below preserves uniform density/energy.
    return float2(cos(angle),sin(angle))*radius;
}
// Soft depth ordering bins; floating source radii remain continuous within/across bins.
void addContribution(thread float4* colors,thread float* coverage,thread float* moments,
                     float4 color,float weight,float depth){
    float z=saturate(depth)*31;
    uint lo=min(uint(z),30u);float f=z-float(lo);
    float weights[2]={1-f,f};
    for(uint k=0;k<2;k++){float beta=weights[k],v=weight*beta;
        colors[lo+k]+=color*v;coverage[lo+k]+=v;moments[lo+k]+=v*beta;}
}
kernel void prepareGeometry(texture2d<float,access::read> depth [[texture(0)]],
                            texture2d<float,access::read> rawBack [[texture(1)]],
                            texture2d<float,access::write> geometry [[texture(2)]],
                            texture2d<float,access::write> backGeometry [[texture(3)]],
                            constant Params& p [[buffer(0)]],uint2 q [[thread_position_in_grid]]){
    if(q.x>=depth.get_width()||q.y>=depth.get_height())return;
    float d=depth.read(q).r,b=normalizedDepth(rawBack.read(q).r,p);
    geometry.write(float4(d,coc(d,p,float(depth.get_width())),0,1),q);
    backGeometry.write(float4(b,coc(b,p,float(depth.get_width())),0,1),q);
}
kernel void depthLens(texture2d<float,access::sample> src [[texture(0)]],
                      texture2d<float,access::read> raw [[texture(1)]],
                      texture2d<float,access::sample> dep [[texture(2)]],
                      texture2d<float,access::read> confidence [[texture(3)]],
                      texture2d<float,access::write> out [[texture(4)]],
                      texture2d<float,access::read> geometry [[texture(5)]],
                      texture2d<float,access::read> backGeometry [[texture(6)]],
                      texture2d<float,access::read> alpha [[texture(7)]],
                      texture2d<float,access::read> front [[texture(8)]],
                      texture2d<float,access::read> back [[texture(9)]],
                      constant Params& p [[buffer(0)]],
                      device const float4* apertureSamples [[buffer(1)]],constant uint& layerCount [[buffer(2)]],
                      uint2 q [[thread_position_in_grid]]) {
    uint w=out.get_width(), h=out.get_height(); if(q.x>=w||q.y>=h)return;
    float2 center=float2(q)+.5f;
    float4 original=src.read(q); float d=dep.read(q).r;
    float radius=coc(d,p,float(w));
    uint debug=fixedDebug;
    if(debug>0) {
        float4 v=original;
        if(debug==2)v=float4(float3(raw.read(q).r),1);
        if(debug==3)v=float4(float3(d),1);
        if(debug==4)v=float4(float3(confidence.read(q).r),1);
        if(debug==5){float gx=dep.read(uint2(min(q.x+1,w-1),q.y)).r-dep.read(uint2(q.x?q.x-1:0,q.y)).r;
            float gy=dep.read(uint2(q.x,min(q.y+1,h-1))).r-dep.read(uint2(q.x,q.y?q.y-1:0)).r;
            v=float4(float3(saturate(length(float2(gx,gy))*8)),1);}
        if(debug==6){float mask=1-smoothstep(p.depth.z,max(p.depth.z*2,.0001f),abs(d-p.lens.z));v=float4(mix(original.rgb,float3(0,1,.2),mask*.55f),original.a);}
        if(debug==7)v=float4(max(radius,0.f)/max(p.lens.w,1.f),0,max(-radius,0.f)/max(p.lens.w,1.f),1);
        out.write(v,q);return;
    }
    const uint bins=32;
    float4 colors[bins];float coverage[bins];float moments[bins];
    for(uint b=0;b<bins;b++){colors[b]=0;coverage[b]=0;moments[b]=0;}
    uint count=p.flags.y,blades=fixedBlades;
    // Proposal disks cover the entire antialiased source footprint, including its rim.
    float footprintPixel=float(max(w,h))/960.f;
    float R=max(p.lens.w+footprintPixel,1.5f*footprintPixel),localR=max(abs(radius)+footprintPixel,1.5f*footprintPixel);
    float localR2=localR*localR,R2=R*R;
    float area=apertureArea(blades);
    bool opaqueFocus=abs(radius)<=.5f && alpha.read(q).r>=.999999f;
    float fillDepth=0,fillWeight=0;float4 fillColor=0;
    float4 backgroundRadiance=0;float backgroundWeight=0;
    // Balance-heuristic mixture: local support for small CoCs + global support for expansion.
    // Each sample contributes using its OWN CoC, for both signs of defocus.
    for(uint i=0;i<count;i++){
        float2 disk=apertureSamples[i].xy;
        float2 offset=disk*(i<count/2 ? localR:R);
        float2 pos=center+offset;
        float2 bounded=clamp(pos,float2(.5f),float2(w-.5f,h-.5f));
        uint2 t=uint2(bounded);
        float distance=apertureSamples[i].z*(i<count/2 ? localR:R);
        float density=float(count-count/2)/(M_PI_F*R2);
        if(dot(offset,offset)<=localR2)density+=float(count/2)/(M_PI_F*localR2);
        for(uint surface=0;surface<(scalarOnly ? 1u:layerCount);surface++){
            float2 dr=surface==0 ? geometry.read(t).rg:backGeometry.read(t).rg;
            float sr=abs(dr.y);
            // Fill only the missing sharp under-layer of a defocused occluder. A smooth
            // coverage estimate replaces the V1/V2 draft binary switch between raw fills.
            // Full hidden radiance remains unavailable in a scalar-depth photograph.
            if(scalarOnly && !opaqueFocus && sr<=.5f && dr.x<d-.005f){
                float support=1-smoothstep(localR-.5f*footprintPixel,localR+.5f*footprintPixel,distance);
                float fw=support/(density*area*localR2);
                fillColor+=front.read(t)*fw;fillDepth+=dr.x*fw;fillWeight+=fw;
            }
            if(opaqueFocus && dr.x<=d)continue;
            if(sr<=.5f)continue;
            float a=surface==0 ? alpha.read(t).r:1;
            if(a<=0)continue;
            float footprint=1-smoothstep(sr-.5f*footprintPixel,sr+.5f*footprintPixel,distance);
            float weight=a*footprint*smoothstep(.5f,1.5f,sr)/(density*area*sr*sr);
            if(weight<=0)continue;
            float4 color=surface==0 ? front.read(t):back.read(t);
            if(surface==1){backgroundRadiance+=color*weight;backgroundWeight+=weight;}
            else addContribution(colors,coverage,moments,color,weight,dr.x);
        }
    }
    // Delta component at subpixel focus: exact original surface, not a blurred gather.
    float a=alpha.read(q).r;
    if(!opaqueFocus)addContribution(colors,coverage,moments,front.read(q),a*(1-smoothstep(.5f,1.5f,abs(radius))),d);
    if(!scalarOnly){float2 dr=backGeometry.read(q).rg;
        float weight=1-smoothstep(.5f,1.5f,abs(dr.y));
        backgroundRadiance+=back.read(q)*weight;backgroundWeight+=weight;}
    if(fillWeight>1e-6f)addContribution(colors,coverage,moments,fillColor/fillWeight,saturate(2*fillWeight),fillDepth/fillWeight);
    float4 completeBackground=backgroundWeight>1e-6f ? backgroundRadiance/backgroundWeight:back.read(q);
    float4 result=opaqueFocus ? original:(!scalarOnly ? completeBackground:float4(0));
    float totalCoverage=(opaqueFocus || !scalarOnly) ? 1.f:0.f;
    for(uint b=0;b<bins;b++){
        float mass=coverage[b];if(mass<=1e-8f)continue;
        float4 color=colors[b]/mass;
        // Smooth overlapping depth buckets order radiance; they never quantize the source CoC.
        // Correct fractional basis coverage before over-composition. A single opaque surface
        // split across adjacent buckets must remain opaque, not become two half-alpha layers.
        float basis=clamp(moments[b]/mass,1e-5f,1.f);
        float opacity=1-pow(1-saturate(mass/basis),basis);
        result=result*(1-opacity)+color*opacity;
        totalCoverage=totalCoverage*(1-opacity)+opacity;
    }
    result=totalCoverage>1e-6f ? result/totalCoverage:original;
    // Full-coverage focused surfaces are exact occluders of all FAR contributions.
    // Near splats are composed in depth order above; inject focus as an opaque layer there,
    // rather than overriding the final result (a closer blurred object may cover it).
    float r=abs(radius);
    if(p.options.w>0 && r>1.5f){float l=dot(result.rgb,float3(.2126,.7152,.0722));
        result.rgb*=1+p.options.w*smoothstep(.8f,2.f,l);}
    out.write(result,q);
}

kernel void sampleFocus(texture2d<float,access::read> depth [[texture(0)]],
                        device float* output [[buffer(0)]],constant uint2& point [[buffer(1)]],uint index [[thread_position_in_grid]]) {
    if(index>0)return;
    float values[9];int k=0;
    for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
        uint2 t=uint2(clamp(int2(point)+int2(x,y),int2(0),int2(depth.get_width()-1,depth.get_height()-1)));
        values[k++]=depth.read(t).r;
    }
    for(int i=1;i<9;i++){float v=values[i];int j=i-1;while(j>=0&&values[j]>v){values[j+1]=values[j];j--;}values[j+1]=v;}
    output[0]=values[4];
}

"""#
}
