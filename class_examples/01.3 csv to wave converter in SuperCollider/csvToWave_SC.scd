(
var lastPercentValue = 0, lastSampleIncVal;
var inputPath, outputPath, prefix;
var window, guiElements;
var readCSV, writeSF, plot, plotSoundFile, renderWave, processWave;
var csvArr, csvArrDataOnly, csvArrDataOnlyAsFloat, soundfile, numChannels, numSamples, duration, channelToExtract;
var fs_Hz, aDS1299_Vref, aDS1299_gain, scale_fac_uVolts_per_count;


// following calculations are from OpenBCI_ADS1299 in order to convert raw values to uV: scale_fac_uVolts_per_count - multiply every sample frome the sample file by this....
fs_Hz = 250.0;  //sample rate used by OpenBCI board...set by its Arduino code
aDS1299_Vref = 4.5;  //reference voltage for ADC in ADS1299.  set by its hardware
aDS1299_gain = 24.0;  //assumed gain setting for ADS1299.  set by its Arduino code
scale_fac_uVolts_per_count = aDS1299_Vref / (pow(2,23)-1) / aDS1299_gain  * 1000000; //ADS1299 datasheet Table 7, confirmed through experiment

//note: channelToExtract shoudl be 0-based!

guiElements = IdentityDictionary();
prefix = "".resolveRelative;

readCSV = {
	if(inputPath.notNil, {
		Routine.run({
			var message;
			"Opening file ".post; inputPath.basename.postln;
			guiElements[\csvFilePath].background_(Color.green(1, 0));
			guiElements[\csvFilePath].string_("Opening file " ++ inputPath.basename ++ " - please wait...");
			0.1.wait;
			csvArr = CSVFileReader.read(inputPath);
			"Extracting basic data...".postln;
			csvArrDataOnly = csvArr.select({|thisArr, inc| thisArr[0][0] != "%"[0]/*select only data itself, filter our lines starting with % sign*/});
			csvArrDataOnlyAsFloat = csvArrDataOnly.asFloat;
			if(csvArrDataOnly[0].size <18, { //basic arbitrary switch... file should have 12 elements for 8 channels (index, 8 channels, 3ch of accelerometer data) and probably 20 elements for 16 channels (not tested yet)
				numChannels = 8;
			}, {
				numChannels = 16;
			});
			numSamples = csvArrDataOnly.size;
			duration = numSamples / fs_Hz;
			//update GUI
			guiElements[\writeCh].items = numChannels.collect({|inc| inc}) ++ ["All"];
			guiElements[\writeCh].value = numChannels;
			"Done.".postln;
			message =
			postf("File contains % sample frames (% seconds) of %-channel EEG data\n", numSamples, duration.round(0.01), numChannels);
			guiElements[\csvFilePath].string_("CSV file loaded: " ++ inputPath.basename ++ "\nFile contains " ++ numSamples ++ " sample frames (" ++ duration.round(0.01) ++ " seconds) of " ++ numChannels ++ "-channel EEG data");
			guiElements[\csvFilePath].background_(Color.green(1, 0.5));
			guiElements[\inspectChannel].items = numChannels.collect({|inc| inc});
		}, clock: AppClock);
	});
};

writeSF = {
	var thisNumChannels;
	if(channelToExtract.notNil, {
		thisNumChannels = 1;
		outputPath = inputPath ++ "_ch" ++ channelToExtract.asString ++".wav";//just append wav for now
	}, {
		thisNumChannels = numChannels;
		outputPath = inputPath ++ "_allCh.wav";//just append wav for now
	});
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
					thisSubArr = [thisArr[channelToExtract + 1].asFloat * scale_fac_uVolts_per_count];
				}, {
					thisSubArr = thisArr[1..numChannels].asFloat * scale_fac_uVolts_per_count; /*numChannels stays since we start at index 1 (2nd in array)*/
				});

				thisFloatArr = FloatArray.newFrom(thisSubArr);

				// thisFloatArr.postln;
				soundfile.writeData(thisFloatArr);
			} {
				// "Something was wrong...".warn;
			};
			progressPercent = inc/ numSamples * 100;
			if(progressPercent.floor > lastPercentValue, {
				progressPercent.floor.post;"%".postln;
				lastPercentValue = progressPercent.floor;
			});
			lastSampleIncVal = inc;
			0.0000001.wait; //to not block the interpreter....
		});
		lastPercentValue = 0;
		"Wrote ".post; (lastSampleIncVal + 1).post; " samples.".postln;
		// "Duration: ".post; f.duration.postln; //this doesn't post properly anyway...
		soundfile.close;
		"Writing done.".postln;
	})
};

plot = {|channel = 0, histo = false|
	// csvArrDataOnly
	if(histo, {
		csvArrDataOnlyAsFloat.flop[7].histo.plot(discrete: true);
	}, {
		csvArrDataOnlyAsFloat.flop[7].plot;
	});
};

processWave = {|loFreq = 7, hiFreq = 13, fadeTime = 0.1|
	var numCh, sf, options, score, processedOutputPath, oscFilePath;
	oscFilePath = prefix ++ "csvToWav";
	sf = SoundFile.openRead(outputPath);
	numCh = sf.numChannels;
	duration = sf.duration;
	sf.close;
	processedOutputPath = outputPath ++ "_filt" ++ loFreq ++ "_" ++ hiFreq ++ ".wav";
	SynthDef(\filtered, {//arg loFreq = 7, hiFreq = 13;
		var sig, filtSig, env;
		// sig = PlayBuf.ar(numCh, buffer, 1/*we'll set server's sample rate to buffer sample rate!!!*/);
		sig = SoundIn.ar(numCh.collect({|inc| inc})); //from NRT in
		// sig = SoundIn.ar([0]); //from NRT in??
		// rq = bw/freq
		// freq = (lo+hi)/2
		// bw = hi-lo
		// -> rq = (hi - lo) / ((lo+hi)/2)
		env = EnvGen.ar(Env([0, 1, 1, 0], [fadeTime, duration-(2*fadeTime), fadeTime], \sin));
		sig = LeakDC.ar(sig * env);
		filtSig = BPF.ar(sig, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
		Out.ar(0, filtSig);
	}).load;
	{
		score = [
			    [0, [\s_new, \filtered, 1000, 0, 0]],
			    [duration, [\c_set, 0, 0]] // finish
		    ];
		options = ServerOptions.new.numInputBusChannels_(numCh).numOutputBusChannels_(numCh).sampleRate_(fs_Hz); // mono output
		Score.recordNRT(score, oscFilePath, processedOutputPath, outputPath, fs_Hz, "WAV", "float", options, "", duration, {File.delete(oscFilePath); "Writing file done!".postln}); // synthesize
	}.defer(1);
};

plotSoundFile = {
	var numCh, sf, options, score, processedOutputPath, oscFilePath;
	sf = SoundFile.openRead(outputPath);
	numCh = sf.numChannels;
	duration = sf.duration;
	//plot
	// sf.plot;
/*	Routine.run({
			var message;
			"Opening file ".post; inputPath.basename.postln;
			guiElements[\csvFilePath].background_(Color.green(1, 0));
			guiElements[\csvFilePath].string_("Opening file " ++ inputPath.basename ++ " - please wait...");
			0.1.wait;
			csvArr = CSVFileReader.read(inputPath);
			"Extracting basic data...".postln;
			csvArrDataOnly = csvArr.select({|thisArr, inc| thisArr[0][0] != "%"[0]/*select only data itself, filter our lines starting with % sign*/});
			csvArrDataOnlyAsFloat = csvArrDataOnly.asFloat;
			if(csvArrDataOnly[0].size <18, { //basic arbitrary switch... file should have 12 elements for 8 channels (index, 8 channels, 3ch of accelerometer data) and probably 20 elements for 16 channels (not tested yet)
				numChannels = 8;
			}, {
				numChannels = 16;
			});
			numSamples = csvArrDataOnly.size;
			duration = numSamples / fs_Hz;
			//update GUI
			guiElements[\writeCh].items = numChannels.collect({|inc| inc}) ++ ["All"];
			guiElements[\writeCh].value = numChannels;
			"Done.".postln;
			message =
			postf("File contains % sample frames (% seconds) of %-channel EEG data\n", numSamples, duration.round(0.01), numChannels);
			guiElements[\csvFilePath].string_("CSV file loaded: " ++ inputPath.basename ++ "\nFile contains " ++ numSamples ++ " sample frames (" ++ duration.round(0.01) ++ " seconds) of " ++ numChannels ++ "-channel EEG data");
			guiElements[\csvFilePath].background_(Color.green(1, 0.5));
			guiElements[\inspectChannel].items = numChannels.collect({|inc| inc});
		}, clock: AppClock);
	});*/
	sf.close;
};

window = Window.new("CSV to WAV converter", 700@400).front;
//gui elements here
guiElements[\writeCh] = PopUpMenu(window).action_({|menu| if(numChannels.notNil, {if(menu.value < numChannels, {channelToExtract = menu.value; postf("Extracting channel % (0-based)\n", channelToExtract)}, {channelToExtract = nil; postf("Using all channels\n")})})});
guiElements[\waveFilePath] = StaticText(window);
guiElements[\csvFilePath] = StaticText(window);
guiElements[\inspectChannel] = PopUpMenu(window);

window.layout_(
	VLayout(
		VLayout(
			HLayout( //main read
				StaticText().string_("1. Load CSV file"),
				Button().states_([["Load CSV"]]).action_({File.openDialog("Select CSV file", {|path| inputPath = path; readCSV.()}, {"loading aborted".postln})}),
			),
			guiElements[\csvFilePath]
		),
		VLayout(
			StaticText().string_("2. Inspect data"),
			HLayout( //parameters
				StaticText().string_("from channel:"),
				guiElements[\inspectChannel],
				nil,
				Button().states_([["Plot signal from channel"]]).action_({plot.(guiElements[\inspectChannel].item.asInteger, false)}),
				Button().states_([["[not finished yet] Plot histogram"]]).action_({plot.(guiElements[\inspectChannel].item.asInteger, true)}),
			),
		),
		HLayout( //save
			StaticText().string_("3. Choose single or all channels\nand save as wave file (in the same location)"),
			guiElements[\writeCh],
			Button().states_([["Save wave file"]]).action_({writeSF.()})
		),
		VLayout(
			VLayout(
				StaticText().string_("4. additional processing for wave file (save above first!). Current file path:"),
				guiElements[\waveFilePath];
				HLayout(
					StaticText().string_("If you'd like to process a different file, choose it here: "),
					Button().states_([["Change wave file to process"]]).action_({File.openDialog("Select Wave file", {|path| outputPath = path; guiElements[\waveFilePath].string_(outputPath)}, {"loading aborted".postln})}),
				)
			),
			HLayout( //add processing
				Button().states_([["Apply BPF 1-50Hz"]]).action_({processWave.(1, 50)}),
				Button().states_([["Apply BPF 7-13Hz"]]).action_({processWave.(7, 13)}),
		),
			HLayout(
				Button().states_([["Plot a wave file"]]).action_({File.openDialog("Select Wave file", {|path| plotSoundFile.(path)}, {"loading aborted".postln})}),
			)
		)
	)
)

)

