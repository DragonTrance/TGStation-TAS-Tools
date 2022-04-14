GLOBAL_DATUM_INIT(TAS_MANAGER, /datum/tas_manager, new)

//Get it? Task manager? Eh

/*
	My current TODO:
	1.) Basic bitch input shit from file.
		- SLEEP or WAIT some deciseconds
		- MOVE NORTH or UP ?
		- Read from basic file
		- Create a basic script of moving in the 4 directions and run it when the round starts
		- Don't disable hub options. It's possible to get 2 players going with some sort of thing and doing a dumb tas like it's a smash bros tournament
			Normal File i guess?:
			WAIT 50 //5 seconds
			MOVE UP
			WAIT 50
			MOVE LEFT
	2.) Ability to record to the file mentioned above. Support for multiple files in the future.
		- Add a TAS tab in the stat panel, Simple toggle verb to decide if we're recording or playing. Again, simple shit.
	3.) Option to save and record files with different names, changed in TAS tab.
		- Option to change the file name when recording to something else.
		- Option to change the file that the server is playing from. Use flist() to get folder contents and display a tgui list of everything that's a txt file in the folder.
	4.) Verbs to disable recording or input entirely when the round starts.
*/

/* This is how this datum currently runs:
 * First, get new()'d from global vars initialization
 * Then run a loop, handled by RunLoop().
 * This loop watches and records keyboard inputs and mouse inputs when a certain client decides to play a recorded TAS project.
 * (TODO: Pausing and playing)
 * If there's a runtime somewhere (i.e. the loop stops), this acts like a cheap failsafe system for itself, and infinitely creates a new datum every time it runtimes.
 * Recreating the datum should provide easy customizability for people who want to add their own code.
 * An admin can cancel the loop by setting looping = 0 in the VV window for this datum, and resume it again by setting looping = 1.
*/
/datum/tas_manager
	var/last_client_length = 0 //Used for assessing whether or not we're watching a new client's inputs
	var/list/clients = list()
	
	var/looping = TRUE //Similar to defcon in the failsafe SS. Doesn't make us create a new tas_manager if we prematurely end the main loop
	var/already_looping = FALSE //Same as looping var, but prevents admins from calling Loop() when it's already running through a loop.
	var/admin_usr //The first admin that tried to call Loop(). We message the admin when the Loop() starts again.

/datum/tas_manager/New()
	Initialize()
	RunLoop() //The main loop

//Handles when we get created. Essentially initializes vars, and recovers them if GLOB.TAS_MANAGER is already there
/datum/tas_manager/proc/Initialize()
	HandleRecovery()
	RegisterClients()

//This loop watches all currently-connected clients and records their input
/datum/tas_manager/proc/Loop()
	. = -looping //0 or -1. Derived from looping var in case this was admin proccalled
	if(already_looping)
		to_chat(usr, span_warning("This operation could not be completed. Loop() is already being called. It will be called when next available."))
		admin_usr = usr
		return 1
	while(TRUE)
		already_looping = TRUE
		if(QDELETED(src))
			return
		if(LAZYLEN(GLOB.clients) != last_client_length) //If the connected players changed since our last tick
			last_client_length = LAZYLEN(GLOB.clients)
			RegisterClients()

		for(var/client/client in clients)
			var/datum/tas_sequence/sequence = clients[client.ckey]
			switch(sequence.setting)
				if(SETTING_RECORDING)
					HandleSequenceRecord(sequence)
				if(SETTING_PLAYING)
			sequence.sequence["[world.time]"] = client.keys_held + client.key_combos_held
		
		//Should always be at the end just before the sleep()
		if(!looping)
			return 0
		
		stoplag(0) //This is used to wait a world tick until running again

//This proc records the client's keyboard and mouse input into the appropriate tas_sequence datum.
//This doesn't record if there was no change between this tick and the last tick
/datum/tas_manager/proc/HandleSequenceRecord(datum/tas_sequence/sequence)
	//First, get some vars, and compare them with the sequence's last-recorded stuff.
	//If our stuff is the same with the sequence, set world.time to last_nohold, and to first_nohold only if it's null
	var/we_are_the_same = TRUE

	//Mouse Modifiers first. Things like if the client is clicking, and where the position is
	var/list/modifiers = params2list(client.mouseParams)
	var/list/sequence_modifiers = params2list(sequence.last_mouse_params)
	var/list/mouse_positions = list(text2num(LAZYACCESS(modifiers, ICON_X)), text2num(LAZYACCESS(modifiers, ICON_Y)))
	var/list/sequence_positions = list(text2num(LAZYACCESS(sequence_modifiers, ICON_X)), text2num(LAZYACCESS(modifiers, ICON_Y)))
	if(!compare_list(mouse_positions, sequence_positions) && sequence.handle_mouse)
		we_are_the_same = FALSE
	var/list/client_keys_held = client.keys_held
	var/list/sequence_keys_held = sequence.last_keys_held
	if(!compare_list(client_keys_held, sequence_keys_held))
		we_are_the_same = FALSE
	
	//If we ended up the same, simply update the vars we're watching over
	if(we_are_the_same)
		if(!sequence.first_nohold)
			first_nohold = world.time
		last_nohold = world.time
		return
	
	//Otherwise, set a list that watches empty changes
	else
		if(sequence.first_nohold)
			sequence.nohold_times += list("[sequence.first_nohold-sequence.created_worldtime]" = "[sequence.last_nohold-sequence.created_worldtime]")
		sequence.first_nohold = null
		sequence.last_nohold = null
	
	//Next, get the appropriate keybind datums for the keys currently being held
	var/list/appropriate_keybinds = list()
	for(var/key in client_keys_held)
		//The stuff below is copied from keyDown code, since this is how keybindings are found
		var/AltMod = client_keys_held["Alt"] ? "Alt" : ""
		var/CtrlMod = client_keys_held["Ctrl"] ? "Ctrl" : ""
		var/ShiftMod = client_keys_held["Shift"] ? "Shift" : ""
		var/full_key
		switch(key)
			if("Alt", "Ctrl", "Shift")
				full_key = "[AltMod][CtrlMod][ShiftMod]"
			else
				if(AltMod || CtrlMod || ShiftMod)
					full_key = "[AltMod][CtrlMod][ShiftMod][_key]"
					key_combos_held[_key] = full_key
				else
					full_key = _key
		//Add the keybindings now. Since you can have multiple binds assigned to a single key
		for(var/kb_name in sequence.client_reference.prefs.key_bindings_by_key[full_key])
			appropriate_keybinds += GLOB.keybindings_by_name[kb_name]
	
	//Update the sequence's variables with our current ones, and finish here
	sequence.sequence += list("[world.time-sequence.created_worldtime]" = list(appropriate_keybinds, modifiers))


//This proc looks inside the sequence's.. sequence... and forces keybindings to activate, and the mouse to do shit
/datum/tas_manager/proc/HandleSequencePlayback(datum/tas_sequence/sequence)
	usr = sequence.client_reference?.mob //This is needed to make sure things work correctly. Since we're technically forcing the user to do these actions, but not really. It's finnicky.
	var/current_time = world.time-sequence.created_worldtime
	var/list/keybindings_to_activate = sequence.sequence["[current_time]"]

	//TODO: Write code for clicking on shit.
	//BYOND handles clicking through its internal proc Click(), not shown in stddef.dm. Ask on the byond forums how to call it and hope to god someone responds


/datum/tas_manager/proc/RunLoop()
	if(IsAdminAdvancedProcCall())
		return
	switch(Loop()) //Run the actual loop, and handle shit when we error
		if(-1) //Runtimed or errored.
			new/datum/tas_manager
			return
		if(0) //An admin made us stop looping, so wait until we need to again
			UNTIL(!looping)
		if(1) //An admin called Loop(). The Loop() proc sends the message that it's in use, this proc sends a message when it next becomes available.
			if(!admin_usr)
				admin_usr = usr
			UNTIL(!already_looping)
			message_admins("[key_name(admin_usr)] called Loop() on the global tas_manager while it was looping. It has finished, so it will be called again. looping==[looping].")
			admin_usr = null
	already_looping = FALSE
	if(!QDELETED(src))
		RunLoop()

/datum/tas_manager/proc/HandleRecovery()
	. = RecoverVars() //Try and copy over the vars from the old TAS_MANAGER into the new one.
	if(GLOB.TAS_MANAGER != src) //Not if it's already us, though
		qdel(GLOB.TAS_MANAGER)
		GLOB.TAS_MANAGER = src

/datum/tas_manager/proc/RecoverVars()
	if(!GLOB.TAS_MANAGER)
		return FALSE
	clients = list()
	last_client_length = GLOB.TAS_MANAGER.last_client_length
	clients = GLOB.TAS_MANAGER.clients.Copy()

	looping = GLOB.TAS_MANAGER.looping
	already_looping = FALSE
	admin_usr = null

	return TRUE

//Register every client in the server to our vars, create shit for them, and whatnot.
//Returns FALSE if one of them somehow ends up failing.
/datum/tas_manager/proc/RegisterClients()
	. = TRUE
	for(var/client/client in GLOB.clients)
		if(!RegisterClient(client))
			. = FALSE

//Registers a specific client to our datum and assign shit to them.
//Either returns a tas sequence datum or null if something ends up going wrong
/datum/tas_manager/proc/RegisterClient(client/client)
	if(clients[client])
		return clients[client]
	. = new/datum/tas_sequence(client)
	clients[client] = .

//This datum is used to handle a client's recorded inputs every world tick.
//The tas_manager handles overwriting the sequences, but this datum handles saving and stuff
/datum/tas_sequence
	var/setting = SETTING_RECORDING //What this sequence is currently doing, dealt with by the manager
	var/handle_mouse = TRUE //If we care about mouse input. FALSE on recording simply will not record mouse input. FALSE on playback will not play mouse input previously recorded
	var/client/client_reference //direct access back to the client we're helping
	var/created_worldtime //The world.time we were created on New()
	var/list/sequence = list() //The actual sequences. Syntax is "world.time" = list(list(keys_held), list(mouseX, mouseY, mouseparams))
	//TODO: var that handles the times when the client never had any input at all, syntaxed as a keyed list. "start.time" = "end.time", if they're equal then it ends the same world tick
		//^ this is for memory optimization. recording every single frame is obviously gonna be taxing for a program limited to 2gb of memory
	var/list/nohold_times = list() //The times that no input has changed at all, handled by the TAS manager. syntax is "first_nohold world.time" = "last_nohold world.time"
	
	//These vars are for determining where no input was held at all. Used for memory optimization mostly
	var/first_nohold = null
	var/last_nohold = null
	var/last_keys_held = null
	var/last_mouse_params = null

/datum/tas_sequence/New(client/client)
	client_reference = client
	created_worldtime = world.time

/datum/tas_sequence/Destroy(force)
	client_reference = null
	. = ..()
