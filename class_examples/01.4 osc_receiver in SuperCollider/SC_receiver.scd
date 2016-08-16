//EEG processing in SuperCollider
//streaming from OpenBCI app
//note: receivePort should be the same as oscSendToPort in OpenBCI_GUI code

//use OpenBCI to stream either prerecorded or live signal, run code below for basic processing

//note: data from OpenBCI is already scaled according to scale_fac_uVolts_per_count!

//2 examples: one outputs on audio bus, one on control bus

//-----------
// control rate
//----------

//choose one channel, filter, output on a control bus
(
var receivePort = 8100, numChannels = 8;
var synths;
thisProcess.openUDPPort(receivePort); // attempt to open 8100

~def.free;
~rawBus.free;
~processedBus.free;
~processNote.free;

s.waitForBoot({
	synths = CtkProtoNotes(
		SynthDef(\rawProcessing, {|in = 0, out = 0, dcCoeff = 0.995, mul = 1, loFreq = 7, hiFreq = 13, whichElectrode = 7|
			var inSig, outSig, outSigAR, selectedSig;
			inSig = In.kr(in, numChannels);
			outSig = LeakDC.kr(inSig, dcCoeff) * mul;
			selectedSig = Select.kr(whichElectrode, outSig);
			outSig = BPF.kr(outSig, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
			Out.kr(out, outSig);
		})
	);

	~synths = synths;


	~rawBus = Bus.control(Server.default, numChannels);
	~processedBus = Bus.control(Server.default, 1);
	~def = OSCdef(\rawEEG, {|msg|
		var rawData;
		// msg.postln;
		rawData = msg[1..]; // 1 and up
		~rawBus.setnSynchronous(rawData);
	}, '/raw', recvPort: receivePort);

	~processNote = synths[\rawProcessing].note(addAction: \head).in_(~rawBus).out_(~processedBus).play;
});

)

//stethoscope... not super useful, but useful for checking if it works
p = Stethoscope.new(s, 8, ~rawBus.index, 16384, 1, \control); //input; note, this is way beyond bounds of the stethoscope
p = Stethoscope.new(s, 1, ~processedBus.index, 16384, 1, \control); //processed

//free
(
~def.free;
~rawBus.free;
~processedBus.free;
~processNote.free;
)


//-----------
// audio rate
//----------

//choose one channel, filter, output on a audio bus
(
var receivePort = 8100, numChannels = 8;
var synths;
thisProcess.openUDPPort(receivePort); // attempt to open 8100

~def.free;
~rawBus.free;
~processedBus.free;
~processNote.free;

s.waitForBoot({
	synths = CtkProtoNotes(
		SynthDef(\rawProcessing, {|in = 0, out = 0, dcCoeff = 0.995, mul = 1, loFreq = 7, hiFreq = 13, whichElectrode = 7|
			var inSig, outSig, outSigAR, selectedSig;
			inSig = In.kr(in, numChannels);
			outSig = LeakDC.kr(inSig, dcCoeff) * mul;
			selectedSig = Select.kr(whichElectrode, outSig);
			outSigAR = K2A.ar(selectedSig);
			outSigAR = BPF.ar(outSigAR, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
			Out.ar(out, outSigAR);
		})
	);

	~synths = synths;


	~rawBus = Bus.control(Server.default, numChannels);
	~processedBus = Bus.audio(Server.default, 1);
	~def = OSCdef(\rawEEG, {|msg|
		var rawData;
		// msg.postln;
		rawData = msg[1..]; // 1 and up
		~rawBus.setnSynchronous(rawData);
	}, '/raw', recvPort: receivePort);

	~processNote = synths[\rawProcessing].note(addAction: \head).in_(~rawBus).out_(~processedBus).play;
});

)

//stethoscope... not super useful, but useful for checking if it works
p = Stethoscope.new(s, 8, ~rawBus.index, 16384, 1, \control); //input; note, this is way beyond bounds of the stethoscope
p = Stethoscope.new(s, 1, ~processedBus.index, 16384, 1, \audio); //processed

//free
(
~def.free;
~rawBus.free;
~processedBus.free;
~processNote.free;
)
