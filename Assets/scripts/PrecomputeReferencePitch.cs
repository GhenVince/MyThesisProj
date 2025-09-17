using Godot;
using System;
using System.Collections.Generic;
using System.IO;

[Tool]
public partial class PrecomputeReferencePitch : Node
{
	[Export]
	public string VocalPath = "res://Assets/songs/RefVocals/WITH A SMILE [vocals].wav";

	[Export]
	public string SavePath = "res://songs/RefPitchVocal/ReferencePitch.tres";

	private const int SampleRate = 44100;
	private const int FrameSize = 2048;
	private const int HopSize = 512;

	/// <summary>
	/// Call this to precompute the reference pitch from the vocal WAV
	/// </summary>
	public void RunPrecompute()
	{
		GD.Print("Running precompute...");

		if (string.IsNullOrEmpty(VocalPath))
		{
			GD.PushError("VocalPath is empty!");
			return;
		}

		string systemPath = ProjectSettings.GlobalizePath(VocalPath);

		float[] audioData;
		try
		{
			audioData = LoadWavFile(systemPath);
		}
		catch (Exception e)
		{
			GD.PushError("Failed to read WAV file: " + e.Message);
			return;
		}

		if (audioData.Length == 0)
		{
			GD.PushError("No audio data found!");
			return;
		}

		GD.Print($"Loaded {audioData.Length} samples from vocal.");

		// Initialize your C# pitch extractor helper
		PitchExtractorHelper.Init(SampleRate, FrameSize, HopSize);

		List<float> referencePitchList = new List<float>();

		for (int i = 0; i < audioData.Length - FrameSize; i += HopSize)
		{
			float[] frame = new float[FrameSize];
			Array.Copy(audioData, i, frame, 0, FrameSize);

			float pitch = PitchExtractorHelper.ComputePitch(frame);
			referencePitchList.Add(pitch);
		}

		// Save as a Godot Resource
		var pitchRes = new Resource();
		var pitchArray = new Godot.Collections.Array<float>();
		foreach (var p in referencePitchList)
			pitchArray.Add(p);

		pitchRes.Set("pitches", pitchArray);

		var err = ResourceSaver.Save(pitchRes, SavePath);
		if (err == Error.Ok)
			GD.Print("Reference pitch saved to " + SavePath);
		else
			GD.PushError("Failed to save reference pitch resource");
	}

	/// <summary>
	/// Simple 16-bit PCM WAV loader
	/// </summary>
	private float[] LoadWavFile(string path)
	{
		using var reader = new BinaryReader(File.OpenRead(path));
		reader.BaseStream.Seek(22, SeekOrigin.Begin);
		short channels = reader.ReadInt16();
		reader.BaseStream.Seek(24, SeekOrigin.Begin);
		int sampleRate = reader.ReadInt32();
		reader.BaseStream.Seek(34, SeekOrigin.Begin);
		short bitsPerSample = reader.ReadInt16();

		if (bitsPerSample != 16)
			throw new Exception("Only 16-bit PCM WAV supported");

		reader.BaseStream.Seek(44, SeekOrigin.Begin);

		var samples = new List<float>();
		while (reader.BaseStream.Position < reader.BaseStream.Length)
		{
			short sample = reader.ReadInt16();
			samples.Add(sample / 32768f);
			if (channels == 2) reader.ReadInt16(); // skip right channel
		}

		return samples.ToArray();
	}
}
