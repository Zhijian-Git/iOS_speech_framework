//
//  ViewController.m
//  SpeechFMDemo
//
//  Created by zhijian.li on 2023/3/23.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    // 初始化状态标签
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.frame.size.width - 40, 30)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"Speech recognition not available";
    [self.view addSubview:self.statusLabel];

    // 初始化开始按钮
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startButton.frame = CGRectMake(20, 150, self.view.frame.size.width - 40, 30);
    [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
    [self.startButton addTarget:self action:@selector(startButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startButton];

    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(20, 200, self.view.frame.size.width - 40, 200)];
    self.textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.textView.layer.borderWidth = 1;
    self.textView.layer.cornerRadius = 5;
    self.textView.layer.masksToBounds = YES;
    [self.view addSubview:self.textView];

    _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh-CN"]];
    _audioEngine = [[AVAudioEngine alloc] init];
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                // User has authorized speech recognition
                self.startButton.enabled = YES;
                self.statusLabel.text = @"ready to speech recognition";
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                // User has denied speech recognition
                self.startButton.enabled = NO;
                self.statusLabel.text = @"User denied access to speech recognition";
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                // Speech recognition is restricted on this device
                self.startButton.enabled = NO;
                self.statusLabel.text = @"Speech recognition is restricted on this device";
                break;
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                // Speech recognition has not been authorized yet
                self.startButton.enabled = NO;
                self.statusLabel.text = @"Speech recognition has not been authorized yet";
                break;
            default:
                break;
        }
    }];
}

- (IBAction)startButtonTapped:(id)sender {
    if (_audioEngine.isRunning) {
        [self stopRecording];
        [self stopCaptureSession];

        _startButton.enabled = NO;
        [_startButton setTitle:@"Stopping" forState:UIControlStateDisabled];
    } else {
        [self startCaptureSession];
        [self startRecording];

        [_startButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
}

- (void)startCaptureSession {
    NSError *error = nil;
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@"Failed to create audio input device: %@", error);
        return;
    }
    if ([self.captureSession canAddInput:self.audioInput]) {
        [self.captureSession addInput:self.audioInput];
    }
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioQueue = dispatch_queue_create("AudioCaptureQueue", DISPATCH_QUEUE_SERIAL);
    [self.audioOutput setSampleBufferDelegate:self queue:audioQueue];
    if ([self.captureSession canAddOutput:self.audioOutput]) {
        [self.captureSession addOutput:self.audioOutput];
    }
    
    [self.captureSession startRunning];
}

- (void)stopCaptureSession {
    [self.captureSession stopRunning];
}

- (void)processAudioBuffer:(CMSampleBufferRef)sampleBuffer {
    if(![self.audioInput.device hasMediaType:AVMediaTypeAudio]) {
        NSLog(@"Audio input device is not capturing audio data.");
        return;
    }
    float volume = [self volumeLevelFromSampleBuffer:sampleBuffer];
    self.currentVolume = volume;
}

- (float)volumeLevelFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // // 获取音频输入设备的平均音量
    // CFArrayRef channelArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    // CFDictionaryRef channelDict = CFArrayGetValueAtIndex(channelArray, 0);
    // const void *peakValue;
    // OSStatus status = CMAttachmentGetPropert(channelDict, kCMSampleAttachmentKey_ChannelLevelMeteringInfo, &peakValue);
    // if (status == noErr) {
    //     const struct AudioChannelLevel *audioChannelLevels = peakValue;
    //     float peak = audioChannelLevels[0].mPeakPower;
    //     float average = audioChannelLevels[0].mAveragePower;
    //     return average;
    // }

    // 获取音频样本数据
    CMBlockBufferRef audioBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t lengthAtOffset;
    size_t totalLength;
    char *data;

    if (CMBlockBufferGetDataPointer(audioBuffer, 0, &lengthAtOffset, &totalLength, &data) == noErr) {
        // 计算音量大小
        float volume = 0;
        for (int i = 0; i < totalLength; i += 2) {
            int16_t sample = *(int16_t *)(data + i);
            volume += (sample * sample);
        }

        volume /= totalLength;
        volume = sqrtf(volume);

        NSLog(@"音量大小: %f", volume);
        return volume;
    }else {
        NSLog(@"获取音频样本数据失败");
    }
    return 0.0;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [self processAudioBuffer:sampleBuffer];
}

- (void)startRecording {
    if (_recognitionTask) {
        [_recognitionTask cancel];
        _recognitionTask = nil;
    }

    self.currentVolume = 0.0;
    
    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    
    _recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    
    AVAudioInputNode *inputNode = [_audioEngine inputNode];
    _recognitionRequest.shouldReportPartialResults = YES;
    __block typeof(self) weakSelf = self;
    _recognitionTask = [_speechRecognizer recognitionTaskWithRequest:_recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        BOOL isFinal = NO;
        if (result) {
            weakSelf.textView.text = [[result bestTranscription] formattedString];
            isFinal = [result isFinal];
        }
        if (error || isFinal) {
            [weakSelf.audioEngine stop];
            [inputNode removeTapOnBus:0];
            weakSelf.recognitionRequest = nil;
            weakSelf.recognitionTask = nil;
            weakSelf.startButton.enabled = YES;
            [weakSelf.startButton setTitle:@"Start" forState:UIControlStateNormal];
        }
    }];
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [weakSelf.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [_audioEngine prepare];
    [_audioEngine startAndReturnError:&error];
    _statusLabel.text = @"Say something, I'm listening!";
}

- (void)stopRecording {
    self.currentVolume = 0.0;

    [_audioEngine stop];
    [_recognitionRequest endAudio];
}

#pragma mark - SFSpeechRecognizerDelegate

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    if (available) {
    _startButton.enabled = YES;
    _statusLabel.text = @"Speech recognition available";
    } else {
    _startButton.enabled = NO;
    _statusLabel.text = @"Speech recognition not available";
    }
}
@end
