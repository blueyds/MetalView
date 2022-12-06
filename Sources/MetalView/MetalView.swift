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
	private var framesPerSecond: Int?
	private var device: MTLDevice?
	private var commandQueue: MTLCommandQueue? = nil
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
	/// typealias for the main draw callback function used by the view. The function used will be the 
	/// main loop
	public typealias DrawCallFunction = ((MTKView) -> Void)
	private var drawingMode: drawingModeType
	private var onDrawCallback: DrawCallFunction? = nil
	private var onRenderCallback: ((MTLRenderCommandEncoder)-> Void)? = nil
	private var onSizeChangeCallback: ((CGSize) -> Void)? = nil
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
				depthPixelFormat: MTLPixelFormat? = nil,
				framesPerSecond: Int? = nil){
		self.clearColor = clearColor!
		self.colorPixelFormat = colorPixelFormat
		self.depthPixelFormat = depthPixelFormat
		
		if let _ = device {
			self.device = device
		} else {
			self.device = MTLCreateSystemDefaultDevice()

		}
		self.drawingMode = drawingMode
		self.framesPerSecond = framesPerSecond
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
		if let _ = self.framesPerSecond {
			mtkView.preferredFramesPerSecond = self.framesPerSecond!
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
 loop in the app/game. You have to create the commandBuffer in your app.

 ```swift
	.onDraw(){view in
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
 - Parameter action: This is a function that takes one parameters described in ``DrawCallFunction
 	1) An MTKView allows your render pass to get the currentDrawable and the
 	  currentRenderPassDescriptor
 - Returns: a View
 */
	public func onDraw( perform action: DrawCallFunction? = nil) -> MetalView {
		var result = self
		if let _ = action {
			result.onDrawCallback = action!
		}
		return result
	}

	/// This function will present a simpler solutioni to the end user. The view will manage the device
	/// and the command queue. It iwill generate the Render command encoder and send that
	/// to the call back function
	/// - Parameter action: Function that takes a MTLRenderCommandEncoder in
	/// - Returns: some view so iti can be used declaratively in SwiftUI
	public func onRender(render action: ((MTLRenderCommandEncoder) -> Void)? = nil) -> MetalView {
		var result = self
		if let _ = result.onDrawCallback {
			result.onDrawCallback = nil
		}
		result.commandQueue = result.device?.makeCommandQueue()
		result.onRenderCallback = action
		return result
	}
	public func onSizeChange(_ callBack: @escaping ((CGSize)->Void))-> MetalView{
		var result = self
		result.onSizeChangeCallback = callBack
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
		public func mtkView(_ view: MTKView, drawableSizeWillChange newSize: CGSize) {
			self.size = newSize
			if let onSizeChangeCB = parent.onSizeChangeCallback {
				onSizeChangeCB(newSize)
			}
		}

		/// This delegate function will call the parents drawFunction if it exists. This is part of the
		///  render cycle.
		/// - Parameter view: The view we are drawing in.
		public func draw(in view: MTKView) {
			if let onDrawCallback = parent.onDrawCallback {
				onDrawCallback( view )
			} else if let onRenderCallback = parent.onRenderCallback {
				if let drawable = view.currentDrawable,
				   let commandBuffer = parent.commandQueue?.makeCommandBuffer(),
				   let renderPassDesciptor =  view.currentRenderPassDescriptor,
				   let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesciptor){
					onRenderCallback(renderCommandEncoder)
					renderCommandEncoder.endEncoding()
					commandBuffer.present(drawable)
					commandBuffer.commit()
				}
			}
		}
	}
}


