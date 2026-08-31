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

  property int keyRoot: 0
  property string scaleType: "major"
  property string scaleLockMode: "nearest"
  property bool keyPickerOpen: false
  property bool scalePickerOpen: false
  property int lastScaleShift: 0
  property int octave: 4
  property int selectedDegree: 0
  property string modifier: ""
  property string lockedModifier: ""
  property int temporaryModifierIndex: -1
  property int activeMidi: -1
  property int activeDegreeIndex: -1
  property var activeChordNotes: []
  property var adjustedMidiNotes: []
  property var noteHistory: []
  property bool audioReady: false
  property int styleIndex: 0
  property bool stylePickerOpen: false
  readonly property var styles: Styles.all()
  readonly property var currentStyle: Styles.at(styleIndex)
  readonly property var chords: Styles.chordsFor(styleIndex, keyRoot)
  property var progression: []
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
    stopActiveNotes()
    if (audioProcess.running) audioProcess.write(JSON.stringify({ type: "all_off" }) + "\n")
    root.controller.hide()
  }
  function toggle() { if (root.opened) close(); else open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }
  function chooseDegree(index) {
    selectedDegree = index
    statusText = "Selected " + chords[index].roman + " · " + Model.chordDisplayName(chords[index].root, chords[index].quality)
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
  function rebuildProgression() {
    var pool = Styles.chordsFor(styleIndex, keyRoot)
    var next = []
    var order = [0, 2, 3, 1]
    for (var j = 0; j < order.length; j++) next.push(pool[order[j] % pool.length])
    progression = next
  }
  function applyStyle(index) {
    stopActiveNotes()
    styleIndex = ((index % styles.length) + styles.length) % styles.length
    stylePickerOpen = false
    temporaryModifierIndex = -1
    lockedModifier = ""
    modifier = ""
    rebuildProgression()
    selectedDegree = 0
    statusText = currentStyle.name + " style · palette loaded"
  }
  function cycleStyle() { applyStyle(styleIndex + 1) }
  function randomizeAll() {
    var nextStyle = Math.floor(Math.random() * styles.length)
    applyStyle(nextStyle)
    selectedDegree = Math.floor(Math.random() * chords.length)
    lockedModifier = modifiers[Math.floor(Math.random() * modifiers.length)]
    modifier = lockedModifier
    statusText = "Random · " + currentStyle.name + " · "
      + Model.chordDisplayName(chords[selectedDegree].root, chords[selectedDegree].quality)
      + " · " + Model.qualityDisplayName(lockedModifier) + " locked"
  }
  function setKeyRoot(value) {
    stopActiveNotes()
    keyRoot = value
    keyPickerOpen = false
    scalePickerOpen = false
    if (scaleLockMode === "off") scaleLockMode = "nearest"
    rebuildProgression()
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
  function styleSuggestionText() {
    var names = []
    for (var i = 0; i < chords.length; i++) names.push(Model.chordDisplayName(chords[i].root, chords[i].quality))
    return names.join("  •  ")
  }
  function progressionSpec() {
    var parts = []
    for (var i = 0; i < progression.length; i++)
      parts.push(Model.asciiNoteName(progression[i].root) + ":" + progression[i].quality)
    return parts.join(",")
  }
  function handlePress(event) {
    if (event.isAutoRepeat) { event.accepted = true; return }
    if (event.key === Qt.Key_Escape) { close(); event.accepted = true; return }
    if (event.key === Qt.Key_Z) { octave = Math.max(1, octave - 1); statusText = "Octave " + octave; event.accepted = true; return }
    if (event.key === Qt.Key_X) { octave = Math.min(7, octave + 1); statusText = "Octave " + octave; event.accepted = true; return }
    if (event.text === "<") {
      cycleStyle(); event.accepted = true; return
    }
    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
      pressDegree(event.key - Qt.Key_1); event.accepted = true; return
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
    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
      releaseDegree(event.key - Qt.Key_1); event.accepted = true; return
    }
    var modifierIndex = modifierIndexForText(event.text)
    if (modifierIndex >= 0) {
      endTemporaryModifier(modifierIndex); event.accepted = true; return
    }
    var midi = Model.mappedMidi(event.text, octave)
    if (midi >= 0) { releaseMidi(midi); event.accepted = true }
  }

  function pressMidi(midi) {
    stopActiveNotes()
    var rawNotes = [midi]
    if (modifier !== "") {
      var intervals = Model.intervalsFor(modifier)
      rawNotes = []
      for (var intervalIndex = 0; intervalIndex < intervals.length; intervalIndex++)
        rawNotes.push(midi + intervals[intervalIndex])
    }
    var notes = resolveScaleNotes(rawNotes)
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
    recordHistory(historyLabel)
    startNotes(notes)
    statusText = modifier !== ""
      ? "Playing " + historyLabel + " · " + notes.map(Model.noteName).join("  ")
      : "Playing " + Model.noteName(notes[0]) + (audioReady ? "" : " · audio starting…")
    keyArea.forceActiveFocus()
  }
  function releaseMidi(midi) {
    if (activeMidi === midi) stopActiveNotes()
  }
  function pressDegree(index) {
    stopActiveNotes()
    activeDegreeIndex = index
    var chord = chords[index]
    var rawNotes = Model.chordNotes(chord.root, chord.quality, octave)
    var notes = resolveScaleNotes(rawNotes)
    if (notes.length === 0) {
      activeDegreeIndex = -1
      statusText = scaleLockModeName() + " blocked " + Model.chordDisplayName(chord.root, chord.quality)
      return
    }
    activeChordNotes = notes
    var playedRoot = scaleLockMode === "fit" ? chord.root + lastScaleShift : chord.root
    var historyLabel = Model.chordDisplayName(playedRoot, chord.quality)
    recordHistory(historyLabel)
    startNotes(notes)
    statusText = chord.roman + " · " + historyLabel + " · " + notes.map(Model.noteName).join("  ")
  }
  function releaseDegree(index) {
    if (activeDegreeIndex === index) stopActiveNotes()
  }
  function recordHistory(label) {
    var nextHistory = noteHistory.slice()
    nextHistory.push(label)
    if (nextHistory.length > 12) nextHistory = nextHistory.slice(nextHistory.length - 12)
    noteHistory = nextHistory
  }
  function startNotes(notes) {
    if (!audioProcess.running) return
    for (var noteIndex = 0; noteIndex < notes.length; noteIndex++)
      audioProcess.write(JSON.stringify({ type: "note_on", note: notes[noteIndex], velocity: 104 }) + "\n")
  }
  function stopActiveNotes() {
    if (audioProcess.running) {
      for (var i = 0; i < activeChordNotes.length; i++)
        audioProcess.write(JSON.stringify({ type: "note_off", note: activeChordNotes[i] }) + "\n")
    }
    activeChordNotes = []
    adjustedMidiNotes = []
    activeMidi = -1
    activeDegreeIndex = -1
  }

  function handleAudioLine(line) {
    try {
      var message = JSON.parse(String(line))
      if (message.type === "ready") {
        audioReady = true
        statusText = "Audio ready · Acoustic Grand Piano"
      } else if (message.type === "error") {
        audioReady = false
        statusText = "Audio unavailable · " + message.message
      }
    } catch (error) {
      statusText = "Audio engine · " + String(line)
    }
  }

  function runEngine(process, action, output) {
    if (process.running) return
    statusText = action === "save" ? "Saving project…" : "Exporting MIDI…"
    process.command = ["python3", enginePath, action, "--output", output,
      "--tempo", "110", "--key", Model.asciiNoteName(keyRoot),
      "--scale", scaleType, "--progression", progressionSpec()]
    process.running = true
  }

  Process {
    id: audioProcess
    command: ["python3", root.enginePath, "serve"]
    running: true
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.handleAudioLine(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        if (String(line).trim() !== "") root.statusText = "Synth · " + String(line).trim()
      }
    }
    onExited: function(exitCode) {
      root.audioReady = false
      if (exitCode !== 0) root.statusText = "Audio engine stopped · install FluidSynth and restart the shell"
    }
  }

  Component.onCompleted: applyStyle(0)

  Process {
    id: saveProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.statusText = "Saved · " + String(text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.statusText = "Save failed · " + String(text).trim()
    }
  }

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
            width: parent.width - headerControls.width - Style.space(10)
            Text { text: "CHORDPUMPER PROMARCHY"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text {
              text: Model.pitchClassLabel(root.keyRoot) + " " + root.scaleTypeName() + " · " + root.scaleLockModeName() + " · " + root.currentStyle.name + " · 110 BPM"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
          Row {
            id: headerControls
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            Button {
              text: root.currentStyle.name + "  ▾"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.stylePickerOpen = !root.stylePickerOpen
            }
            Button {
              text: "Random"
              iconText: "⚄"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: { root.randomizeAll(); keyArea.forceActiveFocus() }
            }
            Text {
              text: "OCT " + root.octave + "  Z/X"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        Grid {
          visible: root.stylePickerOpen
          columns: 6
          spacing: Style.space(5)
          Repeater {
            model: root.styles
            Button {
              required property var modelData
              required property int index
              width: (content.width - Style.space(25)) / 6
              text: modelData.name
              selected: root.styleIndex === index
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: { root.applyStyle(index); keyArea.forceActiveFocus() }
            }
          }
        }

        Row {
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

        Text { text: root.currentStyle.name.toUpperCase() + " CHORDS  ·  hold 1–6 to play"; color: Qt.darker(root.foreground, 1.35); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
        Grid {
          columns: 6
          spacing: Style.space(6)
          Repeater {
            model: root.chords
            Button {
              required property var modelData
              required property int index
              width: (content.width - Style.space(30)) / 6
              text: (index + 1) + " · " + modelData.roman + "\n" + Model.chordDisplayName(modelData.root, modelData.quality)
              selected: root.selectedDegree === index || root.activeDegreeIndex === index
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: { root.chooseDegree(index); keyArea.forceActiveFocus() }
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
              readonly property bool sounding: root.activeChordNotes.indexOf(midi) !== -1
              x: index * piano.whiteKeyWidth
              y: 0
              width: piano.whiteKeyWidth + 1
              height: piano.height
              color: adjusted ? root.pianoAdjusted
                : root.activeMidi === midi ? root.pianoPressed
                : sounding ? Style.selectedStateColor(root.foreground, Color.accent, Color.urgent)
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
                color: parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface
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
                color: parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface : root.pianoMuted
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
              readonly property bool sounding: root.activeChordNotes.indexOf(midi) !== -1
              z: 2
              x: modelData.after * piano.whiteKeyWidth - piano.blackKeyWidth / 2
              y: 0
              width: piano.blackKeyWidth
              height: piano.blackKeyHeight
              color: adjusted ? root.pianoAdjusted
                : root.activeMidi === midi ? root.pianoPressed
                : sounding ? Style.selectedStateColor(root.foreground, Color.accent, Color.urgent)
                : scaleTone ? root.pianoBlack
                : Qt.darker(root.pianoMuted, 1.45)
              border.width: 1
              border.color: adjusted || root.activeMidi === midi ? root.foreground : Color.popups.border
              radius: Style.space(3)
              Behavior on color { ColorAnimation { duration: 90 } }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Style.space(7)
                color: parent.adjusted ? Qt.darker(root.pianoAdjusted, 1.15)
                  : root.activeMidi === parent.midi ? Qt.darker(root.pianoPressed, 1.15)
                  : Qt.rgba(root.pianoSurface.r, root.pianoSurface.g, root.pianoSurface.b, 0.78)
                radius: Style.space(2)
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: blackNoteLabel.top
                anchors.bottomMargin: Style.space(3)
                text: modelData.letter
                color: parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface
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
                color: parent.adjusted || root.activeMidi === parent.midi ? root.pianoSurface : root.pianoMuted
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
            width: parent.width - saveButton.width - exportButton.width - parent.spacing * 2
            text: root.statusText; color: Qt.darker(root.foreground, 1.3); font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
          }
          Button {
            id: saveButton; text: "Save"; bordered: true; foreground: root.foreground
            onClicked: {
              root.runEngine(saveProcess, "save", root.outputDir + "/Untitled.chordpumper.json")
              keyArea.forceActiveFocus()
            }
          }
          Button {
            id: exportButton; text: "Export MIDI"; bordered: true; foreground: root.foreground
            onClicked: {
              root.runEngine(midiProcess, "midi", root.outputDir + "/Untitled.mid")
              keyArea.forceActiveFocus()
            }
          }
        }
      }
    }
  }
}
