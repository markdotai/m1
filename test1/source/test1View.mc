using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;
using Toybox.StringUtil;

using Application.Properties as applicationProperties;
using Application.Storage as applicationStorage;

class test1View extends WatchUi.WatchFace
{
	//const forceTestFont = false;
	//const forceClearStorage = false;
	//const forceDemoProfiles = false;
	//const forceDemoFontStyles = false;

	const PROFILE_VERSION = 13;			// a version number
	const PROFILE_NUM_PRESET = 14;		// number of preset profiles (in the jsondata resource)

	var firstUpdateSinceInitialize = true;

	var settingsHaveChanged = false;
	
	//var updateLastSec;		// just needed for bug in CIQ
	//var updateLastMin;		// just needed for bug in CIQ

	var lastPartialUpdateSec;

	enum
	{
		//!ITEM_OFF = 0x00,
		ITEM_ON = 0x01,
		ITEM_ONGLANCE = 0x02,
		
		ITEM_RETRIEVE = 0x10
	}
	var onOrGlanceActive = ITEM_ON;
	
	var fontTimeHourResource = null;
	var fontTimeMinuteResource = null;
	var fontFieldResource = null;
	var fontFieldUnsupportedResource = null;
	//enum
	//{
	//	//!APPCASE_ANY = 0,
	//	//APPCASE_UPPER = 1,
	//	//APPCASE_LOWER = 2
	//}
	
	// prop or "property" variables - are the ones which we store in onUpdate, so they don't change when they are used in onPartialUpdate
	var propBackgroundColor;

    var propTimeOn;
    var propTimeHourFont;
    var propTimeMinuteFont;
	var propTimeHourColor;
	var propTimeMinuteColor;
	var propTimeItalic;
	var propTimeYOffset;
    
    var propSecondIndicatorOn = 0;
	var propSecondFontResource = null;
	//enum
	//{
	//	REFRESH_EVERY_SECOND = 0,
	//	REFRESH_EVERY_MINUTE = 1,
	//	REFRESH_ALTERNATE_MINUTES = 2
	//}
    var propSecondRefreshStyle;
	var propSecondMoveInABit;
	var propSecondIndicatorStyle;
    
    var propFieldFont;
    var propFieldFontUnsupported;

	var propOuterOn;
	var propOuterColorFilled;
	var propOuterColorUnfilled;
	
	var propDemoDisplayOn;
	
	const FIELD_NUM = 8;		// number of fields
	const FIELD_NUM_ELEMENTS = 6;
	const FIELD_NUM_ELEMENTS_DRAW = 10;		// 4 extra for 5 move bar icons + 5 other icons
	// We pack justifcation and field management (off/on/glance) into 1 char:
	// (and it has a single digit value for export string to fit into 255 chars)
	// a=0,1,2 & b=0,1,2, then (a + 3*b)=0 to 8
	const FIELD_MANAGEMENT_MODULO = 3;
	enum
	{
	//	FIELD_INDEX_YOFFSET = 0,
	//	FIELD_INDEX_XOFFSET = 1,
	//	FIELD_INDEX_JUSTIFICATION = 2,
	//	FIELD_INDEX_ELEMENTS = 3,
		FIELD_NUM_PROPERTIES = 21,
	}	
    // "FM" = field management
    // "FN" = field number
    // "F0" = field y offset
    // "F1" = field x offset
    // "F2" = field justification
    // "F3" = field element 1
    // "F4" = field visibility 1
    // "F5" = field color 1
    // "F6" = field element 2
    // "F7" = field visibility 2
    // "F8" = field color 2
    // "F9" = field element 3
    // "F10" = field visibility 3
    // "F11" = field color 3
    // "F12" = field element 4
    // "F13" = field visibility 4
    // "F14" = field color 4
    // "F15" = field element 5
    // "F16" = field visibility 5
    // "F17" = field color 5
    // "F18" = field element 6
    // "F19" = field visibility 6
    // "F20" = field color 6
    var propFieldData = new[FIELD_NUM*FIELD_NUM_PROPERTIES]b;		// don't initialize as it takes 1250 bytes of code ...
    
	var hasDoNotDisturb;
	var hasLTE;

	var fieldActivePhoneStatus = null;
	var fieldActiveNotificationsStatus = null;
	var fieldActiveNotificationsCount = null;
	var fieldActiveLTEStatus = null;

    const PROFILE_NUM_PROPERTIES = 36;
	
	const PROFILE_PRIVATE_INDEX = -1;			// only used for temporary storage while app is running

	// Time is stored as hour*60 + minutes
	// This has a maximum of 24*60 = 1,440 = 0x5A0 (11 bits 0x7FF)
	const PROFILE_NUM_USER = 24;				// number of user profiles
	var profileTimes = new[PROFILE_NUM_USER*2];
	// 1st number:
	const PROFILE_DAYS_MASK = 0x7F;				// 7 bits for days mon-sun
	const PROFILE_BLOCK_MASK = 0x80;			// block random
	//!const PROFILE_UNUSED1_MASK = 0x100;
	//!const PROFILE_UNUSED2_MASK = 0x200;
	const PROFILE_START_MASK = 0x7FF;
	const PROFILE_START_SHIFT = 10;
	const PROFILE_END_MASK = 0x7FF;
	const PROFILE_END_SHIFT = 21;
	// 2nd number:
	const PROFILE_EVENTS_MASK = 0xFF;			// number of random events per day 0-255
	
	var profileActive = PROFILE_PRIVATE_INDEX;	// currently active profile
	var profileDelayEnd = 0;		// after manually changing settings then any automatic profile loads get delayed until this moment
	var profileGlance = -1;		// -1 means no glance profile active
	var profileGlanceReturn = PROFILE_PRIVATE_INDEX;
	var profileRandom = -1;		// -1 means no random profile active
	var profileRandomEnd = 0;
	var profileRandomLastMin = -1;		// last minute number that we did the random checks

	var demoProfilesOn = false;
	var demoProfilesOnPrev = false;	
	var demoProfilesCurrentProfile = -1;
	var demoProfilesCurrentEnd = 0;

	var iconsFontResource;
	//!const iconsString = "ABCDEFGHIJKLMNOPQRSTUVWX";
	//const ICONS_FIRST_CHAR_ID = 65;
	// A = 65 = circle
	// B = 66 = circle solid
	// C = 67 = rounded
	// D = 68 = rounded solid
	// E = 69 = square
	// F = 70 = square solid
	// G = 71 = triangle
	// H = 72 = triangle solid
	// I = 73 = diamond
	// J = 74 = diamond solid
	// K = 75 = star
	// L = 76 = star solid
	//
	// M = 77 = alarm
	// N = 78 = lock
	// O = 79 = phone
	// P = 80 = notification
	// Q = 81 = figure
	// R = 82 = battery
	// S = 83 = battery solid
	// T = 84 = bed
	// U = 85 = flower
	// V = 86 = footsteps
	// W = 87 = network
	// X = 88 = stairs
	//
	// Y = 89 = move bar
	// Z = 90 = move bar solid

	//enum
	//{
		// if any of these numbers below change, then also need to modify:
		//     	- FIELD_SHAPE_CIRCLE, as they are in the same order
		//     	- the icons font resource (ICONS_FIRST_CHAR_ID)
		//		- the demo display drawing mode 
		//!FIELD_ICON_EMPTY = 0,
		//!FIELD_ICON_SPACE = 1,

		//!FIELD_ICON_CIRCLE = 2,				
		//!FIELD_ICON_CIRCLE_SOLID = 3,
		//!FIELD_ICON_ROUNDED = 4,
		//!FIELD_ICON_ROUNDED_SOLID = 5,
		//!FIELD_ICON_SQUARE = 6,
		//!FIELD_ICON_SQUARE_SOLID = 7,
		//!FIELD_ICON_TRIANGLE = 8,
		//!FIELD_ICON_TRIANGLE_SOLID = 9,
		//!FIELD_ICON_DIAMOND = 10,
		//!FIELD_ICON_DIAMOND_SOLID = 11,
		//!FIELD_ICON_STAR = 12,
		//!FIELD_ICON_STAR_SOLID = 13,
		//!FIELD_ICON_ALARM = 14,
		//!FIELD_ICON_LOCK = 15,
		//!FIELD_ICON_PHONE = 16,
		//!FIELD_ICON_NOTIFICATION = 17,
		//!FIELD_ICON_FIGURE = 18,
		//!FIELD_ICON_BATTERY = 19,
		//!FIELD_ICON_BATTERY_SOLID = 20,
		//!FIELD_ICON_BED = 21,
		//!FIELD_ICON_FLOWER = 22,
		//!FIELD_ICON_FOOTSTEPS = 23,
		//!FIELD_ICON_NETWORK = 24,
		//!FIELD_ICON_STAIRS = 25,

		//!FIELD_ICON_UNUSED = -1,		
	//}
	
	//enum
	//{
	//	STATUS_ALWAYSON = 0,
	//	STATUS_DONOTDISTURB_ON = 1,
	//	STATUS_DONOTDISTURB_OFF = 2,
	//	STATUS_ALARM_ON = 3,
	//	STATUS_ALARM_OFF = 4,
	//	STATUS_NOTIFICATIONS_PENDING = 5,
	//	STATUS_NOTIFICATIONS_NONE = 6,
	//	STATUS_PHONE_CONNECTED = 7,
	//	STATUS_PHONE_NOT = 8,
	//	STATUS_LTE_CONNECTED = 9,
	//	STATUS_LTE_NOT = 10,
	//	STATUS_BATTERY_HIGHORMEDIUM = 11,
	//	STATUS_BATTERY_HIGH = 12,
	//	STATUS_BATTERY_MEDIUM = 13,
	//	STATUS_BATTERY_LOW = 14,
	//	STATUS_MOVEBARALERT_TRIGGERED = 15,
	//	STATUS_MOVEBARALERT_NOT = 16,
	//
	//	STATUS_NUM = 17
	//}
	
	//enum
	//{
    //	FIELD_EMPTY = 0,
	//
    //	FIELD_HOUR = 1,
    //	FIELD_MINUTE = 2,
    //	FIELD_DAY_NAME = 3,
	//	FIELD_DAY_OF_WEEK = 4,
	//	FIELD_DAY_OF_MONTH = 5,
	//	FIELD_DAY_OF_MONTH_XX = 6,
	//	FIELD_DAY_OF_YEAR = 7,
	//	FIELD_DAY_OF_YEAR_XXX = 8,
	//	FIELD_MONTH_NAME = 9,
	//	FIELD_MONTH_OF_YEAR = 10,
	//	FIELD_MONTH_OF_YEAR_XX = 11,
	//	FIELD_YEAR_XX = 12,
	//	FIELD_YEAR_XXXX = 13,
	//	FIELD_WEEK_ISO_XX = 14,
	//	FIELD_WEEK_ISO_WXX = 15,
	//	FIELD_YEAR_ISO_WEEK_XXXX = 16,
	//	FIELD_WEEK_CALENDAR_XX = 17,
	//	FIELD_YEAR_CALENDAR_WEEK_XXXX = 18,
	//
	//	FIELD_SEPARATOR_SPACE = 21,
	//	//!FIELD_SEPARATOR_SLASH_FORWARD = 22,
	//	//!FIELD_SEPARATOR_SLASH_BACK = 23,
	//	//!FIELD_SEPARATOR_COLON = 24,
	//	//!FIELD_SEPARATOR_MINUS = 25,
	//	//!FIELD_SEPARATOR_DOT = 26,
	//	//!FIELD_SEPARATOR_COMMA = 27,
	//	FIELD_SEPARATOR_PERCENT = 28,
	//
	//	FIELD_STEPSCOUNT = 31,
	//	FIELD_STEPSGOAL = 32,
	//	FIELD_FLOORSCOUNT = 33,
	//	FIELD_FLOORSGOAL = 34,
	//	FIELD_NOTIFICATIONSCOUNT = 35,
	//	FIELD_BATTERYPERCENTAGE = 36,
	//	FIELD_MOVEBAR = 37,
	//
	//	FIELD_SHAPE_CIRCLE = 41,
	//	//!FIELD_SHAPE_CIRCLE_SOLID = 42,
	//	//!FIELD_SHAPE_ROUNDED = 43,
	//	//!FIELD_SHAPE_ROUNDED_SOLID = 44,
	//	//!FIELD_SHAPE_SQUARE = 45,
	//	//!FIELD_SHAPE_SQUARE_SOLID = 46,
	//	//!FIELD_SHAPE_TRIANGLE = 47,
	//	//!FIELD_SHAPE_TRIANGLE_SOLID = 48,
	//	//!FIELD_SHAPE_DIAMOND = 49,
	//	//!FIELD_SHAPE_DIAMOND_SOLID = 50,
	//	//!FIELD_SHAPE_STAR = 51,
	//	//!FIELD_SHAPE_STAR_SOLID = 52,
	//	//!FIELD_SHAPE_ALARM = 53,
	//	//!FIELD_SHAPE_LOCK = 54,
	//	//!FIELD_SHAPE_PHONE = 55,
	//	//!FIELD_SHAPE_NOTIFICATION = 56,
	//	//!FIELD_SHAPE_FIGURE = 57,
	//	//!FIELD_SHAPE_BATTERY = 58,
	//	//!FIELD_SHAPE_BATTERY_SOLID = 59,
	//	//!FIELD_SHAPE_BED = 60,
	//	//!FIELD_SHAPE_FLOWER = 61,
	//	//!FIELD_SHAPE_FOOTSTEPS = 62,
	//	//!FIELD_SHAPE_NETWORK = 63,
	//	FIELD_SHAPE_STAIRS = 64,
	//
	//	//!FIELD_UNUSED
	//}
	
	const COLOR_NOTSET = -1;	// just used in the code to indicate no color set
	
	function getColorArray(i)
	{
		if (i<0)
		{
			return COLOR_NOTSET; 
		}
		else if (i>=64)
		{
			return i;
		}
	
		// 0x00 = 000, 0x01 = 005, 0x02 = 00A, 0x03 = 00F
		// 0x04 = 050, 0x05 = 055, 0x06 = 05A, 0x07 = 05F
		// 0x08 = 0A0, 0x09 = 0A5, 0x0A = 0AA, 0x0B = 0AF
		// 0x0C = 0F0, 0x0D = 0F5, 0x0E = 0FA, 0x0F = 0FF
		//
		// 0x10 = 500, 0x20 = A00, 0x30 = F00
		var colorArray = [
			// grayscale......
			//      0            1            2           3
			// 000000       555555       AAAAAA      FFFFFF
			(0x00<<24) | (0x15<<16) | (0x2A<<8) | (0x3F),
	
			// bright......
			//      4            5            6           7
			// FFFF00       AAFF00       55FF00      00FF00
			(0x3C<<24) | (0x2C<<16) | (0x1C<<8) | (0x0C),
			//      8            9           10          11
			// 00FF55       00FFAA       00FFFF      00AAFF
			(0x0D<<24) | (0x0E<<16) | (0x0F<<8) | (0x0B),
			//     12           13           14          15
			// 0055FF       0000FF       5500FF      AA00FF
			(0x07<<24) | (0x03<<16) | (0x13<<8) | (0x23),
			//     16           17           18          19
			// FF00FF       FF00AA       FF0055      FF0000
			(0x33<<24) | (0x32<<16) | (0x31<<8) | (0x30),
							          // dim.......
			//     20           21           22          23
			// FF5500       FFAA00       AAAA55      55AA55
			(0x34<<24) | (0x38<<16) | (0x29<<8) | (0x19),
			//     24           25           26          27
			// 55AAAA       5555AA       AA55AA      AA5555
			(0x1A<<24) | (0x16<<16) | (0x26<<8) | (0x25),
			// pale......
			//     28           29           30          31
			// FFFF55       AAFF55       55FF55      55FFAA
			(0x3D<<24) | (0x2D<<16) | (0x1D<<8) | (0x1E),
			//     32           33           34          35
			// 55FFFF       55AAFF       5555FF      AA55FF
			(0x1F<<24) | (0x1B<<16) | (0x17<<8) | (0x27),
			//     36           37           38          39
			// FF55FF       FF55AA       FF5555      FFAA55
			(0x37<<24) | (0x36<<16) | (0x35<<8) | (0x39),
			// palest......
			//     40           41           42          43
			// FFFFAA       AAFFAA       AAFFFF      AAAAFF
			(0x3E<<24) | (0x2E<<16) | (0x2F<<8) | (0x2B),
									  // dark......
			//     44           45           46          47
			// FFAAFF       FFAAAA       AAAA00      55AA00
			(0x3B<<24) | (0x3A<<16) | (0x28<<8) | (0x18),
			//     48           49           50          51
			// 00AA00       00AA55       00AAAA      0055AA
			(0x08<<24) | (0x09<<16) | (0x0A<<8) | (0x06),
			//     52           53           54          55
			// 0000AA       5500AA       AA00AA      AA0055
			(0x02<<24) | (0x12<<16) | (0x22<<8) | (0x21),
									  // darkest......
			//     56           57           58          59
			// AA0000       AA5500       555500      005500
			(0x20<<24) | (0x24<<16) | (0x14<<8) | (0x04),
			//     60           61           62          63
			// 005555       000055       550055      550000
			(0x05<<24) | (0x01<<16) | (0x11<<8) | (0x10),
		];
			
		var byte = 3 - (i%4);
		var shortCol = (colorArray[i/4] >> (byte*8));
		var c0 = (shortCol & 0x003) * 5;			// 0x0, 0x5, 0xA, 0xF	
		var c1 = ((shortCol<<2) & 0x030) * 5;		// 0x00, 0x50, 0xA0, 0xF0
		var c2 = ((shortCol<<4) & 0x300) * 5;		// 0x000, 0x500, 0xA00, 0xF00
		var col = (c0 | ((c0|c1) << 4) | ((c1|c2) << 8) | (c2 << 12)); 
		return col;
	}

	//function colorHexToIndex(col) not tested but may work ...
	//{	
	//	var r = ((col>>20) & 0x0F) / 5;	// 0-3
	//	var g = ((col>>12) & 0x0F) / 5;	// 0-3
	//	var b = ((col>>4) & 0x0F) / 5;	// 0-3
	//	
	//	var shortTest = (r<<4) | (g<<2) | b;
	//	
	//	var index = 0;
	//
	//	for (var i=0; i<64; i++)
	//	{
	//		var byte = 3 - (i%4);
	//		var shortCol = (colorArray[i/4] >> (byte*8));
	//		if (shortCol == shortTest)
	//		{
	//			index = i;
	//			break;
	//		}
	//	}
	//	
	//	return index;
	//}

	//const SECONDS_FIRST_CHAR_ID = 21;
	//const SECONDS_SIZE_HALF = 8;
	//!const SECONDS_CENTRE_OFFSET = SCREEN_CENTRE_X - SECONDS_SIZE_HALF;

	//enum
	//{
	//	SECONDFONT_TRI = 0,
	//	//!SECONDFONT_V = 1,
	//	//!SECONDFONT_LINE = 2,
	//	//!SECONDFONT_LINETHIN = 3,
	//	//!SECONDFONT_CIRCULAR = 4,
	//	//!SECONDFONT_CIRCULARTHIN = 5,
	//	SECONDFONT_TRI_IN = 6,
	//	//!SECONDFONT_V_IN = 7,
	//	//!SECONDFONT_LINE_IN = 8,
	//	//!SECONDFONT_LINETHIN_IN = 9,
	//	//!SECONDFONT_CIRCULAR_IN = 10,
	//	//!SECONDFONT_CIRCULARTHIN_IN = 11,
	//	SECONDFONT_UNUSED = 12
	//}

	//var secondsX = [120, 132, 143, 155, 166, 176, 186, 195, 203, 211, 217, 222, 227, 230, 231, 232, 231, 230, 227, 222, 217, 211, 203, 195, 186, 176, 166, 155, 143, 132, 120, 108, 97, 85, 74, 64, 54, 45, 37, 29, 23, 18, 13, 10, 9, 8, 9, 10, 13, 18, 23, 29, 37, 45, 54, 64, 74, 85, 97, 108, 120, 131, 142, 153, 164, 174, 183, 192, 200, 207, 214, 219, 223, 226, 227, 228, 227, 226, 223, 219, 214, 207, 200, 192, 183, 174, 164, 153, 142, 131, 120, 109, 98, 87, 76, 66, 57, 48, 40, 33, 26, 21, 17, 14, 13, 12, 13, 14, 17, 21, 26, 33, 40, 48, 57, 66, 76, 87, 98, 109]b;
	//var secondsY = [7, 8, 9, 12, 17, 22, 28, 36, 44, 53, 63, 73, 84, 96, 107, 119, 131, 142, 154, 165, 175, 185, 194, 202, 210, 216, 221, 226, 229, 230, 231, 230, 229, 226, 221, 216, 210, 202, 194, 185, 175, 165, 154, 142, 131, 119, 107, 96, 84, 73, 63, 53, 44, 36, 28, 22, 17, 12, 9, 8, 11, 12, 13, 16, 20, 25, 32, 39, 47, 56, 65, 75, 86, 97, 108, 119, 130, 141, 152, 163, 173, 182, 191, 199, 206, 213, 218, 222, 225, 226, 227, 226, 225, 222, 218, 213, 206, 199, 191, 182, 173, 163, 152, 141, 130, 119, 108, 97, 86, 75, 65, 56, 47, 39, 32, 25, 20, 16, 13, 12]b;
	var secondsX = new[60*2]b;
	var secondsY = new[60*2]b;
	//!const secondsString = "\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f" +					// 11
	//	"\u0020\u0021\u0022\u0023\u0024\u0025\u0026\u0027\u0028\u0029\u002a\u002b\u002c\u002d\u002e\u002f" +		// 27
	//	"\u0030\u0031\u0032\u0033\u0034\u0035\u0036\u0037\u0038\u0039\u003a\u003b\u003c\u003d\u003e\u003f" +		// 43
	//	"\u0040\u0041\u0042\u0043\u0044\u0045\u0046\u0047\u0048\u0049\u004a\u004b\u004c\u004d\u004e\u004f" +		// 59
	//	"\u0050";																									// 60
	
	var secondsCol = new[60];
	
	//const BUFFER_SIZE = 62;
	var bufferBitmap = null;
	var bufferIndex = -1;	// ensures buffer will get updated first time
	var bufferX;
	var bufferY;
	
	var outerFontResource;
	//const OUTER_FIRST_CHAR_ID = 12;
	//const OUTER_SIZE_HALF = 5;
	//!const OUTER_CENTRE_OFFSET = 117;
	var outerBigFontResource;

	//var outerX = [123, 129, 135, 141, 147, 153, 159, 165, 170, 176, 181, 186, 191, 196, 201, 205, 209, 213, 216, 220, 223, 226, 228, 230, 232, 234, 235, 236, 237, 237, 237, 237, 236, 235, 234, 232, 230, 228, 226, 223, 220, 216, 213, 209, 205, 201, 196, 191, 186, 181, 176, 170, 165, 159, 153, 147, 141, 135, 129, 123, 117, 111, 105, 99, 93, 87, 81, 75, 70, 64, 59, 54, 49, 44, 39, 35, 31, 27, 24, 20, 17, 14, 12, 10, 8, 6, 5, 4, 3, 3, 3, 3, 4, 5, 6, 8, 10, 12, 14, 17, 20, 24, 27, 31, 35, 39, 44, 49, 54, 59, 64, 70, 75, 81, 87, 93, 99, 105, 111, 117]b;
	//var outerY = [2, 2, 3, 4, 5, 7, 9, 11, 13, 16, 19, 23, 26, 30, 34, 38, 43, 48, 53, 58, 63, 69, 74, 80, 86, 92, 98, 104, 110, 116, 122, 128, 134, 140, 146, 152, 158, 164, 169, 175, 180, 185, 190, 195, 200, 204, 208, 212, 215, 219, 222, 225, 227, 229, 231, 233, 234, 235, 236, 236, 236, 236, 235, 234, 233, 231, 229, 227, 225, 222, 219, 215, 212, 208, 204, 200, 195, 190, 185, 180, 175, 169, 164, 158, 152, 146, 140, 134, 128, 122, 116, 110, 104, 98, 92, 86, 80, 74, 69, 63, 58, 53, 48, 43, 38, 34, 30, 26, 23, 19, 16, 13, 11, 9, 7, 5, 4, 3, 2, 2]b;
	var outerX = new[120]b;
	var outerY = new[120]b;
	
	//var characterString;

	//var circleFont;
	//var ringFont;

	//var worldBitmap;

    var backgroundTimeCharArray = new[4];        
    var backgroundTimeCharArrayLength;
	var backgroundTimeCharArrayMinuteStart;
    var backgroundTimeWidthArray = new[4];	        	        
	var backgroundTimeTotalWidth;
	var backgroundTimeXOffset;

	const FIELD_INFO_CHAR_MAX_LEN = 20;		// 20 characters seems plenty - widest element might be step count, but normally day or month name = 3*6
	var backgroundFieldInfoIndex = new[FIELD_NUM]b;		// index into backgroundFieldInfo arrays
	var backgroundFieldInfoCharArray = new[FIELD_NUM*FIELD_INFO_CHAR_MAX_LEN];
	var backgroundFieldInfoCharArrayLength = new[FIELD_NUM]b;
	var backgroundFieldInfoData = new[FIELD_NUM*FIELD_NUM_ELEMENTS_DRAW];	// pixel width, string start, string end, is icon, use unsupported font
	var backgroundFieldInfoColor = new[FIELD_NUM*FIELD_NUM_ELEMENTS_DRAW];
	var backgroundFieldTotalWidth = new[FIELD_NUM];

	var backgroundOuterFillStart;	// first segment of outer ring to draw as filled (-1 to 119)
	var backgroundOuterFillEnd;		// last segment of outer ring to draw as filled (-1 to 119)

	//enum
	//{
	//	//!APPFONT_ULTRA_LIGHT = 0,
	//	//!APPFONT_EXTRA_LIGHT = 1,
	//	//!APPFONT_LIGHT = 2,
	//	APPFONT_REGULAR = 3,
	//	//!APPFONT_BOLD = 4,
	//	APPFONT_HEAVY = 5,			// our custom number fonts are assumed to be at the top of this enum
	//	
	//	APPFONT_ULTRA_LIGHT_TINY = 6,
	//	//!APPFONT_EXTRA_LIGHT_TINY = 7,
	//	//!APPFONT_LIGHT_TINY = 8,
	//	//!APPFONT_REGULAR_TINY = 9,
	//	//!APPFONT_BOLD_TINY = 10,
	//	//!APPFONT_HEAVY_TINY = 11,
	//	
	//	//!APPFONT_ULTRA_LIGHT_SMALL = 12,
	//	//!APPFONT_EXTRA_LIGHT_SMALL = 13,
	//	//!APPFONT_LIGHT_SMALL = 14,
	//	APPFONT_REGULAR_SMALL = 15,
	//	//!APPFONT_BOLD_SMALL = 16,
	//	//!APPFONT_HEAVY_SMALL = 17,
	//	
	//	//!APPFONT_ULTRA_LIGHT_MEDIUM = 18,
	//	//!APPFONT_EXTRA_LIGHT_MEDIUM = 19,
	//	//!APPFONT_LIGHT_MEDIUM = 20,
	//	//!APPFONT_REGULAR_MEDIUM = 21,
	//	//!APPFONT_BOLD_MEDIUM = 22,
	//	//!APPFONT_HEAVY_MEDIUM = 23,
	//
	//	APPFONT_SYSTEM_XTINY = 24,
	//	APPFONT_SYSTEM_TINY = 25,
	//	//!APPFONT_SYSTEM_SMALL = 26,
	//	//!APPFONT_SYSTEM_MEDIUM = 27,
	//	APPFONT_SYSTEM_LARGE = 28,
	//
	//	//!APPFONT_SYSTEM_NUMBER_NORMAL = 29,	// FONT_SYSTEM_NUMBER_MILD 
	//	//!APPFONT_SYSTEM_NUMBER_MEDIUM = 30,	// FONT_SYSTEM_NUMBER_MEDIUM 
	//	//!APPFONT_SYSTEM_NUMBER_LARGE = 31,		// FONT_SYSTEM_NUMBER_HOT 
	//	//!APPFONT_SYSTEM_NUMBER_HUGE = 32,		// FONT_SYSTEM_NUMBER_THAI_HOT 
	//
	//	APPFONT_NUMBER_OF_FONTS = 33
	//}

	// custom time font ascii characters:
	// 48-57 = 0-9
	// 58 = :
	//enum
	//{
	//	APPCHAR_0 = 48,		// digit 0
	//	APPCHAR_1 = 49,		// digit 1
	//	//!APPCHAR_2 = 50,		// digit 2
	//	//!APPCHAR_3 = 51,		// digit 3
	//	//!APPCHAR_4 = 52,		// digit 4
	//	//!APPCHAR_5 = 53,		// digit 5
	//	//!APPCHAR_6 = 54,		// digit 6
	//	//!APPCHAR_7 = 55,		// digit 7
	//	//!APPCHAR_8 = 56,		// digit 8
	//	APPCHAR_9 = 57,		// digit 9
	//
	//	APPCHAR_SPACE = 32,
	//	APPCHAR_COMMA = 44,
	//	APPCHAR_MINUS = 45,
	//	//!APPCHAR_DOT = 46,
	//	//!APPCHAR_COLON = 58,
	//	//!APPCHAR_f = 102,
	//	APPCHAR_t = 116,
	//	//!APPCHAR_F = 70,
	//	APPCHAR_T = 84,
	//	APPCHAR_OPEN_SQUARE_BRACKET = 91,
	//	APPCHAR_CLOSE_SQUARE_BRACKET = 93,
	//}
	
	function getKern(cur, next, appFontCur, appFontNext)
	{
		var val = 0;
		
		var kernTable = [
					/*76543210    3210  98      987654 */
		/* 0 & 1 */	0x10F01010, 0x01010000, 0x00218104,
		/* 2 & 3 */	0x10F20000, 0x10100000, 0x000010F0,
		/* 4 & 5 */	0x30001020, 0x10100010, 0x001010F0,
		/* 6 & 7 */	0x10F01010, 0x12400010, 0x000010F6,
		/* 8 & 9 */	0x10F01010, 0x10100000, 0x000010F0,
		];
	
		var bits = cur*48 + next*4;
		var byte4 = bits/32;
	
		// make sure index inside array
		if (byte4>=0 && byte4<15)
		{
			bits = bits%32;
			
			val = (kernTable[byte4] >> bits) & 0xF;
			if (val > 0x8)
			{
				val -= 0x10;
			}
		}
		
		// special case code for different weights
		if (cur==1)
		{
			if (next==4)	// 1-4
			{
				if (appFontCur==4/*APPFONT_BOLD*/)
				{
					val -= 1;
				}
				else if (appFontCur==5/*APPFONT_HEAVY*/)
				{
					val -= 2;
				}
			}
		}
		else if (cur==2)
		{
			if (next==4)	// 2-4
			{
				if (appFontCur==5/*APPFONT_HEAVY*/)
				{
					val -= 1;
				}
			}
		}
		
		return val;
	}	
	
//	function getKern2(cur, next, appFontCur, appFontNext)
//	{
//		var kernTable = [
//				/* 3 2 1 0     7 6 5 4         9 8 */
//		/* 0 */	0x00000000, 0x0000FF00, 0x00000000,
//		/* 1 */	0x00000000, 0x05000004, 0x00000100,
//		/* 2 */	0x00000000, 0x0000FF02, 0x00000000,
//		/* 3 */	0x00000000, 0x0000FF00, 0x00000000,
//		/* 4 */	0x01000100, 0x02000000, 0x00000100,
//		/* 5 */	0x00000000, 0x0000FF00, 0x00000100,
//		/* 6 */	0x00000000, 0x0000FF00, 0x00000000,
//		/* 7 */	0x000103FF, 0x0000FF05, 0x00000000,
//		/* 8 */	0x00000000, 0x0000FF00, 0x00000000,
//		/* 9 */	0x00000000, 0x0000FF00, 0x00000000,
//		];
//	
//		var val = 0;
//		
//		cur -= 48/*APPCHAR_0*/;
//		next -= 48/*APPCHAR_0*/;
//	
//		var index = cur*3 + next/4;
//		
//		// make sure index inside array, and both fonts are our custom ones
//		if (index>=0 && index<30 && appFontCur<=5/*APPFONT_HEAVY*/ && appFontNext<=5/*APPFONT_HEAVY*/)
//		{
//			val = kernTable[index];
//			
//			var byte = (next%4);
//			val = (val >> (byte*8)) & 0xFF;
//			
//			if (val > 0x80)
//			{
//				val -= 0x100;
//			}
//		}
//				
////if ((cur==0 || cur==2 || cur==3 || cur==5 || cur==6  || cur==7 || cur==8 || cur==9) && next==5)
////{
////	val -= 1;
////}
////else if (cur==1 && next==4)
////{
////	val += 1;
////}
////else if (cur==1 && next==7)
////{
////	val += 2;
////}
////else if (cur==7 && next==4)
////{
////	val += 2;
////}
////else if (cur==7 && next==0)
////{
////	val -= 1;
////}
//
//		return val;
//	}
	
//	function getKern(cur, next, appFontCur, appFontNext)
//	{
//		// ultra light & extra light = 0x00, 0x01, 0x02, 0x03 (= 0, 1, 2, 3)
//		// light & regular = 0x00, 0x04, 0x08, 0x0C (= 0, 1, 2, 3)
//		// bold & heavy = 0x00, 0x10, 0x20, 0x30 (= 0, 1, 2, 3)
//		// unused = 0x40, 0x80
//		var kernTable = [
//				/* 3 2 1 0     7 6 5 4         9 8 */
//		/* 0 */	0x16001B00, 0x1A000000, 0x00000000,
//		/* 1 */	0x0000001B, 0x001B0000, 0x00002A1B,
//		/* 2 */	0x00000000, 0x1A000000, 0x00000000,
//		/* 3 */	0x16001B00, 0x1A000000, 0x00000000,
//		/* 4 */	0x00000000, 0x00000000, 0x00000000,
//		/* 5 */	0x1A001B00, 0x2A00152A, 0x00002F00,
//		/* 6 */	0x1A001B00, 0x2A00152A, 0x00002F00,
//		/* 7 */	0x1B1B1B15, 0x1B150000, 0x00001515,
//		/* 8 */	0x16001B00, 0x1A000000, 0x00000000,
//		/* 9 */	0x16001B00, 0x1A000000, 0x00000000,
//		];
//	
//		var val = 0;
//		
//		cur -= 48/*APPCHAR_0*/;
//		next -= 48/*APPCHAR_0*/;
//		
//		var index = cur*3 + next/4;
//		
//		// make sure index inside array, and both fonts are our custom ones
//		if (index>=0 && index<30 && appFontCur<=5/*APPFONT_HEAVY*/ && appFontNext<=5/*APPFONT_HEAVY*/)
//		{
//			val = kernTable[index];
//			
//			var byte = (next%4);
//			val = (val >> (byte*8));
//	
//			// for digit "1" the test is for it's own font, not font of next character
//			// (it shouldn't be for "1" then "9" - but it's ok since that is set to same change on every font weight)
//			var kernFont = ((cur==1) ? appFontCur : appFontNext);
//	
//			val >>= 2*(kernFont/2);	// same as below but less code
//			//if (kernFont>=APPFONT_BOLD)			// bold (4) & heavy (5)
//			//{
//			//	val = (val>>4);
//			//}
//			//else if (kernFont>=APPFONT_LIGHT)		// light (2) & regular (3)
//			//{
//			//	val = (val>>2);
//			//}
//			//else									// ultra light (0) & extra light (1)
//			//{
//			//}
//	
//			val = (val&0x03);
//
//			// we also do some programmed custom kerning for "1" followed by "4" or "7"
//			// x advance for normal 1, then ultra light, extra light, light, regular, bold, heavy
//    		if (cur==1)
//    		{
//    			if (next==4 || next==7)			// digit 1 followed by 4 or 7
//	    		{
//        			val += (39-25) - appFontCur;		// 39 -> 25 26 27 28 29 30
//
//	    			//val += (39-24) - appFontCur - (APPFONT_HEAVY-appFontNext)/3;		// 39 -> 25 26 27 27 28 29
//        			//val += (39-24) - appFontCur;		// 39 -> 24 25 26 27 28 29
//        			//val += (39-25) - appFontCur;		// 39 -> 25 26 27 28 29 30
//        			//val += (39-27) - (appFontCur/2);	// 39 -> 27 27 28 28 29 29
//	    		}
//    			//else if (next==7)		// digit 1 followed by 7
//	    		//{
//	    		//	val += (39-25) - appFontCur;		// 39 -> 25 26 27 28 29 30
//	    		//	//val += (39-24) - appFontCur;		// 39 -> 24 25 26 27 28 29
//	    		//}
//	    	}
//			else if (cur==7)	// and special kerning for new slanted 7 too
//			{
//				if (next==1)
//				{
//					val += 5;
//				}
//				else if (next==2)
//				{
//					val += 1;
//				}
//			}
//		}
//				
//		return val;
//	}
	
	function useUnsupportedFieldFont(s)
	{
//		var bits = [
//		//	0-31		32-63		64-95		96-127		128-159		160-191		192-223		224-255		256-287		288-319		320-351		352-383
//			0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 
//		];
//
//		// all the chars in the custom field .fnt files
//		var chars = [
//			32,37,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,92,
//			193,196,197,199,201,204,205,211,214,216,218,219,220,221,260,268,282,317,321,323,336,344,346,352,377,381			 
//		];
//		
//		for (var i=0; i<chars.size(); i++)
//		{
//			var c = chars[i];
//			
//			var byte = c / 32;
//			var bit = c % 32;
//			
//			bits[byte] |= (0x1<<bit);  
//		}
//		
//		System.println("bits = " + bits.toString());
        
		if (propFieldFont < 24/*APPFONT_SYSTEM_XTINY*/)		// custom fonts
		{
	        var bits = [0, 134213665, 402653182, 0, 0, 0, 1028141746, 0, 67112976, 536870912, 83951626, 570425345];
	        var bitsSize = bits.size();
	        
	        var sArray = s.toCharArray();
	        var sArraySize = sArray.size();
	        for (var i=0; i<sArraySize; i++)
	        {
	        	var c = sArray[i].toNumber();	// unicode number
				var byte = c / 32;
				var bit = c % 32;
		       	//System.println("c=" + c + " byte=" + byte + " bit=" + bit);
				if (byte<0 || byte>=bitsSize || (bits[byte]&(0x1<<bit))==0)
				{
					return true;
				}
			}
		}
				
		return false;
	}
	
	function lteConnected()
	{
		return (hasLTE && (System.getDeviceSettings().connectionInfo[:lte].state==System.CONNECTION_STATE_CONNECTED));
    }
        	
	function propertiesGetBoolean(p)
	{
		// this test code for null works fine
		//var test1=null;
		//var test1=5;
		//var test1=1.754;
		//var test1="a";
		//var test2=(test1?1:2);
		//System.println("test2=" + test2);

		//return (applicationProperties.getValue(p) ? true : false);	got some crashes on real watch on this line? Error: Unexpected Type Error
		
		var v = applicationProperties.getValue(p);
		if ((v == null) || !(v instanceof Boolean))
		{
			v = false;
		}
		return v;
	}
	
	function propertiesGetNumber(p)
	{
		var v = applicationProperties.getValue(p);
		if ((v == null) || (v instanceof Boolean))
		{
			v = 0;
		}
		else if (!(v instanceof Number))
		{
			v = v.toNumber();
			if (v == null)
			{
				v = 0;
			}
		}
		return v;
	}
	
	function propertiesGetCharArray(p)
	{	
		var v = applicationProperties.getValue(p);
		if (v == null)
		{
			v = "";
		}
		else if (!(v instanceof String))
		{
			v = v.toString();
		}
		return v.toCharArray();
	}
	
	// Parse 2 numbers (number seperator number) from a string
	function propertiesGetTwoNumbers(p)
	{
		var n = new[2];
		
		var charArray = propertiesGetCharArray(p);
		var charArraySize = charArray.size();
		parseIndex = 0;
		
		n[0] = parseNumber(charArray, charArraySize);

       	// find next non-numeric character
    	for (; parseIndex<charArraySize; parseIndex++)
    	{
    		var c = charArray[parseIndex].toNumber();
       		if (c<48/*APPCHAR_0*/ || c>57/*APPCHAR_9*/)
    		{
    			break;
    		}
    	}
		
		parseIndex++;		// step over the separator
		
    	// then find next numeric character
    	for (; parseIndex<charArraySize; parseIndex++)
    	{
    		var c = charArray[parseIndex].toNumber();
       		if (c>=48/*APPCHAR_0*/ && c<=57/*APPCHAR_9*/)
    		{
    			break;
    		}
    	}

		n[1] = parseNumber(charArray, charArraySize);
		
		//System.println("parseTwoNumbers=" + n[0] + " and " + n[1]);

		return n;
	}
	
	// Parse a time (hours & minutes) from a string
	function propertiesGetTime(p)
	{
		var n = propertiesGetTwoNumbers(p);

		var t = n[0]*60 + n[1];  	// convert hours to minutes
	
		if (t<0 || t>=(24*60))		// check in correct range
		{
			t = 0;
		}
		
		return t;
	}
	
	function propertiesGetColor(p)
	{
		var v = propertiesGetNumber(p);
		return getColorArray(v);
	}
	
	function addStringToCharArray(s, toArray, toLen, toMax)
	{
		var charArray = s.toCharArray();
		var charArraySize = charArray.size();
		
		if (toLen+charArraySize <= toMax)
		{ 
			for (var i=0; i<charArraySize; i++)
			{
				toArray[toLen] = charArray[i];
				toLen += 1;
			}
		}
	
		return toLen;
	}
	
	function addArrayToCharArray(sArray, toArray, toLen, toMax)
	{
		var lastComma = toLen;
		var charArray = sArray.toString().toCharArray();
		var charArraySize = charArray.size();
		var cPrev = 0;
		for (var i=0; i<charArraySize; i++)
		{
			var c = charArray[i];
			var cNumber = c.toNumber();
			// remove square brackets
			// remove spaces immediately after commas (leave spaces in middle of profile names!)
			if (cNumber!=91/*APPCHAR_OPEN_SQUARE_BRACKET*/ && cNumber!=93/*APPCHAR_CLOSE_SQUARE_BRACKET*/ && !(cNumber==32/*APPCHAR_SPACE*/ && cPrev==44/*APPCHAR_COMMA*/))
			{
				if (toLen >= toMax)
				{
					toLen = lastComma;
					break;
				}

				if (cNumber==44/*APPCHAR_COMMA*/)
				{
					lastComma = toLen;
				}

				toArray[toLen] = c;
				toLen += 1;
			}
			
			cPrev = cNumber;
		}

		return toLen;
	}

    // Order of calling on start up
	// initialize() → onLayout() → onShow() → onUpdate()
	//
	// Order of calling when settings changed
	// onSettingsChanged() → onUpdate()
	//
	// Order of calling on close
	// onHide()

    function initialize()
    {
        //System.println("initialize");

        WatchFace.initialize();
    }

	function importJsonData(id, profileIndex, watchUi, storage)
	{
		var tempResource = watchUi.loadResource(id);
		for (var i=0; i<tempResource.size(); i++)
		{
			storage.setValue("P" + profileIndex, tempResource[i][0]);
			
			// use propFieldData byte array temporarily (it gets initialized later anyway)
			// we convert all the resource field data to a byte array so that it is in the same format (and memory size) as any user saved profiles
			// - then we don't need to worry about presets and user profiles acting differently when loaded/exported
			var fArray = tempResource[i][1];
			var fArraySize = fArray.size();					
			for (var j=0; j<FIELD_NUM*FIELD_NUM_PROPERTIES; j++)
			{
				propFieldData[j] = ((j<fArraySize) ? fArray[j] : 0);
			}
			storage.setValue("PF" + profileIndex, propFieldData);

			profileIndex++;
		}
		
		return profileIndex;
	}

    // Load your resources here
    function onLayout(dc)
    {
        //System.println("onLayout");

		var storage = applicationStorage;
		var watchUi = WatchUi;
		var fonts = Rez.Fonts;

		//if (forceClearStorage)
		//{
		//	storage.clearValues();		// clear all values from storage for debugging
		//}		
	
        var deviceSettings = System.getDeviceSettings();	// 960 bytes, but uses less code memory 
		hasDoNotDisturb = (deviceSettings has :doNotDisturb);
		hasLTE = (deviceSettings.connectionInfo[:lte]!=null);

		// need to seed the random number generator?
		//var clockTime = System.getClockTime();
		//var seed = clockTime.sec + clockTime.min*60 + clockTime.hour*(60*60) + System.getTimer();
		//Math.srand(seed);
				
        iconsFontResource = watchUi.loadResource(fonts.id_icons);

		outerFontResource = watchUi.loadResource(fonts.id_outer);
		outerBigFontResource = watchUi.loadResource(fonts.id_outer_big);

        //circleFont = WatchUi.loadResource(fonts.id_circle);
        //ringFont = WatchUi.loadResource(fonts.id_ring);

		//worldBitmap = WatchUi.loadResource(Rez.Drawables.id_world);

        // If this device supports BufferedBitmap, allocate the buffer for what's behind the seconds indicator 
        //if (Toybox.Graphics has :BufferedBitmap)
		// This full color buffer is needed because anti-aliased fonts cannot be drawn into a buffer with a reduced color palette
        bufferBitmap = new Graphics.BufferedBitmap({:width=>62/*BUFFER_SIZE*/, :height=>62/*BUFFER_SIZE*/});
		
		// load in character string (for seconds & outer ring)
		//characterString = WatchUi.loadResource(Rez.JsonData.id_characterString);

		// make sure preset profiles are saved to storage (from jsondata)
		{
			var sVersion = storage.getValue("V");
			if (sVersion==null || sVersion!=PROFILE_VERSION)
			{
				var jsonData = Rez.JsonData;
				var profileIndex = PROFILE_NUM_USER;

				// less code to just call 3 times instead of loop				
				//var loadPreset = [jsonData.id_preset, jsonData.id_preset2, jsonData.id_preset3];
				//for (var i=0; i<loadPreset.size(); i++)
				//{
				//	profileIndex = importJsonData(loadPreset[i], profileIndex, watchUi, storage);
				//}
				
				profileIndex = importJsonData(jsonData.id_preset, profileIndex, watchUi, storage);
				profileIndex = importJsonData(jsonData.id_preset2, profileIndex, watchUi, storage);
				profileIndex = importJsonData(jsonData.id_preset3, profileIndex, watchUi, storage);
									
				storage.setValue("V", PROFILE_VERSION);
			}
		}
		
		// load in second indicator & outer ring positions
		{
			var tempResource = watchUi.loadResource(Rez.JsonData.id_coordsXY);
			for (var i=0; i<120; i++)
			{
				secondsX[i] = tempResource[0][i];
				secondsY[i] = tempResource[1][i];
				outerX[i] = tempResource[2][i];
				outerY[i] = tempResource[3][i];
			}
			tempResource = null;
		}

		// initialize propFieldData
		{
			var sArray = storage.getValue("F");		// load saved prop field data from storage
		 	var sArraySize = ((sArray!=null) ? sArray.size() : 0);
			for (var i=0; i<FIELD_NUM*FIELD_NUM_PROPERTIES; i++)
			{
				if (i<sArraySize)
				{
					propFieldData[i] = sArray[i];
				}
				else
				{
					var n = (i%FIELD_NUM_PROPERTIES);
	    			if (n==0/*FIELD_INDEX_YOFFSET*/ || n==1/*FIELD_INDEX_XOFFSET*/)
	    			{
	    				propFieldData[i] = 120;
	    			}
	    			else
	    			{
						propFieldData[i] = 0;
					}
				}
			}
			
			// if there was no saved field data (first time running watch face)
			// then make sure the propFieldData matches the properties (as set to their default values)
			if (sArray==null)
			{
				getOrSetPropFieldDataProperties();		// get field data from properties
			}
			//else
			//{
			//	// delete the saved prop field data (in case the app decides to reset itself and all properties ...)
			//	// this doesn't even work - must call onStop() when crashing too
			//	storage.deleteValue("F");
			//}
			
			sArray = null;
		}
						
		// remember which profile was active and also any profileDelayEnd value
		// - then checkProfiles will know whether to restore the private profile or not
		{
			var saveData = storage.getValue("C");
			if (saveData!=null)
			{
				// delete the saved data (in case the app decides to reset itself and all properties ...)
				//storage.deleteValue("C");

				var timeNowValue = Time.now().value();
				
				if (saveData[0]>=PROFILE_PRIVATE_INDEX && saveData[0]<PROFILE_NUM_USER+PROFILE_NUM_PRESET)
				{
					profileActive = saveData[0];
					profileDelayEnd = saveData[1];
					
					// verify that profileDelayEnd is not too far in the future ... just in case (should be 2+1 minutes or less)
					if (profileDelayEnd > (timeNowValue + (2+1)*60))
					{
						profileDelayEnd = 0;
					}
				}
				
				if (saveData[2]>=0 && saveData[2]<PROFILE_NUM_USER)
				{
					profileRandom = saveData[2]; 
					profileRandomEnd = saveData[3];
					
					// verify that profileRandomEnd is not too far in the future ... just in case (should be 20+1 minutes or less)
					if (profileRandomEnd > (timeNowValue + (20+1)*60))
					{
						profileRandomEnd = 0;
					}
				}
				
				if (saveData[4]>=0 && saveData[4]<PROFILE_NUM_USER+PROFILE_NUM_PRESET)
				{
					demoProfilesCurrentProfile = saveData[4]; 
					demoProfilesCurrentEnd = saveData[5];
					
					// verify that demoProfilesCurrentEnd is not too far in the future ... just in case (should be 5+1 minutes or less)
					if (demoProfilesCurrentEnd > (timeNowValue + (5+1)*60))
					{
						demoProfilesCurrentEnd = 0;
					}
				}
				
				demoProfilesOn = saveData[6];
				demoProfilesOnPrev = demoProfilesOn; 
			}
			saveData = null;
		}

		initProfiles();			// load profile times and save out a first version of the private profile to storage if it doesn't exist
    }

	function saveDataForStop()
	{
		// remember the active profile and profileDelayEnd
		// and other variables we want to save between runs
		var saveData = [profileActive, profileDelayEnd, profileRandom, profileRandomEnd, demoProfilesCurrentProfile, demoProfilesCurrentEnd, demoProfilesOn];
		applicationStorage.setValue("C", saveData);
		
		// store the current field data to storage - used only when watchface next loaded
		applicationStorage.setValue("F", propFieldData);	// seems to work storing a byte array ...
	}

	// called from the app when it is being ended
	function onStop()
	{
        //System.println("onStop");

		saveDataForStop();

		if (profileActive>=0)	// not the private profile (watch settings)
		{
			applicationProperties.setValue("PM", 6);	// set the "profile was active" management status
		}
	}

    // Called when this View is brought to the foreground.
    // Restore the state of this View and prepare it to be shown. This includes loading resources into memory.
    function onShow()
    {
        //System.println("onShow");

		/*
		// calculate second indicator positions & character string
		{
			//var secondsX = new[60*2];
			//var secondsY = new[60*2];

			for (var i=0; i<60; i++)
			{
        		var r = Math.toRadians(i*6);
        		var rSin = Math.sin(r);
        		var rCos = Math.cos(r);
        		var x;
        		var y;
	        	// top left of char
	        	x = Math.floor(SCREEN_CENTRE_X - SECONDS_SIZE_HALF + 0.5 + SECONDS_CENTRE_OFFSET * rSin);
	        	y = Math.floor(SCREEN_CENTRE_Y - SECONDS_SIZE_HALF + 0.5 - SECONDS_CENTRE_OFFSET * rCos) - 1;
		    	secondsX[i] = x.toNumber() + SECONDS_SIZE_HALF;	// make sure in range 0 to 255
		    	secondsY[i] = y.toNumber() + SECONDS_SIZE_HALF;	// make sure in range 0 to 255
	
				var i60 = i+60;
        		x = Math.floor(SCREEN_CENTRE_X - SECONDS_SIZE_HALF + 0.5 + (SECONDS_CENTRE_OFFSET-4) * rSin);
        		y = Math.floor(SCREEN_CENTRE_Y - SECONDS_SIZE_HALF + 0.5 - (SECONDS_CENTRE_OFFSET-4) * rCos) - 1;
		    	secondsX[i60] = x.toNumber() + SECONDS_SIZE_HALF;	// make sure in range 0 to 255
		    	secondsY[i60] = y.toNumber() + SECONDS_SIZE_HALF;	// make sure in range 0 to 255
			}
			
			//storage.setValue("secondsX", secondsX);
			//storage.setValue("secondsY", secondsY);
	    }

		// calculate outer ring positions & character string
		{
			//var outerX = new[120];
			//var outerY = new[120];

			for (var i=0; i<120; i++)
			{
		        var r = Math.toRadians((i*3) + 1.5);	// to centre of arc
	        	// top left of char
		    	var x = Math.floor(SCREEN_CENTRE_X - OUTER_SIZE_HALF + 0.5 + OUTER_CENTRE_OFFSET * Math.sin(r));
		    	var y = Math.floor(SCREEN_CENTRE_Y - OUTER_SIZE_HALF + 0.5 - OUTER_CENTRE_OFFSET * Math.cos(r)) - 1;
		    	outerX[i] = x.toNumber() + OUTER_SIZE_HALF;	// make sure in range 0 to 255
		    	outerY[i] = y.toNumber() + OUTER_SIZE_HALF;	// make sure in range 0 to 255
			}

			//storage.setValue("outerX", outerX);
			//storage.setValue("outerY", outerY);
	    }
		*/
		
		/*
		// debug code for calculating font character positions of second indicator
        for (var i = 0; i < 60; i++)
        {
       		var id = SECONDS_FIRST_CHAR_ID + i;
			var page = (i % 2);		// even or odd pages
        
        	var r = Math.toRadians(i*6);

        	// top left of char
        	//var x = Math.floor(SCREEN_CENTRE_X - SECONDS_SIZE_HALF + 0.5 + SECONDS_CENTRE_OFFSET * Math.sin(r));
        	//var y = Math.floor(SCREEN_CENTRE_Y - SECONDS_SIZE_HALF + 0.5 - SECONDS_CENTRE_OFFSET * Math.cos(r));
        	var x = secondsX[i];
        	var y = secondsY[i] + 1;

        	var s = Lang.format("char id=$1$ x=$2$ y=$3$ width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=$4$ chnl=15", [id, x.format("%d"), y.format("%d"), page]);
        	System.println(s);
		}
		
		char id=21 x=112 y=0 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=22 x=124 y=1 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=23 x=135 y=2 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=24 x=147 y=5 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=25 x=158 y=10 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=26 x=168 y=15 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=27 x=178 y=21 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=28 x=187 y=29 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=29 x=195 y=37 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=30 x=203 y=46 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=31 x=209 y=56 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=32 x=214 y=66 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=33 x=219 y=77 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=34 x=222 y=89 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=35 x=223 y=100 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=36 x=224 y=112 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=37 x=223 y=124 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=38 x=222 y=135 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=39 x=219 y=147 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=40 x=214 y=158 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=41 x=209 y=168 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=42 x=203 y=178 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=43 x=195 y=187 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=44 x=187 y=195 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=45 x=178 y=203 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=46 x=168 y=209 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=47 x=158 y=214 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=48 x=147 y=219 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=49 x=135 y=222 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=50 x=124 y=223 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=51 x=112 y=224 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=52 x=100 y=223 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=53 x=89 y=222 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=54 x=77 y=219 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=55 x=66 y=214 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=56 x=56 y=209 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=57 x=46 y=203 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=58 x=37 y=195 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=59 x=29 y=187 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=60 x=21 y=178 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=61 x=15 y=168 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=62 x=10 y=158 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=63 x=5 y=147 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=64 x=2 y=135 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=65 x=1 y=124 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=66 x=0 y=112 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=67 x=1 y=100 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=68 x=2 y=89 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=69 x=5 y=77 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=70 x=10 y=66 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=71 x=15 y=56 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=72 x=21 y=46 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=73 x=29 y=37 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=74 x=37 y=29 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=75 x=46 y=21 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=76 x=56 y=15 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=77 x=66 y=10 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=78 x=77 y=5 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=79 x=89 y=2 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=80 x=100 y=1 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		*/
		
		/*
		// debug code for calculating font character positions of second indicator (moved in 4 pixels)
        for (var i = 0; i < 60; i++)
        {
       		var id = SECONDS_FIRST_CHAR_ID + i;
			var page = (i % 2);		// even or odd pages
        
        	var r = Math.toRadians(i*6);

        	// top left of char
        	//var x = Math.floor(SCREEN_CENTRE_X - SECONDS_SIZE_HALF + 0.5 + (SECONDS_CENTRE_OFFSET-4) * Math.sin(r));
        	//var y = Math.floor(SCREEN_CENTRE_Y - SECONDS_SIZE_HALF + 0.5 - (SECONDS_CENTRE_OFFSET-4) * Math.cos(r));
        	var x = secondsX[i+60];
        	var y = secondsY[i+60] + 1;

        	var s = Lang.format("char id=$1$ x=$2$ y=$3$ width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=$4$ chnl=15", [id, x.format("%d"), y.format("%d"), page]);
        	System.println(s);
		}

		char id=21 x=112 y=4 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=22 x=123 y=5 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=23 x=134 y=6 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=24 x=145 y=9 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=25 x=156 y=13 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=26 x=166 y=18 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=27 x=175 y=25 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=28 x=184 y=32 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=29 x=192 y=40 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=30 x=199 y=49 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=31 x=206 y=58 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=32 x=211 y=68 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=33 x=215 y=79 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=34 x=218 y=90 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=35 x=219 y=101 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=36 x=220 y=112 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=37 x=219 y=123 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=38 x=218 y=134 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=39 x=215 y=145 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=40 x=211 y=156 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=41 x=206 y=166 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=42 x=199 y=175 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=43 x=192 y=184 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=44 x=184 y=192 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=45 x=175 y=199 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=46 x=166 y=206 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=47 x=156 y=211 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=48 x=145 y=215 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=49 x=134 y=218 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=50 x=123 y=219 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=51 x=112 y=220 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=52 x=101 y=219 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=53 x=90 y=218 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=54 x=79 y=215 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=55 x=68 y=211 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=56 x=58 y=206 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=57 x=49 y=199 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=58 x=40 y=192 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=59 x=32 y=184 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=60 x=25 y=175 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=61 x=18 y=166 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=62 x=13 y=156 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=63 x=9 y=145 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=64 x=6 y=134 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=65 x=5 y=123 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=66 x=4 y=112 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=67 x=5 y=101 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=68 x=6 y=90 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=69 x=9 y=79 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=70 x=13 y=68 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=71 x=18 y=58 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=72 x=25 y=49 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=73 x=32 y=40 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=74 x=40 y=32 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=75 x=49 y=25 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=76 x=58 y=18 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=77 x=68 y=13 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=78 x=79 y=9 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=79 x=90 y=6 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=80 x=101 y=5 width=16 height=16 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		*/
		
		/*
		// debug code for calculating font character positions of outer circle
        for (var i = 0; i < 120; i++)
        {
       		var id = OUTER_FIRST_CHAR_ID + i;

			var page = (i % 2);		// even or odd pages
        
        	var r = Math.toRadians((i*3) + 1.5);

        	// top left of char
        	//var x = Math.floor(SCREEN_CENTRE_X - OUTER_SIZE_HALF + 0.5 + OUTER_CENTRE_OFFSET * Math.sin(r));
        	//var y = Math.floor(SCREEN_CENTRE_Y - OUTER_SIZE_HALF + 0.5 - OUTER_CENTRE_OFFSET * Math.cos(r));
        	var x = outerX[i];
        	var y = outerY[i] + 1;

        	var s = Lang.format("char id=$1$ x=$2$ y=$3$ width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=$4$ chnl=15", [id, x.format("%d"), y.format("%d"), page]);
        	System.println(s);
		}
		
		char id=1 x=118 y=-2 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=2 x=124 y=-2 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=3 x=130 y=-1 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=4 x=136 y=0 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=5 x=142 y=1 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=6 x=148 y=3 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=7 x=154 y=5 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=8 x=160 y=7 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=9 x=165 y=9 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=11 x=171 y=12 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=12 x=176 y=15 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=13 x=181 y=19 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=14 x=186 y=22 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=15 x=191 y=26 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=16 x=196 y=30 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=17 x=200 y=34 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=18 x=204 y=39 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=19 x=208 y=44 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=20 x=211 y=49 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=21 x=215 y=54 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=22 x=218 y=59 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=23 x=221 y=65 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=24 x=223 y=70 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=25 x=225 y=76 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=26 x=227 y=82 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=27 x=229 y=88 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=28 x=230 y=94 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=29 x=231 y=100 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=30 x=232 y=106 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=31 x=232 y=112 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=32 x=232 y=118 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=33 x=232 y=124 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=34 x=231 y=130 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=35 x=230 y=136 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=36 x=229 y=142 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=37 x=227 y=148 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=38 x=225 y=154 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=39 x=223 y=160 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=40 x=221 y=165 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=41 x=218 y=171 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=42 x=215 y=176 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=43 x=211 y=181 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=44 x=208 y=186 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=45 x=204 y=191 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=46 x=200 y=196 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=47 x=196 y=200 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=48 x=191 y=204 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=49 x=186 y=208 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=50 x=181 y=211 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=51 x=176 y=215 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=52 x=171 y=218 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=53 x=165 y=221 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=54 x=160 y=223 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=55 x=154 y=225 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=56 x=148 y=227 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=57 x=142 y=229 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=58 x=136 y=230 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=59 x=130 y=231 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=60 x=124 y=232 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=61 x=118 y=232 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=62 x=112 y=232 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=63 x=106 y=232 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=64 x=100 y=231 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=65 x=94 y=230 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=66 x=88 y=229 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=67 x=82 y=227 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=68 x=76 y=225 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=69 x=70 y=223 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=70 x=65 y=221 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=71 x=59 y=218 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=72 x=54 y=215 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=73 x=49 y=211 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=74 x=44 y=208 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=75 x=39 y=204 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=76 x=34 y=200 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=77 x=30 y=196 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=78 x=26 y=191 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=79 x=22 y=186 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=80 x=19 y=181 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=81 x=15 y=176 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=82 x=12 y=171 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=83 x=9 y=165 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=84 x=7 y=160 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=85 x=5 y=154 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=86 x=3 y=148 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=87 x=1 y=142 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=88 x=0 y=136 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=89 x=-1 y=130 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=90 x=-2 y=124 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=91 x=-2 y=118 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=92 x=-2 y=112 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=93 x=-2 y=106 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=94 x=-1 y=100 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=95 x=0 y=94 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=96 x=1 y=88 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=97 x=3 y=82 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=98 x=5 y=76 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=99 x=7 y=70 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=100 x=9 y=65 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=101 x=12 y=59 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=102 x=15 y=54 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=103 x=19 y=49 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=104 x=22 y=44 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=105 x=26 y=39 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=106 x=30 y=34 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=107 x=34 y=30 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=108 x=39 y=26 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=109 x=44 y=22 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=110 x=49 y=19 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=111 x=54 y=15 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=112 x=59 y=12 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=113 x=65 y=9 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=114 x=70 y=7 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=115 x=76 y=5 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=116 x=82 y=3 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=117 x=88 y=1 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=118 x=94 y=0 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=119 x=100 y=-1 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		char id=120 x=106 y=-2 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=0 chnl=15
		char id=121 x=112 y=-2 width=10 height=10 xoffset=0 yoffset=0 xadvance=16 page=1 chnl=15
		*/
    }

    // Called when this View is removed from the screen (including the app ending).
    // Save the state of this View here. This includes freeing resources from memory.
    function onHide()
    {
        //System.println("onHide");
	}

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep()
    {
        //System.println("Glance");
        onOrGlanceActive = (ITEM_ON|ITEM_ONGLANCE);		// on + show on glance
        //WatchUi.requestUpdate();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep()
    {
        //System.println("Sleep");
        onOrGlanceActive = ITEM_ON;			// on only
        WatchUi.requestUpdate();
    }

	// Called by app when settings are changed by user
    function onSettingsChanged()
    {
    	settingsHaveChanged = true;		// set flag so onUpdate can handle this
    	
    	// when sending new settings it seems some memory gets allocated (by the system) between here and next onUpdate
    	// so release all the dynamic font resources here, so the system allocation isn't allocated after them
		releaseDynamicResources();

        WatchUi.requestUpdate();
	}
	
	function clearExportImportStrings()
	{
		applicationProperties.setValue("EP", "");
		applicationProperties.setValue("EF", "");
		applicationProperties.setValue("EG", "");
	}
	
	function handleSettingsChanged(clockTime, timeNow)
	{
		demoProfilesOnPrev = demoProfilesOn; 
		demoProfilesOn = propertiesGetBoolean("DP");

		var profileManagement = propertiesGetNumber("PM");
		var profileNumber = propertiesGetNumber("PN") - 1;
		var setProfileDelay = false;

		if (profileManagement!=5)		// clear the export/import strings if doing anything other than an import
		{
			clearExportImportStrings();
		}

		if (profileManagement>0)	// not making changes to watch settings
		{
			// set property to do a normal update (so not caught out the next time you open settings)
			applicationProperties.setValue("PM", 0);

			setProfileDelay = true;

			if (profileManagement == 1)				// retrieve watch settings
			{
				// always load this even if it was currently active
				// - otherwise whatever settings are in the users window get applied, which is confusing! 
				loadProfile(PROFILE_PRIVATE_INDEX);	// clears profileActive, and sets field management property to retrieve
				//setProfileDelay = true;
			}
			else if (profileManagement == 2)		// save to profile
			{
				saveProfile(profileNumber);			// will set profileActive
				//setProfileDelay = true;
			}
			else if (profileManagement == 3)		// load from profile
			{
				loadProfile(profileNumber);			// will set profileActive
				//setProfileDelay = true;
			}
			else if (profileManagement == 4)
			{
				exportProfile(profileNumber);
				loadProfile(profileNumber);			// also load it to show the user what they exported
				//setProfileDelay = true;
			}
			else if (profileManagement == 5)
			{
				importProfile(profileNumber);
				clearExportImportStrings();			// clear the export/import strings before load 
				loadProfile(profileNumber);			// also load it to show the user what they imported
				//setProfileDelay = true;
			}
			else //if (profileManagement == 6)		// profile was active (so settings won't get changed)
			{
				setProfileDelay = false;

				// always load this even though it was currently active
				// - otherwise whatever settings are in the users window get applied, which is confusing! 
				loadProfile(profileActive);			// sets field management property to retrieve
				
				// if we didn't have this setting, then whenever the user leaves the watchface (e.g. to a widget)
				// and returns while a profile was active, then those profile settings would get saved to the 
				// private profile below! 
			}

			getOrSetPropFieldDataProperties();
		}
		else	// making changes to watch settings
		{
			var fManagement = propertiesGetNumber("FM");
		
			getOrSetPropFieldDataProperties();
	
			// if user is retrieving field settings, or turning on/off demo profiles, then don't accept any settings changes
			// - instead load the currently active profile to override any changes
			if (fManagement==ITEM_RETRIEVE || demoProfilesOn!=demoProfilesOnPrev)
			{
				loadProfile(profileActive);			// sets field management property to retrieve
			}
			else
			{
				// do this after getOrSetPropFieldDataProperties
				saveProfile(PROFILE_PRIVATE_INDEX);		// will set profileActive = PROFILE_PRIVATE_INDEX
			}
		}
		
		// special case for handling when demoProfiles is toggled from off to on - don't do any profile delay
		if (!setProfileDelay)
		{
			if (demoProfilesOn!=demoProfilesOnPrev)
			{
				profileDelayEnd = 0;
			}
			else if (settingsHaveChanged)
			{
				setProfileDelay = true;
			}
		}
		
		if (setProfileDelay)
		{
			profileDelayEnd = timeNow.value() + ((60-clockTime.sec)%60) + 2*60;		// delay of 2 minutes before any auto profile switching
			profileRandomEnd = 0;							// clear this
			demoProfilesCurrentEnd = 0;
		}
	}
		
	// forceChange is set to true when either the settings have been changed by the user or a new profile has loaded
	// - in these situations if any of the demo settings flags are set then we need to set the relevant properties straight away
	function checkDemoSettings(index, forceChange)
	{
		var changed = false;
        var properties = applicationProperties;		// using local variable reduces code size
        
        if (propertiesGetBoolean("32") /*|| forceDemoFontStyles*/)		// demo font styles on
        {
	        if ((index%3)==0 || forceChange)
	        { 
	        	var index3 = index/3;
	        
				properties.setValue("4", (index3/6)%6);		// time hour font
				properties.setValue("6", index3%6);			// time minute font
		
		    	properties.setValue("24", 6/*APPFONT_ULTRA_LIGHT_TINY*/ + 6*(index3%3));		// field font
		    	properties.setValue("25", (index3/3)%6);	// field custom weight
		
				properties.setValue("8", ((index3/36)%2)==1);		// italic

		    	changed = true;
		    }
		}
			    
        if (propertiesGetBoolean("33"))		// demo second styles on
        {
	        if ((index%3)==0 || forceChange)
	        { 
	        	var index3 = index/3;
	        
		    	properties.setValue("11", index3%6/*SECONDFONT_TRI_IN*/);		// second indicator style - cycles every 18
		
		    	changed = true;
		    }

        	var srs = index%11;		// prime number to be out of sync with indicator style
        	if (srs<3)		// 0, 1, 2
        	{
        		srs = 1/*REFRESH_EVERY_MINUTE*/;
        	}
        	else if (srs<7)	// 3, 4, 5, 6
        	{
        		srs = 2/*REFRESH_ALTERNATE_MINUTES*/;
        	}
        	else			// 7, 8, 9, 10
        	{
        		srs = 0/*REFRESH_EVERY_SECOND*/;
        	}
	    	properties.setValue("12", srs);		// second refresh style
	    	//changed = true;	don't need to set changed for this
		}
			    
	    return changed;
	}

	function getOrSetPropFieldDataProperties()
	{
		var fManagement = propertiesGetNumber("FM");
		var fNumber = propertiesGetNumber("FN");
		
		var fNumberValid = (fNumber>=1 && fNumber<=FIELD_NUM);	// check the field number is in range (1-8)
		if (!fNumberValid)
		{
			fNumber = 1;
			applicationProperties.setValue("FN", fNumber);
		}
		
		var fIndex = (fNumber-1)*FIELD_NUM_PROPERTIES;		// index into field data array
    	if (fManagement==ITEM_RETRIEVE)						// field status off/on/retrieve == retrieve
    	{
    		// set field properties from values in memory
    		for (var i=0; i<FIELD_NUM_PROPERTIES; i++)
    		{
    			var v = propFieldData[fIndex + i].toNumber();
    			if (i==0/*FIELD_INDEX_YOFFSET*/)
    			{
    				v = 120 - v;
    			}
    			else if (i==1/*FIELD_INDEX_XOFFSET*/)
    			{
    				v -= 120;
    			}
    			else if (i==2/*FIELD_INDEX_JUSTIFICATION*/)
    			{
    				var m = (v%FIELD_MANAGEMENT_MODULO);
					applicationProperties.setValue("FM", m);

    				v = (v/FIELD_MANAGEMENT_MODULO);
    			}
				applicationProperties.setValue("F" + i, v);
    		}
    	}
    	else
    	{
   			// only store the values if the user entered a valid number
   			// (best not to overwrite the wrong field which they didn't intend)
    		if (fNumberValid)
    		{
	    		// store all current field properties to memory
	    		for (var i=0; i<FIELD_NUM_PROPERTIES; i++)
	    		{
					var v = propertiesGetNumber("F" + i);	// All of the field properties are numbers

	    			if (i==0/*FIELD_INDEX_YOFFSET*/)
	    			{
	    				v = 120 - v;
	    			}
	    			else if (i==1/*FIELD_INDEX_XOFFSET*/)
	    			{
	    				v += 120;
	    			}
	    			else if (i==2/*FIELD_INDEX_JUSTIFICATION*/)
	    			{
	    				v = (fManagement%FIELD_MANAGEMENT_MODULO) + (v*FIELD_MANAGEMENT_MODULO);
	    			}

    				if (v<0)
    				{
    					v = 0;
    				}
    				else if (v>255)
    				{
    					v = 255;
    				}

					propFieldData[fIndex + i] = v;
	    		}

				// store the current field data to storage - used only when watchface next loaded
				// - ideally we'd only do this in onStop() but there seems to be a bug where saving there doesn't always happen
				// e.g. if switching watchfaces fast in the system menu
				saveDataForStop();
	    	}	    	
    	}
	}
		
    // Get values for all our settings
    function getGlobalProperties()
    {
		propBackgroundColor = propertiesGetColor("1");

    	propTimeOn = propertiesGetNumber("2");
   		propTimeHourFont = propertiesGetNumber("4");
	 	if (propTimeHourFont<0 || propTimeHourFont>=33/*APPFONT_NUMBER_OF_FONTS*/)
	 	{
	 		propTimeHourFont = 3/*APPFONT_REGULAR*/;
	 	}
		propTimeHourColor = propertiesGetColor("5");
   		propTimeMinuteFont = propertiesGetNumber("6");
		if (propTimeMinuteFont<0 || propTimeMinuteFont>=33/*APPFONT_NUMBER_OF_FONTS*/)
		{
	 		propTimeMinuteFont = 3/*APPFONT_REGULAR*/;
		}
		propTimeMinuteColor = propertiesGetColor("7");
    	propTimeItalic = (propertiesGetBoolean("8") && (propTimeHourFont<=5/*APPFONT_HEAVY*/) && (propTimeMinuteFont<=5/*APPFONT_HEAVY*/));
		propTimeYOffset = propertiesGetNumber("9");
    	
    	propSecondIndicatorOn = propertiesGetNumber("10");
    	propSecondRefreshStyle = propertiesGetNumber("12");
    	propSecondMoveInABit = propertiesGetBoolean("19");		// move in a bit
    
		propSecondIndicatorStyle = propertiesGetNumber("11") + (propSecondMoveInABit ? 6/*SECONDFONT_TRI_IN*/ : 0);
	 	if (propSecondIndicatorStyle<0 || propSecondIndicatorStyle>=12/*SECONDFONT_UNUSED*/)
	 	{
	 		propSecondIndicatorStyle = 0/*SECONDFONT_TRI*/;
	 	}

		if ((propSecondIndicatorOn&(ITEM_ON|ITEM_ONGLANCE))!=0)
		{
			// calculate the seconds color array
	    	var secondColor = propertiesGetColor("13");		// second color
	    	var secondColor5 = propertiesGetColor("14");
	    	var secondColor10 = propertiesGetColor("15");
	    	var secondColor15 = propertiesGetColor("16");
	    	var secondColor0 = propertiesGetColor("17");
	    	var secondColorDemo = propertiesGetBoolean("18");		// second color demo
	    	for (var i=0; i<60; i++)
	    	{
				var col;
		
		        if (secondColorDemo)		// second color demo
		        {
		        	col = getColorArray(4 + i);
		        }
				else if (secondColor0!=COLOR_NOTSET && i==0)
				{
					col = secondColor0;
				}
				else if (secondColor15!=COLOR_NOTSET && (i%15)==0)
				{
					col = secondColor15;
				}
				else if (secondColor10!=COLOR_NOTSET && (i%10)==0)
				{
					col = secondColor10;
				}
				else if (secondColor5!=COLOR_NOTSET && (i%10)==5)
				{
					col = secondColor5;
				}
		        else
		        {
		        	col = secondColor;		// second color
		        }
		        
		        secondsCol[i] = col;
		    }
		}
		
    	var fieldFont = propertiesGetNumber("24");
   		propFieldFont = ((fieldFont<24/*APPFONT_SYSTEM_XTINY*/) ? (fieldFont + propertiesGetNumber("25")) : fieldFont);		// add weight to non system fonts 
		if (propFieldFont<0 || propFieldFont>=33/*APPFONT_NUMBER_OF_FONTS*/)
		{
			propFieldFont = 15/*APPFONT_REGULAR_SMALL*/;
		}
		
    	propFieldFontUnsupported = propertiesGetNumber("27");
		
		propOuterOn = propertiesGetNumber("20");		// outer ring on
		propOuterColorFilled = propertiesGetColor("22");
		propOuterColorUnfilled = propertiesGetColor("23");

		propDemoDisplayOn = propertiesGetBoolean("34");
	}
    
    function releaseDynamicResources()
    {
		// allow all old resources to be freed immediately and at same time
    	fontTimeHourResource = null;
    	fontTimeMinuteResource = null;
		propSecondFontResource = null;
	   	fontFieldResource = null;
    }
    
    function loadDynamicResources()
    {
    	var watchUi = WatchUi;
    	var fonts = Rez.Fonts;
		var graphics = Graphics;

		var fontLoad = [
			fonts.id_trivial_ultra_light,		// APPFONT_ULTRA_LIGHT
			fonts.id_trivial_extra_light,		// APPFONT_EXTRA_LIGHT
			fonts.id_trivial_light,				// APPFONT_LIGHT
			fonts.id_trivial_regular,			// APPFONT_REGULAR
			fonts.id_trivial_bold,				// APPFONT_BOLD
			fonts.id_trivial_heavy,				// APPFONT_HEAVY
			fonts.id_trivial_ultra_light_tiny,	// APPFONT_ULTRA_LIGHT_TINY
			fonts.id_trivial_extra_light_tiny,	// APPFONT_EXTRA_LIGHT_TINY
			fonts.id_trivial_light_tiny,		// APPFONT_LIGHT_TINY
			fonts.id_trivial_regular_tiny,		// APPFONT_REGULAR_TINY
			fonts.id_trivial_bold_tiny,			// APPFONT_BOLD_TINY
			fonts.id_trivial_heavy_tiny,		// APPFONT_HEAVY_TINY
			fonts.id_trivial_ultra_light_small,	// APPFONT_ULTRA_LIGHT_SMALL
			fonts.id_trivial_extra_light_small,	// APPFONT_EXTRA_LIGHT_SMALL
			fonts.id_trivial_light_small,		// APPFONT_LIGHT_SMALL
			fonts.id_trivial_regular_small,		// APPFONT_REGULAR_SMALL
			fonts.id_trivial_bold_small,		// APPFONT_BOLD_SMALL
			fonts.id_trivial_heavy_small,		// APPFONT_HEAVY_SMALL
			fonts.id_trivial_ultra_light_medium,// APPFONT_ULTRA_LIGHT_MEDIUM
			fonts.id_trivial_extra_light_medium,// APPFONT_EXTRA_LIGHT_MEDIUM
			fonts.id_trivial_light_medium,		// APPFONT_LIGHT_MEDIUM
			fonts.id_trivial_regular_medium,	// APPFONT_REGULAR_MEDIUM
			fonts.id_trivial_bold_medium,		// APPFONT_BOLD_MEDIUM
			fonts.id_trivial_heavy_medium,		// APPFONT_HEAVY_MEDIUM
		];
				
		var fontSystem = [
			graphics.FONT_SYSTEM_XTINY, 			// APPFONT_SYSTEM_XTINY
			graphics.FONT_SYSTEM_TINY, 				// APPFONT_SYSTEM_TINY
			graphics.FONT_SYSTEM_SMALL, 			// APPFONT_SYSTEM_SMALL
			graphics.FONT_SYSTEM_MEDIUM,			// APPFONT_SYSTEM_MEDIUM
			graphics.FONT_SYSTEM_LARGE,				// APPFONT_SYSTEM_LARGE
			graphics.FONT_SYSTEM_NUMBER_MILD,		// APPFONT_SYSTEM_NUMBER_NORMAL 
			graphics.FONT_SYSTEM_NUMBER_MEDIUM,		// APPFONT_SYSTEM_NUMBER_MEDIUM 
			graphics.FONT_SYSTEM_NUMBER_HOT,		// APPFONT_SYSTEM_NUMBER_LARGE 
			graphics.FONT_SYSTEM_NUMBER_THAI_HOT,	// APPFONT_SYSTEM_NUMBER_HUGE 
		];
	
		var fontLoadItalic = [
			fonts.id_trivial_ultra_light_italic,	// APPFONT_ULTRA_LIGHT
			fonts.id_trivial_extra_light_italic,	// APPFONT_EXTRA_LIGHT
			fonts.id_trivial_light_italic,			// APPFONT_LIGHT
			fonts.id_trivial_regular_italic,		// APPFONT_REGULAR
			fonts.id_trivial_bold_italic,			// APPFONT_BOLD
			fonts.id_trivial_heavy_italic,			// APPFONT_HEAVY
		];

		var secondFontLoad = [
			fonts.id_seconds_tri,			// SECONDFONT_TRI
			fonts.id_seconds_v,				// SECONDFONT_V
			fonts.id_seconds_line,			// SECONDFONT_LINE
			fonts.id_seconds_linethin,		// SECONDFONT_LINETHIN
			fonts.id_seconds_circular,		// SECONDFONT_CIRCULAR
			fonts.id_seconds_circularthin,	// SECONDFONT_CIRCULARTHIN
			
			fonts.id_seconds_tri_in,		// SECONDFONT_TRI_IN
			fonts.id_seconds_v_in,			// SECONDFONT_V_IN
			fonts.id_seconds_line_in,		// SECONDFONT_LINE_IN
			fonts.id_seconds_linethin_in,	// SECONDFONT_LINETHIN_IN
			fonts.id_seconds_circular_in,	// SECONDFONT_CIRCULAR_IN
			fonts.id_seconds_circularthin_in,	// SECONDFONT_CIRCULARTHIN_IN
		];

	 	//if (forceTestFont)
	 	//{
	 	//	propTimeHourFont = 1/*APPFONT_EXTRA_LIGHT*/;
	 	//	propTimeMinuteFont = 1/*APPFONT_EXTRA_LIGHT*/;
	 	//	//propTimeHourFont = 3/*APPFONT_REGULAR*/;
	 	//	//propTimeMinuteFont = 3/*APPFONT_REGULAR*/;
	 	//	//propTimeHourFont = 4/*APPFONT_BOLD*/;
	 	//	//propTimeMinuteFont = 4/*APPFONT_BOLD*/;
	 	//	propTimeItalic = false;
		//}
		
		// field font	
		if (propFieldFont < 24/*APPFONT_SYSTEM_XTINY*/)		// custom fonts
		{
			fontFieldResource = watchUi.loadResource(fontLoad[propFieldFont]);
		}
		else											// system fonts
		{ 
		   	fontFieldResource = fontSystem[propFieldFont - 24/*APPFONT_SYSTEM_XTINY*/];
		}

		// hour font		 	
		if (propTimeHourFont < 24/*APPFONT_SYSTEM_XTINY*/)		// custom fonts
		{
			fontTimeHourResource = watchUi.loadResource(propTimeItalic ? fontLoadItalic[propTimeHourFont] : fontLoad[propTimeHourFont]);
		}
		else												// system fonts
		{ 
	    	fontTimeHourResource = fontSystem[propTimeHourFont - 24/*APPFONT_SYSTEM_XTINY*/];
		}

		// minute font			
		if (propTimeMinuteFont < 24/*APPFONT_SYSTEM_XTINY*/)		// custom fonts
		{
			fontTimeMinuteResource = watchUi.loadResource(propTimeItalic ? fontLoadItalic[propTimeMinuteFont] : fontLoad[propTimeMinuteFont]);
		}
		else												// system fonts
		{ 
		   	fontTimeMinuteResource = fontSystem[propTimeMinuteFont - 24/*APPFONT_SYSTEM_XTINY*/];
		}
			
   		propSecondFontResource = watchUi.loadResource(secondFontLoad[propSecondIndicatorStyle]);
			
		fontFieldUnsupportedResource = ((propFieldFontUnsupported>=24/*APPFONT_SYSTEM_XTINY*/ && propFieldFontUnsupported<=28/*APPFONT_SYSTEM_LARGE*/) ? fontSystem[propFieldFontUnsupported-24/*APPFONT_SYSTEM_XTINY*/] : fontSystem[25/*APPFONT_SYSTEM_TINY*/-24/*APPFONT_SYSTEM_XTINY*/]); 
    }
    
    //function printMem(s)
    //{
    //	var stats = System.getSystemStats();
	//	System.println("free=" + stats.freeMemory + " " + s);
    //}
    
    // Update the view
    function onUpdate(dc)
    {
		//System.println("onUpdate");
    
        var clockTime = System.getClockTime();	// get as first thing so we know it is correct and won't change later on
		var timeNow = Time.now();
		var profileToActivate;
		var demoSettingsChanged;
		var doGetPropertiesAndDynamicResources = false;
		var forceDemoSettingsChange = false;
				
        //View.onUpdate(dc);        // Call the parent onUpdate function to redraw the layout

        //if (clockTime.min == updateLastMin && clockTime.sec == updateLastSec)
        //{
        //	//System.println("multiple onUpdate");
        //	return;
        //}
		//
		//if ((onOrGlanceActive&ITEM_ONGLANCE)==0)		// if not during glance
		//{        
	    //    updateLastSec = clockTime.sec;
	    //    updateLastMin = clockTime.min;
	    //}
	    
		//System.println("update rest sec=" + clockTime.sec);

		if (settingsHaveChanged || firstUpdateSinceInitialize)
		{
			profileRandomLastMin = clockTime.min;	// don't do a random profile change on first minute (after initialize or settings change)

			releaseDynamicResources();						// also done in onSettingsChanged()
			doGetPropertiesAndDynamicResources = true;
			forceDemoSettingsChange = true;
			
			handleSettingsChanged(clockTime, timeNow);		// save/load/export/import etc

			settingsHaveChanged = false;			// clear the flag now as it has been handled (do after handleSettingsChanged)
			firstUpdateSinceInitialize = false;		// and make sure this is cleared now also
		}
					
		profileToActivate = checkProfileToActivate(clockTime, timeNow);
		if (profileToActivate != profileActive)
		{
			releaseDynamicResources();
			doGetPropertiesAndDynamicResources = true;
			forceDemoSettingsChange = true;
			
			clearExportImportStrings();				// clear the export/import strings before load (won't match properties or watch display after load anyway) 
			loadProfile(profileToActivate);			// will set profileActive
			getOrSetPropFieldDataProperties();
			profileGlance = doActivateGlanceCheck;		// set this after loadProfile, so it gets remembered
		}

    	demoSettingsChanged = checkDemoSettings(clockTime.hour*60 + clockTime.min, forceDemoSettingsChange);
    	if (demoSettingsChanged)
    	{
			releaseDynamicResources();
			doGetPropertiesAndDynamicResources = true;
		}

        if (doGetPropertiesAndDynamicResources)
        {
   			getGlobalProperties();
   			
			loadDynamicResources();
        }
        
        //System.println("onUpdate sec=" + clockTime.sec);

	    //dc.drawBitmap(0, 0, worldBitmap);

		// test draw a circle
        //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        //dc.drawText(0, -1, circleFont, "0", Graphics.TEXT_JUSTIFY_LEFT);
        
		// test draw a ring
        //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        //dc.drawText(120, 120+75, ringFont, "0", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

        // test draw an icon
        //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        //dc.drawText(60, 120 - 64 - 12, iconsFontResource, "A", Graphics.TEXT_JUSTIFY_CENTER);
        //dc.drawText(120, 120 + 64 - 12, iconsFontResource, "AAAAAAAA", Graphics.TEXT_JUSTIFY_CENTER);

		// test drawing a circle 
   		//dc.setColor(Graphics.COLOR_WHITE, backgroundColor);
		//dc.setPenWidth(4);		  
		//dc.drawCircle(120, 120 + 74, 25);		  

        var deviceSettings = System.getDeviceSettings();		// 960 bytes, but uses less code memory
		var activityMonitorInfo = ActivityMonitor.getInfo();  	// 560 bytes, but uses less code memory
		var systemStats = System.getSystemStats();				// 168 bytes, but uses less code memory
        var firstDayOfWeek = deviceSettings.firstDayOfWeek;
		var gregorian = Time.Gregorian;
		var dateInfoShort = gregorian.info(timeNow, Time.FORMAT_SHORT);
		var dateInfoMedium = gregorian.info(timeNow, Time.FORMAT_MEDIUM);
                
        // Get the current time and format it correctly       
        var hour = clockTime.hour;
        if (deviceSettings.is24Hour)		// 24 hours - test if military is needed
        {
            if (propertiesGetBoolean("3"))		// time military on
            {
                hour = hour.format("%02d");
            }
        }
        else        	// 12 hours
        {
            hour += ((hour > 12) ? -12 : 0);
        }
        
        var minuteString = clockTime.min.format("%02d");
        var hourString = "" + hour;

		// calculate main time display
		if ((propTimeOn & onOrGlanceActive)!=0 && !propDemoDisplayOn)
        {
			backgroundTimeCharArrayMinuteStart = addStringToCharArray(hourString, backgroundTimeCharArray, 0, 4);
			backgroundTimeCharArrayLength = addStringToCharArray(minuteString, backgroundTimeCharArray, backgroundTimeCharArrayMinuteStart, 4);
			
			backgroundTimeTotalWidth = 0;
			backgroundTimeXOffset = (propTimeItalic ? 1 : 0);

	        for (var i=0; i<backgroundTimeCharArrayLength; i++)
	        {
	        	var w = dc.getTextWidthInPixels(backgroundTimeCharArray[i].toString(), ((i<backgroundTimeCharArrayMinuteStart) ? fontTimeHourResource : fontTimeMinuteResource));

				// make sure both fonts are our custom ones
				if (propTimeHourFont<=5/*APPFONT_HEAVY*/ && propTimeMinuteFont<=5/*APPFONT_HEAVY*/)
				{
					var curNum = backgroundTimeCharArray[i].toNumber() - 48/*APPCHAR_0*/;

	    			if (i < backgroundTimeCharArrayLength-1)
	    			{
						var nextNum = backgroundTimeCharArray[i+1].toNumber() - 48/*APPCHAR_0*/;
						var appFontCur = ((i<backgroundTimeCharArrayMinuteStart) ? propTimeHourFont : propTimeMinuteFont);
						var appFontNext = ((i<(backgroundTimeCharArrayMinuteStart-1)) ? propTimeHourFont : propTimeMinuteFont);
						
						w -= getKern(curNum, nextNum, appFontCur, appFontNext);
				    }
				    else
				    {
				    	// last digit - if it's a 4 then shift whole number right a bit
				    	if (curNum==4)
				    	{
				    		backgroundTimeXOffset += 1;
				    	}
				    }
				}
							    
		       	backgroundTimeWidthArray[i] = w;
	        	backgroundTimeTotalWidth += w;
			}
		}

		// calculate fields to display
		var visibilityStatus = new[17/*STATUS_NUM*/];
		visibilityStatus[0/*STATUS_ALWAYSON*/] = true;
	    visibilityStatus[1/*STATUS_DONOTDISTURB_ON*/] = (hasDoNotDisturb && deviceSettings.doNotDisturb);
	    visibilityStatus[2/*STATUS_DONOTDISTURB_OFF*/] = (hasDoNotDisturb && !deviceSettings.doNotDisturb);
	    var alarmCount = deviceSettings.alarmCount;
	    visibilityStatus[3/*STATUS_ALARM_ON*/] = (alarmCount > 0);
	    visibilityStatus[4/*STATUS_ALARM_OFF*/] = (alarmCount == 0);
	    var notificationCount = deviceSettings.notificationCount;
	    visibilityStatus[5/*STATUS_NOTIFICATIONS_PENDING*/] = (notificationCount > 0);
	    visibilityStatus[6/*STATUS_NOTIFICATIONS_NONE*/] = (notificationCount == 0);
	    var phoneConnected = deviceSettings.phoneConnected;
	    visibilityStatus[7/*STATUS_PHONE_CONNECTED*/] = phoneConnected;
	    visibilityStatus[8/*STATUS_PHONE_NOT*/] = !phoneConnected;
	    var lteState = lteConnected();
	    visibilityStatus[9/*STATUS_LTE_CONNECTED*/] = (hasLTE && lteState);
	    visibilityStatus[10/*STATUS_LTE_NOT*/] = (hasLTE && !lteState);
	    var batteryLevel = systemStats.battery;
	    var batteryHighPercentage = propertiesGetNumber("30");
	    var batteryLowPercentage = propertiesGetNumber("31");
	    visibilityStatus[12/*STATUS_BATTERY_HIGH*/] = (batteryLevel>=batteryHighPercentage);
	    visibilityStatus[14/*STATUS_BATTERY_LOW*/] = (!visibilityStatus[12/*STATUS_BATTERY_HIGH*/] && batteryLevel<=batteryLowPercentage);
	    visibilityStatus[13/*STATUS_BATTERY_MEDIUM*/] = (!visibilityStatus[12/*STATUS_BATTERY_HIGH*/] && !visibilityStatus[14/*STATUS_BATTERY_LOW*/]);
	    visibilityStatus[11/*STATUS_BATTERY_HIGHORMEDIUM*/] = !visibilityStatus[14/*STATUS_BATTERY_LOW*/];
		// moveBarLevel 0 = not triggered
		// moveBarLevel has range 1 to 5
		// propFieldMoveAlarmTriggerTime has range 1 to 5
		var activityTrackingOn = deviceSettings.activityTrackingOn;
	    var moveBarAlertTriggered = (activityMonitorInfo.moveBarLevel >= propertiesGetNumber("29")); 
	    visibilityStatus[15/*STATUS_MOVEBARALERT_TRIGGERED*/] = (activityTrackingOn && moveBarAlertTriggered);
	    visibilityStatus[16/*STATUS_MOVEBARALERT_NOT*/] = (activityTrackingOn && !moveBarAlertTriggered);

		fieldActivePhoneStatus = null;
		fieldActiveNotificationsStatus = null;
		fieldActiveNotificationsCount = null;
		fieldActiveLTEStatus = null;

		var fontSystemCase = propertiesGetNumber("26");		// get case for system fonts 
		
    	for (var f=0; f<FIELD_NUM; f++)
    	{
    		var dataStart = f*FIELD_NUM_PROPERTIES;
    		var fJustification = propFieldData[dataStart + 2/*FIELD_INDEX_JUSTIFICATION*/];
			if (((fJustification%FIELD_MANAGEMENT_MODULO) & onOrGlanceActive)!=0 && !propDemoDisplayOn)
			{
				backgroundFieldInfoIndex[f] = f*FIELD_NUM_ELEMENTS_DRAW;	// index into backgroundFieldInfo arrays
				backgroundFieldInfoCharArrayLength[f] = f*FIELD_INFO_CHAR_MAX_LEN;
				backgroundFieldTotalWidth[f] = 0;

				var fieldInfoIndexEnd = backgroundFieldInfoIndex[f] + FIELD_NUM_ELEMENTS_DRAW; 

				var moveBarNum = 0;

				for (var i=0; i<FIELD_NUM_ELEMENTS; i++)
				{
					var elementStart = dataStart + 3/*FIELD_INDEX_ELEMENTS*/ + i*3;
					var eDisplay = propFieldData[elementStart];
					var eVisible = propFieldData[elementStart + 1];

					// don't need to test >=0 as it's a byte array
					if (eDisplay!=0/*FIELD_EMPTY*/ && /*eVisible>=0 &&*/ eVisible<17/*STATUS_NUM*/)
					{
						if (eVisible==5/*STATUS_NOTIFICATIONS_PENDING*/ || eVisible==6/*STATUS_NOTIFICATIONS_NONE*/)
						{
							fieldActiveNotificationsStatus = (notificationCount > 0);
						} 
						if (eVisible==7/*STATUS_PHONE_CONNECTED*/ || eVisible==8/*STATUS_PHONE_NOT*/)
						{
							fieldActivePhoneStatus = phoneConnected;
						} 
						if (eVisible==9/*STATUS_LTE_CONNECTED*/ || eVisible==10/*STATUS_LTE_NOT*/)
						{
							fieldActiveLTEStatus = lteState;
						} 

 						if (visibilityStatus[eVisible])		// only test this after calculating the filedActiveXXXStatus flags
						{ 
							var eColor = getColorArray(propFieldData[elementStart + 2]);

	 						var eStr = null;		// null means empty if nothing below sets it
							var eIsIcon = false;
							var eUseUnsupportedFont = false;
		
							//if (e==FIELD_EMPTY)			// empty
						    //{
						    //	eStr = null;
							//}
							//else
						    if (eDisplay>=21/*FIELD_SEPARATOR_SPACE*/ && eDisplay<=28/*FIELD_SEPARATOR_PERCENT*/)
						    {
								var separatorString = " /\\:-.,%";
			        			eStr = separatorString.substring(eDisplay-21/*FIELD_SEPARATOR_SPACE*/, eDisplay-21/*FIELD_SEPARATOR_SPACE*/+1);
						    }
						    else if (eDisplay>=41/*FIELD_SHAPE_CIRCLE*/ && eDisplay<=64/*FIELD_SHAPE_STAIRS*/)
						    {			    	
								//var iconsString = "ABCDEFGHIJKLMNOPQRSTUVWX";
								//eStr = iconsString.substring(e-FIELD_SHAPE_CIRCLE, e-FIELD_SHAPE_CIRCLE+1);
								//var charArray = [(e - FIELD_SHAPE_CIRCLE + ICONS_FIRST_CHAR_ID).toChar()];
								//eStr = StringUtil.charArrayToString(charArray);
								//var charArray = [(e - FIELD_SHAPE_CIRCLE + ICONS_FIRST_CHAR_ID).toChar()];
								eStr = (eDisplay - 41/*FIELD_SHAPE_CIRCLE*/ + 65/*ICONS_FIRST_CHAR_ID*/).toChar().toString();
						    	eIsIcon = true;
						    }
							else
							{
								switch(eDisplay)
								{
									case 1/*FIELD_HOUR*/:			// hour
								    {
										eStr = hourString;
										break;
									}
				
									case 2/*FIELD_MINUTE*/:			// minute
								    {
										eStr = minuteString;
										break;
									}
				
									case 3/*FIELD_DAY_NAME*/:		// day name
									case 9/*FIELD_MONTH_NAME*/:		// month name
								    {
										eStr = ((eDisplay==3/*FIELD_DAY_NAME*/) ? dateInfoMedium.day_of_week : dateInfoMedium.month);
			
										//eStr = "0\u0158\u015a\u00c7\u0179\u0104";		// test string for diacritics & bounding rectangle (use system large)
										//eStr = "A\u042d\u03b8\u05e9\u069b";			// test string for other languages
			
										if (propFieldFont < 24/*APPFONT_SYSTEM_XTINY*/)		// custom font
										{ 
											var tempStr = eStr.toUpper();				// custom fonts always upper case
											eUseUnsupportedFont = useUnsupportedFieldFont(tempStr);
											if (eUseUnsupportedFont)
											{
												// will be using system font - so use case for that as specified by user
												if (fontSystemCase==1)	// APPCASE_UPPER = 1
												{
													eStr = tempStr;
												}
												else if (fontSystemCase==2)	// APPCASE_LOWER = 2
												{
													eStr = eStr.toLower();
												}
												//else
												//{
												//	eStr = eStr;	// keep case as is
												//}
											}
											else
											{
												eStr = tempStr;		// ok to use
											}
										}
										else
										{
											if (fontSystemCase==1)	// APPCASE_UPPER = 1
											{
												eStr = eStr.toUpper();
											}
											else if (fontSystemCase==2)	// APPCASE_LOWER = 2
											{
												eStr = eStr.toLower();
											}
										}
										break;
									}
				
									case 4/*FIELD_DAY_OF_WEEK*/:			// day number of week
								    {
										eStr = "" + (((dateInfoShort.day_of_week - firstDayOfWeek + 7) % 7) + 1);	// 1-7
										break;
									}
				
									case 5/*FIELD_DAY_OF_MONTH*/:			// day number of month
								    {
										eStr = "" + dateInfoMedium.day;
										break;
									}
				
									case 6/*FIELD_DAY_OF_MONTH_XX*/:			// day number of month XX
								    {
										eStr = dateInfoMedium.day.format("%02d");
										break;
									}
				
									case 7/*FIELD_DAY_OF_YEAR*/:				// day number of year
									case 8/*FIELD_DAY_OF_YEAR_XXX*/:			// day number of year XXX
									{
										calculateDayWeekYearData(0, firstDayOfWeek, dateInfoMedium);
			
			    						eStr = dayOfYear.format((eDisplay == 7/*FIELD_DAY_OF_YEAR*/) ? "%d" : "%03d");        					
			        					break;
			        				}
			
									case 10/*FIELD_MONTH_OF_YEAR*/:		// month number of year
								    {
										eStr = "" + dateInfoShort.month;
										break;
									}
				
									case 11/*FIELD_MONTH_OF_YEAR_XX*/:			// month number of year XX
								    {
										eStr = dateInfoShort.month.format("%02d");
										break;
									}
				
									case 12/*FIELD_YEAR_XX*/:		// year XX
									{
										eStr = (dateInfoMedium.year % 100).format("%02d");
										break;
									}
				
									case 13/*FIELD_YEAR_XXXX*/:		// year XXXX
								    {
										eStr = "" + dateInfoMedium.year;
										break;
									}
			
									case 14/*FIELD_WEEK_ISO_XX*/:			// week number of year XX
									case 15/*FIELD_WEEK_ISO_WXX*/:		// week number of year WXX
									case 16/*FIELD_YEAR_ISO_WEEK_XXXX*/:
									{
										calculateDayWeekYearData(1, firstDayOfWeek, dateInfoMedium);							
									
										if (eDisplay == 16/*FIELD_YEAR_ISO_WEEK_XXXX*/)
										{
				        					eStr = "" + ISOYear;
										}
										else
										{
				        					eStr = ((eDisplay == 14/*FIELD_WEEK_ISO_XX*/) ? "" : "W") + ISOWeek.format("%02d");
				        				}
			    						break;
									}
				
									case 17/*FIELD_WEEK_CALENDAR_XX*/:			// week number of year XX
									case 18/*FIELD_YEAR_CALENDAR_WEEK_XXXX*/:
									{
										calculateDayWeekYearData(2, firstDayOfWeek, dateInfoMedium);							
									    eStr = ((eDisplay==17/*FIELD_WEEK_CALENDAR_XX*/) ? CalendarWeek.format("%02d") : "" + CalendarYear);
										break;
									}
				
									case 31/*FIELD_STEPSCOUNT*/:
									{
										eStr = "" + activityMonitorInfo.steps;
										break;
									}
			
									case 32/*FIELD_STEPSGOAL*/:
									{
										eStr = "" + activityMonitorInfo.stepGoal;
										break;
									}
			
									case 33/*FIELD_FLOORSCOUNT*/:
									{
										eStr = "" + activityMonitorInfo.floorsClimbed;
										break;
									}
			
									case 34/*FIELD_FLOORSGOAL*/:
									{
										eStr = "" + activityMonitorInfo.floorsClimbedGoal;
										break;
									}
			
									case 35/*FIELD_NOTIFICATIONSCOUNT*/:
									{
										fieldActiveNotificationsCount = deviceSettings.notificationCount; 
										eStr = "" + fieldActiveNotificationsCount;
										break;
									}
									
									case 36/*FIELD_BATTERYPERCENTAGE*/:
									{
										eStr = "" + systemStats.battery.toNumber();
										break;
									}
									
									case 37/*FIELD_MOVEBAR*/:
									{
										// check how many in rest of field
										// and if next element is a movebar for kerning
										var numToAdd = 5;
										var nextIsMoveBar = -1;
										for (var j=i+1; j<FIELD_NUM_ELEMENTS; j++)
										{
											var jStart = dataStart + 3/*FIELD_INDEX_ELEMENTS*/ + j*3;
											var jDisplay = propFieldData[jStart];
											var jVisible = propFieldData[jStart + 1];
											// don't need to test >=0 as it's a byte array
											if (jDisplay!=0/*FIELD_EMPTY*/ && /*jVisible>=0 &&*/ jVisible<17/*STATUS_NUM*/ && visibilityStatus[jVisible])
											{
												if (jDisplay==37/*FIELD_MOVEBAR*/)
												{
													numToAdd--;
													
													if (nextIsMoveBar<0)	// not set yet
													{
														nextIsMoveBar = 1;		// true
													}
												}
												else
												{
													if (nextIsMoveBar<0)	// not set yet
													{
														nextIsMoveBar = 0;		// false
													}
												}
											}
										}
										
										if (moveBarNum!=0)	// first in this field so need to add some extra ones
										{
											numToAdd = 1;
										}
										
				    					var offColor = propertiesGetColor("28");
				    					if (offColor==COLOR_NOTSET)
				    					{
				    						offColor = eColor;
				    					}
										
										for (var j=0; j<numToAdd; j++)
										{
											moveBarNum++;
			
											// moveBarLevel 0 = not triggered
											// moveBarLevel has range 1 to 5
											// moveBarNum goes from 1 to 5
											var barIsOn = (moveBarNum <= activityMonitorInfo.moveBarLevel);
											var eKern = ((j<numToAdd-1 || nextIsMoveBar==1) ? -5 : 0);
											addBackgroundField(dc, f, fieldInfoIndexEnd, (barIsOn ? "Z" : "Y"), true, false, (barIsOn ? eColor : offColor), eKern);
										}
										
										// leave eStr as null so doesn't get added again below
										// eStr = null;
										
										break;
									}
			   					}
							}
							
							if (eStr != null)
							{
								addBackgroundField(dc, f, fieldInfoIndexEnd, eStr, eIsIcon, eUseUnsupportedFont, eColor, 0);
							}
						}
					}
				}
			}
		}

		// calculate outer ring data
		if ((propOuterOn & onOrGlanceActive)!=0)		// outer ring on
		{
			backgroundOuterFillStart = -1;

			var outerMode = propertiesGetNumber("21");
	
			if (outerMode==1 && activityMonitorInfo.stepGoal>0)		// steps
			{
				var steps = activityMonitorInfo.steps;
				var stepGoal = activityMonitorInfo.stepGoal;
				
				backgroundOuterFillEnd = (120 * steps) / stepGoal - 1;
				if (backgroundOuterFillEnd>=120)
				{
					backgroundOuterFillEnd++;	// add that 1 back on again so multiples of stepGoal correctly align at start 
					
					// once past steps goal then use a different style - draw just two unfilled blocks moving around
					var multiple = steps / stepGoal;
					backgroundOuterFillStart = (backgroundOuterFillEnd+2*multiple)%120;
					backgroundOuterFillEnd = (backgroundOuterFillEnd+119)%120;	// same as -1
				}
			}
			else if (outerMode==2)			// minutes
			{
	    		backgroundOuterFillEnd = (clockTime.min * 2) - 1;
			}
			else if (outerMode==3)			// hours
			{
		        if (deviceSettings.is24Hour)
		        {
	        		//backgroundOuterFillEnd = ((clockTime.hour*60 + clockTime.min) * 120) / (24 * 60);
	        		backgroundOuterFillEnd = (clockTime.hour*60 + clockTime.min) / 12 - 1;
		        }
		        else        	// 12 hours
		        {
	        		backgroundOuterFillEnd = ((clockTime.hour%12)*60 + clockTime.min) / 6 - 1;
		        }
	   		}
	   		else if (outerMode==4)			// battery percentage
	   		{
				backgroundOuterFillEnd = (systemStats.battery * 120).toNumber() / 100 - 1;
	   		}
			else		// plain color
			{
				backgroundOuterFillEnd = 119;
			}
		}
		
		// draw the background to main display
        drawBackgroundToDc(dc);

        lastPartialUpdateSec = clockTime.sec;
		bufferIndex = -1;		// clear any background buffer being known

		// draw the seconds indicator to the screen
		if ((propSecondIndicatorOn & onOrGlanceActive)!=0)
		{
        	if (propSecondRefreshStyle==0/*REFRESH_EVERY_SECOND*/)
        	{
    			drawSecond(dc, clockTime.sec, clockTime.sec);
    		}
    		else if ((propSecondRefreshStyle==1/*REFRESH_EVERY_MINUTE*/) ||
    			(propSecondRefreshStyle==2/*REFRESH_ALTERNATE_MINUTES*/ && (clockTime.min%2)==0))
    		{
    			// draw all the seconds up to this point in the minute
   				drawSecond(dc, 0, clockTime.sec);
    		}
    		else if (propSecondRefreshStyle==2/*REFRESH_ALTERNATE_MINUTES*/ && (clockTime.min%2)==1)
			{
				// always draw indicator at 0 in this mode
				// (it covers up frame slowdown when drawing all the rest of the seconds coming next ...)
   				drawSecond(dc, 0, 0);

    			// draw all the seconds after this point in the minute
   				drawSecond(dc, clockTime.sec+1, 59);
    		}
		}
    }

	function addBackgroundField(dc, f, fieldInfoIndexEnd, eStr, eIsIcon, eUseUnsupportedFont, eColor, eKern)
	{
		// add the background field info (precalculate stuff so don't need to do it for the offscreen buffer)
		var fieldInfoIndex = backgroundFieldInfoIndex[f];
		if (fieldInfoIndex < fieldInfoIndexEnd)
		{
			var sLen = backgroundFieldInfoCharArrayLength[f];
			var eLen = addStringToCharArray(eStr, backgroundFieldInfoCharArray, sLen, (f+1)*FIELD_INFO_CHAR_MAX_LEN);
			if (eLen>sLen)
			{
				backgroundFieldInfoCharArrayLength[f] = eLen;
	
				var width = eKern + dc.getTextWidthInPixels(eStr, (eIsIcon ? iconsFontResource : (eUseUnsupportedFont ? fontFieldUnsupportedResource : fontFieldResource)));
				backgroundFieldInfoData[fieldInfoIndex] = (width | (sLen << 24) | (eLen << 16) | (eIsIcon?0x1000:0x0000) | (eUseUnsupportedFont?0x2000:0x0000));
	
				backgroundFieldInfoColor[fieldInfoIndex] = eColor;
		
				backgroundFieldTotalWidth[f] += width;
				backgroundFieldInfoIndex[f] += 1;		// increase the counter
			}
		}
	}

	function drawBackgroundToDc(useDc)
	{ 
		var graphics = Graphics;
	
		var dcX;
		var dcY;

		var toBuffer = (useDc==null);
		if (toBuffer)	// offscreen buffer
		{
			//if (bufferBitmap==null)
			//{
			//	return;
			//}
		
			useDc = bufferBitmap.getDc();
			dcX = bufferX;
			dcY = bufferY;
		}
		else
		{
			dcX = 0;
			dcY = 0;
		}

		var dcWidth = useDc.getWidth();
		var dcHeight = useDc.getHeight();

    	// reset to the background color
		useDc.clearClip();
	    useDc.setColor(graphics.COLOR_TRANSPARENT, propBackgroundColor);
		// test draw background of offscreen buffer in a different color
		//if (toBuffer)
		//{
	    //	useDc.setColor(graphics.COLOR_TRANSPARENT, getColorArray(4+42+(bufferIndex*4)%12));
		//}
        useDc.clear();
		
		// draw all the fields
    	for (var f=0; f<FIELD_NUM; f++)
    	{
    		var dataStart = f*FIELD_NUM_PROPERTIES;
    		var fJustification = propFieldData[dataStart + 2/*FIELD_INDEX_JUSTIFICATION*/];
			if (((fJustification%FIELD_MANAGEMENT_MODULO) & onOrGlanceActive)!=0 && !propDemoDisplayOn)
			{
				// draw the date        
			    //const SCREEN_CENTRE_X = 120;
			    //const SCREEN_CENTRE_Y = 120;
				var dateYStart = propFieldData[dataStart + 0/*FIELD_INDEX_YOFFSET*/].toNumber();		// field y offset
				var dateXStart = propFieldData[dataStart + 1/*FIELD_INDEX_XOFFSET*/].toNumber();		// field x offset

				fJustification = fJustification/FIELD_MANAGEMENT_MODULO;	// field justification
				if (fJustification==0)		// centre justify
				{
					dateXStart -= backgroundFieldTotalWidth[f]/2;
				}
				else if (fJustification==2)	// right justify
				{
					dateXStart -= backgroundFieldTotalWidth[f];
				}
				//else if (fJustification==1)	// left justify
				//{
		    	//	// ok as is
				//}
		
				var dateX = dateXStart - dcX;
				var dateYOffset = dateYStart - dcY;

				if (dateX<=dcWidth && (dateX+backgroundFieldTotalWidth[f])>=0 && 
						(dateYOffset-23)<=dcHeight && (dateYOffset-23+38)>=0)
				{
					// show where the text bounding box is
				    //useDc.setColor(graphics.COLOR_DK_BLUE, graphics.COLOR_TRANSPARENT);
					//useDc.fillRectangle(dateX, (dateYOffset-23), backgroundFieldTotalWidth[f], 38);

					var fieldInfoIndexStart = f*FIELD_NUM_ELEMENTS_DRAW;
					var fieldInfoIndexEnd = backgroundFieldInfoIndex[f];
					for (var i=fieldInfoIndexStart; i<fieldInfoIndexEnd; i++)
					{
						var w = backgroundFieldInfoData[i];
						var eWidth = (w & 0x0FFF);
						
						if (dateX<=dcWidth && (dateX+eWidth)>=0)	// check element x overlaps buffer
						{ 
							var curFont;
							var dateY = dateYOffset;
							if ((w&0x1000)!=0)		// isIcon
							{
								curFont = iconsFontResource;
								dateY -= 10;
							}
							else if ((w&0x2000)!=0)	// use the system font for unsupported languages
							{
								curFont = fontFieldUnsupportedResource;
								//const fieldYAdjustFontSystem = 6;
								dateY += 6 - graphics.getFontAscent(curFont);
							}
							else
							{
								curFont = fontFieldResource;	// sometimes onPartialUpdate is called between onSettingsChanged and onUpdate - so this resource could be null
								if (curFont!=null)
								{
									// align bottom of text with bottom of icons
									if (propFieldFont<24/*APPFONT_SYSTEM_XTINY*/)		// custom font?
									{
										var fieldYAdjustFontCustom = [
											0,		// APPFONT_ULTRA_LIGHT
											-12,	// APPFONT_ULTRA_LIGHT_TINY
											-16,	// APPFONT_ULTRA_LIGHT_SMALL
											-21,	// APPFONT_ULTRA_LIGHT_MEDIUM
										];
										dateY += fieldYAdjustFontCustom[propFieldFont/6];
									}
									else
									{
										//const fieldYAdjustFontSystem = 6;
										dateY += 6 - graphics.getFontAscent(curFont);
									}
								}						
							}					
			
							if (curFont!=null)
							{
						        useDc.setColor(backgroundFieldInfoColor[i], graphics.COLOR_TRANSPARENT);
	
								var sLen = ((w>>24) & 0xFF);
								var eLen = ((w>>16) & 0xFF);
								var s = StringUtil.charArrayToString(backgroundFieldInfoCharArray.slice(sLen, eLen));
				        		useDc.drawText(dateX, dateY, curFont, s, graphics.TEXT_JUSTIFY_LEFT);
				        	}
						}
								
			        	dateX += eWidth;
					}
				}
			}
		}

		// draw the main time (after / on top of fields)
		if ((propTimeOn & onOrGlanceActive)!=0 && !propDemoDisplayOn)
        {
	        // draw time
		    //const SCREEN_CENTRE_X = 120;
		    //const SCREEN_CENTRE_Y = 120;
			var timeXStart = 120 - backgroundTimeTotalWidth/2 + backgroundTimeXOffset;
			var timeYStart = 120 - propTimeYOffset;
	
			var timeX = timeXStart - dcX;
			var timeYOffset = timeYStart - dcY;
	
			if (timeX<=dcWidth && (timeX+backgroundTimeTotalWidth)>=0 && 
					(timeYOffset-32)<=dcHeight && (timeYOffset-32+64)>=0)
			{
				//System.println("timedraw=" + i);
	
				// show where the text bounding box is
			    //useDc.setColor(graphics.COLOR_DK_BLUE, graphics.COLOR_TRANSPARENT);
				//useDc.fillRectangle(timeX, (timeYOffset-32), backgroundTimeTotalWidth, 64);
		
		        for (var i=0; i<backgroundTimeCharArrayLength; i++)
		        {
					if (timeX<=dcWidth && (timeX+backgroundTimeWidthArray[i])>=0)		// check digit x overlaps buffer
					{
						var beforeMinuteStart = (i<backgroundTimeCharArrayMinuteStart); 
			        	var fontTimeResource = (beforeMinuteStart ? fontTimeHourResource : fontTimeMinuteResource);			// sometimes onPartialUpdate is called between onSettingsChanged and onUpdate - so this resource could be null
			   			var fontTypeCur = (beforeMinuteStart ? propTimeHourFont : propTimeMinuteFont);

						if (fontTimeResource!=null)
						{			   			
							// align bottom of text
							var timeY = timeYOffset;
							if (fontTypeCur<24/*APPFONT_SYSTEM_XTINY*/)		// custom font?
							{
								//const timeYAdjustFontCustom = -32;
								timeY += -32;
							}
							else
							{
								//const timeYAdjustFontSystem = 30;
								timeY += 30 - graphics.getFontAscent(fontTimeResource);	
							}
			
				       		useDc.setColor(beforeMinuteStart ? propTimeHourColor : propTimeMinuteColor, graphics.COLOR_TRANSPARENT);
			        		useDc.drawText(timeX, timeY, fontTimeResource, backgroundTimeCharArray[i].toString(), graphics.TEXT_JUSTIFY_LEFT);
			        	}
					}
							
		        	timeX += backgroundTimeWidthArray[i];
				}
			}
		}

		// draw the outer ring
		if ((propOuterOn & onOrGlanceActive)!=0)		// outer ring on
		{
			// positions of the outerBig segments (from fnt file)
			// y are all adjusted -1 as usual
			var outerBigXY = [118, -2-1, 200, 34-1, 200, 118-1, 118, 200-1, 34, 200-1, -2, 118-1, -2, 34-1, 34, -2-1];

			var jStart;
			var jEnd;
	
			if (!toBuffer)		// main display
			{
				jStart = 0;
				jEnd = 119;		// all segments
			}
			else				// offscreen buffer
			{
				// these arrays contain outer ring segment numbers (0-119) for the offscreen buffer positions
									  		// t2   tr   r1   r2   br   b1   b2   bl   l1   l2   tl   t1
				var outerOffscreenStart = 	[  -2,   7,  19,  28,  37,  49,  58,  67,  79,  88,  97, 109 ];
				var outerOffscreenEnd = 	[   9,  22,  30,  39,  52,  59,  69,  82,  89,  99, 112, 120 ];
			
    			jStart = outerOffscreenStart[bufferIndex];
    			jEnd = outerOffscreenEnd[bufferIndex];
			}
	
			//jStart = 0;	// test draw all
			//jEnd = 119;

			var colFilled = propOuterColorFilled;
			var colUnfilled = propOuterColorUnfilled;
			var fillStart = backgroundOuterFillStart;
			var fillEnd = backgroundOuterFillEnd;
			if (backgroundOuterFillEnd < backgroundOuterFillStart)
			{
				colFilled = propOuterColorUnfilled;
				colUnfilled = propOuterColorFilled;
				fillStart = (backgroundOuterFillEnd+1)%120;		// + 1
				fillEnd = (backgroundOuterFillStart+119)%120;	// - 1
			}

			var xOffset = -dcX - 5/*OUTER_SIZE_HALF*/;
			var yOffset = -dcY - 5/*OUTER_SIZE_HALF*/;
			var curCol = COLOR_NOTSET;
	
			// draw the correct segments
			for (var j=jStart; j<=jEnd; )
			{
				var index = (j+120)%120;	// handle segments <0 and >=120
				
				var indexCol = ((index>=fillStart && index<=fillEnd) ? colFilled : colUnfilled); 

				if (indexCol!=COLOR_NOTSET && curCol!=indexCol)
				{
					curCol = indexCol;
       				useDc.setColor(curCol, graphics.COLOR_TRANSPARENT);
       			}

				// when drawing whole display in onUpdate then do an optimization using 8 large segments
				if (!toBuffer)
				{
					if (index%15==0)	// start of large segment (they each cover 15 small segments)
					{
						// if the whole of large segment is the same color, then we can draw it
						// Otherwise use small segments as normal
						if ((/*index<fillStart &&*/ index+14<fillStart) ||
							(index>=fillStart && index+14<=fillEnd) ||
							(index>fillEnd /*&& index+14>fillEnd*/))
						{
							if (indexCol != COLOR_NOTSET)
							{
								var bigIndex = index/15;
								var bigIndex2 = bigIndex*2;
								//var s = characterString.substring(bigIndex, bigIndex+1);
								//var s = StringUtil.charArrayToString([(bigIndex + OUTER_FIRST_CHAR_ID).toChar()]);
								var s = (bigIndex + 12/*OUTER_FIRST_CHAR_ID*/).toChar().toString();
					        	useDc.drawText(outerBigXY[bigIndex2] - dcX, outerBigXY[bigIndex2 + 1] - dcY, outerBigFontResource, s, graphics.TEXT_JUSTIFY_LEFT);
					        }
					        
				        	j += 15;	// drawn a big segment so advance 15 small ones
							continue;	// skip to next loop so don't draw small segment
						}
					}
				}

				// draw the segment (if a color is set)
				if (indexCol != COLOR_NOTSET)
				{
					//var s = characterString.substring(index, index+1);
					//var s = StringUtil.charArrayToString([(index + OUTER_FIRST_CHAR_ID).toChar()]);
					var s = (index + 12/*OUTER_FIRST_CHAR_ID*/).toChar().toString();
		        	useDc.drawText(xOffset + outerX[index], yOffset + outerY[index], outerFontResource, s, graphics.TEXT_JUSTIFY_LEFT);
		        }
			    
			    j++;	// next segment
			}
		}

		if (propDemoDisplayOn)
		{
		/*
	   		useDc.setColor(propTimeHourColor, graphics.COLOR_TRANSPARENT);
	   		if (fontTimeHourResource!=null)		// sometimes onPartialUpdate is called between onSettingsChanged and onUpdate - so this resource could be null
	   		{
				useDc.drawText(120 - dcX, 120 - 105 - dcY, fontTimeHourResource, "012", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 - 35 - dcY, fontTimeHourResource, "3456", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 + 35 - dcY, fontTimeHourResource, "789:", graphics.TEXT_JUSTIFY_CENTER);
			}
		/**/

		/*
	   		useDc.setColor(propTimeHourColor, graphics.COLOR_TRANSPARENT);
	   		if (fontFieldResource!=null)		// sometimes onPartialUpdate is called between onSettingsChanged and onUpdate - so this resource could be null
	   		{
				useDc.drawText(120 - dcX, 120 - 120 - dcY, fontFieldResource, " I:I1%", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 - 95 - dcY, fontFieldResource, "2345678", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 - 70 - dcY, fontFieldResource, "9-0\\/A.B,CD", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 - 45 - dcY, fontFieldResource, "EFGHIJKLMNO", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 - 20 - dcY, fontFieldResource, "PQRSTUVWXYZ", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 + 10 - dcY, fontFieldResource, "ÁÚÄÅÇÉÌÍÓÖØ", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 + 40 - dcY, fontFieldResource, "ÛÜÝĄČĚĽŁŃ", graphics.TEXT_JUSTIFY_CENTER);
				useDc.drawText(120 - dcX, 120 + 70 - dcY, fontFieldResource, "ŐŘŚŠŹŽ​", graphics.TEXT_JUSTIFY_CENTER);
			}
		/**/
 
 		/**/
 			// draw demo grid of all colors
			for (var i=-3; i<3; i++)
			{
				var y = 120 + i * 20 - dcY;
				if (y<=dcHeight && (y+20)>=0)
				{
					for (var j=-5; j<5; j++)
					{
						var x = 120 + j * 20 - dcX;
						if (x<=dcWidth && (x+20)>=0)
						{
				   			useDc.setColor(getColorArray(4 + (i+3) + (j+5)*6), graphics.COLOR_TRANSPARENT);
							useDc.drawText(x, y, iconsFontResource, "F", graphics.TEXT_JUSTIFY_LEFT);	// solid squares
						}
					}
				}
			}

			// draw demo grid of all shapes & icons
	   		useDc.setColor(propTimeHourColor, graphics.COLOR_TRANSPARENT);

			var x = 120 - dcX;
			var y;
			var iconStrings = ["ACEGIK", "BDFHJL", "NMPOWRS", "QTVXU"];
			var iconOffsets = [60, 80, -80, -100];
				
			for (var i=0; i<4; i++)
			{
				y = 120 + iconOffsets[i] - dcY;
				if (y<=dcHeight && (y+20)>=0)
				{
					useDc.drawText(x, y, iconsFontResource, iconStrings[i], graphics.TEXT_JUSTIFY_CENTER);
				}
			}
		/**/
		}
	}

	function drawBuffer(secondsIndex, dc)
	{
						  	// t2   tr   r1   r2   br   b1   b2   bl   l1   l2   tl   t1
	    var bufferSeconds = [   0,   5,  11,  15,  20,  26,  30,  35,  41,  45,  50,  56 ];
	    
	    var doUpdate = (bufferIndex < 0);	// if no buffer yet
	    
	    if (!doUpdate)
	    {
			// see if need to redraw the offscreen buffer (if clearIndex is outside it)
			var bufferSecondsStart = bufferSeconds[bufferIndex];						// current start of range in offscreen buffer
	    	var bufferNext = (bufferIndex + 1)%bufferSeconds.size();
		    var bufferSecondsNextMinusOne = (bufferSeconds[bufferNext] + 59)%60;		// current end of range in offscreen buffer - do it this way to handle when end is 0

			doUpdate = (secondsIndex<bufferSecondsStart || secondsIndex>bufferSecondsNextMinusOne);		// outside current range
		}

	    if (doUpdate)
	    {
			// find buffer which contains the indicator for specified second
			var useIndex = -1;
			for (var i=bufferSeconds.size()-1; i>=0; i--)
			{
				if (secondsIndex>=bufferSeconds[i])
				{
					useIndex = i;
					break;
				}
			}
			
			if (useIndex>=0)
			{
								  	// t2   tr   r1   r2   br   b1   b2   bl   l1   l2   tl   t1
			    var bufferPosX =    [ 112, 166, 211, 211, 166, 120,  66,  12, -33, -33,  12,  59 ];
			    var bufferPosY =    [ -33,  12,  59, 111, 165, 210, 210, 165, 120,  65,  12, -33 ];
	
				bufferIndex = useIndex;		// set the buffer we are using
				bufferX = bufferPosX[useIndex];
				bufferY = bufferPosY[useIndex];
				
				drawBackgroundToDc(null);
	
				// test draw the offscreen buffer to see what is in it
		    	//dc.setClip(bufferX, bufferY, BUFFER_SIZE, BUFFER_SIZE);
				//dc.drawBitmap(bufferX, bufferY, buffer);
		    	//dc.clearClip();
			}
		}
	}

// timing of onUpdate from onPartialUpdate
//    	onUpdate(dc);
//    	return;
//
// normal
// total = 249000
// execution = 130000
// graphics = 70000
// display = 49920
//
// not drawing background or seconds
// total = 38093
// execution = 38093
// graphics = 0
// display = 0
//
// drawing background (to main dc only), not seconds
// total = 227000 (+189k)
// execution = 115000 (+77k)
// graphics = 61000 (+61k)
// display = 49920
// drawing background (to main dc only), not seconds - now down to:
// total = 176558 (-50k)
// execution = 58943 (-57k)
// graphics = 67695 (+7k)
// display = 49920
//
// drawing background (to main dc only) and all 60 seconds
// total = 309000 (+82k)
// execution = 176000 (+61k)
// graphics = 83000 (+22k)
// display = 49920
//
// drawing background (to main dc only) and all 60 seconds and ring off
// total = 196000 (-113k)
// execution = 106000 (-70k)
// graphics = 39000 (-44k)
// display = 49920
//
// drawing background (to main dc and one buffer) and all 60 seconds and ring off
// total = 201000 (+5k)
// execution = 111000 (+5k)
// graphics = 39000 (+0k)
// display = 49920
//
// drawing background (to main dc and one buffer) and all 60 seconds and ring on again
// total = 325000 (+124k)
// execution = 189000 (+78k)
// graphics = 85000 (+46k)
// display = 49920

    // Handle the partial update event - not called during high power mode (glance active)
    function onPartialUpdate(dc)
    {
    	// check for some status icons changing dynamically
    	{
 			var deviceSettings = System.getDeviceSettings();	// 960 bytes, but uses less code memory
	
	    	var wouldLikeAnUpdate = false;
			wouldLikeAnUpdate = (wouldLikeAnUpdate || (fieldActivePhoneStatus!=null && (fieldActivePhoneStatus != deviceSettings.phoneConnected)));
			wouldLikeAnUpdate = (wouldLikeAnUpdate || (fieldActiveNotificationsStatus!=null && (fieldActiveNotificationsStatus != (deviceSettings.notificationCount > 0))));
			wouldLikeAnUpdate = (wouldLikeAnUpdate || (fieldActiveNotificationsCount!=null && (fieldActiveNotificationsCount != deviceSettings.notificationCount)));
			wouldLikeAnUpdate = (wouldLikeAnUpdate || (fieldActiveLTEStatus!=null && (fieldActiveLTEStatus != lteConnected())));
			
	    	if (wouldLikeAnUpdate)
	    	{
	        	WatchUi.requestUpdate();
	    	}
	    }
    
		if ((propSecondIndicatorOn&ITEM_ON)!=0)
		{ 
        	var clockTime = System.getClockTime();

	 		// it seems as though occasionally onPartialUpdate can skip a second
	 		// so check whether that has happened, and within the same minute since last full update
	 		// - but only for certain refresh styles
    		if ((propSecondRefreshStyle==1/*REFRESH_EVERY_MINUTE*/) || (propSecondRefreshStyle==2/*REFRESH_ALTERNATE_MINUTES*/))
    		{
		 		var prevSec = ((clockTime.sec+59)%60);
		 		if (prevSec<clockTime.sec && prevSec!=lastPartialUpdateSec)	// check earlier second in same minute
		 		{
		 			doPartialUpdateSec(dc, prevSec, clockTime.min);
		 		}
			}

	 		// do the partial update for this current second
	 		doPartialUpdateSec(dc, clockTime.sec, clockTime.min);
	 		lastPartialUpdateSec = clockTime.sec;	// set after calling doPartialUpdateSec
        }
    }

    function doPartialUpdateSec(dc, secondsIndex, minuteIndex)
    {
    	if (secondsIndex>0)		// when secondsIndex is 0 then everything is up to date already (from doUpdate)
    	{		
 			var clearIndex;
	    	if (propSecondRefreshStyle==0/*REFRESH_EVERY_SECOND*/)
	    	{
	        	// Clear the previous second indicator we drew and restore the background
	    		clearIndex = lastPartialUpdateSec;
	    	}
	    	else if (propSecondRefreshStyle==2/*REFRESH_ALTERNATE_MINUTES*/ && (minuteIndex%2)==1)
	    	{
	        	clearIndex = secondsIndex;
			}
			else
			{
				clearIndex = -1;
			}

	        if (clearIndex>=0)
	        {
				drawBuffer(clearIndex, dc);

				// copy from the offscreen buffer over the second indicator
    			setSecondClip(dc, clearIndex);
	    		
	    		//dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_GREEN);	// check the buffer is clearing the whole of clip region
        		//dc.clear();
				
				//if (bufferBitmap==null)
				//{
	    		//	dc.setColor(Graphics.COLOR_TRANSPARENT, propBackgroundColor);
	        	//	dc.clear();
				//}
				//else
				//{
					dc.drawBitmap(bufferX, bufferY, bufferBitmap);
				//}
	       	}

			if (propSecondRefreshStyle==2/*REFRESH_ALTERNATE_MINUTES*/ && (minuteIndex%2)==1)
			{
		        if (clearIndex>=0)
		        {
					// redraw the indicator following the one we just cleared
					// as some of it might have been erased
					// - but need to keep using the clip region we used for the erase above
					var nextIndex = (clearIndex+1)%60; 
					drawSecond(dc, nextIndex, nextIndex);
		
					// in this mode we also always draw the indicator at 0
					// - so check if that needs redrawing too after erasing the indicator at 1
					if (clearIndex==1)
					{
						drawSecond(dc, 0, 0);
					}
				}
			}
			else
			{
    			setSecondClip(dc, secondsIndex);
				drawSecond(dc, secondsIndex, secondsIndex);
			}
		}
    }

    function setSecondClip(dc, index)
    {
    	index += (propSecondMoveInABit ? 60 : 0);
   		dc.setClip(-8/*SECONDS_SIZE_HALF*/ + secondsX[index], -8/*SECONDS_SIZE_HALF*/ + secondsY[index], 8/*SECONDS_SIZE_HALF*/*2, 8/*SECONDS_SIZE_HALF*/*2);
    }

    function drawSecond(dc, startIndex, endIndex)
    {
		if (propSecondFontResource!=null)		// sometimes onPartialUpdate is called between onSettingsChanged and onUpdate - so this resource could be null
		{
	    	var graphics = Graphics;
	    	
	    	var curCol = COLOR_NOTSET;
	   		var xyIndex = startIndex + (propSecondMoveInABit ? 60 : 0);
	    	for (var index=startIndex; index<=endIndex; index++, xyIndex++)
	    	{
				var col = secondsCol[index];
		
		        if (curCol != col)
		        {
		        	curCol = col;
		       		dc.setColor(curCol, graphics.COLOR_TRANSPARENT);	// seconds color
		       	}
		       	//dc.setColor(col, graphics.COLOR_GREEN);
		       	//dc.setColor(getColorArray(4+42+(index*4)%12), graphics.COLOR_TRANSPARENT);
		       	
		       	//var s = characterString.substring(index+9, index+10);
				//var s = StringUtil.charArrayToString([(index + SECONDS_FIRST_CHAR_ID).toChar()]);
				var s = (index + 21/*SECONDS_FIRST_CHAR_ID*/).toChar().toString();
	        	dc.drawText(-8/*SECONDS_SIZE_HALF*/ + secondsX[xyIndex], -8/*SECONDS_SIZE_HALF*/ + secondsY[xyIndex], propSecondFontResource, s, graphics.TEXT_JUSTIFY_LEFT);
			}
		}
    }

	function initProfiles()
	{
       	var storage = applicationStorage;

		// load times from storage
		var sArray = storage.getValue("PT");			// profile times
		var sArraySize = ((sArray!=null) ? sArray.size() : 0);
		for (var i=0; i<PROFILE_NUM_USER*2; i++)
		{
			profileTimes[i] = ((i<sArraySize) ? sArray[i] : 0);
		}

		// and also save out a first version of the private profile to storage (so it is always available later on)
		// Note this would probably get done in onUpdate first time after initialize anyway - but wouldn't if someone changed the profile
		// management property before ever running the watchface.
		if (storage.getValue("P" + PROFILE_PRIVATE_INDEX) == null)
		{
			saveProfile(PROFILE_PRIVATE_INDEX);		// remember current watch settings
		}
   	}
	
	var doActivateGlanceCheck = -1;
	
	function checkProfileToActivate(clockTime, timeNow)
	{
		var doActivate = profileActive;		// stick with current profile until told otherwise
		doActivateGlanceCheck = -1;			// -1 used to clear profileGlance once glance is finished
		
		if ((onOrGlanceActive&ITEM_ONGLANCE)!=0)		// during glance
		{
			if (profileGlance<0)
			{
				var check = propertiesGetNumber("35") - 1;		// 0 (goes to -1) which means none
				if (check>=0 && check<(PROFILE_NUM_USER+PROFILE_NUM_PRESET))
				{
					doActivate = check;
					doActivateGlanceCheck = check;
					profileGlanceReturn = profileActive;	// return to this profile after glance 
				}
			}
			else
			{
				doActivate = profileGlance;		// keep glance profile active until glance ends
				doActivateGlanceCheck = profileGlance;
			}
		}
		else
		{
			if (profileGlance>=0)
			{
				doActivate = profileGlanceReturn; 
			}
		}
		
		var timeNowValue = timeNow.value();
		
		if (doActivateGlanceCheck<0 && timeNowValue>=profileDelayEnd)
		{
			doActivate = PROFILE_PRIVATE_INDEX;		// assume want to be in normal watch settings

			var dateInfoShort = Time.Gregorian.info(timeNow, Time.FORMAT_SHORT);
			var nowDayNumber = (dateInfoShort.day_of_week+5)%7;		// 1=Sun, 2=Mon 3=Tue, etc so convert to 0=Mon, 1=Tue ... 6=Sun
			var prevDayNumber = (nowDayNumber+6)%7;
	        var nowTime = clockTime.hour*60 + clockTime.min;
			var randomNum = 0;
			var randomProfiles = new[PROFILE_NUM_USER];
			var randomEvents = new[PROFILE_NUM_USER];
			var randomEventsTotal = 0;
			
			for (var i=0; i<PROFILE_NUM_USER; i++)
			{
				if (doActivate==PROFILE_PRIVATE_INDEX)	// not found a profile to activate yet
				{
					var t0 = profileTimes[i];
					var startTime = (t0>>PROFILE_START_SHIFT)&PROFILE_START_MASK;
					var endTime = (t0>>PROFILE_END_SHIFT)&PROFILE_END_MASK;
					if (startTime<endTime)		// Note: if 2 times are equal then go for 24 hours (e.g. by default both times are 0)
					{
						if (nowTime>=startTime && nowTime<endTime && (t0&(0x01<<nowDayNumber))!=0)	// current day set?
						{
							doActivate = i;
						}
					}
					else
					{
						// goes over midnight
						if ((nowTime>=startTime && (t0&(0x01<<nowDayNumber))!=0) ||			// current day 
							(nowTime<endTime && (t0&(0x01<<prevDayNumber))!=0))				// previous day
						{
							doActivate = i;
						}
					}
				}

				var t1 = profileTimes[i+PROFILE_NUM_USER];
				var numEvents = (t1&PROFILE_EVENTS_MASK);
				if (numEvents>0)
				{
					randomProfiles[randomNum] = i;
					randomEvents[randomNum] = numEvents;
					randomEventsTotal += numEvents;
					randomNum++;
				}
			}
			
			// doActivate must be PROFILE_PRIVATE_INDEX or in range (0 to PROFILE_NUM_USER-1) when we get here
			if (doActivate==PROFILE_PRIVATE_INDEX || (profileTimes[doActivate]&PROFILE_BLOCK_MASK)==0)
			{
				if (profileRandom>=0)					// random already active
				{
					if (timeNowValue<profileRandomEnd)
					{
						doActivate = profileRandom;		// stick with same random
					}
					else
					{
						profileRandom = -1;				// end current random
					}
				}
				
				if (profileRandom<0 && randomNum>0 && profileRandomLastMin!=clockTime.min)
				{
					profileRandomLastMin = clockTime.min;
				
					var r = Math.rand()%(24*60);		// number of minutes in a day
					if (r < randomEventsTotal)
					{
						r = Math.rand()%randomEventsTotal;
						for (var i=0; i<randomNum; i++)
						{
							var numEvents = randomEvents[i];
							
							r -= numEvents;
							
							if (r < 0)
							{
								var lenMinutes = 3 + Math.rand()%12;		// 3 to 14 minutes
								// scale length depending on how many events per day for this particular random profile
								// minimum of 1 minute long
								// if 9 events a day then roughly 2/3 as long
								// if 18 events a day then roughly 1/2 as long
								// if 36 events a day then roughly 1/3 as long
								// if 72 events a day then roughly 1/5 as long
								// if 144 events a day then roughly 1/9 as long
								// if 216 events a day then roughly 1/13 as long
								lenMinutes = 1 + ((lenMinutes*18 + numEvents/2) / (17 + numEvents));
								
								profileRandom = randomProfiles[i];
								profileRandomEnd = timeNowValue + ((60-clockTime.sec)%60) + lenMinutes*60;
								doActivate = profileRandom;
								
								break;
							}
						}
					}
				}
			}
			else
			{
				profileRandom = -1;
			}

			if (demoProfilesOn /*|| forceDemoProfiles*/)
			{
				if (doActivate!=PROFILE_PRIVATE_INDEX)
				{
					// end current demo profile
					demoProfilesCurrentEnd = 0;
				}
				else
				{
					var n = propertiesGetTwoNumbers("DR");
					n[0] = n[0] - 1;	// convert from user to code index
					n[1] = n[1] - 1;	// convert from user to code index
					if (n[0] < 0)
					{
						n[0] = 0;
					}
					if (n[1] > PROFILE_NUM_USER+PROFILE_NUM_PRESET - 1)
					{
						n[1] = PROFILE_NUM_USER+PROFILE_NUM_PRESET - 1;
					}
					
	       			//System.println("DR=" + n[0] + " " + n[1]);

					if (n[1] >= n[0])
					{
						if (timeNowValue >= demoProfilesCurrentEnd)
						{
							var nextProfile = demoProfilesCurrentProfile + 1;
							if (nextProfile < n[0] || nextProfile > n[1])
							{
								nextProfile = n[0];
							}

							demoProfilesCurrentProfile = nextProfile;
							// if within 1 minute of end time of previous demo profile - then just add 5 minutes to end of previous
							demoProfilesCurrentEnd = ((timeNowValue-demoProfilesCurrentEnd < 60) ? demoProfilesCurrentEnd : (timeNowValue + (60-clockTime.sec)%60)) + 5*60;	// 5 minutes
						}
					
						if (demoProfilesCurrentProfile >= 0)
						{
							doActivate = demoProfilesCurrentProfile; 
						}
					}
				}
			}
		}

		return doActivate;
	}
	
	var parseIndex;
	
   	// find next comma or end of array
	function parseToComma(charArray, charArraySize)
	{	
    	for (; parseIndex<charArraySize; parseIndex++)
    	{
    		if (charArray[parseIndex].toNumber()==44/*APPCHAR_COMMA*/)
    		{
    			break;
    		}
    	}
    }
    	
	function parseNumber(charArray, charArraySize)
	{
		var v = 0;
		var vMult = 1;
	
    	for (; parseIndex<charArraySize; parseIndex++)
    	{
    		var c = charArray[parseIndex].toNumber();
    		if (c>=48/*APPCHAR_0*/ && c<=57/*APPCHAR_9*/)
    		{
    			v = v*10 + (c-48/*APPCHAR_0*/); 
    		}
    		else if (c==45/*APPCHAR_MINUS*/)
    		{
    			vMult = -1;
    		}
    		else
    		{
    			break;
    		}
    	}

		return v*vMult;
	}

	function parseNumberComma(charArray, charArraySize)
	{
		var v = parseNumber(charArray, charArraySize);

		parseToComma(charArray, charArraySize);   	// find next comma or end of array
		parseIndex++;		// step over the comma

		return v;
	}

	function parseBooleanComma(charArray, charArraySize)
	{
		var v = false;
	
		if (parseIndex<charArraySize)
		{	
    		var c = charArray[parseIndex].toNumber();
			v = (c==116/*APPCHAR_t*/ || c==49/*APPCHAR_1*/ || c==84/*APPCHAR_T*/);
				
			parseToComma(charArray, charArraySize);   	// find next comma or end of array
			parseIndex++;		// step over the comma
		}

		return v;
	}

	function parseStringComma(charArray, charArraySize)
	{
		var v = "";
		
		var charStart = parseIndex;
		parseToComma(charArray, charArraySize);   	// find next comma or end of array
		var charEnd = parseIndex;
		parseIndex++;		// step over the comma
		
		if (charEnd > charStart)
		{
			var charMax = charStart+20;		// limit length of strings just in case
			if (charEnd > charMax)
			{
				charEnd = charMax;
			}
			v = StringUtil.charArrayToString(charArray.slice(charStart, charEnd));	
		}

		return v;
	}

	function saveProfile(profileIndex)
	{
		profileActive = profileIndex;		// profile now active
		profileGlance = -1;					// clear glance profile if it was active

		if (profileIndex>=PROFILE_PRIVATE_INDEX && profileIndex<PROFILE_NUM_USER)
		{
        	var storage = applicationStorage;

			// save normal properties
			var pArray = new[PROFILE_NUM_PROPERTIES];
			for (var i=0; i<PROFILE_NUM_PROPERTIES; i++)
			{
				pArray[i] = applicationProperties.getValue("" + i);	// these values are only copied from & to properties, never used directly
			}
			storage.setValue("P" + profileIndex, pArray);
			pArray = null;

			// save field data
			storage.setValue("PF" + profileIndex, propFieldData);	// seems to work ok for byte array

			if (profileIndex!=PROFILE_PRIVATE_INDEX)
			{
				// calculate activate times from properties
				var t0 = 0;
				
				var daysNumber = propertiesGetNumber("PD");
				while (daysNumber>0)
				{
					var d = daysNumber%10;
					daysNumber /= 10;
					
					if (d>=1 && d<=7)
					{
						t0 |= (0x1<<(d-1));					
					}
				}
				
				var startTime = propertiesGetTime("PS");
				var endTime = propertiesGetTime("PE");
				t0 |= (startTime<<PROFILE_START_SHIFT) | (endTime<<PROFILE_END_SHIFT);
				
				if (propertiesGetBoolean("PB"))
				{
					t0 |= PROFILE_BLOCK_MASK;
				}

				var t1 = propertiesGetNumber("PR");
				if (t1<0)
				{
					t1 = 0;
				}
				else if (t1>PROFILE_EVENTS_MASK)
				{
					t1 = PROFILE_EVENTS_MASK;
				}

				// remember the profile time
				profileTimes[profileIndex] = t0;
				profileTimes[profileIndex+PROFILE_NUM_USER] = t1;

				// and save all profile times to storage
				storage.setValue("PT", profileTimes);
			}
		}
	}

	function loadProperties(profileIndex, propertiesOrFields)
	{
		var pArray = applicationStorage.getValue((propertiesOrFields ? "P" : "PF") + profileIndex);
		if (pArray != null)
		{
			var size = (propertiesOrFields ? PROFILE_NUM_PROPERTIES : (FIELD_NUM*FIELD_NUM_PROPERTIES));
			if (pArray.size() < size)
			{
				size = pArray.size();
			}

			for (var i=0; i<size; i++)
			{
				if (propertiesOrFields)
				{
					applicationProperties.setValue("" + i, pArray[i]);
				}
				else
				{
					// ok not to check byte value range as loading from byte array (user profile)
					propFieldData[i] = pArray[i];
				}
			}
		}
	}

	function loadProfile(profileIndex)
	{
		profileActive = profileIndex;		// profile now active
		profileGlance = -1;					// clear glance profile if it was active

		if (profileIndex>=PROFILE_PRIVATE_INDEX && profileIndex<(PROFILE_NUM_USER+PROFILE_NUM_PRESET))
		{
			loadProperties(profileIndex, true);
			loadProperties(profileIndex, false);
			
        	var properties = applicationProperties;		// using local variable reduces code size

			properties.setValue("FM", ITEM_RETRIEVE);	// set field management to retrieve - so that properties are updated to match field settings
			
			if (profileIndex>=0 && profileIndex<PROFILE_NUM_USER)	// not for private or preset profiles
			{
				// set the profile properties from our profile times array
				var t0 = profileTimes[profileIndex];
				var t1 = profileTimes[profileIndex+PROFILE_NUM_USER];
				var days = t0&PROFILE_DAYS_MASK;
				var startTime = (t0>>PROFILE_START_SHIFT)&PROFILE_START_MASK;
				var endTime = (t0>>PROFILE_END_SHIFT)&PROFILE_END_MASK;
		
				var daysNumber = 0;
				for (var i=0; i<7; i++)
				{
					if ((days&(0x1<<i))!=0)
					{
						daysNumber *= 10;
						daysNumber += i+1;
					}
				}
				properties.setValue("PD", daysNumber);
		
				properties.setValue("PS", "" + (startTime/60).format("%02d") + ":" + (startTime%60).format("%02d"));
				properties.setValue("PE", "" + (endTime/60).format("%02d") + ":" + (endTime%60).format("%02d"));

				properties.setValue("PB", ((t0&PROFILE_BLOCK_MASK)!=0));
				properties.setValue("PR", (t1&PROFILE_EVENTS_MASK));		
			}
		}
	}

	function exportPropertiesFillCharArray(profileIndex, toArray, toMax)
	{
		var toLen = 0;
		
		var pArray = applicationStorage.getValue("P" + profileIndex);
		if (pArray != null)
		{
			// profile activation times
			var sTimes;
			if (profileIndex<PROFILE_NUM_USER)
			{			
        		sTimes = Lang.format("$1$,$2$,", [profileTimes[profileIndex], profileTimes[profileIndex+PROFILE_NUM_USER]]);
			}
			else
			{
				sTimes = "0,0,";
			}
			toLen = addStringToCharArray(sTimes, toArray, toLen, toMax);
				
			toLen = addArrayToCharArray(pArray, toArray, toLen, toMax);
		}

		return toLen;
	}

	function exportPropertiesGetString(profileIndex)
	{
		var charArray = new[255];
		var charArrayLen = exportPropertiesFillCharArray(profileIndex, charArray, 255);
		charArray = charArray.slice(0, charArrayLen);

		return StringUtil.charArrayToString(charArray);
	}

	function exportFieldDataGetString(fArray, start, end)
	{
		var tempArray = fArray.slice(start, end);
		var charArray = new[255];
		var charArrayLen = addArrayToCharArray(tempArray, charArray, 0, 255);
		tempArray = null;
		
		charArray = charArray.slice(0, charArrayLen);

		return StringUtil.charArrayToString(charArray);
	}
	
	function exportProfile(profileIndex)
	{
		if (profileIndex>=0 && profileIndex<(PROFILE_NUM_USER+PROFILE_NUM_PRESET))
		{
			var s = exportPropertiesGetString(profileIndex);
			applicationProperties.setValue("EP", s);
			s = null;
	
			var fArray = applicationStorage.getValue("PF" + profileIndex);
			
			s = exportFieldDataGetString(fArray, 0, (FIELD_NUM*FIELD_NUM_PROPERTIES)/2);
			applicationProperties.setValue("EF", s);
			s = null;
			
			s = exportFieldDataGetString(fArray, (FIELD_NUM*FIELD_NUM_PROPERTIES)/2, FIELD_NUM*FIELD_NUM_PROPERTIES);
			applicationProperties.setValue("EG", s);
		}
	}

	function importPropertiesFillArray(profileIndex, pArray)
	{
		// main bulk of profile properties
		var charArray = propertiesGetCharArray("EP");
		var charArraySize = charArray.size();
		parseIndex = 0;

		profileTimes[profileIndex] = parseNumberComma(charArray, charArraySize);
		profileTimes[profileIndex+PROFILE_NUM_USER] = parseNumberComma(charArray, charArraySize);
		applicationStorage.setValue("PT", profileTimes);  	// and save all profile times to storage

		var pNum = 0;
		for (; pNum<PROFILE_NUM_PROPERTIES && parseIndex<charArraySize; pNum++)
		{
			if (pNum==0)		// "0" profile name
			{
				pArray[pNum] = parseStringComma(charArray, charArraySize);
			}
			else if (pNum==3 ||	// "3" time military
					pNum==8 || 	// "8" time italic font
					pNum==18 || 	// "18" seconds color demo
					pNum==19 || 	// "19" seconds move in a bit
					pNum==32 || 	// "32" demo font styles
					pNum==33 || 	// "33" demo second styles
					pNum==34)		// "34" demo display
			{
				pArray[pNum] = parseBooleanComma(charArray, charArraySize);
			}
			else
			{
				pArray[pNum] = parseNumberComma(charArray, charArraySize);
			}
		}
		
		return pNum;
	}
			
	function importFieldDataAddToByteArray(fArray, fNum, propertyStr)
	{
		// field data properties
		var charArray = propertiesGetCharArray(propertyStr);
		var charArraySize = charArray.size();
		parseIndex = 0;

		for (; fNum<FIELD_NUM*FIELD_NUM_PROPERTIES && parseIndex<charArraySize; fNum++)
		{
			var v = parseNumberComma(charArray, charArraySize);

			if (v<0)
			{
				v = 0;
			}
			else if (v>255)
			{
				v = 255;
			}

			fArray[fNum] = v; 
		}
				
		return fNum;
	}
	
	function importProfile(profileIndex)
	{
		if (profileIndex>=0 && profileIndex<PROFILE_NUM_USER)
		{
			var pArray = new[PROFILE_NUM_PROPERTIES];
			var pNum = importPropertiesFillArray(profileIndex, pArray);
			pArray = pArray.slice(0, pNum);
			applicationStorage.setValue("P" + profileIndex, pArray);
			pArray = null;

			var fArray = new[FIELD_NUM*FIELD_NUM_PROPERTIES]b;
			var fNum = 0;
			fNum = importFieldDataAddToByteArray(fArray, fNum, "EF");
			fNum = importFieldDataAddToByteArray(fArray, fNum, "EG");
			fArray = fArray.slice(0, fNum);
			applicationStorage.setValue("PF" + profileIndex, fArray);
		}
	}

	var dayWeekYearCalculatedDay = [-1, -1, -1];	// dayOfYear, ISO, Calendar
	var dayOfYear;		// the day number of the year (0-364)
	var ISOWeek;		// in ISO format the first week of the year always includes the first Thursday
	var ISOYear;
	var CalendarWeek;	// in Calendar format the first week of the year always includes 1st Jan
	var CalendarYear;

	function calculateDayWeekYearData(index, firstDayOfWeek, dateInfoMedium)
	{
		var startOfToday = Time.today();
		var startOfTodayValue = startOfToday.value();
		if (startOfTodayValue == dayWeekYearCalculatedDay[index])
		{
			return;
		}

		var gregorian = Time.Gregorian;
	
		var startOfYear = Time.Gregorian.moment({:year => dateInfoMedium.year, :month => 1, :day => 1, :hour => 0, :minute => 0, :second => 0 });
		var durationToStartOfYear = startOfToday.subtract(startOfYear);
		//var secs = duration.value();
		//var mins = secs / 60.0;
		//var hours = mins / 60.0;
		//var days = Math.round(hours / 24.0) + 1;
		var days = Math.round(durationToStartOfYear.value() / 86400.0).toNumber();

		dayWeekYearCalculatedDay[0] = startOfTodayValue;
		dayOfYear = days + 1;
		if (index==0)
		{
			return;
		}
		
		// Garmin numbers days of the week as 1=sun, 2=mon, 3=tue, 4=wed, 5=thu, 6=fri, 7=sat
		//
		// 1st ISO week has the first Thu of the gregorian year in it
		// If first day of week is set to Mon then Jan 1 is in week 1 if Jan 1 is Mon, Tue, Wed, Thu
		// If first day of week is set to Sun then Jan 1 is in week 1 if Jan 1 is Sun, Mon, Tue, Wed, Thu
		// If first day of week is set to Sat then Jan 1 is in week 1 if Jan 1 is Sat, Sun, Mon, Tue, Wed, Thu
	       					
		var dateInfoStartOfYear = gregorian.info(startOfYear, Time.FORMAT_SHORT);
		var numberInWeekOfJan1 = ((dateInfoStartOfYear.day_of_week - firstDayOfWeek + 7) % 7);	// 0-6
		var weeks = (days + numberInWeekOfJan1) / 7;
		var year = dateInfoMedium.year;

		var numberInWeekOfThu = ((gregorian.DAY_THURSDAY - firstDayOfWeek + 7) % 7);	// 0-6
		
		if (index==1)
		{
			if (numberInWeekOfJan1>=0 && numberInWeekOfJan1<=numberInWeekOfThu)
			{
				// jan1 is in week 1 of the year
				weeks += 1;
			}
			//else
			//{
			//	// jan1 is in last week of previous year
			//}
		}
		else
		{
			weeks += 1;
		}

		var checkWeeksLessThan1 = (index==1 && weeks<1);		// only for ISO
		var checkWeeksGreaterThan52 = (weeks>52);

		if (checkWeeksLessThan1)		// check to find last week of previous year
		{
			var prevYear = dateInfoMedium.year-1;
			var startOfPrevYear = gregorian.moment({:year => prevYear, :month => 1, :day => 1, :hour => 0, :minute => 0, :second => 0 });
			var dateInfoStartOfPrevYear = gregorian.info(startOfPrevYear, Time.FORMAT_SHORT);
			var numberInWeekOfJan1PrevYear = ((dateInfoStartOfPrevYear.day_of_week - firstDayOfWeek + 7) % 7);	// 0-6
			
			var durationToJan1PrevYear = startOfToday.subtract(startOfPrevYear);
			var daysToJan1PrevYear = Math.round(durationToJan1PrevYear.value() / 86400.0).toNumber();
			var daysToStartOfWeekYear = daysToJan1PrevYear + numberInWeekOfJan1PrevYear;
			weeks = daysToStartOfWeekYear / 7;
			year = prevYear;

			if (numberInWeekOfJan1PrevYear<=numberInWeekOfThu)
			{
				// jan1 prev year is in week 1 of the year
				weeks += 1;
			}
			//else
			//{
			//	// jan1 prev year is not in week 1 of the year - so our calculated week number is fine
			//}
		}
		else if (checkWeeksGreaterThan52)	// check to see if in first week of next year
		{
			var nextYear = dateInfoMedium.year+1;
			var startOfNextYear = gregorian.moment({:year => nextYear, :month => 1, :day => 1, :hour => 0, :minute => 0, :second => 0 });
			var dateInfoStartOfNextYear = gregorian.info(startOfNextYear, Time.FORMAT_SHORT);
			var numberInWeekOfJan1NextYear = ((dateInfoStartOfNextYear.day_of_week - firstDayOfWeek + 7) % 7);	// 0-6
			
			var checkInFirstWeek;
			
			if (index==1)
			{
				checkInFirstWeek = (numberInWeekOfJan1NextYear<=numberInWeekOfThu);

				//if (numberInWeekOfJan1NextYear<=numberInWeekOfThu)
				//{
				//	// jan1 next year is in week 1 of the year
				//	checkInFirstWeek = true;
				//}
				//else
				//{
				//	// jan1 next year is in last week of previous year - so our calculated week number is fine
				//	checkInFirstWeek = false;
				//}
			}
			else
			{
				checkInFirstWeek = true;
			}

			if (checkInFirstWeek)
			{
				// so see if we are in the same week as jan1 next year
				var durationToJan1NextYear = startOfNextYear.subtract(startOfToday);
				var daysToJan1NextYear = Math.round(durationToJan1NextYear.value() / 86400.0).toNumber();
				if (daysToJan1NextYear <= numberInWeekOfJan1NextYear)
				{
					 weeks = 1;		// in first week of next year
					 year = nextYear;
				}
			}
		}

		dayWeekYearCalculatedDay[index] = startOfTodayValue;
		if (index==1)
		{
			ISOWeek = weeks;
			ISOYear = year;
		}
		else
		{
			CalendarWeek = weeks;
			CalendarYear = year;
		}
	}
}

//class TestDelegate extends WatchUi.WatchFaceDelegate
//{
//    function initialize()
//    {
//        WatchFaceDelegate.initialize();
//    }
//
//    // The onPowerBudgetExceeded callback is called by the system if the
//    // onPartialUpdate method exceeds the allowed power budget. If this occurs,
//    // the system will stop invoking onPartialUpdate each second, so we set the
//    // partialUpdatesAllowed flag here to let the rendering methods know they
//    // should not be rendering a second hand.
//    function onPowerBudgetExceeded(powerInfo)
//    {
//        //System.println("Average execution time: " + powerInfo.executionTimeAverage);
//        //System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
//    }
//}
