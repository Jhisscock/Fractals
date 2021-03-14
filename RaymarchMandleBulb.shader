Shader "Explorer/MandleBulb"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MaxIter ("MaxIter", range(1, 20)) = 255
        _Power ("Power", float) = 1
        _Color("Color", range(0, 1)) = .5
        _Repeat("Repeat", float) = 1
        _Speed("Speed", float) = 1
        _Red("Red", range(0, 1)) = 1
        _Green("Green", range(0, 1)) = 1
        _Blue("Blue", range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #define MAX_STEPS 100
            #define MAX_DIST 100
            #define SURF_DIST .001
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _MaxIter, _Power, _Color, _Speed, _Repeat, _Red, _Green, _Blue;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                o.hitPos = v.vertex;
                return o;
            }

            float2 GetDist(float3 p){
                float3 z = p;
	            float dr = 1.0;
	            float r = 0.0;
                int iterations = 0;

	            for (int i = 0; i < _MaxIter ; i++) {
                    iterations = i;
	            	r = length(z);

	            	if (r>2) {
                        break;
                    }

	            	// convert to polar coordinates
	            	float theta = acos(z.z/r);
	            	float phi = atan2(z.y,z.x);
	            	dr =  pow( r, _Power-1.0)*_Power*dr + 1.0;

	            	// scale and rotate the point
	            	float zr = pow( r,_Power);
	            	theta = theta*_Power;
	            	phi = phi*_Power;

	            	// convert back to cartesian coordinates
	            	z = zr*float3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
	            	z += p;
	            }
                float dst = 0.5*log(r)*r/dr;
                return float2(dst, iterations);
            }

            float Raymarch(float3 ro, float3 rd){
                float dO = 0;
                float dS;
                for(int i = 0; i < MAX_STEPS; i++){
                    float3 p = ro + dO * rd;
                    dS = GetDist(p);
                    dO += dS;
                    if(dS < SURF_DIST || dO > MAX_DIST) break;
                }

                return dO;
            }

            float4 GetNormal(float3 p){
                float2 e = float2(.01, 0);
                float2 dist = GetDist(p);
                float3 n = dist.x - float3(
                        GetDist(p - e.xyy).x,
                        GetDist(p - e.yxy).x,
                        GetDist(p - e.yyx).x
                    );
                return float4(normalize(n), dist.y);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv - .5;
                float3 ro = i.ro;
                float3 rd = normalize(i.hitPos - ro);

                float d = Raymarch(ro, rd);
                fixed4 col = 0;

                if(d < MAX_DIST){
                    float3 p = ro + rd * d;
                    float4 n = GetNormal(p);
                    float m = sqrt(n.w / _MaxIter);

                    if(n.w >= _MaxIter - 1) return 0;
                    col.xyz = float3(_Red, _Green, _Blue) * n.xyz;
                    float4 mod = tex2D(_MainTex, float2(m  * _Repeat + _Time.y * _Speed, _Color));
                    col += mod;
                }else{
                    discard;
                }
                return col;
            }
            ENDCG
        }
    }
}
