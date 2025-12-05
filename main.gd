extends Node


const SERVER_IP = "localhost" # Replace it with the cloud hosting’s public DNS
const SERVER_PORT = 8080

@export var player : PackedScene
@export var maps : Array[PackedScene]


func _input(event):
	if event.is_action_pressed("enter"):
		if %SendMessage.visible:
			var message = %SendMessage.text.strip_edges() # Remove spaces at the beginning
			message = message.replace("[", "[ ") # Prevent from using BBCode
			%DisplayMessagesTimer.start()
			if message != "":
				rpc("message", multiplayer.get_unique_id() , message)
				%SendMessage.release_focus()
		else:
			%Messages.show()
			%SendMessage.grab_focus()

		%SendMessage.text = ""
		%SendMessage.visible = not %SendMessage.visible


func _ready():
	$Chat.hide()

	if OS.has_feature("editor"):
		$Debug.show()
	else:
		$Debug.hide()

	if OS.has_feature("dedicated_server"):
		create_server()
	else:
		create_client()


func create_server():
	var peer = ENetMultiplayerPeer.new()
	var res = peer.create_server(SERVER_PORT)

	if res != OK:
		return

	multiplayer.multiplayer_peer = peer
	
	var map_instance = maps.pick_random().instantiate()
	$Map.add_child(map_instance)

	print("DEDICATED SERVER IS RUNNING")
	print("Waiting for players to join...\n")
	%HostButton.text = "SERVER ONLINE"
	%HostButton.disabled = true

	multiplayer.peer_connected.connect(
		func(id):
			#%Messages.text += "[color=green]" + str(id) + " has joined[/color]\n"
			
			rpc("message", multiplayer.get_unique_id() , "[color=green]" + str(id) + " has joined[/color]")
			
			
			print("%d has joined" % id)
			print("Number of players: %d\n" % multiplayer.get_peers().size())

			var player_instance = player.instantiate()
			player_instance.name = str(id)

			var spawn_area = get_tree().get_nodes_in_group("spawn_area").pick_random()
			var x = randi_range(0, spawn_area.size.x)
			var y = randi_range(0, spawn_area.size.y)
			player_instance.global_position = spawn_area.global_position + Vector2(x, y)

			$Players.add_child(player_instance)
	)

	multiplayer.peer_disconnected.connect(
		func(id):
			rpc("message", multiplayer.get_unique_id() , "[color=red]" + str(id) + " has left[/color]")
			print("%d has left" % id)
			print("Number of players: %d\n" % multiplayer.get_peers().size())
			$Players.get_node(str(id)).queue_free()
	)


func create_client():
	var peer = ENetMultiplayerPeer.new()

	if OS.has_feature("editor"):
		peer.create_client("localhost", SERVER_PORT)
	else:
		peer.create_client(SERVER_IP, SERVER_PORT)

	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(
		func hide_GUI():
		%HostButton.hide()
		$Chat.show()
	)

	multiplayer.server_disconnected.connect(func ():
		create_client() # Try to reconnect
		$StatusLabel.text = "Connection lost — trying to reconnect…"
		%HostButton.show()
		$Chat.hide()
	)


@rpc("any_peer", "call_local", "reliable")
func message(id, msg: String):
	%Messages.show()
	#msg = msg.replace("[", "[ ").replace("]", " ]") # Prevent from using BBCode
	if id == 1:
		id = "SERVER"
	%Messages.text += "%s: %s\n" % [id, msg]
	%DisplayMessagesTimer.start()


func _on_display_messages_timer_timeout() -> void:
	%Messages.hide()
