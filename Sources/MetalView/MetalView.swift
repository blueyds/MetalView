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

public struct MetalView: Representable {
	
	private var clearColor: MTLClearColor?
	private var colorPixelFormat: MTLPixelFormat?
	private var depthPixelFormat: MTLPixelFormat?
	private var device: MTLDevice?
	public enum drawingModeType{
		case Timed, Notifications, Explicit
	}
	private var drawingMode: drawingModeType
	private var onDrawCallback: ((CAMetalDrawable, MTLRenderPassDescriptor, CGSize) -> Void)? = nil

	public init(device: MTLDevice? = nil, drawingMode: drawingModeType = .Timed){
		if let _ = device {
			self.device = MTLCreateSystemDefaultDevice()
		} else {
			self.device = device
		}
		self.drawingMode = drawingMode
	}
	
	public init(device: MTLDevice? = nil,
				drawingMode: drawingModeType = .Timed,
				clearColor: MTLClearColor,
				colorPixelFormat: MTLPixelFormat,
				depthPixelFormat: MTLPixelFormat){
		self.clearColor = clearColor
		self.colorPixelFormat = colorPixelFormat
		self.depthPixelFormat = depthPixelFormat
		if let _ = device {
			self.device = MTLCreateSystemDefaultDevice()
		} else {
			self.device = device
		}
		self.drawingMode = drawingMode
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

	public func onDraw( perform action: ((CAMetalDrawable, MTLRenderPassDescriptor, CGSize) -> Void)? = nil) -> some View {
		var result = self
		if let action = action {
			result.onDrawCallback = action
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
			guard let drawable = view.currentDrawable else {return}
			if let onDrawCallback = parent.onDrawCallback,
			   let rpe = view.currentRenderPassDescriptor,
			   let size = size {
				onDrawCallback(drawable, rpe, size)
			}
		}





	}
}


