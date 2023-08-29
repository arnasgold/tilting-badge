//
//  ContentView.swift
//  BadgeTest
//
//  Created by Arnas on 25/08/2023.
//

import SwiftUI
import UIKit

class SharedViewModel: ObservableObject {
    @Published var rotationAngle: Double = 0.0
    @Published var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 0, 1)
    
    @Published var offsetX: CGFloat = 0
    @Published var offsetY: CGFloat = 0
    
    @Published var offsetBadge: CGFloat = 0
    
    @Published var perspective: CGFloat = 0
    
    @Published var startPoint = UnitPoint(x: 0, y: 1)
    @Published var endPoint = UnitPoint(x: 0.1, y: 0.9)
    
    @Published var shadowRadius: CGFloat = 20
    @Published var shadowX: CGFloat = 0
    @Published var shadowY: CGFloat = 20
    
    @Published var didTriggerHaptic = false
    @Published var didPassThreshold = false
}

struct AnimatableGradient: AnimatableModifier {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var gradient: Gradient

    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(startPoint.animatableData, endPoint.animatableData) }
        set { startPoint.animatableData = newValue.first; endPoint.animatableData = newValue.second }
    }

    func body(content: Content) -> some View {
        content.overlay(LinearGradient(gradient: gradient, startPoint: UnitPoint(x: startPoint.x, y: startPoint.y), endPoint: UnitPoint(x: endPoint.x, y: endPoint.y)))
    }
}

extension View {
    func animatableGradient(startPoint: CGPoint, endPoint: CGPoint, colors: [Color]) -> some View {
        self.modifier(AnimatableGradient(startPoint: startPoint, endPoint: endPoint, gradient: Gradient(colors: colors)))
    }
}

struct TiltImageView: View {
    @ObservedObject var viewModel: SharedViewModel
    
    let badgeGradient = LinearGradient(gradient: Gradient(colors: [Color.gray, Color.white, Color.gray]), startPoint: .bottomLeading, endPoint: .topTrailing)
    
    var body: some View {
        
        let threshold: CGFloat = 100.0 // 100 points from the center
        let startPoint = CGPoint(x: viewModel.startPoint.x * 2, y: viewModel.startPoint.y * 2)
        let endPoint = CGPoint(x: viewModel.endPoint.x * 2, y: viewModel.endPoint.y * 2)
        
        ZStack {
            Circle()
                .fill(badgeGradient)
                .frame(width: 300, height: 300)
                .rotation3DEffect(
                    .degrees(viewModel.rotationAngle),
                    axis: viewModel.rotationAxis,
                    perspective: viewModel.perspective
                )
                .offset(x: viewModel.offsetX, y: viewModel.offsetY)
                .shadow(color: .gray,
                        radius: viewModel.shadowRadius,
                        x: viewModel.shadowX,
                        y: viewModel.shadowY)
            
            Image("badge")
                .resizable()
                .frame(width: 280, height: 280)
                .cornerRadius(150)
                .blur(radius: 10)
                .blendMode(.hardLight)
                .offset(x: viewModel.offsetX, y: viewModel.offsetY)
                .rotation3DEffect(
                    .degrees(viewModel.rotationAngle),
                    axis: viewModel.rotationAxis,
                    perspective: viewModel.perspective
                )
            
            Image("badge")
                .resizable()
                .frame(width: 300, height: 300)
                .overlay(
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 800, height: 800)
                        .animatableGradient(startPoint: startPoint, endPoint: endPoint, colors: [Color.white.opacity(0), Color.white.opacity(0.6), Color.white.opacity(0)])
                        .blur(radius: 6)
                )
                .cornerRadius(150)
                .rotation3DEffect(
                    .degrees(viewModel.rotationAngle),
                    axis: viewModel.rotationAxis,
                    perspective: viewModel.perspective
                )

        }
        .offset(x: 0, y: viewModel.offsetBadge)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    withAnimation(.easeOut(duration: 0.5)) {
                        let halfSize = CGSize(width: 150, height: 150)
                        
                        let maxUpwardDrag: CGFloat = -150
                        let dragFromCenterX = value.location.x - halfSize.width
                        let dragFromCenterY = max(value.location.y - halfSize.height, maxUpwardDrag)
                        let upwardDrag = max(-100, -dragFromCenterY) / halfSize.height
                        
                        // Calculate the rotation angle based on drag distance from the center
                        let distance = sqrt(dragFromCenterX*dragFromCenterX + dragFromCenterY*dragFromCenterY)
                        
                        // Enables drag down if threshold is passed and can be dragged back up freely to the original position
                        // Can be removed when used as a preview (outside of the claim flow)
                        if dragFromCenterY > threshold {
                            viewModel.offsetBadge = dragFromCenterY
                            viewModel.didPassThreshold = true
                            
                            if !viewModel.didTriggerHaptic {
                                let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
                                feedbackGenerator.prepare()
                                feedbackGenerator.impactOccurred()
                                viewModel.didTriggerHaptic = true
                            }
                        } else if viewModel.didPassThreshold == true {
                            viewModel.offsetBadge = max(dragFromCenterY, 0)
                        } else {
                            viewModel.didTriggerHaptic = false
                        }

                        viewModel.rotationAngle = min(Double(distance) * 0.15, 25)
                        
                        // Calculate the rotation axis based on drag direction
                        viewModel.rotationAxis = (-dragFromCenterY, dragFromCenterX, 0)
                        
                        // Calculate the backface offset (depth) based on drag direction
                        // You can adjust the multiplier to get the desired translation effect
                        viewModel.offsetX = max(min(-dragFromCenterX * 0.05, 10), -10)
                        viewModel.offsetY = max(min(-dragFromCenterY * 0.05, 10), -10)
                        
                        viewModel.startPoint = UnitPoint(x: 0.8 * upwardDrag, y: 1 - 0.8 * upwardDrag)
                        viewModel.endPoint = UnitPoint(x: 0.2 + 0.8 * upwardDrag, y: 0.8 - 0.8 * upwardDrag)

                        // Compute shadow properties based on drag direction and distance
                        let shadowRadius = 20 + distance / 30
                        let shadowX = (1 - dragFromCenterX / 20)
                        let shadowY = max(1 - dragFromCenterY / 3, 25)
                        
                        // Update shadow properties in the viewModel
                        viewModel.shadowRadius = min(shadowRadius, 25)
                        viewModel.shadowX = shadowX
                        viewModel.shadowY = min(shadowY, 60)
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.4)) {
                        viewModel.rotationAngle = 0
                        viewModel.offsetX = 0
                        viewModel.offsetY = 0
                        viewModel.startPoint = UnitPoint(x: 0, y: 1)
                        viewModel.endPoint = UnitPoint(x: 0.1, y: 0.9)
                        viewModel.shadowRadius = 20
                        viewModel.shadowX = 0
                        viewModel.shadowY = 20
                        viewModel.offsetBadge = 0
                        viewModel.didPassThreshold = false
                    }
                }
        )
    }
}

struct TiltImageView_Previews: PreviewProvider {
    
    static var previews: some View {
        let viewModel = SharedViewModel()
        
        ZStack {
            TiltImageView(viewModel: viewModel)
        }
    }
}

