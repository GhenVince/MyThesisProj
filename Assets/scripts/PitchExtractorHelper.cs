using Godot;
using NWaves.Signals;
using NWaves.FeatureExtractors;

public static class PitchExtractorHelper
{
	private static PitchExtractor _pitchExtractor;

	public static void Init(int sampleRate = 44100, int frameSize = 2048, int hopSize = 512)
	{
		var pitchOptions = new NWaves.FeatureExtractors.Options.PitchOptions
		{
			SamplingRate = sampleRate,
			FrameDuration = (double)frameSize / sampleRate,
			HopDuration = (double)hopSize / sampleRate,
			LowFrequency = 80,
			HighFrequency = 400
		};
		_pitchExtractor = new PitchExtractor(pitchOptions);
	}

	public static float ComputePitch(float[] frame)
	{
		var signal = new DiscreteSignal(44100, frame);
		var pitchVectors = _pitchExtractor.ComputeFrom(signal);

		if (pitchVectors.Count == 0)
			return 0.0f;

		float sum = 0;
		int count = 0;
		foreach (var f in pitchVectors)
		{
			if (f.Length > 0 && f[0] > 0)
			{
				sum += f[0];
				count++;
			}
		}

		return count > 0 ? sum / count : 0.0f;
	}
}
