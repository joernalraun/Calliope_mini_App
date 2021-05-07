//
//  MatrixConnectionViewController.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 14.12.18.
//

import UIKit
import CoreBluetooth

class MatrixConnectionViewController: UIViewController, CollapsingViewControllerProtocol {

    @IBOutlet weak var connectionDescriptionLabel: UILabel!
    
	public static var instance: MatrixConnectionViewController!

	/// button to toggle whether connection view is open or not
	@IBOutlet var collapseButton: ConnectionViewCollapseButton!
	var collapseButtonView: (CollapseButtonProtocol & UIView)! {
		return collapseButton
	}
    //gesture recognizer added to background when open
    lazy var collapseGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleOpen(_:)))

	/// the view which handles the collapsing
	@IBOutlet var zoomView: UIView!

	/// constraint to collapse view horizontally
	@IBOutlet var collapseWidthConstraint: NSLayoutConstraint!
	/// constraint to collapse view vertically
	@IBOutlet var collapseHeightConstraint: NSLayoutConstraint!

	/// the matrix in which to draw the calliope name pattern
	@IBOutlet var matrixView: MatrixView!

	/// button to trigger the connection with the calliope
	@IBOutlet var connectButton: ConnectionButton!

	let collapsedWidth: CGFloat = 28
	let collapsedHeight: CGFloat = 28
	let expandedWidth: CGFloat = 274
	let expandedHeight: CGFloat = 430

	private let queue = DispatchQueue(label: "bluetooth")
    
    public private(set) var calliopeTypeLastChangedBy: AnyObject?
    
    public var connectionDescriptionText: String = "1. Programm 5 starten\n2. Schütteln\n3. LED-Muster eingeben".localized {
        didSet { connectionDescriptionLabel.text = connectionDescriptionText }
    }

	public var calliopeWithCurrentMatrix: CalliopeBLEDevice? {
		return connector.discoveredCalliopes[Matrix.matrix2friendly(matrixView.matrix) ?? ""]
	}

	public var usageReadyCalliope: CalliopeBLEDevice? {
		guard let calliope = connector.connectedCalliope,
			calliope.state == .usageReady
			else { return nil }
		return calliope
	}
    
    public func changeCalliopeType(sender: AnyObject, calliopeClass: CalliopeBLEDevice.Type) {
        if let changer = calliopeTypeLastChangedBy, changer === sender {
            return
        }
        calliopeTypeLastChangedBy = sender
        let calliopeBuilder = { (_ peripheral: CBPeripheral, _ name: String) -> CalliopeBLEDevice in
            return calliopeClass.init(peripheral: peripheral, name: name)
        }
        connector = CalliopeBLEDiscovery(calliopeBuilder)
    }
    
    private var connector: CalliopeBLEDiscovery = CalliopeBLEDiscovery({ peripheral, name in
        FlashableCalliope(peripheral: peripheral, name: name) }) {
        didSet {
            self.changedConnector(oldValue)
        }
    }

	private func changedConnector(_ oldValue: CalliopeBLEDiscovery) {
        oldValue.giveUpResponsibility()
        connector.updateBlock = updateDiscoveryState
        connector.errorBlock = error
		matrixView.updateBlock = {
			//matrix has been changed manually, this always triggers a disconnect
			self.connector.disconnectFromCalliope()
			self.updateDiscoveryState()
		}
	}

	override public func viewDidLoad() {
		super.viewDidLoad()
		MatrixConnectionViewController.instance = self
		changedConnector(connector)
		connectButton.imageView?.contentMode = .scaleAspectFit
		animate(expand: false)
	}

	@IBAction func toggleOpen(_ sender: Any) {
        self.parent?.view.removeGestureRecognizer(collapseGestureRecognizer)
		toggleOpen()
	}

	func animationCompletions(expand: Bool) {
        //start or end calliope discovery
		if expand {
			if self.connector.state == .initialized {
				self.connector.startCalliopeDiscovery()
			}
		} else {
			self.connector.stopCalliopeDiscovery()
		}

        //add gesture recognizer to background for dismissal
        if expand {
            self.parent?.view.addGestureRecognizer(collapseGestureRecognizer)
        }
	}

    public func animateBounce() {
        if collapseButton.expansionState == .open {
            self.connectButton.animateBounce()
        } else {
            self.collapseButton.animateBounce()
        }
    }

	// MARK: calliope connection

	private var attemptReconnect = false
	private var reconnecting = false

	@IBAction func connect() {
		if self.connector.state == .initialized
			|| self.calliopeWithCurrentMatrix == nil && self.connector.state == .discoveredAll {
			connector.startCalliopeDiscovery()
		} else if let calliope = self.calliopeWithCurrentMatrix {
			if calliope.state == .discovered || calliope.state == .willReset {
				calliope.updateBlock = updateDiscoveryState
                calliope.errorBlock = error
				LogNotify.log("Matrix view connecting to \(calliope)")
				connector.connectToCalliope(calliope)
			} else if calliope.state == .connected {
				calliope.evaluateMode()
			} else {
				LogNotify.log("Connect button of matrix view should not be enabled in this state (\(self.connector.state), \(String(describing: self.calliopeWithCurrentMatrix?.state)))")
			}
		} else {
			LogNotify.log("Connect button of matrix view should not be enabled in this state (\(self.connector.state), \(String(describing: self.calliopeWithCurrentMatrix?.state)))")
		}
	}

	private func updateDiscoveryState() {

		switch self.connector.state {
		case .initialized:
			matrixView.isUserInteractionEnabled = true
			connectButton.connectionState = .initialized
			self.collapseButton.connectionState = .disconnected
		case .discoveryWaitingForBluetooth:
			matrixView.isUserInteractionEnabled = true
			connectButton.connectionState = .waitingForBluetooth
			self.collapseButton.connectionState = .disconnected
		case .discovering, .discovered:
			if let calliope = self.calliopeWithCurrentMatrix {
				evaluateCalliopeState(calliope)
			} else {
				matrixView.isUserInteractionEnabled = true
				connectButton.connectionState = .searching
				self.collapseButton.connectionState = .disconnected
			}
		case .discoveredAll:
			if let matchingCalliope = calliopeWithCurrentMatrix {
				evaluateCalliopeState(matchingCalliope)
			} else {
				matrixView.isUserInteractionEnabled = true
				connectButton.connectionState = .notFoundRetry
				self.collapseButton.connectionState = .disconnected
			}
		case .connecting:
			matrixView.isUserInteractionEnabled = false
			attemptReconnect = false
			reconnecting = false
			connectButton.connectionState = .connecting
			self.collapseButton.connectionState = .connecting
		case .connected:
			if let connectedCalliope = connector.connectedCalliope, calliopeWithCurrentMatrix != connector.connectedCalliope {
				//set matrix in case of auto-reconnect, where we do not have corresponding matrix yet
				matrixView.matrix = Matrix.friendly2Matrix(connectedCalliope.name)
				connectedCalliope.updateBlock = updateDiscoveryState
			}
			evaluateCalliopeState(calliopeWithCurrentMatrix!)
		}
	}

	private func evaluateCalliopeState(_ calliope: CalliopeBLEDevice) {

		if calliope.state == .wrongMode || calliope.state == .discovered {
			self.collapseButton.connectionState = attemptReconnect || reconnecting ? .connecting : .disconnected
		} else if calliope.state == .usageReady {
			self.collapseButton.connectionState = .connected
		} else {
			self.collapseButton.connectionState = .connecting
		}

		if calliope.state == .discovered && attemptReconnect {
			//start reconnection attempt
			queue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.restartDuration, execute: connect)
			reconnecting = true
			attemptReconnect = false
			return
		}

		switch calliope.state {
		case .discovered:
			matrixView.isUserInteractionEnabled = !reconnecting
			connectButton.connectionState = reconnecting ? .testingMode : .readyToConnect
		case .connected:
			reconnecting = false
			attemptReconnect = false
			matrixView.isUserInteractionEnabled = false
			connectButton.connectionState = .testingMode
		case .evaluateMode:
			matrixView.isUserInteractionEnabled = false
			connectButton.connectionState = .testingMode
		case .usageReady:
			matrixView.isUserInteractionEnabled = true
			connectButton.connectionState = .readyToPlay
		case .wrongMode:
			matrixView.isUserInteractionEnabled = true
			connectButton.connectionState = .wrongProgram
		case .willReset:
			matrixView.isUserInteractionEnabled = false
			attemptReconnect = true
			connectButton.connectionState = .testingMode
		}
	}

    private func error(_ error: Error) {
        let alertController: UIAlertController
        if (error as? CBError)?.errorCode == 14 {
            alertController = UIAlertController(title: "Remove paired device".localized, message: "This Calliope can not be connected until you go to the bluetooth settings of your device and \"ignore\" it.".localized, preferredStyle: .alert)
        } else {
            alertController = UIAlertController(title: "Error".localized, message: "Encountered an error discovering or connecting calliope:".localized + "\n\(error.localizedDescription)", preferredStyle: .alert)
        }
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        self.show(alertController, sender: nil)
    }
}
