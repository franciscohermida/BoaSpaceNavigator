global boaSpaceNavigatorStructDef
struct boaSpaceNavigatorStructDef
(
	hook,
	assembly,
	
	moveSensitivity = 1.0 / 10000,
	rotationSensitivity = 1.0 / 500,

	randomSensitivity = 50,
	randomSmoothing = #(),
	randomMaxSamples = 20,
	cameraMoveSmoothing = #(),
	cameraRotSmoothing = #(),
	cameraSmoothingMaxSamples = 10,
	useRandom = false,
	useSmoothing = false,
	
	fn onMessageReceived sender args =
	(
		local tm
		local viewType = viewport.getType()
		local camIfAny
		local moveSensitivityResult = viewport.getFocalDistance() * boaSpaceNavigator.moveSensitivity
		
		if viewType == #view_camera do
		(
			camIfAny = viewport.getCamera()
			tm = camIfAny.transform
		)
		if viewType == #view_persp_user do tm = getViewTM()
		
		if tm != undefined do
		(
			local rawtrans = [args.TransX, args.TransY, -args.TransZ]
			local rawrot = [args.RotX, args.RotY, args.RotZ]
			
			--print (args.TransX as string + args.TransY  as string +  args.TransZ as string)
			--print (args.RotX as string + "     " + args.RotY  as string + "     " +   args.RotZ as string)
			
			if boaSpaceNavigator.useRandom then
			(
				append boaSpaceNavigator.randomSmoothing (random [-1.0,-1.0,-1.0] [1.0,1.0,1.0])
				if boaSpaceNavigator.randomSmoothing.count > boaSpaceNavigator.randomMaxSamples do
					deleteItem boaSpaceNavigator.randomSmoothing 1
			)
			
			append boaSpaceNavigator.cameraMoveSmoothing rawtrans
			if boaSpaceNavigator.cameraMoveSmoothing.count > boaSpaceNavigator.cameraSmoothingMaxSamples do
				deleteItem boaSpaceNavigator.cameraMoveSmoothing 1
			
			append boaSpaceNavigator.cameraRotSmoothing rawrot
			if boaSpaceNavigator.cameraRotSmoothing.count > boaSpaceNavigator.cameraSmoothingMaxSamples do
				deleteItem boaSpaceNavigator.cameraRotSmoothing 1
				
			local smoothRandom
			local trans = rawtrans
			local rot = rawrot
			if boaSpaceNavigator.useSmoothing do
			(
				smoothRandom = [0,0,0]; for val in boaSpaceNavigator.randomSmoothing do ( smoothRandom += val ) ; smoothRandom = smoothRandom / boaSpaceNavigator.randomSmoothing.count
				trans = [0,0,0]; for val in boaSpaceNavigator.cameraMoveSmoothing do ( trans += val ) ; trans = trans / boaSpaceNavigator.cameraMoveSmoothing.count
				rot = [0,0,0]; for val in boaSpaceNavigator.cameraRotSmoothing do ( rot += val ) ; rot = rot / boaSpaceNavigator.cameraRotSmoothing.count
			)
			
			if boaSpaceNavigator.useRandom do
			(
				trans += smoothRandom * boaSpaceNavigator.randomSensitivity
				rot += smoothRandom * boaSpaceNavigator.randomSensitivity
			)
			
			local finalTrans = (trans*moveSensitivityResult)
			local finalRotX = (rot.X*boaSpaceNavigator.rotationSensitivity)
			--finalRotX = 0
			local finalRotZ = (Rot.Y*boaSpaceNavigator.rotationSensitivity)
			
			--in coordsys world rotate tm (eulerangles 0 0 finalRotZ)--(eulerangles -args.RotZ 0 args.RotY)
			--in coordsys local rotate tm (eulerangles finalRotX 0 0)--(eulerangles -args.RotZ 0 args.RotY)
			--in coordsys local rotate tm ((eulerAngles finalRotX 0 0) as quat) -- rotates Z axis in world space
			
			if viewType == #view_camera do
			(
				preTranslate tm finalTrans
				--preRotateX tm finalRotX
				--preRotateY tm finalRotZ
				
				in coordsys local move camIfAny finalTrans--(eulerangles -args.RotZ 0 args.RotY)
				in coordsys world rotate camIfAny (eulerangles 0 0 finalRotZ)--(eulerangles -args.RotZ 0 args.RotY)
				in coordsys local rotate camIfAny (eulerangles finalRotX 0 0)--(eulerangles -args.RotZ 0 args.RotY)
				--in coordsys local rotate tm ((eulerAngles finalRotX 0 0) as quat) -- rotates Z axis in world space
				
				--camIfAny.transform = tm
			)
			if viewType == #view_persp_user do
			(
				translate tm -finalTrans

				rotate tm (quat finalRotZ tm.row3)
				
				rotate tm ((eulerAngles -finalRotX 0 0) as quat)
				viewport.setTM tm
			)

-- ******************************************************************************************************
-- Thanks for your code Francisco Hermida. Consider include this contribution.

-- ***********
-- Rotation on orthographic mode
-- This is still rough, I'll be working to emprove even more.

			if viewType == #view_iso_user do
			(
				translate tm -finalTrans
				viewport.setTm (tm)	--Just to set the same position of #view_persp_user
				
				--This actually "fake" de mouseScrollWheel behavior becouse I didn't
				--found yet a good way to hook up on it (still searching)

				if -args.TransZ > 0 do (viewport.zoom(1.05)) --Values hardcoded may be ajusted
				if -args.TransZ < 0 do (viewport.zoom(0.95)) --to each one preference. :$
									     

				--Using all (of yours) excelent calculation, it is now possible to make it rotate
				--in the orthographic viewport.

				viewport.rotate ((eulerAngles -finalRotX 0 0) as quat)
				viewport.rotate (quat finalRotZ tm.row3)
				completeredraw()

				--By now I'm adjusting the speed by hand, a dialog will be made to take care of it, soon. :P
			)
-- ******************************************************************************************************

		)
	),
	
	fn firstTimeCreating =
	(
		-- Loading from bytes so dll is not locked
		local currentScriptFolder = getFilenamePath (getThisScriptFilename())
		local dllsFolder = pathConfig.appendPath currentScriptFolder @"dlls"
		local dllPath = pathConfig.appendPath dllsFolder @"BoaSpaceNavigatorWrapper.dll"
		
		this.assembly = (dotnetClass "System.Reflection.assembly").Load ((dotnetClass "System.IO.File").ReadAllBytes dllpath)
		this.hook = (dotNetClass "System.Activator").CreateInstance (assembly.GetType("BoaSpaceNavigatorWrapper.WindowHooker"))
	
		this.hook.AssignHandle (dotnetobject "IntPtr" (windows.getMAXHWND()))
		this.hook.Initialize()
	),
	
	fn register =
	(
		print "register"
		
		dotNet.addEventHandler this.hook "MessageReceived" this.onMessageReceived
	),
	
	fn deregister =
	(
		print "deregister"
		--/* -- Run this only once TODO: include this in script by default
		dotNet.removeAllEventHandlers this.hook
		--this.hook.dispose() -- we don't dipose because we are going to reuse it in the next instance created
	),
	
	on create do
	(
		if boaSpaceNavigator == undefined then
		(
			-- load assembly
			this.firstTimeCreating()
		)
		else
		(
			this.hook = boaSpaceNavigator.hook
			this.assembly = boaSpaceNavigator.assembly
			
			boaSpaceNavigator.deregister()
			boaSpaceNavigator.hook = undefined
			boaSpaceNavigator.assembly = undefined
		)
		
		-- register stuff
		this.register()
	)
)

boaSpaceNavigator = boaSpaceNavigatorStructDef()


