//
//  MetalView.swift
//  Craigs Engine
//
//  Created by Craig Nunemaker on 6/11/22.
//

import MetalKit
import SwiftUI

#if os(iOS) || os(watchOS) || os(tvOS)
typealias Representable = UIViewRepresentable
#else
typealias Representable = NSViewRepresentable
#endif

/// MetalView is a platform agnostic representation of an MTKView
public struct MetalView: Representable {
	private var clearColor: MTLClearColor?
	private var colorPixelFormat: MTLPixelFormat?
	private var depthPixelFormat: MTLPixelFormat?
	private var device: MTLDevice?
	private var commandQueue: MTLCommandQueue?
	/// Set the isPaused and enableSetNeedsDisplay on the MTKView based on how we want to draw
	public enum drawingModeType{
		/// We expect the drawing loop to get called on each refresh.
		/// Will set both isPaused and enableSetNeedsDisplay to false
		case Timed
		/// Will set both isPaused and enableSetNeedsDisplay to true
		case Notifications
		/// We will explicitiely force the screen to draw.
		/// Will set isPaused to true and enableSetNeedsDisplay to false
		case Explicit
	}
	public typealias DrawCallFunction = ((MTKView, MTLCommandQueue, CGSize) -> Void)
	private var drawingMode: drawingModeType
	private var onDrawCallback: DrawCallFunction? = nil
//	private var onKeyboardCallback: (())
//	public init(device: MTLDevice? = nil, drawingMode: drawingModeType = .Timed){
//		if let _ = device {
//			self.device = MTLCreateSystemDefaultDevice()
//		} else {
//			self.device = device
//		}
//		self.drawingMode = drawingMode
//	}
//
/// Creates a new MetalView.
/// '''
/// MetalView(drawingMode: .Timed, clearColor: MTLClearColorMake(1.0, 0.3, 0.5, 0.0))
/// '''
/// - Parameters:
///   - device: The Metal Device being used. If your app/game needs to keep up with the device then
///   you should explicitly create device and provide the reference to it here. nil is default.
///   If nil then the init will create a system defaultl device
///   - drawingMode: The drawing mode we want to use. Based on the inputs it will set the appropriate
///   values for isPaused and enableSetNeedsDisplay. The default is .Timed which sets both to false. In
///   this case the draw loop will be called once per screen refresh.
///   - clearColor: The MTLClearColor to use. The default isi nil. Use MTLClearColorMake to
///   generate a color.
///   - colorPixelFormat: The MTLPixelFormat to use for the colorPixelFormat. The default is nil.
///   If nil, then no value is set and the view will use system defaults.
///   - depthPixelFormat: The MTLPixelFormat to use for the depthPixelFormat. The default is nil.
///   If nil, then no value is set and the view will use system defaults.
	public init(device: MTLDevice? = nil,
				drawingMode: drawingModeType = .Timed,
				clearColor: MTLClearColor? = nil,
				colorPixelFormat: MTLPixelFormat? = nil,
				depthPixelFormat: MTLPixelFormat? = nil){
		if let _ = clearColor {
			self.clearColor = clearColor!
		}
		if let _ = colorPixelFormat {
			self.colorPixelFormat = colorPixelFormat

		}
		if let _ = depthPixelFormat {
			self.depthPixelFormat = depthPixelFormat
		}
		if let _ = device {
			self.device = device
		} else {
			self.device = MTLCreateSystemDefaultDevice()

		}
		self.drawingMode = drawingMode
		if let cQ = self.device?.makeCommandQueue(){
			self.commandQueue = cQ
		} else {
			fatalError("Could noto init commmand queue")
		}
	}
	private func setDrawingMode(for view: MTKView) -> MTKView{
		let result = view
		switch drawingMode {
			case .Timed:
				result.isPaused = false
				result.enableSetNeedsDisplay = false
			case .Notifications:
				result.isPaused = true
				result.enableSetNeedsDisplay = true
			case .Explicit:
				result.isPaused = true
				result.enableSetNeedsDisplay = false
		}
		return result
	}
	private func makeMTKView(context: Context) -> MTKView {
		let mtkView = setDrawingMode(for: MTKView())
		if let _ = device {
			mtkView.device = device
		}
		if let _ = self.clearColor {
			mtkView.clearColor = clearColor!
		}
		if let _ = self.colorPixelFormat {
			mtkView.colorPixelFormat = colorPixelFormat!
		}
		if let _ = self.depthPixelFormat {
			mtkView.depthStencilPixelFormat = depthPixelFormat!
		}
		mtkView.delegate = context.coordinator
		return mtkView
	}
#if os(iOS) || os(watchOS) || os(tvOS)
	public func makeUIView(context: Context) -> MTKView {
		return makeMTKView(context: context)
	}
	public func updateUIView(_ uiView: MTKView, context: Context) {

	}
	#else
	public func makeNSView(context: Context) -> MTKView {
		return makeMTKView(context: context)
	}
	public func updateNSView(_ uiView: MTKView, context: Context) {

	}
	#endif
/**
 This function can be used to declaratively set the onDraw Function. onDraw will be the main render
 loop in the app/game.

 ```swift
	.onDraw(){view, command, frameSize in
			if let drawable = view.currentDrawable,
				let commandBuffer = command.makeCommandBuffer(),
				let renderPassDesciptor =  view.currentRenderPassDescriptor,
				let renderCommandEncoder =
				  commandBuffer.makeRenderCommandEncoder
						(descriptor: renderPassDesciptor){
					renderCommandEncoder.endEncoding()
					commandBuffer.present(drawable)
					commandBuffer.commit()
		}
 ```
 - Parameter action: This is a function that takes three parameters described in ``DrawCallFunction
 	1) An MTKView allows your render pass to get the currentDrawable and the
 	  currentRenderPassDescriptor
  	2) The stored command buffer allows your render pass to get a renderCommandEncoder
  	3) The framesize is the size of the view and your render pass can use it however.
 - Returns: a View
 */
	public func onDraw( perform action: DrawCallFunction? = nil) -> some View {
		var result = self
		if let _ = action {
			result.onDrawCallback = action!
		}
		return result
	}
	public func makeCoordinator() -> MetalView.Coordinator {
		Coordinator(self)
	}
	public class Coordinator: NSObject, MTKViewDelegate{
		var parent: MetalView
		var size: CGSize?

		init(_ parent: MetalView){
			self.parent = parent
		}
		public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
			self.size = size
		}

		/// This delegate function will call the parents drawFunction if it exists. This is part of the
		///  render cycle.
		/// - Parameter view: The view we are drawing in.
		public func draw(in view: MTKView) {
			if let onDrawCallback = parent.onDrawCallback,
			   let frameSize = size,
			   let command = parent.commandQueue {
				onDrawCallback(view, command, frameSize)
			}
		}
	}
}


