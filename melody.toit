import gpio.pwm show Pwm
import gpio show Pin

OCTAVES ::= {
  "c1": 32, "d1": 36, "e1": 41, "f1": 43, "g1": 48, "a1": 55, "b1": 61,
  "c2": 65, "d2": 73, "e2": 82, "f2": 87, "g2": 97, "a2": 110, "b2": 123,
  "c3": 130, "d3": 146, "e3": 164, "f3": 174, "g3": 196, "a3": 220, "b3": 246,
  "c4": 261, "d4": 293, "e4": 329, "f4": 349, "g4": 392, "a4": 440, "b4": 493,
  "c5": 523, "d5": 587, "e5": 659, "f5": 698, "g5": 783, "a5": 880, "b5": 987,
  "c6": 1046, "d6": 1174, "e6": 1318, "f6": 1396, "g6": 1568, "a6": 1760, "b6": 1979,
  "c7": 2093, "d7": 2349, "e7": 2637, "f7": 2793, "g7": 3136, "a7": 3520, "b7": 3951,
  "C1": 34, "D1": 38, "F1": 46, "G1": 51, "A1": 58,
  "C2": 69, "D2": 77, "F2": 92, "G2": 103, "A2": 116,
  "C3": 138, "D3": 155, "F3": 185, "G3": 207, "A3": 233,
  "C4": 227, "D4": 311, "F4": 369, "G4": 415, "A4": 466,
  "C5": 554, "D5": 622, "F5": 739, "G5": 830, "A5": 932,
  "C6": 1108, "D6": 1244, "F6": 1480, "G6": 1661, "A6": 1864,
  "C7": 2217, "D7": 2489, "F7": 2960, "G7": 3322, "A7": 3729
}

class Melody:

  melody_pin := ?

  constructor pin/Pin:
    melody_pin = pin

  play melody/string tempo/int = 100:
    note := ""
    // print "melody.size $melody.size"
    // print "first letter $melody[0]"
    for i := 0; i < melody.size; i+=2:
      note = melody[i..i+2]
      if note.starts_with "-":
        pause := noteLengthToMs 0.25 tempo
        print "pause $pause ms"
        sleep --ms=pause
        continue

      print "Note to play: $note"
      freq := OCTAVES[note]
      playNote freq tempo
  
  noteLengthToMs noteLength/float tempo/int -> int:
    notesPerSecond := tempo / 60.0
    wholeNoteMs := 1000 / notesPerSecond
    return (wholeNoteMs * noteLength).to_int

  playNote freq/int length/int:
    melody_pwm := Pwm --frequency=freq
    melody_channel := melody_pwm.start melody_pin
    melody_channel.set_duty_factor 0.5
    sleep --ms=length
    melody_pwm.close