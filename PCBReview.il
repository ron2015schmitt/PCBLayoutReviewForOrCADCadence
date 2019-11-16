;###########################################################################
;#                                                                         #
;# sets useful views for reviewign a PCB
;#
;#
;# SIDE EFFECTS
;# - modifies colors 188-192 in the palette
;# - adds 5 text blocks
;###########################################################################

/*
	History:
	0.4 set form defaults for all but fixed text
	0.5 re-wrote ignore fixed code to be like the rest of the code (use globals vars)
	0.6 add display layers to processing
	0.7 handle mirror/no-mirror of bottom layer text
	0.8 started add color selection field
	0.9 remove locked code (always perform)
	0.10 remove mirror bottom checkbox (never mirror)
	0.11 remove junk code and add display priority for all REFDES layers
	0.12 apply color from assembly to other layers and add vicibility vars for each layer
	0.13 add color swatch and processing for bottom layers
	0.14 rename booleans for which layers ot process
	0.15 use own text blocks deinfitions
	0.16 fix centering of text based on height of text used
	0.17 update view at start and after any form change
	0.18 updated GUI for top layer
	0.19 updated bottom layer GUI
	1.0  released with "review" as command name
	1.1  mostly done with V2.0 development
	1.2  implemented rotation of text based on aspect ratio of the bounds
	1.3 set board outline as active layer. don't change visible layers other than ref des layers
	1.4 fixed bug: bounds gets destroyed the second time you run the script. fixed by only deleting text, not all
	1.5 update GUI: separate buttons for copper
	1.6 cteate rgb2HSL and HSL2rgb functions and dim the package boundry layers
	1.7 add code for the bottom layer
	2.0 change command from "r" to "review"
	2.1 fixed - color hue bug
	2.2 relabel pins on top
	2.3 relabel pins on bottom
	2.4 released
	2.5 create new GUI
	2.6 add hue and saturation buttons using objects functions for top copper
	2.7 implemented everything for top copper. added color type and table of colors
	2.8 top layer refs, outline and bounds.  
	2.9 added "Do All" button after refresh. have its own group to sectuion off from others. fixed bugs that caused it to crash durign relabel
	2.10 added bottom layer and pin label functionality
	2.11 fix pin label visibility. simplified code for pin labels.  need to apply to rest. now two functions: initializeFromDatabase and updateView(apply changes from popup)
	2.12 apply new code paradigm to top and bottom colors s well as refdes, outline, bounds
	2.13 grid and custom colors checkboxes.  updated help text and form layout.
	2.14 shadow mode and controls. custom color sahdowing on/off
	2.15 inner layers
	2.17 redo refdes creation
		instead of use package bounds list, get list of all symbols (figure out how to do this)
		use bBox and xy from symbol props
		test with 75G5-X2_1 REVC U33
		fixed bug: Recolor was causing error because pin label color "BrightYellow" didn;t exist
	2.18 list inner layers vertically
	2.19 draw all outlines on package display layers. then use that instead so that we have outline not patches (this helps tremendously for printing out)
	     add these new layer to layer priority list
		only change priority list when clickign "setview"

	TODO:
	recolor of inner layers:
	- display vias and pins of inner layers
	- define a bunch of colors (at least 14 more)
	- implement all the colordefs functions
	- recolor: choose 16-24 colors and then cycle through them if more than max amount
	- implemnt DRC checkbox by looping through all layers
	- set view: include display of assembly notes layer. check that it turns of registration in 68INT board
	- include layers that show ground plane divisions (see MOD-SX2--DS-2CH-2-OUT-LO--REVA, MOD-SX2--DS-3CH-OUT-LO--REVA, MOD-SX2--REF-2CH-OUT-LO--REVC)
	- create View>Colow View Save fiels (perhaps just hard code and write to files)
	-display nets: doesn;t work because there are three variables in Setup window  but only one in programming i/f. set works and controls Clines but get doesn't work.  see cadence reply. open a ticket
	-rats: have to loop through all nets "rats all" 
		axlClearSelSet()
		axlSetFindFilter(?enabled list( "noall" "nets")
		ratsnestOn is attrubute
		name is another attribute


	
	NOTES
	- code indentation is made with tabs (not spaces)
	
*/


;##########################
;#  Register Program Name #
;##########################

axlCmdRegister("r" 'pcbreview)
;axlCmdRegister("review" 'pcbreview)

;#############################
;# MAIN Program Starts Here. #
;#############################

(defun pcbreview ()

	; ==== Initialize Global Variables ====

	vers_major = 2
	vers_minor = 19


	; --------------- Text Style Objects ---------------------- 
	

	axlDBTextBlockCompact(t)
	numUnalteredTextBlocks = axlDBControl('maxTextBlock)

	; define our text blocks structure
	;printf( "txtstyle_t exists: %s\n", symeval( 'txtstyle_t ) )
	if( symeval('txtstyle_t)=='unbound then
		defstruct( txtstyle_t str_name blockNum width photoWidth lineSpace height charSpace )
	)

	; define our text block (ie fonts)
	styleList = list()
	printf(" length=%L \n", length(styleList))
	
	txt_tiny = make_txtstyle_t( ?str_name "tiny" ?blockNum 0 ?width 4.0 ?height 6.0 ?lineSpace 8.0 ?photoWidth 1.0 ?charSpace 0.0 )
	txt_xsmall = make_txtstyle_t( ?str_name "xsmall" ?blockNum 0 ?width 8.0 ?height 10.0 ?lineSpace 15.0 ?photoWidth 2.0 ?charSpace 2.0 )
	txt_small = make_txtstyle_t( ?str_name "small" ?blockNum 0 ?width 15.0 ?height 20.0 ?lineSpace 25.0 ?photoWidth 3.0 ?charSpace 5.0 )
	txt_medium = make_txtstyle_t( ?str_name "medium" ?blockNum 0 ?width 25.0 ?height 32.0 ?lineSpace 63.0 ?photoWidth 4.0 ?charSpace 9.0 )
	txt_large = make_txtstyle_t( ?str_name "large" ?blockNum 0 ?width 38.0 ?height 50.0 ?lineSpace 63.0 ?photoWidth 7.0 ?charSpace 13.0 )
	txt_xlarge = make_txtstyle_t( ?str_name "xlarge" ?blockNum 0 ?width 60.0 ?height 80.0 ?lineSpace 100.0 ?photoWidth 8.0 ?charSpace 20.0)

	sym_savex  = -1
	sym_savey  = -1
	sym_saveparent = nil
	

	;  ----------   color definitions -------------------------------

	if( symeval('colordef_t)=='unbound then
		defstruct( colordef_t label hsl colorFamilies )
	)

	COLORFAMILY_RED = 1
	COLORFAMILY_ORANGE = 2
	COLORFAMILY_YELLOW = 3
	COLORFAMILY_GREEN = 4
	COLORFAMILY_BLUE = 5
	COLORFAMILY_PURPLE = 6
	COLORFAMILY_MAGENTA = 7
	
	; colro names and definitions from here
	;https://en.wikipedia.org/wiki/Web_colors#HTML_color_names
	addColorDef("Red", '( 0.0 1.0 0.5), '(COLORFAMILY_RED))
	addColorDef("BrightOrange", '( 20.125 1.0 0.5), '(COLORFAMILY_ORANGE))
	addColorDef("PureOrange", '( 30.0 1.0 0.5), '(COLORFAMILY_ORANGE))
	addColorDef("Orange", '( 38.82353 1.0 0.5), '(COLORFAMILY_ORANGE))
	addColorDef("Yellow", '( 60.00 1.0 0.5), '(COLORFAMILY_YELLOW))
	addColorDef("YellowGreen", '( 90.00 1.0 0.5), '(COLORFAMILY_YELLOW))
	addColorDef("Chartreuse", '( 90.11765 1.0 0.5), '(COLORFAMILY_YELLOW))
	addColorDef("Lime", '( 120.0 1.0 0.5), '(COLORFAMILY_GREEN))
	addColorDef("SpringGreen", '( 149.8824  1.0 0.5), '(COLORFAMILY_GREEN))
	addColorDef("GreenBlue", '( 150.0 1.0 0.5), '(COLORFAMILY_GREEN))
	addColorDef("Cyan", '( 180.0 1.0 0.5), '(COLORFAMILY_GREEN))
	addColorDef("DeepSkyBlue", '( 195.0588 1.0 0.5), '(COLORFAMILY_BLUE))
	addColorDef("PrimarySchoolBlue", '( 210.0 1.0 0.5), '(COLORFAMILY_BLUE))
	addColorDef("Blue", '( 240.0 1.0 0.5), '(COLORFAMILY_BLUE))
	addColorDef("Purple", '(300.0 1.0 0.25), '(COLORFAMILY_PURPLE))
	addColorDef("Magenta", '( 300.0 1.0 0.5), '(COLORFAMILY_MAGENTA))
	addColorDef("White", '( 0.0 0.0 1.0), '())
	addColorDef("Black", '( 0.0 0.0 0.0), '())
	
	
	; --------------- Layer Objects ---------------------- 
	
	if( symeval('layerObj_t)=='unbound then
		defstruct( layerObj_t label isVisible colorNum defaultHSL defaultColorName layer tiedLayers hasVisibilityField hasColorField)
	)	

	
	nextColorNum = 192
	
	
	; --------- TOP LAYERS -----------
	
	top_etch_layer = "ETCH/TOP"
	top_pin_layer = "PIN/TOP"
	top_via_layer = "VIA CLASS/TOP"
	top_copper = make_layerObj_t( ?label "Top_Copper" ?layer top_etch_layer ?tiedLayers list(top_pin_layer, top_via_layer) ?colorNum nextColorNum ?defaultColorName "Lime" ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1

	; defualt color for top ref des 
	newHSLColor = getColorDefByLabel(top_copper->defaultColorName)->hsl
	newHSLColor = incrLightnessBy(newHSLColor, 0.255)
	newHSLColor = decrHueBy(newHSLColor, 30)

	; we use the display layer for ref des so as to not mess up the gerber files
	top_refdes_disp_layer = "REF DES/DISPLAY_TOP"
	top_refdes_silk_layer = "REF DES/SILKSCREEN_TOP"
	top_refdes_assy_layer = "REF DES/ASSEMBLY_TOP"

	top_refdes_disp = make_layerObj_t( ?label "Top_RefDes_Disp" ?layer top_refdes_disp_layer ?tiedLayers list() ?colorNum nextColorNum  ?defaultHSL newHSLColor ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1	
	top_refdes_silk = make_layerObj_t( ?label "Top_RefDes_Silk" ?layer top_refdes_silk_layer ?tiedLayers list() ?colorNum getLayerColorNum(top_refdes_silk_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)
	top_refdes_assy = make_layerObj_t( ?label "Top_RefDes_Assy" ?layer top_refdes_assy_layer ?tiedLayers list() ?colorNum getLayerColorNum(top_refdes_assy_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)

	; defualt color for top outline 
	newHSLColor = getColorDefByLabel(top_copper->defaultColorName)->hsl
	newHSLColor = decrLightnessBy(newHSLColor, 0.255)

	top_package_outline_disp_layer = "PACKAGE GEOMETRY/DISPLAY_TOP"
	top_package_outline_silk_layer = "PACKAGE GEOMETRY/SILKSCREEN_TOP"
	top_package_outline_assy_layer = "PACKAGE GEOMETRY/ASSEMBLY_TOP"

	top_package_outline_disp = make_layerObj_t( ?label "Top_Outline_Disp" ?layer top_package_outline_disp_layer ?tiedLayers list() ?colorNum nextColorNum  ?defaultHSL newHSLColor ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1	
	top_package_outline_silk = make_layerObj_t( ?label "Top_Outline_Silk" ?layer top_package_outline_silk_layer ?tiedLayers list() ?colorNum getLayerColorNum(top_package_outline_silk_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)
	top_package_outline_assy = make_layerObj_t( ?label "Top_Outline_Assy" ?layer top_package_outline_assy_layer ?tiedLayers list() ?colorNum getLayerColorNum(top_package_outline_assy_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)

	
	; defualt color for top placement bounds
	newHSLColor = getColorDefByLabel(top_copper->defaultColorName)->hsl
	newHSLColor = incrLightnessBy(newHSLColor, 0.255)
	
	top_package_bounds = make_layerObj_t( ?label "Top_Bounds" ?layer "PACKAGE GEOMETRY/PLACE_BOUND_TOP" ?tiedLayers list() ?colorNum nextColorNum  ?defaultHSL newHSLColor ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1	
	

	; --------- BOTTOM LAYERS -----------
	
	bottom_etch_layer = "ETCH/BOTTOM"
	bottom_pin_layer = "PIN/BOTTOM"
	bottom_via_layer = "VIA CLASS/BOTTOM"
	bottom_copper = make_layerObj_t( ?label "Bottom_Copper" ?layer bottom_etch_layer ?tiedLayers list(bottom_pin_layer, bottom_via_layer) ?colorNum nextColorNum  ?defaultColorName "DeepSkyBlue" ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1

	; defualt color for bottom ref des 
	newHSLColor = getColorDefByLabel(bottom_copper->defaultColorName)->hsl
	newHSLColor = incrLightnessBy(newHSLColor, 0.255)
	newHSLColor = decrHueBy(newHSLColor, 30)

	; we use the display layer for ref des so as to not mess up the gerber files
	bottom_refdes_disp_layer = "REF DES/DISPLAY_BOTTOM"
	bottom_refdes_silk_layer = "REF DES/SILKSCREEN_BOTTOM"
	bottom_refdes_assy_layer = "REF DES/ASSEMBLY_BOTTOM"
	
	bottom_refdes_disp = make_layerObj_t( ?label "Bottom_RefDes_Disp" ?layer bottom_refdes_disp_layer ?tiedLayers list() ?colorNum nextColorNum  ?defaultHSL newHSLColor ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1	
	bottom_refdes_silk = make_layerObj_t( ?label "Bottom_RefDes_Silk" ?layer bottom_refdes_silk_layer ?tiedLayers list() ?colorNum getLayerColorNum(bottom_refdes_silk_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)
	bottom_refdes_assy = make_layerObj_t( ?label "Bottom_RefDes_Assy" ?layer bottom_refdes_assy_layer ?tiedLayers list() ?colorNum getLayerColorNum(bottom_refdes_assy_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)

	; defualt color for bottom outline 
	newHSLColor = getColorDefByLabel(bottom_copper->defaultColorName)->hsl
	newHSLColor = decrLightnessBy(newHSLColor, 0.255)

	bottom_package_outline_disp_layer = "PACKAGE GEOMETRY/DISPLAY_BOTTOM"
	bottom_package_outline_silk_layer = "PACKAGE GEOMETRY/SILKSCREEN_BOTTOM"
	bottom_package_outline_assy_layer = "PACKAGE GEOMETRY/ASSEMBLY_BOTTOM"
	
	bottom_package_outline_disp = make_layerObj_t( ?label "Bottom_Outline_Disp" ?layer bottom_package_outline_disp_layer ?tiedLayers list() ?colorNum nextColorNum  ?defaultHSL newHSLColor ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1	
	bottom_package_outline_silk = make_layerObj_t( ?label "Bottom_Outline_Silk" ?layer bottom_package_outline_silk_layer ?tiedLayers list() ?colorNum getLayerColorNum(bottom_package_outline_silk_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)
	bottom_package_outline_assy = make_layerObj_t( ?label "Bottom_Outline_Assy" ?layer bottom_package_outline_assy_layer ?tiedLayers list() ?colorNum getLayerColorNum(bottom_package_outline_assy_layer)  ?defaultHSL nil ?hasVisibilityField nil ?hasColorField nil)


	; defualt color for bottom placement bounds
	newHSLColor = getColorDefByLabel(bottom_copper->defaultColorName)->hsl
	newHSLColor = incrLightnessBy(newHSLColor, 0.255)

	bottom_package_bounds = make_layerObj_t( ?label "Bottom_Bounds" ?layer "PACKAGE GEOMETRY/PLACE_BOUND_BOTTOM" ?tiedLayers list() ?colorNum nextColorNum  ?defaultHSL newHSLColor ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1	


	; --------- INNER LAYERS -----------
	Etch_Layers=(axlGetParam("paramLayerGroup:ETCH")->groupMembers)
	Nlayers = length(Etch_Layers)
	printf(" Nlayers=%L \n",Nlayers)
	innerLayerCopperList = list()
	printf(" length(innerLayerCopperList)=%L\n",length(innerLayerCopperList))
	n=1
	(foreach layer Etch_Layers
		etch_layer = strcat("ETCH/",layer)
		layerLabel = titleCase(layer)
		printf(" layer=%s %s\n",layer, layerLabel)
		if( n>1 && n<Nlayers then
			printf(" make_layerObj_t=%s\n",layerLabel)
			layerObj = make_layerObj_t( ?label layerLabel ?layer etch_layer ?tiedLayers nil ?colorNum nextColorNum  ?defaultColorName "DeepSkyBlue" ?hasVisibilityField t ?hasColorField t)
			innerLayerCopperList = append1(innerLayerCopperList, layerObj)
			printf(" length(innerLayerCopperList)=%L\n",length(innerLayerCopperList))
			nextColorNum = nextColorNum - 1	
		)
		n  = n + 1
	); 
	(foreach layerObj innerLayerCopperList
		printf("%s isVisible=%L \n",layerObj->label, layerObj->isVisible)
	)
	
	
	; --------- OTHER LAYERS -----------
	
	;board outline
	board_outline = make_layerObj_t( ?label "Board_Outline" ?layer "BOARD GEOMETRY/OUTLINE" ?tiedLayers '() ?colorNum nextColorNum  ?defaultColorName "Red" ?hasVisibilityField nil ?hasColorField nil)
	nextColorNum = nextColorNum - 1
	
	; pin labels
	pin_labels = make_layerObj_t( ?label "Pin_Labels"  ?layer "PACKAGE GEOMETRY/PIN_NUMBER" ?tiedLayers '() ?colorNum nextColorNum ?defaultColorName "White" ?hasVisibilityField t ?hasColorField t)
	nextColorNum = nextColorNum - 1

	; these are set in initializeFromDatabase()
	showNetLabels = nil
	showGrid = nil
	showCustomColors = nil
	shadowModeOn = nil
	dimActiveLayerOn = nil
	dimCustomColorsOn = nil
	brightnessPercent = 100 
	globalTransparencyPercent = 100
	shapeTransparencyPercent = 100


	; listOfNames = axlDBDisplayControl(nil)
	; printf("\naxlDBDisplayControl NAMES: \n")
	; foreach( dispName listOfNames
		; printf(" %L \n",dispName)
	; )
	; listOfNames = axlDBControl(nil)
	; printf("\naxlDBControl NAMES: \n")
	; foreach( dispName listOfNames
		; printf(" %L \n",dispName)
	; )

	initializeFromDatabase()
	
	
	;  ----------  Create the Form (popup window) ---------------------
	
	
	;SetupDir(); Commented out DE 26-Jan-11
	FormDir = "./"; Inserted DE 26-Jan-11
  
	if( axlOKToProceed() then
		; ==== Create and Display the User Interface ====

		createModRDForm()
		fFile = strcat( FormDir "modRDForm.form" )
		Form = axlFormCreate( (gensym)  fFile  nil 'modRDForm_Action t)

		updateView()  ; sets the form values

		axlFormDisplay( Form )
	else
		printf("E- Please terminate your interactive command .\n")
	);endif OKToProceed


	
); end defun - MAIN Program














 ;###########################################################
 ;# Form CallBacks - Determine Allegro command to execute   #
 ;#                  based on the user's selection          #
 ;###########################################################
 
(defun modRDForm_Action (Form)

	field = Form->curField
	val = Form->curValue

	; TOP GROUP
	processActionForColorSet(field, val, top_copper)
	processActionForColorSet(field, val, top_refdes_disp)
	processActionForColorSet(field, val, top_package_outline_disp)
	processActionForColorSet(field, val, top_package_bounds)

	; BOTTOM GROUP
	processActionForColorSet(field, val, bottom_copper)
	processActionForColorSet(field, val, bottom_refdes_disp)
	processActionForColorSet(field, val, bottom_package_outline_disp)
	processActionForColorSet(field, val, bottom_package_bounds)

	processActionForColorSet(field, val, pin_labels)

	
	(foreach layerObj innerLayerCopperList
			processActionForColorSet(field, val, layerObj)
	)
	
	
	(case field
	
		("ShowNetLabels"
			showNetLabels = val
			printf("showNetLabels =%L \n", showNetLabels)
		)

		("ShowGrid"
			showGrid = val
			printf("showGrid =%L \n", showGrid)
		)
		
		("DisableCustomColors"
			showCustomColors = !val
			printf("showCustomColors =%L \n", showCustomColors)
		)
		
		("ShadowMode"
			shadowModeOn = val
			printf("shadowModeOn =%L \n", shadowModeOn)
		)

		("DimActiveLayer"
			dimActiveLayerOn = val
			printf("dimActiveLayerOn =%L \n", dimActiveLayerOn)
		)

		("DimCustomColors"
			dimCustomColorsOn = val
			printf("dimCustomColorsOn =%L \n", dimCustomColorsOn)
		)
	
		
		
		("Brightness"
			brightnessPercent = val
			printf("brightnessPercent =%L \n", brightnessPercent)
		)

		("GlobalTransparency"
			globalTransparencyPercent = val
			printf("globalTransparencyPercent =%L \n", globalTransparencyPercent)
		)

		("ShapeTransparency"
			shapeTransparencyPercent = val
			printf("shapeTransparencyPercent =%L \n", shapeTransparencyPercent)
		)
		
		
		("Relabel"
			reLabel()
		)

		("Recolor"
			reColor()
		)

		("SetView"
			setView()
		)

		("Refresh"
			initializeFromDatabase()
		)

		("RunAll"
			reLabel()
			reColor()
			setView()
		)
		

		("Close"
			(axlFormClose Form)
			(axlCancelEnterFun)
			deleteFile( fFile )
		) ; end "Close"
	) ; end case

	updateView()
	
) ; end defun - modRDForm_Action

  ;#########################
  ;# End Form CallBacks    #
  ;#########################
 
 
 
 
 


(defun processActionForColorSet (field, val, layerObj)

	label = layerObj->label
	colornum = layerObj->colorNum
	color_field = strcat("Color_", label)
	;printf("field=%L value=%L label=%L\n", field, val, label)
	
	cond( 
		( equal(field, strcat("Show_", label)) 
			layerObj->isVisible = val
		)
		( equal(field, strcat("Color_", label)) 
			rgb = axlColorGet(colornum)
			rgb = axlUIColorDialog(Form rgb)  ; if user presses cancel button in popu, the return value is nil
			when(rgb
				updateColorNum(colornum, rgb)			
			)     
		)
		( equal(field, strcat("Color_", label, "_HuePlus")) 
			rgb = axlColorGet(colornum)
			hsl = incrHue(rgb2hsl(rgb))			
			updateColorNum(colornum, hsl2rgb(hsl))			
		)
		( equal(field, strcat("Color_", label, "_HueMinus")) 
			rgb = axlColorGet(colornum)
			hsl = decrHue(rgb2hsl(rgb))			
			updateColorNum(colornum, hsl2rgb(hsl))			
		)
		( equal(field, strcat("Color_", label, "_SaturationPlus")) 
			rgb = axlColorGet(colornum)
			hsl = incrSaturation(rgb2hsl(rgb))			
			updateColorNum(colornum, hsl2rgb(hsl))			
		)
		( equal(field, strcat("Color_", label, "_SaturationMinus")) 
			rgb = axlColorGet(colornum)
			hsl = decrSaturation(rgb2hsl(rgb))			
			updateColorNum(colornum, hsl2rgb(hsl))			
		)
		( equal(field, strcat("Color_", label, "_LightPlus")) 
			rgb = axlColorGet(colornum)
			
			printf( "RGB=%L HS=%L \n", rgb, rgb2hsl(rgb))

			
			hsl = incrLightness(rgb2hsl(rgb))			
			updateColorNum(colornum, hsl2rgb(hsl))			
		)
		( equal(field, strcat("Color_", label, "_LightMinus")) 
			rgb = axlColorGet(colornum)
			hsl = decrLightness(rgb2hsl(rgb))			
			updateColorNum(colornum, hsl2rgb(hsl))			
		)
	)
)
 
 




				
 
 
 
 
 
 
 
  ;########################################################### 
  ;# createTitleBlockForm - Main User Interface Form         #
  ;#                        Brought up by executing command. #
  ;###########################################################

(defun createModRDForm ()  

	fFile = strcat( FormDir "modRDForm.form" )
	Form  = outfile( fFile "w")

	xcol1 = 3
	xcol2 = 38
	xgroup = 2
	width_group = 66
	
	fprintf(Form "FILE_TYPE=FORM_DEFN VERSION=2\n")
	fprintf(Form "FORM \n")
	fprintf(Form "FIXED\n")
	fprintf(Form "PORT 75 1\n")  ; height is automatically caluclated
	fprintf(Form "HEADER \"PCB Review V%L.%L\"\n", vers_major, vers_minor)
	fprintf(Form "TILE\n")

	; TOP GROUP
	yref = 0

	fprintf(Form "GROUP \"Top Layer\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE %d 7\n", width_group)
	fprintf(Form "ENDGROUP\n")

	createFormColorSet(Form, xcol1, yref+2, top_copper->label, "Copper")  
	createFormColorSet(Form, xcol2, yref+2, top_refdes_disp->label, "RefDes")  
	createFormColorSet(Form, xcol1, yref+4, top_package_outline_disp->label, "Outline")  
	createFormColorSet(Form, xcol2, yref+4, top_package_bounds->label, "Bounds")  

	; BOTTOM GROUP
	yref = 7

	fprintf(Form "GROUP \"Bottom Layer\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE %d 7\n", width_group)
	fprintf(Form "ENDGROUP\n")

	createFormColorSet(Form, xcol1, yref+2, bottom_copper->label, "Copper")  
	createFormColorSet(Form, xcol2, yref+2, bottom_refdes_disp->label, "RefDes")  
	createFormColorSet(Form, xcol1, yref+4, bottom_package_outline_disp->label, "Outline")  
	createFormColorSet(Form, xcol2, yref+4, bottom_package_bounds->label, "Bounds")  
	






	; ------  pinsandnets -----------
	yref = 14
	
	fprintf(Form "GROUP \"\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE %d 5\n", width_group)
	fprintf(Form "ENDGROUP\n")

	createFormColorSet(Form, xcol1, yref+2, pin_labels->label, "Pin Labels")  

	fprintf(Form "FIELD \"ShowNetLabels\"\n")
	fprintf(Form "FLOC %d %d \n", xcol2, yref+2)
	fprintf(Form "CHECKLIST \"(Net Labels)\" \n")
	fprintf(Form "ENDFIELD\n")


	; ------  Misc -----------
	yref = 19
	fprintf(Form "GROUP \"\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE %d 7\n", width_group)
	fprintf(Form "ENDGROUP\n")

	fprintf(Form "FIELD \"DisableCustomColors\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+2)
	fprintf(Form "CHECKLIST \"Disable Custom Colors\" \n")
	fprintf(Form "ENDFIELD\n")

	fprintf(Form "FIELD \"DRC\"\n")
	fprintf(Form "FLOC %d %d \n", xcol2, yref+2)
	fprintf(Form "CHECKLIST \"(DRC) \" \n")
	fprintf(Form "ENDFIELD\n")

	fprintf(Form "FIELD \"RatsNest\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+4)
	fprintf(Form "CHECKLIST \"(Rats)\" \n")
	fprintf(Form "ENDFIELD\n")

	fprintf(Form "FIELD \"ShowGrid\"\n")
	fprintf(Form "FLOC %d %d \n", xcol2, yref+4)
	fprintf(Form "CHECKLIST \"Grid\" \n")
	fprintf(Form "ENDFIELD\n")


	; ------  Shadow Mode -----------

	; fprintf(Form "FIELD \"Brightness\"\n")
	; fprintf(Form "FLOC 12 %d \n", ymisc+9)
	; fprintf(Form "TRACKBAR 30 5\n")
	; fprintf(Form "MIN 0\n")
	; fprintf(Form "MAX 100\n")
	; fprintf(Form "ENDFIELD\n")
	
	yref = 26
	fprintf(Form "GROUP \"\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE %d 8\n", width_group)
	fprintf(Form "ENDGROUP\n")

	fprintf(Form "FIELD \"ShadowMode\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+2)
	fprintf(Form "CHECKLIST \"Shadow Mode\" \n")
	fprintf(Form "ENDFIELD\n")

	fprintf(Form "FIELD \"DimActiveLayer\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+20, yref+2)
	fprintf(Form "CHECKLIST \"Dim Active Layer\" \n")
	fprintf(Form "ENDFIELD\n")

	fprintf(Form "FIELD \"DimCustomColors\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+41, yref+2)
	fprintf(Form "CHECKLIST \"Dim Custom Colors\" \n")
	fprintf(Form "ENDFIELD\n")

	fprintf(Form "FIELD \"Brightness\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+5)
	fprintf(Form "INTSLIDEBAR 4 3\n")
	fprintf(Form "MIN 0\n")
	fprintf(Form "MAX 100\n")
	fprintf(Form "ENDFIELD\n")	

	fprintf(Form "TEXT \"Brightness\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+8, yref+5)
	fprintf(Form "FSIZE 10 2 \n")
	fprintf(Form "ENDTEXT\n")


	fprintf(Form "TEXT \"Transparency:\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+20, yref+5)
	fprintf(Form "FSIZE 15 2 \n")
	fprintf(Form "ENDTEXT\n")

	fprintf(Form "FIELD \"GlobalTransparency\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+32, yref+5)
	fprintf(Form "INTSLIDEBAR 4 3\n")
	fprintf(Form "MIN 0\n")
	fprintf(Form "MAX 100\n")
	fprintf(Form "ENDFIELD\n")	

	fprintf(Form "TEXT \"Global\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+40, yref+5)
	fprintf(Form "FSIZE 10 2 \n")
	fprintf(Form "ENDTEXT\n")

	fprintf(Form "FIELD \"ShapeTransparency\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+46, yref+5)
	fprintf(Form "INTSLIDEBAR 4 3\n")
	fprintf(Form "MIN 0\n")
	fprintf(Form "MAX 100\n")
	fprintf(Form "ENDFIELD\n")	

	fprintf(Form "TEXT \"Shape\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1+54, yref+5)
	fprintf(Form "FSIZE 10 2 \n")
	fprintf(Form "ENDTEXT\n")
	

	
	; ---------------- INNER LAYERS -------------

	yref = 34
	Nby2 = Nlayers/2
	;Ntotalrows = 2+2*(Nby2-2) + 3
	Ntotalrows = 2*(Nlayers-2) + 3
	fprintf(Form "GROUP \"Inner Layers\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE %d %d\n", width_group, Ntotalrows)
	fprintf(Form "ENDGROUP\n")

	yoffset = 2
	xcol = (xcol1 + xcol2)/2
	(foreach layerObj innerLayerCopperList
		createFormColorSet(Form, xcol, yref+yoffset, layerObj->label, layerObj->label)  
		; if(xcol == xcol1 then
			; xcol = xcol2
		; else
			; xcol = xcol1
			; yoffset = yoffset + 2
		; )
		yoffset = yoffset + 2
	)



	
	; ---------------- BUTTONS -------------
	
	yref = yref + Ntotalrows
	fprintf(Form "GROUP \"\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE 53 5\n")
	fprintf(Form "ENDGROUP\n")

	fprintf(Form "FIELD Relabel\n")
	fprintf(Form "FLOC 7 %d \n", yref+2)
	fprintf(Form "MENUBUTTON \"Relabel\" 8 3\n")
	fprintf(Form "ENDFIELD\n")	
	
	fprintf(Form "FIELD Recolor\n")
	fprintf(Form "FLOC 18 %d \n", yref+2)
	fprintf(Form "MENUBUTTON \"Recolor\" 8 3\n")
	fprintf(Form "ENDFIELD\n")	
	
	fprintf(Form "FIELD SetView \n")
	fprintf(Form "FLOC 29 %d \n", yref+2)
	fprintf(Form "MENUBUTTON \"Set View\" 8 3\n")
	fprintf(Form "ENDFIELD\n")	

	fprintf(Form "FIELD Refresh\n")
	fprintf(Form "FLOC 40 %d \n", yref+2)
	fprintf(Form "MENUBUTTON \"Refresh\" 8 3\n")
	fprintf(Form "ENDFIELD\n")	


	fprintf(Form "GROUP \"\"\n")
	fprintf(Form "GLOC 56 %d \n", yref)
	fprintf(Form "GSIZE 12 5\n")
	fprintf(Form "ENDGROUP\n")

	fprintf(Form "FIELD RunAll\n")
	fprintf(Form "FLOC 58 %d \n", yref+2)
	fprintf(Form "MENUBUTTON \"Run All\" 8 3\n")
	fprintf(Form "ENDFIELD\n")	
	
	

	; ---------------- NOTES -------------
	

	yref = yref + 5
	fprintf(Form "GROUP \"NOTES\"\n")
	fprintf(Form "GLOC %d %d \n", xgroup, yref)
	fprintf(Form "GSIZE %d 13\n", width_group)
	fprintf(Form "ENDGROUP\n")
	
	fprintf(Form "TEXT \"'Relabel' modifies and displays the reference designators on the RefDes display layer. Silkscreen and assembly layers are not changed.\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+2)
	fprintf(Form "FSIZE 62 5 \n", width_group-2)
	fprintf(Form "ENDTEXT\n")
	
	fprintf(Form "TEXT \"'Recolor' re-colors all the layers shown above.\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+5)
	fprintf(Form "FSIZE %d 2 \n", width_group-2)
	fprintf(Form "ENDTEXT\n")

	fprintf(Form "TEXT \"'Set View' sets view to default layer visibility, shadow, grid, etc.\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+7)
	fprintf(Form "FSIZE %d 2 \n", width_group)
	fprintf(Form "ENDTEXT\n")

	fprintf(Form "TEXT \"'Refresh' refreshes this popup with any changes made from other windows.\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+9)
	fprintf(Form "FSIZE %d 2 \n", width_group)
	fprintf(Form "ENDTEXT\n")

	fprintf(Form "TEXT \"+/- button pairs are for Hue, Saturation, and Lightness.\"\n")
	fprintf(Form "FLOC %d %d \n", xcol1, yref+11)
	fprintf(Form "FSIZE %d 2 \n", width_group)
	fprintf(Form "ENDTEXT\n")
	
	printf("Done: form setup\n")


	fprintf(Form "ENDTILE\n")
	fprintf(Form "ENDFORM\n")
	close(Form)
); end defun  - createModRDForm


















(defun createFormColorSet (form, xref, yref, str, label)  


	fprintf(form "FIELD Show_%s\n", str)
	fprintf(form "FLOC %d %d \n", xref, yref)
	fprintf(form "CHECKLIST \"%s\" \n", label)
	fprintf(form "ENDFIELD\n")

	fprintf(form "FIELD Color_%s\n", str)
	fprintf(form "FLOC %d %d \n", xref+11, yref)
	fprintf(form "COLOR 3 1\n")
	fprintf(form "ENDFIELD\n")

	fprintf(form "FIELD Color_%s_HuePlus\n", str)
	fprintf(form "FLOC %d %d \n", xref+14, yref)
	fprintf(form "MENUBUTTON \"+\" 4 1\n")
	fprintf(form "ENDFIELD\n")	

	fprintf(form "FIELD Color_%s_HueMinus\n", str)
	fprintf(form "FLOC %d %d \n", xref+14, yref+1)
	fprintf(form "MENUBUTTON \"-\" 4 1\n")
	fprintf(form "ENDFIELD\n")	

	fprintf(form "FIELD Color_%s_SaturationPlus\n", str)
	fprintf(form "FLOC %d %d \n", xref+18, yref)
	fprintf(form "MENUBUTTON \"+\" 4 1\n")
	fprintf(form "ENDFIELD\n")	

	fprintf(form "FIELD Color_%s_SaturationMinus\n", str)
	fprintf(form "FLOC %d %d \n", xref+18, yref+1)
	fprintf(form "MENUBUTTON \"-\" 4 1\n")
	fprintf(form "ENDFIELD\n")	

	fprintf(form "FIELD Color_%s_LightPlus\n", str)
	fprintf(form "FLOC %d %d \n", xref+22, yref)
	fprintf(form "MENUBUTTON \"+\" 4 1\n")
	fprintf(form "ENDFIELD\n")	

	fprintf(form "FIELD Color_%s_LightMinus\n", str)
	fprintf(form "FLOC %d %d \n", xref+22, yref+1)
	fprintf(form "MENUBUTTON \"-\" 4 1\n")
	fprintf(form "ENDFIELD\n")	
)




(defun 	reLabel ()

	;--------- RES DEFS ----------

	deleteLayerText(top_refdes_disp->layer)
	deleteLayerText(bottom_refdes_disp->layer)
	deleteLayerObjectsOfTypes(top_package_outline_disp->layer, (list "text" "shapes"))
	deleteLayerObjectsOfTypes(bottom_package_outline_disp->layer, (list "text" "shapes"))
	
	; next step is to loop through the objects and then call the label routine for each
	; the updateRD
	dbidList = axlDBGetDesign()->symbols
	foreach( mySymbol dbidList
		if( equal(mySymbol->type, "PACKAGE") then
			createRD(mySymbol)
		else
			printf("IGNORED: DBID=%L objType=%L type=%L refdes=%L\n\n" , mySymbol, mySymbol->objType, mySymbol->type, mySymbol->refdes)
		)
		;printf(" props: %L\n", mySymbol->??)
	)

	;--------- PIN LABELS ----------

	deleteLayerText(pin_labels->layer)

	pinList = getLayerObjectList(top_pin_layer,(list "noall"  "pins"), (list "pins"))
	foreach( pin pinList
		 createPL(pin, pin_labels->layer)
	)
	pinList = getLayerObjectList(bottom_pin_layer,(list "noall"  "pins"), (list "pins"))
	foreach( pin pinList
		 createPL(pin, pin_labels->layer)
	)

	;--------- UPDATE VIEW ----------

	top_refdes_disp->isVisible = t
	top_refdes_assy->isVisible = nil
	top_refdes_silk->isVisible = nil
	top_package_outline_disp->isVisible = t
	top_package_outline_assy->isVisible = nil
	top_package_outline_silk->isVisible = nil
	top_package_bounds->isVisible = nil
	
	bottom_refdes_disp->isVisible = t
	bottom_refdes_assy->isVisible = nil
	bottom_refdes_silk->isVisible = nil	
	bottom_package_outline_disp->isVisible = t
	bottom_package_outline_assy->isVisible = nil
	bottom_package_outline_silk->isVisible = nil
	bottom_package_bounds->isVisible = nil
	
	updateView();
)















(defun reColor ()

	; TODO: give back all colors

	; set top and bottom
	reColorLayer(top_copper)
	reColorLayer(bottom_copper)

	; INTERNAL LAYERS
	; TODO: get color of adjacent layers (if previously defined)
	; implement getColorDef(exclusionFamiles)
	; loop through all inetrnal layers

	
	
	; RECOLOR REF DES ETC

	reColorLayer(top_refdes_disp)
	reColorLayer(top_package_outline_disp)
	reColorLayer(top_package_bounds)
	
	reColorLayer(bottom_refdes_disp)
	reColorLayer(bottom_package_outline_disp)
	reColorLayer(bottom_package_bounds)

	reColorLayer(pin_labels)
	reColorLayer(board_outline)

	
	updateView()
)



(defun reColorLayer (layerObj)
	printf("RECOLOR Layer %s \n", layerObj->layer)
	colorDef = reserveColorDefByLabel(layerObj->defaultColorName)
	if(colorDef != nil then
		hsl = colorDef->hsl
	else
		hsl = layerObj->defaultHSL
	)
	rgb = hsl2rgb(hsl)
	updateColorNum(layerObj->colorNum, rgb)
)


(defun setView ()

	
	top_copper->isVisible = nil
	top_refdes_disp->isVisible = t
	top_refdes_assy->isVisible = nil
	top_refdes_silk->isVisible = nil
	top_package_outline_disp->isVisible = t
	top_package_outline_assy->isVisible = nil
	top_package_outline_silk->isVisible = nil
	top_package_bounds->isVisible = nil

	(foreach layerObj innerLayerCopperList
		layerObj->isVisible = nil
	)

	
	bottom_copper->isVisible = nil
	bottom_refdes_disp->isVisible = t
	bottom_refdes_assy->isVisible = nil
	bottom_refdes_silk->isVisible = nil
	bottom_package_outline_disp->isVisible = t
	bottom_package_outline_assy->isVisible = nil
	bottom_package_outline_silk->isVisible = nil
	bottom_package_bounds->isVisible = nil
	
	board_outline->isVisible = t
	pin_labels->isVisible = t
	showNetLabels = t
	showGrid = nil
	showCustomColors = nil
	shadowModeOn = t
	dimActiveLayerOn = t
	dimCustomColorsOn = nil
	
	brightnessPercent = 100
	globalTransparencyPercent = 50
	shapeTransparencyPercent = 30
	
	; set active layer as board outline so that refdes text is always display on top of the copper of all layers
	board_outline->isVisible = t
	updateLayer(board_outline)
	axlDBControl('activeLayer, board_outline->layer)
	
	; set layer display priorities
	axlLayerPriorityClearAll()
	cnt = 1
	axlLayerPrioritySet(board_outline->layer, cnt)
	cnt = cnt + 1
	axlLayerPrioritySet(top_refdes_disp->layer, cnt)
	cnt = cnt + 1
	axlLayerPrioritySet(bottom_refdes_disp->layer, cnt)	  
	cnt = cnt + 1
	axlLayerPrioritySet(pin_labels->layer, cnt)	  

	
	updateView()

)




; applies updates made in the popup

(defun updateView ()

	
	; NEW PARADIGM

	updateLayer(top_copper)
	updateLayer(top_refdes_disp)
	updateLayer(top_refdes_assy)
	updateLayer(top_refdes_silk)
	updateLayer(top_package_outline_disp)
	updateLayer(top_package_outline_assy)
	updateLayer(top_package_outline_silk)
	updateLayer(top_package_bounds)

	(foreach layerObj innerLayerCopperList
		updateLayer(layerObj)		
	); 

	updateLayer(bottom_copper)
	updateLayer(bottom_refdes_disp)
	updateLayer(bottom_refdes_assy)
	updateLayer(bottom_refdes_silk)
	updateLayer(bottom_package_outline_disp)
	updateLayer(bottom_package_outline_assy)
	updateLayer(bottom_package_outline_silk)
	updateLayer(bottom_package_bounds)

	updateLayer(pin_labels)


	;axlFlushDisplay()	
	

	axlFormSetField(Form "ShowNetLabels" showNetLabels)	
	axlDBDisplayControl('displayNetNames, showNetLabels)	
	axlFormSetField(Form "ShowGrid" showGrid)	
	axlDBDisplayControl('gridEnable, showGrid)	
	axlFormSetField(Form "DisableCustomColors" !showCustomColors)	
	axlDBDisplayControl('customColorEnabled, showCustomColors)	

	; TODO implemnt aapplication of settings to dispaly
	axlFormSetField(Form "ShadowMode" shadowModeOn)	
	axlColorShadowSet('mode shadowModeOn)
	axlFormSetField(Form "DimActiveLayer" dimActiveLayerOn)	
	axlColorShadowSet('activeLayer dimActiveLayerOn)
	axlFormSetField(Form "DimCustomColors" dimCustomColorsOn)	
	axlColorShadowSet('highlight dimCustomColorsOn)  
	axlFormSetField(Form "Brightness" brightnessPercent)	
	axlColorShadowSet('percent brightnessPercent)
	axlFormSetField(Form "GlobalTransparency" globalTransparencyPercent)	
	axlDBDisplayControl('transparencyGlobal round(2.55*globalTransparencyPercent))
	axlFormSetField(Form "ShapeTransparency" shapeTransparencyPercent)	
	axlDBDisplayControl('transparencyShape round(2.55*shapeTransparencyPercent))

	
	axlVisibleUpdate(t)
	axlUIWRedraw(nil)
	axlUIWUpdate(nil)  
	

); end defun updateView




(defun updateLayer (layerObject)
	axlVisibleLayer(layerObject->layer  layerObject->isVisible)
	foreach( layer layerObject->tiedLayers
		axlVisibleLayer(layer layerObject->isVisible)
	)
	if(layerObject->hasVisibilityField then
		axlFormSetField(Form strcat("Show_",layerObject->label) layerObject->isVisible)	
	)
	if(layerObject->hasColorField then
		axlFormSetField(Form strcat("Color_",layerObject->label), layerObject->colorNum)
	)
)





; syncrhonizes pop-up window with any changes made through other parts of Allegro
(defun initializeFromDatabase ()


	initLayerFromDatabase(top_copper)
	initLayerFromDatabase(top_refdes_disp)
	initLayerFromDatabase(top_refdes_assy)
	initLayerFromDatabase(top_refdes_silk)
	initLayerFromDatabase(top_package_outline_disp)
	initLayerFromDatabase(top_package_outline_assy)
	initLayerFromDatabase(top_package_outline_silk)
	initLayerFromDatabase(top_package_bounds)
	
	(foreach layerObj innerLayerCopperList
		initLayerFromDatabase(layerObj)		
	); 

	initLayerFromDatabase(bottom_copper)
	initLayerFromDatabase(bottom_refdes_disp)
	initLayerFromDatabase(bottom_refdes_assy)
	initLayerFromDatabase(bottom_refdes_silk)
	initLayerFromDatabase(bottom_package_outline_disp)
	initLayerFromDatabase(bottom_package_outline_assy)
	initLayerFromDatabase(bottom_package_outline_silk)
	initLayerFromDatabase(bottom_package_bounds)

	initLayerFromDatabase(board_outline)
	initLayerFromDatabase(pin_labels)



		

	; --------------- Text Style Objects ---------------------- 
	

	axlDBTextBlockCompact(t)
	numUnalteredTextBlocks = axlDBControl('maxTextBlock)

	styleList = list()
	
	txt_tiny->blockNum = getTextBlockNumFromTxtStyle(txt_tiny)
	styleList = cons(txt_tiny, styleList)
	txt_xsmall->blockNum = getTextBlockNumFromTxtStyle(txt_xsmall)
	styleList = cons(txt_xsmall, styleList)
	txt_small->blockNum = getTextBlockNumFromTxtStyle(txt_small)
	styleList = cons(txt_small, styleList)
	txt_medium->blockNum = getTextBlockNumFromTxtStyle(txt_medium)
	styleList = cons(txt_medium, styleList)
	txt_large->blockNum = getTextBlockNumFromTxtStyle(txt_large)
	styleList = cons(txt_large, styleList)
	txt_xlarge->blockNum = getTextBlockNumFromTxtStyle(txt_xlarge)
	styleList = cons(txt_xlarge, styleList)

	
	
	; ---------------------- other ----------------------
	showNetLabels = axlDBDisplayControl('displayNetNames)	
	printf("init showNetLabels =%L \n", showNetLabels)
	showNetLabels = axlDBControl('displayNetNames)	
	printf("init showNetLabels =%L \n", showNetLabels)
	showGrid = axlDBDisplayControl('gridEnable)
	if( showGrid == 1 then 
		showGrid = t
	else
		showGrid = nil
	)
	printf("init showGrid =%L \n", showGrid)
	showCustomColors = axlDBDisplayControl('customColorEnabled)
	printf("init showCustomColors =%L \n", showCustomColors)		
	
	shadowModeOn = axlColorShadowGet('mode)
	printf("init shadowModeOn =%L \n", shadowModeOn)
	dimActiveLayerOn = axlColorShadowGet('activeLayer)
	printf("init dimActiveLayerOn =%L \n", dimActiveLayerOn)
	dimCustomColorsOn = axlColorShadowGet('highlight)
	printf("init dimCustomColorsOn =%L \n", dimCustomColorsOn)
	brightnessPercent = axlColorShadowGet('percent)
	printf("init brightnessPercent =%L \n", brightnessPercent)
	globalTransparencyPercent = round(axlDBDisplayControl('transparencyGlobal)/2.55)
	printf("init globalTransparencyPercent =%L \n", globalTransparencyPercent)
	shapeTransparencyPercent = round(axlDBDisplayControl('transparencyShape)/2.55)
	printf("init shapeTransparencyPercent =%L \n", shapeTransparencyPercent)
	

	
	axlVisibleUpdate(t)
	axlUIWRedraw(nil)
	axlUIWUpdate(nil)  



); end defun initializeFromDatabase






(defun initLayerFromDatabase (layerObject)
	layerObject->isVisible = axlIsVisibleLayer(layerObject->layer )
	colornum_0 = getLayerColorNum(layerObject->layer)
	rgb = axlColorGet(colornum_0)
	printf("rgb of %s = %L\n", layerObject->label, rgb)
	colornum = layerObject->colorNum
	if(colornum != colornum_0 then
		axlColorSet(colornum rgb)
		setLayerColorNum(layerObject->layer, colornum)	
	)
	foreach( tiedLayer layerObject->tiedLayers
		printf("rgb of %s = %L\n", tiedLayer, rgb)
		setLayerColorNum(tiedLayer colornum)
	)

)




(defun createPL (pin, layer)

	;printf(" pin props: %L\n", pin->??)
	isValid = t
	
	parent = pin->parent
	if(parent == nil || parent->refdes == nil then
		printf("*PIN HAS NO COMPONENT: %L %L parent=%L \n", pin->name, pin->number, parent)
		isValid = nil
	)

	pinum = pin->number
	if(pinum == nil || equal(pinum, "") then
		printf("*PIN HAS NO NUMBER: %L\n", pin->name)
		isValid = nil
	)


	if(isValid then
		Nrefdes = strlen(pinum)


		; get bounding box dimensions
		bBox = pin->bBox
		bBox_min = nth(0 bBox)
		bBox_max = nth(1 bBox)
		bBox_x1 = nth(0 bBox_min)
		bBox_y1 = nth(1 bBox_min)
		bBox_x2 = nth(0 bBox_max)
		bBox_y2 = nth(1 bBox_max)


		;printf("bBox_x1: %L\n", bBox_x1)
		;printf("bBox_x2: %L\n", bBox_x2)
		;printf("bBox_y1: %L\n", bBox_y1)
		;printf("bBox_y2: %L\n", bBox_y2)

		bBox_size_x = bBox_x2 - bBox_x1
		bBox_size_y = bBox_y2 - bBox_y1

		;printf("bBox_size_x: %L\n", bBox_size_x)
		;printf("bBox_size_y: %L\n", bBox_size_y)



		bBox_center_x   = (bBox_x1 + bBox_x2) / 2
		bBox_center_y   = (bBox_y1 + bBox_y2) / 2

		;printf("bBox_center_x: %L\n", bBox_center_x)
		;printf("bBox_center_y: %L\n", bBox_center_y)


		; determine if text should be horizontal or vertical using the aspcect ratio of the bounding box
		rotation = 0
		rotated_width = bBox_size_x
		rotated_height = bBox_size_y
		if(bBox_size_y > 1.2*bBox_size_x then
		rotation = 270
		rotated_width = bBox_size_y
		rotated_height = bBox_size_x
		)
		;printf("rotated_width: %L\n", rotated_width)
		;printf("rotated_height: %L\n", rotated_height)

		; find a text style just small enough that the Ref Des fits within the footprint (bounds)
		txtStyle = txt_tiny


		; offset position of text by half of font height since font position is referenced to top of text
		delta = (txtStyle->height)/2
		if( rotation ==   0 then 
		ypos = bBox_center_y - delta
		xy = list( bBox_center_x, ypos )
		)
		if( rotation ==  90 then 
		xpos = bBox_center_x + delta
		xy = list( xpos, bBox_center_y )
		)
		if( rotation == 180 then 
		ypos = bBox_center_y + delta	
		xy = list( bBox_center_x, ypos )
		)
		if( rotation == 270 then 
		xpos = bBox_center_x - delta
		xy = list( xpos, bBox_center_y )
		)

		; create the pin number text
		isMirrored = nil
		justification = "CENTER"
		txtBlockNumAsStr = concat("",txtStyle->blockNum)
		textOrientation = make_axlTextOrientation( ?textBlock txtBlockNumAsStr, ?rotation  rotation, ?mirrored  isMirrored, ?justify   justification)
		update = axlDBCreateText( pinum, xy, textOrientation, layer, pin)
	)

	


)
















(defun createRD (mySymbol)

	if(mySymbol->isMirrored then
		layer = bottom_refdes_disp->layer
		outlineLayer = bottom_package_outline_disp->layer
	else
		layer = top_refdes_disp->layer
		outlineLayer = top_package_outline_disp->layer
	)

	refdes = mySymbol->refdes
	if(refdes == nil then
		refdes = mySymbol->name
	)
	Nrefdes = strlen(refdes)
	;printf("createRD: %s strlen=%L\n", refdes, Nrefdes)
	;printf(" props: %L\n", mySymbol->??)


	bBox = mySymbol->bBox
	
	; if we find a bounds objects, use that bbox instead since it tends to be more accurate in practice
	foreach( child mySymbol->children
		if( equal(child->layer, top_package_bounds->layer)
			;printf(" child props: %L\n", child->??)
			bBox = child->bBox
		)
		if( equal(child->layer, bottom_package_bounds->layer)
			;printf(" child props: %L\n", child->??)
			bBox = child->bBox
		)
	)
	mybBox = copy(bBox)

	
	bBox_min = nth(0 bBox)
	bBox_max = nth(1 bBox)
	bBox_x1 = nth(0 bBox_min)
	bBox_y1 = nth(1 bBox_min)
	bBox_x2 = nth(0 bBox_max)
	bBox_y2 = nth(1 bBox_max)


	;printf("bBox_x1: %L\n", bBox_x1)
	;printf("bBox_x2: %L\n", bBox_x2)
	;printf("bBox_y1: %L\n", bBox_y1)
	;printf("bBox_y2: %L\n", bBox_y2)

	bBox_size_x = bBox_x2 - bBox_x1
	bBox_size_y = bBox_y2 - bBox_y1

	;printf("bBox_size_x: %L\n", bBox_size_x)
	;printf("bBox_size_y: %L\n", bBox_size_y)



	bBox_center_x   = (bBox_x1 + bBox_x2) / 2
	bBox_center_y   = (bBox_y1 + bBox_y2) / 2

	;printf("bBox_center_x: %L\n", bBox_center_x)
	;printf("bBox_center_y: %L\n", bBox_center_y)

	
	; determine if text should be horizontal or vertical using the aspcect ratio of the bounding box
	rotation = 0
	rotated_width = bBox_size_x
	rotated_height = bBox_size_y
	if(bBox_size_y > 1.2*bBox_size_x then
		rotation = 270
		rotated_width = bBox_size_y
		rotated_height = bBox_size_x
	)
	;printf("rotated_width: %L\n", rotated_width)
	;printf("rotated_height: %L\n", rotated_height)
	
	; find a text style just small enough that the Ref Des fits within the footprint (bounds)
	n = 0
	N = length(styleList)-1
	txtStyle = nth(0 styleList)
	prog( ( )
		for( n 0 N 
			txtStyle = nth(n styleList)
			refWidth = Nrefdes*(txtStyle->width) + (Nrefdes-1)*(txtStyle->charSpace)
			;printf("refWidth: %L\n", refWidth)
			if( and((txtStyle->height < (0.667*rotated_height)), (refWidth < (0.7*rotated_width))) then
				return()
			)
		)
	)
	
	;printf(" n=%L length=%L \n", n, length(styleList))
	;printf(" n=%L name=%s blockNum=%L height = %L  rotation = %d\n", n, txtStyle->str_name, txtStyle->blockNum, txtStyle->height, rotation)
	
	; offset position of text by half of font height since font position is referenced to top of text
	delta = (txtStyle->height)/2
	if( rotation ==   0 then 
		ypos = bBox_center_y - delta
		xy = list( bBox_center_x, ypos )
	)
	if( rotation ==  90 then 
		xpos = bBox_center_x + delta
		xy = list( xpos, bBox_center_y )
	)
	if( rotation == 180 then 
		ypos = bBox_center_y + delta	
		xy = list( bBox_center_x, ypos )
	)
	if( rotation == 270 then 
		xpos = bBox_center_x - delta
		xy = list( xpos, bBox_center_y )
	)

	
	; DEBUGGING 
	if(txtStyle->blockNum == nil then
		printf("txtStyle %L %L\n", n, txtStyle->str_name)	
	)
	
	; create the REF DES text
	isMirrored = nil
	justification = "CENTER"
	txtBlockNumAsStr = concat("",txtStyle->blockNum)
	textOrientation = make_axlTextOrientation( ?textBlock txtBlockNumAsStr, ?rotation  rotation, ?mirrored  isMirrored, ?justify   justification)
	update = axlDBCreateText( refdes, xy, textOrientation, layer, mySymbol)

	
	; create outline on package display layers
	isFilled = nil
	netName = nil
	axlDBIgnoreFixed(t)
	axlDBCreateRectangle( mybBox, isFilled, outlineLayer, netName, mySymbol)
	axlDBIgnoreFixed(nil)
	

)









;------------------------------------------------------------------------
;   HELPER FUNCTIONS
;------------------------------------------------------------------------



procedure( getTextBlockNumFromTxtStyle(txtStyle) 
	blockNum = 0
	nBlocks = axlDBControl('maxTextBlock)
	;printf( "num text blocks=%d \n", nBlocks )
	; use prog so we can exit the foreach loop usign return
	prog( ( )
		for( n 1 nBlocks
			sprintf(str, "paramTextBlock:%d\n", n)
			;printf("paramTextBlock:%d ?= %s\n",n, str)
			txtBlock = axlGetParam(str)
			;printf( " txtBlock->width=%f txtStyle->width=%f \n", txtBlock->width, txtStyle->width )
			if( txtBlock->width == txtStyle->width 
			&&  txtBlock->height == txtStyle->height
			&&  txtBlock->lineSpace == txtStyle->lineSpace
			&&  txtBlock->photoWidth == txtStyle->photoWidth
			&&  txtBlock->charSpace == txtStyle->charSpace
			then 
				blockNum = evalstring(txtBlock->name)
				printf( "found a matching text block=%d !!\n", blockNum )
				return()
			)
		)	
	)
	if( blockNum == 0
		if( nBlocks == 64 then
			; allegro only allows 64 fonts (lame!)
			; overwrite another font
			sprintf(str, "paramTextBlock:%d\n", numUnalteredTextBlocks)
			;printf("paramTextBlock:%d ?= %s\n",n, str)
			txtBlock = axlGetParam(str)
			txtBlock->width = txtStyle->width 
			txtBlock->height = txtStyle->height
			txtBlock->lineSpace = txtStyle->lineSpace
			txtBlock->photoWidth = txtStyle->photoWidth
			txtBlock->charSpace = txtStyle->charSpace
			numUnalteredTextBlocks = numUnalteredTextBlocks - 1
		else
			blockNum = axlDBTextBlockCreate(0 ?width txtStyle->width ?height txtStyle->height ?lineSpace txtStyle->lineSpace ?photoWidth txtStyle->photoWidth ?charSpace txtStyle->charSpace)	
		)
	)
	blockNum
) 
; end proc etTextBlockNumFromContent














(defun layerStr2ParamStr (layerStr)
	rexCompile( "\\([^/]+\\)/\\([^/]+\\)" )
	rexExecute( layerStr )
	sprintf(paramStr, "paramLayerGroup:%s/paramLayer:%s", rexSubstitute("\\1"), rexSubstitute("\\2"))
	paramStr
) 
; end proc 









(defun setLayerColorNum (layerStr, colorNum)
	val = axlGetParam( layerStr2ParamStr(layerStr) )
	val->color = colorNum
	axlSetParam( val )
) 
; end proc 



(defun getLayerColorNum (layerStr)
	colorNum = axlLayerGet(layerStr)->color
	colorNum
)






(defun getLayerObjectList (layer, enableList, onButtonsList)
	saveVis = axlVisibleGet()
	axlVisibleDesign(nil)

	axlVisibleLayer( layer t)
	axlClearSelSet()
;	axlSetFindFilter( ?enabled   (list "alltypes") ?onButtons (list "alltypes") )
	axlSetFindFilter( ?enabled enableList ?onButtons  onButtonsList)
	axlAddSelectAll()
	objList = axlGetSelSet()
	axlClearSelSet()
	axlVisibleSet(saveVis)
	axlFlushDisplay()
	objList
)



(defun deleteLayerText (layer)

	saveVis = axlVisibleGet()
	axlClearSelSet()
	axlSetFindFilter( ?enabled (list "noall"  "text") ?onButtons (list "text"))
	axlVisibleDesign(nil)
	axlVisibleLayer( layer t)
	if( layer==pin_labels->layer  then
		axlVisibleLayer( top_pin_layer t)	
		axlVisibleLayer( bottom_pin_layer t)	
	)
	list_rds = axlGetSelSet( axlAddSelectAll() )
	axlDBIgnoreFixed(t)
	foreach( text_id list_rds
		axlDeleteObject( list( text_id ))
	)
	axlDBIgnoreFixed(nil)
	axlClearSelSet()
	axlVisibleSet(saveVis)
	axlFlushDisplay()
	axlMsgPut(strcat( layer " text deletion completed.") )
	
)


(defun deleteLayerObjectsOfTypes (layer, objTypeList )

	saveVis = axlVisibleGet()
	axlClearSelSet()
	axlSetFindFilter( ?enabled cons("noall", objTypeList) ?onButtons objTypeList)
	axlVisibleDesign(nil)
	axlVisibleLayer( layer t)
	if( layer==pin_labels->layer  then
		axlVisibleLayer( top_pin_layer t)	
		axlVisibleLayer( bottom_pin_layer t)	
	)
	list_rds = axlGetSelSet( axlAddSelectAll() )
	axlDBIgnoreFixed(t)
	foreach( text_id list_rds
		axlDeleteObject( list( text_id ))
	)
	axlDBIgnoreFixed(nil)
	axlClearSelSet()
	axlVisibleSet(saveVis)
	axlFlushDisplay()
	axlMsgPut(strcat( layer " text deletion completed.") )
	
)



(defun rgb2hsl (rgb) 

	; input list (r g b) is assumed to range from 0 to 255
	; must use 255.0, not 255, to get a floating point answer
	r = nth(0, rgb)
	g = nth(1, rgb)
	b = nth(2, rgb)

	;printf(" r=%L  g=%L  b= %L  \n",  r, g, b) 

	r = r/255.0
	g = g/255.0
	b = b/255.0

	
	Cmax = max(r,g,b)
	Cmin = min(r,g,b)
	
	delta = Cmax - Cmin
	;printf(" Cmin=%L  Cmax=%L  delta = %L  \n",  Cmin, Cmax, delta) 
	
	; calculate Hue, range [0,360] degrees
	H = 0;
	cond( 
		( delta == 0  
			H = 0 
		)
		( Cmax == r
			temp1 = (g - b)/delta
			temp2 = modf(temp1, 6.0)
			H = 60.0 * temp2
		)
		( Cmax == g
			temp1 = (b - r)/delta
			temp2 = temp1 + 2.0
			H = 60.0 * temp2
		)
		( Cmax == b
			temp1 = (r - g)/delta
			temp2 = temp1 + 4.0
			H = 60.0 * temp2
		)
	)
	
	if( H < 0 then
		H = H + 360
	)
	
	; caluclate Lightness
	L=(Cmax + Cmin)/2.0

	; calculate Saturation
	if( delta == 0 then
		S=0
	else
		S = delta / (1 - abs(2.0*L-1.0))
	)
	;printf(" H=%L  S=%L  L= %L  \n",  H, S, L) 

	hsl = list( H S L )
	;printf(" hsl=%L \n",  hsl) 
	
	; return as a list
	hsl
)	




(defun hsl2rgb (hsl) 

	; input list (H S L)
	; 0 <= H <= 260
	; 0 <= S <= 1
	; 0 <= L <= 1
	H = nth(0, hsl)
	while( H < 0
		H = H + 360
	)
	while( H >= 360 
		H = H - 360
	)
	S = nth(1, hsl)
	L = nth(2, hsl)
	
	;printf(" H=%L  S=%L  L= %L  \n",  H, S, L) 
	
	temp = 2.0*L - 1.0
	C = (1.0 - abs(temp))*S
	X = C*(1.0 - abs(modf(H/60.0,2.0) - 1.0))
	m = L - C/2.0
	
	cond( 
		( H <= 60.0
			rp = C
			gp = X
			bp = 0.0
		)
		( 60 <= H && H <= 120.0
			rp = X
			gp = C
			bp = 0.0
		)
		( 120 <= H && H <= 180.0
			rp = 0.0
			gp = C
			bp = X
		)
		( 180 <= H && H <= 240.0
			rp = 0.0
			gp = X
			bp = C
		)
		( 240 <= H && H <= 300.0
			rp = X
			gp = 0.0
			bp = C
		)
		( 300 <= H && H <= 360.0
			rp = C
			gp = 0.0
			bp = X
		)
	)
	
	r = round(255.0*(rp+m))
	g = round(255.0*(gp+m))
	b = round(255.0*(bp+m))

	; just in case, limit from 0 to 255
	;if( r < 0 then r = 0)
	;if( r > 255 then r = 255)
	;if( g < 0 then g = 0)
	;if( g > 255 then g = 255)
	;if( b < 0 then b = 0)
	;if( b > 255 then b = 255)
	
	; return as a list
	;printf(" r=%L  g=%L  b= %L  \n",  r,g,b) 

	list( r g b )
	
)



(defun incrHue (hsl) 
	incrHueBy(hsl, 15) 
)


(defun decrHue (hsl) 
	decrHueBy(hsl, 15) 
)


(defun incrHueBy (hsl, delta) 
	H = nth(0 hsl) + delta
	S = nth(1 hsl)
	L = nth(2 hsl)
	list( H S L )
)


(defun decrHueBy (hsl, delta) 
	H = nth(0 hsl) - delta
	S = nth(1 hsl)
	L = nth(2 hsl)
	list( H S L )
)



(defun incrSaturation (hsl) 
	delta = 0.085
	granularity = 0.005
	S = nth(1 hsl)
	if( S < (1.0 - delta - granularity) then
		hsl = incrSaturationBy(hsl, delta) 
	)
	hsl
)


(defun decrSaturation (hsl) 
	delta = 0.085
	granularity = 0.005
	S = nth(1 hsl)
	if( S > (delta + granularity) then
		hsl = decrSaturationBy(hsl, delta) 
	)
	hsl
)


(defun incrSaturationBy (hsl, delta) 
	H = nth(0 hsl)
	S = nth(1 hsl)
	S = S + delta
	if( S > 1.0 then
		S = 1.0
	)
	L = nth(2 hsl)
	list( H S L )
)



(defun decrSaturationBy (hsl, delta) 
	H = nth(0 hsl)
	S = nth(1 hsl)
	S = S - delta
	if( S < 0.0 then
		S = 0.0
	)
	L = nth(2 hsl)
	list( H S L )
)


(defun incrLightness (hsl) 
	delta = 0.085
	granularity = 0.005
	L = nth(2 hsl)
	if( L < (1.0 - delta - granularity) then
		hsl = incrLightnessBy(hsl, delta) 
	)
	hsl
)


(defun decrLightness (hsl) 
	delta = 0.085
	granularity = 0.005
	L = nth(2 hsl)
	if( L > (delta + granularity) then
		hsl = decrLightnessBy(hsl, delta) 
	)
	hsl
)

(defun incrLightnessBy (hsl, delta) 
	H = nth(0 hsl)
	S = nth(1 hsl)
	L = nth(2 hsl)
	L = L + delta
	if( L > 1.0 then
		L = 1.0
	)
	list( H S L )
)


(defun decrLightnessBy (hsl, delta)
	H = nth(0 hsl)
	S = nth(1 hsl)
	L = nth(2 hsl)
	L = L - delta
	if( L < 0.0 then
		L = 0.0
	)
	list( H S L )
)



(defun rgb2AllegroHSL (rgb) 
	hsl = rgb2hsl(rgb)
	H = round(nth(0 hsl)  / 360 * 240)
	S = round(nth(1 hsl) * 240)
	L = round(nth(2 hsl) * 240)
	list( H S L )
)





(defun updateColorNum (colornum, rgb)
	printf( "new color for color#%L=RGB%L=HSL%L=allegroHSL=%L\n",colornum, rgb, rgb2hsl(rgb),  rgb2AllegroHSL(rgb))
	axlColorSet(colornum rgb)
	axlVisibleUpdate(t)
	axlUIWRedraw(nil)
	axlUIWUpdate(nil)
)



(defun addColorDef (label, hsl, colorFamilies)

	if( symeval('ColorDefinitionsTable)=='unbound then
		ColorDefinitionsTable = makeTable("ColorTable" nil)
		AvailableColorDefinitionsTable = makeTable("ColorTable" nil)		
	)
	
	colordef = make_colordef_t( ?label label ?hsl hsl ?colorFamilies colorFamilies	)
	ColorDefinitionsTable[label] = colordef
	AvailableColorDefinitionsTable[label] = colordef
	colordef
)	



(defun getColorDefByLabel (label)
	ColorDefinitionsTable[label]
)	


; TODO; write this function
(defun reserveAColorDef (excludedColorFamilies)
	AvailableColorDefinitionsTable[""]
)	

(defun reserveColorDefByLabel (label)
	; TODO: check that color exists
	if(label == nil then
		colorDef = nil
	else
		colorDef = ColorDefinitionsTable[label]
	)
	if(colorDef != nil then
		remove(label AvailableColorDefinitionsTable)
	)
	colorDef
)	

(defun returnColorDefByLabel (label)
	; TODO: check that color exists
	AvailableColorDefinitionsTable[label] = ColorDefinitionsTable[label]
)


; TODO; write this function
; return a list of the colors
(defun returnAllColorDefs ()
	AvailableColorDefinitionsTable[""]
)



(defun titleCase (str)
	firstChar = substring(str,1,1)
	theRest = substring(str,2)
	strcat(upperCase(firstChar), lowerCase(theRest))
)
