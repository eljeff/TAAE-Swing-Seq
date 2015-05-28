//
//  ElaborateDemoVC.m
//  The Amazing Audio Engine
//
//  Created by Ariel Elkin on 01/04/2014.
//  Copyright (c) 2014 Ariel Elkin. All rights reserved.
//

#import "ElaborateDemoVC.h"

#import "AEAudioController.h"
#import "AESequencerChannel.h"
#import "AESequencerBeat.h"
#import "AESequencerChannelSequence.h"

#import "SequencerButton.h"
#define NUM_STEPS 16


@import AVFoundation;

@interface ElaborateDemoVC()<SequencerButtonDelegate>

@end

@implementation ElaborateDemoVC {
    
    AEAudioController *audioController;

    AESequencerChannel *kickChannel;
    AESequencerChannel *woodblockChannel;
    AESequencerChannel *crickChannel;
    AESequencerChannel *hihatChannel;

    AEChannelGroupRef _mainChannelGroup;

    IBOutlet UIButton *playPauseButton;
    
    bool sequencerIsPlaying;

    NSInteger numberOfRows;
    NSInteger numberOfColumns;
    CGFloat buttonWidth;
    CGFloat buttonHeight;
    CGFloat offsets[NUM_STEPS];

    IBOutlet UILabel *infoLabel;
    IBOutlet UILabel *swingLabel;
}


#pragma mark -
#pragma mark Setup

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self setupSequencerUI];
    [self setupAudioController];
    [self setupSequencer];

    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgressView) userInfo:nil repeats:YES];
    
    for (int i = 0; i < NUM_STEPS; i++){
        float offsetAmt = (float)i/NUM_STEPS;
        offsets[i] = offsetAmt;
    }
}


- (void)setupSequencerUI {

    [_mainVolumeSlider addTarget:self action:@selector(mainVolumeSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_bpmSlider addTarget:self action:@selector(bpmSliderChanged:) forControlEvents:UIControlEventValueChanged];


    UIView *sequencerView = [UIView new];
    sequencerView.backgroundColor = [UIColor purpleColor];
    sequencerView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:sequencerView];

    NSArray *constraintsH = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[sequencerView]-240-|" options:0 metrics:nil views:@{@"sequencerView": sequencerView}];
    [self.view addConstraints:constraintsH];

    NSArray *constraintsV = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[sequencerView]|" options:0 metrics:nil views:@{@"sequencerView": sequencerView}];
    [self.view addConstraints:constraintsV];

    CGFloat seqWidth = infoLabel.frame.origin.x;
    
    numberOfRows = 4;
    numberOfColumns = NUM_STEPS;
    CGFloat buttonMargin = (seqWidth/NUM_STEPS)*0.2;
    CGFloat buttonHeightMargin = (seqWidth/numberOfRows)*0.2;
    buttonWidth = ((seqWidth - buttonMargin/2)/NUM_STEPS) - buttonMargin;
    
    buttonHeight = (((self.view.frame.size.height - buttonMargin/2)/numberOfRows) - buttonHeightMargin) * 0.9;

    for( int i = 0; i < numberOfRows; i++) {

        for ( int j = 0 ; j < numberOfColumns; j++ ) {

            SequencerButton *sequencerButton = [SequencerButton buttonWithRow:i column:j];
            sequencerButton.delegate = self;
            CGFloat width = buttonWidth;
            CGFloat height = buttonHeight;
            CGFloat originX = (j * width) * 1.2 + buttonMargin;
            CGFloat originY = (i * height) * 1.2 + buttonHeightMargin;
            sequencerButton.frame = CGRectMake(originX, originY, width, height);

            [sequencerView addSubview:sequencerButton];
        }
    }
    [self.view bringSubviewToFront:self.playheadPositionOfKickSequence];
}


- (void) updateProgressView {
    self.playheadPositionOfKickSequence.progress = kickChannel.playheadPosition;
}


#pragma mark -
#pragma mark Playback Control

- (IBAction)togglePlayPause {

    sequencerIsPlaying = !sequencerIsPlaying;

    // Sweep all channels and apply.
    NSArray *channels = [self sequencerChannelsInGroup:_mainChannelGroup];
    for(int i = 0; i < channels.count; i++) {
        AESequencerChannel *channel = [channels objectAtIndex:i];
        channel.sequenceIsPlaying = sequencerIsPlaying;
    }

    // Toggle button.
    if(!sequencerIsPlaying) {
        [playPauseButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        playPauseButton.backgroundColor = [UIColor orangeColor];
    }
    else {
        playPauseButton.backgroundColor = [UIColor blackColor];
        [playPauseButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    }
}

- (void)tappedButton:(SequencerButton *)button {

    AESequencerChannel *selectedChannel;

    if (button.row == 0) selectedChannel = kickChannel;
    else if (button.row == 1) selectedChannel = woodblockChannel;
    else if (button.row == 2) selectedChannel = crickChannel;
    else if (button.row == 3) selectedChannel = hihatChannel;
    
    //double onset = (double)button.column / (double)numberOfColumns;
    double onset = offsets[(int)button.column];

    AESequencerBeat *beat = [AESequencerBeat beatWithOnset:onset];

    if (button.isActive) {
        [selectedChannel.sequence addBeat:beat];
    }
    else {
        [selectedChannel.sequence removeBeatAtOnset:onset];
    }
    NSLog(@"%@", selectedChannel.sequence);
}

- (void)mainVolumeSliderChanged:(UISlider*)sender {
    [audioController setVolume:sender.value forChannelGroup:_mainChannelGroup];
}

- (void)bpmSliderChanged:(UISlider*)sender {
    //    NSLog(@"bpmSliderChanged: %f", sender.value);

    // Update label.
    _bpmLabel.text = [NSString stringWithFormat:@"%f", sender.value];

    // Sweep all channels and apply.
    NSArray *channels = [self sequencerChannelsInGroup:_mainChannelGroup];
    for(int i = 0; i < channels.count; i++) {
        AESequencerChannel *channel = [channels objectAtIndex:i];
        channel.bpm = sender.value;
    }
}

- (IBAction)swingChanged:(id)sender {

    AESequencerChannelSequence *sequence;
    UISlider *swingSlider = sender;
    bool swingStep = NO;
    
    float swingAmount = 100*(swingSlider.value - swingSlider.minimumValue)/(swingSlider.maximumValue - swingSlider.minimumValue);
    swingLabel.text = [NSString stringWithFormat:@"%.2f %%",swingAmount];
    for (int i = 0; i < NUM_STEPS; i++){
        if(swingStep){
            float oldOffset = offsets[i];
            float newOffset = (float)i/NUM_STEPS + ((swingSlider.value - 0.5) * ((float)1/NUM_STEPS)*2);
            offsets[i] = newOffset;
            for (int seqI = 0; seqI < 4; seqI++){
                switch (seqI) {
                    case 0:
                        sequence = kickChannel.sequence;
                        break;
                    case 1:
                        sequence = woodblockChannel.sequence;
                        break;
                    case 2:
                        sequence = crickChannel.sequence;
                        break;
                    case 3:
                        sequence = hihatChannel.sequence;
                        break;
                    default:
                        break;
                }//set sequence depending on loop
                AESequencerBeat *step = [sequence beatAtOnset:oldOffset];
                if(step){
                    [sequence removeBeatAtOnset:step.onset];
                    [sequence addBeat:[AESequencerBeat beatWithOnset:newOffset]];
                }//add / remove swing
            }//loop over each sequence
        }//if this is a squng step
        swingStep = !swingStep;
    }//loop over each step
}

#pragma mark -
#pragma mark Sequencer Setup

- (void)setupSequencer {
    _mainChannelGroup = [audioController createChannelGroup];
    sequencerIsPlaying = false;


    // Pattern vars.
    double bpm = _bpmSlider.value;
    NSUInteger numBeats = 4;

    // KICK channel
    NSURL *kickURL = [[NSBundle mainBundle] URLForResource:@"kick" withExtension:@"caf"];
    AESequencerChannelSequence *kickSequence = [AESequencerChannelSequence new];
    kickChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:kickURL
                                                    audioController:audioController
                                                       withSequence:kickSequence
                                        numberOfFullBeatsPerMeasure:numBeats
                                                              atBPM:bpm];
    [audioController addChannels:@[kickChannel] toChannelGroup:_mainChannelGroup];


    // WOODBLOCK channel
    NSURL *woodblockURL = [[NSBundle mainBundle] URLForResource:@"woodblock" withExtension:@"caf"];
    AESequencerChannelSequence *woodblockSequence = [AESequencerChannelSequence new];
    woodblockChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:woodblockURL
                                                         audioController:audioController
                                                            withSequence:woodblockSequence
                                             numberOfFullBeatsPerMeasure:numBeats
                                                                   atBPM:bpm];
    [audioController addChannels:@[woodblockChannel] toChannelGroup:_mainChannelGroup];



    // CRICK channel
    NSURL *crickURL = [[NSBundle mainBundle] URLForResource:@"crick" withExtension:@"caf"];
    AESequencerChannelSequence *crickSequence = [AESequencerChannelSequence new];
    crickChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:crickURL
                                                     audioController:audioController
                                                        withSequence:crickSequence
                                         numberOfFullBeatsPerMeasure:numBeats
                                                               atBPM:bpm];
    [audioController addChannels:@[crickChannel] toChannelGroup:_mainChannelGroup];


    // HI-HAT channel
    NSURL *hihatURL = [[NSBundle mainBundle] URLForResource:@"hihat" withExtension:@"caf"];
    AESequencerChannelSequence *hihatSequence = [AESequencerChannelSequence new];
    hihatChannel = [AESequencerChannel sequencerChannelWithAudioFileAt:hihatURL
                                                     audioController:audioController
                                                        withSequence:hihatSequence
                                         numberOfFullBeatsPerMeasure:numBeats
                                                               atBPM:bpm];
    [audioController addChannels:@[hihatChannel] toChannelGroup:_mainChannelGroup];

}

- (void)setupAudioController {

    // Init audio controller:
    audioController = [[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription]];

    // Start it.
    NSError *audioControllerStartError = nil;
    [audioController start:&audioControllerStartError];
    if (audioControllerStartError) {
        NSLog(@"Audio controller start error: %@", audioControllerStartError.localizedDescription);
    }
}

- (IBAction)pressedBackButton{

    for (AESequencerChannel *channel in [audioController channelsInChannelGroup:_mainChannelGroup]){
        channel.sequenceIsPlaying = false;
    }
    [audioController stop];
    [self dismissViewControllerAnimated:YES completion:nil];

}


#pragma mark -
#pragma mark Utils

- (NSArray*)sequencerChannelsInGroup:(AEChannelGroupRef)group {
    
    NSMutableArray *seqChannels = [NSMutableArray array];
    
    NSArray *channels = [audioController channelsInChannelGroup:group];
    for(int i = 0; i < channels.count; i++) {
        id channel = [channels objectAtIndex:i];
        if([channel isKindOfClass:[AESequencerChannel class]]) {
            [seqChannels addObject:channel];
        }
    }
    
    return seqChannels;
}

@end

