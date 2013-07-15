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

#import "GameViewController.h"
#import "ExternalDisplay.h"
#import "UIImage+CaptureScreen.h"
#import "FakeCameraUtil.h"

extern PreviewableViewController *previewInstance;

@implementation GameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self initialize];
    [boardCalibrator startFindBounds];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self.view bringSubviewToFront:boardCalibrator];
    [self.view bringSubviewToFront:super.overlayView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [cameraSession start];
}

- (void)initialize {
    self.view.backgroundColor = [UIColor blackColor];
    
    cameraSession = [[CameraSession alloc] initWithDelegate:self];

    boardCalibrator = [[BoardCalibrator alloc] initWithFrame:self.view.bounds cameraSession:cameraSession];
    [self.view addSubview:boardCalibrator];

    gameState = GAME_STATE_INITIAL_CALIBRATION;
}

- (void)processFrame:(UIImage *)image {
    [previewInstance previewFrame:[[[BoardRecognizer alloc] init] boardEdgesToImage:image] boardCalibrator:boardCalibrator];
    //[previewInstance previewFrame:image boardCalibrator:boardCalibrator];

    [self calibrateBoard:image];
    [self updateGameStateAccordingToFrame];
}

- (void)updateGameStateAccordingToFrame {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setFrameUpdateIntervalAccordingToGameState];
        if (gameState == GAME_STATE_INITIAL_CALIBRATION) {
            if (boardCalibrator.state == BOARD_CALIBRATION_STATE_CALIBRATED) {
                [self startIntro];
            }
        }
        cameraSession.readyToProcessFrame = YES;
    });
}

- (void)setFrameUpdateIntervalAccordingToGameState {
    if (boardCalibrator.state != BOARD_CALIBRATION_STATE_CALIBRATED) {
        cameraSession.delegateProcessFrameInterval = CAMERA_SESSION_DELEGATE_INTERVAL_FAST;
    } else {
        //cameraSession.delegateProcessFrameInterval = CAMERA_SESSION_DELEGATE_INTERVAL_DEFAULT;
    }
}

- (void)startIntro {
    gameState = GAME_STATE_INTRO;
    intro = [[Intro alloc] initWithFrame:self.view.bounds delegate:self];
    [self.view insertSubview:intro atIndex:0];
    [intro show];
}

- (void)introFinished {
    [intro removeFromSuperview];
    [self startBoardGame];
}

- (void)startBoardGame {
    boardGame = [[BoardGame alloc] initWithFrame:self.view.bounds delegate:self];
    [self.view insertSubview:boardGame atIndex:0];
    [boardGame startWithLevel:0];
}

- (void)boardGameFinished {
    NSLog(@"Board game finished!");
}

- (void)calibrateBoard:(UIImage *)image {
    if (boardCalibrator.state != BOARD_CALIBRATION_STATE_CALIBRATING) {
        return;
    }
    [boardCalibrator updateBoundsWithImage:image];
    if (boardCalibrator.state == BOARD_CALIBRATION_STATE_CALIBRATED) {
        [previewInstance hideBoardContour];
    } else {
        [previewInstance previewBoardContour:boardCalibrator.boardBounds];
    }
}

- (UIImage *)requestSimulatedImageIfNoCamera {
    super.overlayView.hidden = YES;
    UIImage *image = [UIImage imageWithView:self.view];
    UIImage *transformedImage = [FakeCameraUtil fakePerspectiveOnImage:image];
    super.overlayView.hidden = NO;
    return transformedImage;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end