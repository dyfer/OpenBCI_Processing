(
var lastPercentValue = 0, lastSampleIncVal;
var inputPath, outputPath, prefix;
var window, guiElements;
var readCSV, readSF, writeSF, plot, plotSoundFile, renderWave, processWave, processWaveAuto, updateProgress, generateOutputFilename;
var csvArr, csvArrDataOnly, csvArrDataOnlyAsFloat, soundfile, numChannels, numSamples, duration, channelToProcess;
var fs_Hz, aDS1299_Vref, aDS1299_gain, scale_fac_uVolts_per_count;
var tempIn, tempOut, tempInPath, tempOutPath;
var tempFileReady = false;
var filterList;


//!!!! this seem not to be needed!!!!
// following calculations are from OpenBCI_ADS1299 in order to convert raw values to uV: scale_fac_uVolts_per_count - multiply every sample frome the sample file by this....
fs_Hz = 250.0;  //sample rate used by OpenBCI board...set by its Arduino code
aDS1299_Vref = 4.5;  //reference voltage for ADC in ADS1299.  set by its hardware
aDS1299_gain = 24.0;  //assumed gain setting for ADS1299.  set by its Arduino code
scale_fac_uVolts_per_count = aDS1299_Vref / (pow(2,23)-1) / aDS1299_gain  * 1000000; //ADS1299 datasheet Table 7, confirmed through experiment

"scale_fac_uVolts_per_count: ".post; scale_fac_uVolts_per_count.postln;

//note: channelToExtract shoudl be 0-based!

guiElements = IdentityDictionary();
prefix = "".resolveRelative;

tempInPath = prefix ++ "tempIn.wav";
tempOutPath = prefix ++ "tempOut.wav";

filterList = [ //name, loFreq, hiFreq
	["None", nil, nil], //don't remove this
	["BPF 1-50Hz", 1, 50],
	["BPF 7-13Hz", 7, 13],
	["BPF 0.5-7Hz", 0.5, 7]
];

readCSV = {|path|
	inputPath = path;
	if(inputPath.notNil, {
		Routine.run({
			var message;
			"Opening file ".post; inputPath.basename.postln;
			guiElements[\inputFilePath].background_(Color.green(1, 0));
			guiElements[\inputFilePath].string_("Opening file " ++ inputPath.basename ++ " - please wait...");
			0.1.wait;
			updateProgress.(0);
			0.1.wait;
			csvArr = CSVFileReader.read(inputPath);
			0.1.wait;
			updateProgress.(50);
			"Extracting basic data...".postln;
			csvArrDataOnly = csvArr.select({|thisArr, inc| thisArr[0][0] != "%"[0]/*select only data itself, filter our lines starting with % sign*/}).asFloat;
			if(csvArrDataOnly[0].size < 18, { //basic arbitrary switch... file should have 12 elements for 8 channels (index, 8 channels, 3ch of accelerometer data) and probably 20 elements for 16 channels (not tested yet)
				numChannels = 8;
			}, {
				numChannels = 16;
			});
			numSamples = csvArrDataOnly.size;
			duration = numSamples / fs_Hz;
			//update GUI
			guiElements[\chSelectMenu].items = numChannels.collect({|inc| inc}) ++ ["All"];
			guiElements[\chSelectMenu].value = numChannels;
			"Done.".postln;
			updateProgress.(100);
			0.1.wait;
			message =
			postf("File contains % sample frames (% seconds) of %-channel EEG data\n", numSamples, duration.round(0.01), numChannels);
			guiElements[\inputFilePath].string_("Writing temporary file...");
			writeSF.(csvArrDataOnly, tempInPath, nil, actionWhenDone: {
				guiElements[\inputFilePath].string_("CSV file loaded: " ++ inputPath.basename ++ "\nFile contains " ++ numSamples ++ " sample frames (" ++ duration.round(0.01) ++ " seconds) of " ++ numChannels ++ "-channel EEG data");
				guiElements[\inputFilePath].background_(Color.green(1, 0.5));
				// guiElements[\inspectChannel].items = numChannels.collect({|inc| inc});
			});
		}, clock: AppClock);
	});
};

readSF = {|path, updateGUI = true, actionWhenDone = ({})|
	if(updateGUI, {
		inputPath = path;
	});
	if(path.notNil, {

		Routine.run({
			var message;
			"Opening file ".post; path.basename.postln;
			if(updateGUI, {
				guiElements[\inputFilePath].background_(Color.green(1, 0));
				guiElements[\inputFilePath].string_("Opening file " ++ path.basename ++ " - please wait...");
			});
			0.1.wait;

			soundfile = SoundFile.openRead(path);
			numChannels = soundfile.numChannels;
			numSamples = soundfile.numFrames;
			duration = numSamples / fs_Hz;
			// "soundfile.duration :" .post; soundfile.duration.postln;

			csvArrDataOnly = Array.fill(numSamples, 0);
			numSamples.do({|inc|
				var thisSubArr, thisFloatArr, progressPercent;
				try{
					thisFloatArr = FloatArray.fill(numChannels, 0);
					soundfile.readData(thisFloatArr);
					if(thisFloatArr.includes(nil).not, { //not sure why is this happening
						csvArrDataOnly[inc] = thisFloatArr.asArray;
					});
				} {
					// "Something was wrong...".warn;
				};
				progressPercent = inc / numSamples * 100;
				updateProgress.(progressPercent);
				lastSampleIncVal = inc;
				0.0000001.wait; //to not block the interpreter....
			});
			~csvArrDataOnly = csvArrDataOnly;
			// lastPercentValue = 0;
			"Read ".post; (lastSampleIncVal + 1).post; " samples.".postln;
			// "Duration: ".post; f.duration.postln; //this doesn't post properly anyway...
			soundfile.close;
			// actionWhenDone.();
			//update GUI
			if(updateGUI, {
				guiElements[\chSelectMenu].items = numChannels.collect({|inc| inc}) ++ ["All"];
				guiElements[\chSelectMenu].value = numChannels;
				guiElements[\inputFilePath].string_("Wave file loaded: " ++ path.basename ++ "\nFile contains " ++ numSamples ++ " sample frames (" ++ duration.round(0.01) ++ " seconds) of " ++ numChannels ++ "-channel EEG data");
				guiElements[\inputFilePath].background_(Color.green(1, 0.5));
				// guiElements[\inspectChannel].items = numChannels.collect({|inc| inc});
				tempInPath = path; //use as temp file
			});
			"Before actionWhenDone".postln;
			actionWhenDone.();
			"Reading done.".postln;
		}, clock: AppClock);
	});
};

writeSF = {arg arrayToWrite = csvArrDataOnly, path = tempInPath, channelToExtract, actionWhenDone = {};
	var thisNumChannels;
	if(channelToExtract.notNil, {
		thisNumChannels = 1;
		outputPath = inputPath ++ "_ch" ++ channelToExtract.asString ++".wav";//just append wav for now
	}, {
		thisNumChannels = numChannels;
		outputPath = inputPath ++ "_allCh.wav";//just append wav for now
	});
	outputPath = path;
	guiElements[\waveFilePath].string = outputPath;
	// outputPath = inputPath ++ ".wav";//just append wav for now
	"Writing wave file at ".post; outputPath.postln;
	soundfile = SoundFile.new.headerFormat_("WAV").sampleFormat_("float").numChannels_(thisNumChannels).sampleRate_(fs_Hz);
	soundfile.openWrite(outputPath);
	Routine.run({
		csvArrDataOnly.do({|thisArr, inc|
			var thisSubArr, thisFloatArr, progressPercent;
			try{
				if(channelToExtract.notNil, {
					// thisSubArr = [thisArr[channelToExtract + 1].asFloat * scale_fac_uVolts_per_count];
					thisSubArr = [thisArr[channelToExtract + 1].asFloat]; //seems scaling is already done when recording!!!!!
				}, {
					// thisSubArr = thisArr[1..numChannels].asFloat * scale_fac_uVolts_per_count; /*numChannels stays since we start at index 1 (2nd in array)*/
					thisSubArr = thisArr[1..numChannels].asFloat; 
				});

				thisFloatArr = FloatArray.newFrom(thisSubArr);

				// thisFloatArr.postln;
				soundfile.writeData(thisFloatArr);
			} {
				// "Something was wrong...".warn;
			};
			progressPercent = inc/ numSamples * 100;
			updateProgress.(progressPercent);
			lastSampleIncVal = inc;
			0.0000001.wait; //to not block the interpreter....
		});
		// lastPercentValue = 0; //moved to updateProgress
		"Wrote ".post; (lastSampleIncVal + 1).post; " samples.".postln;
		// "Duration: ".post; f.duration.postln; //this doesn't post properly anyway...
		soundfile.close;
		actionWhenDone.();
		"Writing done.".postln;
	}, clock: AppClock);
};

plot = {|channel = 0, histo = false|
	// csvArrDataOnly
	processWaveAuto.(actionWhenDone: {
		"csvArrDataOnly: ".post; csvArrDataOnly.postln;
		// if(channel.isKindOf(SimpleNumber), {
		// 	if(histo, {
		// 		csvArrDataOnly.flop[channel].histo.plot(discrete: true);
		// 	}, {
		// 		csvArrDataOnly.flop[channel].plot;
		// 	});
		// }, {
		{
			if(histo, {
				csvArrDataOnly.flop.size.do({|inc|
					csvArrDataOnly.flop[inc].histo.plot(discrete: true);
				});
			}, {
				csvArrDataOnly.flop.plot(minval: -4, maxval: 4);
			});
		}.defer(0.1);
		// });
	});
};

processWave = {arg loFreq = 7, hiFreq = 13, fadeTime = 0.1, channelToExtract, pathIn = tempInPath, pathOut = tempOutPath, actionWhenDone = {};
	var numCh, sf, options, score, processedOutputPath, oscFilePath, numChOut;
	oscFilePath = prefix ++ "csvToWav";
	sf = SoundFile.openRead(pathIn);
	numCh = sf.numChannels;
	"channelToExtract: ".post; channelToExtract.postln;
	if(channelToExtract.notNil,{
		numChOut = 1;
	}, {
		numChOut = numCh;
	});
	duration = sf.duration;
	sf.close;
	// processedOutputPath = outputPath ++ "_filt" ++ loFreq ++ "_" ++ hiFreq ++ ".wav";
	processedOutputPath = pathOut;
	SynthDef(\filtered, {//arg loFreq = 7, hiFreq = 13;
		var sig, filtSig, env, sigChosen;
		// sig = PlayBuf.ar(numCh, buffer, 1/*we'll set server's sample rate to buffer sample rate!!!*/);
		sig = SoundIn.ar(numCh.collect({|inc| inc})); //from NRT in
		// sig = SoundIn.ar([0]); //from NRT in??
		// rq = bw/freq
		// freq = (lo+hi)/2
		// bw = hi-lo
		// -> rq = (hi - lo) / ((lo+hi)/2)
		if(channelToExtract.isKindOf(SimpleNumber), {
			sigChosen = sig[channelToExtract];
		}, {
			sigChosen = sig;
		});
		env = EnvGen.ar(Env([0, 1, 1, 0], [fadeTime, duration-(2*fadeTime), fadeTime], \sin));
		sigChosen = LeakDC.ar(sigChosen * env);
		if(loFreq.notNil && hiFreq.notNil, {
			filtSig = BPF.ar(sigChosen, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
		}, {
			filtSig = sigChosen;
		});
		Out.ar(0, filtSig);
	}).load;
	{
		score = [
			    [0, [\s_new, \filtered, 1000, 0, 0]],
			    [duration, [\c_set, 0, 0]] // finish
		    ];
		options = ServerOptions.new.numInputBusChannels_(numCh).numOutputBusChannels_(numChOut).sampleRate_(fs_Hz); // mono output
		Score.recordNRT(score, oscFilePath, processedOutputPath, pathIn, fs_Hz, "WAV", "float", options, "", duration, {
			File.delete(oscFilePath);
			"Writing file done!".postln;
			tempFileReady = true;
			{actionWhenDone.()}.defer;
		}); // synthesize
	}.defer(1);
};

updateProgress = {|percentage = 100|
	if(percentage.floor > lastPercentValue, {
		{
			lastPercentValue = percentage.floor;
			if(percentage > 99, {
				guiElements[\progressText].string_("Done.");
				lastPercentValue = 0;
			}, {
				guiElements[\progressText].string_("Working... " ++ lastPercentValue.asString ++ "%");
			});
		}.defer;
	});
};

processWaveAuto = {arg outPath, actionWhenDone = {}, readToArray = true; //some poor argument and variable naming here...
	var loFreq, hiFreq, channelToExtract, pathIn, pathOut;
	if(guiElements[\chSelectMenu].value < numChannels, {
		channelToExtract = guiElements[\chSelectMenu].value;
	}, {
		channelToExtract = nil
	});
	pathIn = tempInPath;
	"pathIn: ".post; pathIn.postln;
	if(outPath.notNil, {
		pathOut = outPath;
	}, {
		pathOut = tempOutPath;
	});
	loFreq = filterList[guiElements[\filterMenu].value][1];
	hiFreq = filterList[guiElements[\filterMenu].value][2];

	processWave.(loFreq, hiFreq, 0.1, channelToExtract, pathIn, pathOut, {
		if(readToArray, {
			readSF.(pathOut, false, {actionWhenDone.()});
		}, {
			actionWhenDone.();
		});
	});
};

generateOutputFilename = {
	var outName;
	outName = inputPath ++ "_filter_" ++ filterList[guiElements[\filterMenu].value][0].tr(" ", "_");
	if(guiElements[\chSelectMenu].item.isKindOf(SimpleNumber), {
		outName = outName ++ "_ch" ++ guiElements[\chSelectMenu].item.asString
	}, {
		outName = outName ++ "_allCh"
	});
	outName = outName ++ ".wav";
	outName;
};

window = Window.new("CSV/WAV converter and processor, Art&Brain2016, DXARTS", 700@400).front;
//gui elements here
guiElements[\chSelectMenu] = PopUpMenu(window);//.action_({|menu| if(numChannels.notNil, {if(menu.value < numChannels, {channelToProcess = menu.value.asInteger; postf("Extracting channel % (0-based)\n", channelToProcess)}, {channelToProcess = nil; postf("Using all channels\n")})})});
guiElements[\waveFilePath] = StaticText(window);
guiElements[\inputFilePath] = StaticText(window);
// guiElements[\inspectChannel] = PopUpMenu(window);
guiElements[\filterMenu] = PopUpMenu(window);
guiElements[\filterMenu].items = filterList.collect({|thisFiltArr| thisFiltArr[0]});
guiElements[\progressText] = StaticText(window);

window.layout_(
	VLayout(
		VLayout(
			HLayout( //main read
				StaticText().string_("1. Load: "),
				Button().states_([["CSV (text) file"]]).action_({File.openDialog("Select CSV file", {|path| readCSV.(path)}, {"loading aborted".postln})}),
				StaticText().string_("or"),
				Button().states_([["Wave file"]]).action_({File.openDialog("Select Wave file", {|path| readSF.(path)}, {"loading aborted".postln})}),
				nil,
				VLayout(
					StaticText().string_("Status:").background_(Color.grey(0.9)),
					guiElements[\progressText].fixedWidth_(100)
				)
			),
			guiElements[\inputFilePath]
		),
		VLayout(
			StaticText().string_("2. Process"),
			HLayout( //parameters
				StaticText().string_("channel:"),
				guiElements[\chSelectMenu],
				StaticText().string_("filtering:"),
				guiElements[\filterMenu],
			),
		),
		VLayout(
			StaticText().string_("3. Inspect data"),
			HLayout(
				Button().states_([["Plot signal from channel"]]).action_({plot.(guiElements[\chSelectMenu].item, false)}),
				Button().states_([["[not finished yet] Plot histogram"]]).action_({plot.(guiElements[\chSelectMenu].item, true)}),
			),
		),
		VLayout(
			VLayout(
				StaticText().string_("4. Save"),
				// guiElements[\waveFilePath];
				HLayout(
					StaticText().string_("Wave file: "),
					Button().states_([["Save in the same location under automatically generated filename"]]).action_({processWaveAuto.(generateOutputFilename.())}),
					Button().states_([["Save as..."]]).action_({File.saveDialog("Select Wave file", "out.wav", {|path| processWaveAuto.(path)}, {"saving aborted".postln})}),
				)
			),
		)
	)
)

)

