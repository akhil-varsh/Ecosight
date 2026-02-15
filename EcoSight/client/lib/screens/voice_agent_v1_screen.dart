library;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/tts_manager.dart';
import '../services/voice_agent_orchestrator_v1.dart';

class VoiceAgentV1Screen extends StatefulWidget {
  const VoiceAgentV1Screen({super.key});

  @override
  State<VoiceAgentV1Screen> createState() => _VoiceAgentV1ScreenState();
}

class _VoiceAgentV1ScreenState extends State<VoiceAgentV1Screen> {
  final SpeechToText _speech = SpeechToText();
  final TTSManager _tts = TTSManager();
  final VoiceAgentOrchestratorV1 _orchestrator = VoiceAgentOrchestratorV1();

  bool _speechReady = false;
  bool _isListening = false;
  bool _isRunning = false;
  String _heardText = '';
  String _resultText = 'Say a command like: current location, weather, or call mom.';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _tts.init();
    final ready = await _speech.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _speechReady = ready;
      _resultText = ready
          ? 'Voice agent ready.'
          : 'Speech recognition unavailable on this device.';
    });
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
      });
      return;
    }

    await _speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _heardText = result.recognizedWords;
        });
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
      ),
      pauseFor: const Duration(seconds: 3),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = true;
    });
  }

  Future<void> _runAgent() async {
    if (_isRunning) {
      return;
    }

    final text = _heardText.trim();
    if (text.isEmpty) {
      setState(() {
        _resultText = 'Please speak a command first.';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _resultText = 'Thinking and executing...';
    });

    final outcome = await _orchestrator.execute(text);

    if (!mounted) {
      return;
    }

    setState(() {
      _isRunning = false;
      _resultText = outcome.response;
    });

    await _tts.speakStatus(outcome.response);
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Agent v1')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Heard Command',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(_heardText.isEmpty ? '-' : _heardText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agent Response',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(_resultText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _speechReady ? _toggleListening : null,
                      icon: Icon(
                        _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                      ),
                      label: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRunning ? null : _runAgent,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Run Agent'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Try commands: "current location", "weather", "call mom"',
                style: TextStyle(color: Color(0xFF8E95A9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
