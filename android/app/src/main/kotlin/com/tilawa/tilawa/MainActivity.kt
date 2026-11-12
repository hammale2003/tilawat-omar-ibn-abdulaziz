package com.tilawa.tilawa

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity, not FlutterActivity: required so the audio service can
// bind to this activity and keep playing when the app is backgrounded.
class MainActivity : AudioServiceActivity()
