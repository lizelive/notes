// Principled PBR Shader. Except where otherwise noted:

// Copyright © 2019 Markus Moenig Distributed under The MIT License.
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// 
// Based on an collaboration with pixotronics.com

// Implementation of http://disney-animation.s3.amazonaws.com/library/s2012_pbs_disney_brdf_notes_v2.pdf

// Turn off the incorrectly sharp local reflections here
const bool useReflections = true;

#define SAMPLES 1
#define MAXDEPTH 4.

#define PI 3.14159265359
#define TWO_PI 6.28318
#define NUM_SPHERES 6

#define LIGHT_ID 1.
#define SPHERE_ID1 2.
#define SPHERE_ID2 3.
#define SPHERE_ID3 4.
#define SPHERE_ID4 5.
#define SPHERE_ID5 6.
#define SPHERE_ID6 7.
#define FLOOR_ID 8.

#define LIGHT_TYPE_SPHERE 0
#define LIGHT_TYPE_SUN    1

#define EPSILON 0.0001
#define INFINITY 1000000.

#define RAY_MARCH_STEPS 200

#define IS_SAME_MATERIAL(id1, id2) (id1 == id2)

#define Le vec3(10.)

#define clearCoatBoost 1.

/* Sun/Directional Light Parameters

SUN_DIRECTION   - Mean direction
SUN_SOLID_ANGLE - The solid angle sun subtens at eye. higher value will create softer shadows.
sunLe           - Radiance

*/

#define SUN_DIRECTION vec3(-1.,1.,1.)
#define SUN_SOLID_ANGLE 6.87E-2     
#define sunLe vec3(2.)

#define USE_MIS

struct LightInfo {
    vec3 L;
    vec3 position;
    vec3 direction;
    float radius;
    int type;
    bool enabled;
};

struct Sphere {
    float r;
    vec3 p;
};
    
struct Plane {
    vec3 p;
    vec4 n;
};

struct Ray {
    vec3 origin;
    vec3 direction;
};


struct MaterialInfo {
    vec3  baseColor;
    float subsurface;
    float roughness;
    float metallic;
    float specular;
    float specularTint;
    float clearcoat;
    float clearcoatGloss;
    float anisotropic;
    float sheen;
    float sheenTint;
};

Sphere spheres[NUM_SPHERES+1];
Plane  planes[1];

float seed = 0.;

#define NUM_LIGHTS 2
LightInfo lights[NUM_LIGHTS];

void initScene() {
    
    int count = 0;
    float radius = 0.55;
    spheres[count++] = Sphere(0.24, vec3(0.,2.5, 0.5));

    float x = -3.;
    float y = 1.;

    for( int i=0; i < 6; ++i ) {
        spheres[count++] = Sphere(radius, vec3(x, y, 0.));
        x += 2.2 * radius;
    }
    
    planes[0] = Plane(vec3(0.,0.85,0.), vec4(0.,1.,0., 1.));
    
    lights[0] = LightInfo(Le, spheres[0].p, vec3(0.), spheres[0].r, LIGHT_TYPE_SPHERE, true);
    lights[1] = LightInfo(sunLe, vec3(0.), normalize(SUN_DIRECTION), 0., LIGHT_TYPE_SUN, true);

}

struct SurfaceInteraction {
    float id;
    vec3 incomingRayDir;
    vec3 point;
    vec3 normal;
    vec3 tangent;
    vec3 binormal;
    float objId;
};

///////////////////////////////////////////////////////////////////////
//////////////////////// Utility Functions ///////////////////////////
///////////////////////////////////////////////////////////////////////

vec3 linearToGamma(const in vec3 linearColor) {
   return pow(linearColor, vec3(0.4545));
}

vec3 gammaToLinear(const in vec3 gammaColor) {
   return pow(gammaColor, vec3(2.2));
}

#define HASHSCALE3 vec3(.1031, .1030, .0973)
vec2 hash21(float p) {
    vec3 p3 = fract(vec3(p) * HASHSCALE3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec2((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y));
}

#define HASHSCALE1 .1031
float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float random() {
   return fract(sin(seed++)*43758.5453123);
}

float distanceSq(vec3 v1, vec3 v2) {
    vec3 d = v1 - v2;
    return dot(d, d);
}

float pow2(float x) { 
    return x*x;
}

void createBasis(vec3 normal, out vec3 tangent, out vec3 binormal){
    if (abs(normal.x) > abs(normal.y)) {
        tangent = normalize(vec3(0., normal.z, -normal.y));
    }
    else {
        tangent = normalize(vec3(-normal.z, 0., normal.x));
    }
    
    binormal = cross(normal, tangent);
}

void directionOfAnisotropicity(vec3 normal, out vec3 tangent, out vec3 binormal){
    tangent = cross(normal, vec3(1.,0.,1.));
    binormal = normalize(cross(normal, tangent));
    tangent = normalize(cross(normal,binormal));
}

vec3 sphericalDirection(float sinTheta, float cosTheta, float sinPhi, float cosPhi) {
    return vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
}

vec3 uniformSampleCone(vec2 u12, float cosThetaMax, vec3 xbasis, vec3 ybasis, vec3 zbasis) {
    float cosTheta = (1. - u12.x) + u12.x * cosThetaMax;
    float sinTheta = sqrt(1. - cosTheta * cosTheta);
    float phi = u12.y * TWO_PI;
    vec3 samplev = sphericalDirection(sinTheta, cosTheta, sin(phi), cos(phi));
    return samplev.x * xbasis + samplev.y * ybasis + samplev.z * zbasis;
}

bool sameHemiSphere(const in vec3 wo, const in vec3 wi, const in vec3 normal) {
    return dot(wo, normal) * dot(wi, normal) > 0.0;
}

vec2 concentricSampleDisk(const in vec2 u) {
    vec2 uOffset = 2. * u - vec2(1., 1.);

    if (uOffset.x == 0. && uOffset.y == 0.) return vec2(0., 0.);

    float theta, r;
    if (abs(uOffset.x) > abs(uOffset.y)) {
        r = uOffset.x;
        theta = PI/4. * (uOffset.y / uOffset.x);
    } else {
        r = uOffset.y;
        theta = PI/2. - PI/4. * (uOffset.x / uOffset.y);
    }
    return r * vec2(cos(theta), sin(theta));
}

vec3 cosineSampleHemisphere(const in vec2 u) {
    vec2 d = concentricSampleDisk(u);
    float z = sqrt(max(EPSILON, 1. - d.x * d.x - d.y * d.y));
    return vec3(d.x, d.y, z);
}

vec3 uniformSampleHemisphere(const in vec2 u) {
    float z = u[0];
    float r = sqrt(max(EPSILON, 1. - z * z));
    float phi = 2. * PI * u[1];
    return vec3(r * cos(phi), r * sin(phi), z);
}

///////////////////////////////////////////////////////////////////////
///////////// DISTANCE FIELDS AND RAY MARCHING ////////////////////////
///////////////////////////////////////////////////////////////////////

float sdSphere( vec3 p, float r) { 
    return length(p) - r;
}

float sdPlane( vec3 p, vec4 n ) {
  return dot(p,n.xyz) + n.w;
}

vec2 opU(vec2 o1, vec2 o2) {
    return (o1.x < o2.x) ? o1 : o2;
}

vec2 map(vec3 p) {
    
    vec2 sphereObj =  vec2(sdSphere(p - spheres[1].p, spheres[1].r), SPHERE_ID1);        
    vec2 resultObj = sphereObj;

    vec2 newObj =  vec2(sdSphere(p - spheres[2].p, spheres[2].r), SPHERE_ID2);
    resultObj = opU(resultObj, newObj);
    newObj =  vec2(sdSphere(p - spheres[3].p, spheres[3].r), SPHERE_ID3);
    resultObj = opU(resultObj, newObj);
    newObj =  vec2(sdSphere(p - spheres[4].p, spheres[4].r), SPHERE_ID4);
    resultObj = opU(resultObj, newObj);
    newObj =  vec2(sdSphere(p - spheres[5].p, spheres[5].r), SPHERE_ID5);
    resultObj = opU(resultObj, newObj);
    newObj =  vec2(sdSphere(p - spheres[6].p, spheres[6].r), SPHERE_ID6);
    resultObj = opU(resultObj, newObj);
    newObj =  vec2(sdPlane(p - planes[0].p, planes[0].n), FLOOR_ID);
    resultObj = opU(resultObj, newObj);
    newObj =  vec2(sdSphere(p - spheres[0].p, spheres[0].r), LIGHT_ID);
    resultObj = opU(resultObj, newObj);
    
    return resultObj;
}

vec3 calculateNormal(vec3 p) {
 
    vec3 epsilon = vec3(0.001, 0., 0.);
    
    vec3 n = vec3(map(p + epsilon.xyy).x - map(p - epsilon.xyy).x,
                  map(p + epsilon.yxy).x - map(p - epsilon.yxy).x,
                  map(p + epsilon.yyx).x - map(p - epsilon.yyx).x);
    
    return normalize(n);
}

SurfaceInteraction rayMarch(vec3 ro, vec3 rd) {
    
    SurfaceInteraction interaction = SurfaceInteraction(-1., rd, vec3(0.), vec3(0.), vec3(0.), vec3(0.), -10.);
    
    float t = 0.;
    vec3 p = ro;    
    vec2 obj = vec2(0.);
    float d = INFINITY;
    
    for (int i = 0; i < RAY_MARCH_STEPS; i++) {
        
        obj = map(p);
        d = obj.x;
        
        t += d;
        p += rd * d;
        
        if (d < .001) { break; }
        obj.y = 0.;
        
    }

    interaction.id = obj.y;        
    interaction.point = p;
    interaction.normal = calculateNormal(interaction.point);
    interaction.objId = obj.y;
    return interaction;
}

MaterialInfo getMaterial(SurfaceInteraction interaction, out bool found){
    MaterialInfo material = MaterialInfo(vec3(.8), 0., 1., 0., 0., 0., 0., 1., 0., 0., 0.);
	found = true;
    if (interaction.id < .5) {
        //L += beta * gammaToLinear(texture(iChannel0, ray.direction).rgb) ;//BG Color
        found = false;
    }        
    else if (IS_SAME_MATERIAL(interaction.id, LIGHT_ID)) {
        material.baseColor = lights[0].L;
        return material;
    }
    else if (IS_SAME_MATERIAL(interaction.id, SPHERE_ID1)) {
        material.baseColor = vec3(0.815, .00418501512, .00180012);
        material.sheen = 1.;
    }
    else if (IS_SAME_MATERIAL(interaction.id, SPHERE_ID2)) {
        material.baseColor = vec3(0.815, .418501512, .00180012);
        material.metallic = 1.;
        material.roughness = 0.53;
        material.specular = 0.3;
    }
    else if (IS_SAME_MATERIAL(interaction.id, SPHERE_ID3)) {
        material.baseColor = vec3(0.815, .00418501512, .00180012);
        material.specular = 1.;
    }
    else if (IS_SAME_MATERIAL(interaction.id, SPHERE_ID4)) {
        material.baseColor = vec3(0.9, 0.4,0.3);
        material.roughness = 0.9;
        material.metallic = 1.;
        material.anisotropic = 1.;
    }
    else if (IS_SAME_MATERIAL(interaction.id, SPHERE_ID5)) {
        material.baseColor = vec3(0.5, .1501512, .80012);
        material.specular = 0.1;
        material.roughness = 0.1;
        material.clearcoatGloss = 1.;
    }
    else if (IS_SAME_MATERIAL(interaction.id, SPHERE_ID6)) {
        material.baseColor = vec3(0.025, .2501512, .0180012);
        material.clearcoat = 1.;
        material.specular = 0.1;
        //material.subsurface = 1.;
        material.clearcoatGloss = 1.;
    }
    else if (IS_SAME_MATERIAL(interaction.id, FLOOR_ID)) {
        material.baseColor = pow(texture( iChannel0, interaction.point.xz ).xyz, vec3(2.2f));
        material.roughness = 0.7 - clamp( 0.5 - dot( material.baseColor, material.baseColor ), 0.05, 0.95 );;
            }
    else {
        found = false;
    }
    return material;
}

//Soft Shadows :: https://iquilezles.org/articles/rmshadows
SurfaceInteraction calcSoftshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax, int technique,out float shadowValue ) {
    vec3 p = ro;
    float res = 1.0;
    float t = mint;
    float ph = 1e10; // big, such that y = 0 on the first iteration
    vec2 obj = vec2(0.);
    SurfaceInteraction interaction = SurfaceInteraction(-1., rd, vec3(0.), vec3(0.), vec3(0.), vec3(0.), -10.);
    
    for( int i=0; i<RAY_MARCH_STEPS; i++ )
    {
        obj = map(p);
        
        if(obj.y == LIGHT_ID) {
           break;
        }
        //obj = map( ro + rd*t );
        float h = obj.x;

        // traditional technique
        if( technique==0 )
        {
            res = min( res, 10.0*h/t );
        }
        // improved technique
        else
        {
            // use this if you are getting artifact on the first iteration, or unroll the
            // first iteration out of the loop
            float y = (i==0) ? 0.0 : h*h/(2.0*ph); 

            //float y = h*h/(2.0*ph);
            float d = sqrt(h*h-y*y);
            res = min( res, 10.0*d/max(0.0,t-y) );
            ph = h;
        }
        
        t += h;
        p += rd * h;
        
        if( res<0.0001 || t>tmax ) break;
        obj.y = 0.;
        
    }
    interaction.id = obj.y;        
    interaction.point = p;
    interaction.normal = calculateNormal(interaction.point);
    interaction.objId = obj.y;
    
    shadowValue = clamp( res, 0.0, 1.0 );
    return interaction;//clamp( res, 0.0, 1.0 );
}

float visibilityTest(vec3 ro, vec3 rd) {
    float softShadowValue = 1.;
    SurfaceInteraction interaction = calcSoftshadow(ro, rd, 0.01, 3., 3, softShadowValue);
    return softShadowValue;
}

float visibilityTestSun(vec3 ro, vec3 rd) {
    float softShadowValue = 1.;
    SurfaceInteraction interaction = calcSoftshadow(ro, rd, 0.01, 3., 0, softShadowValue);
    return softShadowValue;//IS_SAME_MATERIAL(interaction.objId, 0.) ? 1. : 0.;
}


float powerHeuristic(float nf, float fPdf, float ng, float gPdf){
    float f = nf * fPdf;
    float g = ng * gPdf;
    return (f*f)/(f*f + g*g);
}
///////////////////////////////////////////////////////////////////////
///////////////////////  PDF's and BRDF's  ////////////////////////////
///////////////////////////////////////////////////////////////////////

// Disney brdf's taken from here:: https://github.com/wdas/brdf/blob/master/src/brdfs/disney.brdf
float schlickWeight(float cosTheta) {
    float m = clamp(1. - cosTheta, 0., 1.);
    return (m * m) * (m * m) * m;
}

float GTR1(float NdotH, float a) {
    if (a >= 1.) return 1./PI;
    float a2 = a*a;
    float t = 1. + (a2-1.)*NdotH*NdotH;
    return (a2-1.) / (PI*log(a2)*t);
}

float GTR2(float NdotH, float a) {
    float a2 = a*a;
    float t = 1. + (a2-1.)*NdotH*NdotH;
    return a2 / (PI * t*t);
}

float GTR2_aniso(float NdotH, float HdotX, float HdotY, float ax, float ay) {
    return 1. / (PI * ax*ay * pow2( pow2(HdotX/ax) + pow2(HdotY/ay) + NdotH*NdotH ));
}

float smithG_GGX(float NdotV, float alphaG) {
    float a = alphaG*alphaG;
    float b = NdotV*NdotV;
    return 1. / (abs(NdotV) + max(sqrt(a + b - a*b), EPSILON));
}

float smithG_GGX_aniso(float NdotV, float VdotX, float VdotY, float ax, float ay) {
    return 1. / (NdotV + sqrt( pow2(VdotX*ax) + pow2(VdotY*ay) + pow2(NdotV) ));
}

float pdfLambertianReflection(const in vec3 wi, const in vec3 wo, const in vec3 normal) {
    return sameHemiSphere(wo, wi, normal) ? abs(dot(normal, wi))/PI : 0.;
}

float pdfMicrofacet(const in vec3 wi, const in vec3 wo, const in SurfaceInteraction interaction, const in MaterialInfo material) {
    if (!sameHemiSphere(wo, wi, interaction.normal)) return 0.;
    vec3 wh = normalize(wo + wi);
    
    float NdotH = dot(interaction.normal, wh);
    float alpha2 = material.roughness * material.roughness;
    alpha2 *= alpha2;
    
    float cos2Theta = NdotH * NdotH;
    float denom = cos2Theta * ( alpha2 - 1.) + 1.;
    if( denom == 0. ) return 0.;
    float pdfDistribution = alpha2 * NdotH /(PI * denom * denom);
    return pdfDistribution/(4. * dot(wo, wh));
}

float pdfMicrofacetAniso(const in vec3 wi, const in vec3 wo, const in vec3 X, const in vec3 Y, const in SurfaceInteraction interaction, const in MaterialInfo material) {
    if (!sameHemiSphere(wo, wi, interaction.normal)) return 0.;
    vec3 wh = normalize(wo + wi);
    
    float aspect = sqrt(1.-material.anisotropic*.9);
    float alphax = max(.001, pow2(material.roughness)/aspect);
    float alphay = max(.001, pow2(material.roughness)*aspect);
    
    float alphax2 = alphax * alphax;
    float alphay2 = alphax * alphay;

    float hDotX = dot(wh, X);
    float hDotY = dot(wh, Y);
    float NdotH = dot(interaction.normal, wh);
    
    float denom = hDotX * hDotX/alphax2 + hDotY * hDotY/alphay2 + NdotH * NdotH;
    if( denom == 0. ) return 0.;
    float pdfDistribution = NdotH /(PI * alphax * alphay * denom * denom);
    return pdfDistribution/(4. * dot(wo, wh));
}

float pdfClearCoat(const in vec3 wi, const in vec3 wo, const in SurfaceInteraction interaction, const in MaterialInfo material) {
    if (!sameHemiSphere(wo, wi, interaction.normal)) return 0.;

    vec3 wh = wi + wo;
    wh = normalize(wh);
    
    float NdotH = abs(dot(wh, interaction.normal));
    float Dr = GTR1(NdotH, mix(.1,.001,material.clearcoatGloss));
    return Dr * NdotH/ (4. * dot(wo, wh));
}

vec3 disneyDiffuse(const in float NdotL, const in float NdotV, const in float LdotH, const in MaterialInfo material) {
    
    float FL = schlickWeight(NdotL), FV = schlickWeight(NdotV);
    
    float Fd90 = 0.5 + 2. * LdotH*LdotH * material.roughness;
    float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);
    
    return (1./PI) * Fd * material.baseColor;
}

vec3 disneySubsurface(const in float NdotL, const in float NdotV, const in float LdotH, const in MaterialInfo material) {
    
    float FL = schlickWeight(NdotL), FV = schlickWeight(NdotV);
    float Fss90 = LdotH*LdotH*material.roughness;
    float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
    float ss = 1.25 * (Fss * (1. / (NdotL + NdotV) - .5) + .5);
    
    return (1./PI) * ss * material.baseColor;
}

vec3 disneyMicrofacetIsotropic(float NdotL, float NdotV, float NdotH, float LdotH, const in MaterialInfo material) {
    
    float Cdlum = .3*material.baseColor.r + .6*material.baseColor.g + .1*material.baseColor.b; // luminance approx.

    vec3 Ctint = Cdlum > 0. ? material.baseColor/Cdlum : vec3(1.); // normalize lum. to isolate hue+sat
    vec3 Cspec0 = mix(material.specular *.08 * mix(vec3(1.), Ctint, material.specularTint), material.baseColor, material.metallic);
    
    float a = max(.001, pow2(material.roughness));
    float Ds = GTR2(NdotH, a);
    float FH = schlickWeight(LdotH);
    vec3 Fs = mix(Cspec0, vec3(1), FH);
    float Gs;
    Gs  = smithG_GGX(NdotL, a);
    Gs *= smithG_GGX(NdotV, a);
    
    return Gs*Fs*Ds;
}

vec3 disneyMicrofacetAnisotropic(float NdotL, float NdotV, float NdotH, float LdotH,
                                 const in vec3 L, const in vec3 V,
                                 const in vec3 H, const in vec3 X, const in vec3 Y,
                                 const in MaterialInfo material) {
    
    float Cdlum = .3*material.baseColor.r + .6*material.baseColor.g + .1*material.baseColor.b;

    vec3 Ctint = Cdlum > 0. ? material.baseColor/Cdlum : vec3(1.);
    vec3 Cspec0 = mix(material.specular *.08 * mix(vec3(1.), Ctint, material.specularTint), material.baseColor, material.metallic);
    
    float aspect = sqrt(1.-material.anisotropic*.9);
    float ax = max(.001, pow2(material.roughness)/aspect);
    float ay = max(.001, pow2(material.roughness)*aspect);
    float Ds = GTR2_aniso(NdotH, dot(H, X), dot(H, Y), ax, ay);
    float FH = schlickWeight(LdotH);
    vec3 Fs = mix(Cspec0, vec3(1), FH);
    float Gs;
    Gs  = smithG_GGX_aniso(NdotL, dot(L, X), dot(L, Y), ax, ay);
    Gs *= smithG_GGX_aniso(NdotV, dot(V, X), dot(V, Y), ax, ay);
    
    return Gs*Fs*Ds;
}

float disneyClearCoat(float NdotL, float NdotV, float NdotH, float LdotH, const in MaterialInfo material) {
    float gloss = mix(.1,.001,material.clearcoatGloss);
    float Dr = GTR1(abs(NdotH), gloss);
    float FH = schlickWeight(LdotH);
    float Fr = mix(.04, 1.0, FH);
    float Gr = smithG_GGX(NdotL, .25) * smithG_GGX(NdotV, .25);
    return clearCoatBoost * material.clearcoat * Fr * Gr * Dr;
}

vec3 disneySheen(float LdotH, const in MaterialInfo material) {
    float FH = schlickWeight(LdotH);
    float Cdlum = .3*material.baseColor.r + .6*material.baseColor.g  + .1*material.baseColor.b;

    vec3 Ctint = Cdlum > 0. ? material.baseColor/Cdlum : vec3(1.);
    vec3 Csheen = mix(vec3(1.), Ctint, material.sheenTint);
    vec3 Fsheen = FH * material.sheen * Csheen;
    return FH * material.sheen * Csheen;
}

vec3 lightSample( const in LightInfo light, const in SurfaceInteraction interaction, out vec3 wi, out float lightPdf, float seed, const in MaterialInfo material) {
    vec3 L = (light.position - interaction.point);
    vec3 V = -normalize(interaction.incomingRayDir);
    vec3 r = reflect(V, interaction.normal);
    vec3 centerToRay = dot( L, r ) * r - L;
    vec3 closestPoint = L + centerToRay * clamp( light.radius / length( centerToRay ), 0.0, 1.0 );
    wi = normalize(closestPoint);


    return light.L/dot(L, L);
}

vec3 sampleSun(const in LightInfo light, const in SurfaceInteraction interaction, out vec3 wi, out float lightPdf, float seed) {
    wi = light.direction;
    return light.L;
}

float lightPdf(const in vec4 light, const in SurfaceInteraction interaction) {
    float sinThetaMax2 = light.w * light.w / distanceSq(light.xyz, interaction.point);
    float cosThetaMax = sqrt(max(EPSILON, 1. - sinThetaMax2));
    return 1. / (TWO_PI * (1. - cosThetaMax));
}


vec3 bsdfEvaluate(const in vec3 wi, const in vec3 wo, const in vec3 X, const in vec3 Y, const in SurfaceInteraction interaction, const in MaterialInfo material) {
    if( !sameHemiSphere(wo, wi, interaction.normal) )
        return vec3(0.);
    
    float NdotL = dot(interaction.normal, wo);
    float NdotV = dot(interaction.normal, wi);
    
    if (NdotL < 0. || NdotV < 0.) return vec3(0.);

    vec3 H = normalize(wo+wi);
    float NdotH = dot(interaction.normal,H);
    float LdotH = dot(wo,H);
    
    vec3 diffuse = disneyDiffuse(NdotL, NdotV, LdotH, material);
    vec3 subSurface = disneySubsurface(NdotL, NdotV, LdotH, material);
    vec3 glossy = disneyMicrofacetAnisotropic(NdotL, NdotV, NdotH, LdotH, wi, wo, H, X, Y, material);
    float clearCoat = disneyClearCoat(NdotL, NdotV, NdotH, LdotH, material);
    vec3 sheen = disneySheen(LdotH, material);

    vec3 f = ( mix(diffuse, subSurface, material.subsurface) + sheen ) * (1. - material.metallic);
    f += glossy;
    f += clearCoat;
    //f = material.specular * Lr + (1.f - material.specular) * f;
    return f;
}



vec3 sampleLightType( const in LightInfo light, const in SurfaceInteraction interaction, out vec3 wi, out float lightPdf, out float visibility, float seed, const in MaterialInfo material) {
    if( !light.enabled )
        return vec3(0.);
    
    if( light.type == LIGHT_TYPE_SPHERE ) {
        vec3 L = lightSample(light, interaction, wi, lightPdf, seed, material);
        vec3 shadowRayDir =normalize(light.position - interaction.point);
        visibility = visibilityTest(interaction.point + shadowRayDir * .01, shadowRayDir);
        return L;
    }
    else if( light.type == LIGHT_TYPE_SUN ) {
        vec3 L = sampleSun(light, interaction, wi, lightPdf, seed);
        visibility = visibilityTestSun(interaction.point + wi * .01, wi);
        return L;
    }
    else {
        return vec3(0.);
    }
}

// From https://www.shadertoy.com/view/XlKSDR

vec3 Irradiance_SphericalHarmonics(const vec3 n) {
    // Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
    return max(
          vec3( 0.754554516862612,  0.748542953903366,  0.790921515418539)
        + vec3(0.3,  0.3,  0.3) * (n.y)
        + vec3( 0.35,  0.36,  0.35) * (n.z)
        + vec3(-0.2, -0.24, -0.24) * (n.x)
        , 0.0);
}

vec2 PrefilteredDFG_Karis(float roughness, float NoV) {
    // Karis 2014, "Physically Based Material on Mobile"
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572,  0.022);
    const vec4 c1 = vec4( 1.0,  0.0425,  1.040, -0.040);

    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;

    return vec2(-1.04, 1.04) * a004 + r.zw;
}

vec3 calculateDirectLight(const in LightInfo light, const in SurfaceInteraction interaction, const in MaterialInfo material, out vec3 wi, out vec3 f, out float scatteringPdf) {
    
        
    vec3 wo = -interaction.incomingRayDir;
    vec3 Ld = vec3(0.);
    float lightPdf = 0., visibility = 1.;

    vec3 Li = sampleLightType( light, interaction, wi, lightPdf, visibility, seed, material);
    Li *= visibility;

    f = bsdfEvaluate(wi, wo, interaction.tangent, interaction.binormal, interaction, material) * abs(dot(wi, interaction.normal));        
    Ld += Li * f;

    return Ld;
}
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////

Ray getCameraRay(vec2 offset) {
    vec3 origin = vec3(0.0, 2.5, 6.0);
    vec3 lookAt = vec3(0., 1.2, 0.);

    vec2 uv = (gl_FragCoord.xy + offset) / iResolution.xy - .5;
    uv.y *= iResolution.y / iResolution.x;

    vec3 iu = vec3(0., 1., 0.);

    vec3 iz = normalize( lookAt - origin );
    vec3 ix = normalize( cross(iz, iu) );
    vec3 iy = cross(ix, iz);

    vec3 direction = normalize( uv.x * ix + uv.y * iy + .85 * iz );

    return Ray(origin, direction);
}

vec3 calculatePixelColor() {
        
    vec3 L = vec3(0.);
    vec3 beta = vec3(1.);
    
    vec2 uv = gl_FragCoord.xy / iResolution.xy;            
    seed = float(iFrame) + hash12( uv );
    vec3 wi;
    
    Ray ray = getCameraRay( vec2(random(), random()) );
    

    for (float depth = 0.; depth < 1.; ++depth) {
        
        SurfaceInteraction interaction = rayMarch(ray.origin, ray.direction);
		bool found = false;
        MaterialInfo material = getMaterial(interaction, found);
        if(IS_SAME_MATERIAL(interaction.id, LIGHT_ID) && depth == 0.){
            L += vec3(Le);
            break;
        }
        if(!found){
            break;
        }

        vec3 X = vec3(0.), Y = vec3(0.);
        directionOfAnisotropicity(interaction.normal, X, Y);
        interaction.tangent = X;
        interaction.binormal = Y;
        
        vec3 wi;
        vec3 f = vec3(0.);
        float scatteringPdf = 0.;
        vec3 Ld = beta * calculateDirectLight(lights[1], interaction, material, wi, f, scatteringPdf);
        Ld += beta * calculateDirectLight(lights[0], interaction, material, wi, f, scatteringPdf);
        L += Ld;
        
        // Add indirect diffuse light from an env map
        vec3 diffuseColor = (1.0 - material.metallic) * material.baseColor.rgb ;
        L += diffuseColor * Irradiance_SphericalHarmonics(interaction.normal)/3.14;
        
        
        if(useReflections) {
            
            vec3 f0 = 0.04 * (1.0 - material.metallic) + material.baseColor.rgb * material.metallic;
        	vec2 dfg = PrefilteredDFG_Karis(material.roughness, abs(dot(interaction.normal, ray.direction)));
        	vec3 specularColor = f0 * dfg.x + dfg.y;
        
            vec3 r = reflect(normalize(interaction.incomingRayDir), interaction.normal);
            SurfaceInteraction interaction1 = rayMarch(interaction.point + .02 * r, r);
            MaterialInfo m = getMaterial(interaction1, found);
            if(found && !IS_SAME_MATERIAL(interaction1.id, LIGHT_ID)) {
                L += m.baseColor * specularColor;
            }
            if(!found) {
                // add env map reflection here
                //L += m.baseColor * envMapColor;
            }
        }
        

    }
    
    return L;   
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    
    initScene();
        
    vec2 uv = fragCoord.xy / iResolution.xy;        

    float seed = float(iFrame) + hash12( uv );
    
    vec3 pixelColor = calculatePixelColor( );   
    
    vec3 finalColor = (pixelColor);
    fragColor = vec4(clamp(finalColor, vec3(0.), vec3(10.)),1.0);
}
