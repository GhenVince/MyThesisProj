using Godot;
using System;
#if TOOLS
[Tool]
public partial class PrecomputeReferencePitchPlugin : EditorPlugin
{
	private Button _button;
	private PrecomputeReferencePitch _targetNode;
	
	public override void _EnterTree()
	{
		GD.Print("Plugin entering tree...");
		
		// Create the button
		_button = new Button();
		_button.Text = "Run Precompute";
		_button.Pressed += OnButtonPressed;
		
		// Set button size and properties
		_button.CustomMinimumSize = new Vector2(120, 30);
		_button.SizeFlagsHorizontal = Control.SizeFlags.ShrinkCenter;
		_button.SizeFlagsVertical = Control.SizeFlags.ShrinkStart;
		
		// Add to inspector dock
		AddControlToDock(DockSlot.RightUl, _button);
		GD.Print("Button added to dock");
		
		// Show button initially for testing
		_button.Show();
		GD.Print("Button shown");
		
		// Connect to selection changed signal
		EditorInterface.Singleton.GetSelection().SelectionChanged += OnSelectionChanged;
		GD.Print("Selection changed signal connected");
	}
	
	public override void _ExitTree()
	{
		GD.Print("Plugin exiting tree...");
		
		if (_button != null)
		{
			RemoveControlFromDocks(_button);
			_button.QueueFree();
		}
	}
	
	private void OnSelectionChanged()
	{
		GD.Print("Selection changed");
		_targetNode = null;
		var selectedNodes = EditorInterface.Singleton.GetSelection().GetSelectedNodes();
		
		GD.Print($"Selected nodes count: {selectedNodes.Count}");
		
		foreach (var node in selectedNodes)
		{
			GD.Print($"Selected node: {node.GetType().Name} - {node.Name}");
			GD.Print($"Full type: {node.GetType().FullName}");
			
			// Try different ways to check for the node type
			if (node is PrecomputeReferencePitch precompute)
			{
				_targetNode = precompute;
				GD.Print("PrecomputeReferencePitch node found via 'is' check!");
				break;
			}
			else if (node.GetType().Name == "PrecomputeReferencePitch")
			{
				_targetNode = node as PrecomputeReferencePitch;
				GD.Print("PrecomputeReferencePitch node found via type name check!");
				break;
			}
			else if (node.HasMethod("RunPrecompute"))
			{
				// If it has the method, treat it as our target
				_targetNode = node as PrecomputeReferencePitch;
				GD.Print("Node with RunPrecompute method found!");
				break;
			}
		}
		
		if (_targetNode != null)
		{
			_button.Show();
			GD.Print("Button shown - target node selected");
		}
		else
		{
			_button.Hide();
			GD.Print("Button hidden - no target node selected");
		}
	}
	
	private void OnButtonPressed()
	{
		GD.Print("Button pressed!");
		if (_targetNode != null)
		{
			_targetNode.RunPrecompute();
			GD.Print("Reference pitch precompute executed!");
		}
		else
		{
			GD.Print("No target node available!");
		}
	}
}
#endif
