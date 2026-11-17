package core

// game_state_update :: proc (game_state, player_inputs) -> events
// then send game state to all connections unreliably
// send game events reliably, game events are damage, item pickup, door closed, player started to attack etc...
// events need unique ids so clients dont replicate duplicated events ?
// actually lets test client ignores events that are related to their character (start attack) but doesnt ignore or tries to
// predict authorative events (player takes damage, other player starts attack)
state_update :: proc (game_state : ^GameState, player_inputs : []MsgPlayerInput) {
	BALL_SPEED :: 20
	for input in player_inputs {
		game_state.player_pos.xy += BALL_SPEED*f32(input.duration_msec)/1000 * input.input_dir
	}
}
