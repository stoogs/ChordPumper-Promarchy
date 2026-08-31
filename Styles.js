.pragma library

function preset(name, shapes, chords) {
  return { name: name, shapes: shapes, chords: chords }
}

// Chord entries are [semitones from key root, quality, harmonic label].
var PRESETS = [
  preset("Pop", ["maj", "min", "7", "maj7", "min7", "sus2", "sus4", "add9"],
    [[0,"maj","I"],[7,"maj","V"],[9,"min","vi"],[5,"maj","IV"],[2,"min","ii"],[4,"min","iii"]]),
  preset("Rock", ["maj", "min", "5", "7", "sus2", "sus4", "add9", "aug"],
    [[0,"maj","I"],[10,"maj","♭VII"],[5,"maj","IV"],[7,"maj","V"],[9,"min","vi"],[3,"maj","♭III"]]),
  preset("Indie", ["maj7", "min7", "add9", "sus2", "sus4", "6", "min6", "5"],
    [[0,"maj7","I"],[5,"maj7","IV"],[9,"min7","vi"],[2,"min7","ii"],[7,"maj","V"],[4,"min7","iii"]]),
  preset("Folk", ["maj", "min", "7", "sus2", "sus4", "add9", "6", "5"],
    [[0,"maj","I"],[7,"maj","V"],[5,"maj","IV"],[9,"min","vi"],[2,"min","ii"],[10,"maj","♭VII"]]),
  preset("Country", ["maj", "min", "7", "6", "add9", "sus2", "sus4", "5"],
    [[0,"maj","I"],[5,"maj","IV"],[7,"maj","V"],[9,"min","vi"],[2,"7","II7"],[10,"maj","♭VII"]]),
  preset("Blues", ["7", "9", "13", "min7", "6", "sus4", "dim7", "5"],
    [[0,"7","I7"],[5,"7","IV7"],[7,"7","V7"],[3,"7","♭III7"],[10,"7","♭VII7"],[9,"min7","vi7"]]),
  preset("Soul", ["maj7", "min7", "7", "9", "13", "6", "min6", "dim7"],
    [[0,"maj7","I"],[9,"min7","vi"],[2,"min7","ii"],[7,"7","V"],[5,"maj7","IV"],[4,"min7","iii"]]),
  preset("Funk", ["9", "13", "7", "min7", "7sus4", "dim7", "5", "aug"],
    [[0,"9","I9"],[5,"9","IV9"],[10,"9","♭VII9"],[9,"min7","vi7"],[2,"9","II9"],[7,"9","V9"]]),
  preset("R&B", ["maj7", "min7", "maj9", "min9", "9", "13", "add9", "dim7"],
    [[0,"maj7","I"],[4,"min7","iii"],[9,"min7","vi"],[5,"maj7","IV"],[2,"min7","ii"],[7,"7","V"]]),
  preset("Disco", ["min7", "maj7", "7", "9", "13", "6", "min6", "dim7"],
    [[0,"min7","i"],[10,"maj7","♭VII"],[8,"maj7","♭VI"],[7,"7","V"],[5,"min7","iv"],[3,"maj7","♭III"]]),
  preset("House", ["min7", "maj7", "add9", "sus2", "sus4", "9", "min9", "5"],
    [[0,"min7","i"],[8,"maj7","♭VI"],[3,"maj7","♭III"],[10,"maj7","♭VII"],[5,"min7","iv"],[7,"min7","v"]]),
  preset("Techno", ["min", "maj", "5", "sus2", "sus4", "dim", "aug", "add9"],
    [[0,"min","i"],[1,"maj","♭II"],[8,"maj","♭VI"],[10,"maj","♭VII"],[5,"min","iv"],[7,"dim","v°"]]),
  preset("Ambient", ["add9", "maj7", "min7", "sus2", "sus4", "6", "min6", "5"],
    [[0,"add9","I"],[5,"maj7","IV"],[9,"min7","vi"],[7,"sus4","V"],[2,"min7","ii"],[4,"min7","iii"]]),
  preset("Dream Pop", ["maj9", "min9", "maj7", "min7", "add9", "sus2", "sus4", "6"],
    [[0,"maj9","I"],[5,"maj9","IV"],[9,"min7","vi"],[4,"min7","iii"],[2,"min7","ii"],[7,"sus2","V"]]),
  preset("Lo-fi", ["maj7", "min7", "7", "maj9", "min9", "9", "dim7", "6"],
    [[0,"maj7","I"],[9,"7","VI"],[2,"min7","ii"],[7,"7","V"],[4,"min7","iii"],[9,"min7","vi"]]),
  preset("Synthwave", ["min", "maj", "add9", "sus2", "sus4", "5", "min7", "maj7"],
    [[0,"min","i"],[8,"maj","♭VI"],[3,"maj","♭III"],[10,"maj","♭VII"],[5,"min","iv"],[7,"sus4","V"]]),
  preset("Cinematic", ["min", "maj", "add9", "sus2", "sus4", "5", "aug", "dim"],
    [[0,"min","i"],[8,"maj","♭VI"],[3,"maj","♭III"],[10,"maj","♭VII"],[5,"sus2","iv"],[7,"maj","V"]]),
  preset("Epic", ["min", "maj", "5", "sus2", "sus4", "add9", "aug", "dim"],
    [[0,"min","i"],[8,"maj","♭VI"],[10,"maj","♭VII"],[7,"maj","V"],[5,"min","iv"],[1,"maj","♭II"]]),
  preset("Jazz", ["maj7", "min7", "7", "maj9", "min9", "9", "13", "dim7"],
    [[0,"maj7","I"],[2,"min7","ii"],[7,"7","V"],[9,"min7","vi"],[4,"min7","iii"],[11,"m7b5","viiø"]]),
  preset("Neo-Soul", ["maj9", "min9", "13", "maj7#11", "min11", "9", "dim7", "6"],
    [[0,"maj9","I"],[4,"min7","iii"],[9,"min9","vi"],[2,"min9","ii"],[7,"13","V"],[5,"maj9","IV"]]),
  preset("Bossa Nova", ["maj7", "min7", "7", "6", "min6", "9", "13", "dim7"],
    [[0,"maj7","I"],[9,"7","VI"],[2,"min7","ii"],[7,"7","V"],[4,"min7","iii"],[9,"min7","vi"]]),
  preset("Gospel", ["maj7", "min7", "7", "9", "13", "6", "dim7", "sus4"],
    [[0,"maj7","I"],[5,"maj7","IV"],[2,"min7","ii"],[7,"7","V"],[9,"min7","vi"],[2,"7","II"]]),
  preset("Reggae", ["maj", "min", "7", "sus2", "sus4", "add9", "6", "5"],
    [[0,"maj","I"],[7,"maj","V"],[9,"min","vi"],[5,"maj","IV"],[10,"maj","♭VII"],[2,"min","ii"]]),
  preset("Classical", ["maj", "min", "7", "dim", "aug", "sus4", "6", "min6"],
    [[0,"maj","I"],[2,"min","ii"],[5,"maj","IV"],[7,"maj","V"],[9,"min","vi"],[11,"dim","vii°"]])
]

function all() { return PRESETS }

function at(index) {
  var normalized = ((index % PRESETS.length) + PRESETS.length) % PRESETS.length
  return PRESETS[normalized]
}

function seededValue(seed) {
  var value = Math.sin(seed * 12.9898 + 78.233) * 43758.5453
  return value - Math.floor(value)
}

function paletteSource(index, variation, seed) {
  var presetValue = at(index)
  var source = presetValue.chords
  var expanded = source.slice()
  var extraRoots = [0, 3, 1, 4]
  for (var extra = 0; extra < extraRoots.length; extra++) {
    var baseChord = source[extraRoots[extra]]
    expanded.push([baseChord[0], presetValue.shapes[(extra + 2) % presetValue.shapes.length], baseChord[2]])
  }
  if (variation === "core" || !variation) return expanded

  var order = variation === "alt" ? [0, 3, 1, 4, 2, 5, 6, 8, 7, 9] : [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  if (variation === "shuffle") {
    for (var position = order.length - 1; position > 0; position--) {
      var swapWith = Math.floor(seededValue(seed + position * 17) * (position + 1))
      var held = order[position]
      order[position] = order[swapWith]
      order[swapWith] = held
    }
  }
  var result = []
  for (var i = 0; i < 10; i++) {
    var sourceIndex = order[i]
    var chord = expanded[sourceIndex]
    var quality = chord[1]
    if (variation === "colour") quality = presetValue.shapes[(i + 2) % presetValue.shapes.length]
    if (variation === "shuffle" && seededValue(seed + i * 31) > 0.38)
      quality = presetValue.shapes[Math.floor(seededValue(seed + i * 47) * presetValue.shapes.length)]
    result.push([chord[0], quality, chord[2]])
  }
  return result
}

function chordsFor(index, keyRoot, variation, seed) {
  var source = paletteSource(index, variation || "core", seed || 1)
  var result = []
  for (var i = 0; i < source.length; i++) {
    result.push({ root: ((keyRoot + source[i][0]) % 12 + 12) % 12,
      quality: source[i][1], roman: source[i][2] })
  }
  return result
}
