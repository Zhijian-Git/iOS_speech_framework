//
//  ViewController.h
//  SpeechFMDemo
//
//  Created by zhijian.li on 2023/3/23.
//

#import <UIKit/UIKit.h>
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController <SFSpeechRecognizerDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UIButton *startButton;
@property (strong, nonatomic) IBOutlet UITextView *textView;

@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) AVAudioEngine *audioEngine;

@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDeviceInput *audioInput;
@property (strong, nonatomic) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic) float currentVolume;

- (IBAction)startButtonTapped:(id)sender;

- (void)startCaptureSession;
- (void)stopCaptureSession;
- (void)processAudioBuffer:(CMSampleBufferRef)sampleBuffer;

@end
