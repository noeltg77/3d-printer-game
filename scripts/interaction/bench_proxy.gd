class_name BenchProxy
extends Interactable
## Makes one of a print farm's plain benches clickable. The bench is only
## furniture: the premises' one Workbench owns the printers on it. This sits on
## it, takes the clicks and offers what that Workbench offers.

var host: Workbench


func get_actions(agent: Agent) -> Array[Action]:
	return host.get_actions(agent)
