Shader "RayMarching/Base"
{
	Properties
	{
		_Colors("Color",Color)=(1.0,1.0,1.0,0.0)
		_LightValue("LightLevel",Range(0.0,10.0))=1.25
	}
	SubShader
	{
		Cull Off
		Tags { 
			"RenderType"="Transparent" 
			"Queue" = "Transparent"
		}
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			uniform float4 _Colors;
			uniform float _LightValue;

			struct VertInput
			{
				float4 vertex : POSITION;
			};

			struct Ray{
				float3 org;
				float3 dir;
			};

			struct v2f
			{	

				float4 vertex : SV_POSITION;
				float2 screenPos : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};

			struct frag_out{
				//色と深度情報を返す
				half4 color : SV_Target;
				float depth : SV_Depth;
			};
			//深度情報を計算します。
			float computeDepth(float3 pos)
            {
                float4 vpPos = UnityObjectToClipPos(float4(pos, 1.0));
                #if UNITY_UV_STARTS_AT_TOP
                    return vpPos.z / vpPos.w;
                #else
                    return (vpPos.z / vpPos.w) * 0.5 + 0.5;
                #endif
            }

			//球のレイマーチングを行う距離関数
			float sphere(float3 pos,float size){
				return length(pos)-size;
			}
			//箱のレイマーチングを行う距離関数
			float sdBox(float3 pos,float size){
				float3 d = abs(pos) - size;
				return length(max(d,0.0))
						+min(max(d.x,max(d.y,d.z)),0.0);
			}
			//全体の距離関数　ここをいじれば形が変わる
			float2 distFunc(float3 pos){
				return float2(sphere(pos,0.1),1.0);
			}
			//ライティングとかに必要になる法線ベクトルを生成する関数
			//極微小な数値のずれをx,y,zから取得し、それをnormalize（ベクトルの長さを1に）することで得る
			float3 generateNormal(float3 p){
				//レイマーチングで必要な法線ベクトルを作る
				//float d = 0.0001;
				const float3 d = float3(0.0001,0.0,0.0);
				float x = distFunc(p+d.xyy)-distFunc(p-d.xyy);
				float y = distFunc(p+d.yxy)-distFunc(p-d.yxy);
				float z = distFunc(p+d.yyx)-distFunc(p-d.yyx);
				return normalize(float3(x,y,z));
			}
			
			v2f vert (VertInput v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);		//実座標(640,360)etc
                o.screenPos = o.vertex;							//UV座標(0-1)
                o.worldPos = v.vertex.xyz;						//もともとの頂点座標
                return o;
            }
			
			frag_out frag (v2f i)
			{
				// Put the results and return this.
				frag_out o;
				//レイマーチング用のレイの定義
				Ray ray;
				//レイの原点を現在のカメラ位置をワールド座標に置き換えたものに定義
				ray.org = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1.0));
				ray.dir = normalize(i.worldPos - ray.org);

				float3 posOnRay = ray.org;
				float maxStep = 32;
				float lightValue = _LightValue; //ライトの明るさ調整
				float threshold = 0.001;		//衝突したと判定する閾値
				float maxDistance = 10.0;		//あとでカメラからMax距離を作成
				float tmp;
				float2 dist;
				tmp = 0.0;

				//Marching Loop
				for(int i=0;i<maxStep;i++){
					dist = distFunc(posOnRay);
					tmp += dist.x;
					posOnRay = ray.org + tmp*ray.dir;
					if(dist.x<threshold||dist.x>maxDistance)
						break;
				}

				//レイがオブジェクトにぶつかったか判定
				float4 color;
				//ぶつかっていれば一定より小さいはず、大きかったらそのピクセルはdiscard(処理しない)
				if(abs(dist.x)>threshold)
					discard;
				else{
					//法線ベクトルを作成
					float3 normal = generateNormal(posOnRay);
					//_WorldSpaceLightPos0でシーン内のライトの位置を取得できる
					float diff = clamp(dot(_WorldSpaceLightPos0,normal),0.1,1.0);
					color = _Colors * diff * lightValue;
				}
				o.color = color;
				o.depth = computeDepth(posOnRay);
				return o;
			}
			ENDCG
		}
	}
}
