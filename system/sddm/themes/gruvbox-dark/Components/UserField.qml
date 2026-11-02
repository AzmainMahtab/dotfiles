import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
  id: userField
  height: inputHeight
  width: inputWidth
  selectByMouse: true
  echoMode: TextInput.Normal
  selectionColor: "#7c6f64"
  renderType: Text.NativeRendering
  font {
    family: config.Font
    pointSize: config.FontSize
    bold: true
  }
  color: "#d5c4a1"
  horizontalAlignment: Text.AlignHCenter
  placeholderText: "Username"
  text: userModel.lastUser
  background: Rectangle {
    id: userFieldBackground
    color: "#3c3836"
    radius: 3
  }
  states: [
    State {
      name: "focused"
      when: userField.activeFocus
      PropertyChanges {
        target: userFieldBackground
        color: "#504945"
      }
    },
    State {
      name: "hovered"
      when: userField.hovered
      PropertyChanges {
        target: userFieldBackground
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
