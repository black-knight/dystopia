// Copyright (c) 2013, Daniel Andersen (daniel@trollsahead.dk)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "CameraSession.h"
#import "CameraUtil.h"

@implementation CameraSession

@synthesize initialized;
@synthesize readyToProcessFrame;

- (id)initWithDelegate:(id<CameraSessionDelegate>)d {
    if (self = [super init]) {
        delegate = d;
        [self initialize];
    }
    return self;
}

- (void)initialize {
    initialized = NO;
    
    frameProcessQueue = dispatch_queue_create("dk.trollsahead.dystopia.CameraSession.ProcessFrame", NULL);

    session = [[AVCaptureSession alloc] init];
    
    [session beginConfiguration];
    session.sessionPreset = [session canSetSessionPreset:AVCaptureSessionPreset640x480] ? AVCaptureSessionPreset640x480 : AVCaptureSessionPresetMedium;
    
    if (![self addVideoInput]) {
        NSLog(@"Could not add device input!");
        return;
    }
    if (![self addVideoOutput]) {
        NSLog(@"Could not add device output!");
        return;
    }
    
    [session commitConfiguration];
    
    readyToProcessFrame = YES;
    initialized = YES;
    
    NSLog(@"Camera session initialized");
}

- (bool)addVideoInput {
    AVCaptureDeviceInput *input = [self findDeviceInput];
    if ([session canAddInput:input]) {
        [session addInput:input];
        return YES;
    } else {
        return NO;
    }
}

- (bool)addVideoOutput {
    AVCaptureVideoDataOutput *output = [self createDeviceOutput];
    if ([session canAddOutput:output]) {
        [session addOutput:output];
        return YES;
    } else {
        return NO;
    }
}

- (AVCaptureVideoDataOutput *)createDeviceOutput {
    dispatch_queue_t queue = dispatch_queue_create("dk.trollsahead.dystopia.CameraSession.ReceiveFrame", NULL);
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    [output setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [output setSampleBufferDelegate:self queue:queue];
    return output;
}

- (AVCaptureDeviceInput *)findDeviceInput {
    NSError *error;
    AVCaptureDevice *device = [self findBackfacingDevice];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        NSLog(@"%@", error.description);
    }
    return input;
}

- (AVCaptureDevice *)findBackfacingDevice {
    for (AVCaptureDevice *device in [AVCaptureDevice devices]) {
        if ([device hasMediaType:AVMediaTypeVideo] && [device position] == AVCaptureDevicePositionBack) {
            return device;
        }
    }
    return nil;
}

- (void)start {
    if (initialized) {
        [session startRunning];
        NSLog(@"Camera session started");
    } else {
        NSLog(@"Did not start camera session!");
    }
}

- (void)stop {
    if (initialized) {
        [session stopRunning];
        NSLog(@"Camera session stopped");
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (readyToProcessFrame) {
        readyToProcessFrame = NO;
        @autoreleasepool {
            CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            UIImage *image = [CameraUtil imageFromPixelBuffer:pixelBuffer];
            dispatch_async(frameProcessQueue, ^{
                [delegate processFrame:image];
            });
        };
    }
}

@end
