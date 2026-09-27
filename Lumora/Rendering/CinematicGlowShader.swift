enum CinematicGlowShader {
 static let source = #"""
#include <metal_stdlib>
using namespace metal;
struct Params { float4 diffusion; float4 halation; float4 global; };
constant float3 luma=float3(.2126,.7152,.0722);
float softPositive(float x,float k) {
 if(x<=-k)return 0;
 if(x>=k)return x;
 return (x+k)*(x+k)/(4*k);
}
float extractedFraction(float y,float threshold,float knee) {
 // Continuous C1 knee, with HDR contribution proportional to radiance.
 return min(.95,softPositive(y-threshold,max(.001,knee))/max(y,1e-6)*(1+.2*y/(1+y)));
}

// One extraction representation is reused for diffusion and halation.
// global.z = extraction mode; global.w = pyramid divisor for accumulation.
kernel void extractLevel(texture2d<float,access::read> source [[texture(0)]],
 texture2d<float,access::write> target [[texture(1)]], constant Params& p [[buffer(0)]], uint2 q [[thread_position_in_grid]]) {
 if(q.x>=source.get_width()||q.y>=source.get_height())return;
 float3 c=max(source.read(q).rgb,0.0);float y=dot(c,luma);
 float h=extractedFraction(y,p.diffusion.z,p.diffusion.w);
 float e=y*extractedFraction(y,max(.22,p.diffusion.z*.65),max(.10,p.diffusion.w*.7));
 float broad=y/(y+.5);
 target.write(p.global.z<.5 ? float4(c*h,0):float4(e*(1-broad),e*broad,0,0),q);
}
kernel void reduceLevel(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],uint2 q [[thread_position_in_grid]]) {
 if(q.x>=dst.get_width()||q.y>=dst.get_height())return;
 uint2 m=uint2(src.get_width()-1,src.get_height()-1),a=q*2;
 dst.write((src.read(min(a,m))+src.read(min(a+uint2(1,0),m))+src.read(min(a+uint2(0,1),m))+src.read(min(a+uint2(1,1),m)))*.25,q);
}
kernel void clearOutput(texture2d<float,access::write> dst [[texture(0)]],uint2 q [[thread_position_in_grid]]) {
 if(q.x<dst.get_width()&&q.y<dst.get_height())dst.write(float4(0),q);
}
// Each blur is consumed immediately. float32 accumulation avoids repeated half rounding.
// weights.x: diffusion weight; weights.y: halation scale index + 1 (0 = diffusion).
kernel void accumulate(texture2d<float,access::sample> src [[texture(0)]],texture2d<float,access::read_write> dst [[texture(1)]],
 constant Params& p [[buffer(0)]],constant float4& weights [[buffer(1)]],uint2 q [[thread_position_in_grid]]) {
 if(q.x>=dst.get_width()||q.y>=dst.get_height())return;
 constexpr sampler s(coord::pixel,address::clamp_to_edge,filter::linear);
 float4 v=src.sample(s,(float2(q)+.5)/p.global.w);float3 add;
 if(weights.y<.5)add=v.rgb*weights.x*min(.65,.44*p.diffusion.x);
 else {
  float3 tint=mix(float3(1),float3(1,.12,.015),p.halation.z);tint/=dot(tint,luma);
  int i=int(weights.y)-1;
  float3 propagated=i==0 ? float3(0,0,v.r):i==1 ? float3(0,v.r,v.g):i==2 ? float3(v.r,v.g,0):float3(v.g,0,0);
  add=propagated*tint*min(.30,.22*p.halation.x);
 }
 dst.write(dst.read(q)+float4(add,0),q);
}
// Smooth interpolation of recombination only. 40 is the exact frozen V2 point.
kernel void finish(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::read_write> dst [[texture(1)]],constant Params& p [[buffer(0)]],uint2 q [[thread_position_in_grid]]) {
 if(q.x>=src.get_width()||q.y>=src.get_height())return;
 float4 original=src.read(q);float3 c=original.rgb,cp=max(c,0.0);float y=dot(cp,luma);
 float3 h=cp*extractedFraction(y,p.diffusion.z,p.diffusion.w);
 float3 removed=min(.65,.44*p.diffusion.x)*h;
 float3 added=dst.read(q).rgb;
 float3 v2=c-removed+added;
 float intensity=p.global.y;
 float3 result;
 if(intensity<=40.0) {
  float t=smoothstep(0.0,40.0,intensity);
  result=intensity==40.0 ? v2:mix(c,v2,t);
 } else {
  float t=smoothstep(40.0,70.0,intensity);
  float upper=smoothstep(70.0,100.0,intensity);
  // Interpolate the recombination weights, not an unprotected additive intermediate.
  // Between 40 and 70 this convex path cannot exceed both endpoint values.
  float gain=1.10+.40*upper;
  float compensation=.45;
  float shoulder=mix(.85,.65,upper);
  float3 rawDelta=gain*added-compensation*removed;
  float3 delta=max(rawDelta,0.0);
  delta=delta*delta/(delta+.001);
  delta*=exp(-pow(y/shoulder,4.0));
  float3 room=max(.99-cp,0.0);
  float3 capacity=room*room/(room+.02);
  float3 safeAdded=capacity*delta/(capacity+delta+1e-12);
  result=intensity>=70.0 ? c+safeAdded:mix(v2,c+safeAdded,t);
 }
 dst.write(float4(result,original.a),q);
}
"""#
}
