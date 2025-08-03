import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  late AudioPlayer _backgroundPlayer;
  late AudioPlayer _deathPlayer;
  bool _isInitialized = false;
  bool _deathSoundPlayed = false;

    Future<void> initialize() async {
    if (_isInitialized) return;
    
    _backgroundPlayer = AudioPlayer();
    _deathPlayer = AudioPlayer();
    
    // Set up background player for looping
    await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
    
    _isInitialized = true;
  }

  Future<void> playMenuMusic() async {
    if (!_isInitialized) await initialize();
    
    try {
      // Stop any current background music
      await _backgroundPlayer.stop();
      
      // Play super-mario-2.mp3 for menu state
      await _backgroundPlayer.play(AssetSource('music/super-mario-2.mp3'));
      _deathSoundPlayed = false; // Reset death sound flag
    } catch (e) {
      // Ignore audio errors - they might occur due to browser restrictions
      print('Audio error: $e');
    }
  }

    Future<void> playGameMusic() async {
    if (!_isInitialized) await initialize();
    
    try {
      // Stop any current background music
      await _backgroundPlayer.stop();
      
      // Play super-mario-1.mp3 for playing state
      await _backgroundPlayer.play(AssetSource('music/super-mario-1.mp3'));
    } catch (e) {
      // Ignore audio errors - they might occur due to browser restrictions
      print('Audio error: $e');
    }
  }

    Future<void> playDeathSound() async {
    if (!_isInitialized) await initialize();
    
    // Only play death sound once per game over
    if (!_deathSoundPlayed) {
      _deathSoundPlayed = true;
      
      try {
        // Stop background music immediately
        await _backgroundPlayer.stop();
        
        // Small delay to ensure background music stops completely
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Play super-mario-death.mp3 once
        await _deathPlayer.play(AssetSource('music/super-mario-death.mp3'));
        
        // Wait for death sound to finish, then resume menu music
        _deathPlayer.onPlayerComplete.listen((_) async {
          await playMenuMusic();
        });
      } catch (e) {
        // Ignore audio errors - they might occur due to browser restrictions
        print('Audio error: $e');
        // If death sound fails, still try to play menu music
        await playMenuMusic();
      }
    }
  }

  Future<void> stopAll() async {
    if (!_isInitialized) return;

    try {
      await _backgroundPlayer.stop();
      await _deathPlayer.stop();
    } catch (e) {
      print('Audio stop error: $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    if (!_isInitialized) return;
    
    try {
      await _backgroundPlayer.stop();
    } catch (e) {
      print('Background music stop error: $e');
    }
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;

    await _backgroundPlayer.dispose();
    await _deathPlayer.dispose();
    _isInitialized = false;
  }
}
