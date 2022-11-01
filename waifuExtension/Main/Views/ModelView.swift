//
//  ModelView.swift
//  waifuExtension
//
//  Created by Vaida on 5/4/22.
//

import SwiftUI
import Support


struct Waifu2xModelView: View {
    
    let containVideo: Bool
    
    private let styleNames: [String] = ["anime", "photo"]
    private let noiseLevels: [String] = ["none", "0", "1", "2", "3"]
    
    @State private var chosenNoiseLevel = "3"
    
    @State private var scaleLevels: [Int] = [1, 2, 4, 8]
    
    @State private var modelClass: [String] = []
    @State private var chosenModelClass: String = ""
    
    @EnvironmentObject private var dataProvider: ModelDataProvider
    @EnvironmentObject private var model: ModelCoordinator
    
    @AppStorage("Waifu2x Model Style") private var modelStyle = "anime"
    
    func findModelClass() {
        self.modelClass = Model_Caffe.allModels.filter{ ($0.style == modelStyle ) && ($0.noise == Int(chosenNoiseLevel)) && ($0.scale == ( model.scaleLevel == 1 ? 1 : 2 )) }.map(\.class).removingDuplicates()
        guard let value = modelClass.first else {
            modelStyle = "anime"
            return
        }
        self.chosenModelClass = value
    }
    
    var body: some View {
        VStack {
            DoubleView("Style:", selection: $modelStyle, options: styleNames)
                .help("anime: for illustrations or 2D images or CG\nphoto: for photos of real world or 3D images")
            DoubleView("Scale Level:", selection: $model.scaleLevel, options: scaleLevels)
                .help("Choose how much you want to scale.")
            DoubleView("Denoise Level:", selection: $chosenNoiseLevel, options: noiseLevels)
                .help("denoise level 3 recommended.")
        }
        .onAppear {
            findModelClass()
            self.scaleLevels = !containVideo ? [1, 2, 4, 8] : [1, 2]
            if self.containVideo && model.scaleLevel > 2 {
                model.scaleLevel = 2
            }
        }
        .onChange(of: chosenNoiseLevel) { _ in
            findModelClass()
        }
        .onChange(of: model.scaleLevel) { newValue in
            findModelClass()
            if newValue == 8 {
                model.enableConcurrent = false
            } else {
                model.enableConcurrent = true
            }
            model.scaleLevel = newValue
        }
        .onChange(of: chosenModelClass) { newValue in
            model.caffe = Model_Caffe.allModels.filter({ ($0.style == modelStyle) && ($0.noise == Int(chosenNoiseLevel)) && ($0.scale == ( model.scaleLevel == 1 ? 1 : 2 )) }).first!
        }
        .onChange(of: dataProvider.container) { _ in
            findModelClass()
        }
    }
}


struct ChooseModelOptionView<T>: View where T: CustomStringConvertible & Hashable {
    
    private let title: LocalizedStringKey
    
    @Binding var selection: T
    
    private let options: [T]
    
    init(_ title: LocalizedStringKey, selection: Binding<T>, options: [T]) {
        self.title = title
        self._selection = selection
        self.options = options
    }
    
    var body: some View {
        HStack {
            HStack {
                Spacer()
                
                Text(title)
            }
            .frame(width: 150, alignment: .trailing)
            .padding(.horizontal)
            
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) {
                    Text(LocalizedStringKey($0.description))
                }
            }
            .disabled(options.count == 1)
        }
        .help(options.count == 1 ? "This option is not customizable for this model." : "")
            
    }
    
}


struct SpecificationsView: View {
    
    let containVideo: Bool
    @Binding var isProcessing: Bool
    
    @ObservedObject var images: MainModel
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataProvider: ModelDataProvider
    @EnvironmentObject private var model: ModelCoordinator
    
    private var frameModelNotInstalled: Bool {
        if let model = model.chosenFrameModel {
            return !model.programItem.isExistence
        } else {
            return false
        }
    }
    private var anyFrameModelNotInstalled: Bool {
        ModelCoordinator.allInstalledFrameModels.allSatisfy { !$0.programItem.isExistence }
    }
    
    var body: some View {
        
        VStack {
            VStack {
                DoubleView("Image Model:") {
                    Picker("", selection: $model.imageModel) {
                        ForEach(_ModelCoordinator.ImageModel.allCases, id: \.self) { value in
                            Text(value.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.bottom, 10)
                
                VStack {
                    if model.imageModel == .caffe {
                        Waifu2xModelView(containVideo: containVideo)
                    } else if model.imageModel == .realcugan {
                        ChooseModelOptionView("Model Name:",    selection: $model.realcugan.modelName,    options: model.realcugan.modelNameOptions)
                        ChooseModelOptionView("Scale Level:",   selection: $model.realcugan.scaleLevel,   options: model.realcugan.scaleLevelOptions)
                        ChooseModelOptionView("Denoise Level:", selection: $model.realcugan.denoiseLevel, options: model.realcugan.denoiseLevelOption)
                    } else if model.imageModel == .realesrgan {
                        ChooseModelOptionView("Model Name:",    selection: $model.realesrgan.modelName,    options: model.realesrgan.modelNameOptions)
                        ChooseModelOptionView("Scale Level:",   selection: $model.realesrgan.scaleLevel,   options: model.realesrgan.scaleLevelOptions)
                        ChooseModelOptionView("Denoise Level:", selection: $model.realesrgan.denoiseLevel, options: model.realesrgan.denoiseLevelOption)
                    } else if model.imageModel == .realsr {
                        ChooseModelOptionView("Model Name:",    selection: $model.realsr.modelName,    options: model.realsr.modelNameOptions)
                        ChooseModelOptionView("Scale Level:",   selection: $model.realsr.scaleLevel,   options: model.realsr.scaleLevelOptions)
                        ChooseModelOptionView("Denoise Level:", selection: $model.realsr.denoiseLevel, options: model.realsr.denoiseLevelOption)
                    }
                }
                
                if self.containVideo {
                    Divider()
                        .padding(.top)
                    
                    HStack {
                        DoubleView {
                            Toggle(isOn: $model.enableFrameInterpolation) { }
                        } rhs: {
                            Text("")
                            Text("Enable video frame interpolation")
                                .onTapGesture {
                                    model.enableFrameInterpolation.toggle()
                                }
                        }
                        
                        Spacer()
                    }
                    .disabled(anyFrameModelNotInstalled)
                    .foregroundColor(anyFrameModelNotInstalled ? .secondary : .primary)
                    .onAppear {
                        if !anyFrameModelNotInstalled {
                            model.enableFrameInterpolation = false
                        }
                    }
                    .help {
                        if anyFrameModelNotInstalled {
                            return "Please install models in Preferences"
                        } else {
                            return "Enable video frame interpolation"
                        }
                    }
                    
                    if model.enableFrameInterpolation {
                        DoubleView("Interpolation Model:") {
                            Picker("", selection: $model.frameModel) {
                                ForEach(_ModelCoordinator.FrameModel.allCases, id: \.self) { value in
                                    Text(value.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Group {
                            DoubleView("Frame Interpolation:", selection: $model.frameInterpolation, options: [2, 4])
                                .help("Choose how many times more frames you want the video be.")
                            
                            if model.frameModel == .rife {
                                VStack {
                                    DoubleView("Model Name:", selection: $model.rife.modelName, options: model.rife.modelNameOptions)
                                    DoubleView("Enable UHD:", selection: $model.rife.enableUHD, options: [true, false])
                                }
                            }
                        }
                        .disabled(frameModelNotInstalled)
                        .foregroundColor(frameModelNotInstalled ? .secondary : .primary)
                        .help {
                            if frameModelNotInstalled {
                                return "Please install models in Preferences"
                            } else {
                                return ""
                            }
                        }
                    }
                }
            }
            
            Spacer()

            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(width: 80)
                }
                .padding(.trailing)
                .keyboardShortcut(.cancelAction)
                .help("Return to previous page.")

                Button {
                    isProcessing = true
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(width: 80)
                }
                .keyboardShortcut(.defaultAction)
                .help("Begin processing.")
                .disabled(model.enableFrameInterpolation && frameModelNotInstalled)
            }
        }
        .padding()
        .onChange(of: model.enableFrameInterpolation) { newValue in
            if newValue {
                model.frameInterpolation = 2
            } else {
                model.frameInterpolation = 1
            }
        }
        .frame(height: {() -> CGFloat in
            var height: CGFloat = 200
            
            guard self.containVideo else { return height }
            if !model.enableFrameInterpolation {
                height += 40
            } else {
                if model.frameModel == .rife {
                    height += 170
                } else {
                    height += 110
                }
            }
            
            return height
        }())
    }
    
}
