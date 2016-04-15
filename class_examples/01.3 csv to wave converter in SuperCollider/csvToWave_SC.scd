(
var lastPercentValue = 0, lastSampleIncVal;
var inputPath, outputPath, prefix;
var window, guiElements;
var readCSV, writeSF, getHisto, getPlot, renderWave, processWave;
var csvArr, csvArrDataOnly, soundfile, numChannels, numSamples, duration, channelToExtract;
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
		"Opening file ".post; inputPath.basename.postln;
		csvArr = CSVFileReader.read(inputPath);
		"Extracting basic data...".postln;
		csvArrDataOnly = csvArr.select({|thisArr, inc| thisArr[0][0] != "%"[0]/*select only data itself, filter our lines starting with % sign*/});
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
		postf("File contains % sample frames (% seconds) of %-channel EEG data\n", numSamples, duration.round(0.01), numChannels);
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

processWave = {|loFreq = 7, hiFreq = 13|
	var numCh, sf, options, score, processedOutputPath, oscFilePath;
	oscFilePath = prefix ++ "csvToWav";
	sf = SoundFile.openRead(outputPath);
	numCh = sf.numChannels;
	duration = sf.duration;
	sf.close;
	processedOutputPath = outputPath ++ "_filt" ++ loFreq ++ "_" ++ hiFreq ++ ".wav";
	SynthDef(\filtered, {//arg loFreq = 7, hiFreq = 13;
		var sig, filtSig;
		// sig = PlayBuf.ar(numCh, buffer, 1/*we'll set server's sample rate to buffer sample rate!!!*/);
		sig = SoundIn.ar(numCh.collect({|inc| inc})); //from NRT in??
		// sig = SoundIn.ar([0]); //from NRT in??
		// rq = bw/freq
		// freq = (lo+hi)/2
		// bw = hi-lo
		// -> rq = (hi - lo) / ((lo+hi)/2)
		filtSig = BPF.ar(sig, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
		    Out.ar(0, filtSig);
	}).add;
	{
		score = [
			    [0, [\s_new, \filtered, 1000, 0, 0]],
			    [duration, [\c_set, 0, 0]] // finish
		    ];
		options = ServerOptions.new.numInputBusChannels_(numCh).numOutputBusChannels_(numCh).sampleRate_(fs_Hz); // mono output
		Score.recordNRT(score, oscFilePath, processedOutputPath, outputPath, fs_Hz, "WAV", "float", options, "", duration, {"Writing file done!".postln}); // synthesize
	}.defer(1);
};

window = Window.new("CSV to WAV converter", 700@400).front;
//gui elements here
guiElements[\writeCh] = PopUpMenu(window).action_({|menu| if(numChannels.notNil, {if(menu.value < numChannels, {channelToExtract = menu.value; postf("Extracting channel % (0-based)\n", channelToExtract)}, {channelToExtract = nil; postf("Using all channels\n")})})});
guiElements[\waveFilePath] = StaticText(window);

window.layout_(
	VLayout(
		HLayout( //main read
			StaticText().string_("1. Load CSV file"),
			Button().states_([["Load CSV"]]).action_({File.openDialog("Select CSV file", {|path| inputPath = path; readCSV.()}, {"loading aborted".postln})})
		),
		HLayout( //parameters
			Button().states_([["Plot signal from channel"]]).action_({}),
			nil,
			Button().states_([["Plot histogram"]]).action_({}),
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
			),
			HLayout( //add processing
				Button().states_([["Change wave file to process"]]).action_({File.openDialog("Select Wave file", {|path| outputPath = path; guiElements[\waveFilePath].string_(outputPath)}, {"loading aborted".postln})}),
				Button().states_([["Apply BPF 1-50Hz"]]).action_({processWave.(1, 50)}),
				Button().states_([["Apply BPF 7-13Hz"]]).action_({processWave.(7, 13)})
		),
		)
	)
)

)

