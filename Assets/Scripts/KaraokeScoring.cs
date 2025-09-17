using Godot;

public partial class ScoringSystem : Node
{
	private Label scoreLabel;
	private Label accuracyLabel;

	private float timer = 0f;
	private int score = 0;

	// Pitch margins in cents
	private const float PERFECT_MARGIN = 25f;
	private const float GOOD_MARGIN = 75f;

	// Set by PitchDetector
	public float CurrentDetectedPitch { get; set; } = 0f;
	public float CurrentReferencePitch { get; set; } = 440f;

	public override void _Ready()
	{
		// Find UI labels
		scoreLabel = GetNode<Label>("../UI/ScoreLabel");
		accuracyLabel = GetNode<Label>("../UI/AccuracyLabel");

		UpdateScoreLabel();
	}

	public override void _Process(double delta)
	{
		timer += (float)delta;
		if (timer >= 1f) // per second scoring
		{
			EvaluatePitch(CurrentDetectedPitch, CurrentReferencePitch);
			timer = 0f;
		}
	}

	private void EvaluatePitch(float detectedPitch, float referencePitch)
	{
		if (detectedPitch <= 0 || referencePitch <= 0)
		{
			accuracyLabel.Text = "Miss!";
			return;
		}

		float centsError = 1200 * Mathf.Log(detectedPitch / referencePitch, 2);

		string comment;
		int points = 0;

		if (Mathf.Abs(centsError) <= PERFECT_MARGIN)
		{
			comment = "Perfect!";
			points = 100;
		}
		else if (Mathf.Abs(centsError) <= GOOD_MARGIN)
		{
			comment = "Good!";
			points = 70;
		}
		else
		{
			comment = "Miss!";
			points = 0;
		}

		score += points;
		UpdateScoreLabel();
		accuracyLabel.Text = comment;
	}

	private void UpdateScoreLabel()
	{
		scoreLabel.Text = $"Score: {score}";
	}
}
