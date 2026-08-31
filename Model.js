.pragma library

var NOTE_NAMES = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
var MAJOR_STEPS = [0, 2, 4, 5, 7, 9, 11]
var MAJOR_QUALITIES = ["maj", "min", "min", "maj", "maj", "min", "dim"]
var ROMAN = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
var MINOR_STEPS = [0, 2, 3, 5, 7, 8, 10]
var PITCH_CLASS_LABELS = ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"]

function modulo(value, base) { return ((value % base) + base) % base }

function noteName(midi) {
  return NOTE_NAMES[modulo(midi, 12)] + (Math.floor(midi / 12) - 1)
}

function pitchClassLabel(value) {
  return PITCH_CLASS_LABELS[modulo(value, 12)]
}

function scaleSteps(scaleType) {
  return scaleType === "minor" ? MINOR_STEPS : MAJOR_STEPS
}

function isInScale(note, root, scaleType) {
  return scaleSteps(scaleType).indexOf(modulo(note - root, 12)) !== -1
}

function nearestScaleNote(note, root, scaleType) {
  if (isInScale(note, root, scaleType)) return note
  for (var distance = 1; distance <= 6; distance++) {
    if (isInScale(note - distance, root, scaleType)) return note - distance
    if (isInScale(note + distance, root, scaleType)) return note + distance
  }
  return note
}

function fitChordToScale(notes, root, scaleType) {
  var bestShift = 0
  var bestMatches = -1
  var bestDistance = 99
  for (var shift = -6; shift <= 6; shift++) {
    var matches = 0
    for (var i = 0; i < notes.length; i++)
      if (isInScale(notes[i] + shift, root, scaleType)) matches++
    var distance = Math.abs(shift)
    if (matches > bestMatches || (matches === bestMatches && distance < bestDistance)) {
      bestShift = shift
      bestMatches = matches
      bestDistance = distance
    }
  }
  var fitted = []
  for (var j = 0; j < notes.length; j++) fitted.push(notes[j] + bestShift)
  return { notes: fitted, shift: bestShift, matches: bestMatches }
}

function uniqueNotes(notes) {
  var result = []
  for (var i = 0; i < notes.length; i++)
    if (result.indexOf(notes[i]) === -1) result.push(notes[i])
  return result
}

function chordName(root, quality) {
  if (quality === "maj") return NOTE_NAMES[modulo(root, 12)]
  if (quality === "min") return NOTE_NAMES[modulo(root, 12)] + "m"
  if (quality === "dim") return NOTE_NAMES[modulo(root, 12)] + "dim"
  return NOTE_NAMES[modulo(root, 12)] + quality
}

function majorChords(root) {
  var result = []
  for (var i = 0; i < 7; i++) {
    var chordRoot = modulo(root + MAJOR_STEPS[i], 12)
    result.push({ degree: i, roman: ROMAN[i], root: chordRoot,
      quality: MAJOR_QUALITIES[i], name: chordName(chordRoot, MAJOR_QUALITIES[i]) })
  }
  return result
}

function intervalsFor(quality) {
  var intervals = {
    "maj": [0, 4, 7], "min": [0, 3, 7], "7": [0, 4, 7, 10],
    "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10], "sus2": [0, 2, 7],
    "sus4": [0, 5, 7], "dim": [0, 3, 6], "aug": [0, 4, 8], "add9": [0, 4, 7, 14],
    "maj9": [0, 4, 7, 11, 14], "min9": [0, 3, 7, 10, 14],
    "9": [0, 4, 7, 10, 14], "13": [0, 4, 7, 10, 14, 21],
    "dim7": [0, 3, 6, 9], "6": [0, 4, 7, 9],
    "min6": [0, 3, 7, 9], "5": [0, 7],
    "11": [0, 4, 7, 10, 14, 17], "min11": [0, 3, 7, 10, 14, 17],
    "7sus4": [0, 5, 7, 10], "m7b5": [0, 3, 6, 10],
    "maj7#11": [0, 4, 7, 11, 18]
  }
  return intervals[quality] || intervals.maj
}

function qualityFullName(quality) {
  var names = {
    "maj": "Major", "min": "Minor", "7": "Dominant Seventh",
    "maj7": "Major Seventh", "min7": "Minor Seventh",
    "sus2": "Suspended Second", "sus4": "Suspended Fourth",
    "dim": "Diminished", "aug": "Augmented", "add9": "Major Add Nine",
    "maj9": "Major Ninth", "min9": "Minor Ninth", "9": "Dominant Ninth",
    "11": "Dominant Eleventh", "min11": "Minor Eleventh",
    "13": "Dominant Thirteenth", "dim7": "Diminished Seventh",
    "6": "Major Sixth", "min6": "Minor Sixth", "5": "Power Fifth",
    "7sus4": "Dominant Seventh Suspended Fourth",
    "m7b5": "Minor Seventh Flat Five", "maj7#11": "Major Seventh Sharp Eleven"
  }
  return names[quality] || quality
}

function qualityDisplayName(quality) {
  var names = {
    "maj": "Major", "min": "Minor", "7": "Dom 7",
    "maj7": "Major 7", "min7": "Minor 7",
    "sus2": "Sus 2", "sus4": "Sus 4",
    "dim": "Dim", "aug": "Aug", "add9": "Add 9",
    "maj9": "Major 9", "min9": "Minor 9", "9": "Dom 9",
    "11": "Dom 11", "min11": "Minor 11", "13": "Dom 13",
    "dim7": "Dim 7", "6": "Major 6", "min6": "Minor 6",
    "5": "Power 5", "7sus4": "Dom 7 Sus 4",
    "m7b5": "Minor 7 ♭5", "maj7#11": "Major 7 ♯11"
  }
  return names[quality] || quality
}

function chordFullName(root, quality) {
  return NOTE_NAMES[modulo(root, 12)] + " " + qualityFullName(quality)
}

function chordDisplayName(root, quality) {
  return NOTE_NAMES[modulo(root, 12)] + " " + qualityDisplayName(quality)
}

function noteClassName(midi) {
  return NOTE_NAMES[modulo(midi, 12)]
}

function asciiNoteName(root) {
  var names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  return names[modulo(root, 12)]
}

function chordNotes(root, quality, octave) {
  var base = 12 * (octave + 1) + root
  var intervals = intervalsFor(quality)
  var notes = []
  for (var i = 0; i < intervals.length; i++) notes.push(base + intervals[i])
  return notes
}

function suggestedDegrees(degree) {
  var paths = [
    [3, 4, 5, 1], [4, 5, 0, 3], [5, 3, 1, 4], [4, 0, 1, 5],
    [0, 5, 3, 1], [3, 1, 4, 0], [0, 4, 2, 5]
  ]
  return paths[modulo(degree, 7)].slice()
}

function mappedMidi(text, octave) {
  var keys = "awsedftgyhuj"
  var index = keys.indexOf(String(text).toLowerCase())
  return index < 0 ? -1 : 12 * (octave + 1) + index
}
