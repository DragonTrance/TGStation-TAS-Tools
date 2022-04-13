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
/datum/tas_manager

/datum/tas_manager/New()