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

#import <QuartzCore/QuartzCore.h>

#import "BoardCalibrator.h"
#import "CameraSession.h"
#import "CameraUtil.h"
#import "ExternalDisplay.h"

@implementation BoardCalibrator

const float calibrationBorderPct = 0.03f;
const UIColor *calibrationBorderColor;

const float calibrationFadeInterval = 2.0f;

@synthesize state;
@synthesize boardBounds;
@synthesize screenPoints;
@synthesize boardCameraToScreenTransformation;

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    boardRecognizer = [[BoardRecognizer alloc] init];
    state = BOARD_CALIBRATION_STATE_UNCALIBRATED;
    boardBounds.defined = NO;
    [self setupView];
}

- (void)start {
    [self setCalibrationViewAlpha:1.0f];
    state = BOARD_CALIBRATION_STATE_CALIBRATING;
    successCount = 0;
    boardBounds.defined = NO;
    NSLog(@"Board calibration started");
}

- (void)updateWithImage:(UIImage *)image {
    boardBounds = [boardRecognizer findBoardBoundsFromImage:image];
    if (boardBounds.defined) {
        successCount++;
        [self findCameraToScreenTransformation];
        [self findScreenPoints];
        if (successCount >= BOARD_CALIBRATION_SUCCESS_COUNT) {
            [self success];
        }
    } else {
        successCount = 0;
    }
}

- (void)findCameraToScreenTransformation {
    CGSize screenSize = [ExternalDisplay instance].widescreenBounds.size;
    FourPoints dstPoints = {.p1 = CGPointMake(0.0f, 0.0f), .p2 = CGPointMake(screenSize.width, 0.0f), .p3 = CGPointMake(screenSize.width, screenSize.height), .p4 = CGPointMake(0.0f, screenSize.height)};
    boardCameraToScreenTransformation = [CameraUtil findAffineTransformationSrcPoints:boardBounds dstPoints:dstPoints];
}

- (void)findScreenPoints {
    screenPoints.p1 = [self affineTransformPoint:boardBounds.p1 transformation:boardCameraToScreenTransformation];
    screenPoints.p2 = [self affineTransformPoint:boardBounds.p2 transformation:boardCameraToScreenTransformation];
    screenPoints.p3 = [self affineTransformPoint:boardBounds.p3 transformation:boardCameraToScreenTransformation];
    screenPoints.p4 = [self affineTransformPoint:boardBounds.p4 transformation:boardCameraToScreenTransformation];
}

- (CGPoint)affineTransformPoint:(CGPoint)p transformation:(cv::Mat)transformation {
    cv::Mat src(3, 1, CV_64F);
    src.at<double>(0, 0) = p.x;
    src.at<double>(1, 0) = p.y;
    src.at<double>(2, 0) = 1.0f;
    cv::Mat dst = transformation * src;
    return CGPointMake(dst.at<double>(0, 0), dst.at<double>(1, 0));
}

- (void)success {
    state = BOARD_CALIBRATION_STATE_CALIBRATED;
    [self setCalibrationViewAlpha:0.0f];
    NSLog(@"Board calibrated!");
}

- (void)setCalibrationViewAlpha:(float)alpha {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (alpha == 1.0f) {
            self.layer.hidden = NO;
        }
        [UIView animateWithDuration:calibrationFadeInterval animations:^{
            self.layer.opacity = alpha;
        } completion:^(BOOL finished) {
            if (alpha == 0.0f) {
                self.layer.hidden = YES;
            }
        }];
    });
}

- (void)setupView {
    self.hidden = YES;
    self.layer.opacity = 0.0f;
    
    calibrationBorderColor = [UIColor colorWithRed:0.0f green:0.4f blue:0.0f alpha:1.0f];
    
    float borderWidth = self.frame.size.width * calibrationBorderPct;
    float borderHeight = self.frame.size.height * calibrationBorderPct;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    // Top
    [path moveToPoint:CGPointMake(0.0f,                     0.0f)];
    [path addLineToPoint:CGPointMake(self.frame.size.width, 0.0f)];
    [path addLineToPoint:CGPointMake(self.frame.size.width, borderHeight)];
    [path addLineToPoint:CGPointMake(0.0f,                  borderHeight)];
    [path closePath];
    
    // Bottom
    [path moveToPoint:CGPointMake(0.0f,                     self.frame.size.height - borderHeight)];
    [path addLineToPoint:CGPointMake(self.frame.size.width, self.frame.size.height - borderHeight)];
    [path addLineToPoint:CGPointMake(self.frame.size.width, self.frame.size.height)];
    [path addLineToPoint:CGPointMake(0.0f,                  self.frame.size.height)];
    [path closePath];
    
    // Left
    [path moveToPoint:CGPointMake(0.0f,           borderHeight)];
    [path addLineToPoint:CGPointMake(borderWidth, borderHeight)];
    [path addLineToPoint:CGPointMake(borderWidth, self.frame.size.height - borderHeight)];
    [path addLineToPoint:CGPointMake(0.0f,        self.frame.size.height - borderHeight)];
    [path closePath];
    
    // Right
    [path moveToPoint:CGPointMake(self.frame.size.width - borderWidth,    borderHeight)];
    [path addLineToPoint:CGPointMake(self.frame.size.width,               borderHeight)];
    [path addLineToPoint:CGPointMake(self.frame.size.width,               self.frame.size.height - borderHeight)];
    [path addLineToPoint:CGPointMake(self.frame.size.width - borderWidth, self.frame.size.height - borderHeight)];
    [path closePath];
    
    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
    borderLayer.fillColor = calibrationBorderColor.CGColor;
    borderLayer.strokeColor = calibrationBorderColor.CGColor;
    borderLayer.path = path.CGPath;
    
    [self.layer addSublayer:borderLayer];
}

@end
