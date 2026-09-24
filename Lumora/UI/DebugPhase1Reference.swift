#if DEBUG
import Foundation

/// Swift port of the fixed Phase 1 Python equations. It runs off MainActor.
enum DebugPhase1Reference {
    static func render(_ rgba:[Float],width w:Int,height h:Int,
                       variant:DebugToneVariant,amount:Float)throws->[Float] {
        let n=w*h,epsilon:Float=0.005
        var y=[Float](repeating:0,count:n),logY=y
        for i in 0..<n {
            y[i]=max(0,0.2126*rgba[4*i]+0.7152*rgba[4*i+1]+0.0722*rgba[4*i+2])
            logY[i]=log2(y[i]+epsilon)
        }
        let radius=max(2,Int((Double(min(w,h))*0.045).rounded(.toNearestOrEven)))
        let base:[Float]
        switch variant {
        case .gaussian:base=try gaussian(logY,w:w,h:h,sigma:Float(radius))
        case .bilateral:
            let sw=max(1,w/4),sh=max(1,h/4)
            let small=resample(logY,w:w,h:h,toW:sw,toH:sh)
            let filtered=try bilateral(small,w:sw,h:sh,sigmaSpace:max(1,Float(radius)/4),sigmaColor:0.8)
            base=resample(filtered,w:sw,h:sh,toW:w,toH:h)
        default:throw NSError(domain:"Phase 1 variant",code:1)
        }
        let sorted=y.sorted()
        let p95=sorted[min(n-1,Int((Double(n-1)*0.95).rounded()))]
        let context=smooth(0.48,0.88,p95)
        var output=rgba
        for i in 0..<n {
            if i%w==0 {try Task.checkCancellation()}
            let b=base[i],detail=logY[i]-b
            let shadow=1-smooth(log2(0.012+epsilon),log2(0.22+epsilon),b)
            let highlight=smooth(log2(0.50+epsilon),log2(1.8+epsilon),b)
            let mapped=b+1.5*context*shadow-highlight+detail
            let target=max(0,exp2(mapped)-epsilon)
            let gain=min(4,target/max(y[i],0.003))
            for c in 0..<3 {output[4*i+c]=rgba[4*i+c]+amount*(rgba[4*i+c]*gain-rgba[4*i+c])}
        }
        return output
    }
    private static func smooth(_ a:Float,_ b:Float,_ x:Float)->Float {
        let t=min(1,max(0,(x-a)/(b-a)));return t*t*(3-2*t)
    }
    private static func reflect(_ x:Int,_ n:Int)->Int {
        if n<=1{return 0};let period=2*n
        let value=((x%period)+period)%period
        return value<n ? value : period-value-1
    }
    private static func gaussian(_ input:[Float],w:Int,h:Int,sigma:Float)throws->[Float] {
        let radius=max(1,Int(3*sigma+0.5))
        let weights=(-radius...radius).map { exp(-0.5*Float($0*$0)/(sigma*sigma)) }
        let normalization=weights.reduce(0,+)
        var temp=[Float](repeating:0,count:input.count),out=temp
        for row in 0..<h {
            try Task.checkCancellation()
            for x in 0..<w {
                var sum:Float=0
                for offset in -radius...radius {sum+=weights[offset+radius]*input[row*w+reflect(x+offset,w)]}
                temp[row*w+x]=sum/normalization
            }
        }
        for row in 0..<h {
            try Task.checkCancellation()
            for x in 0..<w {
                var sum:Float=0
                for offset in -radius...radius {sum+=weights[offset+radius]*temp[reflect(row+offset,h)*w+x]}
                out[row*w+x]=sum/normalization
            }
        }
        return out
    }
    private static func bilateral(_ input:[Float],w:Int,h:Int,sigmaSpace:Float,sigmaColor:Float)throws->[Float] {
        let radius=max(2,Int(2*sigmaSpace+0.5))
        var out=[Float](repeating:0,count:input.count)
        for row in 0..<h {
            try Task.checkCancellation()
            for x in 0..<w {
                let center=input[row*w+x];var weighted:Float=0,norm:Float=0
                for dy in -radius...radius {for dx in -radius...radius {
                    let sample=input[reflect(row+dy,h)*w+reflect(x+dx,w)]
                    let spatialDistance=Float(dx*dx+dy*dy)/(2*sigmaSpace*sigmaSpace)
                    let colorDistance=(sample-center)*(sample-center)/(2*sigmaColor*sigmaColor)
                    let weight=exp(-spatialDistance-colorDistance)
                    weighted+=weight*sample;norm+=weight
                }}
                out[row*w+x]=weighted/max(1e-8,norm)
            }
        }
        return out
    }
    private static func resample(_ input:[Float],w:Int,h:Int,toW:Int,toH:Int)->[Float] {
        var out=[Float](repeating:0,count:toW*toH)
        for row in 0..<toH {for x in 0..<toW {
            let sx=(Float(x)+0.5)*Float(w)/Float(toW)-0.5
            let sy=(Float(row)+0.5)*Float(h)/Float(toH)-0.5
            let x0=max(0,min(w-1,Int(floor(sx)))),x1=min(w-1,x0+1)
            let y0=max(0,min(h-1,Int(floor(sy)))),y1=min(h-1,y0+1)
            let fx=max(0,min(1,sx-Float(x0))),fy=max(0,min(1,sy-Float(y0)))
            let top=input[y0*w+x0]*(1-fx)+input[y0*w+x1]*fx
            let bottom=input[y1*w+x0]*(1-fx)+input[y1*w+x1]*fx
            out[row*toW+x]=top*(1-fy)+bottom*fy
        }}
        return out
    }
}
#endif
