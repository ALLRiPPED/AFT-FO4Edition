ScriptName AFT:TweakGatherLooseScript extends Quest

FormList Property lootItemsUnique Auto Const
FormList Property TweakLootItemsUnique Auto Const
FormList Property CA_JunkItems Auto Const
FormList Property TweakConstructed_Cont Auto Const
FormList Property TweakNonConstructed_Cont Auto Const
FormList Property TweakGatherLooseContainers Auto Const
FormList Property TweakDedupe1Items Auto Const
FormList Property TweakDedupe2Items Auto Const
FormList Property TweakDedupe3Items Auto Const
FormList Property TweakDedupe4Items Auto Const
FormList Property TweakGatherLoose Auto Const
FormList Property TweakDedupeStackable Auto Const
GlobalVariable Property TweakGatherLooseRadius Auto Const
GlobalVariable Property TweakGatherLooseClean Auto Const
Container Property Arena_Wager_Container Auto Const
Keyword Property ActorTypeTurret Auto Const
Quest Property pFollowers Auto Const
ActorBase Property Player Auto Const
Message Property TweakGatherFeedback Auto Const

ObjectReference[] ownedContainers
ObjectReference[] ownedResults
int[]             ownedCounts
float nextSearchingMsg
int lockedCount
int ownedCount
int gatheredCount
float maxRadius

; TODO: Need to add some more containers:
; - CashRegister
; - AmmoBox
bool Function Trace(string asTextToPrint, int aiSeverity = 0) debugOnly
	string logName = "TweakGatherLooseScript"
	debug.OpenUserLog(logName)
	RETURN debug.TraceUser(logName, asTextToPrint, aiSeverity)
EndFunction

Function GatherLooseItems(ObjectReference targetContainer)
	Trace("GatherLooseItems()")
	
	; Copy the global to a local variable so that processing isn't unexpectedly interrupted
	maxRadius = TweakGatherLooseRadius.GetValue()
	if (!targetContainer)
		AFT:TweakDFScript pTweakDFScript = pFollowers as AFT:TweakDFScript
		if (pTweakDFScript)
			targetContainer = pTweakDFScript.pDogmeatCompanion.GetActorReference() as ObjectReference
			if (!targetContainer)
				targetContainer = pTweakDFScript.pCompanion.GetActorReference() as ObjectReference
			endIf
		endIf
		if (!targetContainer)
			targetContainer = Game.GetPlayer() as ObjectReference
		endIf
	endIf

	if ownedContainers && ownedContainers.length > 0
		ownedContainers.clear()
	endif
	if ownedResults && ownedResults.length > 0
		ownedResults.clear()
	endif
	if ownedCounts && ownedCounts.length > 0
		ownedCounts.clear()
	endif
		
	gatheredCount = 0
	ownedCount = 0
	lockedCount = 0
	
	ObjectReference theContainer = targetContainer.placeAtMe(Arena_Wager_Container, 1, False, False, True)
	If (!theContainer)
		Trace("Unable to Spawn Container")
		return 
	EndIf
	theContainer.SetPosition(targetContainer.GetPositionX(), targetContainer.GetPositionY(), targetContainer.GetPositionZ() - 200)

	AFT:TweakGatherShowSearch searchMsgHandler = (self as Quest) as  AFT:TweakGatherShowSearch
	searchMsgHandler.ShowSearching()

	AddInventoryEventFilter(None)
	RegisterForRemoteEvent(theContainer, "OnItemAdded")
	
	ScanContainersForItems(TweakConstructed_Cont, "TweakConstructed_Cont", theContainer)
	ScanContainersForItems(TweakNonConstructed_Cont, "TweakNonConstructed_Cont", theContainer)
	ScanContainersForItems(TweakGatherLooseContainers, "TweakGatherLooseContainers", theContainer)
	
	ScanDeadActorsForItems(theContainer)
	
	ScanForLooseItems(TweakDedupe1Items,    "TweakDedupe1Items",       targetContainer)
	ScanForLooseItems(TweakDedupe2Items,    "TweakDedupe2Items",       targetContainer)
	ScanForLooseItems(TweakDedupe3Items,    "TweakDedupe3Items",       targetContainer)
	ScanForLooseItems(TweakDedupe4Items,    "TweakDedupe4Items",       targetContainer)
	ScanForLooseItems(TweakDedupeStackable, "TweakDedupeStackable",    targetContainer)
	ScanForLooseItems(TweakGatherLoose,     "TweakGatherLoose",        targetContainer)
	ScanForLooseItems(CA_JunkItems,         "CA_JunkItems",            targetContainer)
	ScanForLooseItems(lootItemsUnique,      "lootItemsUnique",         targetContainer)
	
	Trace("Waiting for events to process...")
	
	; Wait up to 6 seconds for AddItem Queues to finish procesing. 	
	int waitforevents = gatheredCount - 1
	int maxwait = 30
	while (maxwait > 0 && waitforevents < gatheredCount)
		waitforevents = gatheredCount
		Utility.WaitMenuMode(0.2)
		maxwait -= 1
	endWhile
	
	if (0 == maxwait)
		Trace("Warning : Event Processing Timed Out. Proceeding anyway...")
	else
		Trace("Event Processing Complete")
	endIf
	
	if ownedContainers
		int ownedContainerLen = ownedContainers.length
		If (ownedContainerLen > 0)
			Trace("Owned Items Detected [" + ownedContainerLen as string + "]. Restoring")
			int i = 0
			while (i < ownedContainerLen)
				if (ownedContainers[i])
					theContainer.RemoveItem(ownedResults[i], ownedCounts[i], True, ownedContainers[i])
				endIf
				i += 1
			endWhile
		endIf
	endif
	
	theContainer.RemoveAllItems(targetContainer, False)
	Utility.WaitMenuMode(0.1)
	
	; Wait up to 6 seconds for intermediate container to transfer items to target Container
	maxwait = 30
	while (maxwait > 0 && theContainer.GetItemCount(None) > 0)
		Utility.WaitMenuMode(0.2)
		maxwait -= 1
	endWhile
	if (0 == maxwait)
		Trace("Warning : Not all loot removed from theContainer")
		Utility.WaitMenuMode(0.3)
		theContainer.Disable(False)
	else
		theContainer.Disable(False)
		theContainer.Delete()
	endIf
	theContainer = None
	
	if ownedContainers && ownedContainers.length > 0
		ownedContainers.clear()
	endif
	if ownedResults && ownedResults.length > 0
		ownedResults.clear()
	endif
	if ownedCounts && ownedCounts.length > 0
		ownedCounts.clear()
	endif
	
	RemoveAllInventoryEventFilters()
	searchMsgHandler.StopShowSearching()	
	TweakGatherFeedback.Show(gatheredCount, ownedCount, lockedCount)
	
EndFunction

Function ScanContainersForItems(FormList containers, string name, ObjectReference target)
	Trace("ScanContainersForItems [" + name + "]...")
	
	ObjectReference[] results = None
	ObjectReference result = None
	Actor pc = Game.GetPlayer()	
	ObjectReference center = pc as ObjectReference
	
	Trace("Scanning [" + name + "]...")
	results = center.FindAllReferencesOfType(containers, maxRadius)
	int numresults = results.length
	Trace("Scan [" + name + "] Complete: [" + numresults + "] container objects found", 0)
	
	int i = 0
	ObjectReference containedin = None
	bool keepit = True
	
	if (None == target)
		target = center
	endIf
	
	float yield = 0
	
	while (i < numresults)
		keepit = True
		result = results[i]
		if (result)
			Trace("Found Container [" + result + "] IsLocked [" + result.IsLocked() + "] Lock Level [" + result.GetLockLevel() + "]")
			if (result.IsLocked())
				Trace("Rejected: Container is Locked [" + result.GetLockLevel() + "]")
				keepit = False
				lockedCount += 1
			elseIf (0 == result.GetItemCount(None))
				Trace("Rejected: Container is Empty")
				keepit = False
			else
				Actor owner = result.GetActorRefOwner()
				ActorBase ownerBase = result.GetActorOwner()
				if (owner)
					if (owner.GetFactionReaction(pc) > 1)
						Trace("Accepted: Container Owner is Ally to player")
					else
						Trace("Rejected: Container owned By Another Actor")
						keepit = False
					endIf
				elseif (ownerBase)
					if (ownerBase == Player)
						Trace("Accepted: Container owner is Player")
					else
						Trace("Rejected: Container owned By another Actor Base")
						keepit = False
					endIf
				else
					Faction ownerFaction = result.GetFactionOwner()
					if (ownerFaction)
						if (pc.IsInFaction(ownerFaction))
							Trace("Accepted: Player member of container owning Faction")
						elseIf (ownerFaction.GetFactionReaction(pc) > 1)
							Trace("Accepted: Container Faction is Ally to player")
						else
							Trace("Rejected: Container Faction isn't associated with Player")
							keepit = False
						endIf
					endIf
				endIf
				if (!keepit)
					ownedCount += 1
				endIf
			endIf
			if (keepit)
				Trace("Storing Items to Eval Bin")
				result.RemoveAllItems(target, True)
				; I would prefer to yield later, but if we wait too long, the 
				; item is removed and the result coming into the container is None
				; (And you can't check for ownership on None objects)
				; Utility.wait(0.01)
				
				; yield += 1.0
			endIf
		endIf
		i += 1
	endWhile
	
	; The OnItemEventHandlers are on THIS SCRIPT. So they can't get
	; called unless we yield. Papyrus to Engine command syncs happen 
	; in batches sent/received every 0.03 seconds. 
;	if (0 != yield)
;		Trace("Processing Eval Bin")
;		float total = (yield * 0.3)
;		if total > 1.5
;			total = 1.5
;		endIf
;		Utility.wait(total)
;	endif
	
	
endFunction

Function ScanDeadActorsForItems(ObjectReference target)
	Trace("ScanActorsForItems [" + target as string + "]...")
	bool gatherLooseCleanup = (1.0 == TweakGatherLooseClean.GetValue())
	
	FormList TweakActorTypes = Game.GetFormFromFile(0x01025B3B, "AmazingFollowerTweaks.esp") as FormList
	Actor pc = Game.GetPlayer()
	
	if (None == target)
		target = pc as ObjectReference
	endIf
			
	ObjectReference[] nearby = None
	Actor npc = None
	int nsize = 0
	int j = 0
	
	ObjectReference opc = pc as ObjectReference
	int numTypes = TweakActorTypes.GetSize()
	int i = 0
	
	float yield = 0
	
	while (i < numTypes)
		nearby = pc.FindAllReferencesWithKeyword(TweakActorTypes.GetAt(i), maxRadius)
		if (0 != nearby.length)
			nsize = nearby.length
			Trace("Found [" + nsize + "] [" + TweakActorTypes.GetAt(i) + "] nearby ", 0)
			j = 0
			while (j < nsize)
				npc = nearby[j] as Actor
				if (npc as bool && npc.IsDead())
					if (0 != npc.GetItemCount(None))
						Trace("Dead actor [" + npc + "] within " + maxRadius + " of player with items. Looting")
						npc.RemoveAllItems(target, False)
					endif
					if gatherLooseCleanup
						npc.SetPosition(0,0,10)
						npc.Disable()
						npc.Delete()
					endif
					; Utility.wait(0.01)
					; yield += 1.0
				else
					Trace("Rejected: Actor is Alive or Has No Items")
				endIf
				j += 1
			endWhile
		endIf
		i += 1
	endWhile
	
	; Handle Turrets
	nearby = pc.FindAllReferencesWithKeyword(ActorTypeTurret, maxRadius)
	if (0 != nearby.length)
		nsize = nearby.length
		Trace("Found [" + nsize + "] [ActorTypeTurret] nearby ")
		j = 0
		while (j < nsize)
			npc = nearby[j] as Actor
			if (npc && npc.IsDead() && 0 != npc.GetItemCount(None))
				Trace("Broken Turret [" + npc + "] within " + maxRadius + " of player with items. Looting")
				npc.RemoveAllItems(target, True)
				Utility.wait(0.01)
				; yield += 1.0
			else
				Trace("Rejected: Turret is Active or Has No Items")
			endIf
			j += 1
		endWhile
	endIf

	; The OnItemEventHandlers are on THIS SCRIPT. So they can't get
	; called unless we yield. Papyrus to Engine command syncs happen 
	; in batches sent/received every 0.03 seconds. 
;	if (0 != yield)
;		float total = (yield * 0.3)
;		if total > 1.5
;			total = 1.5
;		endIf
;		Utility.wait(total)
;	endif
	
	
EndFunction

Function ScanForLooseItems(FormList list, string name, ObjectReference target)
	Trace("ScanForLooseItems [" + name + "]")
	
	if (list == None)
		Trace(name + " is None")
		return 
	endIf
	
	ObjectReference[] results = None
	ObjectReference result = None
	Actor pc = Game.GetPlayer()
	ObjectReference center = pc as ObjectReference
	
	if (None == target)
		target = center
	endIf
	
	results = center.FindAllReferencesOfType(list, maxRadius)
	
	int numresults = results.length
	if (numresults < 1)
		return 
	endIf
	Trace("Found [" + numresults + "] objects found")
	
	int i = 0
	ObjectReference containedin = None
	bool keepit = True
	while (i < numresults)
		keepit = True
		result = results[i]
		if result.IsEnabled()
			Actor owner = result.GetActorRefOwner()
			ActorBase ownerBase = result.GetActorOwner()
			if (owner)
				if (owner.GetFactionReaction(pc) > 1)
					Trace("Accepted: Loose item owner is Ally to player")
				else
					Trace("Rejected: Loose item owned By Another Actor")
					keepit = False
				endIf
			elseif (ownerBase)
				if (ownerBase == Player)
					Trace("Accepted: Loose item owned by Player")
				else
					Trace("Rejected: Loose item owned By another Actor Base")
					keepit = False
				endIf
			else
				Faction ownerFaction = result.GetFactionOwner()
				if (ownerFaction)
					if (pc.IsInFaction(ownerFaction))
						Trace("Accepted: Player member of container owning Faction")
					elseIf (ownerFaction.GetFactionReaction(pc) > 1)
						Trace("Accepted: Container Faction is Ally to player")
					else
						Trace("Rejected: Loose item not associated with Player Faction")
						keepit = false
					endIf
				else
					; Delimma... No ActorRefOwner, No ActorBaseOwner and now Faction Owner. Should we assume unowned?
					Trace("Accepted: Unable to determined ownership. Assuming unowned.")
				endIf
			endIf
			if (keepit)
				if (result.IsQuestItem())
					Trace("Rejected : Is Quest Item")
					keepit = False
				endIf
			else
				ownedCount += 1
			endIf
			if (keepit)
				containedin = result.GetContainer()
				if (containedin)
					if (center == containedin)
						Trace("Rejected: Container is Player")
						keepit = False
					elseIf (containedin as Actor)
						if !(containedin as Actor).IsDead()
							Trace("Rejected: Container is Actor [" + (containedin as Actor) + "]")
							keepit = False
						endif
					elseIf (containedin.IsLocked())
						Trace("Rejected: Container is Locked [" + containedin.GetLockLevel() + "]")
						lockedCount += 1
						keepit = False
					endIf
				endIf
			endIf
			if (keepit)
				gatheredCount += 1
				Form akBaseItem = result.GetBaseObject()
				if (TweakLootItemsUnique.HasForm(akBaseItem))
					Trace("Redirected: Is UNQIUE Item")
					pc.AddItem(result, 1, True)
				else
					target.AddItem(result, 1, True)
				endIf
				result.Disable()				
			endIf
		endif
		i += 1
	endWhile
endFunction

Event ObjectReference.OnItemAdded(ObjectReference theContainer, Form akBaseItem, int aiItemCount, ObjectReference result, ObjectReference akSourceContainer)
	Trace("OnItemAdded: theContainer [" + theContainer + "] akBaseItem [" + akBaseItem + "] aiItemCount [" + aiItemCount + "] result [" + result + "]")
		
	; Do we keep it? Return it? Or Redirect to the player?
	; 1) Quest and Unique status Trump ownership
	if ((None != akBaseItem) && (TweakLootItemsUnique.HasForm(akBaseItem)))
		Trace("OnItemAdded - Redirected: [" + akBaseItem + "] Is Unique Item")
		theContainer.RemoveItem(akBaseItem, aiItemCount, False, Game.GetPlayer())
		gatheredCount += aiItemCount
		return
	else
		Trace("OnItemAdded - Not found in TweakLootItemsUnique.")				
	endIf
	
	; Can't test for unique or ownership unless there is an instance pointer:	
	if (result)
	
		Actor pc = Game.GetPlayer()
		Trace("Checking Quest Status")				
		if (result.IsQuestItem())
			Trace("OnItemAdded - Redirected: Is Quest Item")
			theContainer.RemoveItem(akBaseItem, aiItemCount, False, pc)
			gatheredCount += aiItemCount
			return
		else
			Trace("OnItemAdded - Item [" + akBaseItem + "] Not reporting quest item")				
		endIf

		bool keepit = False
		Actor owner = result.GetActorRefOwner()
		if (owner)
			if (owner.GetFactionReaction(pc) > 1)
				Trace("OnItemAdded - Accepted: Item owner is Ally to player")
				keepit = True
			else
				Trace("OnItemAdded - Rejected: Item owned By Another Actor")
			endIf
		else
			Trace("OnItemAdded : No ActorRefOwner")				
			ActorBase ownerBase = result.GetActorOwner()
			if (ownerBase)
				if (ownerBase == Player)
					Trace("OnItemAdded - Accepted: Item owned by Player")
					keepit = True
				else
					Trace("OnItemAdded - Loose item owned By another Actor Base")
				endIf
			else
				Trace("OnItemAdded : No ActorOwner")				
			endIf
		endIf
		if (!keepit)
			Faction ownerFaction = result.GetFactionOwner()
			if (ownerFaction)
				if (pc.IsInFaction(ownerFaction))
					Trace("OnItemAdded - Accepted: Player member of item owning Faction")
					keepit = True
				elseIf (ownerFaction.GetFactionReaction(pc) > 1)
					Trace("OnItemAdded - Accepted: Item Faction is Ally to player")
					keepit = True
				endIf
			else
				; Delimma... No ActorRefOwner, No ActorBaseOwner and no Faction Owner. Should we assume unowned?
				Trace("Rejected: Unable to determined ownership. Assuming unowned.")
			endIf
		endIf		
		if (!keepit)
			Trace("OnItemAdded - Rejecting item [" + akBaseItem + "] as owned...")
			ownedCount += 1
			ownedContainers.add(akSourceContainer, 1)
			ownedResults.add(result, 1)
			ownedCounts.add(aiItemCount, 1)
			return 
		endIf
	endIf
	gatheredCount += aiItemCount
endEvent
