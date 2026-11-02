import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
  implicitHeight: powerButton.height
  implicitWidth: powerButton.width
  Button {
    id: powerButton
    height: inputHeight
    width: inputHeight
    hoverEnabled: true
    icon {
      source: Qt.resolvedUrl("../icons/power.svg")
      height: height
      width: width
      color: "#1d2021"
    }
    background: Rectangle {
      id: powerButtonBackground
      radius: 3
      color: "#e2594b"
    }
    states: [
      State {
        name: "hovered"
        when: powerButton.hovered
        PropertyChanges {
          target: powerButtonBackground
          color: "#bdae93"
        }
      }
    ]
    transitions: Transition {
      PropertyAnimation {
        properties: "color"
        duration: 300
      }
    }
    onClicked: sddm.powerOff()
  }
}
