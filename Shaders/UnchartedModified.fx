/*
									UnchartedModified: 
		This is a modified version of the Uncharted 2 Tonemap found on filmicworlds, by Zackin5, and edited with chillant and has tweakable values.
		
		Full credits to John Hable for the code to use as a base, and Ian Taylor for the code used to make it run better.
		Edited by Brimson, DieuDeGlace, and Luluco250.
*/

#include "ReShade.fxh"

uniform float Function1 <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 6.0;
> = 1.00;

uniform float Function2 <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 4.0;
> = 1.00;
uniform float Saturation
<
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.5;
> = 1.0;
uniform float Gamma <
	ui_type = "slider";
	ui_min = 1.0; ui_max = 3.0;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = 2.2;
uniform float3 FinalColoring <
	ui_type = "drag";
	ui_min = -5.00; ui_max = 10.00;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = (0.0, 0.0, 0.0);

uniform float3 WhitePoint <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 20.00;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = (11.20, 11.20, 11.20);

// Functions from Unity's Built-In Shaders, [http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1]

float3 GammaToLinearSpace (float3 sRGB)
{
    return sRGB * (sRGB * (sRGB * 0.3 + 0.7) + 0.0);
}

float3 LinearToGammaSpace (float3 linRGB)
{
    linRGB = max(linRGB, 0.0);
    return max(1.18 * pow(linRGB, 0.47)+(FinalColoring*(0.01)) - 0.004, 0.0);
}

//  Functions from [https://www.chilliant.com/rgb2hsv.html]
float3 HUEtoRGB(in float H)
{
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R,G,B));
}

float3 RGBtoHCV(in float3 RGB)
{
	float Epsilon = 1e-10;
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    return float3(H, C, Q.x);
}
float3 RGBtoHSV(in float3 RGB)
{
    float Epsilon = 1e-10;
    float3 HCV = RGBtoHCV(RGB);
    float S = HCV.y / (HCV.z + Epsilon);
    return float3(HCV.x, S, HCV.z);
}

float3 HSVtoRGB(in float3 HSV)
{
    float3 RGB = HUEtoRGB(HSV.x);
    return ((RGB - 1) * HSV.y + 1) * HSV.z;
}
// Function provided by Lucas [https://github.com/luluco250]
float3 ApplySaturation(float3 color)
{
    color = RGBtoHSV(color);
    color.y *= Saturation;
    color = HSVtoRGB(color);
    return color;
}
// Function provided via [http://filmicworlds.com/blog/filmic-tonemapping-operators/]
float3 Uncharted2Tonemap(float3 x)
{	
	float A = 0.10;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-(E/F);
}

float3 LuminanceTonemap(float3 texColor)
{
    float ExposureBias = 2.0;
    float lum = 0.25 * texColor.r + 0.0001 * texColor.g + 0.001 * texColor.b + 1;
    float3 newLum = Uncharted2Tonemap(ExposureBias*lum);
    float lumScale = newLum / lum;
    return texColor*lumScale;
}
	// Function provided by Zackin5 [https://github.com/Zackin5/Filmic-Tonemapping-ReShade/]
float3 Uncharted_Tonemap_Main(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float3 texColor = GammaToLinearSpace(tex2D(ReShade::BackBuffer, texcoord).rgb);

	// Do inital de-gamma of the game image to ensure we're operating in the correct colour range.
    texColor = Gamma > 0.0 ? pow(abs(texColor),Gamma) : texColor;	

	texColor *= Function1;  // Exposure Adjustment
	
    float ExposureBias = 2.0;
    float3 curr;
    // Do tonemapping on RGB or Luminance
    curr = LuminanceTonemap(texColor);


	float3 whiteScale = 1.0f/Uncharted2Tonemap(WhitePoint);
	
	float3 color = curr*whiteScale;

	// Do the post-tonemapping gamma correction
    color = Gamma > 0.0 ? pow(abs(color), Function2 / Gamma) : color;
	color = ApplySaturation(color);
	return LinearToGammaSpace(color);
}

technique Uncharted2Tonemap
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Uncharted_Tonemap_Main;
	}
}
