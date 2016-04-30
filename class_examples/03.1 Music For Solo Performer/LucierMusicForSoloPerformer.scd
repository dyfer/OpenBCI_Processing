OSCFunc.trace(false)
s.plotTree
(
var receivePort = 8100, numChannels = 8;
var synths;
var decType = \bf; //\stereo or \bf
var firstOutput = 0;
var gloablAmp = -12.dbamp;
var isTouched;
thisProcess.openUDPPort(receivePort); // attempt to open 8100 for streaming eeg

// using actual brain data (alpha waves) - file playback
// ~data = CtkBuffer.playbuf("/Users/juan/AeroFS/Files/Courses/490-16/Assignment_2/Edited/G3_OpenBCI-RAW-2016-04-15_13-22-08_edited_7_13Hz.wav").load(sync: true);
// ~playBuf = CtkSynthDef(\playBuf, {
// 	arg buffer, rate=1, start=0, outbus=0;
// 	var in;
// 	in = PlayBuf.ar(
// 		1, buffer, BufRateScale.kr(buffer) * rate,
// 		startPos: start * BufSampleRate.kr(buffer),
// 		loop: 1);
// 	Out.ar(outbus, in);
// });

MIDIClient.init;
MIDIIn.connectAll;

try{
	~midiOut = MIDIOut.newByName("X-TOUCH COMPACT", "X-TOUCH COMPACT");
};

~freeAll = {
	[~inBus, ~bfBus, ~rawBus, ~processedBus, ~def, ~defCC, ~rawNote, ~ccNote, ~decNote, ~touchResp].do(_.free);
	~percSynths !? {~percSynths.do(_.free)};
	~memSynths !? {~memSynths.do(_.free)};
	~midiBut.free;
};

~freeAll.(); // free when re-running

s.stopRecording; // this closes the file and deallocates the buffer recording node, etc.

isTouched = false ! 8;

s.options.numOutputBusChannels_(4); //for b-format

s.waitForBoot({

	//synths

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
		SynthDef(\ampFollower, {|in = 0, lag = 0.3, dcCoeff = 0.995, loFreq = 1, hiFreq = 50, lagShape = 0, minVal = 0, maxVal = 1/*input values*/, ampAtt = 0.2, ampRel = 0.5, triggerRate = 30, mul = 1|
			var inSig, outSig, amp, selectedSig, trig;
			inSig = In.kr(in, numChannels);
			outSig = LeakDC.kr(inSig, dcCoeff) * mul;
			outSig = BPF.kr(outSig, (loFreq+hiFreq)/2, (hiFreq - loFreq) / ((loFreq+hiFreq)/2));
			amp = Amplitude.kr(outSig, ampAtt, ampRel);
			amp = amp.linlin(minVal, maxVal, 0, 1, \minmax); //scaling for midi output
			amp = Lag3.kr(amp, lag);
			trig = Impulse.kr(triggerRate);
			SendReply.kr(trig, '/cc', amp);
		})
	);

	~synths = synths;

	//synths cont
	~perc = CtkSynthDef(\perc, {
		arg freq=800, in_gain = 1, amp=1, thresh=0.1, att=0.01, rel=0.1, inbus=0, outbus=0, az=0, el=0, del=0, lim=1;

		var in, amp_follow, excitation, sig, out;

		in = DelayN.ar(Limiter.ar(In.ar(inbus, 1) * in_gain, lim), 1.0, del);

		// in = DelayN.ar(In.ar(inbus, 1) * in_gain, 1.0, del);

		amp_follow = Amplitude.kr(in);

		excitation = EnvGen.ar(
			Env.perc(att, rel),
			// Trig.ar((in * in_gain) > thresh, att),
			Trig.ar(in, att),
			levelScale: amp_follow
		);

		sig = Klank.ar(`[
			Array.geom(12, 1.0, 1.33875),
			Array.geom(12, 1.0, 1.33875.reciprocal),
			Array.geom(12, 1.0, 1.33875.reciprocal)
		],
			excitation, freq);

		out = FoaPanB.ar(sig, az, el);

		Out.ar(outbus, out * amp);
	});

	~membrane = CtkSynthDef(\membrane, {
		arg in_gain = 1, amp=1, thresh=0.1, att=0.01, rel=0.1, tension = 0.011, loss = 0.9999, inbus=0, outbus=0, az=0, el=0, del=0, lim=1;
		var in, amp_follow, excitation, sig, out;

		in = DelayN.ar(Limiter.ar(In.ar(inbus, 1) * in_gain, lim), 1.0, del);

		amp_follow = Amplitude.kr(in);

		excitation = EnvGen.ar(
			Env.perc(att, rel),
			// Trig.ar((in * in_gain) > thresh, att),
			Trig.ar(in, att),
			levelScale: amp_follow
		);

		sig = MembraneCircle.ar(excitation, tension, loss);
		// MembraneHexagon.ar(excitation, tension, loss);
		out = FoaPanB.ar(sig, az, el);

		Out.ar(outbus, out * amp);
	});

	~decoder = CtkSynthDef(\decoder, {
		arg inbus, outbus=0;
		var in, out;
		in = In.ar(inbus, 4) * gloablAmp;
		in = FoaEncode.ar(Limiter.ar(FoaDecode.ar(in, FoaDecoderMatrix.newBtoA), -3.dbamp), FoaEncoderMatrix.newAtoB);
		// in.poll;
		decType.switch(
			\stereo, {out = FoaDecode.ar(in, FoaDecoderMatrix.newStereo(60))},
			\bf, {out = in},
			{"no proper decder selected!".warn}
		);
		Out.ar(outbus, out)
	});


	//buses
	~inBus = CtkAudio(1);
	~bfBus = CtkAudio(4);
	~rawBus = Bus.control(Server.default, numChannels);
	~processedBus = Bus.audio(Server.default, 1);

	s.sync;
	//responders
	~def = OSCdef(\rawEEG, {|msg|
		var rawData;
		// msg.postln;
		rawData = msg[1..]; // 1 and up
		~rawBus.setnSynchronous(rawData);
	}, '/raw', recvPort: receivePort);

	~defCC = OSCdef(\cc, {|msg|
		var ccData;
		// msg.round(0.01).postln;
		ccData = msg[3..]; // 1 and up
		ccData.do({|thisVal, inc|
			if(isTouched[inc].not, {
				try{
					~midiOut.control(0, 1 + inc, thisVal.linlin(0, 1, 0, 127, \minmax));
				};
				(~percSynths ++ ~memSynths)[inc].amp_([0.0, 10.dbamp, 4.7].asSpec.map(thisVal));
			}, {
				// var msg = "Fader " ++ inc.asString ++ " touched, not setting the amp";
				// msg.warn;
			});
		});
	}, '/cc');

	~touchResp = MIDIdef(\touch, {|val, num, chan, and src|
		var ctlOffset = 101;
		isTouched[num - ctlOffset] = val.asBoolean;
		// isTouched.postln;
	}, (101..108), 0, \control);

	try{
		~midiBut = MIDICV(0, \unipolar.asSpec).button(16);

		~startBrainFaders = {|val|
			if(val.asBoolean, {
				~ccNote.free;
				~ccNote = ~synths[\ampFollower].note(addAction: \tail)
				.in_(~rawBus)
				.lag_(0.5)
				.lagShape_(0)
				.minVal_(0)
				.maxVal_(5)
				.ampAtt_(0.2)
				.ampRel_(0.5)
				.triggerRate_(60)
				.play;
			}, {
				~ccNote.free;
			});
		};
		~midiBut.makeToggle;
		~midiBut.toggleCV.connectTo(~startBrainFaders);			// remember to connect it!
		~midiBut.mirrorHWToggle(destPort: 1); //this might not work....

	};



	s.sync;
	//init notes
	~rawNote = synths[\rawProcessing].note(addAction: \head).in_(~rawBus).out_(~processedBus).play;
	~decNote = ~decoder.note(addAction: \tail).inbus_(~bfBus).outbus_(0	).play;


	s.sync; //wait for synths to start
	{
		var dels, perc_freqs, perc_angs, mem_tension, mem_loss, mem_angs;
		dels = [0.0] ++ Array.geom(7, 1.0, 1.33875.reciprocal).reverse;
		perc_freqs = Array.geom(4, 800, 1.33875);
		perc_angs = Array.series(4, 0, 90).degrad;
		mem_tension = Array.rand(4, 0.011, 0.019);
		mem_loss = Array.rand(4, 0.999, 0.9999);
		mem_angs = Array.series(4, 45, 90).degrad;

		~percSynths = 4.collect{ arg i;
			~perc.note(addAction: \before, target: ~decNote).freq_(perc_freqs[i])
			.in_gain_(12.dbamp).amp_(0).lim_(24.dbamp)
			.inbus_(~processedBus).outbus_(~bfBus)
			.az_(perc_angs[i]).el_(30.degrad)
			.del_(dels[i]).play;
		};

		~memSynths = 4.collect{ arg i;
			~membrane.note(addAction: \before, target: ~decNote).in_gain_(12.dbamp).amp_(0).lim_(24.dbamp)
			.tension_(mem_tension[i]).loss_(mem_loss[i])
			.inbus_(~processedBus).outbus_(~bfBus)
			.az_(mem_angs[i]).el_(0)
			.del_(dels[i+4]).play;
		};
	}.();

	s.sync;
	//now midi controller
	try{
	~vCtl = 8.collect{|i| MIDICV(0, [0.0, 10.dbamp, 4.7].asSpec).cc(i+1)};

	// connect midi control values to amp param
	f = {|val| val.ampdb.postln};

	// [(~percSynths ++ ~memSynths), \amp_ ! 8].flop;

	[(~percSynths ++ ~memSynths), \amp_ ! 8].flop.do{|ctl, i|
		ctl.postln;
		~vCtl[i].connectTo(ctl[0], ctl[1]);
		~vCtl[i].connectTo(f);
	};

	~rotC1 = MIDICV(0, [0.0, 1].asSpec).cc(10).connectTo({|val|
		var sc;
		sc = val.linlin(0, 1, 0, 5);
		~ccNote !? {~ccNote.minVal_(sc)};
		"Min val: ".post;
		sc.round(0.01).postln;
	});
	~rotC2 = MIDICV(0, [0.0, 1].asSpec).cc(11).connectTo({|val|
		var sc;
		sc = val.linlin(0, 1, 1, 20);
		~ccNote !? {~ccNote.maxVal_(sc)};
		"Max val: ".post;
		sc.round(0.01).postln;
	});

	~rotC3 = MIDICV(0, [0.0, 1].asSpec).cc(12).connectTo({|val|
		var sc;
		sc = val.linlin(0, 1, 0.1, 10, \minmax);
		~ccNote !? {~ccNote.lag_(sc)};
		"Lag: ".post;
		sc.round(0.01).postln;
	});
	};

	fork{
		s.prepareForRecord; // if you want to start recording on a precise moment in time, you have to call this first.
		0.2.wait;
		s.record;
	};

});

)


//------ free ------
~freeAll.();


//----- recording -----

//start
(
fork{
	s.prepareForRecord; // if you want to start recording on a precise moment in time, you have to call this first.
	0.2.wait;
	s.record;
}
)

//stop
(
s.stopRecording; // this closes the file and deallocates the buffer recording node, etc.
thisProcess.platform.recordingsDir.openOS; //look into recordings folder
)





//-------------------
//scratch below
//-------------------

s.plotTree

//move faders automatically
~ccNote = ~synths[\ampFollower].note(addAction: \tail).in_(~rawBus).lag_(0.5).lagShape_(0).minVal_(0).maxVal_(5).ampAtt_(0.2).ampRel_(0.5).triggerRate_(60).play;

~ccNote.free; //stop

//tweak params
~ccNote.lag_(2);
~ccNote.minVal_(0).maxVal_(20);
~ccNote.triggerRate_(60);


x = ~perc.note(addAction: \before, target: w ).freq_(800).in_gain_(12.dbamp).amp_(0.dbamp).inbus_(~processedBus).outbus_(~bfBus).az_(-30.degrad).lim_(24.dbamp).play;
x.amp_(0)
x.in_gain_(12.dbamp)
x.lim_(24.dbamp)
x.free


y = ~membrane.note(addAction: \before, target: w ).in_gain_(12.dbamp).amp_(0.dbamp).tension_(0.015).loss_(0.9999).inbus_(~processedBus).outbus_(~bfBus).az_(30.degrad).del_(1.0).lim_(24.dbamp).play;
y.free

z = ~playBuf.note.buffer_(~data).rate_(1).start_(0).outbus_(~inBus).play


[w,x,y,z].do{ arg me; me.free};

(
var dels, perc_freqs, perc_angs, mem_tension, mem_loss, mem_angs;
dels = [0.0] ++ Array.geom(7, 1.0, 1.33875.reciprocal).reverse;
perc_freqs = Array.geom(4, 800, 1.33875);
perc_angs = Array.series(4, 0, 90).degrad;
mem_tension = Array.rand(4, 0.011, 0.019);
mem_loss = Array.rand(4, 0.999, 0.9999);
mem_angs = Array.series(4, 45, 90).degrad;

~percSynths = 4.collect{ arg i;
	~perc.note(addAction: \before, target: ~decNote).freq_(perc_freqs[i])
	.in_gain_(12.dbamp).amp_(0.dbamp).lim_(24.dbamp)
	.inbus_(~processedBus).outbus_(~bfBus)
	.az_(perc_angs[i]).el_(30.degrad)
	.del_(dels[i]).play;
};

~memSynths = 4.collect{ arg i;
	~membrane.note(addAction: \before, target: ~decNote).in_gain_(12.dbamp).amp_(-3.dbamp).lim_(24.dbamp)
	.tension_(mem_tension[i]).loss_(mem_loss[i])
	.inbus_(~processedBus).outbus_(~bfBus)
	.az_(mem_angs[i]).el_(0)
	.del_(dels[i+4]).play;
};
)

~memSynths.do{ arg me; me.amp_(-13.dbamp) }
~memSynths.do{ arg me; me.amp_(0) }

~memSynths.do{ arg me; me.tension.postln}

~percSynths.do{ arg me; me.amp_(0) }

~percSynths.do{ arg me; me.freq.postln }

~percSynths.do{ arg me; me.free }

~memSynths.do{ arg me; me.free }

z.free

s.meter