import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Styles.js" as Styles

Panel {
  id: root
  moduleName: "io.github.stoogs.chordpumper-promarchy"
  ipcTarget: "io.github.stoogs.chordpumper-promarchy"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color pianoSurface: Color.popups.background
  readonly property color pianoWhite: Color.foreground
  readonly property color pianoBlack: Color.background
  readonly property color pianoMuted: Color.muted
  readonly property color pianoPressed: Color.accent
  readonly property color pianoAdjusted: Color.urgent
  readonly property color pianoGold: "#d6aa5c"
  readonly property int synthPanelBudget: 760
  readonly property int synthMainLabelWidth: 40
  readonly property int synthVoiceDropdownWidth: 145
  readonly property int synthSpaceShortcutWidth: 55
  readonly property int synthParameterLabelWidth: 57
  readonly property int synthParameterSliderWidth: 135
  readonly property int synthCutoffShortcutWidth: 48
  readonly property int synthCutoffLabelWidth: 65
  readonly property int synthCutoffSliderWidth: 150
  readonly property int synthControlGap: 7
  readonly property int synthInnerGap: 4
  readonly property int synthOuterGap: 8

  property int keyRoot: 0
  property string scaleType: "major"
  property string scaleLockMode: "off"
  property bool keyPickerOpen: false
  property bool scalePickerOpen: false
  property int lastScaleShift: 0
  property int octave: 3
  property string modifier: ""
  property string lockedModifier: ""
  property int temporaryModifierIndex: -1
  property int activeMidi: -1
  property int activeDegreeIndex: -1
  property var activeChordNotes: []
  property var manualHeldNotes: []
  property var adjustedMidiNotes: []
  property var noteHistory: []
  property var playedEvents: []
  readonly property int maxPlayedEvents: 4096
  property bool clearHistoryArmed: false
  property bool audioReady: false
  property string audioBackendPreference: "auto"
  property string activeAudioBackend: ""
  property bool proAudioAvailable: false
  property bool audioRestarting: false
  property int basicCharacter: 50
  property int keyboardTone: 60
  property int cinematicFactor: 0
  property int synthVoiceIndex: 0
  property int synthCutoff: 58
  property int synthShape: 32
  property int synthSpace: 62
  property int synthRelease: 68
  property string synthBank: "basic"
  property int proSynthVoiceIndex: 0
  property int proSynthCutoff: 60
  property int proSynthShape: 38
  property int proSynthSpace: 24
  property int proSynthRelease: 68
  readonly property var synthVoices: [
    { name: "Analogue Silk", cutoff: 60, shape: 38, space: 52, release: 68 },
    { name: "Velvet Choir", cutoff: 58, shape: 24, space: 84, release: 76 },
    { name: "Moon Harp", cutoff: 70, shape: 18, space: 82, release: 60 },
    { name: "Glass Lead", cutoff: 78, shape: 24, space: 52, release: 40 },
    { name: "Aurora Flute", cutoff: 66, shape: 20, space: 78, release: 68 },
    { name: "Shadow Cello", cutoff: 48, shape: 20, space: 72, release: 65 }
  ]
  readonly property var synthVoiceOptions: [
    { value: "0", label: "Analogue Silk" }, { value: "1", label: "Velvet Choir" },
    { value: "2", label: "Moon Harp" }, { value: "3", label: "Glass Lead" },
    { value: "4", label: "Aurora Flute" }, { value: "5", label: "Shadow Cello" }
  ]
  readonly property var proSynthVoices: [
    { name: "Analogue Silk", cutoff: 60, shape: 38, space: 24, release: 68 },
    { name: "Moon Harp", cutoff: 70, shape: 18, space: 28, release: 60 },
    { name: "Iron Cathedral", cutoff: 50, shape: 52, space: 24, release: 60 },
    { name: "Aurora Flute", cutoff: 66, shape: 20, space: 28, release: 68 },
    { name: "Dirty Trumpet", cutoff: 68, shape: 62, space: 18, release: 42 },
    { name: "Velvet Choir", cutoff: 58, shape: 24, space: 30, release: 76 },
    { name: "Glass Lead", cutoff: 82, shape: 44, space: 22, release: 42 },
    { name: "Shadow Cello", cutoff: 48, shape: 20, space: 26, release: 65 }
  ]
  readonly property var proSynthVoiceOptions: [
    { value: "0", label: "Analogue Silk" }, { value: "1", label: "Moon Harp" },
    { value: "2", label: "Iron Cathedral" }, { value: "3", label: "Aurora Flute" },
    { value: "4", label: "Dirty Trumpet" }, { value: "5", label: "Velvet Choir" },
    { value: "6", label: "Glass Lead" }, { value: "7", label: "Shadow Cello" }
  ]
  readonly property bool synthSelected: activeAudioBackend === "synth" || activeAudioBackend === "synth-fluid"
    || (audioRestarting && (audioBackendPreference === "synth" || audioBackendPreference === "synth-fluid"))
  property int cinematicCueIndex: 0
  property var cinematicCueNotes: []
  property int cueAccentIndex: 0
  property int cueAccentNote: -1
  property bool cueUsesBasic: false
  property bool cueSoundActive: false
  property int cueSavedSoundFactor: 0
  readonly property string proHelpText: "Want Electric Keyboard, Piano, and Pro Synth sounds? Follow the GitHub instructions to install Omarchy's optional FluidSynth packages."
  readonly property string proHelpUrl: "https://github.com/stoogs/ChordPumper-Promarchy#optional-pro-piano"
  property int styleIndex: 0
  property string chordPaletteMode: "core"
  property int chordPaletteSeed: 1
  readonly property var styles: Styles.all()
  readonly property var styleOptions: {
    var options = []
    for (var index = 0; index < styles.length; index++)
      options.push({ value: String(index), label: styles[index].name })
    return options
  }
  readonly property var currentStyle: Styles.at(styleIndex)
  readonly property var chords: Styles.chordsFor(styleIndex, keyRoot, chordPaletteMode, chordPaletteSeed)
  property string statusText: "Keyboard ready · audio engine is the next milestone"
  readonly property var modifiers: currentStyle.shapes
  readonly property var modifierKeys: ["C", "V", "B", "N", "M", ",", ".", "/"]
  readonly property var scaleRoots: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  readonly property var scaleTypes: [
    { id: "major", name: "Major" },
    { id: "minor", name: "Natural Minor" },
    { id: "harmonicMinor", name: "Harmonic Minor" },
    { id: "melodicMinor", name: "Melodic Minor" },
    { id: "majorPentatonic", name: "Major Pentatonic" },
    { id: "minorPentatonic", name: "Minor Pentatonic" },
    { id: "blues", name: "Blues" },
    { id: "dorian", name: "Dorian" },
    { id: "phrygian", name: "Phrygian" },
    { id: "lydian", name: "Lydian" },
    { id: "mixolydian", name: "Mixolydian" },
    { id: "locrian", name: "Locrian" }
  ]
  readonly property var scaleLockModes: [
    { id: "off", name: "Off" },
    { id: "nearest", name: "Note Snap" },
    { id: "fit", name: "Chord Snap" },
    { id: "strict", name: "Strict" }
  ]
  readonly property var whiteKeys: [
    { letter: "A", offset: 0 }, { letter: "S", offset: 2 },
    { letter: "D", offset: 4 }, { letter: "F", offset: 5 },
    { letter: "G", offset: 7 }, { letter: "H", offset: 9 },
    { letter: "J", offset: 11 }
  ]
  readonly property var blackKeys: [
    { letter: "W", offset: 1, after: 1 }, { letter: "E", offset: 3, after: 2 },
    { letter: "T", offset: 6, after: 4 }, { letter: "Y", offset: 8, after: 5 },
    { letter: "U", offset: 10, after: 6 }
  ]
  readonly property string enginePath: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.stoogs.chordpumper-promarchy/engine/chordpumper_engine.py"
  readonly property string outputDir: Quickshell.env("HOME") + "/Music/ChordPumper Promarchy"

  function open() {
    root.controller.show()
    Qt.callLater(function() { keyArea.forceActiveFocus() })
  }
  function close() {
    stopCinematicCue()
    stopActiveNotes()
    manualHeldNotes = []
    activeMidi = -1
    if (audioProcess.running) audioProcess.write(JSON.stringify({ type: "all_off" }) + "\n")
    root.controller.hide()
  }
  function toggle() { if (root.opened) close(); else open() }
  function selectAudioBackend(backend) {
    if (backend === activeAudioBackend && audioReady) {
      statusText = backend === "fluid" ? "Piano is active"
        : backend === "keyboard-fluid" ? "Electric Keyboard is active"
        : backend === "synth" || backend === "synth-fluid" ? (synthBank === "pro" ? "Pro Synth is active" : "Basic Synth is active")
        : "Organ is active"
      keyArea.forceActiveFocus()
      return
    }
    if ((backend === "fluid" || backend === "keyboard-fluid" || backend === "synth-fluid") && !proAudioAvailable) {
      statusText = proHelpText
      keyArea.forceActiveFocus()
      return
    }
    stopActiveNotes()
    audioReady = false
    audioBackendPreference = backend
    audioRestarting = true
    statusText = backend === "fluid" ? "Starting Piano…"
      : backend === "keyboard-fluid" ? "Starting Electric Keyboard…"
      : backend === "synth-fluid" ? "Starting Pro Synth…"
      : backend === "synth" ? "Starting Basic Synth…" : "Starting Organ…"
    if (audioProcess.running) audioProcess.running = false
    else {
      audioRestarting = false
      audioProcess.running = true
    }
    keyArea.forceActiveFocus()
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }
  function setBasicCharacter(value) {
    basicCharacter = Math.max(0, Math.min(100, Math.round(value)))
    if (audioProcess.running && audioReady && activeAudioBackend === "basic")
      audioProcess.write(JSON.stringify({ type: "character", value: basicCharacter }) + "\n")
    statusText = "Basic character " + basicCharacter + " · "
      + (basicCharacter < 34 ? "clean" : basicCharacter > 66 ? "driven" : "balanced")
  }
  function setCinematic(value) {
    cinematicFactor = Math.max(0, Math.min(100, Math.round(value)))
    if (audioProcess.running && audioReady && activeAudioBackend === "fluid")
      audioProcess.write(JSON.stringify({ type: "cinematic", value: cinematicFactor }) + "\n")
    statusText = "Cinematic " + cinematicFactor + " · "
      + (cinematicFactor < 34 ? "natural piano" : cinematicFactor > 66 ? "wide and atmospheric" : "spacious piano")
  }
  function setKeyboardTone(value) {
    keyboardTone = Math.max(0, Math.min(100, Math.round(value)))
    if (audioProcess.running && audioReady && activeAudioBackend === "keyboard-fluid")
      audioProcess.write(JSON.stringify({ type: "keyboard_tone", value: keyboardTone }) + "\n")
    statusText = "Electric Keyboard tone " + keyboardTone + " · "
      + (keyboardTone < 34 ? "warm" : keyboardTone > 66 ? "bell and bite" : "full-bodied")
  }
  function adjustSoundFactor(delta) {
    if (activeAudioBackend === "fluid") setCinematic(cinematicFactor + delta)
    else if (activeAudioBackend === "keyboard-fluid") setKeyboardTone(keyboardTone + delta)
    else if (synthSelected) setSynthCutoff(currentSynthCutoff() + delta)
    else if (activeAudioBackend === "basic") setBasicCharacter(basicCharacter + delta)
    keyArea.forceActiveFocus()
  }
  function currentSynthVoices() { return synthBank === "pro" ? proSynthVoices : synthVoices }
  function currentSynthVoiceOptions() { return synthBank === "pro" ? proSynthVoiceOptions : synthVoiceOptions }
  function currentSynthVoiceIndex() { return synthBank === "pro" ? proSynthVoiceIndex : synthVoiceIndex }
  function currentSynthCutoff() { return synthBank === "pro" ? proSynthCutoff : synthCutoff }
  function currentSynthShape() { return synthBank === "pro" ? proSynthShape : synthShape }
  function currentSynthSpace() { return synthBank === "pro" ? proSynthSpace : synthSpace }
  function currentSynthRelease() { return synthBank === "pro" ? proSynthRelease : synthRelease }
  function activateKeyboard() { selectAudioBackend("keyboard-fluid") }
  function activateProSynth() { synthBank = "pro"; selectAudioBackend("synth-fluid") }
  function sendSynthSettings() {
    if (audioProcess.running && audioReady && (activeAudioBackend === "synth" || activeAudioBackend === "synth-fluid"))
      audioProcess.write(JSON.stringify({ type: "synth_settings", voice: currentSynthVoiceIndex(),
        cutoff: currentSynthCutoff(), shape: currentSynthShape(), space: currentSynthSpace(),
        release: currentSynthRelease() }) + "\n")
  }
  function setSynthCutoff(value) {
    var next = Math.max(0, Math.min(100, Math.round(value)))
    if (synthBank === "pro") proSynthCutoff = next
    else synthCutoff = next
    sendSynthSettings()
    statusText = currentSynthVoices()[currentSynthVoiceIndex()].name + " · filter " + next
  }
  function setSynthShape(value) {
    var next = Math.max(0, Math.min(100, Math.round(value)))
    if (synthBank === "pro") proSynthShape = next
    else synthShape = next
    sendSynthSettings()
    statusText = currentSynthVoices()[currentSynthVoiceIndex()].name + " · resonance " + next
  }
  function setSynthSpace(value) {
    var next = Math.max(0, Math.min(100, Math.round(value)))
    if (synthBank === "pro") proSynthSpace = next
    else synthSpace = next
    sendSynthSettings()
    statusText = currentSynthVoices()[currentSynthVoiceIndex()].name + " · space " + next
  }
  function setSynthRelease(value) {
    var next = Math.max(0, Math.min(100, Math.round(value)))
    if (synthBank === "pro") proSynthRelease = next
    else synthRelease = next
    sendSynthSettings()
    statusText = currentSynthVoices()[currentSynthVoiceIndex()].name + " · release " + next
  }
  function resetSound() {
    if (synthSelected) {
      var preset = currentSynthVoices()[currentSynthVoiceIndex()]
      if (synthBank === "pro") {
        proSynthCutoff = preset.cutoff
        proSynthShape = preset.shape
        proSynthSpace = preset.space
        proSynthRelease = preset.release
      } else {
        synthCutoff = preset.cutoff
        synthShape = preset.shape
        synthSpace = preset.space
        synthRelease = preset.release
      }
      sendSynthSettings()
      statusText = preset.name + " · original sound restored"
    } else if (activeAudioBackend === "keyboard-fluid") {
      setKeyboardTone(60)
      statusText = "Electric Keyboard · original sound restored"
    } else if (activeAudioBackend === "fluid") {
      setCinematic(0)
      statusText = "Piano · original sound restored"
    } else {
      setBasicCharacter(50)
      statusText = "Organ · original sound restored"
    }
    keyArea.forceActiveFocus()
  }
  function selectSynthVoice(index) {
    var preset = currentSynthVoices()[index]
    if (synthBank === "pro") {
      proSynthVoiceIndex = index
      proSynthCutoff = preset.cutoff
      proSynthShape = preset.shape
      proSynthSpace = preset.space
      proSynthRelease = preset.release
    } else {
      synthVoiceIndex = index
      synthCutoff = preset.cutoff
      synthShape = preset.shape
      synthSpace = preset.space
      synthRelease = preset.release
    }
    sendSynthSettings()
    statusText = (synthBank === "pro" ? "Pro Synth · " : "Basic Synth · ") + preset.name
    keyArea.forceActiveFocus()
  }
  function stopCinematicCue() {
    if (audioProcess.running)
      for (var index = 0; index < cinematicCueNotes.length; index++)
        audioProcess.write(JSON.stringify({ type: "note_off", note: cinematicCueNotes[index] }) + "\n")
    cinematicCueNotes = []
    cinematicCueTimer.stop()
    if (cueAccentNote >= 0 && audioProcess.running)
      audioProcess.write(JSON.stringify({ type: "note_off", note: cueAccentNote }) + "\n")
    cueAccentNote = -1
    cueAccentTimer.stop()
    if (cueSoundActive) {
      if (cueUsesBasic) setBasicCharacter(cueSavedSoundFactor)
      else setCinematic(cueSavedSoundFactor)
      cueSoundActive = false
    }
  }
  function playCinematicCue() {
    if (!audioProcess.running || !audioReady) return
    if (synthSelected) {
      statusText = "Synth ready · play the 1–0 chord palette"
      return
    }
    stopCinematicCue()
    cueUsesBasic = activeAudioBackend === "basic"
    cueSavedSoundFactor = cueUsesBasic ? basicCharacter : cinematicFactor
    cueSoundActive = true
    if (cueUsesBasic) setBasicCharacter(0)
    else setCinematic(0)
    cinematicCueIndex = 0
    cueAccentIndex = 0
    statusText = "Chord cue · original 1–0 progression"
    cinematicCueTimer.interval = 1
    cinematicCueTimer.start()
    cueAccentTimer.start()
  }
  function modifierIndexForText(text) {
    return "cvbnm,./".indexOf(String(text).toLowerCase())
  }
  function beginTemporaryModifier(index) {
    temporaryModifierIndex = index
    modifier = modifiers[index]
    statusText = "Hold " + modifierKeys[index] + " · " + Model.qualityDisplayName(modifier) + " shape armed"
  }
  function endTemporaryModifier(index) {
    if (temporaryModifierIndex !== index) return
    temporaryModifierIndex = -1
    modifier = lockedModifier
    statusText = lockedModifier !== ""
      ? "Returned to locked " + Model.qualityDisplayName(lockedModifier) + " shape"
      : "Returned to single-note mode"
  }
  function toggleModifierLock(value) {
    lockedModifier = lockedModifier === value ? "" : value
    if (temporaryModifierIndex < 0) modifier = lockedModifier
    statusText = lockedModifier !== ""
      ? "Locked " + Model.qualityDisplayName(lockedModifier) + " · every piano key now voices a chord"
      : "Modifier unlocked · piano returned to single notes"
  }
  function applyStyle(index) {
    stopActiveNotes()
    styleIndex = ((index % styles.length) + styles.length) % styles.length
    temporaryModifierIndex = -1
    lockedModifier = ""
    modifier = ""
    chordPaletteMode = "core"
    statusText = currentStyle.name + " style · palette loaded"
  }
  function cycleStyle() { applyStyle(styleIndex + 1) }
  function randomizeAll() {
    var nextStyle = Math.floor(Math.random() * styles.length)
    applyStyle(nextStyle)
    chordPaletteMode = "shuffle"
    chordPaletteSeed = Math.floor(Math.random() * 1000000) + 1
    lockedModifier = modifiers[Math.floor(Math.random() * modifiers.length)]
    modifier = lockedModifier
    statusText = "Random · " + currentStyle.name + " · "
      + chordPaletteName() + " palette · " + Model.qualityDisplayName(lockedModifier) + " locked"
  }
  function setChordPalette(mode) {
    stopActiveNotes()
    chordPaletteMode = mode
    if (mode === "shuffle") chordPaletteSeed = Math.floor(Math.random() * 1000000) + 1
    statusText = currentStyle.name + " · " + chordPaletteName() + " chord palette"
  }
  function chordPaletteName() {
    if (chordPaletteMode === "alt") return "Alternate"
    if (chordPaletteMode === "colour") return "Colour"
    if (chordPaletteMode === "shuffle") return "Shuffle"
    return "Core"
  }
  function setKeyRoot(value) {
    stopActiveNotes()
    keyRoot = value
    keyPickerOpen = false
    scalePickerOpen = false
    if (scaleLockMode === "off") scaleLockMode = "nearest"
    statusText = "Scale locked · " + Model.pitchClassLabel(keyRoot) + " " + scaleTypeName() + " · " + scaleLockModeName()
  }
  function setScaleType(value) {
    stopActiveNotes()
    scaleType = value
    scalePickerOpen = false
    if (scaleLockMode === "off") scaleLockMode = "nearest"
    statusText = "Scale locked · " + Model.pitchClassLabel(keyRoot) + " " + scaleTypeName() + " · " + scaleLockModeName()
  }
  function scaleTypeName() {
    for (var i = 0; i < scaleTypes.length; i++)
      if (scaleTypes[i].id === scaleType) return scaleTypes[i].name
    return scaleType
  }
  function setScaleLockMode(value) {
    stopActiveNotes()
    scaleLockMode = value
    statusText = "Scale lock · " + scaleLockModeName()
  }
  function scaleLockModeName() {
    for (var i = 0; i < scaleLockModes.length; i++)
      if (scaleLockModes[i].id === scaleLockMode) return scaleLockModes[i].name
    return scaleLockMode
  }
  function scaleAllowed(midi) {
    return scaleLockMode === "off" || Model.isInScale(midi, keyRoot, scaleType)
  }
  function resolveScaleNotes(notes) {
    lastScaleShift = 0
    adjustedMidiNotes = []
    if (scaleLockMode === "off") return notes.slice()
    if (scaleLockMode === "strict") {
      for (var i = 0; i < notes.length; i++)
        if (!Model.isInScale(notes[i], keyRoot, scaleType)) return []
      return notes.slice()
    }
    if (scaleLockMode === "nearest") {
      var snapped = []
      for (var j = 0; j < notes.length; j++) {
        var snappedNote = Model.nearestScaleNote(notes[j], keyRoot, scaleType)
        snapped.push(snappedNote)
        if (snappedNote !== notes[j]) adjustedMidiNotes.push(snappedNote)
      }
      return Model.uniqueNotes(snapped)
    }
    if (notes.length === 1) {
      var fittedNote = Model.nearestScaleNote(notes[0], keyRoot, scaleType)
      if (fittedNote !== notes[0]) adjustedMidiNotes = [fittedNote]
      return [fittedNote]
    }
    var fitted = Model.fitChordToScale(notes, keyRoot, scaleType)
    lastScaleShift = fitted.shift
    if (fitted.shift !== 0) adjustedMidiNotes = fitted.notes.slice()
    return fitted.notes
  }
  function midiNotesValid(notes) {
    for (var i = 0; i < notes.length; i++)
      if (!Number.isInteger(notes[i]) || notes[i] < 0 || notes[i] > 127) return false
    return true
  }
  function numberChordIndex(key) {
    if (key >= Qt.Key_1 && key <= Qt.Key_9) return key - Qt.Key_1
    if (key === Qt.Key_0) return 9
    return -1
  }
  function handlePress(event) {
    if (event.isAutoRepeat) { event.accepted = true; return }
    if (event.key === Qt.Key_BracketLeft) { adjustSoundFactor(-10); event.accepted = true; return }
    if (event.key === Qt.Key_BracketRight) { adjustSoundFactor(10); event.accepted = true; return }
    if (root.synthSelected && event.text === "'") { setSynthSpace(currentSynthSpace() - 10); event.accepted = true; return }
    if (root.synthSelected && event.text === "\\") { setSynthSpace(currentSynthSpace() + 10); event.accepted = true; return }
    if (event.key === Qt.Key_Escape) { close(); event.accepted = true; return }
    if (event.key === Qt.Key_Z) { octave = Math.max(2, octave - 1); statusText = octave === 2 ? "Octave 2 · lowest range" : "Octave " + octave; event.accepted = true; return }
    if (event.key === Qt.Key_X) { octave = Math.min(6, octave + 1); statusText = octave === 6 ? "Octave 6 · highest range" : "Octave " + octave; event.accepted = true; return }
    if (event.text === "<") {
      cycleStyle(); event.accepted = true; return
    }
    var chordIndex = numberChordIndex(event.key)
    if (chordIndex >= 0) {
      pressDegree(chordIndex); event.accepted = true; return
    }
    var modifierIndex = modifierIndexForText(event.text)
    if (modifierIndex >= 0) {
      beginTemporaryModifier(modifierIndex); event.accepted = true; return
    }
    var midi = Model.mappedMidi(event.text, octave)
    if (midi >= 0) {
      pressMidi(midi)
      event.accepted = true
    }
  }
  function handleRelease(event) {
    if (event.isAutoRepeat) { event.accepted = true; return }
    if (event.text === "<") { event.accepted = true; return }
    var chordIndex = numberChordIndex(event.key)
    if (chordIndex >= 0) {
      releaseDegree(chordIndex); event.accepted = true; return
    }
    var modifierIndex = modifierIndexForText(event.text)
    if (modifierIndex >= 0) {
      endTemporaryModifier(modifierIndex); event.accepted = true; return
    }
    var midi = Model.mappedMidi(event.text, octave)
    if (midi >= 0) { releaseMidi(midi); event.accepted = true }
  }

  function pressMidi(midi) {
    if (modifier === "") {
      pressManualMidi(midi)
      return
    }
    stopActiveNotes()
    var rawNotes = [midi]
    if (modifier !== "") {
      var intervals = Model.intervalsFor(modifier)
      rawNotes = []
      for (var intervalIndex = 0; intervalIndex < intervals.length; intervalIndex++)
        rawNotes.push(midi + intervals[intervalIndex])
    }
    var notes = resolveScaleNotes(rawNotes)
    if (!midiNotesValid(notes)) {
      statusText = "Voicing exceeds the MIDI range · lower the octave with Z"
      keyArea.forceActiveFocus()
      return
    }
    if (notes.length === 0) {
      statusText = scaleLockModeName() + " blocked " + (modifier !== ""
        ? Model.noteClassName(midi) + " " + Model.qualityDisplayName(modifier)
        : Model.noteName(midi))
      keyArea.forceActiveFocus()
      return
    }
    activeMidi = midi
    activeChordNotes = notes
    var historyLabel = Model.noteName(notes[0])
    if (modifier !== "") {
      var playedRoot = scaleLockMode === "fit" ? midi + lastScaleShift : midi
      historyLabel = Model.noteClassName(playedRoot) + " " + Model.qualityDisplayName(modifier)
    }
    recordHistory(historyLabel, notes)
    startChordNotes(notes)
    statusText = modifier !== ""
      ? "Playing " + historyLabel + " · " + notes.map(Model.noteName).join("  ")
      : "Playing " + Model.noteName(notes[0]) + (audioReady ? "" : " · audio starting…")
    keyArea.forceActiveFocus()
  }
  function releaseMidi(midi) {
    if (manualHeldNotes.length > 0) {
      releaseManualMidi(midi)
      return
    }
    if (activeMidi === midi) stopActiveNotes()
  }
  function manualOutputNotes() {
    var outputs = []
    for (var index = 0; index < manualHeldNotes.length; index++) {
      var note = manualHeldNotes[index].note
      if (outputs.indexOf(note) === -1) outputs.push(note)
    }
    return outputs
  }
  function pressManualMidi(midi) {
    for (var heldIndex = 0; heldIndex < manualHeldNotes.length; heldIndex++)
      if (manualHeldNotes[heldIndex].source === midi) return
    if (manualHeldNotes.length >= 5) {
      statusText = "Manual piano holds up to 5 notes"
      keyArea.forceActiveFocus()
      return
    }
    var notes = resolveScaleNotes([midi])
    if (!midiNotesValid(notes) || notes.length === 0) {
      statusText = scaleLockModeName() + " blocked " + Model.noteName(midi)
      keyArea.forceActiveFocus()
      return
    }
    var output = notes[0]
    var alreadySounding = manualOutputNotes().indexOf(output) !== -1 || activeChordNotes.indexOf(output) !== -1
    var nextHeld = manualHeldNotes.slice()
    nextHeld.push({ source: midi, note: output })
    manualHeldNotes = nextHeld
    activeMidi = midi
    if (!alreadySounding) startNotes([output])
    recordHistory(Model.noteName(output), [output])
    statusText = "Holding " + manualOutputNotes().map(Model.noteName).join("  ") + " · " + manualHeldNotes.length + "/5"
    keyArea.forceActiveFocus()
  }
  function releaseManualMidi(midi) {
    var released = null
    var remaining = []
    for (var heldIndex = 0; heldIndex < manualHeldNotes.length; heldIndex++) {
      var held = manualHeldNotes[heldIndex]
      if (held.source === midi && released === null) released = held
      else remaining.push(held)
    }
    if (released === null) return
    manualHeldNotes = remaining
    var outputs = manualOutputNotes()
    if (outputs.indexOf(released.note) === -1 && activeChordNotes.indexOf(released.note) === -1 && audioProcess.running)
      audioProcess.write(JSON.stringify({ type: "note_off", note: released.note }) + "\n")
    activeMidi = remaining.length > 0 ? remaining[remaining.length - 1].source : -1
    if (remaining.length === 0) statusText = "Manual piano ready"
  }
  function pressDegree(index) {
    stopActiveNotes()
    activeDegreeIndex = index
    var chord = chords[index]
    var rawNotes = Model.chordNotes(chord.root, chord.quality, octave)
    var notes = resolveScaleNotes(rawNotes)
    if (!midiNotesValid(notes)) {
      activeDegreeIndex = -1
      statusText = "Voicing exceeds the MIDI range · lower the octave with Z"
      return
    }
    if (notes.length === 0) {
      activeDegreeIndex = -1
      statusText = scaleLockModeName() + " blocked " + Model.chordDisplayName(chord.root, chord.quality)
      return
    }
    activeChordNotes = notes
    var playedRoot = scaleLockMode === "fit" ? chord.root + lastScaleShift : chord.root
    var historyLabel = Model.chordDisplayName(playedRoot, chord.quality)
    recordHistory(historyLabel, notes)
    startChordNotes(notes)
    statusText = chord.roman + " · " + historyLabel + " · " + notes.map(Model.noteName).join("  ")
  }
  function releaseDegree(index) {
    if (activeDegreeIndex === index) stopActiveNotes()
  }
  function recordHistory(label, notes) {
    var nextHistory = noteHistory.slice()
    nextHistory.push(label)
    if (nextHistory.length > 12) nextHistory = nextHistory.slice(nextHistory.length - 12)
    noteHistory = nextHistory
    var nextEvents = playedEvents.slice()
    nextEvents.push({ label: label, notes: notes.slice() })
    if (nextEvents.length > maxPlayedEvents)
      nextEvents = nextEvents.slice(nextEvents.length - maxPlayedEvents)
    playedEvents = nextEvents
  }
  function startNotes(notes) {
    if (!audioProcess.running) return
    for (var noteIndex = 0; noteIndex < notes.length; noteIndex++)
      audioProcess.write(JSON.stringify({ type: "note_on", note: notes[noteIndex], velocity: 104 }) + "\n")
  }
  function startChordNotes(notes) {
    var manualOutputs = manualOutputNotes()
    var newNotes = []
    for (var index = 0; index < notes.length; index++)
      if (manualOutputs.indexOf(notes[index]) === -1) newNotes.push(notes[index])
    startNotes(newNotes)
  }
  function isSounding(midi) {
    return activeChordNotes.indexOf(midi) !== -1 || manualOutputNotes().indexOf(midi) !== -1
  }
  function stopActiveNotes() {
    if (audioProcess.running) {
      for (var i = 0; i < activeChordNotes.length; i++)
        if (manualOutputNotes().indexOf(activeChordNotes[i]) === -1)
          audioProcess.write(JSON.stringify({ type: "note_off", note: activeChordNotes[i] }) + "\n")
    }
    activeChordNotes = []
    adjustedMidiNotes = []
    activeDegreeIndex = -1
  }

  function handleAudioLine(line) {
    try {
      var message = JSON.parse(String(line))
      if (message.type === "ready") {
        audioReady = true
        activeAudioBackend = String(message.backend || "fluid")
        proAudioAvailable = message.proAvailable === true
        statusText = activeAudioBackend === "fluid"
          ? "Audio ready · Acoustic Grand Piano"
          : activeAudioBackend === "keyboard-fluid"
            ? "Audio ready · Electric Keyboard"
          : activeAudioBackend === "synth" || activeAudioBackend === "synth-fluid"
            ? "Audio ready · " + (synthBank === "pro" ? "Pro Synth · " : "Basic Synth · ")
              + currentSynthVoices()[currentSynthVoiceIndex()].name
          : proAudioAvailable
            ? "Audio ready · Organ · Piano available"
            : "Audio ready · Organ · follow the GitHub README to add Piano"
        if (activeAudioBackend === "basic")
          audioProcess.write(JSON.stringify({ type: "character", value: basicCharacter }) + "\n")
        else if (activeAudioBackend === "keyboard-fluid")
          audioProcess.write(JSON.stringify({ type: "keyboard_tone", value: keyboardTone }) + "\n")
        else if (activeAudioBackend === "synth" || activeAudioBackend === "synth-fluid")
          sendSynthSettings()
        else if (cinematicFactor > 0)
          audioProcess.write(JSON.stringify({ type: "cinematic", value: cinematicFactor }) + "\n")
      } else if (message.type === "error") {
        audioReady = false
        statusText = "Audio unavailable · " + message.message
      }
    } catch (error) {
      statusText = "Audio engine · " + String(line)
    }
  }

  function filenamePart(value) {
    return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
  }
  function keyFilenamePart() {
    return ["c", "c-sharp", "d", "d-sharp", "e", "f", "f-sharp", "g", "g-sharp", "a", "a-sharp", "b"][keyRoot]
  }
  function twoDigits(value) { return value < 10 ? "0" + value : String(value) }
  function midiFilename() {
    var now = new Date()
    var stamp = now.getFullYear() + "-" + twoDigits(now.getMonth() + 1) + "-" + twoDigits(now.getDate())
      + "-" + twoDigits(now.getHours()) + twoDigits(now.getMinutes()) + twoDigits(now.getSeconds())
    return filenamePart(currentStyle.name) + "-" + keyFilenamePart() + "-" + filenamePart(scaleTypeName()) + "-"
      + filenamePart(chordPaletteName()) + "-" + stamp + ".mid"
  }
  function exportMidi() {
    if (midiProcess.running) return
    if (playedEvents.length === 0) {
      statusText = "Play something first · history is empty"
      return
    }
    var exportEvents = []
    for (var i = 0; i < playedEvents.length; i++)
      exportEvents.push({ notes: playedEvents[i].notes.slice(0, 16) })
    statusText = "Exporting " + exportEvents.length + " played events…"
    midiProcess.command = ["/usr/bin/python3", enginePath, "midi", "--output", outputDir + "/" + midiFilename(),
      "--tempo", "110", "--events", JSON.stringify(exportEvents)]
    midiProcess.running = true
  }
  function requestClearHistory() {
    if (playedEvents.length === 0) {
      clearHistoryArmed = false
      clearHistoryTimer.stop()
      statusText = "MIDI history is already empty"
      return
    }
    if (!clearHistoryArmed) {
      clearHistoryArmed = true
      clearHistoryTimer.restart()
      statusText = "Clear all " + playedEvents.length + " played events? · click Confirm clear"
      return
    }
    clearHistoryTimer.stop()
    clearHistoryArmed = false
    playedEvents = []
    noteHistory = []
    statusText = "MIDI history cleared · ready for a new take"
  }

  Timer {
    id: clearHistoryTimer
    interval: 5000
    repeat: false
    onTriggered: {
      root.clearHistoryArmed = false
      root.statusText = "Clear cancelled · MIDI history kept"
    }
  }

  Timer {
    id: cinematicCueTimer
    interval: 1090
    repeat: true
    onTriggered: {
      interval = 1090
      for (var releaseIndex = 0; releaseIndex < root.cinematicCueNotes.length; releaseIndex++)
        audioProcess.write(JSON.stringify({ type: "note_off", note: root.cinematicCueNotes[releaseIndex] }) + "\n")
      root.cinematicCueNotes = []
      if (root.cinematicCueIndex >= 10) {
        root.stopCinematicCue()
        root.statusText = "Cinematic cue complete"
        return
      }
      if (root.cinematicCueIndex % 2 === 0) {
        var cueFactor = Math.min(100, (Math.floor(root.cinematicCueIndex / 2) + 1) * 20)
        if (root.cueUsesBasic) root.setBasicCharacter(cueFactor)
        else root.setCinematic(cueFactor)
      }
      var chord = root.chords[root.cinematicCueIndex]
      var notes = root.resolveScaleNotes(Model.chordNotes(chord.root, chord.quality, root.octave))
      if (root.midiNotesValid(notes)) {
        root.cinematicCueNotes = notes.slice()
        for (var noteIndex = 0; noteIndex < notes.length; noteIndex++)
          audioProcess.write(JSON.stringify({ type: "note_on", note: notes[noteIndex], velocity: 108 }) + "\n")
      }
      root.cinematicCueIndex++
    }
  }

  Timer {
    id: cueAccentTimer
    interval: 272
    repeat: true
    onTriggered: {
      if (root.cueAccentNote >= 0)
        audioProcess.write(JSON.stringify({ type: "note_off", note: root.cueAccentNote }) + "\n")
      root.cueAccentNote = -1
      if (root.cinematicCueNotes.length === 0) return
      var degrees = [4, 2, 5, 4, 6, 4, 2, 1, 4, 5, 6, 4, 2, 1, 0, 2]
      var octaves = [0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1]
      var scale = Model.scaleSteps(root.scaleType)
      var note = 12 * (Math.min(6, root.octave + 2) + 1) + root.keyRoot
        + scale[degrees[root.cueAccentIndex] % scale.length]
        + 12 * octaves[root.cueAccentIndex]
      note = Math.max(0, Math.min(127, note))
      root.cueAccentNote = note
      audioProcess.write(JSON.stringify({ type: "note_on", note: note, velocity: 88 }) + "\n")
      root.cueAccentIndex = (root.cueAccentIndex + 1) % degrees.length
    }
  }

  Process {
    id: audioProcess
    command: ["/usr/bin/python3", root.enginePath, "serve", "--backend", root.audioBackendPreference]
    running: true
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.handleAudioLine(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        if (String(line).trim() !== "") root.statusText = "Audio engine reported an error"
      }
    }
    onExited: function(exitCode) {
      root.audioReady = false
      root.activeAudioBackend = ""
      if (root.audioRestarting) {
        root.audioRestarting = false
        Qt.callLater(function() { audioProcess.running = true })
        return
      }
      if (exitCode !== 0) root.statusText = "Audio engine stopped · restart the shell or see GitHub troubleshooting"
    }
  }

  Component.onCompleted: applyStyle(0)

  Process {
    id: midiProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.statusText = "Exported · " + String(text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.statusText = "Export failed · " + String(text).trim()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyArea
    contentWidth: panel.fittedContentWidth(Style.space(760))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    FocusScope {
      id: keyArea
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) { root.handlePress(event) }
      Keys.onReleased: function(event) { root.handleRelease(event) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(10)
          Column {
            width: Math.max(0, parent.width - headerControls.width - Style.space(10))
            clip: true
            Text {
              width: parent.width
              text: "CHORDPUMPER PROMARCHY"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: Model.pitchClassLabel(root.keyRoot) + " " + root.scaleTypeName() + " · " + root.scaleLockModeName() + " · " + root.currentStyle.name + " · 110 BPM"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }
          Row {
            id: headerControls
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            Row {
              spacing: 0
              Button {
                text: "Organ"
                selected: root.activeAudioBackend === "basic"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.selectAudioBackend("basic")
              }
              Text {
                text: " | "
                color: root.pianoMuted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
              Button {
                text: "Keyboard"
                selected: root.activeAudioBackend === "keyboard-fluid"
                bordered: true
                foreground: root.proAudioAvailable ? root.pianoGold : root.pianoMuted
                fontFamily: root.fontFamily
                tooltipText: root.proAudioAvailable ? "Electric Keyboard" : "Optional Pro sound · click for installation instructions"
                onClicked: root.activateKeyboard()
              }
              Button {
                text: "Piano"
                selected: root.activeAudioBackend === "fluid"
                bordered: true
                foreground: root.proAudioAvailable ? root.pianoGold : root.pianoMuted
                fontFamily: root.fontFamily
                tooltipText: root.proAudioAvailable ? "Acoustic Piano" : "Optional Pro sound · click for installation instructions"
                onClicked: root.selectAudioBackend("fluid")
              }
              Button {
                text: "Synth"
                selected: root.activeAudioBackend === "synth-fluid"
                bordered: true
                foreground: root.proAudioAvailable ? root.pianoGold : root.pianoMuted
                fontFamily: root.fontFamily
                tooltipText: root.proAudioAvailable ? "Eight-voice Pro Synth" : "Optional Pro sound · click for installation instructions"
                onClicked: root.activateProSynth()
              }
            }
          }
        }

        Row {
          id: scaleLockRow
          width: parent.width
          spacing: Style.space(8)
          Row {
            id: scaleControls
            visible: !root.synthSelected
            spacing: Style.space(5)
            Text {
            text: "SCALE LOCK"
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
          Button {
            text: Model.pitchClassLabel(root.keyRoot) + "  ▾"
            selected: root.keyPickerOpen
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              root.keyPickerOpen = !root.keyPickerOpen
              if (root.keyPickerOpen) root.scalePickerOpen = false
            }
          }
          Button {
            text: root.scaleTypeName() + "  ▾"
            selected: root.scalePickerOpen
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              root.scalePickerOpen = !root.scalePickerOpen
              if (root.scalePickerOpen) root.keyPickerOpen = false
            }
          }
            Repeater {
              model: root.scaleLockModes
              Button {
              required property var modelData
              text: modelData.name
              selected: root.scaleLockMode === modelData.id
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: { root.setScaleLockMode(modelData.id); keyArea.forceActiveFocus() }
              }
            }
          }
          Row {
            id: synthControls
            visible: root.synthSelected
            spacing: Style.space(root.synthControlGap)
            anchors.verticalCenter: parent.verticalCenter
            Text {
              width: Style.space(root.synthMainLabelWidth)
              text: "SYNTH"
              color: Qt.darker(root.foreground, 1.35)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
            Dropdown {
              width: Style.space(root.synthVoiceDropdownWidth)
              height: Style.spacing.controlHeight
              rowHeight: Style.spacing.controlHeight
              popupRowHeight: Style.spacing.popupRowHeight
              showLabel: false
              value: String(root.currentSynthVoiceIndex())
              options: root.currentSynthVoiceOptions()
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) { root.selectSynthVoice(Number(value)) }
            }
            Row {
              spacing: Style.space(root.synthInnerGap)
              anchors.verticalCenter: parent.verticalCenter
              Text {
                width: Style.space(root.synthSpaceShortcutWidth)
                text: "'  \\  ±10"
                color: root.pianoMuted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                width: Style.space(root.synthParameterLabelWidth)
                text: "SPACE " + root.currentSynthSpace()
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }
              PanelSlider {
                bar: root.bar
                width: Style.space(root.synthParameterSliderWidth)
                minimum: 0; maximum: 100; step: 1; tickCount: 3
                value: root.currentSynthSpace()
                onMoved: function(value) { root.setSynthSpace(value) }
              }
            }
          }
          Item {
            width: Math.max(0, parent.width
              - (root.synthSelected ? synthControls.width : scaleControls.width)
              - characterControls.width - parent.spacing * 2)
            height: 1
          }
          Row {
            id: characterControls
            visible: root.activeAudioBackend === "basic" || root.activeAudioBackend === "keyboard-fluid"
              || root.activeAudioBackend === "fluid" || root.synthSelected
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            Text {
              width: root.synthSelected ? Style.space(root.synthCutoffShortcutWidth) : implicitWidth
              text: "[ ] ±10"
              color: root.pianoMuted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              id: soundFactorLabel
              width: root.synthSelected ? Style.space(root.synthCutoffLabelWidth) : implicitWidth
                text: (root.synthSelected ? "FILTER " : "TONE ")
                + (root.activeAudioBackend === "fluid" ? root.cinematicFactor
                  : root.activeAudioBackend === "keyboard-fluid" ? root.keyboardTone
                  : root.synthSelected ? root.currentSynthCutoff() : root.basicCharacter)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignHCenter
              anchors.verticalCenter: parent.verticalCenter
              TapHandler {
                acceptedButtons: Qt.RightButton
                onDoubleTapped: root.playCinematicCue()
              }
              TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: {
                  if (root.activeAudioBackend === "fluid") root.setCinematic(0)
                  else if (root.activeAudioBackend === "keyboard-fluid") root.setKeyboardTone(60)
                  else if (root.synthSelected) root.setSynthCutoff(root.currentSynthVoices()[root.currentSynthVoiceIndex()].cutoff)
                  else root.setBasicCharacter(50)
                }
              }
            }
            PanelSlider {
              id: characterSlider
              bar: root.bar
              width: root.synthSelected
                ? Style.space(root.synthCutoffSliderWidth) : Style.space(125)
              minimum: 0
              maximum: 100
              step: 1
              value: root.activeAudioBackend === "fluid" ? root.cinematicFactor
                : root.activeAudioBackend === "keyboard-fluid" ? root.keyboardTone
                : root.synthSelected ? root.currentSynthCutoff() : root.basicCharacter
              tickCount: 3
              onMoved: function(value) {
                if (root.activeAudioBackend === "fluid") root.setCinematic(value)
                else if (root.activeAudioBackend === "keyboard-fluid") root.setKeyboardTone(value)
                else if (root.synthSelected) root.setSynthCutoff(value)
                else root.setBasicCharacter(value)
              }
              TapHandler {
                onDoubleTapped: {
                  if (root.activeAudioBackend === "fluid") root.setCinematic(0)
                  else if (root.activeAudioBackend === "keyboard-fluid") root.setKeyboardTone(60)
                  else if (root.synthSelected) root.setSynthCutoff(root.currentSynthVoices()[root.currentSynthVoiceIndex()].cutoff)
                  else root.setBasicCharacter(50)
                }
              }
            }
          }
        }

        Row {
          id: synthScaleControls
          visible: root.synthSelected
          width: parent.width
          spacing: Style.space(5)
          Text {
            text: "SCALE LOCK"
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
          Button {
            text: Model.pitchClassLabel(root.keyRoot) + "  ▾"
            selected: root.keyPickerOpen
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              root.keyPickerOpen = !root.keyPickerOpen
              if (root.keyPickerOpen) root.scalePickerOpen = false
            }
          }
          Button {
            text: root.scaleTypeName() + "  ▾"
            selected: root.scalePickerOpen
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              root.scalePickerOpen = !root.scalePickerOpen
              if (root.scalePickerOpen) root.keyPickerOpen = false
            }
          }
          Repeater {
            model: root.scaleLockModes
            Button {
              required property var modelData
              text: modelData.name
              selected: root.scaleLockMode === modelData.id
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: { root.setScaleLockMode(modelData.id); keyArea.forceActiveFocus() }
            }
          }
        }

        Grid {
          visible: root.keyPickerOpen
          columns: 6
          spacing: Style.space(5)
          Repeater {
            model: root.scaleRoots
            Button {
              required property int modelData
              width: (content.width - Style.space(25)) / 6
              text: Model.pitchClassLabel(modelData)
              selected: root.keyRoot === modelData
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: { root.setKeyRoot(modelData); keyArea.forceActiveFocus() }
            }
          }
        }

        Grid {
          visible: root.scalePickerOpen
          columns: 4
          spacing: Style.space(5)
          Repeater {
            model: root.scaleTypes
            Button {
              required property var modelData
              width: (content.width - Style.space(15)) / 4
              text: modelData.name
              selected: root.scaleType === modelData.id
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: { root.setScaleType(modelData.id); keyArea.forceActiveFocus() }
            }
          }
        }

        Text {
          visible: root.scaleLockMode !== "off"
          text: "AVAILABLE TONES  ·  " + Model.scaleToneNames(root.keyRoot, root.scaleType).join("   ")
          color: Qt.darker(root.foreground, 1.25)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Row {
          width: parent.width
          spacing: Style.space(5)
          Text {
            width: parent.width - paletteControls.width - Style.space(5)
            text: root.currentStyle.name.toUpperCase() + " CHORDS  ·  hold 1–9 / 0 to play"
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
          Row {
            id: paletteControls
            spacing: Style.space(4)
            Repeater {
              model: [
                { id: "core", name: "Core" }, { id: "alt", name: "Alt" },
                { id: "colour", name: "Colour" }
              ]
              Button {
                required property var modelData
                text: modelData.name
                selected: root.chordPaletteMode === modelData.id
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: { root.setChordPalette(modelData.id); keyArea.forceActiveFocus() }
              }
            }
            Text {
              text: " · "
              color: root.pianoMuted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
            Dropdown {
              width: Style.space(92)
              showLabel: false
              value: String(root.styleIndex)
              options: root.styleOptions
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) { root.applyStyle(Number(value)); keyArea.forceActiveFocus() }
            }
            Button {
              text: ""
              iconText: "⚄"
              tooltipText: "Randomize everything"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              width: Style.spacing.controlHeight
              height: Style.spacing.controlHeight
              horizontalPadding: 0
              verticalPadding: 0
              iconSize: Style.font.title
              onClicked: { root.randomizeAll(); keyArea.forceActiveFocus() }
            }
          }
        }
        Grid {
          columns: 5
          spacing: Style.space(6)
          Repeater {
            model: root.chords
            Button {
              required property var modelData
              required property int index
              width: (content.width - Style.space(24)) / 5
              text: (index === 9 ? "0" : String(index + 1)) + " · " + modelData.roman + "\n" + Model.chordDisplayName(modelData.root, modelData.quality)
              selected: root.activeDegreeIndex === index
              enabled: false
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
            }
          }
        }

        Text {
          text: root.currentStyle.name.toUpperCase() + " SHAPES  ·  hold C V B N M , . /  ·  click to lock  ·  < next style"
          color: Qt.darker(root.foreground, 1.35)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Grid {
          columns: 4
          spacing: Style.space(5)
          Repeater {
            model: root.modifiers
            Button {
              required property string modelData
              required property int index
              width: (content.width - Style.space(15)) / 4
              text: root.modifierKeys[index] + " · " + Model.qualityDisplayName(modelData) + (root.lockedModifier === modelData ? "  ◆" : "")
              selected: root.modifier === modelData
              active: root.lockedModifier === modelData
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: { root.toggleModifierLock(modelData); keyArea.forceActiveFocus() }
            }
          }
        }

        Row {
          width: parent.width
          Text {
            text: "PLAYABLE KEYBOARD"
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Text {
            width: parent.width - x
            text: root.noteHistory.length > 0 ? "RECENT   " + root.noteHistory.join("  ·  ") : "RECENT   —"
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        Row {
          id: chordKeyStrip
          width: parent.width
          height: Style.space(23)
          spacing: Style.space(2)
          Repeater {
            model: root.chords
            Rectangle {
              required property var modelData
              required property int index
              width: (chordKeyStrip.width - chordKeyStrip.spacing * 9) / 10
              height: chordKeyStrip.height
              radius: Style.space(3)
              color: root.activeDegreeIndex === index
                ? root.pianoPressed
                : Color.popups.background
              border.width: 1
              border.color: root.activeDegreeIndex === index ? root.foreground : Color.popups.border
              clip: true
              Text {
                anchors.fill: parent
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: (index === 9 ? "0" : String(index + 1)) + " · " + modelData.roman
                color: root.activeDegreeIndex === index ? root.pianoSurface : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.activeDegreeIndex === index
              }
            }
          }
        }
        Rectangle {
          id: piano
          width: parent.width
          height: Style.space(108)
          radius: Style.cornerRadius
          color: root.pianoSurface
          clip: true

          readonly property real whiteKeyWidth: width / root.whiteKeys.length
          readonly property real blackKeyWidth: whiteKeyWidth * 0.62
          readonly property real blackKeyHeight: height * 0.61

          Repeater {
            model: root.whiteKeys
            Rectangle {
              required property var modelData
              required property int index
              readonly property int midi: 12 * (root.octave + 1) + modelData.offset
              readonly property bool scaleTone: root.scaleAllowed(midi)
              readonly property bool adjusted: root.adjustedMidiNotes.indexOf(midi) !== -1
              readonly property bool sounding: root.isSounding(midi)
              x: index * piano.whiteKeyWidth
              y: 0
              width: piano.whiteKeyWidth + 1
              height: piano.height
              color: sounding ? root.pianoPressed
                : adjusted ? root.pianoAdjusted
                : scaleTone ? root.pianoWhite
                : Qt.rgba(root.pianoMuted.r, root.pianoMuted.g, root.pianoMuted.b, 0.52)
              border.width: 1
              border.color: Color.popups.border
              radius: index === 0 || index === root.whiteKeys.length - 1 ? Style.space(3) : 0
              Behavior on color { ColorAnimation { duration: 90 } }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: noteLabel.top
                anchors.bottomMargin: Style.space(4)
                text: modelData.letter
                visible: modelData.letter !== ""
                color: parent.sounding || parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface
                  : (parent.scaleTone ? root.pianoBlack : root.pianoSurface)
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
              Text {
                id: noteLabel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(5)
                text: Model.noteName(parent.midi)
                color: parent.sounding || parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface : root.pianoMuted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                anchors.fill: parent
                onPressed: root.pressMidi(parent.midi)
                onReleased: root.releaseMidi(parent.midi)
                onCanceled: root.releaseMidi(parent.midi)
              }
            }
          }

          Repeater {
            model: root.blackKeys
            Rectangle {
              required property var modelData
              readonly property int midi: 12 * (root.octave + 1) + modelData.offset
              readonly property bool scaleTone: root.scaleAllowed(midi)
              readonly property bool adjusted: root.adjustedMidiNotes.indexOf(midi) !== -1
              readonly property bool sounding: root.isSounding(midi)
              z: 2
              x: modelData.after * piano.whiteKeyWidth - piano.blackKeyWidth / 2
              y: 0
              width: piano.blackKeyWidth
              height: piano.blackKeyHeight
              color: sounding ? root.pianoPressed
                : adjusted ? root.pianoAdjusted
                : scaleTone ? root.pianoBlack
                : Qt.darker(root.pianoMuted, 1.45)
              border.width: 1
              border.color: sounding || adjusted || root.activeMidi === midi ? root.foreground : Color.popups.border
              radius: Style.space(3)
              Behavior on color { ColorAnimation { duration: 90 } }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Style.space(7)
                color: parent.sounding || root.activeMidi === parent.midi ? Qt.darker(root.pianoPressed, 1.15)
                  : parent.adjusted ? Qt.darker(root.pianoAdjusted, 1.15)
                  : Qt.rgba(root.pianoSurface.r, root.pianoSurface.g, root.pianoSurface.b, 0.78)
                radius: Style.space(2)
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: blackNoteLabel.top
                anchors.bottomMargin: Style.space(3)
                text: modelData.letter
                color: parent.sounding || parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface
                  : (parent.scaleTone ? root.foreground : root.pianoMuted)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                id: blackNoteLabel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(6)
                text: Model.noteName(parent.midi)
                color: parent.sounding || parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface : root.pianoMuted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                anchors.fill: parent
                onPressed: root.pressMidi(parent.midi)
                onReleased: root.releaseMidi(parent.midi)
                onCanceled: root.releaseMidi(parent.midi)
              }
            }
          }
        }

        Row {
          width: parent.width; spacing: Style.space(8)
          Text {
            id: octaveStatus
            text: "OCT " + root.octave + "  ·  Z/X"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            id: statusLabel
            width: parent.width - octaveStatus.width - clearHistoryButton.width
              - resetSoundButton.width - exportButton.width - parent.spacing * 4
            text: root.statusText
            color: root.statusText === root.proHelpText ? root.pianoPressed : Qt.darker(root.foreground, 1.3)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
            textFormat: Text.PlainText
            font.underline: root.statusText === root.proHelpText
            MouseArea {
              anchors.fill: parent
              enabled: root.statusText === root.proHelpText
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: Qt.openUrlExternally(root.proHelpUrl)
            }
          }
          Button {
            id: clearHistoryButton
            text: root.clearHistoryArmed ? "Confirm clear" : "Clear MIDI"
            selected: root.clearHistoryArmed
            bordered: true
            foreground: root.clearHistoryArmed ? Color.urgent : root.foreground
            onClicked: {
              root.requestClearHistory()
              keyArea.forceActiveFocus()
            }
          }
          Button {
            id: resetSoundButton
            text: "Reset Sound"
            tooltipText: "Restore this instrument's original tone and effects"
            bordered: true
            foreground: root.foreground
            onClicked: root.resetSound()
          }
          Button {
            id: exportButton; text: "Export MIDI"; bordered: true; foreground: root.foreground
            onClicked: {
              root.exportMidi()
              keyArea.forceActiveFocus()
            }
          }
        }
      }
    }
  }
}
