Scriptname AFT:TweakScanCFloorsScript extends Quest

; import AFT

Quest Property TweakScrapScanMaster Auto Const
FormList Property TweakConstructed_Floors Auto Const

GlobalVariable   Property pTweakSettlementSnap Auto Const

GlobalVariable   Property pTweakScanThreadsDone Auto
GlobalVariable[] Property ResultArray Auto
GlobalVariable   Property pTweakScrapAll Auto Const

Struct ComponentData
	int formid    = 0
	int mask    = 0
	int counts  = 0
	string name = ""
EndStruct

ComponentData[] Property ComponentLookup Auto

bool Function Trace(string asTextToPrint, int aiSeverity = 0) debugOnly
	string logName = "TweakScanCFloorsScript"
	debug.OpenUserLog(logName)
	RETURN debug.TraceUser(logName, asTextToPrint, aiSeverity)
EndFunction

Event OnInit()
	initialize_ResultArray()
	allocate_ComponentData()
	initialize_ComponentData()
	
	; PASTE python generated component data without form ids in initialize_ComponentData
	; Uncomment out this loop. Start up game and load mod. Then quit and copy code
	; WITH form ids from log file back into the initialize_ComponentData method
	; below. Recomment this loop. Walla...
	
	
	; string code = "\n"
	; int i = 0
	; while i < 100
		; code += "    ComponentLookup[" + i + "].formid = " + TweakConstructed_Floors.GetAt(i).GetFormID() + "\n"
		; code += "    ComponentLookup[" + i + "].mask = " + ComponentLookup[i].mask + "\n"
		; code += "    ComponentLookup[" + i + "].counts = " + ComponentLookup[i].counts + "\n"
		; code += "    ComponentLookup[" + i + "].name = \"" + ComponentLookup[i].name + "\"\n"
		; i += 1
	; endWhile
	; Trace(code)
	
EndEvent

ObjectReference center
float radius

Function Scan(ObjectReference p_center, float p_radius)
	Trace("Scan Called, Starting Timer")
	center = p_center
	radius = p_radius 
	startTimer(0.0) ; Basically this is the same thing as FORK....
EndFunction

Event OnTimer(int aiTimerID)
	Trace("Timer Fired. Calling ScanHelper")
	ScanHelper()
EndEvent

Function ScanHelper()
	Trace("ScanHelper Called")
	
	ObjectReference[] results
	ObjectReference result
	ComponentData lookupResult
	
	Trace("Scanning...")
	results = center.FindAllReferencesOfType(TweakConstructed_Floors, radius)			
	int numresults = results.length
	
	Trace("Scanning Complete: [" + numresults + "] objects found")
	center = None	
	if (0 == numresults)
		pTweakScanThreadsDone.mod(-1.0)
		return
	endif
	
	; Tracking:
	int lookupsuccess     = 0
	int lookupindex       = 0
	int[] scrapdata = new int[31]	
	int i = 0
	while (i < 31)
		scrapdata[i] = 0
		i += 1
	endwhile
	
	ComponentData lookup
	
	; mask   : There are 31 component types. So we use a 32bit bitmask 
	;          to identify up to 5 components. (Max of 5)
	;          This bits correspond to the index of the formlist TweakScrapComponents.
	;          The formlist is optimized so that the most frequent components appear
	;          first. This helps minimize the number of mod operations we have to 
	;          perform to isolate the last bit. 
	int mask
	
	; counts : We store five 6 bit numbers (max value = 64) using the first 30
	;          bits of the 32 bit int. These correspond to the elements
	;          found in the mask from first to last...  
	int counts
	
	Form rbase	
	int bit
	int offset
	int rid
	int count
	bool keepgoing = true

	bool snapshot = (1.0 == pTweakSettlementSnap.GetValue())
	bool scrapall = (1.0 == pTweakScrapAll.Getvalue())
	Var[] params = new Var[10]
	AFT:TweakScrapScanScript ScrapScanMaster = TweakScrapScanMaster as AFT:TweakScrapScanScript
	
	i = 0
	while (i != numresults && keepgoing)
		result = results[i]
		if scrapall
			result.SetPosition(0,0,10)
			result.Disable()
			result.Delete()
		elseif (!result.IsDisabled())
			rbase = result.GetBaseObject()
			rid   = rbase.GetFormID()
			lookupindex = ComponentLookup.FindStruct("formid",rid)
			if (lookupindex > -1)
				lookup = ComponentLookup[lookupindex]
		
				lookupsuccess += 1
				if snapshot
			
					params[0] = lookup.name
					params[1] = rid
					params[2] = result.GetPositionX()
					params[3] = result.GetPositionY()
					params[4] = result.GetPositionZ()
					params[5] = result.GetAngleX()
					params[6] = result.GetAngleY()
					params[7] = result.GetAngleZ()
					params[8] = result.GetScale()
					params[9] = -1
					Trace("Adding Components [" + lookup.name + "] to scrapdata")
					ScrapScanMaster.CallFunctionNoWait("TweakBuildInfo", params)
				
				else			
					result.SetPosition(0,0,10)
					result.Disable()
					result.Delete()
					Trace("Adding Scrap [" + lookup.name + "] to scrapdata")
				endif
			
				mask   = lookup.mask
				counts = lookup.counts
				bit    = 0
				offset = 0
				count  = 0

				while (mask > 0 && offset < 31)
					bit  = mask % 2                     ; isolate least significant bit
					mask = ((mask / 2) as Int)          ; shift right 1
					if (bit == 1)
						count = counts % 64             ; isolate last 6 bits
						counts = ((counts / 64) as Int) ; shift right 6 (64 = 2^6)
						scrapdata[offset] += count
					endif
					offset += 1
				endWhile
			endif
		endif
		i += 1
		if (0 == (i % 30))
			keepgoing = (pTweakScanThreadsDone.GetValue() > 0.0)
		endif
	endwhile
	if (0 == lookupsuccess)
		pTweakScanThreadsDone.mod(-1.0)
		return
	endif
	pTweakScanObjectsFound.mod(lookupsuccess)
	
	i = 0
	while (i < 31)
		if scrapdata[i] != 0
			Trace("Adding [" + scrapdata[i] + "] to ResultArray [" + i + "]")
			ResultArray[i].mod(scrapdata[i])
		endif
		i += 1
	endwhile
	
	pTweakScanThreadsDone.mod(-1.0)
		
EndFunction

Function initialize_ResultArray()
	ResultArray = new GlobalVariable[31]

	ResultArray[0]  = pTweakScanSteelFound
	ResultArray[1]  = pTweakScanWoodFound
	ResultArray[2]  = pTweakScanRubberFound
	ResultArray[3]  = pTweakScanClothFound
	ResultArray[4]  = pTweakScanPlasticFound
	ResultArray[5]  = pTweakScanCopperFound
	ResultArray[6]  = pTweakScanScrewsFound
	ResultArray[7]  = pTweakScanGlassFound
	ResultArray[8]  = pTweakScanAluminumFound
	ResultArray[9]  = pTweakScanCeramicFound
	ResultArray[10] = pTweakScanCircuitryFound
	ResultArray[11] = pTweakScanConcreteFound
	ResultArray[12] = pTweakScanGearsFound
	ResultArray[13] = pTweakScanOilFound
	ResultArray[14] = pTweakScanAdhesiveFound
	ResultArray[15] = pTweakScanSpringsFound
	ResultArray[16] = pTweakScanNuclearMaterialFound
	ResultArray[17] = pTweakScanFertilizerFound
	ResultArray[18] = pTweakScanFiberOpticsFound
	ResultArray[19] = pTweakScanFiberglassFound
	ResultArray[20] = pTweakScanBoneFound
	ResultArray[21] = pTweakScanAcidFound
	ResultArray[22] = pTweakScanAsbestosFound
	ResultArray[23] = pTweakScanCrystalFound
	ResultArray[24] = pTweakScanLeadFound
	ResultArray[25] = pTweakScanLeatherFound
	ResultArray[26] = pTweakScanAntiBallisticFiberFound
	ResultArray[27] = pTweakScanAntisepticFound
	ResultArray[28] = pTweakScanCorkFound
	ResultArray[29] = pTweakScanSilverFound
	ResultArray[30] = pTweakScanGoldFound
EndFunction

Function allocate_ComponentData()
	ComponentLookup = new ComponentData[25]
	int i = 0
	while (i < ComponentLookup.length)
		ComponentLookup[i] = new ComponentData
		i += 1
	endWhile
EndFunction

Function initialize_ComponentData()

    ; Array co-insides with FORMLIST. This was generated using Python.

    ComponentLookup[0].formid = 967986
    ComponentLookup[0].mask = 3
    ComponentLookup[0].counts = 578
    ComponentLookup[0].name = "workshop_ShackBalconyStairs01"
    ComponentLookup[1].formid = 920495
    ComponentLookup[1].mask = 3
    ComponentLookup[1].counts = 386
    ComponentLookup[1].name = "workshop_ShackBridge01"
    ComponentLookup[2].formid = 1044976
    ComponentLookup[2].mask = 3
    ComponentLookup[2].counts = 202
    ComponentLookup[2].name = "workshop_ShackMetalMidRoof01"
    ComponentLookup[3].formid = 1044977
    ComponentLookup[3].mask = 3
    ComponentLookup[3].counts = 202
    ComponentLookup[3].name = "workshop_ShackMetalMidRoof02"
    ComponentLookup[4].formid = 920456
    ComponentLookup[4].mask = 3
    ComponentLookup[4].counts = 514
    ComponentLookup[4].name = "workshop_ShackMidFloor01"
    ComponentLookup[5].formid = 1048668
    ComponentLookup[5].mask = 2050
    ComponentLookup[5].counts = 204
    ComponentLookup[5].name = "workshop_ShackMidFloor01Foundation"
    ComponentLookup[6].formid = 2279011
    ComponentLookup[6].mask = 3
    ComponentLookup[6].counts = 771
    ComponentLookup[6].name = "workshop_ShackMidFloor01Foundation02"
    ComponentLookup[7].formid = 920457
    ComponentLookup[7].mask = 3
    ComponentLookup[7].counts = 450
    ComponentLookup[7].name = "workshop_ShackMidFloor02"
    ComponentLookup[8].formid = 967984
    ComponentLookup[8].mask = 3
    ComponentLookup[8].counts = 514
    ComponentLookup[8].name = "workshop_ShackMidFloorToRoof01"
    ComponentLookup[9].formid = 920458
    ComponentLookup[9].mask = 3
    ComponentLookup[9].counts = 198
    ComponentLookup[9].name = "workshop_ShackMidRoof01"
    ComponentLookup[10].formid = 920459
    ComponentLookup[10].mask = 3
    ComponentLookup[10].counts = 198
    ComponentLookup[10].name = "workshop_ShackMidRoof01Hole01"
    ComponentLookup[11].formid = 920460
    ComponentLookup[11].mask = 3
    ComponentLookup[11].counts = 262
    ComponentLookup[11].name = "workshop_ShackMidRoof02"
    ComponentLookup[12].formid = 920461
    ComponentLookup[12].mask = 3
    ComponentLookup[12].counts = 262
    ComponentLookup[12].name = "workshop_ShackMidRoof02Hole01"
    ComponentLookup[13].formid = 920462
    ComponentLookup[13].mask = 3
    ComponentLookup[13].counts = 262
    ComponentLookup[13].name = "workshop_ShackMidRoof02Hole02"
    ComponentLookup[14].formid = 920463
    ComponentLookup[14].mask = 3
    ComponentLookup[14].counts = 326
    ComponentLookup[14].name = "workshop_ShackMidRoof03"
    ComponentLookup[15].formid = 920464
    ComponentLookup[15].mask = 3
    ComponentLookup[15].counts = 326
    ComponentLookup[15].name = "workshop_ShackMidRoof03Hole01"
    ComponentLookup[16].formid = 920465
    ComponentLookup[16].mask = 3
    ComponentLookup[16].counts = 326
    ComponentLookup[16].name = "workshop_ShackMidRoof03Hole02"
    ComponentLookup[17].formid = 920466
    ComponentLookup[17].mask = 11
    ComponentLookup[17].counts = 20802
    ComponentLookup[17].name = "workshop_ShackMidRoof04"
    ComponentLookup[18].formid = 920467
    ComponentLookup[18].mask = 11
    ComponentLookup[18].counts = 24834
    ComponentLookup[18].name = "workshop_ShackMidRoof05"
    ComponentLookup[19].formid = 924241
    ComponentLookup[19].mask = 3
    ComponentLookup[19].counts = 771
    ComponentLookup[19].name = "workshop_ShackMidStairwell01"
    ComponentLookup[20].formid = 1114112
    ComponentLookup[20].mask = 3
    ComponentLookup[20].counts = 650
    ComponentLookup[20].name = "workshop_ShackPrefabMid01"
    ComponentLookup[21].formid = 1114113
    ComponentLookup[21].mask = 3
    ComponentLookup[21].counts = 650
    ComponentLookup[21].name = "workshop_ShackPrefabMidTop01"
    ComponentLookup[22].formid = 920497
    ComponentLookup[22].mask = 3
    ComponentLookup[22].counts = 450
    ComponentLookup[22].name = "workshop_ShackStairs01"
    ComponentLookup[23].formid = 920498
    ComponentLookup[23].mask = 3
    ComponentLookup[23].counts = 450
    ComponentLookup[23].name = "workshop_ShackStairs02"
    ComponentLookup[24].formid = 920499
    ComponentLookup[24].mask = 3
    ComponentLookup[24].counts = 450
    ComponentLookup[24].name = "workshop_ShackSteps01"	
		
EndFunction

GlobalVariable Property pTweakScanAcidFound Auto Const
GlobalVariable Property pTweakScanAdhesiveFound Auto Const
GlobalVariable Property pTweakScanRubberFound Auto Const
GlobalVariable Property pTweakScanScrewsFound Auto Const
GlobalVariable Property pTweakScanAluminumFound Auto Const
GlobalVariable Property pTweakScanAntiBallisticFiberFound Auto Const
GlobalVariable Property pTweakScanAntisepticFound Auto Const
GlobalVariable Property pTweakScanAsbestosFound Auto Const
GlobalVariable Property pTweakScanBoneFound Auto Const
GlobalVariable Property pTweakScanCeramicFound Auto Const
GlobalVariable Property pTweakScanCircuitryFound Auto Const
GlobalVariable Property pTweakScanClothFound Auto Const
GlobalVariable Property pTweakScanConcreteFound Auto Const
GlobalVariable Property pTweakScanCopperFound Auto Const
GlobalVariable Property pTweakScanCorkFound Auto Const
GlobalVariable Property pTweakScanCrystalFound Auto Const
GlobalVariable Property pTweakScanFertilizerFound Auto Const
GlobalVariable Property pTweakScanFiberglassFound Auto Const
GlobalVariable Property pTweakScanFiberOpticsFound Auto Const
GlobalVariable Property pTweakScanSteelFound Auto Const
GlobalVariable Property pTweakScanSilverFound Auto Const
GlobalVariable Property pTweakScanGearsFound Auto Const
GlobalVariable Property pTweakScanGlassFound Auto Const
GlobalVariable Property pTweakScanGoldFound Auto Const
GlobalVariable Property pTweakScanSpringsFound Auto Const
GlobalVariable Property pTweakScanLeadFound Auto Const
GlobalVariable Property pTweakScanLeatherFound Auto Const
GlobalVariable Property pTweakScanWoodFound Auto Const
GlobalVariable Property pTweakScanPlasticFound Auto Const
GlobalVariable Property pTweakScanNuclearMaterialFound Auto Const
GlobalVariable Property pTweakScanOilFound Auto Const
GlobalVariable Property pTweakScanObjectsFound Auto Const

