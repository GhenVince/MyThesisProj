using Godot;
using System;
using NWaves.FeatureExtractors;
using NWaves.FeatureExtractors.Options;
using NWaves.Signals;
using System.Collections.Generic;

public partial class PitchDetector : Node
{
	// Reference to your pitch detector node
	[Export]
	public NodePath PitchDetectorPath;

	private PitchDetector _pitchDetector;
	private List<float> _pitchBuffer = new List<float>(); // store detected pitches for 1 sec

	// User settings
	private float targetPitch = 440f; // Example: target note pitch
	private float perfectMargin = 10f; // Hz
	private float goodMargin = 30f; // Hz
	private float updateInterval = 1.0f; // seconds

	private float timer = 0f;

	[Signal]
	public delegate void ScoreUpdatedEventHandler(float score, string comment);

	public override void _Ready()
	{
		_pitchDetector = GetNode<PitchDetector>(PitchDetectorPath);
		_pitchDetector.Connect("PitchDetected", Callable.From(this, "_OnPitchDetected"));

	}

	private void _OnPitchDetected(float pitch)
	{
		// Store for smoothing
		_pitchBuffer.Add(pitch);
	}

	public override void _Process(double delta)
	{
		timer += (float)delta;

		if (timer >= updateInterval)
		{
			timer = 0f;

			if (_pitchBuffer.Count == 0)
				return;

			// --- Real-time smoothing ---
			float sum = 0f;
			foreach (var p in _pitchBuffer)
				sum += p;
			float avgPitch = sum / _pitchBuffer.Count;

			// --- Scoring ---
			float diff = Math.Abs(avgPitch - targetPitch);
			string comment = "";
			float score = 0f;

			if (diff <= perfectMargin)
			{
				comment = "Perfect";
				score = 100f;
			}
			else if (diff <= goodMargin)
			{
				comment = "Good";
				score = 70f;
			}
			else
			{
				comment = "Miss";
				score = 0f;
			}

			// Emit score + comment
			EmitSignal(SignalName.ScoreUpdated, score, comment);

			// Clear buffer for next second
			_pitchBuffer.Clear();
		}
	}

	// Optional: change target pitch dynamically
	public void SetTargetPitch(float pitch)
	{
		targetPitch = pitch;
	}
}
