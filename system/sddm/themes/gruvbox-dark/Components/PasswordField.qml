import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
  id: passwordField
  focus: true
  selectByMouse: true
  placeholderText: "Password"
  echoMode: TextInput.Password
  passwordCharacter: "•"
  passwordMaskDelay: config.PasswordShowLastLetter
  selectionColor: "#7c6f64"
  renderType: Text.NativeRendering
  font {
    family: config.Font
    pointSize: config.FontSize
    bold: true
  }
  color: "#d5c4a1"
  horizontalAlignment: TextInput.AlignHCenter
  background: Rectangle {
    id: passFieldBackground
    radius: 3
    color: "#3c3836"
  }
  states: [
    State {
      name: "focused"
      when: passwordField.activeFocus
      PropertyChanges {
        target: passFieldBackground
        color: "#504945"
      }
    },
    State {
      name: "hovered"
      when: passwordField.hovered
      PropertyChanges {
        target: passFieldBackground
        color: "#504945"
      }
    }
  ]
  transitions: Transition {
    PropertyAnimation {
      properties: "color"
      duration: 300
    }
  }
}
