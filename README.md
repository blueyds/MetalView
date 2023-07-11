# MetalView

MetalView is a platform agnostic presentation of MTKView. Metal Views in
MTKView are represented with the UIViewRepresentable or the 
NSViewRepresentable. This eliminates that and allows you to easily plug
the view into a SwiftUI View.

## Basic Usage

At its simplest you can enter it with no parameters and it will present
a clearColor screen using (0, 0, 0, 1).

    var body: some View{
        MetalView()
	}

More documentation is available as built DocC.

## Features

- Custom main loop function that can get called every render cycle. Main loop will send current MTKView. This allows program to manage how the drawable and the renderCommandEncoder is pulled down. 
- MTLDevice management. if you pass your won device then you can manage the device and use it as you need it in other parts of your program. Otherwise, the view will manage the device internally. If the view creates the device then you cannot query it for its device reference.
- Simplified render loop function that pulls down the drawable and sets up the  renderCommandEncoder for you. ALl you have to is send commands to the encoder. The render loop will also close the drawable and commit everything to the commandBuffer.
- Size change callback function. Allows program to keep track of the view size.
- colorPixelFormat
- depthColorPixelFormat


