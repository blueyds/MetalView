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
///
public struct MetalView: Representable {
	private var clearColor: MTLClearColor?
	private var colorPixelFormat: MTLPixelFormat?
	private var depthPixelFormat: MTLPixelFormat?
	private var device: MTLDevice?
	private var commandQueue: MTLCommandQueue?
	public enum drawingModeType{
		case Timed, Notifications, Explicit
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
			self.device = MTLCreateSystemDefaultDevice()
		} else {
			self.device = device
		}
		self.drawingMode = drawingMode
		commandQueue = self.device?.makeCommandQueue()
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

		public func draw(in view: MTKView) {
			if let onDrawCallback = parent.onDrawCallback,
			   let frameSize = size,
			   let command = parent.commandQueue {
				onDrawCallback(view, command, frameSize)
			}
		}
	}
}


