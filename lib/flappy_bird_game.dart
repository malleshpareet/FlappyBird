import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_manager.dart';

enum GameState { menu, playing, gameOver }

class FlappyBirdGame extends FlameGame with TapDetector {
  static const double gravity = 980;
  static const double jumpSpeed = 350;
  static double gameWidth = 360;
  static double gameHeight = 640;
  static const double pipeGap = 150;
  static const double pipeWidth = 60;

  late Bird bird;
  late Background background;
  late TextComponent scoreText;
  late TextComponent highScoreText;
  late TextComponent menuText;
  late TextComponent gameOverText;

  GameState gameState = GameState.menu;
  int score = 0;
  List<int> topScores = [0, 0, 0]; // Top 3 scores
  double pipeSpawnTimer = 0;
  final double pipeSpawnInterval = 2.0;
  final List<Pipe> pipes = [];

  // Audio manager instance
  final AudioManager _audioManager = AudioManager();

  @override
  Future<void> onLoad() async {
    // Load top scores
    await loadHighScore();

    // Initialize audio manager (don't start music yet - wait for user interaction)
    await _audioManager.initialize();

    // Initialize components
    background = Background();
    bird = Bird();
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(10, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 3, offset: Offset(2, 2)),
          ],
        ),
      ),
    );

    highScoreText = TextComponent(
      text: topScores[0] > 0 ? 'Best: ${topScores[0]}' : 'Best: --',
      anchor: Anchor.topRight,
      position: Vector2(size.x - 10, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.yellowAccent,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 3, offset: Offset(2, 2)),
          ],
        ),
      ),
    );

    menuText = TextComponent(
      text: 'Tap to Start',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
    );

    gameOverText = TextComponent(
      text: 'Game Over\nTap to Restart',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2 - 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
    );

    add(background);
    add(bird);
    add(menuText);
    add(scoreText); // Add score last so it renders on top
    add(highScoreText); // Add high score on top
  }

  @override
  void onRemove() {
    _audioManager.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (gameState) {
      case GameState.playing:
        pipeSpawnTimer += dt;
        if (pipeSpawnTimer > pipeSpawnInterval) {
          spawnPipes();
          pipeSpawnTimer = 0;
        }
        checkCollisions();
        break;
      case GameState.menu:
      case GameState.gameOver:
        break;
    }
  }

  @override
  bool onTapDown(TapDownInfo info) {
    switch (gameState) {
      case GameState.menu:
        startGame();
        break;
      case GameState.playing:
        bird.jump();
        break;
      case GameState.gameOver:
        resetGame();
        break;
    }
    return true;
  }

  void startGame() {
    gameState = GameState.playing;

    // Play game music (this will be the first audio interaction)
    _audioManager.playGameMusic();

    // Safely remove menu text
    if (menuText.isMounted) {
      menuText.removeFromParent();
    }

    bird.reset();
  }

  void gameOver() {
    gameState = GameState.gameOver;

    // Stop background music immediately and play death sound
    _audioManager.stopBackgroundMusic();
    _audioManager.playDeathSound();

    // Check if current score qualifies for top 3 and update if needed
    int ranking = 0;
    if (score > 0) {
      ranking = checkAndUpdateTopScores(score);
    }

    String finalScoreText;

    if (ranking > 0) {
      // Player achieved a top 3 score
      String rankingText = '';
      if (ranking == 1)
        rankingText = '🥇 NEW #1 HIGH SCORE! 🥇';
      else if (ranking == 2)
        rankingText = '🥈 NEW #2 SCORE! 🥈';
      else if (ranking == 3)
        rankingText = '🥉 NEW #3 SCORE! 🥉';

      finalScoreText =
          'Game Over\n\n$rankingText\nYour Score: $score\n\n${_getLeaderboardText()}\n\nTap to Restart';
    } else {
      // Regular game over
      finalScoreText =
          'Game Over\n\nYour Score: $score\n\n${_getLeaderboardText()}\n\nTap to Restart';
    }

    gameOverText.text = finalScoreText;

    // Only add game over text if not already present
    if (!gameOverText.isMounted) {
      add(gameOverText);
    }
  }

  String _getLeaderboardText() {
    String leaderboard = 'Leaderboard:';

    // Only show scores that are greater than 0 (actually achieved)
    if (topScores[0] > 0) {
      leaderboard += '\n1st: ${topScores[0]}';

      if (topScores[1] > 0) {
        leaderboard += '\n2nd: ${topScores[1]}';

        if (topScores[2] > 0) {
          leaderboard += '\n3rd: ${topScores[2]}';
        }
      }
    } else {
      leaderboard += '\nNo scores yet!';
    }

    return leaderboard;
  }

  void resetGame() {
    gameState = GameState.menu;
    score = 0;
    scoreText.text = 'Score: 0';

    // Play menu music when returning to menu
    _audioManager.playMenuMusic();

    // Safely remove game over text
    try {
      if (gameOverText.isMounted) {
        gameOverText.removeFromParent();
      }
    } catch (e) {
      // Text might already be removed, continue
    }

    // Add menu text if not already present
    if (!menuText.isMounted) {
      add(menuText);
    }

    // Remove all pipes
    for (final pipe in pipes.toList()) {
      if (pipe.isMounted) {
        pipe.removeFromParent();
      }
    }
    pipes.clear();

    bird.reset();
    pipeSpawnTimer = 0;
  }

  void incrementScore() {
    score++;
    scoreText.text = 'Score: $score';

    // Update best score display in real-time if current score beats it
    if (score > topScores[0]) {
      highScoreText.text = 'Best: $score';
    }
  }

  int checkAndUpdateTopScores(int newScore) {
    // Check if score qualifies for top 3
    bool qualifies =
        newScore > topScores[2] ||
        (topScores[2] == 0) ||
        (newScore > topScores[1] && topScores[1] == 0) ||
        (newScore > topScores[0] && topScores[0] == 0);

    if (!qualifies) return 0;

    int ranking = 0;

    // Create a list of current non-zero scores plus the new score
    List<int> allScores = [];
    for (int score in topScores) {
      if (score > 0) allScores.add(score);
    }
    allScores.add(newScore);

    // Sort in descending order and take top 3
    allScores.sort((a, b) => b.compareTo(a));

    // Find ranking of new score
    for (int i = 0; i < allScores.length && i < 3; i++) {
      if (allScores[i] == newScore) {
        ranking = i + 1;
        break;
      }
    }

    // Update topScores array
    for (int i = 0; i < 3; i++) {
      if (i < allScores.length) {
        topScores[i] = allScores[i];
      } else {
        topScores[i] = 0;
      }
    }

    // Save the updated scores
    saveTopScores();

    // Update display
    highScoreText.text = topScores[0] > 0
        ? 'Best: ${topScores[0]}'
        : 'Best: --';

    return ranking;
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    final scores1 = prefs.getInt('top_score_1') ?? 0;
    final scores2 = prefs.getInt('top_score_2') ?? 0;
    final scores3 = prefs.getInt('top_score_3') ?? 0;
    topScores = [scores1, scores2, scores3];
  }

  Future<void> saveTopScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('top_score_1', topScores[0]);
    await prefs.setInt('top_score_2', topScores[1]);
    await prefs.setInt('top_score_3', topScores[2]);
  }

  void spawnPipes() {
    final random = Random();
    final gapY = random.nextDouble() * (size.y - pipeGap - 200) + 100;

    final topPipe = Pipe(isTop: true, gapY: gapY);
    final bottomPipe = Pipe(isTop: false, gapY: gapY);

    // Add pipes before other UI elements so they render behind score
    add(topPipe);
    add(bottomPipe);
    pipes.add(topPipe);
    pipes.add(bottomPipe);

    // Ensure score and high score are always on top
    if (scoreText.isMounted) {
      scoreText.removeFromParent();
      add(scoreText);
    }
    if (highScoreText.isMounted) {
      highScoreText.removeFromParent();
      add(highScoreText);
    }
  }

  void checkCollisions() {
    // Check bird collision with pipes using smaller hitbox for better gameplay
    final birdLeft = bird.position.x - bird.size.x / 2 + 4; // Smaller hitbox
    final birdRight = bird.position.x + bird.size.x / 2 - 4;
    final birdTop = bird.position.y - bird.size.y / 2 + 4;
    final birdBottom = bird.position.y + bird.size.y / 2 - 4;

    for (final pipe in pipes) {
      final pipeLeft = pipe.position.x;
      final pipeRight = pipe.position.x + pipe.size.x;
      final pipeTop = pipe.position.y;
      final pipeBottom = pipe.position.y + pipe.size.y;

      // Check if bird overlaps with pipe
      if (birdRight > pipeLeft &&
          birdLeft < pipeRight &&
          birdBottom > pipeTop &&
          birdTop < pipeBottom) {
        if (!bird.hasCollided) {
          bird.hasCollided = true;
          gameOver();
        }
      }
    }
  }
}

class Bird extends SpriteComponent {
  double velocity = 0;
  bool hasCollided = false;
  late ui.Image birdSprite;

  @override
  Future<void> onLoad() async {
    // Create a simple bird sprite programmatically
    birdSprite = await _createBirdSprite();
    sprite = Sprite(birdSprite);

    size = Vector2(32, 32);
    position = Vector2(80, (parent as FlappyBirdGame).size.y / 2);
    anchor = Anchor.center;
  }

  Future<ui.Image> _createBirdSprite() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw bird body (yellow oval)
    final bodyPaint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawOval(const Rect.fromLTWH(4, 8, 24, 16), bodyPaint);

    // Draw wing (orange)
    final wingPaint = Paint()..color = const Color(0xFFFF8C00);
    canvas.drawOval(const Rect.fromLTWH(8, 12, 16, 8), wingPaint);

    // Draw eye (black dot)
    final eyePaint = Paint()..color = Colors.black;
    canvas.drawCircle(const Offset(20, 14), 2, eyePaint);

    // Draw eye highlight (white)
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(21, 13), 1, highlightPaint);

    // Draw beak (orange triangle)
    final beakPaint = Paint()..color = const Color(0xFFFF6600);
    final beakPath = Path()
      ..moveTo(28, 16)
      ..lineTo(32, 16)
      ..lineTo(28, 18)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    final picture = recorder.endRecording();
    return await picture.toImage(32, 32);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final game = parent as FlappyBirdGame;
    if (game.gameState == GameState.playing) {
      velocity += FlappyBirdGame.gravity * dt;
      position.y += velocity * dt;

      // Add slight rotation based on velocity
      angle = (velocity / 300).clamp(-0.5, 0.5);

      // Check ground collision
      if (position.y > game.size.y - size.y / 2) {
        position.y = game.size.y - size.y / 2;
        if (!hasCollided) {
          hasCollided = true;
          game.gameOver();
        }
      }

      // Check ceiling collision
      if (position.y < size.y / 2) {
        position.y = size.y / 2;
        velocity = 0;
      }
    }
  }

  void jump() {
    velocity = -FlappyBirdGame.jumpSpeed;
  }

  void reset() {
    position = Vector2(80, (parent as FlappyBirdGame).size.y / 2);
    velocity = 0;
    hasCollided = false;
    angle = 0;
  }
}

class Pipe extends RectangleComponent {
  final bool isTop;
  final double gapY;
  bool scoreGiven = false;
  late ui.Image pipeSprite;

  Pipe({required this.isTop, required this.gapY});

  @override
  Future<void> onLoad() async {
    final gameSize = (parent as FlappyBirdGame).size;

    if (isTop) {
      // Top pipe extends from top of screen to gap
      size = Vector2(
        FlappyBirdGame.pipeWidth,
        gapY - FlappyBirdGame.pipeGap / 2,
      );
      position = Vector2(gameSize.x, 0);
    } else {
      // Bottom pipe extends from gap to bottom of screen
      final topOfBottomPipe = gapY + FlappyBirdGame.pipeGap / 2;
      size = Vector2(FlappyBirdGame.pipeWidth, gameSize.y - topOfBottomPipe);
      position = Vector2(gameSize.x, topOfBottomPipe);
    }

    // Create pipe sprite programmatically
    pipeSprite = await _createPipeSprite();
    add(SpriteComponent(sprite: Sprite(pipeSprite), size: size));
  }

  Future<ui.Image> _createPipeSprite() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Main pipe body (green)
    final pipePaint = Paint()..color = const Color(0xFF00AA00);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), pipePaint);

    // Pipe highlight (lighter green)
    final highlightPaint = Paint()..color = const Color(0xFF44CC44);
    canvas.drawRect(Rect.fromLTWH(2, 0, size.x - 20, size.y), highlightPaint);

    // Pipe shadow (darker green)
    final shadowPaint = Paint()..color = const Color(0xFF006600);
    canvas.drawRect(Rect.fromLTWH(size.x - 8, 0, 8, size.y), shadowPaint);

    // Pipe cap (if it's a top pipe, add cap at bottom, if bottom pipe, add cap at top)
    final capPaint = Paint()..color = const Color(0xFF008800);
    if (isTop) {
      canvas.drawRect(Rect.fromLTWH(-4, size.y - 20, size.x + 8, 20), capPaint);
    } else {
      canvas.drawRect(Rect.fromLTWH(-4, 0, size.x + 8, 20), capPaint);
    }

    final picture = recorder.endRecording();
    return await picture.toImage(size.x.toInt(), size.y.toInt());
  }

  @override
  void update(double dt) {
    super.update(dt);

    final game = parent as FlappyBirdGame;
    if (game.gameState == GameState.playing) {
      position.x -= 100 * dt; // Pipe speed

      // Give score when bird passes pipe
      if (!scoreGiven && !isTop && position.x + size.x < 80) {
        scoreGiven = true;
        game.incrementScore();
      }

      // Remove pipe when off screen
      if (position.x + size.x < 0) {
        removeFromParent();
        game.pipes.remove(this);
      }
    }
  }
}

class Background extends Component {
  late SpriteComponent sky1;
  late SpriteComponent sky2;
  late SpriteComponent ground1;
  late SpriteComponent ground2;

  @override
  Future<void> onLoad() async {
    final gameSize = (parent as FlappyBirdGame).size;

    // Create sky sprites for parallax - make them wider to prevent gaps
    final skySprite = await _createSkySprite(gameSize);
    sky1 = SpriteComponent(
      sprite: Sprite(skySprite),
      size: Vector2(gameSize.x + 100, gameSize.y),
      position: Vector2.zero(),
    );
    sky2 = SpriteComponent(
      sprite: Sprite(skySprite),
      size: Vector2(gameSize.x + 100, gameSize.y),
      position: Vector2(gameSize.x, 0),
    );

    // Create ground sprites for parallax - make them wider to prevent gaps
    final groundSprite = await _createGroundSprite(gameSize);
    ground1 = SpriteComponent(
      sprite: Sprite(groundSprite),
      size: Vector2(gameSize.x + 100, 50),
      position: Vector2(0, gameSize.y - 50),
    );
    ground2 = SpriteComponent(
      sprite: Sprite(groundSprite),
      size: Vector2(gameSize.x + 100, 50),
      position: Vector2(gameSize.x, gameSize.y - 50),
    );

    add(sky1);
    add(sky2);
    add(ground1);
    add(ground2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final game = parent as FlappyBirdGame;
    if (game.gameState == GameState.playing) {
      final gameSize = game.size;

      // Move sky slowly for parallax effect
      sky1.position.x -= 20 * dt;
      sky2.position.x -= 20 * dt;

      // Move ground faster
      ground1.position.x -= 80 * dt;
      ground2.position.x -= 80 * dt;

      // Reset sky positions when they move off screen
      if (sky1.position.x <= -gameSize.x - 50) {
        sky1.position.x = sky2.position.x + gameSize.x;
      }
      if (sky2.position.x <= -gameSize.x - 50) {
        sky2.position.x = sky1.position.x + gameSize.x;
      }

      // Reset ground positions when they move off screen
      if (ground1.position.x <= -gameSize.x - 50) {
        ground1.position.x = ground2.position.x + gameSize.x;
      }
      if (ground2.position.x <= -gameSize.x - 50) {
        ground2.position.x = ground1.position.x + gameSize.x;
      }
    }
  }

  Future<ui.Image> _createSkySprite(Vector2 gameSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Use actual game size + extra width for seamless scrolling
    final width = gameSize.x + 100;
    final height = gameSize.y;

    // Sky gradient
    final rect = Rect.fromLTWH(0, 0, width, height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF87CEEB), // Sky blue
        const Color(0xFF4682B4), // Steel blue
        const Color(0xFF6495ED), // Cornflower blue
      ],
    );

    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Add clouds distributed across the width
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.7);
    canvas.drawOval(
      Rect.fromLTWH(width * 0.1, height * 0.15, 60, 25),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(width * 0.4, height * 0.2, 80, 30),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(width * 0.7, height * 0.3, 70, 28),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(width * 0.2, height * 0.5, 90, 35),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(width * 0.6, height * 0.65, 75, 30),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(width * 0.85, height * 0.4, 65, 28),
      cloudPaint,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(width.toInt(), height.toInt());
  }

  Future<ui.Image> _createGroundSprite(Vector2 gameSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Use actual game size + extra width for seamless scrolling
    final width = gameSize.x + 100;
    const height = 50.0;

    // Ground with texture
    final groundPaint = Paint()..color = const Color(0xFF228B22);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), groundPaint);

    // Add some grass texture
    final grassPaint = Paint()..color = const Color(0xFF32CD32);
    for (double i = 0; i < width; i += 20) {
      canvas.drawRect(Rect.fromLTWH(i, 0, 10, height * 0.3), grassPaint);
    }

    final picture = recorder.endRecording();
    return await picture.toImage(width.toInt(), height.toInt());
  }
}
