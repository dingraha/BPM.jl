# module BPM


# Subroutine to use the BPM equations for turbine acoustics

# cubic spline interpolation setup (for Tip Vortex Noise)
function splineint(n,x,y,xval)

    # assuming the values of x are in accending order
    for i = 1:n
        if (xval < x[i])
            if (i == 2)
                x1 = x[1]
                x2 = x[2]
                x3 = x[3]
                y1 = y[1]
                y2 = y[2]
                y3 = y[3]
                yval = cubspline(x1,x2,x3,y1,y2,y3,xval)
            elseif (i == n)
                x1 = x[n-2]
                x2 = x[n-1]
                x3 = x[n]
                y1 = y[n-2]
                y2 = y[n-1]
                y3 = y[n]
                yval = cubspline(x1,x2,x3,y1,y2,y3,xval)
            else
                if (xval <= (x[i]+x[i-1])/2.0)
                    x1 = x[i-2]
                    x2 = x[i-1]
                    x3 = x[i]
                    y1 = y[i-2]
                    y2 = y[i-1]
                    y3 = y[i]
                    yval = cubspline(x1,x2,x3,y1,y2,y3,xval)
                else
                    x1 = x[i-1]
                    x2 = x[i]
                    x3 = x[i+1]
                    y1 = y[i-1]
                    y2 = y[i]
                    y3 = y[i+1]
                    yval = cubspline(x1,x2,x3,y1,y2,y3,xval)
                end
            end
            exit()
        elseif (xval == x[i])
            yval = y[i]
            exit()
        end

    end
    return yval
end

function cubspline(x1,x2,x3,y1,y2,y3,xval)

    a11 = 2.0/(x2-x1)
    a12 = 1.0/(x2-x1)
    a13 = 0.0
    a21 = 1.0/(x2-x1)
    a22 = 2.0*((1.0/(x2-x1))+(1.0/(x3-x2)))
    a23 = 1.0/(x3-x2)
    a31 = 0.0
    a32 = 1.0/(x3-x2)
    a33 = 2.0/(x3-x2)
    b1 = 3.0*(y2-y1)/(x2-x1)^2
    b2 = 3.0*(((y2-y1)/(x2-x1)^2)+((y3-y2)/(x3-x2)^2))
    b3 = 3.0*(y3-y2)/(x3-x2)^2

    bot = a11*a22*a33+a12*a23*a31+a13*a21*a32-a13*a22*a31-a12*a21*a33-a11*a23*a32
    if (xval < x2)
        xtop = b1*a22*a33+a12*a23*b3+a13*b2*a32-a13*a22*b3-a12*b2*a33-b1*a23*a32
        ytop = a11*b2*a33+b1*a23*a31+a13*a21*b3-a13*b2*a31-b1*a21*a33-a11*a23*b3

        k1 = xtop/bot
        k2 = ytop/bot

        a = k1*(x2-x1)-(y2-y1)
        b = -k2*(x2-x1)+(y2-y1)
        t = (xval-x1)/(x2-x1)

        yval = (1.0-t)*y1+t*y2+t*(1.0-t)*(a*(1.0-t)+b*t)
    else
        ytop = a11*b2*a33+b1*a23*a31+a13*a21*b3-a13*b2*a31-b1*a21*a33-a11*a23*b3
        ztop = a11*a22*b3+a12*b2*a31+b1*a21*a32-b1*a22*a31-a12*a21*b3-a11*b2*a32

        k2 = ytop/bot
        k3 = ztop/bot

        a = k2*(x3-x2)-(y3-y2)
        b = -k3*(x3-x2)+(y3-y2)
        t = (xval-x2)/(x3-x2)

        yval = (1.0-t)*y2+t*y3+t*(1.0-t)*(a*(1.0-t)+b*t)
    end
    return yval
end

# Function to compute directivity angles and distance
# Based on work by Luis Vargas (Wind Turbine Noise Prediction)
function direct(n,xt,yt,zt,c,c1,d,Hub,beta)

    theta_e = zeros(n)
    phi_e = zeros(n)

    # distance from pitch-axis to trailing edge
    c2[1:n] = c[1:n]-c1[1:n]

    # Calculating observer location from hub
    xo = xt # lateral direction
    yo = yt # downstream direction
    zo = zt-Hub # height direction

    for i=1:n
        # Calculating trailing edge position from hub
        xs = sin(beta)*d[i]-cos(beta)*c2[i]
        zs = cos(beta)*d[i]+sin(beta)*c2[i]

        # Calculating observer position from trailing edge
        xe_d = xo-xs
        ze_d = zo-zs

        # Rotating observer position with repsect to beta
        theta = pi-beta
        xe = cos(theta)*xe_d+sin(theta)*ze_d
        ze = -sin(theta)*xe_d+cos(theta)*ze_d

        # Calculating observer distance and directivity angles
        r[i] = sqrt(yo^2+xe^2+ze^2)
        theta_e[i] = atan2(sqrt(yo^2+ze^2),xe)
        phi_e[i] = atan2(yo,ze)

        # Quadratic smoothing when phi_e is close to 0 or 180 degrees
        if (abs(phi_e[i]) < 5.0*pi/180.0)
            if (phi_e[i] >= 0.0)
                sign = 1
            else
                sign = -1
            end
            phi_er = abs(phi_e[i])*180.0/pi
            phi_er = 0.1*phi_er^2+2.5
            phi_e[i] = sign*phi_er*pi/180.0
        elseif (abs(phi_e[i]) > 175.0*pi/180.0)
            if (phi_e[i] >= 0.0)
                sign = 1
            else
                sign = -1
            end
            phi_er = abs(phi_e[i])*180.0/pi
            phi_er = -0.1*(phi_er-180.0)^2+177.5
            phi_e[i] = sign*phi_er*pi/180.0
        end

    end
    return r,theta_e,phi_e
end #direct

# Directivity function for high-frequency noise
# not for high-angle separation; becomes inaccurate for theta_e approaching 180 deg
function Dhfunc(theta_e,phi_e,M)
    conv = 0.8 # convection factor for speed
    Mc = M*conv

    Dh = (2.0*(sin(theta_e/2.0))^2*(sin(phi_e))^2)/((1.0+
    M*cos(theta_e))*(1.0+(M-Mc)*cos(theta_e))^2)
    return Dh
end

# Directivity function for low-frequency noise
function Dlfunc(theta_e,phi_e,M)
    Dl = ((sin(theta_e))^2*(sin(phi_e))^2)/(1.0+M*cos(theta_e))^4
    return Dl
end #Dlfunc

# Spectral Function A
function Afunc(ain,Re,Aspec)
    a = abs(log10(ain))

    # Calculating Amin
    if (a < 0.204)
        Amin = sqrt(67.552-886.788*a^2)-8.219
    elseif (a >= 0.204 && a <= 0.244)
        Amin = -32.665*a+3.981
    else
        Amin = -142.795*a^3+103.656*a^2-57.757*a+6.006
    end

    # Calculating Amax
    if (a < 0.13)
        Amax = sqrt(67.552-886.788*a^2)-8.219
    elseif (a >= 0.13 && a <= 0.321)
        Amax = -15.901*a+1.098
    else
        Amax = -4.669*a^3+3.491*a^2-16.699*a+1.149
    end

    # Calculating a0
    if (Re < 9.52e4)
        a0 = 0.57
    elseif (Re >= 9.52e4 && Re <= 8.57e5)
        a0 = -9.57e-13*(Re-8.57e5)^2+1.13
    else
        a0 = 1.13
    end

    # Calculating Amin(a0)
    if (a0 < 0.204)
        Amin0 = sqrt(67.552-886.788*a0^2)-8.219
    elseif (a0 >= 0.204 && a0 <= 0.244)
        Amin0 = -32.665*a0+3.981
    else
        Amin0 = -142.795*a0^3+103.656*a0^2-57.757*a0+6.006
    end

    # Calculating Amax(a0)
    if (a0 < 0.13)
        Amax0 = sqrt(67.552-886.788*a0^2)-8.219
    elseif (a0 >= 0.13 && a0 <= 0.321)
        Amax0 = -15.901*a0+1.098
    else
        Amax0 = -4.669*a0^3+3.491*a0^2-16.699*a0+1.149
    end

    AR0 = (-20.0-Amin0)/(Amax0-Amin0)

    Aspec = Amin+AR0*(Amax-Amin)
    return Aspec
end #Afunc

# Spectral Function B
function Bfunc(bin,Re)

    b = abs(log10(bin))

    # Calculating Bmin
    if (b < 0.13)
        Bmin = sqrt(16.888-886.788*b^2)-4.109
    elseif (b >= 0.13 && b <= 0.145)
        Bmin = -83.607*b+8.138
    else
        Bmin = -817.810*b^3+355.210*b^2-135.024*b+10.619
    end

    # Calculating Bmax
    if (b < 0.10)
        Bmax = sqrt(16.888-886.788*b^2)-4.109
    elseif (b >= 0.10 && b <= 0.187)
        Bmax = -31.330*b+1.854
    else
        Bmax = -80.541*b^3+44.174*b^2-39.381*b+2.344
    end

    # Calculating b0
    if (Re < 9.52e4)
        b0 = 0.30
    elseif (Re >= 9.52e4 && Re <= 8.57e5)
        b0 = -4.48e-13*(Re-8.57e5)^2+0.56
    else
        b0 = 0.56
    end

    # Calculating Bmin(b0)
    if (b0 < 0.13)
        Bmin0 = sqrt(16.888-886.788*b0^2)-4.109
    elseif (b0 >= 0.13 && b0 <= 0.145)
        Bmin0 = -83.607*b0+8.138
    else
        Bmin0 = -817.810*b0^3+355.210*b0^2-135.024*b0+10.619
    end

    # Calculating Bmax(b0)
    if (b0 < 0.10)
        Bmax0 = sqrt(16.888-886.788*b0^2)-4.109
    elseif (b0 >= 0.10 && b0 <= 0.187)
        Bmax0 = -31.330*b0+1.854
    else
        Bmax0 = -80.541*b0^3+44.174*b0^2-39.381*b0+2.344
    end

    BR0 = (-20.0-Bmin0)/(Bmax0-Bmin0)

    Bspec =  Bmin+BR0*(Bmax-Bmin)
    return Bspec
end #Bfunc

function G1func(e)
    if (e <= 0.5974)
        G1 = 39.8*log10(e)-11.12
    elseif (e <= 0.8545 && e > 0.5974)
        G1 = 98.409*log10(e)+2.0
    elseif (e <= 1.17 && e > 0.8545)
        G1 = sqrt(2.484-506.25*(log10(e))^2)-5.076
    elseif (e <= 1.674 && e > 1.17)
        G1 = -98.409*log10(e)+2.0
    else
        G1 = -39.8*log10(e)-11.12
    end
    return G1
end #G1func

function G2func(d)
    if (d <= 0.3237)
        G2 = 77.852*log10(d)+15.328
    elseif (d <= 0.5689 && d > 0.3237)
        G2 = 65.188*log10(d)+9.125
    elseif (d <= 1.7579 && d > 0.5689)
        G2 = -114.052*(log10(d))^2
    elseif (d <= 3.0889 && d > 1.7579)
        G2 = -65.188*log10(d)+9.125
    else
        G2 = -77.852*log10(d)+15.328
    end
    return G2
end #G2func

function G3func(alpha)
    G3 = 171.04-3.03*alpha
    return G3
end #G3func

function G4func(hdav,psi)
    if (hdav <= 5.0)
        G4 = 17.5*log10(hdav)+157.5-1.114*psi
    else
        G4 = 169.7-1.114*psi
    end
    return G4
end #G4func

function G5func(hdav,psi,StSt_peak)
    # finding G5 at phi = 14 deg
    eta = log10(StSt_peak)

    if (hdav < 0.25)
        mu = 0.1221
    elseif (hdav < 0.62 && hdav >= 0.25)
        mu = -0.2175*hdav+0.1755
    elseif (hdav < 1.15 && hdav >= 0.62)
        mu = -0.0308*hdav+0.0596
    else
        mu = 0.0242
    end

    if (hdav <= 0.02)
        m = 0.0
    elseif (hdav <= 0.5 && hdav > 0.02)
        m = 68.724*(hdav)-1.35
    elseif (hdav <= 0.62 && hdav > 0.5)
        m = 308.475*hdav-121.23
    elseif (hdav <= 1.15 && hdav > 0.62)
        m = 224.811*hdav-69.35
    elseif (hdav <= 1.2 && hdav > 1.15)
        m = 1583.28*hdav-1631.59
    else
        m = 268.344
    end

    eta_0 = -sqrt((m^2*mu^4)/(6.25+m^2*mu^2))
    k = 2.5*sqrt(1.0-(eta_0/mu)^2)-2.5-m*eta_0

    if (eta < eta_0)
        G14 = m*eta+k
    elseif (eta < 0.0 && eta >= eta_0)
        G14 = 2.5*sqrt(1.0-(eta/mu)^2)-2.5
    elseif (eta < 0.03616 && eta >= 0.0)
        G14 = sqrt(1.5625-1194.99*eta^2)-1.25
    else
        G14 = -155.543*eta+4.375
    end

    # finding G5 at psi = 0 deg
    hdav_prime = 6.724*hdav^2-4.019*hdav+1.107

    if (hdav_prime < 0.25)
        mu0 = 0.1221
    elseif (hdav_prime < 0.62 && hdav_prime >= 0.25)
        mu0 = -0.2175*hdav_prime+0.1755
    elseif (hdav_prime < 1.15 && hdav_prime >= 0.62)
        mu0 = -0.0308*hdav_prime+0.0596
    else
        mu0 = 0.0242
    end

    if (hdav_prime <= 0.02)
        m0 = 0.0
    elseif (hdav_prime <= 0.5 && hdav_prime > 0.02)
        m0 = 68.724*hdav_prime-1.35
    elseif (hdav_prime <= 0.62 && hdav_prime > 0.5)
        m0 = 308.475*hdav_prime-121.23
    elseif (hdav_prime <= 1.15 && hdav_prime > 0.62)
        m0 = 224.811*hdav_prime-69.35
    elseif (hdav_prime <= 1.2 && hdav_prime > 1.15)
        m0 = 1583.28*hdav_prime-1631.59
    else
        m0 = 268.344
    end

    eta_00 = -sqrt((m0^2*mu0^4)/(6.25+m0^2*mu0^2))
    k0 = 2.5*sqrt(1.0-(eta_00/mu0)^2)-2.5-m0*eta_00

    if (eta < eta_00)
        G0 = m0*eta+k0
    elseif (eta < 0.0 && eta >= eta_00)
        G0 = 2.5*sqrt(1.0-(eta/mu0)^2)-2.5
    elseif (eta < 0.03616 && eta >= 0.0)
        G0 = sqrt(1.5625-1194.99*eta^2)-1.25
    else
        G0 = -155.543*eta+4.375
    end

    G5 = G0+0.0714*psi*(G14-G0)
    return G5
end #G5func

# Turbulent Boundary Layer Trailing Edge Noise
function TBLTEfunc(f,V,L,c,r,theta_e,phi_e,alpha,nu,c0,trip)
    # constants
    M = V/c0
    Re = (V*c)/nu

    if (trip == false)
        # UNTRIPPED boundary layer at 0 deg- thickness, displacement thickness
        d0 = c*(10.0^(1.6569-0.9045*log10(Re)+0.0596*(log10(Re))^2))
        d0_d = c*(10.0^(3.0187-1.5397*log10(Re)+0.1059*(log10(Re))^2))
    else
        # TRIPPED boundary layer at 0 deg- thickness, displacement thickness
        d0 = c*(10.0^(1.892-0.9045*log10(Re)+0.0596*(log10(Re))^2))
        if (Re <= 0.3e6)
            d0_d = c*0.0601*Re^(-0.114)
        else
            d0_d = c*(10.0^(3.411-1.5397*log10(Re)+0.1059*(log10(Re))^2))
        end
    end

    # boundary layer on pressure side- thickness, displacement thickness
    dpr = d0*(10.0^(-0.04175*alpha+0.00106*alpha^2))
    dp_d = d0_d*(10.0^(-0.0432*alpha+0.00113*alpha^2))

    if (trip == false)
        # UNTRIPPED boundary layer on suction side- displacement thickness
        if (alpha <= 7.5 && alpha >= 0.0)
            ds_d = d0_d*10.0^(0.0679*alpha)
        elseif (alpha <= 12.5 && alpha > 7.5)
            ds_d = d0_d*0.0162*10.0^(0.3066*alpha)
            #elseif (alpha <= 25.0 && alpha > 12.5)
        else
            ds_d = d0_d*52.42*10.0^(0.0258*alpha)
        end
    else
        # TRIPPED boundary layer on suction side- displacement thickness
        if (alpha <= 5.0 && alpha >= 0.0)
            ds_d = d0_d*10.0^(0.0679*alpha)
        elseif (alpha <= 12.5 && alpha > 5.0)
            ds_d = d0_d*0.381*10.0^(0.1516*alpha)
            #elseif (alpha <= 25.0 && alpha > 12.5)
        else
            ds_d = d0_d*14.296*10.0^(0.0258*alpha)
        end
    end

    Dh = Dhfunc(theta_e,phi_e,M)
    Dl = Dlfunc(theta_e,phi_e,M)

    Stp = (f*dp_d)/V
    Sts = (f*ds_d)/V

    St1 = 0.02*M^(-0.6)

    if (alpha < 1.33)
        St2 = St1*1.0
    elseif (alpha <= 12.5 && alpha >= 1.33)
        St2 = St1*10.0^(0.0054*(alpha-1.33)^2)
    else
        St2 = St1*4.72
    end

    St_bar = (St1+St2)/2.0

    St_peak = max(St1,St2,St_bar)

    apre = Stp/St1
    asuc = Sts/St1
    bang = Sts/St2

    gamma = 27.094*M+3.31
    gamma0 = 23.43*M+4.651
    beta = 72.65*M+10.74
    beta0 = -34.19*M-13.82

    if (Re < 2.47e5)
        K1 = -4.31*log10(Re)+156.3
    elseif (Re >= 2.47e5 && Re <= 8.0e5)
        K1 = -9.0*log10(Re)+181.6
    else
        K1 = 128.5
    end

    if (alpha < (gamma0-gamma))
        K2 = K1-1000.0
    elseif (alpha >= (gamma0-gamma) && alpha <= (gamma0+gamma))
        K2 = K1+sqrt(beta^2-(beta/gamma)^2*(alpha-gamma0)^2)+beta0
    else
        K2 = K1-12.0
    end

    Re = (V*dp_d)/nu

    if (Re <= 5000.0)
        DeltaK1 = alpha*(1.43*log10(Re)-5.29)
    else
        DeltaK1 = 0.0
    end

    # Keeping observer distance from getting too close to the turbine
    if (r < 1e-8)
        rc = 1e-8
    else
        rc = r
    end

    if (alpha > 12.5 || alpha > gamma0)
        # Turbulent Boundary Layer Separation Stall Noise (TBLSS); this is were the airfoil is stalling and stall noise dominates
        # SPLp = -infinity; 10^(SPLp/10) = 0
        # SPLs = -infinity; 10^(SPLs/10) = 0

        A = Afunc(bang,3.0*Re)

        SPLa = 10.0*log10((ds_d*M^5*L*Dl)/rc^2)+A+K2

        TBLTE = 10.0*log10(10.0^(SPLa/10.0))

    else
        Ap = Afunc(apre,Re)
        As = Afunc(asuc,Re)
        B = Bfunc(bang,Re)

        SPLp = 10.0*log10((dp_d*M^5*L*Dh)/rc^2)+Ap+(K1-3.0)+DeltaK1
        SPLs = 10.0*log10((ds_d*M^5*L*Dh)/rc^2)+As+(K1-3.0)
        SPLa = 10.0*log10((ds_d*M^5*L*Dh)/rc^2)+B+K2

        TBLTE =  10.0*log10(10.0^(SPLp/10.0)+10.0^(SPLs/10.0)+10.0^(SPLa/10.0))

    end
    return TBLTE
end #TBLTEfunc

# Turbulent Boundary Layer Tip Vortex Noise
function TBLTVfunc(f,V,c,r,theta_e,phi_e,atip,c0,tipflat,AR)

    # constants
    M = V/c0
    Mmax = M*(1.0+0.036*atip)

    Dh = Dhfunc(theta_e,phi_e,M)

    # Tip vortex noise correction based on data from "Airfoil Tip Vortex Formation Noise"
    AR_data = [2.0,2.67,4.0,6.0,12.0,24.0]
    atipcorr_data = [0.54,0.62,0.71,0.79,0.89,0.95]

    if ((AR >= 2.0) && (AR <= 24.0))
        atipcorr = splineint(6,AR_data,atipcorr_data,AR)
    elseif (AR > 24.0)
        atipcorr = 1.0
    else
        atipcorr = 0.5
    end

    atip_d = atip*atipcorr

    if (tipflat == false)
        # rounded tip
        l = 0.008*c*atip_d
    else
        # flat tip
        if (atip_d <= 2.0 && atip_d >= 0.0)
            l = c*(0.0230+0.0169*atip_d)
        else
            l = c*(0.0378+0.0095*atip_d)
        end
    end

    St = (f*l)/(V*(1.0+0.036*atip_d))

    # Keeping observer distance from getting too close to the turbine
    if (r < 1e-8)
        rc = 1e-8
    else
        rc = r
    end

    TBLTV = 10.0*log10((M^2*Mmax^3*l^2*Dh)/rc^2)-30.5*(log10(St)+0.3)^2+126.0
    return TBLTV
end #TBLTVfunc

# Laminar Boundary Layer Vortex Shedding
function LBLVSfunc(f,V,L,c,r,theta_e,phi_e,alpha,nu,c0,trip)

    # constants
    M = V/c0
    Re = (V*c)/nu

    if (trip == false)
        # UNTRIPPED boundary layer at 0 deg- thickness
        d0 = c*(10.0^(1.6569-0.9045*log10(Re)+0.0596*(log10(Re))^2))
    else
        # TRIPPED boundary layer at 0 deg- thickness
        d0 = c*(10.0^(1.892-0.9045*log10(Re)+0.0596*(log10(Re))^2))
    end
    # boundary layer on pressure side- thickness
    dpr = d0*(10.0^(-0.04175*alpha+0.00106*alpha^2))

    St = (f*dpr)/V

    Dh = Dhfunc(theta_e,phi_e,M)

    if (Re <= 1.3e5)
        St1 = 0.18
    elseif (Re <= 4.0e5 && Re > 1.3e5)
        St1 = 0.001756*Re^0.3931
    else
        St1 = 0.28
    end

    St_peak = St1*10.0^(-0.04*alpha)

    e = St/St_peak

    G1 = G1func(e)

    if (alpha <= 3.0)
        Re0 = 10.0^(0.215*alpha+4.978)
    else
        Re0 = 10.0^(0.12*alpha+5.263)
    end

    d = Re/Re0

    G2 = G2func(d)
    G3 = G3func(alpha)

    # Keeping observer distance from getting too close to the turbine
    if (r < 1e-8)
        rc = 1e-8
    else
        rc = r
    end

    LBLVS = 10.0*log10((dpr*M^5*L*Dh)/rc^2)+G1+G2+G3
    return LBLVS
end #LBLVSfunc

# Trailing Edge Bluntness Vortex Shedding Noise
function TEBVSfunc(f,V,L,c,h,r,theta_e,phi_e,alpha,nu,c0,psi,trip)

    # constants
    M = V/c0
    Re = (V*c)/nu

    if (trip == false)
        # UNTRIPPED boundary layer at 0 deg- thickness, displacement thickness
        d0 = c*(10.0^(1.6569-0.9045*log10(Re)+0.0596*(log10(Re))^2))
        d0_d = c*(10.0^(3.0187-1.5397*log10(Re)+0.1059*(log10(Re))^2))
    else
        # TRIPPED boundary layer at 0 deg- thickness, displacement thickness
        d0 = c*(10.0^(1.892-0.9045*log10(Re)+0.0596*(log10(Re))^2))
        if (Re <= 0.3e6)
            d0_d = c*0.0601*Re^(-0.114)
        else
            d0_d = c*(10.0^(3.411-1.5397*log10(Re)+0.1059*(log10(Re))^2))
        end
    end

    # boundary layer on pressure side- thickness, displacement thickness
    dpr = d0*(10.0^(-0.04175*alpha+0.00106*alpha^2))
    dp_d = d0_d*(10.0^(-0.0432*alpha+0.00113*alpha^2))

    if (trip == false)
        # UNTRIPPED boundary layer on suction side- displacement thickness
        if (alpha <= 7.5 && alpha >= 0.0)
            ds_d = d0_d*10.0^(0.0679*alpha)
        elseif (alpha <= 12.5 && alpha > 7.5)
            ds_d = d0_d*0.0162*10.0^(0.3066*alpha)
            #elseif (alpha <= 25 && alpha > 12.5)
        else
            ds_d = d0_d* 52.42* 10.0^(0.0258*alpha)
        end
    else
        # TRIPPED boundary layer on suction side- displacement thickness
        if (alpha <= 5.0 && alpha >= 0.0)
            ds_d = d0_d*10.0^(0.0679*alpha)
        elseif (alpha <= 12.5 && alpha > 5.0)
            ds_d = d0_d*0.381*10.0^(0.1516*alpha)
            #elseif (alpha <= 25.0 && alpha > 12.5)
        else
            ds_d = d0_d*14.296*10.0^(0.0258*alpha)
        end
    end

    Dh = Dhfunc(theta_e,phi_e,M)
    St = (f*h)/V
    dav = (dp_d+ds_d)/2.0

    hdav = h/dav

    if (hdav >= 0.2)
        St_peak = (0.212-0.0045*psi)/(1.0+0.235*(1.0/hdav)-0.0132*(1.0/hdav)^2)
    else
        St_peak = 0.1*(hdav)+0.095-0.00243*psi
    end

    StSt_peak = St/St_peak

    G4 = G4func(hdav,psi)
    G5 = G5func(hdav,psi,StSt_peak)

    # Keeping observer distance from getting too close to the turbine
    if (r < 1e-8)
        rc = 1e-8
    else
        rc = r
    end

    TEBVS = 10.0*log10((h*M^(5.5)*L*Dh)/rc^2)+G4+G5
    return TEBVS
end #TEBVSfunc

# Computing the overall sound pressure level (OASPL) of a turbine defined below (in dB)
function OASPL(n,ox,oy,oz,windvel,rpm,B,Hub,rad,c,c1,alpha,nu,c0,psi,AR)
    # constants
    pi = 3.1415926535897932
    nf = 27
    bf = 3

    # Using untripped or tripped boundary layer specficiation
    trip = false # untripped
    # trip = true # tripped

    # Tip specfication
    tipflat = false # round
    # tipflat = true # flat

    # Parameters of the wind turbine
    omega = (rpm*2.0*pi)/60.0  # angular velocity (rad/sec)

    for i = 1:n-1
        L[i] = rad[i+1]-rad[i] # length of each radial section (m)
        d[i] = rad[i] # radial section to be used in directivity calculations (m)
        V[i] = sqrt((omega*rad[i])^2+windvel^2) # wind speed over the blade (m/s)
    end

    h[1:n-1] = 0.01*c[1:n-1]  # trailing edge thickness; 1% of chord length (m)
    atip = alpha[n-1]  # angle of attack of the tip region (deg)

    # Blade rotation increments to rotate around (45 deg from Vargas paper)
    # beta = [0.0,0.25*pi,0.5*pi,0.75*pi,pi,1.25*pi,1.5*pi,1.75*pi] # 8 increments
    beta = [0.0,2.0*pi/9.0,4.0*pi/9.0] # 3 increments (equivalent of 9 for 3 blades)
    # beta = [0.0,pi] # 2 increments
    # beta = [0.0] # 1 increment (top blade facing straight up)

    B_int = 2.0*pi/B # Intervals between blades (from the first blade at 0 deg)

    # One-third octave band frequencies (Hz)
    f = [100.0,125.0,160.0,200.0,250.0,315.0,400.0,500.0,
    630.0,800.0,1000.0,1250.0,1600.0,2000.0,2500.0,3150.0,
    4000.0,5000.0,6300.0,8000.0,10000.0,12500.0,16000.0,
    20000.0,25000.0,31500.0,40000.0]

    # A-weighting curve (dBA) for sound perception correction
    AdB = [-19.145,-16.190,-13.244,-10.847,-8.675,-6.644,
    -4.774,-3.248,-1.908,-0.795,0.0,0.576,0.993,1.202,
    1.271,1.202,0.964,0.556,-0.114,-1.144,-2.488,-4.250,
    -6.701,-9.341,-12.322,-15.694,-19.402]

    for di=1:bf # for each rotation increment
        for j=1:nf # for each frequency
            for bi=1:B # for each blade
                # Calcuating observer distances and directivty angles for the given blade orientation
                r,theta_e,phi_e = direct(n-1,ox,oy,oz,c,c1,d,Hub,beta[di]+(bi-1)*B_int)

                TBLTV = TBLTVfunc(f[j],V[n-1],c[n-1],r[n-1],theta_e[n-1],phi_e[n-1],atip,c0,
                tipflat,AR)
                TV_t[bi] = TBLTV
                for k=1:n-1
                    # Calculating sound pressure level (dB) for each noise source at each radial position
                    LBLVS = TBLTEfunc(f[j],V[k],L[k],c[k],r[k],theta_e[k],phi_e[k],alpha[k],
                    nu,c0,trip)
                    if (trip == false)
                        LBLVS = LBLVSfunc(f[j],V[k],L[k],c[k],r[k],theta_e[k],phi_e[k],alpha[k],
                        nu,c0,trip)
                    else
                        LBLVS = 0.0
                    end
                    TEBVS = TEBVSfunc(f[j],V[k],L[k],c[k],h[k],r[k],theta_e[k],phi_e[k],
                    alpha[k],nu,c0,psi,trip)

                    # Assigning noise to blade segment
                    TE_t[k+[n-1]*(bi-1)] = TBLTE
                    BLVS_t[k+[n-1]*(bi-1)] = LBLVS
                    BVS_t[k+[n-1]*(bi-1)] = TEBVS
                end
            end

            # Adding sound pressure levels (dB)
            TE[j] = 10.0*log10(sum(10.0^(TE_t/10.0)))
            TV[j] = 10.0*log10(sum(10.0^(TV_t/10.0)))
            BLVS[j] = 10.0*log10(sum(10.0^(BLVS_t/10.0)))
            BVS[j] = 10.0*log10(sum(10.0^(BVS_t/10.0)))

            # Combining noise sources into overall SPL
            SPLf[j] = 10.0*log10(10.0^(TE[j]/10.0)+10.0^(TV[j]/
            10.0)+10.0^(BLVS[j]/10.0)+10.0^(BVS[j]/10.0))
        end

        # Correcting with A-weighting
        SPLf[1:nf] = SPLf[1:nf]+AdB[1:nf]

        # Adding SPLs for each rotation increment
        SPLoa_d[di] = 10.0*log10(sum(10.0^(SPLf/10.0)))

        # Protecting total calcuation from negative SPL values
        if (SPLoa_d[di] < 0.0)
            SPLoa_d[di] = 0.0
        end
    end

    # Performing root mean square calculation of SPLs at rotation increments for final value
    SPLoa = sqrt(sum(SPLoa_d^2)/bf)
    return SPLoa
end #OASPL

# Placing a turbine in a specified location and finding the OASPL of the turbine with reference to an observer
function turbinepos(nturb,nseg,nobs,x,y,obs,winddir,windvel,rpm,B,Hub,
    rad,c,c1,alpha,nu,c0,psi,AR,noise_corr)

    windrad = (winddir+180.0)*pi/180.0

    for i = 1:nturb # for each turbine
        # Centering the turbine at (0,0) with repect to the observer location
        ox = obs[1]-x[i]
        oy = obs[2]-y[i]
        oz = obs[3]

        # Adjusting the coordinates to turbine reference frame (wind moving in y-direction)
        rxy = sqrt(ox^2+oy^2)
        ang = atan2(oy,ox)+windrad

        ox = rxy*cos(ang)
        oy = rxy*sin(ang)

        # Calculating the overall SPL of each of the turbines at the observer location
        tSPL[i] = OASPL(nseg,ox,oy,oz,windvel[i],rpm[i],B,Hub,rad,c,c1,alpha,nu,c0,psi,AR)
    end

    # Combining the SPLs from each turbine and correcting the value based on the wind farm
    SPL_obs = (10.0*log10(sum(10.0^(tSPL/10.0))))*noise_corr
    return SPL_obs
end #turbinepos


# end # module


# Option to plot a noise distribution around the turbines
plot_dist = true
# plot_dist = False # comment this out if desired on
turbine = "hawt"
turbine = "vawt"

##################################################################################
##################################################################################
##################################################################################

# Rosiere Valdiation (243.84 m, 800 ft should be 47 dB)
# http://www.mge.com/environment/green-power/wind/rosiere.htm
x_test = [0.] # x-locations of turbines (m)
y_test = [0.] # y-locations of turbines (m)
obs_test = [0., 243.84, 0.] # x-, y-, and z-location of the observer (m)
winddir_test = 0. # wind direction (deg)
rpm_test = [28.5] # rotation rate of the tubrines (rpm)
windvel_test = [15.] # wind velocity (m/s)
B_test = 3. # number of blades
h_test = 25. # height of the turbine hub (m)
noise_corr = 0.8697933840957954 # correction factor for noise

rad =  [1.069324603174603, 2.088888888888889, 3.1084531746031745, 4.382936507936508, 5.912301587301587, 7.441666666666666, 8.971031746031747, 10.500396825396825, 12.029761904761905, 13.559126984126985, 15.088492063492065, 16.617857142857144, 18.147222222222222, 19.6765873015873, 20.951070634920637, 21.97063492063492, 22.990199206349207, 23.5] # radial positions (m)
c =  [2.8941253867777776, 3.1490568155396828, 3.404805332214286, 3.7234696181666673, 3.8010929698730163, 3.6425779148095243, 3.4718065410555554, 3.2740712661825397, 3.062445496793651, 2.861441870269841, 2.660438243746032, 2.459434617222222, 2.258430990698413, 2.057427364174603, 1.889924342071429, 1.7044453858888888, 1.1594477481190477] # chord lengths (m)
alpha =  [13.308, 13.308, 13.308, 13.308, 11.48, 10.162, 9.011, 7.795, 6.544, 5.361, 4.188, 3.125, 2.319, 1.526, 0.863, 0.37, 0.106] # angles of attack (deg)
c1 = c*0.25 # pitch axis (m)
AR = 17. # blade aspect ratio

nu = 1.78e-5 # kinematic viscosity (m^2/s)
c0 = 343.2 # speed of sound (m/s)
psi = 14.0 # solid angle (deg)
                        (nturb,  nseg,     nobs,       x,            y,          obs,    winddir,windvel,rpm, B, Hub, rad,  c,  c1,alpha,nu,    c0,      psi, AR, noise_corr)
db_test_ros = turbinepos(x_test, y_test, obs_test, winddir_test, windvel_test, rpm_test, B_test, h_test, rad, c, c1, alpha, nu, c0, psi, AR, noise_corr)

println("Test Cases:")
println("Rosiere Validation (47 dB): $db_test_ros")

##################################################################################
##################################################################################
##################################################################################

# SPL Test Paremeters (changed to whatever desired)
x_test = [0.,5.] # x-locations of turbines (m)
y_test = [0.,5.] # y-locations of turbines (m)
obs_test = [0., 200., 0.] # x-, y-, and z-location of the observer (m)
winddir_test = 0. # wind direction (deg)
rpm_test = [28.5,28.5] # rotation rate of the tubrines (rpm)
windvel_test = [10.0,10.0] # wind velocity (m/s)
B_test = 3. # number of blades
h_test = 25. # height of the turbine hub (m)
noise_corr = 0.8697933840957954 # correction factor for noise

rad =  [1.069324603174603, 2.088888888888889, 3.1084531746031745, 4.382936507936508, 5.912301587301587, 7.441666666666666, 8.971031746031747, 10.500396825396825, 12.029761904761905, 13.559126984126985, 15.088492063492065, 16.617857142857144, 18.147222222222222, 19.6765873015873, 20.951070634920637, 21.97063492063492, 22.990199206349207, 23.5] # radial positions (m)
c =  [2.8941253867777776, 3.1490568155396828, 3.404805332214286, 3.7234696181666673, 3.8010929698730163, 3.6425779148095243, 3.4718065410555554, 3.2740712661825397, 3.062445496793651, 2.861441870269841, 2.660438243746032, 2.459434617222222, 2.258430990698413, 2.057427364174603, 1.889924342071429, 1.7044453858888888, 1.1594477481190477] # chord lengths (m)
alpha =  [13.308, 13.308, 13.308, 13.308, 11.48, 10.162, 9.011, 7.795, 6.544, 5.361, 4.188, 3.125, 2.319, 1.526, 0.863, 0.37, 0.106] # angles of attack (deg)
c1 = c*0.25 # pitch axis (m)
AR = 17. # blade aspect ratio

nu = 1.78e-5 # kinematic viscosity (m^2/s)
c0 = 343.2 # speed of sound (m/s)
psi = 14.0 # solid angle (deg)

db_test = turbinepos(x_test, y_test, obs_test, winddir_test, windvel_test, rpm_test, B_test, h_test, rad, c, c1, alpha, nu, c0, psi, AR, noise_corr)

println("Test SPL: $db_test")