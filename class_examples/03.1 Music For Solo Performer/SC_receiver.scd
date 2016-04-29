Platform.userAppSupportDir.openOS
s.reboot
s.makeGui
(
var receivePort = 8100, numChannels = 8;
var synths;
thisProcess.openUDPPort(receivePort); // attempt to open 8100

~def.free;
~rawBus.free;
~processedBus.free;
// ~processedBusLeakDC.free;
~note.free;
~note2.free;

s.waitForBoot({
	synths = CtkProtoNotes(
		SynthDef(\rawProcessing, {|in = 0, out = 0, dcCoeff = 0.995, mul = 1, loFreq = 7, hiFreq = 13, whichElectrode = 7|
			var inSig, outSig, outSigAR, selectedSig;
			inSig = In.kr(in, numChannels);
			outSig = LeakDC.kr(inSig, dcCoeff) * mul;
			outSigAR = K2A.ar(outSig);
			// outSig = inSig * mul;
			// Out.kr(out2, outSig);
			// outSig = outSig; //add filtering here?
			outSigAR = BPF.ar(outSigAR, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
			// outSig = BPF.kr(inSig, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2)) * mul;
			selectedSig = Select.ar(whichElectrode, outSigAR);
			Out.ar(out, selectedSig);
			// Out.kr(out, outSig);
		}),
		SynthDef(\ampFollower, {|in = 0, rmsWindow = 40, lag = 0.3, dcCoeff = 0.995, loFreq = 1, hiFreq = 50, lagShape = 0, minVal = 0, maxVal = 1/*input values*/, ampAtt = 0.2, ampRel = 0.5, triggerRate = 30, mul = 1|
			var inSig, outSig, amp, selectedSig, trig;
			inSig = In.kr(in, numChannels);
			outSig = LeakDC.kr(inSig, dcCoeff) * mul;
			// outSig = inSig;
			outSig = BPF.kr(outSig, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
			// outSig = outSig.abs;
			// outSig = RunningSum.kr(outSig.abs, rmsWindow) / rmsWindow;
			amp = Amplitude.kr(outSig, ampAtt, ampRel);
			// amp = VarLag.kr(amp, lag, lagShape);
			amp = Lag3.kr(amp, lag);
			amp = amp.linlin(minVal, maxVal, 0, 1, \minmax); //scaling for midi output
			// outSig = inSig * mul;
			// Out.kr(out2, outSig);
			// outSig = outSig; //add filtering here?
			trig = Impulse.kr(triggerRate);
			SendReply.kr(trig, '/cc', amp);
			// Out.kr(out, outSig);
		})
	);

	~synths = synths;


	~rawBus = Bus.control(Server.default, numChannels);
	~processedBus = Bus.audio(Server.default, 1);
	// ~processedBusLeakDC = Bus.control(Server.default, numChannels);
	~def = OSCdef(\rawEEG, {|msg|
		var rawData;
		// msg.postln;
		rawData = msg[1..]; // 1 and up
		~rawBus.setnSynchronous(rawData);
	}, '/raw', recvPort: receivePort);

	~note = synths[\rawProcessing].note(addAction: \head).in_(~rawBus).out_(~processedBus).play;
});

)

p = Stethoscope.new(s, 8, ~rawBus.index, 16384, 1, \control)

(
~def.free;
~rawBus.free;
~processedBus.free;
// ~processedBusLeakDC.free;
~note.free;
~note2.free;
)
~rawBus.scope
~processedBus.scope
Stethoscope.new

// BASIC USAGE

(/* plotting data streams */
// note: busindex can be an array of indices (including non-contiguous), in which case numChans is ignored
~mon = ControlPlotter(~processedBus.index + 4, numChans: 1, plotLength: 175, refresh_rate: 30, plotMode: \linear);
~mon.start;
~mon.bounds_(-45,45);
~mon.bounds_('auto');
~mon.plotMode_(\linear);
// ~mon.plotMode_(\points);
~mon.plotColors_(1.collect{Color.rand(0.2, 0.4)});
)

(/* plotting data streams */
// note: busindex can be an array of indices (including non-contiguous), in which case numChans is ignored
~mon1 = ControlPlotter(~processedBusLeakDC.index + 4, numChans: 1, plotLength: 175, refresh_rate: 30, plotMode: \linear);
~mon1.start;
~mon1.bounds_(-45,45);
~mon1.bounds_('auto');
~mon1.plotMode_(\linear);
// ~mon.plotMode_(\points);
~mon1.plotColors_(1.collect{Color.rand(0.2, 0.4)});
)

(/* plotting data streams */
// note: busindex can be an array of indices (including non-contiguous), in which case numChans is ignored
~mon2 = ControlPlotter(~rawBus.index + 4, numChans: 1, plotLength: 175, refresh_rate: 30, plotMode: \linear);
~mon2.start;
~mon2.bounds_(-45,45);
~mon2.bounds_('auto');
~mon2.plotMode_(\linear);
// ~mon.plotMode_(\points);
~mon2.plotColors_(1.collect{Color.rand(0.2, 0.4)});
)



s.hasShmInterface


p.zoom_(0.1)

~note.dcCoeff_(0.995)

//amplitude to MIDI
MIDIFunc.trace(true)
(
//add ouch sensing
// MIDIClient.init;
m = MIDIOut.newByName("X-TOUCH COMPACT", "X-TOUCH COMPACT");
~note2.free;
~note2 = ~synths[\ampFollower].note(addAction: \tail).in_(~rawBus).rmsWindow_(40).lag_(1).lagShape_(0).minVal_(0).maxVal_(5).ampAtt_(0.2).ampRel_(0.5).triggerRate_(60).play;
	~defCC = OSCdef(\cc, {|msg|
		var ccData;
		// msg.round(0.01).postln;
		ccData = msg[3..]; // 1 and up
		ccData.do({|thisVal, inc|
			m.control(0, 1 + inc, thisVal.asInteger);
			(~percSynths ++ ~memSynths)[inc].amp_([0.0, 10.dbamp, 4.7].asSpec.map(thisVal.linlin(0, 127, 0, 1)));
		});
	}, '/cc');

)

~note2.ampAtt_(0).ampRel_(0)
~note2.free
s.plotTree

m.control(0, 1, 40);

~note2.dcCoeff_(0.995)
~note2.lag_(1).lagShape_(1)
~note2.minVal_(0).maxVal_(20)
~note2.triggerRate_(60)