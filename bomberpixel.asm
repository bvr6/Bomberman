.data
# LED colors (don't change)
.eqv	LED_OFF		0
.eqv	LED_RED		1
.eqv	LED_ORANGE	2
.eqv	LED_YELLOW	3
.eqv	LED_GREEN	4
.eqv	LED_BLUE		5
.eqv	LED_MAGENTA	6
.eqv	LED_WHITE	7

# Board size (don't change)
.eqv	LED_SIZE		2
.eqv	LED_WIDTH	32
.eqv	LED_HEIGHT	32

# System Calls
.eqv	SYS_PRINT_INTEGER	1
.eqv	SYS_PRINT_STRING		4
.eqv	SYS_PRINT_CHARACTER	11
.eqv	SYS_SYSTEM_TIME		30

# Key states
leftPressed:		.word	0
rightPressed:		.word	0
upPressed:		.word	0
downPressed:		.word	0
actionPressed:		.word	0

# Frame counting
lastTime:		.word	0
frameCounter:		.word	0
enemyTime:		.word	0

# Positions
playerCoordinates:	.byte	0, 0	# default position for player
enemyCoordinates1:	.byte	30, 0	# default position for enemy 1
enemyCoordinates2:	.byte	0, 30	# default position for enemy 2
enemyCoordinates3:	.byte	30, 30	# default position for enemy 3
bombCoordinates:		.byte	32, 32	# default position for bomb

# Bomb stuff
bombCounter:		.word	0
bombExplosionPhase:	.byte	0	# counts the phase for each bomb (starts at 0 and goes to 3)
bombExplosionPhaseCounter:	.byte	0	# counts number of frames until it moves to next phase
bombExplosionCenter:	.byte	32, 32	# center of explosion when activated, (32, 32 if not active)
bombExplosionActive:	.byte	0	# boolean that is 0 when an explosion is inactive and 1 otherwise

# Editable variables for game balance
.eqv	TIME_BOMB_DETONATE	25	# Time that bomb detonates
.eqv	TIME_PHASE_CHANGE	5	# Time that bomb changes phases
.eqv	TIME_ENEMY_SPEED		8000	# Time enemies move around
.eqv	BREAKABLE_BLOCKS		200	# Number of blocks

# Messages
loseMessage: 			.asciiz	"You lose!"
winMessage:			.asciiz "You win!"

.text
.globl main
main:	
	li	a0, 1
	jal	displayRedraw				# displayRedraw(1);
	# Initialize the game state
	jal drawDestructible			# draw destructible blocks
	jal drawIndestructible			# draw indestructible blocks
	li a0, 0					# blue bars
	li a1, 31
	li a2, 32
	li a3, LED_BLUE
	jal drawHorizontalLine
	li a0, 31
	li a1, 0
	jal drawVerticalLine
	
	li a0, 0					# x
	li a1, 0					# y
	li a2, LED_WHITE				# color white
	jal displaySetLED				# draw player
	
	li a0, 30
	li a1, 0
	li a2, LED_RED
	jal displaySetLED
	
	li a0, 0
	li a1, 30
	li a2, LED_RED
	jal displaySetLED
	
	li a0, 30
	li a1, 30
	li a2, LED_RED
	jal displaySetLED
	
	jal	initialize				# initialize()
	
	
	# Run our game!
	jal	gameLoop				# gameLoop()
	
	# The game is over.
gameLose:
	li	v0, 55
	la	a0, loseMessage
	li	a1, 2
	syscall
	# Exit
	li	v0, 10
	syscall						# syscall(EXIT)
gameWin:
	li	v0, 55
	la	a0, winMessage
	li	a1, 1
	syscall
	# Exit
	li	v0, 10
	syscall						# syscall(EXIT)

# void initialize()
#   Initializes the game state.
initialize:
	push	ra
	
	# Set lastTime to a reasonable number
	jal	getSystemTime
	sw	v0, lastTime
	
	# Clear the screen
	
	
	# Initialize anything else
	
	pop	ra
	jr	ra
				
# void gameLoop()
#   Infinite loop for the game logic
gameLoop:
	push	ra

gameLoopStart:						# loop {
	jal	getSystemTime				#
	move	s0, v0					# 	s0 = getSystemTime();
	
	move	a0, s0
	jal	handleInput				# 	v0 = handleInput(elapsed: a0);
							# s1 = character coordinate x
							# s2 = character coordinate y
	la	t0, enemyTime
	lw	t1, 0(t0)
	blt	t1, TIME_ENEMY_SPEED, skipEnemyMovement	# edit to change speed of enemy
	sw	0(t0), zero
	jal	handleEnemy
skipEnemyMovement:
	la	t0, enemyTime
	lw	t1, 0(t0)
	addi	t1, t1, 1
	sw	0(t0), t1
	# Determine if a frame passed
	lw	t0, lastTime
	sub	t0, s0, t0
	blt	t0, 50, gameLoopStart			# 	if (s0 - lastTime >= 50) {
	
	# Update last time
	sw	s0, lastTime				# 		lastTime = s0;
	
	# Update bomb timer (if activated)
	jal 	handleBombCounter
	la	t0, bombExplosionActive
	lb	t1, 0(t0)
	beqz	t1, updateGameState
	jal 	handleBombPhase
	
	
	# Update our game state (if a frame elapsed)
updateGameState:
	move	a0, s0
	jal	update					# 		v0 = update();
			
	la	t0, enemyCoordinates1
	la	t1, enemyCoordinates2
	la	t2, enemyCoordinates3
	lb	t0, 0(t0)
	lb	t1, 0(t1)
	lb	t2, 0(t2)
	bne	t0, 32, skipEnemyCheck
	bne	t1, 32, skipEnemyCheck
	bne	t2, 32, skipEnemyCheck
	j	gameWin

	# Redraw (a0 = 0; do not clear the screen!)
skipEnemyCheck:
	li	a0, 0
	jal	displayRedraw				# 		displayRedraw(0);
							#	}
	j	gameLoopStart				# }

gameLoopExit:
	pop	ra
	jr	ra					# return;
			
# int getSystemTime()
#   Returns the number of milliseconds since system booted.
getSystemTime:
	# Now, get the current time
	li	v0, SYS_SYSTEM_TIME
	syscall						# a0 = syscall(GET_SYSTEM_TIME);
	
	move	v0, a0
	
	jr	ra					# return v0;
	
handleEnemy:
	push	ra
	la	a0, enemyCoordinates1
	lb	t0, 0(a0)
	beq	t0, 32, handleEnemy2
	jal 	handleEnemyMovement
handleEnemy2:
	la	a0, enemyCoordinates2
	lb	t0, 0(a0)
	beq	t0, 32, handleEnemy3
	jal	handleEnemyMovement
handleEnemy3:
	la	a0, enemyCoordinates3
	lb	t0, 0(a0)
	beq	t0, 32, endHandleEnemy
	jal	handleEnemyMovement
endHandleEnemy:
	pop	ra
	jr	ra

handleEnemyMovement:
	push	ra
	push	s0
	move	s0, a0		# contains enemyCoordinates
	lb	a0, 0(s0)	# load x coordinate
	lb	a1, 1(s0)	# load y coordinate
	jal	displayGetLED
	beq	v0, LED_MAGENTA, handleEnemyDead
handleEnemyRandomMovement:
	li	v0, 42
	li	a1, 4		# do random movement calculation
	syscall
	beq	a0, 1, handleEnemyRandomMovementRight
	beq	a0, 2, handleEnemyRandomMovementUp
	beq	a0, 3, handleEnemyRandomMovementDown

	lb	a0, 0(s0)	# load x coordinate
	lb	a1, 1(s0)	# load y coordinate
	beqz	a0, handleEnemyRandomMovementReturn
handleEnemyRandomMovementLeft:
	subi	a0, a0, 1	# x = x - 1
	jal	displayGetLED	# v0 contains color
#	beq	v0, LED_MAGENTA, _playerDead
	beq	v0, LED_WHITE, gameLose
	beq	v0, LED_MAGENTA, handleEnemyDead
	bne	v0, LED_OFF, handleEnemyRandomMovementReturn
	
	lb	a0, 0(s0)	# argument x
	lb	a1, 1(s0)	# argument y
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	li	a2, LED_RED
	subi	a0, a0, 1
	sb	0(s0), a0
	jal	displaySetLED
	j	handleEnemyRandomMovementReturn

handleEnemyRandomMovementRight:
	lb	a0, 0(s0)	# load x coordinate
	lb	a1, 1(s0)	# load y coordinate
	beq	a0, 30, handleEnemyRandomMovementReturn

	addi	a0, a0, 1	# x = x - 1
	jal	displayGetLED	# v0 contains color
	beq	v0, LED_WHITE, gameLose
	beq	v0, LED_MAGENTA, handleEnemyDead
	bne	v0, LED_OFF, handleEnemyRandomMovementReturn
	
	lb	a0, 0(s0)	# argument x
	lb	a1, 1(s0)	# argument y
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	li	a2, LED_RED
	addi	a0, a0, 1
	sb	0(s0), a0
	jal	displaySetLED
	j	handleEnemyRandomMovementReturn
	
handleEnemyRandomMovementUp:
	lb	a0, 0(s0)	# load x coordinate
	lb	a1, 1(s0)	# load y coordinate
	beqz	a1, handleEnemyRandomMovementReturn

	subi	a1, a1, 1	# x = x - 1
	jal	displayGetLED	# v0 contains color
	beq	v0, LED_WHITE, gameLose
	beq	v0, LED_MAGENTA, handleEnemyDead
	bne	v0, LED_OFF, handleEnemyRandomMovementReturn
	
	lb	a0, 0(s0)	# argument x
	lb	a1, 1(s0)	# argument y
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	li	a2, LED_RED
	subi	a1, a1, 1
	sb	1(s0), a1
	jal	displaySetLED
	j	handleEnemyRandomMovementReturn
	
handleEnemyRandomMovementDown:
	lb	a0, 0(s0)	# load x coordinate
	lb	a1, 1(s0)	# load y coordinate
	beq	a1, 30, handleEnemyRandomMovementReturn

	addi	a1, a1, 1	# x = x - 1
	jal	displayGetLED	# v0 contains color
	beq	v0, LED_WHITE, gameLose
	beq	v0, LED_MAGENTA, handleEnemyDead
	bne	v0, LED_OFF, handleEnemyRandomMovementReturn
	
	lb	a0, 0(s0)	# argument x
	lb	a1, 1(s0)	# argument y
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	li	a2, LED_RED
	addi	a1, a1, 1
	sb	1(s0), a1
	jal	displaySetLED
	j	handleEnemyRandomMovementReturn
handleEnemyDead:
	li	t0, 32
	sb	0(s0), t0
	sb	1(s0), t0
handleEnemyRandomMovementReturn:
	pop	s0
	pop	ra
	jr	ra
# void handleBombCounter()
# Updates bomb counter
handleBombCounter:
	push 	ra
	push	s0
	push	s1
	la	s0, bombCounter
	lw	t0, 0(s0)
	beqz	t0, _handleBombCounterExit		# skips if bomb counter equals zero
	subi	t0, t0, 1
	sw	0(s0), t0				# ticks down 1 and saves
	bnez	t0, _handleBombCounterExit		# branch if bomb hasn't reached zero yet
	la	s0, bombCoordinates
	lb	a0, 0(s0)
	lb	a1, 1(s0)				
	la	t0, bombExplosionCenter			# move bomb coordinates to bombExplosionCenter
	sb	0(t0), a0
	sb	1(t0), a1
	li	a2, LED_OFF
	jal	displaySetLED				# remove bomb from playing field
	li	t0, 32
	li	t1, 32
	sb	0(s0), t0				# reset bomb position
	sb	1(s0), t1
	li	v0, 1
	la	t0, bombExplosionActive
	sb	v0, 0(t0)				# bomb explosion now occuring
_handleBombCounterExit:
	pop	s1
	pop	s0
	pop	ra
	jr	ra
	
handleBombPhase:
	push	ra
	push	s0
	push	s1
	
	la	s0, bombExplosionPhase
	la	s1, bombExplosionPhaseCounter
	la	s2, bombExplosionCenter
	lb	t0, 0(s0)	# phase
	lb	t1, 0(s1)	# counter
	beqz	t0, _startFirstPhase
	j 	_firstPhase
# t0 = phase number, t1 = counter

_startFirstPhase:
	li 	t1, TIME_PHASE_CHANGE
	addi	t0, t0, 1
	sb	0(s1), t1	# reset counter
	sb	0(s0), t0	# increment phase
_firstPhase:
# center
	lb	a0, 0(s2)	# load x coordinate of bomb center
	lb	a1, 1(s2)	# load y coordinate of bomb center
	li	a2, LED_MAGENTA	# load color of bomb explosion
	jal	displaySetLED
# left
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	beqz	a0, _firstPhaseRight
	subi	a0, a0, 1
	jal	displayGetLED
	beq	v0, LED_GREEN, _firstPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a0, a0, 1
	li	a2, LED_MAGENTA
	jal	displaySetLED
_firstPhaseRight:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	bge	a0, 31, _firstPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _firstPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	li	a2, LED_MAGENTA
	jal	displaySetLED
	
_firstPhaseUp:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	beqz	a1, _firstPhaseDown
	subi	a1, a1, 1
	jal	displayGetLED
	beq	v0, LED_GREEN, _firstPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 1
	li	a2, LED_MAGENTA
	jal	displaySetLED
	
_firstPhaseDown:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	bge	a1, 31, _secondPhase
	jal	displayGetLED
	beq	v0, LED_GREEN, _secondPhase
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	li	a2, LED_MAGENTA
	jal	displaySetLED
	
_secondPhase:
	lb	t0, 0(s0)	# phase
	lb	t1, 0(s1)	# counter
	bge	t0, 2, _secondPhaseLeft
	subi	t1, t1, 1	# tick counter down if phase 1
	sb	0(s1), t1
	bnez	t1, _exitHandleBombPhase
	addi	t0, t0, 1
	li	t1, TIME_PHASE_CHANGE
	sb	0(s0), t0
	sb	0(s1), t1
	j	_exitHandleBombPhase
	
_secondPhaseLeft:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 1
	bltz	a0, _secondPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _secondPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 2
	bltz	a0, _secondPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _secondPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a0, a0, 2
	li	a2, LED_MAGENTA
	jal	displaySetLED
	
_secondPhaseRight:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	bge	a0, 31, _secondPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _secondPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 2
	bge	a0, 31, _secondPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _secondPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 2
	li	a2, LED_MAGENTA
	jal	displaySetLED

_secondPhaseUp:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 1
	bltz	a1, _secondPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _secondPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 2
	bltz	a1, _secondPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _secondPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 2
	li	a2, LED_MAGENTA
	jal	displaySetLED

_secondPhaseDown:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	bge	a1, 31, _thirdPhase
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhase
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 2
	bge	a1, 31, _thirdPhase
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhase
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 2
	li	a2, LED_MAGENTA
	jal	displaySetLED
	
_thirdPhase:
	lb	t0, 0(s0)	# phase
	lb	t1, 0(s1)	# counter
	bge	t0, 3, _thirdPhaseLeft
	subi	t1, t1, 1	# tick counter down if phase 1
	sb	0(s1), t1
	bnez	t1, _exitHandleBombPhase
	addi	t0, t0, 1
	li	t1, TIME_PHASE_CHANGE
	sb	0(s0), t0
	sb	0(s1), t1
	j	_exitHandleBombPhase
	
_thirdPhaseLeft:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 1
	bltz	a0, _thirdPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 2
	bltz	a0, _thirdPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 3
	bltz	a0, _thirdPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a0, a0, 3
	li	a2, LED_MAGENTA
	jal	displaySetLED
	
_thirdPhaseRight:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	bge	a0, 31, _thirdPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 2
	bge	a0, 31, _thirdPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 3
	bge	a0, 31, _thirdPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 3
	li	a2, LED_MAGENTA
	jal	displaySetLED

_thirdPhaseUp:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 1
	bltz	a1, _thirdPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 2
	bltz	a1, _thirdPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 3
	bltz	a1, _thirdPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _thirdPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 3
	li	a2, LED_MAGENTA
	jal	displaySetLED

_thirdPhaseDown:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	bge	a1, 31, _endPhase
	jal	displayGetLED
	beq	v0, LED_GREEN, _endPhase
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 2
	bge	a1, 31, _endPhase
	jal	displayGetLED
	beq	v0, LED_GREEN, _endPhase
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 3
	bge	a1, 31, _endPhase
	jal	displayGetLED
	beq	v0, LED_GREEN, _endPhase
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 3
	li	a2, LED_MAGENTA
	jal	displaySetLED
	
_endPhase:
	lb	t0, 0(s0)	# phase
	lb	t1, 0(s1)	# counter
	beqz	t1, _clearExplosion
	subi	t1, t1, 1	# tick counter down if phase 1
	sb	0(s1), t1
	j	_exitHandleBombPhase
	
_clearExplosion:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	li	a2, LED_OFF
	jal	displaySetLED

	lb	a0, 0(s2)
	lb	a1, 1(s2)
	beqz	a0, _clearFirstPhaseRight
	subi	a0, a0, 1
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearFirstPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a0, a0, 1
	li	a2, LED_OFF
	jal	displaySetLED
_clearFirstPhaseRight:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	bge	a0, 31, _clearFirstPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearFirstPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	li	a2, LED_OFF
	jal	displaySetLED
	
_clearFirstPhaseUp:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	beqz	a1, _clearFirstPhaseDown
	subi	a1, a1, 1
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearFirstPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 1
	li	a2, LED_OFF
	jal	displaySetLED
	
_clearFirstPhaseDown:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	bge	a1, 31, _clearSecondPhaseLeft
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearSecondPhaseLeft
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	li	a2, LED_OFF
	jal	displaySetLED
	
_clearSecondPhaseLeft:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 1
	bltz	a0, _clearSecondPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearSecondPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 2
	bltz	a0, _clearSecondPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearSecondPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a0, a0, 2
	li	a2, LED_OFF
	jal	displaySetLED
	
_clearSecondPhaseRight:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	bge	a0, 31, _clearSecondPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearSecondPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 2
	bge	a0, 31, _clearSecondPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearSecondPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 2
	li	a2, LED_OFF
	jal	displaySetLED

_clearSecondPhaseUp:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 1
	bltz	a1, _clearSecondPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearSecondPhaseDown

	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 2
	bltz	a1, _clearSecondPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearSecondPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 2
	li	a2, LED_OFF
	jal	displaySetLED

_clearSecondPhaseDown:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	bge	a1, 31, _clearThirdPhaseLeft
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseLeft
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 2
	bge	a1, 31, _clearThirdPhaseLeft
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseLeft
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 2
	li	a2, LED_OFF
	jal	displaySetLED
	
_clearThirdPhaseLeft:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 1
	bltz	a0, _clearThirdPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 2
	bltz	a0, _clearThirdPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi 	a0, a0, 3
	bltz	a0, _clearThirdPhaseRight
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseRight
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a0, a0, 3
	li	a2, LED_OFF
	jal	displaySetLED
	
_clearThirdPhaseRight:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 1
	bge	a0, 31, _clearThirdPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 2
	bge	a0, 31, _clearThirdPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 3
	bge	a0, 31, _clearThirdPhaseUp
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseUp
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a0, a0, 3
	li	a2, LED_OFF
	jal	displaySetLED

_clearThirdPhaseUp:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 1
	bltz	a1, _clearThirdPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 2
	bltz	a1, _clearThirdPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 3
	bltz	a1, _clearThirdPhaseDown
	jal	displayGetLED
	beq	v0, LED_GREEN, _clearThirdPhaseDown
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	subi	a1, a1, 3
	li	a2, LED_OFF
	jal	displaySetLED

_clearThirdPhaseDown:
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 1
	bge	a1, 31, _turnOffBombExplosion
	jal	displayGetLED
	beq	v0, LED_GREEN, _turnOffBombExplosion
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 2
	bge	a1, 31, _turnOffBombExplosion
	jal	displayGetLED
	beq	v0, LED_GREEN, _turnOffBombExplosion
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 3
	bge	a1, 31, _turnOffBombExplosion
	jal	displayGetLED
	beq	v0, LED_GREEN, _turnOffBombExplosion
	
	lb	a0, 0(s2)
	lb	a1, 1(s2)
	addi	a1, a1, 3
	li	a2, LED_OFF
	jal	displaySetLED
	
_turnOffBombExplosion:
	la	t0, bombExplosionActive
	li	t1, 0
	sb	0(t0), t1
	la	t0, bombExplosionCenter
	li	t1, 32
	li	t2, 32
	sb	0(t0), t1
	sb	1(t0), t2
	la	t0, bombExplosionPhase
	li	t1, 0
	sb	0(t0), t1
	la	t0, bombExplosionPhaseCounter
	li	t1, 0
	sb	0(t0), t1
	
_exitHandleBombPhase:
	pop	s1
	pop	s0
	pop	ra
	jr	ra
# bool update(elapsed)
#   Updates the game for this frame.
# returns: v0: 1 when the game should end.
update:
	push	ra
	push	s0
	
	# Increment the frame counter
	lw	t0, frameCounter
	add	t0, t0, 1
	sw	t0, frameCounter			# frameCounter++;
	
	li	s0, 0					# s0 = 0;
	
	# Update all of the game state
	jal	updateStuff
	beq	v0, 1, gameLose
	or	s0, s0, v0				# s0 = s0 | updateStuff();
	
_updateExit:
	move	v0, s0
	
	pop	s0
	pop	ra
	jr	ra					# return s0;
	
# void updateStuff()
updateStuff:
	push	ra
	push	s0
	la	s0, playerCoordinates
	
_updateStuffLeft:
	lw	t0, leftPressed
	beq	t0, 0, _updateStuffRight
	lb	a0, 0(s0)	# load x coordinate
	lb	a1, 1(s0)	# load y coordinate
	beqz	a0, _updateStuffRight

	subi	a0, a0, 1	# x = x - 1
	jal	displayGetLED	# v0 contains color
	beq	v0, LED_MAGENTA, _playerDead
	beq	v0, LED_RED, _playerDead
	bne	v0, LED_OFF, _updateStuffRight
	
	lb	a0, 0(s0)	# argument x
	lb	a1, 1(s0)	# argument y
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	la	t0, bombCoordinates
	lb	t1, 0(t0)	# x bomb coordinate
	lb	t2, 1(t0)	# y bomb coordinate
	bne	t1, a0, _noBombPressLeft
	bne	t2, a1, _noBombPressLeft
	move	a0, t1
	move	a1, t2
	li	a2, LED_BLUE
	jal	displaySetLED
_noBombPressLeft:
	subi	a0, a0, 1	# x = x - 1
	sb	0(s0), a0	# save new coordinate
	li	a2, LED_WHITE
	jal	displaySetLED
	

_updateStuffRight:
	lw	t0, rightPressed
	beq	t0, 0, _updateStuffUp
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	addi	a0, a0, 1	# x = x + 1
	jal	displayGetLED	# v0 contains color
	beq	v0, LED_MAGENTA, _playerDead
	beq	v0, LED_RED, _playerDead
	bne	v0, LED_OFF, _updateStuffUp
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	la	t0, bombCoordinates
	lb	t1, 0(t0)	# x bomb coordinate
	lb	t2, 1(t0)	# y bomb coordinate
	bne	t1, a0, _noBombPressRight
	bne	t2, a1, _noBombPressRight
	move	a0, t1
	move	a1, t2
	li	a2, LED_BLUE
	jal	displaySetLED
_noBombPressRight:
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	addi	a0, a0, 1
	sb	0(s0), a0
	li	a2, LED_WHITE
	jal	displaySetLED

_updateStuffUp:	# y = y - 1
	lw	t0, upPressed
	beq	t0, 0, _updateStuffDown
	lb	a0, 0(s0)	# load x coordinate
	lb	a1, 1(s0)	# load y coordinate
	beq	a1, 0, _updateStuffDown
	
	subi	a1, a1, 1	# y = y - 1
	jal	displayGetLED	# v0 contains color
	beq	v0, LED_MAGENTA, _playerDead
	beq	v0, LED_RED, _playerDead
	bne	v0, LED_OFF, _updateStuffDown
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	la	t0, bombCoordinates
	lb	t1, 0(t0)	# x bomb coordinate
	lb	t2, 1(t0)	# y bomb coordinate
	bne	t1, a0, _noBombPressUp
	bne	t2, a1, _noBombPressUp
	move	a0, t1
	move	a1, t2
	li	a2, LED_BLUE
	jal	displaySetLED
_noBombPressUp:
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	subi	a1, a1, 1
	sb	1(s0), a1
	li	a2, LED_WHITE
	jal	displaySetLED

_updateStuffDown: # y = y + 1
	lw	t0, downPressed
	beq	t0, 0, _updateStuffAction
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	addi	a1, a1, 1	# y = y + 1
	jal	displayGetLED	# v0 contains color
	beq	v0, LED_MAGENTA, _playerDead
	beq	v0, LED_RED, _playerDead
	bne	v0, LED_OFF, _updateStuffAction
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	li	a2, LED_OFF	# argument color
	jal	displaySetLED	# remove current position color
	
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	la	t0, bombCoordinates
	lb	t1, 0(t0)	# x bomb coordinate
	lb	t2, 1(t0)	# y bomb coordinate
	bne	t1, a0, _noBombPressDown
	bne	t2, a1, _noBombPressDown
	move	a0, t1
	move	a1, t2
	li	a2, LED_BLUE
	jal	displaySetLED
_noBombPressDown:
	addi	a1, a1, 1
	sb	1(s0), a1
	li	a2, LED_WHITE
	jal	displaySetLED

_updateStuffAction:
	lw	t0, actionPressed
	beq	t0, 0, _checkPlayer
	la	t0, bombCoordinates
	lb	t1, 0(t0)	# load x coordinates of bomb
	lb	t2, 1(t0)	# load y coordinates of bomb
	bne	t1, 32, _checkPlayer
	bne	t1, 32, _checkPlayer
	lb	t3, 0(s0)
	lb	t4, 1(s0)
	sb	0(t0), t3
	sb	1(t0), t4	# save coordinates of bomb to coordinates of player
	
	la	t0, bombCounter
	li	t1, TIME_BOMB_DETONATE		# frames until bomb detonate
	sw	0(t0), t1
	
_checkPlayer:
	lb	a0, 0(s0)
	lb	a1, 1(s0)
	jal displayGetLED
	bne	v0, LED_WHITE, _playerDead
	j	_playerAlive
	
_playerDead:
	li	v0, 1
	j 	_updateStuffExit
_playerAlive:
	# Return 0 so the game loop doesn't exit
	li	v0, 0

_updateStuffExit:
	pop	s0
	pop	ra
	jr	ra					# return 0;
	
# LED Input Handling Function
# -----------------------------------------------------
	
# bool handleInput(elapsed)
#   Handles any button input.
# returns: v0: 1 when the game should end.
handleInput:
	push	ra
	la	t0, playerCoordinates
	lb	a0, 0(t0)
	lb	a1, 1(t0)
	jal	displayGetLED
	beq	v0, LED_WHITE, continueInput
	li	v0, 1
	pop	ra
	jr	ra
continueInput:
	# Get the key state memory
	li	t0, 0xffff0004
	lw	t1, (t0)
	
	# Check for key states
	and	t2, t1, 0x1
	sw	t2, upPressed
	
	srl	t1, t1, 1
	and	t2, t1, 0x1
	sw	t2, downPressed
	
	srl	t1, t1, 1
	and	t2, t1, 0x1
	sw	t2, leftPressed
	
	srl	t1, t1, 1
	and	t2, t1, 0x1
	sw	t2, rightPressed
	
	srl	t1, t1, 1
	and	t2, t1, 0x1
	sw	t2, actionPressed
	
	move	v0, t2
	
	pop	ra
	jr	ra
	
# LED Display Functions
# -----------------------------------------------------
	
# void displayRedraw()
#   Tells the LED screen to refresh.
#
# arguments: $a0: when non-zero, clear the screen
# trashes:   $t0-$t1
# returns:   none
displayRedraw:
	li	t0, 0xffff0000
	sw	a0, (t0)
	jr	ra

# void displaySetLED(int x, int y, int color)
#   sets the LED at (x,y) to color
#   color: 0=off, 1=red, 2=yellow, 3=green
#
# arguments: $a0 is x, $a1 is y, $a2 is color
# returns:   none
#
displaySetLED:
	push	s0
	push	s1
	push	s2
	
	# I am trying not to use t registers to avoid
	#   the common mistakes students make by mistaking them
	#   as saved.
	
	#   :)

	# Byte offset into display = y * 16 bytes + (x / 4)
	sll	s0, a1, 6      # y * 64 bytes
	
	# Take LED size into account
	mul	s0, s0, LED_SIZE
	mul	s1, a0, LED_SIZE
		
	# Add the requested X to the position
	add	s0, s0, s1
	
	li	s1, 0xffff0008 # base address of LED display
	add	s0, s1, s0    # address of byte with the LED
	
	# s0 is the memory address of the first pixel
	# s1 is the memory address of the last pixel in a row
	# s2 is the current Y position	
	
	li	s2, 0	
_displaySetLEDYLoop:
	# Get last address
	add	s1, s0, LED_SIZE
	
_displaySetLEDXLoop:
	# Set the pixel at this position
	sb	a2, (s0)
	
	# Go to next pixel
	add	s0, s0, 1
	
	beq	s0, s1, _displaySetLEDXLoopExit
	j	_displaySetLEDXLoop
	
_displaySetLEDXLoopExit:
	# Reset to the beginning of this block
	sub	s0, s0, LED_SIZE
	
	# Move to next row
	add	s0, s0, 64
	
	add	s2, s2, 1
	beq	s2, LED_SIZE, _displaySetLEDYLoopExit
	
	j _displaySetLEDYLoop
	
_displaySetLEDYLoopExit:
	
	pop	s2
	pop	s1
	pop	s0
	jr	ra
	
# int displayGetLED(int x, int y)
#   returns the color value of the LED at position (x,y)
#
#  arguments: $a0 holds x, $a1 holds y
#  returns:   $v0 holds the color value of the LED (0 through 7)
#
displayGetLED:
	push	s0
	push	s1

	# Byte offset into display = y * 16 bytes + (x / 4)
	sll	s0, a1, 6      # y * 64 bytes
	
	# Take LED size into account
	mul	s0, s0, LED_SIZE
	mul	s1, a0, LED_SIZE
		
	# Add the requested X to the position
	add	s0, s0, s1
	
	li	s1, 0xffff0008 # base address of LED display
	add	s0, s1, s0    # address of byte with the LED
	lbu	v0, (s0)
	
	pop	s1
	pop	s0
	jr	ra
	
drawDestructible:
 # prologue
 push ra
 push s0
 push s1
 push s2
 push s3

# Preserve all input parameters
 li s2, LED_YELLOW                        # s2 contains colour
 li s3, 0				# s3 contains i = 0
  
# s0 contains x
# s1 contains y

_drawDestructible_for_condition:
 bge s3, BREAKABLE_BLOCKS, _drawDestructible_for_end         # Check if i > BREAKABLE_BLOCKS
 li a1, 31				# set range from 1-32
 li v0, 42				# random int range

 syscall					# v0 contains random number from 1-32
 move s0, a0				# set x coordinate
 syscall
 move s1, a0				# set y coordinate
 
 ble s0, 2, _drawDestructible_test_y	# test for y
 bge s0, 28, _drawDestructible_test_y
 j _drawDestructible_setLED
 
 _drawDestructible_test_y:
 ble s1, 2, _drawDestructible_for_condition	# reroll
 bge s1, 28, _drawDestructible_for_condition
 
 _drawDestructible_setLED:
  # for loop implementation
    move a0, s0	                               # Calculate x-coordinate
    move a1, s1                                   # Calculate y-coordinate
    move a2, s2                                   # Colour set by user
    jal displaySetLED
  addi s3, s3, 1					# increment i
  j _drawDestructible_for_condition
  
_drawDestructible_for_end:
  # epilogue
  pop s3
  pop s2
  pop s1
  pop s0
  pop ra
  jr ra
 
		
drawIndestructible:
  # prologue
  push ra
  push s0
  push s1
  push s2


  # Preserve all input parameters
  li s0, 1                                     # s0 contains x
  li s1, 1                                     # s1 contains y
  li s2, LED_GREEN                        # s2 contains colour

  #
_drawIndestructible_for_condition:
  bgt s0, 29, _drawIndestructible_increment_y         # Check if x > 29
  # for loop implementation
    move a0, s0	                               # Calculate x-coordinate
    move a1, s1                                   # Calculate y-coordinate
    move a2, s2                                   # Colour set by user
    addi s0, s0, 2				# Increase x-coordinate by 2
    jal displaySetLED
  j _drawIndestructible_for_condition
  
 _drawIndestructible_increment_y:
 li s0, 1					# x-coordinate = 1
 addi s1, s1, 2					# y-coordinate = y + 2					
 ble s1, 29, _drawIndestructible_for_condition	# check if y <= 29
_drawIndescuctible_for_end:
  # epilogue
  pop s2
  pop s1
  pop s0
  pop ra
  jr ra
  
drawHorizontalLine:
  # prologue
  push ra
  push s0
  push s1
  push s2
  push s3
  push s4
  push a0
  push a1
  push a2

  # Preserve all input parameters
  move s0, a0                                     # s0 contains x
  move s1, a1                                     # s1 contains y
  move s2, a2                                     # s2 contains size
  move s3, a3                                     # s3 contains colour

  #
  li s4, 0                                        # s4 contains i, initialize i=0
_drawHorizontalLine_for_condition:
  bge s4, s2, _drawHorizontalLine_for_end         # Check if i >= size
  # for loop implementation
    add a0, s0, s4                                # Calculate x-coordinate = x+i
    move a1, s1                                   # Calculate y-coordinate is fixed
    move a2, s3                                   # Colour set by user
    jal displaySetLED
  add s4, s4, 1                                   # Increment i
  j _drawHorizontalLine_for_condition
_drawHorizontalLine_for_end:

  # epilogue
  pop a2
  pop a1
  pop a0
  pop s4
  pop s3
  pop s2
  pop s1
  pop s0
  pop ra
  jr ra
  
drawVerticalLine:
  # prologue
  push ra
  push s0
  push s1
  push s2
  push s3
  push s4
  push a0
  push a1
  push a2

  # Preserve all input parameters
  move s0, a0                                     # s0 contains x
  move s1, a1                                     # s1 contains y
  move s2, a2                                     # s2 contains size
  move s3, a3                                     # s3 contains colour

  #
  li s4, 0                                        # s4 contains i, initialize i=0
_drawVerticalLine_for_condition:
  bge s4, s2, _drawVerticalLine_for_end         # Check if i >= size
  # for loop implementation
    move a0, s0                                # Calculate x-coordinate = x+i
    add a1, s1, s4                                   # Calculate y-coordinate is fixed
    move a2, s3                                   # Colour set by user
    jal displaySetLED
  add s4, s4, 1                                   # Increment i
  j _drawVerticalLine_for_condition
_drawVerticalLine_for_end:

  # epilogue
  pop a2
  pop a1
  pop a0
  pop s4
  pop s3
  pop s2
  pop s1
  pop s0
  pop ra
  jr ra
