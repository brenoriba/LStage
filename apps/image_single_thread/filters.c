/*
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On May 2014
	   
	*********************************************************************************************

	Reference: http://www.troubleshooters.com/codecorn/lua/lua_lua_calls_c.htm
*/

#include <string.h>

// Open cv includes
#include "cv.h"
#include "highgui.h"

extern "C" {

#include "lua.h"
#include "lauxlib.h"

// Get metatable by name
int image_getmetatable(lua_State *L) {
   if(lua_type(L,1)==LUA_TSTRING) {
      const char *tname=lua_tostring(L,1);
      luaL_getmetatable(L,tname);
   } else {
      if(!lua_getmetatable (L,1)) {
         lua_pushnil(L);
         lua_pushliteral(L,"Metatable not found for the provided value");
         return 2;
      }
   }
   return 1;
}

// Grayscale filter
static int filters_grayscale (lua_State * L) {
	// Check pointer	
	if(lua_type(L,1)!=LUA_TLIGHTUSERDATA) {
   	lua_pushboolean(L,0);
		lua_pushliteral(L,"Arg is not a pointer");
		return 2;
	}

	// Pointer to the image
	void *ptr;
	ptr=lua_touserdata(L,1);
	
	int w,h,i,j,channels,step;
	w=lua_tointeger(L,2);
	h=lua_tointeger(L,3);

	// Get image
        cv::Mat * img=new cv::Mat(w,h,CV_8UC4,ptr);

	// Get image data	
	uchar *data;
	data = (uchar *)img->data;

	IplImage * dst_img= cvCreateImage(cvSize(w,h), IPL_DEPTH_8U, 4);
        dst_img->imageData = (char *) img->data;  

	step = dst_img->widthStep;
	channels = dst_img->nChannels;

	// Run into image pixels
	int red,green,blue,avg;
	for (i=0;i<h;i++) {
		for (j=0;j<w;j++) {	
			// GIMP - Grayscale Luminosity (with some changes on average formula)
			// http://docs.gimp.org/2.6/en/gimp-tool-desaturate.html
			red   = data[i*step+j*channels+2];
			green = data[i*step+j*channels+1];
			blue  = data[i*step+j*channels+0];
			avg   = (int)((red * 0.3) + (green * 0.59) + (blue * 0.11));

			data[i*step+j*channels+2]=avg; // Red
			data[i*step+j*channels+0]=avg; // Blue
		        data[i*step+j*channels+1]=avg; // Green		        
			data[i*step+j*channels+3]=255; // Alpha
		}
	}
	return 0;
}

// Threshold filter
static int filters_threshold(lua_State * L) {
	// Check pointer	
	if(lua_type(L,1)!=LUA_TLIGHTUSERDATA) {
   	lua_pushboolean(L,0);
		lua_pushliteral(L,"Arg is not a pointer");
		return 2;
	}

	void *ptr;
	ptr=lua_touserdata(L,1);
	
	int w,h,threshold,maxValue;
	w=lua_tointeger(L,2);
	h=lua_tointeger(L,3);
	threshold=lua_tointeger(L,4);
	maxValue=lua_tointeger(L,5);

	// Get image
        cv::Mat * img=new cv::Mat(w,h,CV_8UC4,ptr);

	IplImage * dst_img= cvCreateImage(cvSize(w,h), IPL_DEPTH_8U, 4);
        dst_img->imageData = (char *) img->data;      

	// Apply threshold	
	cvThreshold(dst_img,dst_img,threshold,maxValue,CV_THRESH_BINARY);
	return 0;
}

// Apply invert
static int filters_invert(lua_State * L) {
	// Check pointer	
	if(lua_type(L,1)!=LUA_TLIGHTUSERDATA) {
   	lua_pushboolean(L,0);
		lua_pushliteral(L,"Arg is not a pointer");
		return 2;
	}

	void *ptr;
	ptr=lua_touserdata(L,1);

	int i,j,k,step,w,h,channels;	
	w=lua_tointeger(L,2);
	h=lua_tointeger(L,3);

	// Get image
        cv::Mat * img=new cv::Mat(w,h,CV_8UC4,ptr);

	IplImage * dst_img= cvCreateImage(cvSize(w,h), IPL_DEPTH_8U, 4);
        dst_img->imageData = (char *) img->data;   

	step = dst_img->widthStep;
	channels = dst_img->nChannels;

	// Get image data
	uchar *data;
	data = (uchar *)img->data;

	for (i=0;i<h;i++) {
		for (j=0;j<w;j++) {		
	        	for (k=0;k<channels;k++) {
			    // Inverting image pixels
		            data[i*step+j*channels+k]=255-data[i*step+j*channels+k];
			}
		}
	}
	return 0;
}

// Apply blur
static int filters_blur(lua_State * L) {
	// Check pointer	
	if(lua_type(L,1)!=LUA_TLIGHTUSERDATA) {
   	lua_pushboolean(L,0);
		lua_pushliteral(L,"Arg is not a pointer");
		return 2;
	}

	void *ptr;
	ptr=lua_touserdata(L,1);
	
	int i,j,x,y,step,w,h,channels,blurSize;	
	w=lua_tointeger(L,2);
	h=lua_tointeger(L,3);
	blurSize=lua_tointeger(L,4);

	// Get image
        cv::Mat * img=new cv::Mat(w,h,CV_8UC4,ptr);

	// Get image data	
	uchar *data;
	data = (uchar *)img->data;

	IplImage * dst_img= cvCreateImage(cvSize(w,h), IPL_DEPTH_8U, 4);
        dst_img->imageData = (char *) img->data;  

	step = dst_img->widthStep;
	channels = dst_img->nChannels;

	// Run into image pixels
	int red,green,blue,avgR,avgG,avgB,blurPixelCount;
	for (j=0;j<w;j++) {
		for (i=0;i<h;i++) {
			avgR = 0;
			avgG = 0;
			avgB = 0;
			blurPixelCount = 0;

			// http://notes.ericwillis.com/2009/10/blur-an-image-with-csharp/
			for (x=j;x<(j+blurSize) && x < w;x++) {
				for(y=i;y<(i+blurSize) && y < h;y++) {
					red   = data[y*step+x*channels+2];
					green = data[y*step+x*channels+1];
					blue  = data[y*step+x*channels+0];

					avgR += red;
					avgG += green;
					avgB += blue;

					blurPixelCount++;
				}
			}
			
			avgR = avgR / blurPixelCount;
			avgG = avgG / blurPixelCount;
			avgB = avgB / blurPixelCount;
			
			// Apply blur
			for (x=j;x<(j+blurSize) && x < w;x++) {
				for(y=i;y<(i+blurSize) && y < h;y++) {
					data[y*step+x*channels+2] = avgR; // Red
					data[y*step+x*channels+0] = avgB; // Blue
					data[y*step+x*channels+1] = avgG; // Green		        
					data[y*step+x*channels+3] = 255;  // Alpha
				}
			}
		}
	}
	return 0;
}

// Functions to register
static const luaL_Reg RegisterFunctions[] =
{
    {"grayscale", filters_grayscale},
    {"threshold", filters_threshold},
    {"invert",filters_invert},
    {"blur",filters_blur},
    {"getmetatable", image_getmetatable},
    { NULL, NULL }
};

// Main method
int luaopen_filters (lua_State *L) {
    lua_newtable(L);

    #if LUA_VERSION_NUM < 502
        luaL_register(L, NULL, RegisterFunctions);
    #else
        luaL_setfuncs(L, RegisterFunctions, 0);
    #endif

    return 1;
}
}
