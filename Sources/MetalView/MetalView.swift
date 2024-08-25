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

	
	/// typealias for the main draw callback function used by the view. The function used will be the 
	/// main loop
	public typealias DrawCallFunction = ((MTKView) -> Void)
	private var onMainLoopCallback: DrawCallFunction? = nil
	private var onRenderCallback: ((MTLRenderCommandEncoder)-> Void)? = nil
	private var onSizeChangeCallback: ((Float, Float) -> Void)? = nil
	private var onUpdateCallback: (() -> Void)? = nil


/// Creates a new MetalView.
///
/// The following code creates a `MetalView` inside a `View` body with a drawing Mode and a clear Color.
/// The Drawing mode is set to `.Timed` which will call the render function once per screen refresh.
/// The Clear color is set  to be  Red.
///
///```swift
///var body: some View{
///   MetalView(
///      clearColor: MTLClearColorMake(1.0, 0.0, 0.0, 0.0) )
///}
///```
///### Behind the scenes
///The MetalView initializes an `MTKView` and presents it as either a `UIViewRepresentable` or
///an `NSViewRepresentable` depending on the OS build.
///
///IF no ``onRender(render:)`` or ``onMainLoop(callBackFunction:)`` is specified
///then the MetalView will create a simple ``onRender(render:)`` that will
///push a debug group and pop it. The effect should be a clearColor on screen.
///
/// - Parameters:
///   - device: The Metal Device being used. If your app/game needs to keep up with the device then
///   you should explicitly create device and provide the reference to it here. nil is default.
///   If nil then the init will create a system defaultl device
///   - clearColor: The  `MTLClearColor` to use. The default isi nil. Use `MTLClearColorMake` to
///   generate a color. If nil, then the underlying `MTKView` will use (0, 0, 0, 1) as its default
///   - colorPixelFormat: The `MTLPixelFormat` to use for the colorPixelFormat. The default is nil.
///   If nil, then the underlying `MTKView` will use `MTLPixelFormat.bgra8Unorm` as it iss default.
///   - depthPixelFormat: The `MTLPixelFormat` to use for the depthPixelFormat. The default is nil.
///   If nil, then no value is set and the view will use system defaults.
///   - framesPerSecond: The framesPerSecond will be sent to the underlying `MTKView`. This number
///   represents the `preferredFramesPerSecond` and is not guaranteed.
///   The default isi nil. if nil, then  the underlying `MTKView` will default to 60 frames per second
///
	public init(device: MTLDevice? = nil,
				clearColor: MTLClearColor? = MTLClearColorMake(1.0, 0.0, 0.0, 1.0),
				colorPixelFormat: MTLPixelFormat? = nil,
				depthPixelFormat: MTLPixelFormat? = nil,
				framesPerSecond: Int? = nil){
		self.clearColor = clearColor
		self.colorPixelFormat = colorPixelFormat
		self.depthPixelFormat = depthPixelFormat
		
		if let _ = device {
			self.device = device
		} else {
			self.device = MTLCreateSystemDefaultDevice()

		}
		self.framesPerSecond = framesPerSecond
	}
	private func setDrawingMode(for view: MTKView) -> MTKView{
		let result = view
		result.isPaused = false
		result.enableSetNeedsDisplay = false
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
 The main render loop.

 This function can be used to declaratively set the onDraw Function. onDraw will be the main render
 loop in the app/game. You have to create the commandBuffer in your app. You are responsible for calling all
 render functions. if you set a .timed interval on initi then this function will be called once for each frame.

 The following code calls the onMainLoop and then sets up  and implements the render pipeline

 ```swift
MetalView()
.onMainLoop(){ view in
   if let drawable = view.currentDrawable,
     let commandBuffer = command.makeCommandBuffer(),
     let renderPassDesciptor =  view.currentRenderPassDescriptor,
     let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder
						(descriptor: renderPassDesciptor){
        renderCommandEncoder.endEncoding()
		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
 ```
 - Parameter action: This is a function that takes one parameters described in
 ``DrawCallFunction``
 	1) An MTKView allows your render pass to get the currentDrawable and the
 	  currentRenderPassDescriptor
 - Returns: a View
 */
	public func onMainLoop( _ callBackFunction: @escaping DrawCallFunction) -> MetalView {
		var result = self
		if let _ = result.onRenderCallback {
			result.onRenderCallback = nil
		}
		result.onMainLoopCallback = callBackFunction
		return result
	}

/**
 A managed main event loop.

This function will present a simpler loop to the programmer. The view will manage the device
and the command queue. It iwill generate the Render command encoder and send that
to the call back function The resulting code only has to send commands to the
renderCommandEncoder. Once the function returns, the view will the present the drawable and
commit the drawable to the commandBuffer.

The following code will set the renderPipeliineState, set the vertexBuffer, and draw a triangle.
```swift
MetalView()
.onRender(){ rCE in
   rCE.setRenderPipelineState(renderPipelineState)
   rCE.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
   rCE.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
}
```
 - Parameter action: Function that takes a MTLRenderCommandEncoder in
 - Returns: some view so iti can be used declaratively in SwiftUI
 */
	

	public func onRender(_  action: ((MTLRenderCommandEncoder) -> Void)? = nil) -> MetalView {
		var result = self
		if let _ = result.onMainLoopCallback {
			result.onMainLoopCallback = nil
		}
		result.commandQueue = result.device?.makeCommandQueue()
		result.onRenderCallback = action
		return result
	}
/**

An update loop

This function will be used when youi do not want to fully manage the rendering setup so you use onRender instead of onMainLoop. onMainLoop will ignore this funciton and you would need to call this inside your mainLoop if you use onMainloop. The managed loop will call this inside the managed main event loop before it makes any calls to the renderer. It takes no arguments and returns no arguments. each call should equate to one frame cycle

**/

	public func onUpdate(_ action: ()->Void)-> MetalView{
		var result = self
		result.onUpdateCallback = action
		return result
	}	


/**
Function call back when the view Size has changed.

IT may be necessary for the application/game to know the overall size of its viewport. The size can change
 behind the scenes.

 - Parameter callBack: Function that will take width and height. The paramenter passed to the function will reflect the new overall size of the viewPort.

*/
	public func onSizeChange(_ callBack: @escaping ((Float, Float)->Void))-> MetalView{
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
			if parent.onRenderCallback == nil || parent.onMainLoopCallback == nil {
				// we need to initialize a command queue to at least clear the screen
				self.parent.commandQueue = parent.device?.makeCommandQueue()
			}
		}

		public func mtkView(_ view: MTKView, drawableSizeWillChange newSize: CGSize) {
			self.size = newSize
			if let onSizeChangeCB = parent.onSizeChangeCallback {
				onSizeChangeCB(Float(newSize.width), Float(newSize.height))
			}
		}

		/// This delegate function will call the parents drawFunction if it exists. This is part of the
		///  render cycle.
		/// - Parameter view: The view we are drawing in.
		public func draw(in view: MTKView) {
			if let mainLoop = parent.onMainLoopCallback {
				mainLoop( view )
			} else if let onRenderCallback = parent.onRenderCallback {
				// check to see if we need to update first
				if let update = parent.onUpdateCallback {
					update()	
				}
				if let commandBuffer = parent.commandQueue?.makeCommandBuffer(),
				   let renderPassDesciptor =  view.currentRenderPassDescriptor,
				   let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesciptor),
				   let drawable = view.currentDrawable
				{
					onRenderCallback(renderCommandEncoder)
					renderCommandEncoder.endEncoding()
					commandBuffer.present(drawable)
					commandBuffer.commit()
				}
			} else { // no render function was provided. in this case we will just clear screen when asked
					if  let drawable = view.currentDrawable,
						let commandBuffer = parent.commandQueue?.makeCommandBuffer(),
					   let renderPassDesciptor =  view.currentRenderPassDescriptor,
					   let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesciptor)

					{

						renderCommandEncoder.endEncoding()
						commandBuffer.present(drawable)
						commandBuffer.commit()
					}
			}
		}
	}
}


