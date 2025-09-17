using Godot;
using System;
using NWaves.FeatureExtractors;
using NWaves.FeatureExtractors.Options;
using NWaves.Signals;

public partial class PitchDetector : Node
{
	private AudioEffectCapture micCapture;
	private PitchExtractor _pitchExtractor;
	private float[] _buffer = new float[2048];

	[Signal]
	public delegate void PitchDetectedEventHandler(float pitch);

	public override void _Ready()
	{
		// Get mic input from the "Record" bus (replace 0 with your bus index)
		micCapture = AudioServer.GetBusEffect(0, 0) as AudioEffectCapture;

		int sampleRate = 44100;
		int frameSize = 2048;
		int hopSize = 512;

		var pitchOptions = new PitchOptions
		{
			SamplingRate = sampleRate,
			FrameDuration = (double)frameSize / sampleRate,
			HopDuration = (double)hopSize / sampleRate,
			LowFrequency = 80,
			HighFrequency = 400
		};

		_pitchExtractor = new PitchExtractor(pitchOptions);
	}

	public override void _Process(double delta)
	{
		if (micCapture == null || !micCapture.CanGetBuffer(2048))
			return;

		var data = micCapture.GetBuffer(2048);
		for (int i = 0; i < data.Length; i++)
			_buffer[i] = (data[i].X + data[i].Y) / 2.0f;

		var signal = new DiscreteSignal(44100, _buffer);
		var pitchVectors = _pitchExtractor.ComputeFrom(signal);

		if (pitchVectors.Count == 0)
			return;

		// Average all frames for smoothing
		float sum = 0;
		int count = 0;
		foreach (var frame in pitchVectors)
		{
			if (frame.Length > 0 && frame[0] > 0)
			{
				sum += frame[0];
				count++;
			}
		}

		if (count > 0)
		{
			float avgPitch = sum / count;
			EmitSignal(SignalName.PitchDetected, avgPitch);
		}
	}
}
