//
//  ContentView.swift
//  PDSupply Solo
//
//  Created by Zain Ahmed on 4/25/20.
//  Copyright © 2020 Captio Labs. All rights reserved.
//

import SwiftUI
import Combine
import SwiftUICharts

struct ContentView: View {
    
    @ObservedObject var powerSupply = BluetoothController()
    
    // Sliders
    @State var voltageSlider: Float = 0
    @State var currentSlider: Float = 0
    
    
    // Bindings to call send data over bluetooth upon value changes
    // Dispatchqueue is used to limit the number of bluetooth packets sent
    var voltageBinding: Binding<Float> {
        Binding<Float>(
            get: { self.voltageSlider },
            set: { newValue in
                self.voltageSlider = newValue
                DispatchQueue.main.throttle(deadline: DispatchTime.now() + 0.05) {
                    self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_KEEP_STATE, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
                
        }
        )
    }
    
    var currentBinding: Binding<Float> {
        Binding<Float>(
            get: { self.currentSlider },
            set: { newValue in
                self.currentSlider = newValue
                DispatchQueue.main.throttle(deadline: DispatchTime.now() + 0.05) {
                    self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_KEEP_STATE, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
        }
        )
    }
    
    var body: some View {
        NavigationView {
            
            VStack {
                
                // If device is an iPad, the detail view is shown automatically.
                if !(UIDevice.current.userInterfaceIdiom == .pad) {
                    NavigationLink(destination: chartView) {
                        Text("Live Graph")
                    }
                    Spacer()
                }
                
                voltageView
                
                Spacer()
                
                currentView
                
                Spacer()
                
                outputButton
                
            }
            
            chartView
            
        }
    }
    
    
    
    var chartView: some View {
        VStack {
            LineView(data: powerSupply.voltageDataShort, title: "Voltage", legend: "Volts").padding([.horizontal]).padding([.bottom], 80)
            LineView(data: powerSupply.currentDataShort, title: "Current", legend: "mA").padding([.horizontal])
        }.padding([.bottom], 60)
            .navigationBarTitle(powerSupply.connected ? "Connected" : "Disconnected", displayMode: .large)
    }
    
    var voltageView: some View {
        VStack {
            Text("Voltage: \(voltageSlider, specifier: "%.2f")V")
            Slider(value: voltageBinding, in: 0...12.0, step: 0.1).padding([.horizontal], 40)
            
            HStack {
                Text("Live: \(voltageSlider, specifier: "%.3f")V")
                Stepper("", value: voltageBinding, in: 0...12.0, step: 0.1)
            }.padding([.horizontal], 40)
            
        }
    }
    
    var currentView: some View {
        VStack {
            Text("Current Limit: \(currentSlider, specifier: "%.2f")mA")
            Slider(value: currentBinding, in: 0...1000.0, step: 10.0).padding([.horizontal], 40)
            
            HStack {
                Text("Live: \(currentSlider, specifier: "%.3f")mA")
                Stepper("", value: currentBinding, in: 0...1000.0, step: 10.0)
            }.padding([.horizontal], 40)
            
        }
    }
    
    var outputButton: some View {
        
        VStack {
            if self.powerSupply.statusData == self.powerSupply.PD_STATUS_OUTPUT_GOOD {
                Text("Output Enabled")
                    .onTapGesture {
                        self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_OFF, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
                .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 1000) {
                    self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_ON, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .font(.title)
            } else if self.powerSupply.statusData == self.powerSupply.PD_STATUS_OUTPUT_OFF {
                Text("Output Off")
                    .onTapGesture {
                        self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_OFF, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
                .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 1000) {
                    self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_ON, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
                .padding()
                .background(Color.yellow)
                .foregroundColor(.white)
                .font(.title)
            } else {
                Text("Over Current")
                    .onTapGesture {
                        self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_OFF, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
                .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 1000) {
                    self.powerSupply.commandSupply(commandedStatus: self.powerSupply.PD_COMMAND_OUTPUT_ON, commandedOutput: 0, commandedVoltage: self.voltageSlider, commandedCurrent: self.currentSlider)
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .font(.title)
            }
        }
    }
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
